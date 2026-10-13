// Package auth는 로그인, 자체 토큰 발급·갱신, 로그아웃, 제공자 연결 해제를 맡는 서비스 계층입니다.
//
// 흐름은 다음과 같습니다.
//   - 로그인: 제공자 토큰을 검증하고 (provider, subject)로 계정을 찾거나 만듭니다.
//     삭제 대기 계정이면 되살리고 그 계정의 이전 세션(refresh token)을 모두 폐기합니다. 로그인마다 새 refresh family를 만들고 토큰 쌍을 발급합니다.
//   - 갱신: refresh token을 쓸 때마다 같은 family 안에서 새 토큰으로 바꿉니다(rotation).
//     이미 쓴 토큰이 다시 오면 탈취로 보고 family 전체를 폐기합니다.
//   - 로그아웃: 그 refresh token의 family를 폐기합니다.
//   - 제공자 연결 해제: 계정 삭제 때 Apple refresh token을 revoke하고 카카오 연결을 끊습니다.
//
// 로그에는 제공자 이름과 단계, 계정 id만 남깁니다. id_token·code·nonce·refresh token·subject·이메일은 남기지 않습니다.
package auth

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// DB의 provider 열에 넣는 값입니다.
const (
	providerKakao = "kakao"
	providerApple = "apple"
)

// DB의 accounts.status 값입니다.
const (
	statusActive          = "active"
	statusPendingDeletion = "pending_deletion"
	statusDeleted         = "deleted"
)

// identityUniqueConstraint는 (provider, subject) unique 제약 이름입니다. 동시 첫 로그인 경합을 알아보는 데 씁니다.
const identityUniqueConstraint = "auth_identities_provider_subject_key"

// sqlStateUniqueViolation은 unique 위반 SQLSTATE입니다.
const sqlStateUniqueViolation = "23505"

// KakaoVerifier는 카카오 id_token을 검증합니다. *provider.Kakao가 만족합니다.
type KakaoVerifier interface {
	Verify(ctx context.Context, idToken, rawNonce string) (provider.Identity, error)
}

// KakaoUnlinker는 카카오 사용자와 앱의 연결을 끊습니다. *provider.Kakao가 만족합니다.
type KakaoUnlinker interface {
	Unlink(ctx context.Context, subject string) error
}

// AppleClient는 Apple id_token 검증, authorization code 교환, refresh token revoke를 합니다. *provider.Apple이 만족합니다.
// (provider.AppleClient는 native·web 구분 값이고, 이 인터페이스는 Apple API 호출자입니다.)
type AppleClient interface {
	Verify(ctx context.Context, idToken, rawNonce string, client provider.AppleClient) (provider.Identity, error)
	ExchangeCode(ctx context.Context, code string, client provider.AppleClient) (refreshToken, clientID string, err error)
	Revoke(ctx context.Context, refreshToken, clientID string) error
}

// ServiceDeps는 Service가 쓰는 의존성입니다. Logger는 nil이면 아무것도 남기지 않습니다.
type ServiceDeps struct {
	Kakao       KakaoVerifier
	Apple       AppleClient
	KakaoUnlink KakaoUnlinker
	Access      *token.AccessIssuer
	Box         *secretbox.Box
	Clock       clock.Clock
	Logger      *slog.Logger
}

// TokenPair는 클라이언트에 주는 자체 토큰 한 쌍입니다.
type TokenPair struct {
	AccessToken      string
	AccessExpiresAt  time.Time
	RefreshToken     string
	RefreshExpiresAt time.Time
}

// LoginResult는 로그인 결과입니다.
type LoginResult struct {
	AccountID uuid.UUID
	Tokens    TokenPair
	// IsNewAccount는 이번 로그인으로 계정을 새로 만들었는지입니다.
	IsNewAccount bool
	// RestoredFromDeletion은 삭제 대기 계정을 이번 로그인으로 되살렸는지입니다.
	RestoredFromDeletion bool
}

// Service는 인증 서비스입니다. 여러 goroutine에서 동시에 써도 안전합니다.
type Service struct {
	pool        *pgxpool.Pool
	kakao       KakaoVerifier
	apple       AppleClient
	kakaoUnlink KakaoUnlinker
	access      *token.AccessIssuer
	box         *secretbox.Box
	clock       clock.Clock
	logger      *slog.Logger
}

// NewService는 Service를 만듭니다.
func NewService(pool *pgxpool.Pool, deps ServiceDeps) *Service {
	logger := deps.Logger
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Service{
		pool:        pool,
		kakao:       deps.Kakao,
		apple:       deps.Apple,
		kakaoUnlink: deps.KakaoUnlink,
		access:      deps.Access,
		box:         deps.Box,
		clock:       deps.Clock,
		logger:      logger,
	}
}

// appleGrant는 Apple code 교환으로 받은 값입니다. 탈퇴 때 revoke에 씁니다.
type appleGrant struct {
	refreshToken string
	clientID     string
}

// LoginKakao는 카카오 id_token으로 로그인합니다.
// 제공자 토큰이 틀리면 ErrProviderTokenInvalid, 제공자 장애면 ErrProviderUnavailable을 돌려줍니다.
func (s *Service) LoginKakao(ctx context.Context, idToken, rawNonce string) (LoginResult, error) {
	identity, err := s.kakao.Verify(ctx, idToken, rawNonce)
	if err != nil {
		return LoginResult{}, s.providerError(ctx, err, providerKakao, "verify")
	}
	return s.login(ctx, providerKakao, identity.Subject, nil)
}

// LoginApple은 Apple id_token과 authorization code로 로그인합니다.
// id_token을 검증한 뒤 code를 교환해 Apple refresh token을 받습니다. 교환에 실패하면 로그인도 실패하며 DB에 아무것도 남기지 않습니다.
// 받은 refresh token은 암호화해 저장하고, 이미 있는 연결이면 새 값으로 바꿉니다.
//
// 트랜잭션이 실패하면 교환한 refresh token은 저장하지 않고 버립니다. revoke는 하지 않습니다.
// Apple의 revoke는 그 사용자의 앱 승인 전체를 끊으므로, 일시적인 DB 오류나 동시 첫 로그인에서 진 경우에
// revoke하면 DB에 저장된 기존(또는 먼저 commit된) Apple 연결까지 무효가 되기 때문입니다.
func (s *Service) LoginApple(ctx context.Context, idToken, authorizationCode, rawNonce string, client provider.AppleClient) (LoginResult, error) {
	identity, err := s.apple.Verify(ctx, idToken, rawNonce, client)
	if err != nil {
		return LoginResult{}, s.providerError(ctx, err, providerApple, "verify")
	}
	refreshToken, clientID, err := s.apple.ExchangeCode(ctx, authorizationCode, client)
	if err != nil {
		return LoginResult{}, s.providerError(ctx, err, providerApple, "exchange_code")
	}
	return s.login(ctx, providerApple, identity.Subject, &appleGrant{refreshToken: refreshToken, clientID: clientID})
}

// providerError는 제공자 오류를 이 패키지의 sentinel로 바꿉니다.
// 원인 문구는 응답 경로로 넘기지 않고, 로그에는 제공자 이름과 단계만 남깁니다.
// sentinel이 아닌 오류(우리 설정 문제 등)는 원인을 감싸 그대로 돌려주어 500으로 기록되게 합니다.
func (s *Service) providerError(ctx context.Context, err error, providerName, step string) error {
	switch {
	case errors.Is(err, provider.ErrTokenInvalid):
		s.logger.InfoContext(ctx, "제공자 토큰 거절", "provider", providerName, "step", step)
		return fmt.Errorf("%w: %s %s", ErrProviderTokenInvalid, providerName, step)
	case errors.Is(err, provider.ErrUnavailable):
		s.logger.WarnContext(ctx, "제공자 장애", "provider", providerName, "step", step)
		return fmt.Errorf("%w: %s %s", ErrProviderUnavailable, providerName, step)
	default:
		return fmt.Errorf("%s %s: %w", providerName, step, err)
	}
}

// login은 로그인 트랜잭션을 실행합니다.
// 같은 (provider, subject)의 첫 로그인이 동시에 오면 한쪽이 identity insert에서 unique 위반을 받습니다.
// 그때는 트랜잭션을 처음부터 한 번 다시 실행해, 먼저 commit된 identity와 계정을 씁니다.
func (s *Service) login(ctx context.Context, providerName, subject string, apple *appleGrant) (LoginResult, error) {
	result, err := s.loginOnce(ctx, providerName, subject, apple)
	if isIdentityConflict(err) {
		result, err = s.loginOnce(ctx, providerName, subject, apple)
	}
	if err != nil {
		return LoginResult{}, fmt.Errorf("%s 로그인: %w", providerName, err)
	}
	return result, nil
}

// loginOnce는 로그인 트랜잭션 한 번입니다.
func (s *Service) loginOnce(ctx context.Context, providerName, subject string, apple *appleGrant) (LoginResult, error) {
	var result LoginResult
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 다시 실행할 수 있으므로 결과를 매번 새로 채웁니다.
		result = LoginResult{}
		q := authdb.New(tx)
		now := s.clock.Now()

		accountID, isNew, restored, err := s.findOrCreateAccount(ctx, q, now, providerName, subject, apple)
		if err != nil {
			return err
		}
		familyID, err := uuid.NewV7()
		if err != nil {
			return fmt.Errorf("family id 생성: %w", err)
		}
		tokens, err := s.issueTokens(ctx, q, now, accountID, familyID)
		if err != nil {
			return err
		}
		result = LoginResult{AccountID: accountID, Tokens: tokens, IsNewAccount: isNew, RestoredFromDeletion: restored}
		return nil
	})
	return result, err
}

// findOrCreateAccount는 (provider, subject)의 계정을 찾거나 만듭니다.
// 이미 있으면 계정 행을 잠근 채로 삭제 대기면 되살리고, Apple이면 refresh token을 새 값으로 바꿉니다.
// 되살릴 때는 같은 트랜잭션에서 그 계정의 refresh token을 모두 폐기합니다. 삭제 요청 뒤의 세션 폐기가
// 실패했더라도 삭제 전 세션이 복구와 함께 살아나지 않게 하려는 것이며, 새 family는 이 뒤에 발급합니다.
func (s *Service) findOrCreateAccount(ctx context.Context, q *authdb.Queries, now time.Time, providerName, subject string, apple *appleGrant) (accountID uuid.UUID, isNew, restored bool, err error) {
	existing, err := q.GetIdentity(ctx, authdb.GetIdentityParams{Provider: providerName, Subject: subject})
	if errors.Is(err, pgx.ErrNoRows) {
		accountID, err = s.createAccount(ctx, q, now, providerName, subject, apple)
		return accountID, true, false, err
	}
	if err != nil {
		return uuid.Nil, false, false, fmt.Errorf("identity 조회: %w", err)
	}

	if existing.AccountStatus == statusDeleted {
		// 익명화는 subject를 바꾸므로 정상이라면 여기에 오지 않습니다. 데이터가 어긋난 것이라 서버 오류로 둡니다.
		return uuid.Nil, false, false, fmt.Errorf("계정 %s: 익명화된 계정에 연결된 identity입니다", existing.AccountID)
	}

	// active 계정이면 0행, pending_deletion이면 1행이 바뀝니다. 계정 행을 잠갔으므로 그 사이 상태가 바뀌지 않습니다.
	rows, err := q.RestoreAccount(ctx, existing.AccountID)
	if err != nil {
		return uuid.Nil, false, false, fmt.Errorf("계정 복구: %w", err)
	}
	if rows == 1 {
		restored = true
		if err := q.RevokeAccountTokens(ctx, authdb.RevokeAccountTokensParams{RevokedAt: now, AccountID: existing.AccountID}); err != nil {
			return uuid.Nil, false, false, fmt.Errorf("복구 전 세션 폐기: %w", err)
		}
		if err := q.ClearProviderDisconnected(ctx, existing.AccountID); err != nil {
			return uuid.Nil, false, false, fmt.Errorf("연결 해제 기록 지우기: %w", err)
		}
		s.logger.InfoContext(ctx, "삭제 대기 계정 복구", "accountId", existing.AccountID, "provider", providerName)
	}

	if apple != nil {
		sealed, keyID, err := s.box.Seal([]byte(apple.refreshToken), existing.ID[:])
		if err != nil {
			return uuid.Nil, false, false, fmt.Errorf("apple refresh token 암호화: %w", err)
		}
		if err := q.UpdateAppleToken(ctx, authdb.UpdateAppleTokenParams{
			AppleRefreshToken: sealed,
			AppleTokenKeyID:   pgtype.Text{String: keyID, Valid: true},
			AppleClientID:     pgtype.Text{String: apple.clientID, Valid: true},
			ID:                existing.ID,
		}); err != nil {
			return uuid.Nil, false, false, fmt.Errorf("apple refresh token 저장: %w", err)
		}
	}
	return existing.AccountID, false, restored, nil
}

// createAccount는 active 계정과 identity를 새로 만듭니다.
// Apple refresh token은 identity id를 aad로 묶어 암호화하므로, id를 먼저 만들고 암호화한 뒤 insert합니다.
func (s *Service) createAccount(ctx context.Context, q *authdb.Queries, now time.Time, providerName, subject string, apple *appleGrant) (uuid.UUID, error) {
	accountID, err := uuid.NewV7()
	if err != nil {
		return uuid.Nil, fmt.Errorf("계정 id 생성: %w", err)
	}
	identityID, err := uuid.NewV7()
	if err != nil {
		return uuid.Nil, fmt.Errorf("identity id 생성: %w", err)
	}
	params := authdb.CreateIdentityParams{
		ID:        identityID,
		AccountID: accountID,
		Provider:  providerName,
		Subject:   subject,
	}
	if apple != nil {
		sealed, keyID, err := s.box.Seal([]byte(apple.refreshToken), identityID[:])
		if err != nil {
			return uuid.Nil, fmt.Errorf("apple refresh token 암호화: %w", err)
		}
		params.AppleRefreshToken = sealed
		params.AppleTokenKeyID = pgtype.Text{String: keyID, Valid: true}
		params.AppleClientID = pgtype.Text{String: apple.clientID, Valid: true}
	}

	if err := q.CreateAccount(ctx, authdb.CreateAccountParams{ID: accountID, LastActiveAt: now}); err != nil {
		return uuid.Nil, fmt.Errorf("계정 생성: %w", err)
	}
	if err := q.CreateIdentity(ctx, params); err != nil {
		return uuid.Nil, fmt.Errorf("identity 생성: %w", err)
	}
	s.logger.InfoContext(ctx, "계정 생성", "accountId", accountID, "provider", providerName)
	return accountID, nil
}

// isIdentityConflict는 err가 (provider, subject) unique 위반인지 알려 줍니다.
func isIdentityConflict(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == sqlStateUniqueViolation && pgErr.ConstraintName == identityUniqueConstraint
}

// issueTokens는 familyID에 새 refresh token을 저장하고 access token과 함께 돌려줍니다.
func (s *Service) issueTokens(ctx context.Context, q *authdb.Queries, now time.Time, accountID, familyID uuid.UUID) (TokenPair, error) {
	raw, hash, err := token.NewRefreshToken()
	if err != nil {
		return TokenPair{}, err
	}
	id, err := uuid.NewV7()
	if err != nil {
		return TokenPair{}, fmt.Errorf("refresh token id 생성: %w", err)
	}
	refreshExpiresAt := now.Add(token.RefreshTTL)
	if err := q.InsertRefreshToken(ctx, authdb.InsertRefreshTokenParams{
		ID:        id,
		AccountID: accountID,
		TokenHash: hash,
		FamilyID:  familyID,
		ExpiresAt: refreshExpiresAt,
	}); err != nil {
		return TokenPair{}, fmt.Errorf("refresh token 저장: %w", err)
	}
	access, accessExpiresAt, err := s.access.Issue(accountID)
	if err != nil {
		return TokenPair{}, fmt.Errorf("access token 발급: %w", err)
	}
	return TokenPair{
		AccessToken:      access,
		AccessExpiresAt:  accessExpiresAt,
		RefreshToken:     raw,
		RefreshExpiresAt: refreshExpiresAt,
	}, nil
}

// Refresh는 refresh token을 같은 family의 새 토큰 쌍으로 바꿉니다.
//
//   - 없음·만료·폐기·계정이 active가 아님: ErrRefreshInvalid
//   - 이미 쓴 토큰: family 전체를 폐기하고(commit까지 마친 뒤) ErrRefreshReused
//
// refresh 행을 잠그고 처리하므로, 같은 토큰으로 동시에 두 번 부르면 하나만 성공하고 다른 하나는 재사용이 됩니다.
func (s *Service) Refresh(ctx context.Context, rawRefresh string) (TokenPair, error) {
	hash := token.HashRefreshToken(rawRefresh)
	var (
		pair            TokenPair
		reused          bool
		reusedAccountID uuid.UUID
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		pair, reused, reusedAccountID = TokenPair{}, false, uuid.Nil
		q := authdb.New(tx)
		now := s.clock.Now()

		row, err := q.GetRefreshTokenForUpdate(ctx, hash)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrRefreshInvalid
		}
		if err != nil {
			return fmt.Errorf("refresh token 조회: %w", err)
		}
		if row.RevokedAt != nil || !now.Before(row.ExpiresAt) || row.AccountStatus != statusActive {
			return ErrRefreshInvalid
		}
		if row.UsedAt != nil {
			// 폐기를 남겨야 하므로 오류를 돌려주지 않고 commit합니다. 오류는 commit 뒤에 돌려줍니다.
			if err := q.RevokeFamily(ctx, authdb.RevokeFamilyParams{RevokedAt: now, FamilyID: row.FamilyID}); err != nil {
				return fmt.Errorf("family 폐기: %w", err)
			}
			reused, reusedAccountID = true, row.AccountID
			return nil
		}

		marked, err := q.MarkRefreshTokenUsed(ctx, authdb.MarkRefreshTokenUsedParams{UsedAt: now, ID: row.ID})
		if err != nil {
			return fmt.Errorf("refresh token 사용 기록: %w", err)
		}
		if marked != 1 {
			// 행을 잠근 뒤 used_at이 비어 있음을 확인했으므로 일어나지 않아야 합니다.
			return fmt.Errorf("refresh token 사용 기록: %d행이 바뀌었습니다", marked)
		}
		pair, err = s.issueTokens(ctx, q, now, row.AccountID, row.FamilyID)
		return err
	})
	if err != nil {
		if errors.Is(err, ErrRefreshInvalid) {
			return TokenPair{}, err
		}
		return TokenPair{}, fmt.Errorf("refresh: %w", err)
	}
	if reused {
		s.logger.WarnContext(ctx, "refresh token 재사용 감지, family 폐기", "accountId", reusedAccountID)
		return TokenPair{}, ErrRefreshReused
	}
	return pair, nil
}

// Logout은 refresh token이 accountID의 것이면 그 family를 폐기합니다.
// 토큰이 없거나 다른 계정의 것이어도 존재를 드러내지 않도록 nil을 돌려줍니다.
func (s *Service) Logout(ctx context.Context, accountID uuid.UUID, rawRefresh string) error {
	hash := token.HashRefreshToken(rawRefresh)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := authdb.New(tx)
		row, err := q.GetRefreshTokenForUpdate(ctx, hash)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("refresh token 조회: %w", err)
		}
		if row.AccountID != accountID {
			return nil
		}
		if err := q.RevokeFamily(ctx, authdb.RevokeFamilyParams{RevokedAt: s.clock.Now(), FamilyID: row.FamilyID}); err != nil {
			return fmt.Errorf("family 폐기: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("logout: %w", err)
	}
	return nil
}

// RevokeAllSessions는 계정의 모든 refresh token을 폐기합니다(계정 삭제 때 씀).
func (s *Service) RevokeAllSessions(ctx context.Context, accountID uuid.UUID) error {
	q := authdb.New(s.pool)
	if err := q.RevokeAccountTokens(ctx, authdb.RevokeAccountTokensParams{RevokedAt: s.clock.Now(), AccountID: accountID}); err != nil {
		return fmt.Errorf("계정 refresh token 폐기: %w", err)
	}
	return nil
}

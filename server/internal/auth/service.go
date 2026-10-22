// Package auth는 로그인, 자체 토큰 발급·갱신, 로그아웃, 제공자 연결 해제를 맡는 서비스 계층입니다.
//
// 흐름은 다음과 같습니다.
//   - 로그인: 제공자 토큰을 검증하고 (provider, subject)로 계정을 찾거나 만듭니다.
//     삭제 대기 계정이면 되살리고 그 계정의 이전 세션(refresh token)을 모두 폐기합니다. 로그인마다 새 refresh family를 만들고 토큰 쌍을 발급합니다.
//   - Apple 웹 로그인(Android): 콜백에서 제공자 검증·code 교환을 마치고 결과를 잠시 저장한 뒤 일회용 교환 코드를 주고(BeginAppleWebLogin),
//     앱이 교환 코드와 nonce 원문을 보내면 위 로그인과 같은 단계로 마칩니다(CompleteAppleWebLogin).
//   - 갱신: refresh token을 쓸 때마다 같은 family 안에서 새 토큰으로 바꿉니다(rotation).
//     이미 쓴 토큰이 다시 오면 탈취로 보고 family 전체를 폐기합니다. 단, 첫 사용 뒤 RefreshReuseGrace 안이고
//     그 다음 토큰이 아직 쓰이지 않았으면 응답 유실 재시도로 보고 새 토큰을 발급합니다(server 결정 S20).
//     이렇게 대체된 토큰이 다시 와도 탈취로 보고 family 전체를 폐기합니다.
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
	// providerLine·providerGoogle은 LINE·Google 로그인(S99)의 연결입니다. 둘 다 Apple 토큰 열이 없습니다.
	providerLine   = "line"
	providerGoogle = "google"
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

// identityLookupTimeout은 Apple 로그인 실패 뒤 연결 행을 조회할 때 주는 최대 시간입니다.
// 요청 취소와 분리한 context에서 조회하므로, DB가 응답하지 않아도 이 시간 안에 정리를 포기하게 합니다.
const identityLookupTimeout = 3 * time.Second

// RefreshReuseGrace는 이미 쓴 refresh token을 응답 유실 재시도로 보고 받아 주는 시간입니다(server 결정 S20).
// server가 갱신을 commit했지만 응답이 앱에 닿기 전에 연결이 끊기면, 앱은 예전 token으로 다시 갱신할 수밖에 없습니다.
// 첫 사용 뒤 이 시간 안(경계 포함)이고 그 다음 token이 아직 쓰이지 않았으면 탈취가 아니라 재시도로 봅니다.
const RefreshReuseGrace = 30 * time.Second

// IDTokenVerifier는 nonce가 있는 OIDC id_token을 검증합니다. *provider.Kakao·*provider.LINE·*provider.Google이 만족합니다.
type IDTokenVerifier interface {
	Verify(ctx context.Context, idToken, rawNonce string) (provider.Identity, error)
}

// KakaoVerifier는 카카오 id_token을 검증합니다. IDTokenVerifier의 다른 이름입니다.
type KakaoVerifier = IDTokenVerifier

// KakaoUnlinker는 카카오 사용자와 앱의 연결을 끊습니다. *provider.Kakao가 만족합니다.
type KakaoUnlinker interface {
	Unlink(ctx context.Context, subject string) error
}

// AppleClient는 Apple id_token 검증(웹 콜백용 nonce 없는 검증 포함), authorization code 교환, refresh token revoke를 합니다. *provider.Apple이 만족합니다.
// (provider.AppleClient는 native·web 구분 값이고, 이 인터페이스는 Apple API 호출자입니다.)
type AppleClient interface {
	Verify(ctx context.Context, idToken, rawNonce string, client provider.AppleClient) (provider.Identity, error)
	VerifyWebCallback(ctx context.Context, idToken string) (identity provider.Identity, nonceClaim string, err error)
	ExchangeCode(ctx context.Context, code string, client provider.AppleClient, wantSubject string) (refreshToken, clientID string, err error)
	Revoke(ctx context.Context, refreshToken, clientID string) error
}

// ServiceDeps는 Service가 쓰는 의존성입니다. Logger는 nil이면 아무것도 남기지 않습니다.
type ServiceDeps struct {
	Kakao  KakaoVerifier
	Line   IDTokenVerifier
	Google IDTokenVerifier
	Apple  AppleClient
	Access *token.AccessIssuer
	Box    *secretbox.Box
	Clock  clock.Clock
	Logger *slog.Logger
	// Revoker는 떼기(UnlinkIdentity)가 commit한 뒤 허가 취소 대기 행을 시도합니다. nil이면 시도하지 않고
	// 대기 행이 job retention의 재시도를 기다립니다. *Revocations가 만족합니다.
	Revoker RevocationAttempter
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
	pool    *pgxpool.Pool
	kakao   KakaoVerifier
	line    IDTokenVerifier
	google  IDTokenVerifier
	apple   AppleClient
	access  *token.AccessIssuer
	box     *secretbox.Box
	clock   clock.Clock
	logger  *slog.Logger
	revoker RevocationAttempter
}

// NewService는 Service를 만듭니다.
func NewService(pool *pgxpool.Pool, deps ServiceDeps) *Service {
	logger := deps.Logger
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Service{
		pool:    pool,
		kakao:   deps.Kakao,
		line:    deps.Line,
		google:  deps.Google,
		apple:   deps.Apple,
		access:  deps.Access,
		box:     deps.Box,
		clock:   deps.Clock,
		logger:  logger,
		revoker: deps.Revoker,
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
	return s.login(ctx, providerKakao, fixedTarget(identity.Subject, nil))
}

// LoginLine은 LINE id_token으로 로그인합니다. 흐름과 오류는 LoginKakao와 같습니다.
func (s *Service) LoginLine(ctx context.Context, idToken, rawNonce string) (LoginResult, error) {
	identity, err := s.line.Verify(ctx, idToken, rawNonce)
	if err != nil {
		return LoginResult{}, s.providerError(ctx, err, providerLine, "verify")
	}
	return s.login(ctx, providerLine, fixedTarget(identity.Subject, nil))
}

// LoginGoogle은 Google id_token으로 로그인합니다. 흐름과 오류는 LoginKakao와 같습니다.
func (s *Service) LoginGoogle(ctx context.Context, idToken, rawNonce string) (LoginResult, error) {
	identity, err := s.google.Verify(ctx, idToken, rawNonce)
	if err != nil {
		return LoginResult{}, s.providerError(ctx, err, providerGoogle, "verify")
	}
	return s.login(ctx, providerGoogle, fixedTarget(identity.Subject, nil))
}

// LoginApple은 iOS 앱이 받은 Apple id_token과 authorization code로 로그인합니다.
// Apple client_id는 앱 BundleID(provider.AppleNative)로 고정합니다. Android의 웹 로그인은 BeginAppleWebLogin·CompleteAppleWebLogin입니다.
// id_token을 검증한 뒤 code를 교환해 Apple refresh token을 받습니다. 교환 응답의 id_token sub가 로그인 id_token의
// sub와 다르면 ErrProviderTokenInvalid입니다. 교환에 실패하면 로그인도 실패하며 DB에 아무것도 남기지 않습니다.
// 받은 refresh token은 암호화해 저장하고, 이미 있는 연결이면 새 값으로 바꿉니다.
//
// 로그인 트랜잭션이 실패하면 교환한 refresh token은 저장하지 않습니다. 그 subject의 연결 행이 없을 때만
// revoke해, 처음 로그인하다 실패한 사용자의 Apple 설정 목록(Sign in with Apple)에 앱이 남지 않게 합니다.
// 연결 행이 있으면(기존 사용자의 일시 오류, 동시 첫 로그인에서 먼저 commit된 연결, 익명화된 계정 등) revoke하지 않습니다.
// Apple의 revoke는 그 사용자의 앱 승인 전체를 끊어 저장된 연결까지 무효로 만들기 때문입니다.
// 연결 행 조회나 revoke가 실패해도 원래 로그인 오류를 그대로 돌려줍니다(revokeUnsavedAppleGrant).
func (s *Service) LoginApple(ctx context.Context, idToken, authorizationCode, rawNonce string) (LoginResult, error) {
	subject, grant, err := s.verifyAppleNative(ctx, idToken, authorizationCode, rawNonce)
	if err != nil {
		return LoginResult{}, err
	}
	result, err := s.login(ctx, providerApple, fixedTarget(subject, grant))
	if err != nil {
		s.revokeUnsavedAppleGrant(ctx, subject, grant)
		return LoginResult{}, err
	}
	return result, nil
}

// verifyAppleNative는 iOS 앱의 Apple id_token을 앱 BundleID(provider.AppleNative)로 검증하고 code를 교환해,
// subject와 교환한 grant를 돌려줍니다. 교환 응답의 sub가 id_token의 sub와 다르면 ErrProviderTokenInvalid입니다.
// 로그인(LoginApple)과 iOS Apple 붙이기(LinkIdentity)가 씁니다.
func (s *Service) verifyAppleNative(ctx context.Context, idToken, authorizationCode, rawNonce string) (string, *appleGrant, error) {
	identity, err := s.apple.Verify(ctx, idToken, rawNonce, provider.AppleNative)
	if err != nil {
		return "", nil, s.providerError(ctx, err, providerApple, "verify")
	}
	refreshToken, clientID, err := s.apple.ExchangeCode(ctx, authorizationCode, provider.AppleNative, identity.Subject)
	if err != nil {
		return "", nil, s.providerError(ctx, err, providerApple, "exchange_code")
	}
	return identity.Subject, &appleGrant{refreshToken: refreshToken, clientID: clientID}, nil
}

// revokeUnsavedAppleGrant는 로그인 트랜잭션이 실패해 저장하지 못한 Apple refresh token을, 그 subject의 연결 행이
// 없을 때만 revoke합니다. 결과는 로그로만 남기고 호출자에게 돌려주지 않습니다.
//
// 연결 행 조회는 트랜잭션 밖의 잠금 없는 조회이며 identityLookupTimeout 안에 끝나야 합니다.
// 조회가 실패하거나 시간을 넘기면 revoke하지 않습니다.
// 잘못 끊어 기존 연결을 무효로 만드는 것보다 Apple 목록에 앱이 남는 쪽이 덜 해롭기 때문입니다.
// 요청이 취소된 뒤에도 정리를 마치도록 context의 취소는 떼어 내지만, provider 호출 자체의 deadline은 그대로 걸립니다.
func (s *Service) revokeUnsavedAppleGrant(ctx context.Context, subject string, grant *appleGrant) {
	ctx = context.WithoutCancel(ctx)
	lookupCtx, cancel := context.WithTimeout(ctx, identityLookupTimeout)
	defer cancel()
	exists, err := authdb.New(s.pool).IdentityExists(lookupCtx, authdb.IdentityExistsParams{Provider: providerApple, Subject: subject})
	if err != nil {
		s.logger.WarnContext(ctx, "Apple 연결 행 조회 실패, 교환한 토큰을 revoke하지 않음", "provider", providerApple, "step", "identity_exists")
		return
	}
	if exists {
		return
	}
	if err := s.apple.Revoke(ctx, grant.refreshToken, grant.clientID); err != nil {
		s.logger.WarnContext(ctx, "저장하지 못한 Apple 토큰 revoke 실패", "provider", providerApple, "step", "revoke_unsaved")
		return
	}
	s.logger.InfoContext(ctx, "저장하지 못한 Apple 토큰 revoke", "provider", providerApple, "step", "revoke_unsaved")
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

// loginTarget은 로그인 트랜잭션이 찾거나 만들 연결입니다. apple은 Apple 로그인일 때만 있습니다.
type loginTarget struct {
	subject string
	apple   *appleGrant
}

// prepareLogin은 로그인 트랜잭션 첫머리에서 같은 트랜잭션(q)으로 실행해 로그인할 연결을 정합니다.
// 오류를 돌려주면 트랜잭션 전체가 rollback되므로, 여기서 바꾼 행(예: 교환 코드 소진)도 함께 되돌아갑니다.
// 트랜잭션이 다시 실행될 수 있으므로 여러 번 불려도 결과가 같아야 합니다.
type prepareLogin func(ctx context.Context, q *authdb.Queries, now time.Time) (loginTarget, error)

// fixedTarget은 트랜잭션 전에 이미 정해진 연결로 로그인하는 prepareLogin입니다(카카오·iOS Apple).
func fixedTarget(subject string, apple *appleGrant) prepareLogin {
	return func(context.Context, *authdb.Queries, time.Time) (loginTarget, error) {
		return loginTarget{subject: subject, apple: apple}, nil
	}
}

// login은 로그인 트랜잭션을 실행합니다.
// 같은 (provider, subject)의 첫 로그인이 동시에 오면 한쪽이 identity insert에서 unique 위반을 받습니다.
// 그때는 트랜잭션을 처음부터(prepare 포함) 한 번 다시 실행해, 먼저 commit된 identity와 계정을 씁니다.
func (s *Service) login(ctx context.Context, providerName string, prepare prepareLogin) (LoginResult, error) {
	result, err := s.loginOnce(ctx, providerName, prepare)
	if isIdentityConflict(err) {
		result, err = s.loginOnce(ctx, providerName, prepare)
	}
	if err != nil {
		return LoginResult{}, fmt.Errorf("%s 로그인: %w", providerName, err)
	}
	return result, nil
}

// loginOnce는 로그인 트랜잭션 한 번입니다. prepare로 연결을 정한 뒤 계정을 찾거나 만들고 토큰을 발급합니다.
func (s *Service) loginOnce(ctx context.Context, providerName string, prepare prepareLogin) (LoginResult, error) {
	var result LoginResult
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 다시 실행할 수 있으므로 결과를 매번 새로 채웁니다.
		result = LoginResult{}
		q := authdb.New(tx)
		now := s.clock.Now()

		target, err := prepare(ctx, q, now)
		if err != nil {
			return err
		}
		accountID, isNew, restored, err := s.findOrCreateAccount(ctx, q, now, providerName, target.subject, target.apple)
		if err != nil {
			return err
		}
		familyID, err := uuid.NewV7()
		if err != nil {
			return fmt.Errorf("family id 생성: %w", err)
		}
		tokens, _, err := s.issueTokens(ctx, q, now, accountID, familyID)
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
		s.logger.InfoContext(ctx, "삭제 대기 계정 복구", "accountId", existing.AccountID, "provider", providerName)
	}

	if apple != nil {
		if err := s.saveAppleGrant(ctx, q, existing.ID, apple); err != nil {
			return uuid.Nil, false, false, err
		}
	}
	return existing.AccountID, false, restored, nil
}

// saveAppleGrant는 이미 있는 Apple 연결의 refresh token을 새 값으로 바꿉니다. 연결 id를 aad로 묶어 암호화합니다.
func (s *Service) saveAppleGrant(ctx context.Context, q *authdb.Queries, identityID uuid.UUID, apple *appleGrant) error {
	sealed, keyID, err := s.box.Seal([]byte(apple.refreshToken), identityID[:])
	if err != nil {
		return fmt.Errorf("apple refresh token 암호화: %w", err)
	}
	if err := q.UpdateAppleToken(ctx, authdb.UpdateAppleTokenParams{
		AppleRefreshToken: sealed,
		AppleTokenKeyID:   pgtype.Text{String: keyID, Valid: true},
		AppleClientID:     pgtype.Text{String: apple.clientID, Valid: true},
		ID:                identityID,
	}); err != nil {
		return fmt.Errorf("apple refresh token 저장: %w", err)
	}
	return nil
}

// createAccount는 active 계정과 identity를 새로 만듭니다.
// Apple refresh token은 identity id를 aad로 묶어 암호화합니다(newIdentityParams).
func (s *Service) createAccount(ctx context.Context, q *authdb.Queries, now time.Time, providerName, subject string, apple *appleGrant) (uuid.UUID, error) {
	accountID, err := uuid.NewV7()
	if err != nil {
		return uuid.Nil, fmt.Errorf("계정 id 생성: %w", err)
	}
	params, err := s.newIdentityParams(accountID, providerName, subject, apple)
	if err != nil {
		return uuid.Nil, err
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

// newIdentityParams는 새 연결 행의 insert 값을 만듭니다. 로그인의 계정 생성과 붙이기가 씁니다.
// Apple refresh token은 identity id를 aad로 묶어 암호화하므로, id를 먼저 만들고 암호화합니다.
func (s *Service) newIdentityParams(accountID uuid.UUID, providerName, subject string, apple *appleGrant) (authdb.CreateIdentityParams, error) {
	identityID, err := uuid.NewV7()
	if err != nil {
		return authdb.CreateIdentityParams{}, fmt.Errorf("identity id 생성: %w", err)
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
			return authdb.CreateIdentityParams{}, fmt.Errorf("apple refresh token 암호화: %w", err)
		}
		params.AppleRefreshToken = sealed
		params.AppleTokenKeyID = pgtype.Text{String: keyID, Valid: true}
		params.AppleClientID = pgtype.Text{String: apple.clientID, Valid: true}
	}
	return params, nil
}

// isIdentityConflict는 err가 (provider, subject) unique 위반인지 알려 줍니다.
func isIdentityConflict(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == sqlStateUniqueViolation && pgErr.ConstraintName == identityUniqueConstraint
}

// issueTokens는 familyID에 새 refresh token을 저장하고 access token과 함께 돌려줍니다.
// 저장한 refresh token의 id도 돌려줍니다. 갱신 때 앞 토큰의 replaced_by_id로 기록합니다.
func (s *Service) issueTokens(ctx context.Context, q *authdb.Queries, now time.Time, accountID, familyID uuid.UUID) (TokenPair, uuid.UUID, error) {
	raw, hash, err := token.NewRefreshToken()
	if err != nil {
		return TokenPair{}, uuid.Nil, err
	}
	id, err := uuid.NewV7()
	if err != nil {
		return TokenPair{}, uuid.Nil, fmt.Errorf("refresh token id 생성: %w", err)
	}
	// DB(timestamptz)는 마이크로초 정밀도로 저장하므로, 응답 값도 같은 정밀도로 맞춰 DB 값과 일치시킵니다.
	refreshExpiresAt := now.Add(token.RefreshTTL).Truncate(time.Microsecond)
	if err := q.InsertRefreshToken(ctx, authdb.InsertRefreshTokenParams{
		ID:        id,
		AccountID: accountID,
		TokenHash: hash,
		FamilyID:  familyID,
		ExpiresAt: refreshExpiresAt,
	}); err != nil {
		return TokenPair{}, uuid.Nil, fmt.Errorf("refresh token 저장: %w", err)
	}
	access, accessExpiresAt, err := s.access.Issue(accountID)
	if err != nil {
		return TokenPair{}, uuid.Nil, fmt.Errorf("access token 발급: %w", err)
	}
	return TokenPair{
		AccessToken:      access,
		AccessExpiresAt:  accessExpiresAt,
		RefreshToken:     raw,
		RefreshExpiresAt: refreshExpiresAt,
	}, id, nil
}

// Refresh는 refresh token을 같은 family의 새 토큰 쌍으로 바꿉니다.
//
//   - 없음·만료·폐기·계정이 active가 아님: ErrRefreshInvalid
//   - 이미 쓴 토큰이 첫 사용 뒤 RefreshReuseGrace 안(경계 포함)에 다시 왔고 그 다음 토큰이 아직 미사용·미폐기:
//     응답 유실 재시도로 봅니다. 다음 토큰을 폐기하고 같은 family로 새 토큰 쌍을 줍니다(retryLostResponse).
//   - 그 밖에 이미 쓴 토큰: family 전체를 폐기하고(commit까지 마친 뒤) ErrRefreshReused
//   - 유예 처리로 대체되어 폐기된 토큰(family에 아직 살아 있는 토큰이 있음): 같은 방식으로 family 폐기 후 ErrRefreshReused
//
// refresh 행을 잠그고 처리하므로, 같은 토큰으로 동시에 두 번 부르면 한쪽이 정상 갱신한 뒤
// 다른 쪽이 잠금을 기다렸다가 유예 처리됩니다. 둘 다 성공하지만 살아 남는 토큰은 나중 쪽 하나이며,
// 먼저 받은 쪽 토큰을 다시 쓰면 재사용으로 family가 폐기됩니다. 그래서 앱은 갱신을 한 번에 하나만 보내야 합니다.
func (s *Service) Refresh(ctx context.Context, rawRefresh string) (TokenPair, error) {
	hash := token.HashRefreshToken(rawRefresh)
	var (
		pair      TokenPair
		reused    bool
		retried   bool
		accountID uuid.UUID
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		pair, reused, retried, accountID = TokenPair{}, false, false, uuid.Nil
		q := authdb.New(tx)
		now := s.clock.Now()

		row, err := q.GetRefreshTokenForUpdate(ctx, hash)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrRefreshInvalid
		}
		if err != nil {
			return fmt.Errorf("refresh token 조회: %w", err)
		}
		accountID = row.AccountID
		if row.RevokedAt != nil {
			// 로그아웃·재사용 감지·계정 단위 폐기는 family 전체를 폐기하므로, 폐기된 토큰의 family에
			// 아직 살아 있는 토큰이 있다면 그 토큰은 유예 처리로 대체된 것입니다(retryLostResponse).
			// 대체된 토큰이 다시 온다는 것은 그것을 받은 쪽이 따로 있었다는 뜻이므로 탈취로 봅니다.
			// 이를 막지 않으면 유예 창에 끼어든 쪽이 토큰을 계속 회전시키며 세션을 유지할 수 있습니다.
			revoked, err := q.RevokeFamily(ctx, authdb.RevokeFamilyParams{RevokedAt: now, FamilyID: row.FamilyID})
			if err != nil {
				return fmt.Errorf("family 폐기: %w", err)
			}
			if revoked == 0 {
				return ErrRefreshInvalid
			}
			// 폐기를 남겨야 하므로 오류를 돌려주지 않고 commit합니다. 오류는 commit 뒤에 돌려줍니다.
			reused = true
			return nil
		}
		if !now.Before(row.ExpiresAt) || row.AccountStatus != statusActive {
			return ErrRefreshInvalid
		}
		if row.UsedAt != nil {
			retryPair, ok, err := s.retryLostResponse(ctx, q, now, row)
			if err != nil {
				return err
			}
			if ok {
				pair, retried = retryPair, true
				return nil
			}
			// 폐기를 남겨야 하므로 오류를 돌려주지 않고 commit합니다. 오류는 commit 뒤에 돌려줍니다.
			if _, err := q.RevokeFamily(ctx, authdb.RevokeFamilyParams{RevokedAt: now, FamilyID: row.FamilyID}); err != nil {
				return fmt.Errorf("family 폐기: %w", err)
			}
			reused = true
			return nil
		}

		// replaced_by_id 외래 키 때문에 다음 토큰을 먼저 저장하고 나서 사용을 기록합니다.
		var nextID uuid.UUID
		pair, nextID, err = s.issueTokens(ctx, q, now, row.AccountID, row.FamilyID)
		if err != nil {
			return err
		}
		marked, err := q.MarkRefreshTokenUsed(ctx, authdb.MarkRefreshTokenUsedParams{UsedAt: now, ReplacedByID: nextID, ID: row.ID})
		if err != nil {
			return fmt.Errorf("refresh token 사용 기록: %w", err)
		}
		if marked != 1 {
			// 행을 잠근 뒤 used_at이 비어 있음을 확인했으므로 일어나지 않아야 합니다.
			return fmt.Errorf("refresh token 사용 기록: %d행이 바뀌었습니다", marked)
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrRefreshInvalid) {
			return TokenPair{}, err
		}
		return TokenPair{}, fmt.Errorf("refresh: %w", err)
	}
	if reused {
		s.logger.WarnContext(ctx, "refresh token 재사용 감지, family 폐기", "accountId", accountID)
		return TokenPair{}, ErrRefreshReused
	}
	if retried {
		s.logger.InfoContext(ctx, "refresh token 유예 시간 안 재전송, 새 토큰 발급", "accountId", accountID)
	}
	return pair, nil
}

// retryLostResponse는 이미 쓴 토큰(used)의 재전송이 응답 유실 재시도인지 보고, 맞으면 새 토큰 쌍을 발급합니다.
// 재시도가 아니면 ok=false를 돌려주고 아무것도 바꾸지 않습니다. used 행은 호출자가 잠근 상태여야 합니다.
//
// 재시도의 조건은 첫 사용 뒤 RefreshReuseGrace 안(경계 포함)이고, 그 다음 토큰이 아직 미사용·미폐기인 것입니다.
// 다음 토큰을 잠그고 조건을 확인한 뒤 폐기하고, 같은 family로 새 토큰을 발급해 used의 replaced_by_id로 기록합니다.
// used_at은 바꾸지 않으므로 유예 창은 첫 사용 시각을 기준으로 늘어나지 않습니다.
func (s *Service) retryLostResponse(ctx context.Context, q *authdb.Queries, now time.Time, used authdb.GetRefreshTokenForUpdateRow) (TokenPair, bool, error) {
	if used.UsedAt == nil || !used.ReplacedByID.Valid || now.Sub(*used.UsedAt) > RefreshReuseGrace {
		return TokenPair{}, false, nil
	}
	next, err := q.GetRefreshTokenByIDForUpdate(ctx, used.ReplacedByID.UUID)
	if err != nil {
		return TokenPair{}, false, fmt.Errorf("다음 refresh token 조회: %w", err)
	}
	if next.UsedAt != nil || next.RevokedAt != nil {
		return TokenPair{}, false, nil
	}
	revoked, err := q.RevokeRefreshToken(ctx, authdb.RevokeRefreshTokenParams{RevokedAt: now, ID: next.ID})
	if err != nil {
		return TokenPair{}, false, fmt.Errorf("다음 refresh token 폐기: %w", err)
	}
	if revoked != 1 {
		// 행을 잠근 뒤 revoked_at이 비어 있음을 확인했으므로 일어나지 않아야 합니다.
		return TokenPair{}, false, fmt.Errorf("다음 refresh token 폐기: %d행이 바뀌었습니다", revoked)
	}
	pair, newID, err := s.issueTokens(ctx, q, now, used.AccountID, used.FamilyID)
	if err != nil {
		return TokenPair{}, false, err
	}
	replaced, err := q.SetRefreshTokenReplacedBy(ctx, authdb.SetRefreshTokenReplacedByParams{ReplacedByID: newID, ID: used.ID})
	if err != nil {
		return TokenPair{}, false, fmt.Errorf("다음 refresh token 기록: %w", err)
	}
	if replaced != 1 {
		return TokenPair{}, false, fmt.Errorf("다음 refresh token 기록: %d행이 바뀌었습니다", replaced)
	}
	return pair, true, nil
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
		if _, err := q.RevokeFamily(ctx, authdb.RevokeFamilyParams{RevokedAt: s.clock.Now(), FamilyID: row.FamilyID}); err != nil {
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

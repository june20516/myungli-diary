package auth

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
)

// AppleWebExchangeTTL은 Apple 웹 로그인 교환 코드의 수명입니다.
// 콜백이 앱을 다시 열고 앱이 곧바로 완료를 부르는 데 걸리는 시간이면 충분하므로 짧게 둡니다.
const AppleWebExchangeTTL = 2 * time.Minute

// nonceHashPattern은 id_token nonce claim이 가져야 할 모양(SHA-256 소문자 hex)입니다.
// 앱은 nonce 원문의 hex(sha256)를 Apple에 넘기므로(S15) 정상 흐름이면 항상 이 모양이고,
// DB도 같은 CHECK로 막습니다. 다른 모양이면 비교할 수 없는 토큰이므로 제공자 토큰 오류로 봅니다.
var nonceHashPattern = regexp.MustCompile(`^[0-9a-f]{64}$`)

// BeginAppleWebLogin은 Apple 웹 콜백(Android)에서 받은 id_token과 authorization code로 로그인을 시작합니다.
//
// id_token을 web client(ServicesID)로 검증하고(nonce 원문은 아직 모르므로 claim만 받아 둡니다), code를 교환해
// Apple refresh token을 받습니다. 그 결과를 apple_web_logins에 AppleWebExchangeTTL 동안 저장하고, 앱이 완료에 쓸
// 일회용 교환 코드(256비트 난수 base64url)를 돌려줍니다. DB에는 교환 코드의 SHA-256만 두고, refresh token은
// 행 id를 aad로 묶어 암호화합니다. 계정은 아직 만들지 않습니다(CompleteAppleWebLogin에서 만듭니다).
//
// 제공자 토큰이 틀리면 ErrProviderTokenInvalid, 제공자 장애면 ErrProviderUnavailable을 돌려줍니다.
//
// code 교환 뒤 저장까지 가지 못하면 교환한 refresh token은 어디에도 남지 않습니다. 그때는 LoginApple과 같은
// 규칙(server 결정 S19)으로, 그 subject의 연결 행이 없을 때만 revoke하고 원래 오류를 그대로 돌려줍니다(revokeUnsavedAppleGrant).
func (s *Service) BeginAppleWebLogin(ctx context.Context, idToken, authorizationCode string) (string, error) {
	identity, nonceClaim, err := s.apple.VerifyWebCallback(ctx, idToken)
	if err != nil {
		return "", s.providerError(ctx, err, providerApple, "verify_web")
	}
	if !nonceHashPattern.MatchString(nonceClaim) {
		return "", s.providerError(ctx, fmt.Errorf("%w: nonce claim 모양이 다릅니다", provider.ErrTokenInvalid), providerApple, "verify_web")
	}
	refreshToken, clientID, err := s.apple.ExchangeCode(ctx, authorizationCode, provider.AppleWeb, identity.Subject)
	if err != nil {
		return "", s.providerError(ctx, err, providerApple, "exchange_code")
	}
	grant := &appleGrant{refreshToken: refreshToken, clientID: clientID}
	exchangeCode, err := s.storeAppleWebLogin(ctx, identity.Subject, nonceClaim, grant)
	if err != nil {
		s.revokeUnsavedAppleGrant(ctx, identity.Subject, grant)
		return "", err
	}
	return exchangeCode, nil
}

// storeAppleWebLogin은 교환 결과를 apple_web_logins에 저장하고 일회용 교환 코드를 돌려줍니다.
func (s *Service) storeAppleWebLogin(ctx context.Context, subject, nonceClaim string, grant *appleGrant) (string, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return "", fmt.Errorf("apple 웹 로그인 id 생성: %w", err)
	}
	sealed, keyID, err := s.box.Seal([]byte(grant.refreshToken), id[:])
	if err != nil {
		return "", fmt.Errorf("apple refresh token 암호화: %w", err)
	}
	// 교환 코드는 refresh token과 같은 방식(256비트 난수 base64url, SHA-256 저장)으로 만듭니다.
	exchangeCode, exchangeHash, err := token.NewRefreshToken()
	if err != nil {
		return "", fmt.Errorf("교환 코드 생성: %w", err)
	}
	// DB(timestamptz)의 마이크로초 정밀도에 맞춰, 저장한 만료 시각과 비교 시각이 어긋나지 않게 합니다.
	expiresAt := s.clock.Now().Add(AppleWebExchangeTTL).Truncate(time.Microsecond)
	if err := authdb.New(s.pool).InsertAppleWebLogin(ctx, authdb.InsertAppleWebLoginParams{
		ID:                id,
		ExchangeHash:      exchangeHash,
		Subject:           subject,
		NonceHash:         nonceClaim,
		AppleRefreshToken: sealed,
		AppleTokenKeyID:   keyID,
		AppleClientID:     grant.clientID,
		ExpiresAt:         expiresAt,
	}); err != nil {
		return "", fmt.Errorf("apple 웹 로그인 저장: %w", err)
	}
	return exchangeCode, nil
}

// CompleteAppleWebLogin은 BeginAppleWebLogin이 준 교환 코드와 앱이 가진 nonce 원문으로 로그인을 마칩니다.
//
// 교환 코드 행을 잠그고 확인하는 일, 계정 찾기·만들기·복구, Apple refresh token 저장, 토큰 발급, 교환 코드 소진을
// 모두 한 트랜잭션에서 합니다. 그래서
//   - 같은 코드로 동시에 부르면 행 잠금 때문에 한쪽만 성공하고 다른 쪽은 ErrExchangeInvalid입니다.
//   - 트랜잭션이 실패하면 소진도 되돌아가므로, 같은 코드로 (만료 전까지) 다시 시도할 수 있습니다.
//     교환한 Apple 토큰은 그 행에 그대로 남아 있으므로 revoke하지 않습니다.
//
// 코드가 없거나 만료됐거나(now >= expires_at) 이미 쓰였거나 hex(sha256(rawNonce))가 id_token의 nonce claim과
// 다르면 ErrExchangeInvalid입니다. nonce가 틀려도 코드를 소진하지 않습니다. 소진하면 코드를 가로챈 쪽이 틀린
// nonce로 한 번 부르는 것만으로 정상 사용자의 로그인을 막을 수 있기 때문입니다.
func (s *Service) CompleteAppleWebLogin(ctx context.Context, exchangeCode, rawNonce string) (LoginResult, error) {
	exchangeHash := token.HashRefreshToken(exchangeCode)
	prepare := func(ctx context.Context, q *authdb.Queries, now time.Time) (loginTarget, error) {
		return s.consumeAppleWebLogin(ctx, q, now, exchangeHash, rawNonce)
	}
	result, err := s.login(ctx, providerApple, prepare)
	if err != nil {
		if errors.Is(err, ErrExchangeInvalid) {
			s.logger.InfoContext(ctx, "Apple 웹 로그인 교환 코드 거절", "provider", providerApple, "step", "complete_web")
			return LoginResult{}, ErrExchangeInvalid
		}
		return LoginResult{}, err
	}
	return result, nil
}

// consumeAppleWebLogin은 로그인 트랜잭션 안에서 교환 코드 행을 잠그고 확인한 뒤 소진하고, 로그인할 연결을 돌려줍니다.
//
// 확인 순서는 존재 → 소진 여부 → 만료 → nonce입니다. 만료 행은 소진할 수 없으므로(CHECK consumed_at <= expires_at)
// 만료를 먼저 거릅니다. nonce가 틀리면 소진하기 전에 돌아가므로 행이 그대로 남습니다.
// 소진은 계정·토큰 처리보다 먼저 하지만 같은 트랜잭션이라, 뒤 단계가 실패하면 함께 rollback됩니다.
func (s *Service) consumeAppleWebLogin(ctx context.Context, q *authdb.Queries, now time.Time, exchangeHash []byte, rawNonce string) (loginTarget, error) {
	row, err := q.GetAppleWebLoginForUpdate(ctx, exchangeHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return loginTarget{}, ErrExchangeInvalid
	}
	if err != nil {
		return loginTarget{}, fmt.Errorf("apple 웹 로그인 조회: %w", err)
	}
	if row.ConsumedAt != nil || !now.Before(row.ExpiresAt) {
		return loginTarget{}, ErrExchangeInvalid
	}
	if !nonceHashMatches(row.NonceHash, rawNonce) {
		return loginTarget{}, ErrExchangeInvalid
	}

	refreshToken, err := s.box.Open(row.AppleRefreshToken, row.AppleTokenKeyID, row.ID[:])
	if err != nil {
		return loginTarget{}, fmt.Errorf("apple refresh token 복호화: %w", err)
	}
	consumed, err := q.ConsumeAppleWebLogin(ctx, authdb.ConsumeAppleWebLoginParams{ConsumedAt: now, ID: row.ID})
	if err != nil {
		return loginTarget{}, fmt.Errorf("apple 웹 로그인 소진: %w", err)
	}
	if consumed != 1 {
		// 행을 잠근 뒤 consumed_at이 비어 있음을 확인했으므로 일어나지 않아야 하지만, 일어나면 이미 쓴 코드로 봅니다.
		return loginTarget{}, ErrExchangeInvalid
	}
	return loginTarget{
		subject: row.Subject,
		apple:   &appleGrant{refreshToken: string(refreshToken), clientID: row.AppleClientID},
	}, nil
}

// nonceHashMatches는 저장한 nonce claim이 hex(sha256(rawNonce))와 같은지 상수 시간으로 비교합니다.
// 어느 쪽이든 비어 있으면 비교할 값이 없는 것이므로 불일치로 봅니다.
func nonceHashMatches(nonceHash, rawNonce string) bool {
	if rawNonce == "" || nonceHash == "" {
		return false
	}
	sum := sha256.Sum256([]byte(rawNonce))
	want := hex.EncodeToString(sum[:])
	return subtle.ConstantTimeCompare([]byte(want), []byte(nonceHash)) == 1
}

package provider

import (
	"context"
	"fmt"
	"net/http"
	"slices"

	"github.com/coreos/go-oidc/v3/oidc"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// DefaultGoogleJWKSURL은 Google 공개 키(JWKS) 기본 URL입니다.
const DefaultGoogleJWKSURL = "https://www.googleapis.com/oauth2/v3/certs"

// GoogleIssuers는 Google이 id_token의 iss로 쓰는 두 표기입니다. 둘 다 받습니다.
var GoogleIssuers = []string{"https://accounts.google.com", "accounts.google.com"}

// GoogleConfig는 Google 로그인 연동 설정입니다. 빈 JWKSURL은 DefaultGoogleJWKSURL을 씁니다.
type GoogleConfig struct {
	// ClientIDs는 id_token의 aud로 받는 OAuth client ID 목록입니다(iOS·Android·web 등 플랫폼별).
	ClientIDs []string

	JWKSURL string

	// HTTP는 Google로 나가는 모든 호출에 쓰는 client입니다. nil이면 새 기본 client를 씁니다.
	HTTP *http.Client
	// Clock은 id_token exp 판정에 쓰는 시계입니다. nil이면 clock.System을 씁니다.
	Clock clock.Clock
}

// Google은 Google id_token 검증을 맡습니다. 여러 고루틴에서 함께 써도 안전합니다.
type Google struct {
	verifier  *oidc.IDTokenVerifier
	clientIDs []string
}

// NewGoogle은 cfg로 Google을 만듭니다. ClientIDs가 비면 오류입니다.
// JWKS는 첫 검증 때 받아 오고 이후 캐시합니다.
func NewGoogle(cfg GoogleConfig) (*Google, error) {
	if err := checkRequired("Google", requiredField{"ClientIDs", len(cfg.ClientIDs) == 0}); err != nil {
		return nil, err
	}
	keySet := newKeySet(orDefaultClient(cfg.HTTP), orDefault(cfg.JWKSURL, DefaultGoogleJWKSURL))

	// iss가 두 표기이고 aud가 여러 개라 go-oidc의 단일 값 검사는 끄고, 서명·exp만 맡깁니다. iss·aud는 Verify가 직접 봅니다.
	verifier := oidc.NewVerifier("", keySet, &oidc.Config{
		SkipClientIDCheck:    true,
		SkipIssuerCheck:      true,
		SupportedSigningAlgs: []string{oidc.RS256},
		Now:                  orDefaultClock(cfg.Clock).Now,
	})
	return &Google{verifier: verifier, clientIDs: slices.Clone(cfg.ClientIDs)}, nil
}

// authorizedParty는 id_token의 azp claim을 돌려줍니다. 없거나 문자열이 아니면 빈 문자열입니다.
func authorizedParty(token *oidc.IDToken) string {
	var claims struct {
		AZP string `json:"azp"`
	}
	if err := token.Claims(&claims); err != nil {
		return ""
	}
	return claims.AZP
}

// Verify는 Google id_token을 검증합니다.
// iss(두 표기 중 하나), aud(ClientIDs 중 하나), exp, RS256 서명, nonce(hex(sha256(rawNonce)))를 확인합니다.
// aud가 둘 이상이면 azp claim이 있고 ClientIDs 안에 있어야 합니다(OIDC Core 3.1.3.7).
// Android token은 azp가 Android client ID이므로, aud가 여럿인 토큰을 받으려면 그 ID도 GOOGLE_CLIENT_IDS에 넣어야 합니다.
func (g *Google) Verify(ctx context.Context, idToken, rawNonce string) (Identity, error) {
	const name = "Google id_token"
	token, err := verifyIDTokenClaims(ctx, g.verifier, name, idToken)
	if err != nil {
		return Identity{}, err
	}
	if !slices.Contains(GoogleIssuers, token.Issuer) {
		return Identity{}, fmt.Errorf("%w: %s: iss 불일치", ErrTokenInvalid, name)
	}
	if !slices.ContainsFunc(token.Audience, func(aud string) bool { return slices.Contains(g.clientIDs, aud) }) {
		return Identity{}, fmt.Errorf("%w: %s: aud 불일치", ErrTokenInvalid, name)
	}
	if len(token.Audience) > 1 && !slices.Contains(g.clientIDs, authorizedParty(token)) {
		return Identity{}, fmt.Errorf("%w: %s: azp 불일치", ErrTokenInvalid, name)
	}
	if !nonceMatches(token.Nonce, rawNonce) {
		return Identity{}, fmt.Errorf("%w: %s: nonce 불일치", ErrTokenInvalid, name)
	}
	return Identity{Subject: token.Subject}, nil
}

package provider

import (
	"context"
	"net/http"

	"github.com/coreos/go-oidc/v3/oidc"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// LINE 설정의 기본 URL입니다.
const (
	DefaultLINEIssuer  = "https://access.line.me"
	DefaultLINEJWKSURL = "https://api.line.me/oauth2/v2.1/certs"
)

// LINEConfig는 LINE Login 연동 설정입니다. 빈 URL은 Default* 값을 씁니다.
type LINEConfig struct {
	// ChannelID는 id_token의 aud로 기대하는 LINE Login 채널 ID입니다.
	ChannelID string

	Issuer  string
	JWKSURL string

	// HTTP는 LINE으로 나가는 모든 호출에 쓰는 client입니다. nil이면 새 기본 client를 씁니다.
	HTTP *http.Client
	// Clock은 id_token exp 판정에 쓰는 시계입니다. nil이면 clock.System을 씁니다.
	Clock clock.Clock
}

// LINE은 LINE id_token 검증을 맡습니다. 여러 고루틴에서 함께 써도 안전합니다.
type LINE struct {
	verifier *oidc.IDTokenVerifier
}

// NewLINE은 cfg로 LINE을 만듭니다. ChannelID가 비면 오류입니다.
// JWKS는 첫 검증 때 받아 오고 이후 캐시합니다.
func NewLINE(cfg LINEConfig) (*LINE, error) {
	if err := checkRequired("LINE", requiredField{"ChannelID", cfg.ChannelID == ""}); err != nil {
		return nil, err
	}
	issuer := orDefault(cfg.Issuer, DefaultLINEIssuer)
	jwksURL := orDefault(cfg.JWKSURL, DefaultLINEJWKSURL)
	client := orDefaultClient(cfg.HTTP)
	clk := orDefaultClock(cfg.Clock)

	return &LINE{
		verifier: newVerifier(issuer, cfg.ChannelID, []string{oidc.ES256}, newKeySet(client, jwksURL), clk),
	}, nil
}

// Verify는 LINE id_token을 검증합니다.
// iss, aud(ChannelID), exp, ES256 서명, nonce(hex(sha256(rawNonce)))를 확인합니다.
func (l *LINE) Verify(ctx context.Context, idToken, rawNonce string) (Identity, error) {
	return verifyIDToken(ctx, l.verifier, "LINE id_token", idToken, rawNonce)
}

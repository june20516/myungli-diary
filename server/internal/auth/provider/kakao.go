package provider

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	"github.com/coreos/go-oidc/v3/oidc"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// 카카오 설정의 기본 URL입니다.
const (
	DefaultKakaoIssuer    = "https://kauth.kakao.com"
	DefaultKakaoJWKSURL   = "https://kauth.kakao.com/.well-known/jwks.json"
	DefaultKakaoUnlinkURL = "https://kapi.kakao.com/v1/user/unlink"
)

// kakaoNotRegisteredCode는 카카오가 "이미 연결이 끊긴(앱에 가입되지 않은) 사용자"에 돌려주는 오류 코드입니다.
const kakaoNotRegisteredCode = -101

// KakaoConfig는 카카오 연동 설정입니다. 빈 URL은 Default* 값을 씁니다.
type KakaoConfig struct {
	// AppKey는 id_token의 aud로 기대하는 앱 키입니다.
	AppKey string
	// AdminKey는 unlink 호출에 쓰는 Admin 키입니다.
	AdminKey string

	Issuer    string
	JWKSURL   string
	UnlinkURL string

	// HTTP는 카카오로 나가는 모든 호출에 쓰는 client입니다. nil이면 새 기본 client를 씁니다.
	HTTP *http.Client
	// Clock은 id_token exp 판정에 쓰는 시계입니다. nil이면 clock.System을 씁니다.
	Clock clock.Clock
}

// Kakao는 카카오 id_token 검증과 연결 끊기를 맡습니다. 여러 고루틴에서 함께 써도 안전합니다.
type Kakao struct {
	verifier  *oidc.IDTokenVerifier
	http      *http.Client
	adminKey  string
	unlinkURL string
}

// NewKakao는 cfg로 Kakao를 만듭니다. AppKey·AdminKey가 비면 오류입니다.
// JWKS는 첫 검증 때 받아 오고 이후 캐시합니다.
func NewKakao(cfg KakaoConfig) (*Kakao, error) {
	if err := checkRequired("카카오",
		requiredField{"AppKey", cfg.AppKey == ""},
		requiredField{"AdminKey", cfg.AdminKey == ""},
	); err != nil {
		return nil, err
	}
	issuer := orDefault(cfg.Issuer, DefaultKakaoIssuer)
	jwksURL := orDefault(cfg.JWKSURL, DefaultKakaoJWKSURL)
	client := orDefaultClient(cfg.HTTP)
	clk := orDefaultClock(cfg.Clock)

	return &Kakao{
		verifier:  newVerifier(issuer, cfg.AppKey, newKeySet(client, jwksURL), clk),
		http:      client,
		adminKey:  cfg.AdminKey,
		unlinkURL: orDefault(cfg.UnlinkURL, DefaultKakaoUnlinkURL),
	}, nil
}

// Verify는 카카오 id_token을 검증합니다.
// iss, aud(AppKey), exp, RS256 서명, nonce(hex(sha256(rawNonce)))를 확인합니다.
func (k *Kakao) Verify(ctx context.Context, idToken, rawNonce string) (Identity, error) {
	return verifyIDToken(ctx, k.verifier, "카카오 id_token", idToken, rawNonce)
}

// Unlink는 카카오 사용자와 우리 앱의 연결을 끊습니다(Admin 키 방식).
// 이미 연결이 끊긴 사용자(code -101)는 목적을 이룬 것이므로 성공으로 봅니다.
func (k *Kakao) Unlink(ctx context.Context, subject string) error {
	form := url.Values{
		"target_id_type": {"user_id"},
		"target_id":      {subject},
	}
	header := http.Header{"Authorization": {"KakaoAK " + k.adminKey}}

	resp, err := postForm(ctx, k.http, "카카오 unlink", k.unlinkURL, form, header)
	if err != nil {
		return err
	}
	if isSuccessStatus(resp.status) {
		return nil
	}
	if isTransientStatus(resp.status) {
		return fmt.Errorf("%w: 카카오 unlink: 상태 %d", ErrUnavailable, resp.status)
	}

	var body struct {
		Code *int `json:"code"`
	}
	if err := json.Unmarshal(resp.body, &body); err != nil || body.Code == nil {
		return fmt.Errorf("카카오 unlink: 상태 %d, 오류 코드를 읽지 못했습니다", resp.status)
	}
	if *body.Code == kakaoNotRegisteredCode {
		return nil
	}
	return fmt.Errorf("카카오 unlink: 상태 %d, 오류 코드 %d", resp.status, *body.Code)
}

// orDefault는 value가 비어 있으면 fallback을 돌려줍니다.
func orDefault(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// orDefaultClient는 client가 nil이면 새 기본 client를 돌려줍니다.
// http.DefaultClient를 공유하지 않아, 다른 패키지가 그 설정을 바꿔도 영향받지 않습니다.
func orDefaultClient(client *http.Client) *http.Client {
	if client == nil {
		return &http.Client{}
	}
	return client
}

// orDefaultClock은 clk가 nil이면 clock.System을 돌려줍니다.
func orDefaultClock(clk clock.Clock) clock.Clock {
	if clk == nil {
		return clock.System{}
	}
	return clk
}

package provider

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/golang-jwt/jwt/v5"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// Apple 설정의 기본 URL입니다.
const (
	DefaultAppleIssuer    = "https://appleid.apple.com"
	DefaultAppleJWKSURL   = "https://appleid.apple.com/auth/keys"
	DefaultAppleTokenURL  = "https://appleid.apple.com/auth/token" //nolint:gosec // 공개 엔드포인트 URL이며 자격 증명이 아닙니다
	DefaultAppleRevokeURL = "https://appleid.apple.com/auth/revoke"
)

// appleClientSecretAudience는 Apple client_secret JWT의 aud로 Apple이 요구하는 고정 값입니다.
const appleClientSecretAudience = "https://appleid.apple.com" //nolint:gosec // Apple이 정한 공개 aud 값이며 자격 증명이 아닙니다

// appleClientSecretTTL은 client_secret JWT의 유효 기간입니다. 호출마다 새로 만들므로 짧게 둡니다.
const appleClientSecretTTL = 5 * time.Minute

// appleInvalidGrant는 code·refresh token이 만료·폐기됐거나 다른 client의 것일 때 Apple이 돌려주는 오류 코드입니다.
const appleInvalidGrant = "invalid_grant"

// AppleClient는 Apple 로그인을 시작한 쪽입니다. 어느 쪽이냐에 따라 client_id(aud)가 다릅니다.
type AppleClient string

const (
	// AppleNative는 iOS 앱의 네이티브 로그인입니다. client_id는 BundleID입니다.
	AppleNative AppleClient = "native"
	// AppleWeb은 Android 앱의 웹 흐름 로그인입니다. client_id는 ServicesID입니다.
	AppleWeb AppleClient = "web"
)

// AppleConfig는 Apple 연동 설정입니다. 빈 URL은 Default* 값을 씁니다.
type AppleConfig struct {
	// TeamID는 client_secret의 iss입니다.
	TeamID string
	// KeyID는 client_secret header의 kid입니다.
	KeyID string
	// PrivateKey는 client_secret을 ES256으로 서명하는 Apple 발급 키입니다.
	PrivateKey *ecdsa.PrivateKey
	// BundleID는 native 로그인의 client_id입니다.
	BundleID string
	// ServicesID는 web 로그인의 client_id입니다.
	ServicesID string
	// WebRedirectURI는 web 로그인 code 교환 때 함께 보내는 redirect_uri입니다.
	WebRedirectURI string

	Issuer    string
	JWKSURL   string
	TokenURL  string
	RevokeURL string

	// HTTP는 Apple로 나가는 모든 호출에 쓰는 client입니다. nil이면 새 기본 client를 씁니다.
	HTTP *http.Client
	// Clock은 id_token exp 판정과 client_secret iat·exp에 쓰는 시계입니다. nil이면 clock.System을 씁니다.
	Clock clock.Clock
}

// Apple은 Apple id_token 검증, authorization code 교환, refresh token revoke를 맡습니다.
// 여러 고루틴에서 함께 써도 안전합니다.
type Apple struct {
	cfg       AppleConfig
	http      *http.Client
	clock     clock.Clock
	verifiers map[AppleClient]*oidc.IDTokenVerifier
}

// NewApple은 cfg로 Apple을 만듭니다.
// TeamID·KeyID·PrivateKey·BundleID·ServicesID·WebRedirectURI가 비면 오류입니다.
// native·web 검증기는 JWKS 캐시 하나를 함께 씁니다.
func NewApple(cfg AppleConfig) (*Apple, error) {
	if err := checkRequired("Apple",
		requiredField{"TeamID", cfg.TeamID == ""},
		requiredField{"KeyID", cfg.KeyID == ""},
		requiredField{"PrivateKey", cfg.PrivateKey == nil},
		requiredField{"BundleID", cfg.BundleID == ""},
		requiredField{"ServicesID", cfg.ServicesID == ""},
		requiredField{"WebRedirectURI", cfg.WebRedirectURI == ""},
	); err != nil {
		return nil, err
	}
	cfg.Issuer = orDefault(cfg.Issuer, DefaultAppleIssuer)
	cfg.JWKSURL = orDefault(cfg.JWKSURL, DefaultAppleJWKSURL)
	cfg.TokenURL = orDefault(cfg.TokenURL, DefaultAppleTokenURL)
	cfg.RevokeURL = orDefault(cfg.RevokeURL, DefaultAppleRevokeURL)
	client := orDefaultClient(cfg.HTTP)
	clk := orDefaultClock(cfg.Clock)

	keySet := newKeySet(client, cfg.JWKSURL)
	return &Apple{
		cfg:   cfg,
		http:  client,
		clock: clk,
		verifiers: map[AppleClient]*oidc.IDTokenVerifier{
			AppleNative: newVerifier(cfg.Issuer, cfg.BundleID, keySet, clk),
			AppleWeb:    newVerifier(cfg.Issuer, cfg.ServicesID, keySet, clk),
		},
	}, nil
}

// Verify는 Apple id_token을 검증합니다.
// iss, aud(native면 BundleID, web이면 ServicesID), exp, RS256 서명, nonce(hex(sha256(rawNonce)))를 확인합니다.
func (a *Apple) Verify(ctx context.Context, idToken, rawNonce string, client AppleClient) (Identity, error) {
	verifier, ok := a.verifiers[client]
	if !ok {
		return Identity{}, fmt.Errorf("Apple id_token: 알 수 없는 client %q", client)
	}
	return verifyIDToken(ctx, verifier, "Apple", idToken, rawNonce)
}

// VerifyWebCallback은 Apple 웹 콜백으로 받은 id_token을 web(ServicesID) 검증기로 검증하고
// (subject, id_token의 nonce claim)을 돌려줍니다.
// 콜백 시점의 server는 nonce 원문을 모르므로(앱이 나중에 교환 코드와 함께 보냅니다) 서명·iss·aud·exp·sub만 확인하고,
// nonce 비교는 호출자가 원문을 받은 뒤에 합니다. nonce claim이 비어 있으면 나중에 비교할 수 없으므로 ErrTokenInvalid입니다.
// 오류 분류는 Verify와 같습니다(JWKS 조회 실패는 ErrUnavailable).
func (a *Apple) VerifyWebCallback(ctx context.Context, idToken string) (Identity, string, error) {
	token, err := verifyIDTokenClaims(ctx, a.verifiers[AppleWeb], "Apple", idToken)
	if err != nil {
		return Identity{}, "", err
	}
	if token.Nonce == "" {
		return Identity{}, "", fmt.Errorf("%w: Apple id_token: nonce claim이 없습니다", ErrTokenInvalid)
	}
	return Identity{Subject: token.Subject}, token.Nonce, nil
}

// ExchangeCode는 authorization code를 Apple /auth/token에 교환해 refresh token을 받습니다.
// clientID는 교환에 쓴 client_id로, 나중에 Revoke에 같은 값을 넘겨야 합니다.
//
// 응답의 id_token을 같은 client의 검증기로 검증(nonce는 교환 응답에 없을 수 있어 보지 않음)하고, 그 sub가
// wantSubject(앞서 검증한 로그인 id_token의 sub)와 같은지 확인합니다. 다른 사용자의 code를 끼워 넣어
// 그 사용자의 Apple refresh token이 이 계정에 저장되는 일을 막습니다.
//   - 400 invalid_grant(만료·재사용된 code), 응답 id_token 검증 실패·sub 불일치: ErrTokenInvalid
//   - 연결 실패·timeout·5xx·429, 2xx인데 해석할 수 없거나 refresh_token·id_token이 없는 응답,
//     id_token 검증용 JWKS 조회 실패: ErrUnavailable
//     (code는 받아들여졌는데 Apple 응답이 깨진 것이므로 사용자 탓이 아닙니다)
//   - 그 밖의 거절(invalid_client 등 우리 설정 문제): 일반 오류
func (a *Apple) ExchangeCode(ctx context.Context, code string, client AppleClient, wantSubject string) (refreshToken, clientID string, err error) {
	clientID, err = a.clientID(client)
	if err != nil {
		return "", "", err
	}
	secret, err := a.clientSecret(clientID)
	if err != nil {
		return "", "", err
	}
	form := url.Values{
		"grant_type":    {"authorization_code"},
		"code":          {code},
		"client_id":     {clientID},
		"client_secret": {secret},
	}
	if client == AppleWeb {
		form.Set("redirect_uri", a.cfg.WebRedirectURI)
	}

	resp, err := postForm(ctx, a.http, "Apple token", a.cfg.TokenURL, form, nil)
	if err != nil {
		return "", "", err
	}
	if err := classifyAppleFailure("Apple token", resp); err != nil {
		return "", "", err
	}

	var body struct {
		RefreshToken string `json:"refresh_token"`
		IDToken      string `json:"id_token"`
	}
	if err := json.Unmarshal(resp.body, &body); err != nil {
		return "", "", fmt.Errorf("%w: Apple token: 2xx 응답을 해석하지 못했습니다", ErrUnavailable)
	}
	if body.RefreshToken == "" {
		return "", "", fmt.Errorf("%w: Apple token: 2xx 응답에 refresh_token이 없습니다", ErrUnavailable)
	}
	if body.IDToken == "" {
		return "", "", fmt.Errorf("%w: Apple token: 2xx 응답에 id_token이 없습니다", ErrUnavailable)
	}
	// clientID 조회에 성공했으므로 client는 native·web 중 하나이고 검증기가 있습니다.
	exchanged, err := verifyIDTokenClaims(ctx, a.verifiers[client], "Apple token", body.IDToken)
	if err != nil {
		return "", "", err
	}
	if exchanged.Subject != wantSubject {
		return "", "", fmt.Errorf("%w: Apple token: 교환한 id_token의 sub가 로그인 id_token과 다릅니다", ErrTokenInvalid)
	}
	return body.RefreshToken, clientID, nil
}

// Revoke는 Apple refresh token을 폐기합니다. clientID는 ExchangeCode가 돌려준 값입니다.
// 오류 분류는 ExchangeCode와 같습니다(400 invalid_grant는 ErrTokenInvalid).
func (a *Apple) Revoke(ctx context.Context, refreshToken, clientID string) error {
	secret, err := a.clientSecret(clientID)
	if err != nil {
		return err
	}
	form := url.Values{
		"token":           {refreshToken},
		"token_type_hint": {"refresh_token"},
		"client_id":       {clientID},
		"client_secret":   {secret},
	}

	resp, err := postForm(ctx, a.http, "Apple revoke", a.cfg.RevokeURL, form, nil)
	if err != nil {
		return err
	}
	return classifyAppleFailure("Apple revoke", resp)
}

// clientID는 로그인 쪽에 맞는 client_id를 돌려줍니다.
func (a *Apple) clientID(client AppleClient) (string, error) {
	switch client {
	case AppleNative:
		return a.cfg.BundleID, nil
	case AppleWeb:
		return a.cfg.ServicesID, nil
	default:
		return "", fmt.Errorf("Apple: 알 수 없는 client %q", client)
	}
}

// clientSecret은 Apple이 요구하는 client_secret JWT를 만듭니다.
// ES256 서명, header kid=KeyID, claim iss=TeamID·iat=지금·exp=iat+5분·aud=https://appleid.apple.com·sub=clientID.
func (a *Apple) clientSecret(clientID string) (string, error) {
	now := a.clock.Now()
	claims := jwt.RegisteredClaims{
		Issuer:    a.cfg.TeamID,
		Subject:   clientID,
		Audience:  jwt.ClaimStrings{appleClientSecretAudience},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(appleClientSecretTTL)),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = a.cfg.KeyID
	signed, err := token.SignedString(a.cfg.PrivateKey)
	if err != nil {
		return "", fmt.Errorf("Apple client_secret: 서명 실패: %w", err)
	}
	return signed, nil
}

// classifyAppleFailure는 Apple 응답이 2xx가 아니면 분류한 오류를, 2xx면 nil을 돌려줍니다.
// 오류 문구에는 상태 코드와 Apple 오류 코드(error 필드)만 넣습니다.
func classifyAppleFailure(name string, resp formResponse) error {
	if isSuccessStatus(resp.status) {
		return nil
	}
	if isTransientStatus(resp.status) {
		return fmt.Errorf("%w: %s: 상태 %d", ErrUnavailable, name, resp.status)
	}
	var body struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(resp.body, &body); err != nil || body.Error == "" {
		return fmt.Errorf("%s: 상태 %d, 오류 코드를 읽지 못했습니다", name, resp.status)
	}
	if resp.status == http.StatusBadRequest && body.Error == appleInvalidGrant {
		return fmt.Errorf("%w: %s: %s", ErrTokenInvalid, name, appleInvalidGrant)
	}
	return fmt.Errorf("%s: 상태 %d, 오류 코드 %q", name, resp.status, body.Error)
}

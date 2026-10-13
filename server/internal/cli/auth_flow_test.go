package cli

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// flowNonce는 흐름 테스트가 쓰는 nonce 원문입니다(계약상 16자 이상).
const flowNonce = "flow-test-nonce-0123456789"

// flowEnv는 실제 DB와 제공자 대역에 붙은 server 하나입니다.
type flowEnv struct {
	t      *testing.T
	url    string
	client *http.Client
	fake   *providertest.Server
	clk    *clocktest.Fake
}

// newFlowEnv는 serve와 같은 조립(newServer)으로 server를 띄웁니다. 제공자 주소만 providertest 대역으로 바꿉니다.
func newFlowEnv(t *testing.T) *flowEnv {
	t.Helper()
	fake := providertest.New(t)
	clk := clocktest.New(time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC))

	settings, err := parseAuthSettings(flowAuthConfig(t))
	require.NoError(t, err, "인증 설정 파싱")
	handler, err := newServer(settings, serverDeps{
		Pool:   dbtest.New(t),
		Logger: slog.New(slog.DiscardHandler),
		Clock:  clk,
		HTTP:   fake.Client(),
		Providers: providerURLs{
			KakaoJWKS:   fake.JWKSURL(),
			KakaoUnlink: fake.KakaoUnlinkURL(),
			AppleJWKS:   fake.JWKSURL(),
			AppleToken:  fake.AppleTokenURL(),
			AppleRevoke: fake.AppleRevokeURL(),
		},
	})
	require.NoError(t, err, "server 조립")

	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return &flowEnv{t: t, url: srv.URL, client: srv.Client(), fake: fake, clk: clk}
}

// flowAuthConfig는 providertest 대역의 앱 키·Apple ID를 쓰는 인증 설정을 만듭니다.
// 서명 키와 Apple 개인 키는 테스트마다 새로 만든 P-256 키입니다(대역은 client_secret 서명을 검사하지 않습니다).
func flowAuthConfig(t *testing.T) config.AuthConfig {
	t.Helper()
	tokenKey := make([]byte, 32)
	_, err := rand.Read(tokenKey)
	require.NoError(t, err)
	return config.AuthConfig{
		JWTKeyID:              "jwt-flow-1",
		JWTKeyPEM:             newP256PEM(t),
		TokenKeyID:            "tok-flow-1",
		TokenKey:              base64.StdEncoding.EncodeToString(tokenKey),
		KakaoAppKey:           providertest.KakaoAppKey,
		KakaoAdminKey:         providertest.KakaoAdminKey,
		AppleTeamID:           providertest.AppleTeamID,
		AppleKeyID:            providertest.AppleKeyID,
		ApplePrivateKeyPEM:    newP256PEM(t),
		AppleBundleID:         providertest.AppleBundleID,
		AppleServicesID:       providertest.AppleServicesID,
		AppleWebRedirectURI:   providertest.AppleWebRedirectURI,
		AppleCallbackDeepLink: "myungli://auth/apple",
	}
}

// newP256PEM은 새 P-256 개인 키를 PKCS8 PEM 문자열로 돌려줍니다.
func newP256PEM(t *testing.T) string {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	der, err := x509.MarshalPKCS8PrivateKey(key)
	require.NoError(t, err)
	return string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
}

// flowResponse는 상태 코드와 JSON 본문(없으면 빈 map)입니다.
type flowResponse struct {
	status int
	body   map[string]any
}

// do는 JSON 본문(nil이면 본문 없음)과 access token(빈 문자열이면 헤더 없음)으로 요청을 보냅니다.
func (e *flowEnv) do(method, path, accessToken string, body any) flowResponse {
	e.t.Helper()
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		require.NoError(e.t, err)
		reader = bytes.NewReader(raw)
	}
	req, err := http.NewRequestWithContext(e.t.Context(), method, e.url+path, reader)
	require.NoError(e.t, err)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+accessToken)
	}
	resp, err := e.client.Do(req)
	require.NoError(e.t, err, "%s %s", method, path)
	defer func() { _ = resp.Body.Close() }()

	raw, err := io.ReadAll(resp.Body)
	require.NoError(e.t, err)
	out := flowResponse{status: resp.StatusCode, body: map[string]any{}}
	if len(raw) > 0 {
		require.NoError(e.t, json.Unmarshal(raw, &out.body), "%s %s 응답 JSON: %s", method, path, raw)
	}
	return out
}

// tokens는 로그인·갱신 응답에서 access·refresh token을 꺼냅니다. 로그인 응답은 tokens 아래에 있습니다.
func (r flowResponse) tokens(t *testing.T) (access, refresh string) {
	t.Helper()
	pair := r.body
	if nested, ok := r.body["tokens"].(map[string]any); ok {
		pair = nested
	}
	access, _ = pair["accessToken"].(string)
	refresh, _ = pair["refreshToken"].(string)
	require.NotEmpty(t, access, "accessToken: %v", r.body)
	require.NotEmpty(t, refresh, "refreshToken: %v", r.body)
	return access, refresh
}

// requireProblem은 상태와 problem code를 확인합니다.
func (r flowResponse) requireProblem(t *testing.T, status int, code string) {
	t.Helper()
	require.Equal(t, status, r.status, "본문: %v", r.body)
	assert.Equal(t, code, r.body["code"])
}

// loginKakao는 subject로 서명한 카카오 id_token으로 로그인합니다.
func (e *flowEnv) loginKakao(subject string) flowResponse {
	e.t.Helper()
	idToken := e.fake.SignIDToken(providertest.KakaoClaims(subject, flowNonce, e.clk.Now()))
	return e.do(http.MethodPost, "/v1/auth/kakao", "", map[string]string{"idToken": idToken, "nonce": flowNonce})
}

// loginAppleNative는 subject로 서명한 Apple id_token(앱 audience)으로 로그인합니다.
func (e *flowEnv) loginAppleNative(subject string) flowResponse {
	e.t.Helper()
	idToken := e.fake.SignIDToken(providertest.AppleClaims(subject, flowNonce, provider.AppleNative, e.clk.Now()))
	return e.do(http.MethodPost, "/v1/auth/apple", "", map[string]string{
		"idToken": idToken, "authorizationCode": "flow-auth-code", "nonce": flowNonce, "clientType": "native",
	})
}

// currentConsents는 account.CurrentDocuments를 동의 요청 본문으로 만듭니다.
func currentConsents() map[string]any {
	docs := make([]map[string]string, 0, len(account.CurrentDocuments))
	for doc, version := range account.CurrentDocuments {
		docs = append(docs, map[string]string{"document": string(doc), "version": version})
	}
	return map[string]any{"documents": docs}
}

func TestAuthFlow_KakaoLoginConsentMeRefreshLogout(t *testing.T) {
	env := newFlowEnv(t)

	login := env.loginKakao("kakao-flow-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	assert.Equal(t, true, login.body["isNewAccount"])
	assert.Equal(t, true, login.body["consentRequired"])
	access, refresh := login.tokens(t)

	// 동의 전에는 기능 라우트가 막힙니다.
	env.do(http.MethodGet, "/v1/chart", access, nil).requireProblem(t, http.StatusForbidden, "consent.required")

	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)

	me := env.do(http.MethodGet, "/v1/me", access, nil)
	require.Equal(t, http.StatusOK, me.status, "me 본문: %v", me.body)
	assert.Equal(t, false, me.body["consentRequired"])
	assert.Equal(t, "active", me.body["status"])

	refreshed := env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refresh})
	require.Equal(t, http.StatusOK, refreshed.status, "갱신 본문: %v", refreshed.body)
	_, rotated := refreshed.tokens(t)
	assert.NotEqual(t, refresh, rotated, "갱신하면 refresh token이 바뀝니다")

	// 이미 쓴 refresh token을 다시 보내면 탈취로 보고 거절합니다.
	env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refresh}).
		requireProblem(t, http.StatusUnauthorized, "auth.refresh_reused")

	// 재사용 감지로 앞 family가 폐기됐으므로 새로 로그인한 세션으로 로그아웃합니다.
	relogin := env.loginKakao("kakao-flow-subject")
	require.Equal(t, http.StatusOK, relogin.status, "재로그인 본문: %v", relogin.body)
	assert.Equal(t, false, relogin.body["isNewAccount"])
	assert.Equal(t, false, relogin.body["consentRequired"], "이미 동의한 계정입니다")
	access2, refresh2 := relogin.tokens(t)

	logout := env.do(http.MethodPost, "/v1/auth/logout", access2, map[string]string{"refreshToken": refresh2})
	require.Equal(t, http.StatusNoContent, logout.status, "로그아웃 본문: %v", logout.body)

	env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refresh2}).
		requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")
}

func TestAuthFlow_DeleteThenRestoreByLogin(t *testing.T) {
	env := newFlowEnv(t)

	login := env.loginAppleNative("apple-flow-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, refresh := login.tokens(t)

	deleted := env.do(http.MethodDelete, "/v1/me", access, nil)
	require.Equal(t, http.StatusAccepted, deleted.status, "삭제 본문: %v", deleted.body)
	assert.NotEmpty(t, deleted.body["deletionScheduledAt"])

	// 삭제 대기 중에도 같은 access token으로 내 정보는 볼 수 있지만(복구 안내), 기능 라우트는 막힙니다.
	pending := env.do(http.MethodGet, "/v1/me", access, nil)
	require.Equal(t, http.StatusOK, pending.status, "삭제 대기 me 본문: %v", pending.body)
	assert.Equal(t, "pending_deletion", pending.body["status"])
	env.do(http.MethodGet, "/v1/chart", access, nil).requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")

	// 삭제 예약 뒤 로그인 때 받은 Apple refresh token을 revoke합니다.
	revokes := env.fake.AppleRevokeRequests()
	require.Len(t, revokes, 1, "Apple revoke 호출 수")
	assert.Equal(t, providertest.AppleRefreshToken, revokes[0].Form.Get("token"))

	// 삭제 예약이 세션을 모두 끝냈으므로 이전 refresh token은 쓸 수 없습니다.
	env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refresh}).
		requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")

	// 유예 기간 안에 같은 subject로 다시 로그인하면 계정이 되살아납니다.
	restored := env.loginAppleNative("apple-flow-subject")
	require.Equal(t, http.StatusOK, restored.status, "재로그인 본문: %v", restored.body)
	assert.Equal(t, true, restored.body["restoredFromDeletion"])
	assert.Equal(t, false, restored.body["isNewAccount"])
	access2, _ := restored.tokens(t)

	me := env.do(http.MethodGet, "/v1/me", access2, nil)
	require.Equal(t, http.StatusOK, me.status, "me 본문: %v", me.body)
	assert.Equal(t, "active", me.body["status"])

	// 복구는 삭제 전 세션을 되살리지 않습니다.
	env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refresh}).
		requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")
}

package cli

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// flowNonce는 흐름 테스트가 쓰는 nonce 원문입니다(계약상 16자 이상).
const flowNonce = "flow-test-nonce-0123456789"

// unusedCharts는 프로필 저장을 쓰지 않는 흐름 테스트용 ChartChecker입니다. 부르면 실패합니다.
type unusedCharts struct{}

func (unusedCharts) Chart(context.Context, profile.Birth, profile.LocalDate) (*enginev1.ChartResponse, error) {
	return nil, errors.New("흐름 테스트는 엔진을 쓰지 않습니다")
}

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
	return newFlowEnvWith(t, nil)
}

// newFlowEnvWith는 newFlowEnv와 같되, 조립 직전에 customize가 의존성을 고칠 수 있습니다(nil이면 그대로).
func newFlowEnvWith(t *testing.T, customize func(*serverDeps)) *flowEnv {
	t.Helper()
	fake := providertest.New(t)
	clk := clocktest.New(time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC))
	// Apple token 대역이 돌려주는 id_token의 exp를 server와 같은 시계로 정합니다.
	fake.SetClock(clk)

	settings, err := parseAuthSettings(flowAuthConfig(t))
	require.NoError(t, err, "인증 설정 파싱")
	deps := serverDeps{
		Pool:   dbtest.New(t),
		Charts: unusedCharts{},
		Logger: slog.New(slog.DiscardHandler),
		Clock:  clk,
		HTTP:   fake.Client(),
		Providers: providerURLs{
			KakaoJWKS:   fake.JWKSURL(),
			KakaoUnlink: fake.KakaoUnlinkURL(),
			AppleJWKS:   fake.JWKSURL(),
			AppleToken:  fake.AppleTokenURL(),
			AppleRevoke: fake.AppleRevokeURL(),
			LineJWKS:    fake.JWKSURL(),
			GoogleJWKS:  fake.JWKSURL(),
		},
	}
	deps.Entitlements = billing.NewStore(deps.Pool, clk)
	if customize != nil {
		customize(&deps)
	}
	handler, err := newServer(settings, deps)
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
		JWTKeyID:            "jwt-flow-1",
		JWTKeyPEM:           newP256PEM(t),
		TokenKeyID:          "tok-flow-1",
		TokenKey:            base64.StdEncoding.EncodeToString(tokenKey),
		KakaoAppKey:         providertest.KakaoAppKey,
		KakaoAdminKey:       providertest.KakaoAdminKey,
		LineChannelID:       providertest.LINEChannelID,
		GoogleClientIDs:     providertest.GoogleClientIDs,
		AppleTeamID:         providertest.AppleTeamID,
		AppleKeyID:          providertest.AppleKeyID,
		ApplePrivateKeyPEM:  newP256PEM(t),
		AppleBundleID:       providertest.AppleBundleID,
		AppleServicesID:     providertest.AppleServicesID,
		AppleWebRedirectURI: providertest.AppleWebRedirectURI,
		AppLinkBase:         "https://app.myungli.example",
		AndroidAppPackage:   "app.myungli.test",
		AndroidCertSHA256:   testCertSHA256,
		AndroidStoreURL:     testStoreURL,
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
	return e.send(req)
}

// send는 요청을 보내고 상태 코드와 JSON 본문을 읽습니다.
func (e *flowEnv) send(req *http.Request) flowResponse {
	e.t.Helper()
	resp, err := e.client.Do(req)
	require.NoError(e.t, err, "%s %s", req.Method, req.URL.Path)
	defer func() { _ = resp.Body.Close() }()

	raw, err := io.ReadAll(resp.Body)
	require.NoError(e.t, err)
	out := flowResponse{status: resp.StatusCode, body: map[string]any{}}
	if len(raw) > 0 {
		require.NoError(e.t, json.Unmarshal(raw, &out.body), "%s %s 응답 JSON: %s", req.Method, req.URL.Path, raw)
	}
	return out
}

// mustJSON은 값을 JSON으로 바꿉니다.
func mustJSON(t *testing.T, value any) []byte {
	t.Helper()
	raw, err := json.Marshal(value)
	require.NoError(t, err)
	return raw
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
		"idToken": idToken, "authorizationCode": providertest.AppleCode(subject), "nonce": flowNonce,
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

	// 응답을 받지 못한 앱의 재시도처럼, 이미 쓴 refresh token을 유예 시간 안에 다시 보내면 새 토큰 쌍을 줍니다.
	retried := env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refresh})
	require.Equal(t, http.StatusOK, retried.status, "유예 안 재전송 본문: %v", retried.body)
	_, retriedRefresh := retried.tokens(t)
	assert.NotEqual(t, rotated, retriedRefresh, "앞서 준 토큰과 다른 토큰입니다")

	// 유예 시간이 지난 뒤 이미 쓴 refresh token을 다시 보내면 탈취로 보고 거절합니다.
	env.clk.Advance(auth.RefreshReuseGrace + time.Second)
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

// postAppleCallback은 Apple 웹 콜백(form_post)을 보내고 redirect를 따라가지 않은 응답을 돌려줍니다.
// 본문은 쓰지 않으므로 함수 안에서 닫습니다.
func (e *flowEnv) postAppleCallback(form url.Values) (status int, location string) {
	e.t.Helper()
	client := *e.client
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	req, err := http.NewRequestWithContext(e.t.Context(), http.MethodPost, e.url+"/v1/auth/apple/callback", strings.NewReader(form.Encode()))
	require.NoError(e.t, err)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := client.Do(req)
	require.NoError(e.t, err)
	require.NoError(e.t, resp.Body.Close())
	return resp.StatusCode, resp.Header.Get("Location")
}

func TestAuthFlow_AndroidAppleWebLogin(t *testing.T) {
	env := newFlowEnv(t)

	// Apple 웹 흐름: id_token의 aud는 ServicesID, nonce claim은 앱이 만든 nonce 원문의 SHA-256 hex입니다.
	const subject = "apple-web-flow-subject"
	idToken := env.fake.SignIDToken(providertest.AppleClaims(subject, flowNonce, provider.AppleWeb, env.clk.Now()))
	const state = "flow-state-0123456789"

	// 콜백은 303으로 App Link에 교환 코드와 state만 넘깁니다.
	status, rawLocation := env.postAppleCallback(url.Values{
		"code": {providertest.AppleCode(subject)}, "id_token": {idToken}, "state": {state},
	})
	require.Equal(t, http.StatusSeeOther, status)
	location, err := url.Parse(rawLocation)
	require.NoError(t, err)
	assert.Equal(t, "app.myungli.example", location.Host)
	assert.Equal(t, "/auth/apple", location.Path)
	exchange := location.Query().Get("exchange")
	require.NotEmpty(t, exchange, "Location: %s", location)
	assert.Equal(t, state, location.Query().Get("state"), "보낸 state를 그대로 돌려줍니다")
	assert.Empty(t, location.Query().Get("error"))
	// id_token·code·user 같은 Apple 값은 URL에 실리지 않습니다.
	queryKeys := make([]string, 0, len(location.Query()))
	for key := range location.Query() {
		queryKeys = append(queryKeys, key)
	}
	assert.ElementsMatch(t, []string{"exchange", "state"}, queryKeys, "query는 exchange·state뿐입니다")

	// App Link가 앱을 열지 못하면 브라우저가 이 경로를 서버에서 받아 안내 페이지를 봅니다.
	pageReq, err := http.NewRequestWithContext(t.Context(), http.MethodGet, env.url+"/auth/apple?"+location.RawQuery, nil)
	require.NoError(t, err)
	pageResp, err := env.client.Do(pageReq)
	require.NoError(t, err)
	defer func() { _ = pageResp.Body.Close() }()
	pageBody, err := io.ReadAll(pageResp.Body)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, pageResp.StatusCode)
	assert.Contains(t, pageResp.Header.Get("Content-Type"), "text/html")
	assert.Contains(t, string(pageBody), "intent://app.myungli.example/auth/apple", "앱에서 열기 intent 링크")
	assert.Contains(t, string(pageBody), testStoreURL, "스토어 링크")

	// 틀린 nonce는 거절하되 교환 코드를 소진하지 않습니다.
	completePath := "/v1/auth/apple/web"
	env.do(http.MethodPost, completePath, "", map[string]string{
		"exchangeCode": exchange, "nonce": "wrong-nonce-0123456789",
	}).requireProblem(t, http.StatusUnauthorized, "auth.exchange_invalid")

	complete := env.do(http.MethodPost, completePath, "", map[string]string{"exchangeCode": exchange, "nonce": flowNonce})
	require.Equal(t, http.StatusOK, complete.status, "완료 본문: %v", complete.body)
	assert.Equal(t, true, complete.body["isNewAccount"])
	assert.Equal(t, true, complete.body["consentRequired"])
	access, _ := complete.tokens(t)

	// 교환 코드는 일회용입니다.
	env.do(http.MethodPost, completePath, "", map[string]string{"exchangeCode": exchange, "nonce": flowNonce}).
		requireProblem(t, http.StatusUnauthorized, "auth.exchange_invalid")

	// 동의 전에도 /v1/me는 열려 있습니다(기능 라우트만 막힘).
	me := env.do(http.MethodGet, "/v1/me", access, nil)
	require.Equal(t, http.StatusOK, me.status, "me 본문: %v", me.body)
	assert.Equal(t, true, me.body["consentRequired"])
}

// LINE·Google 설정이 비면 조립이 provider 이름이 붙은 오류로 실패합니다.
func TestNewServer_RejectsEmptyLineAndGoogleConfig(t *testing.T) {
	tests := []struct {
		name    string
		mutate  func(*config.AuthConfig)
		wantErr string
	}{
		{"LINE channel ID 없음", func(c *config.AuthConfig) { c.LineChannelID = "" }, "provider line:"},
		{"Google client ID 없음", func(c *config.AuthConfig) { c.GoogleClientIDs = nil }, "provider google:"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := flowAuthConfig(t)
			tt.mutate(&cfg)
			settings, err := parseAuthSettings(cfg)
			require.NoError(t, err)

			_, err = newServer(settings, serverDeps{Logger: slog.New(slog.DiscardHandler), Clock: clocktest.New(time.Now())})

			require.ErrorContains(t, err, tt.wantErr)
		})
	}
}

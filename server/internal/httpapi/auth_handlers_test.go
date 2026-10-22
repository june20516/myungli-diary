package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers/gorillamux"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// testAppLinkBase는 테스트의 App Link 주소입니다.
const testAppLinkBase = "https://app.myungli.example"

// testExchangeCode는 교환 코드 형식(256비트 난수의 base64url, 43자)의 테스트 값입니다.
const testExchangeCode = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE"

// testAppLink는 테스트의 App Link 설정입니다.
func testAppLink(t *testing.T) httpapi.AppLinkConfig {
	t.Helper()
	base, err := url.Parse(testAppLinkBase)
	require.NoError(t, err)
	return httpapi.AppLinkConfig{
		Base:       base,
		Package:    "app.myungli.test",
		CertSHA256: []string{"14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"},
		StoreURL:   "https://play.google.com/store/apps/details?id=app.myungli.test&hl=ko",
	}
}

var handlerNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

// fakeAuth는 AuthService 대역입니다. 받은 인자를 기록하고 정해 둔 결과를 돌려줍니다.
type fakeAuth struct {
	login   auth.LoginResult
	pair    auth.TokenPair
	err     error
	gotAcct uuid.UUID
	gotRaw  string

	// exchange는 BeginAppleWebLogin이 돌려줄 교환 코드입니다.
	exchange string
	// beginCalls는 BeginAppleWebLogin 호출 횟수이고, got*는 마지막으로 받은 인자입니다.
	beginCalls  int
	gotIDToken  string
	gotCode     string
	gotNonce    string
	gotExchange string
	appleCalled bool

	// 계정 연결 operation의 대역 결과와 마지막으로 받은 인자입니다.
	identities   []auth.LinkedIdentity
	linkResult   auth.LinkResult
	linkErr      error
	unlinkErr    error
	gotProvider  string
	gotLinkProof auth.LinkProof
}

func (f *fakeAuth) LoginKakao(context.Context, string, string) (auth.LoginResult, error) {
	return f.login, f.err
}

func (f *fakeAuth) LoginApple(_ context.Context, idToken, code, nonce string) (auth.LoginResult, error) {
	f.appleCalled = true
	f.gotIDToken, f.gotCode, f.gotNonce = idToken, code, nonce
	return f.login, f.err
}

func (f *fakeAuth) BeginAppleWebLogin(_ context.Context, idToken, code string) (string, error) {
	f.beginCalls++
	f.gotIDToken, f.gotCode = idToken, code
	if f.err != nil {
		return "", f.err
	}
	return f.exchange, nil
}

func (f *fakeAuth) CompleteAppleWebLogin(_ context.Context, exchange, nonce string) (auth.LoginResult, error) {
	f.gotExchange, f.gotNonce = exchange, nonce
	return f.login, f.err
}

func (f *fakeAuth) Refresh(context.Context, string) (auth.TokenPair, error) { return f.pair, f.err }

func (f *fakeAuth) Logout(_ context.Context, id uuid.UUID, raw string) error {
	f.gotAcct, f.gotRaw = id, raw
	return f.err
}

// fakeAccounts는 AccountService 대역입니다.
type fakeAccounts struct {
	me       account.Me
	err      error
	agreeErr error
	gotDocs  []account.ConsentDocument
	// deleted는 Delete가 받은 계정 id입니다.
	deleted []uuid.UUID
}

func (f *fakeAccounts) Me(context.Context, uuid.UUID) (account.Me, error) { return f.me, f.err }

func (f *fakeAccounts) AgreeConsents(_ context.Context, _ uuid.UUID, docs []account.ConsentDocument) error {
	f.gotDocs = docs
	return f.agreeErr
}

func (f *fakeAccounts) Delete(_ context.Context, id uuid.UUID) error {
	f.deleted = append(f.deleted, id)
	return f.err
}

// fakeProfiles는 ProfileService 대역입니다. 받은 인자를 기록하고 정해 둔 결과를 돌려줍니다.
type fakeProfiles struct {
	profile profile.Profile
	saved   profile.Saved
	exists  bool
	err     error

	gotPut   profile.Profile
	gotPatch profile.Patch
}

func (f *fakeProfiles) Get(context.Context, uuid.UUID) (profile.Profile, error) {
	return f.profile, f.err
}

func (f *fakeProfiles) Exists(context.Context, uuid.UUID) (bool, error) { return f.exists, f.err }

func (f *fakeProfiles) Put(_ context.Context, _ uuid.UUID, p profile.Profile) (profile.Saved, error) {
	f.gotPut = p
	return f.saved, f.err
}

func (f *fakeProfiles) Patch(_ context.Context, _ uuid.UUID, p profile.Patch) (profile.Saved, error) {
	f.gotPatch = p
	return f.saved, f.err
}

func testTokenPair() auth.TokenPair {
	return auth.TokenPair{
		AccessToken: "access", AccessExpiresAt: handlerNow.Add(15 * time.Minute),
		RefreshToken: "refresh", RefreshExpiresAt: handlerNow.Add(30 * 24 * time.Hour),
	}
}

// newHandlerAPI는 api를 계약 라우트에 등록한 Handler와 계약 문서를 만듭니다.
// bearer 라우트는 고정 계정(active)을 ctx에 넣어 통과시킵니다.
func newHandlerAPI(t *testing.T, api *httpapi.API) (http.Handler, *openapi3.T) {
	t.Helper()
	handler, spec, _ := newHandlerAPIWithLogs(t, api)
	return handler, spec
}

// newHandlerAPIWithLogs는 newHandlerAPI와 같고, 요청 로그와 핸들러 로그가 쌓이는 buffer를 함께 돌려줍니다.
// api의 Logger와 AppLink가 비어 있으면 테스트 기본값(로그 buffer, testAppLink)을 넣습니다.
func newHandlerAPIWithLogs(t *testing.T, api *httpapi.API) (http.Handler, *openapi3.T, *bytes.Buffer) {
	t.Helper()
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, logs := newTestDeps()
	if api.Logger == nil {
		api.Logger = deps.Logger
	}
	if api.AppLink.Base == nil {
		api.AppLink = testAppLink(t)
	}
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: authenticateFixedAccount,
		AppCheck:     passAppCheck,
	}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, api, deps, routes)
	})
	return handler, spec, logs
}

// expectContractResponse는 요청에 대한 응답이 계약의 상태·헤더·본문 스키마를 통과하는지 확인합니다.
func expectContractResponse(t *testing.T, spec *openapi3.T, req *http.Request, rec *httptest.ResponseRecorder) {
	t.Helper()
	// 요청 검증과 같게 3.0 의미로 검사합니다(ValidateRequests 주석 참고).
	validationSpec := *spec
	validationSpec.OpenAPI = "3.0.3"
	validationSpec.Servers = nil
	router, err := gorillamux.NewRouter(&validationSpec)
	require.NoError(t, err)
	route, pathParams, err := router.FindRoute(req)
	require.NoError(t, err)

	body := rec.Body.Bytes()
	err = openapi3filter.ValidateResponse(req.Context(), &openapi3filter.ResponseValidationInput{
		RequestValidationInput: &openapi3filter.RequestValidationInput{Request: req, PathParams: pathParams, Route: route},
		Status:                 rec.Code,
		Header:                 rec.Header(),
		Body:                   io.NopCloser(bytes.NewReader(body)),
		Options:                &openapi3filter.Options{IncludeResponseStatus: true},
	})
	require.NoError(t, err, "계약 응답 위반, body = %s", body)
}

func postJSON(t *testing.T, target, body string) *http.Request {
	t.Helper()
	return newBodyRequest(t, http.MethodPost, target, contentTypeJSON, body)
}

const kakaoBody = `{"idToken":"id","nonce":"0123456789abcdef"}`

func TestLoginKakao_ReturnsLoginResponse(t *testing.T) {
	fa := &fakeAuth{login: auth.LoginResult{AccountID: testAccountID, Tokens: testTokenPair(), IsNewAccount: true}}
	accts := &fakeAccounts{me: account.Me{AccountID: testAccountID, Access: account.Access{Status: account.StatusActive, ConsentRequired: true}}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa, Accounts: accts})

	req := postJSON(t, "/v1/auth/kakao", kakaoBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.LoginResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.ConsentRequired)
	assert.True(t, got.IsNewAccount)
	assert.NotContains(t, rec.Body.String(), "restoredFromDeletion")
	assert.Equal(t, "access", got.Tokens.AccessToken)
	assert.Equal(t, "refresh", got.Tokens.RefreshToken)
}

func TestLoginKakao_ProviderInvalidIs401WithoutChallenge(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: &fakeAuth{err: auth.ErrProviderTokenInvalid}, Accounts: &fakeAccounts{}})

	req := postJSON(t, "/v1/auth/kakao", kakaoBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Equal(t, "auth.provider_token_invalid", decodeProblem(t, rec).Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
	expectContractResponse(t, spec, req, rec)
}

// TestLoginApple_ReturnsLogin은 loginApple이 서비스의 로그인 결과를 계약 응답으로 돌려주는지 확인합니다.
func TestLoginApple_ReturnsLogin(t *testing.T) {
	fa := &fakeAuth{login: auth.LoginResult{AccountID: testAccountID, Tokens: testTokenPair(), RestoredFromDeletion: true}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa, Accounts: &fakeAccounts{}})

	req := postJSON(t, "/v1/auth/apple", `{"idToken":"id","authorizationCode":"code","nonce":"0123456789abcdef"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
}

// TestLoginApple_NoClientType은 loginApple이 clientType 없이 받은 값만 서비스(native 고정)에 넘기는지 확인합니다.
func TestLoginApple_NoClientType(t *testing.T) {
	fa := &fakeAuth{login: auth.LoginResult{AccountID: testAccountID, Tokens: testTokenPair()}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa, Accounts: &fakeAccounts{}})

	req := postJSON(t, "/v1/auth/apple", `{"idToken":"id","authorizationCode":"code","nonce":"0123456789abcdef"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.True(t, fa.appleCalled)
	assert.Equal(t, "id", fa.gotIDToken)
	assert.Equal(t, "code", fa.gotCode)
	assert.Equal(t, "0123456789abcdef", fa.gotNonce)
	assert.Zero(t, fa.beginCalls, "앱 로그인은 웹 흐름을 쓰지 않습니다")
}

const appleWebBody = `{"exchangeCode":"` + testExchangeCode + `","nonce":"0123456789abcdef"}`

func TestCompleteAppleWebLogin_ReturnsLoginResponse(t *testing.T) {
	fa := &fakeAuth{login: auth.LoginResult{AccountID: testAccountID, Tokens: testTokenPair(), IsNewAccount: true}}
	accts := &fakeAccounts{me: account.Me{AccountID: testAccountID, Access: account.Access{Status: account.StatusActive, ConsentRequired: true}}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa, Accounts: accts})

	req := postJSON(t, "/v1/auth/apple/web", appleWebBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.LoginResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.ConsentRequired)
	assert.True(t, got.IsNewAccount)
	assert.Equal(t, "access", got.Tokens.AccessToken)
	assert.Equal(t, testExchangeCode, fa.gotExchange)
	assert.Equal(t, "0123456789abcdef", fa.gotNonce)
}

func TestCompleteAppleWebLogin_InvalidIs401(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: &fakeAuth{err: auth.ErrExchangeInvalid}, Accounts: &fakeAccounts{}})

	req := postJSON(t, "/v1/auth/apple/web", appleWebBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code, rec.Body.String())
	assert.Equal(t, "auth.exchange_invalid", decodeProblem(t, rec).Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
	expectContractResponse(t, spec, req, rec)
}

func TestRefreshToken_ReturnsTokenPair(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: &fakeAuth{pair: testTokenPair()}})

	req := postJSON(t, "/v1/auth/refresh", `{"refreshToken":"r"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
}

func TestRefreshToken_ReuseIs401RefreshReused(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: &fakeAuth{err: auth.ErrRefreshReused}})

	req := postJSON(t, "/v1/auth/refresh", `{"refreshToken":"r"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Equal(t, "auth.refresh_reused", decodeProblem(t, rec).Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
	expectContractResponse(t, spec, req, rec)
}

func TestLogout_Returns204(t *testing.T) {
	fa := &fakeAuth{}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

	req := postJSON(t, "/v1/auth/logout", `{"refreshToken":"r"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusNoContent, rec.Code)
	expectContractResponse(t, spec, req, rec)
	assert.Equal(t, fixedAccountID, fa.gotAcct)
	assert.Equal(t, "r", fa.gotRaw)
}

func appleCallbackRequest(t *testing.T, form url.Values) *http.Request {
	t.Helper()
	return newBodyRequest(t, http.MethodPost, "/v1/auth/apple/callback", contentTypeForm, form.Encode())
}

// appleCallbackLocation은 303 응답의 Location을 해석하고, App Link 주소(Base + /auth/apple)로 가는지 확인합니다.
func appleCallbackLocation(t *testing.T, spec *openapi3.T, req *http.Request, rec *httptest.ResponseRecorder) url.Values {
	t.Helper()
	require.Equal(t, http.StatusSeeOther, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	location, err := url.Parse(rec.Header().Get("Location"))
	require.NoError(t, err)
	assert.Equal(t, "https", location.Scheme)
	assert.Equal(t, "app.myungli.example", location.Host)
	assert.Equal(t, "/auth/apple", location.Path)
	assert.Empty(t, location.Fragment)
	return location.Query()
}

func TestAppleCallback_SuccessRedirectsWithExchangeOnly(t *testing.T) {
	fa := &fakeAuth{exchange: testExchangeCode}
	handler, spec, logs := newHandlerAPIWithLogs(t, &httpapi.API{Auth: fa})
	user := `{"name":{"firstName":"길 동"},"email":"user@example.test"}`

	req := appleCallbackRequest(t, url.Values{"code": {"c&d"}, "id_token": {"a.b.c"}, "state": {"s 1&x"}, "user": {user}})
	rec := serve(handler, req)

	query := appleCallbackLocation(t, spec, req, rec)
	assert.Equal(t, url.Values{"exchange": {testExchangeCode}, "state": {"s 1&x"}}, query, "Location에는 교환 코드와 state만 있습니다")
	assert.Equal(t, 1, fa.beginCalls)
	assert.Equal(t, "a.b.c", fa.gotIDToken)
	assert.Equal(t, "c&d", fa.gotCode)
	for _, secret := range []string{"user@example.test", "a.b.c", "c&d", testExchangeCode} {
		assert.NotContains(t, logs.String(), secret, "로그에 Apple 값이나 교환 코드가 남으면 안 됩니다")
	}
}

func TestAppleCallback_CancellationRedirectsWithError(t *testing.T) {
	fa := &fakeAuth{exchange: testExchangeCode}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

	req := appleCallbackRequest(t, url.Values{"error": {"user_cancelled_authorize"}, "state": {"s"}, "code": {"ignored"}, "id_token": {"ignored"}})
	rec := serve(handler, req)

	query := appleCallbackLocation(t, spec, req, rec)
	assert.Equal(t, url.Values{"error": {"user_cancelled_authorize"}, "state": {"s"}}, query)
	assert.Zero(t, fa.beginCalls, "Apple이 오류를 보내면 교환하지 않습니다")
}

func TestAppleCallback_UnknownAppleErrorBecomesInvalidRequest(t *testing.T) {
	tests := []struct{ name, appleError string }{
		{"Apple의 다른 오류", "invalid_scope"},
		{"교환 결과 오류 값을 흉내 냄", "token_invalid"},
		{"HTML", "<script>alert(1)</script>"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fa := &fakeAuth{exchange: testExchangeCode}
			handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

			req := appleCallbackRequest(t, url.Values{"error": {tt.appleError}, "state": {"s"}})
			rec := serve(handler, req)

			query := appleCallbackLocation(t, spec, req, rec)
			assert.Equal(t, url.Values{"error": {"invalid_request"}, "state": {"s"}}, query)
			assert.Zero(t, fa.beginCalls)
		})
	}
}

// appleCallbackFailureCase는 BeginAppleWebLogin 오류가 Location의 error 값으로 바뀌는 사례입니다.
func appleCallbackFailureCase(t *testing.T, beginErr error, wantError string) *bytes.Buffer {
	t.Helper()
	fa := &fakeAuth{err: beginErr}
	handler, spec, logs := newHandlerAPIWithLogs(t, &httpapi.API{Auth: fa})

	req := appleCallbackRequest(t, url.Values{"code": {"code-secret"}, "id_token": {"token-secret"}, "state": {"s"}})
	rec := serve(handler, req)

	query := appleCallbackLocation(t, spec, req, rec)
	assert.Equal(t, url.Values{"error": {wantError}, "state": {"s"}}, query)
	assert.Equal(t, 1, fa.beginCalls)
	assert.NotContains(t, logs.String(), "code-secret")
	assert.NotContains(t, logs.String(), "token-secret")
	return logs
}

func TestAppleCallback_ProviderUnavailableRedirects(t *testing.T) {
	appleCallbackFailureCase(t, fmt.Errorf("apple token: %w", auth.ErrProviderUnavailable), "provider_unavailable")
}

func TestAppleCallback_ProviderTokenInvalidRedirects(t *testing.T) {
	appleCallbackFailureCase(t, fmt.Errorf("apple verify: %w", auth.ErrProviderTokenInvalid), "token_invalid")
}

func TestAppleCallback_UnexpectedErrorRedirectsServerError(t *testing.T) {
	logs := appleCallbackFailureCase(t, errors.New("db down"), "server_error")
	assert.Contains(t, logs.String(), "db down", "예상하지 못한 오류는 원인을 로그에 남깁니다")
}

func TestAppleCallback_MissingCodeRedirectsInvalidRequest(t *testing.T) {
	tests := []struct {
		name string
		form url.Values
	}{
		{"state만", url.Values{"state": {"s"}}},
		{"id_token 없음", url.Values{"state": {"s"}, "code": {"c"}}},
		{"code 없음", url.Values{"state": {"s"}, "id_token": {"t"}}},
		{"빈 code", url.Values{"state": {"s"}, "code": {""}, "id_token": {"t"}}},
		{"빈 error는 오류가 아님", url.Values{"state": {"s"}, "error": {""}, "id_token": {"t"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fa := &fakeAuth{exchange: testExchangeCode}
			handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

			req := appleCallbackRequest(t, tt.form)
			rec := serve(handler, req)

			query := appleCallbackLocation(t, spec, req, rec)
			assert.Equal(t, url.Values{"error": {"invalid_request"}, "state": {"s"}}, query)
			assert.Zero(t, fa.beginCalls)
		})
	}
}

func TestAppleCallback_MissingStateIs400(t *testing.T) {
	tests := []struct {
		name string
		form url.Values
	}{
		{"state 없음", url.Values{"code": {"c"}, "id_token": {"t"}}},
		{"빈 state", url.Values{"code": {"c"}, "id_token": {"t"}, "state": {""}}},
		{"빈 state와 Apple 오류", url.Values{"error": {"user_cancelled_authorize"}, "state": {""}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fa := &fakeAuth{exchange: testExchangeCode}
			handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

			req := appleCallbackRequest(t, tt.form)
			rec := serve(handler, req)

			require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, "request.invalid", p.Code)
			assert.Equal(t, []string{"/state"}, fieldsOf(p))
			assert.Empty(t, rec.Header().Get("Location"))
			assert.Zero(t, fa.beginCalls)
			expectContractResponse(t, spec, req, rec)
		})
	}
}

func TestGetHealth_NilDBIs503(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/healthz", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, "DB가 없으면 503")
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, req, rec)
}

func TestGetHealth_DBPingOKIs200(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{DB: dbtest.New(t)})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/healthz", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, "DB ping이 성공하면 200")
	var body gen.Health
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	assert.Equal(t, gen.Ok, body.Status)
	expectContractResponse(t, spec, req, rec)
}

func TestGetHealth_DBDownIs503(t *testing.T) {
	// 연결을 맺을 수 없는 주소입니다. pool은 지연 연결이라 생성은 성공하고 ping이 실패합니다.
	pool, err := pgxpool.New(t.Context(), "postgres://u:p@127.0.0.1:1/db?connect_timeout=1")
	require.NoError(t, err)
	t.Cleanup(pool.Close)
	handler, spec := newHandlerAPI(t, &httpapi.API{DB: pool})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/healthz", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusServiceUnavailable, rec.Code)
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, req, rec)
}

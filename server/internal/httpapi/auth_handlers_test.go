package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
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
)

const testDeepLink = "myungli://auth/apple"

var handlerNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

// fakeAuth는 AuthService 대역입니다. 받은 인자를 기록하고 정해 둔 결과를 돌려줍니다.
type fakeAuth struct {
	login   auth.LoginResult
	pair    auth.TokenPair
	err     error
	gotAcct uuid.UUID
	gotRaw  string
}

func (f *fakeAuth) LoginKakao(context.Context, string, string) (auth.LoginResult, error) {
	return f.login, f.err
}

func (f *fakeAuth) LoginApple(context.Context, string, string, string) (auth.LoginResult, error) {
	return f.login, f.err
}

func (f *fakeAuth) Refresh(context.Context, string) (auth.TokenPair, error) { return f.pair, f.err }

func (f *fakeAuth) Logout(_ context.Context, id uuid.UUID, raw string) error {
	f.gotAcct, f.gotRaw = id, raw
	return f.err
}

// fakeAccounts는 AccountService 대역입니다.
type fakeAccounts struct {
	me          account.Me
	scheduledAt time.Time
	err         error
	agreeErr    error
	gotDocs     []account.ConsentDocument
}

func (f *fakeAccounts) Me(context.Context, uuid.UUID) (account.Me, error) { return f.me, f.err }

func (f *fakeAccounts) AgreeConsents(_ context.Context, _ uuid.UUID, docs []account.ConsentDocument) error {
	f.gotDocs = docs
	return f.agreeErr
}

func (f *fakeAccounts) RequestDeletion(context.Context, uuid.UUID) (time.Time, error) {
	return f.scheduledAt, f.err
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
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: authenticateFixedAccount,
	}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, api, deps, routes)
	})
	return handler, spec
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
	assert.False(t, got.RestoredFromDeletion)
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

func TestAppleCallback_RedirectsWithCodeAndUser(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{AppleCallbackDeepLink: testDeepLink})
	user := `{"name":{"firstName":"길 동"}}`

	req := appleCallbackRequest(t, url.Values{"code": {"c&d"}, "id_token": {"a.b.c"}, "state": {"s 1"}, "user": {user}})
	rec := serve(handler, req)

	require.Equal(t, http.StatusSeeOther, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	location, err := url.Parse(rec.Header().Get("Location"))
	require.NoError(t, err)
	assert.Equal(t, "myungli", location.Scheme)
	query := location.Query()
	assert.Equal(t, "c&d", query.Get("code"))
	assert.Equal(t, "a.b.c", query.Get("id_token"))
	assert.Equal(t, "s 1", query.Get("state"))
	assert.Equal(t, user, query.Get("user"))
	assert.Empty(t, query.Get("error"))
	assert.NotContains(t, location.RawQuery, "&d", "특수문자는 인코딩되어야 합니다")
}

func TestAppleCallback_CancellationRedirectsWithError(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{AppleCallbackDeepLink: testDeepLink})

	req := appleCallbackRequest(t, url.Values{"error": {"user_cancelled_authorize"}, "state": {"s"}, "code": {"ignored"}})
	rec := serve(handler, req)

	require.Equal(t, http.StatusSeeOther, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	location, err := url.Parse(rec.Header().Get("Location"))
	require.NoError(t, err)
	assert.Equal(t, url.Values{"error": {"user_cancelled_authorize"}, "state": {"s"}}, location.Query())
}

func TestAppleCallback_NeitherErrorNorCodeIs400(t *testing.T) {
	tests := []struct {
		name string
		form url.Values
		want []string
	}{
		{"state만", url.Values{"state": {"s"}}, []string{"/code", "/id_token"}},
		{"id_token 없음", url.Values{"state": {"s"}, "code": {"c"}}, []string{"/id_token"}},
		{"code 없음", url.Values{"state": {"s"}, "id_token": {"t"}}, []string{"/code"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler, spec := newHandlerAPI(t, &httpapi.API{AppleCallbackDeepLink: testDeepLink})

			req := appleCallbackRequest(t, tt.form)
			rec := serve(handler, req)

			require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, "request.invalid", p.Code)
			assert.Equal(t, tt.want, fieldsOf(p))
			for _, fe := range p.Errors {
				assert.Equal(t, "required", fe.Code)
			}
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

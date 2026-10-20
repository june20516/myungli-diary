//go:build staging

package httpapi_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

const testLoginSecret = "0123456789abcdef0123456789abcdef-staging"

// testLoginFixture는 테스트 로그인을 켠 Handler와 그 뒤의 실제 서비스입니다.
type testLoginFixture struct {
	realAuth
	handler http.Handler
	spec    *openapi3.T
	logs    *bytes.Buffer
}

func newTestLoginFixture(t *testing.T) testLoginFixture {
	t.Helper()
	real := newRealAuth(t)
	api := &httpapi.API{Auth: real.auth, Accounts: real.accounts}
	api.EnableTestLogin(testLoginSecret, real.auth)
	handler, spec, logs := newHandlerAPIWithLogs(t, api)
	return testLoginFixture{realAuth: real, handler: handler, spec: spec, logs: logs}
}

func testLoginRequest(t *testing.T, secret, body string) *http.Request {
	t.Helper()
	req := newBodyRequest(t, http.MethodPost, testLoginPath, contentTypeJSON, body)
	if secret != "" {
		req.Header.Set(testLoginSecretHeader, secret)
	}
	return req
}

// login은 맞는 비밀로 로그인하고 200과 계약 LoginResponse 스키마를 확인합니다.
func (f testLoginFixture) login(t *testing.T, label string) map[string]any {
	t.Helper()
	rec := serve(f.handler, testLoginRequest(t, testLoginSecret, `{"label":"`+label+`"}`))
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "application/json", rec.Header().Get("Content-Type"))
	assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"), "토큰 응답은 캐시하지 않습니다")

	var body map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	schema := f.spec.Components.Schemas["LoginResponse"]
	require.NotNil(t, schema)
	require.NoError(t, schema.Value.VisitJSON(body), "계약 LoginResponse 위반: %s", rec.Body.String())
	return body
}

func (f testLoginFixture) accountOf(t *testing.T, label string) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, f.pool.QueryRow(t.Context(),
		`SELECT account_id FROM auth_identities WHERE provider = 'test' AND subject = $1`, label).Scan(&id))
	return id
}

// 맞는 비밀이면 정상 로그인과 같은 LoginResponse이고, 같은 label은 같은 계정입니다.
func TestLogin_TestLoginIssuesLoginResponse(t *testing.T) {
	f := newTestLoginFixture(t)

	first := f.login(t, "e2e01")
	assert.Equal(t, true, first["isNewAccount"])
	assert.Equal(t, true, first["consentRequired"], "새 계정은 약관 동의가 필요합니다")
	assert.Equal(t, false, first["restoredFromDeletion"])
	accountID := f.accountOf(t, "e2e01")

	again := f.login(t, "e2e01")
	assert.Equal(t, false, again["isNewAccount"])
	assert.Equal(t, accountID, f.accountOf(t, "e2e01"))
	assert.Equal(t, 1, f.countTestIdentities(t))

	f.login(t, "e2e02")
	assert.NotEqual(t, accountID, f.accountOf(t, "e2e02"))
}

// 비밀이 없거나 틀리면 라우트가 없는 것처럼 404 route.not_found이고, 메서드가 틀려도 405로 존재를 드러내지 않습니다.
func TestLogin_TestLoginWrongSecretIsRouteNotFound(t *testing.T) {
	f := newTestLoginFixture(t)
	notFound := serve(f.handler, httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/test/v1/auth/nothing", nil))

	cases := map[string]*http.Request{
		"비밀 없음":       testLoginRequest(t, "", `{"label":"e2e01"}`),
		"틀린 비밀":       testLoginRequest(t, "wrong", `{"label":"e2e01"}`),
		"한 글자 다름":     testLoginRequest(t, testLoginSecret[:len(testLoginSecret)-1]+"X", `{"label":"e2e01"}`),
		"앞부분만 맞음":     testLoginRequest(t, testLoginSecret[:10], `{"label":"e2e01"}`),
		"뒤에 더 붙음":     testLoginRequest(t, testLoginSecret+"x", `{"label":"e2e01"}`),
		"비밀 없이 GET":   newBodyRequest(t, http.MethodGet, testLoginPath, contentTypeJSON, ""),
		"비밀 없이 본문 틀림": testLoginRequest(t, "", `{"label":"bad-label"}`),
	}
	for name, req := range cases {
		rec := serve(f.handler, req)
		require.Equal(t, http.StatusNotFound, rec.Code, "%s: %s", name, rec.Body.String())
		assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code, name)
		assert.Equal(t, notFound.Header().Get("Content-Type"), rec.Header().Get("Content-Type"), name)
	}
	assert.Zero(t, f.countTestIdentities(t))
	assert.NotContains(t, f.logs.String(), testLoginSecret[:10], "비밀은 로그에 남기지 않습니다")
}

// 맞는 비밀에서 POST가 아니면 405이고 Allow는 POST입니다.
func TestLogin_TestLoginMethodNotAllowed(t *testing.T) {
	f := newTestLoginFixture(t)
	req := newBodyRequest(t, http.MethodGet, testLoginPath, contentTypeJSON, "")
	req.Header.Set(testLoginSecretHeader, testLoginSecret)

	rec := serve(f.handler, req)

	require.Equal(t, http.StatusMethodNotAllowed, rec.Code, rec.Body.String())
	assert.Equal(t, http.MethodPost, rec.Header().Get("Allow"))
	assert.Equal(t, "method.not_allowed", decodeProblem(t, rec).Code)
}

// label은 영숫자 1~32자입니다. 어기면 400 request.invalid이고 field는 본문 JSON Pointer(/label)입니다.
func TestLogin_TestLoginInvalidLabel(t *testing.T) {
	f := newTestLoginFixture(t)
	cases := map[string]struct {
		body, code string
	}{
		"label 없음": {`{}`, "required"},
		"null":     {`{"label":null}`, "required"},
		"빈 문자열":    {`{"label":""}`, "pattern"},
		"33자":      {`{"label":"` + strings.Repeat("a", 33) + `"}`, "pattern"},
		"하이픈":      {`{"label":"e2e-01"}`, "pattern"},
		"한글":       {`{"label":"테스트"}`, "pattern"},
		"문자열 아님":   {`{"label":12}`, "type"},
	}
	for name, tc := range cases {
		rec := serve(f.handler, testLoginRequest(t, testLoginSecret, tc.body))
		require.Equal(t, http.StatusBadRequest, rec.Code, "%s: %s", name, rec.Body.String())
		p := decodeProblem(t, rec)
		assert.Equal(t, "request.invalid", p.Code, name)
		require.Len(t, p.Errors, 1, name)
		assert.Equal(t, "/label", p.Errors[0].Field, name)
		assert.Equal(t, tc.code, p.Errors[0].Code, name)
	}

	rec := serve(f.handler, testLoginRequest(t, testLoginSecret, `{not json`))
	require.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Equal(t, "request.malformed", decodeProblem(t, rec).Code)
	assert.Zero(t, f.countTestIdentities(t))
}

// 약관 동의 흐름은 정상 로그인과 같습니다. 현재 문서에 동의하면 다음 로그인부터 consentRequired가 false입니다.
func TestLogin_TestLoginConsentFlow(t *testing.T) {
	f := newTestLoginFixture(t)
	f.login(t, "e2e01")
	accountID := f.accountOf(t, "e2e01")

	docs := make([]account.ConsentDocument, 0, len(account.CurrentDocuments))
	for doc, version := range account.CurrentDocuments {
		docs = append(docs, account.ConsentDocument{Document: doc, Version: version})
	}
	require.NoError(t, f.accounts.AgreeConsents(t.Context(), accountID, docs))

	assert.Equal(t, false, f.login(t, "e2e01")["consentRequired"])
}

// 삭제 대기 계정은 정상 로그인처럼 되살아나고, 테스트 연결도 계정 삭제의 연결 해제를 거칩니다.
func TestLogin_TestLoginRestoresPendingDeletion(t *testing.T) {
	f := newTestLoginFixture(t)
	f.login(t, "e2e01")
	accountID := f.accountOf(t, "e2e01")
	_, err := f.accounts.RequestDeletion(t.Context(), accountID)
	require.NoError(t, err)
	var disconnected bool
	require.NoError(t, f.pool.QueryRow(t.Context(),
		`SELECT provider_disconnected_at IS NOT NULL FROM auth_identities WHERE account_id = $1`, accountID).Scan(&disconnected))
	assert.True(t, disconnected, "테스트 연결은 외부 호출 없이 해제된 것으로 기록됩니다")

	body := f.login(t, "e2e01")

	assert.Equal(t, true, body["restoredFromDeletion"])
	assert.Equal(t, false, body["isNewAccount"])
	assert.Equal(t, accountID, f.accountOf(t, "e2e01"))
}

// 로그에 비밀과 label을 남기지 않습니다(label은 테스트 계정의 subject입니다).
func TestLogin_TestLoginDoesNotLogSecretOrLabel(t *testing.T) {
	f := newTestLoginFixture(t)
	f.login(t, "uniqueLabel7x")

	assert.NotContains(t, f.logs.String(), testLoginSecret)
	assert.NotContains(t, f.logs.String(), "uniqueLabel7x")
}

// EnableTestLogin을 부르지 않은 API에는 staging 빌드여도 라우트가 없습니다.
func TestLogin_TestLoginNotEnabledIsRouteNotFound(t *testing.T) {
	real := newRealAuth(t)
	handler, _ := newHandlerAPI(t, &httpapi.API{Auth: real.auth, Accounts: real.accounts})

	rec := serve(handler, testLoginRequest(t, testLoginSecret, `{"label":"e2e01"}`))

	require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
	assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code)
	assert.Zero(t, real.countTestIdentities(t))
}

// 비어 있는 비밀이나 서비스로 켜는 것은 조립 버그라 panic합니다.
func TestLogin_EnableTestLoginRejectsEmptyConfig(t *testing.T) {
	real := newRealAuth(t)
	assert.Panics(t, func() { (&httpapi.API{}).EnableTestLogin("", real.auth) })
	assert.Panics(t, func() { (&httpapi.API{}).EnableTestLogin(testLoginSecret, nil) })
}

//go:build staging

package httpapi_test

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

// testGrantPath는 staging 테스트 광고 제거 기간(S125)의 경로입니다.
const testGrantPath = "/test/v1/billing/ad-free"

// newTestGrantFixture는 테스트 로그인과 테스트 광고 제거 기간을 함께 켠 Handler입니다.
func newTestGrantFixture(t *testing.T) testLoginFixture {
	t.Helper()
	real := newRealAuth(t)
	api := &httpapi.API{Auth: real.auth, Accounts: real.accounts}
	api.EnableTestLogin(testLoginSecret, real.auth)
	api.EnableTestGrant(billing.NewStore(real.pool, clocktest.New(handlerNow), nil))
	handler, spec, logs := newHandlerAPIWithLogs(t, api)
	return testLoginFixture{realAuth: real, handler: handler, spec: spec, logs: logs}
}

func testGrantRequest(t *testing.T, method, secret, target, body string) *http.Request {
	t.Helper()
	req := newBodyRequest(t, method, target, contentTypeJSON, body)
	if secret != "" {
		req.Header.Set(testLoginSecretHeader, secret)
	}
	return req
}

// entitlementsOf는 200 응답이 계약 Entitlements 스키마인지 확인하고 해석합니다.
func (f testLoginFixture) entitlementsOf(t *testing.T, req *http.Request) gen.Entitlements {
	t.Helper()
	rec := serve(f.handler, req)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	var raw map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
	require.NoError(t, f.spec.Components.Schemas["Entitlements"].Value.VisitJSON(raw), "계약 Entitlements 위반: %s", rec.Body.String())
	var got gen.Entitlements
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	return got
}

func (f testLoginFixture) countTestGrants(t *testing.T) int {
	t.Helper()
	var count int
	require.NoError(t, f.pool.QueryRow(t.Context(), `SELECT count(*) FROM entitlement_grants WHERE source = 'test_grant'`).Scan(&count))
	return count
}

// 맞는 비밀로 POST하면 지금부터 days일의 광고 제거와 근거 열람이 생기고, DELETE하면 바로 끝납니다.
func TestTestGrant_GrantThenRevoke(t *testing.T) {
	f := newTestGrantFixture(t)
	f.login(t, "grant01")
	accountID := f.accountOf(t, "grant01")

	got := f.entitlementsOf(t, testGrantRequest(t, http.MethodPost, testLoginSecret, testGrantPath,
		`{"accountId":"`+accountID.String()+`","days":30}`))
	assert.True(t, got.AdFree.Active)
	require.NotNil(t, got.AdFree.ExpiresAt)
	assert.True(t, handlerNow.Add(30*24*time.Hour).Equal(*got.AdFree.ExpiresAt))
	assert.True(t, got.Insight.Active)
	require.NotNil(t, got.Insight.Source)
	assert.Equal(t, gen.AdFreePass, *got.Insight.Source, "계약에는 같은 권한인 ad_free_pass로 보냄")

	revoked := f.entitlementsOf(t, testGrantRequest(t, http.MethodDelete, testLoginSecret, testGrantPath+"?accountId="+accountID.String(), ""))
	assert.False(t, revoked.AdFree.Active)
	assert.False(t, revoked.Insight.Active)
	assert.Equal(t, 2, f.countTestGrants(t), "회수는 행을 지우지 않고 끊음")
}

// 비밀이 없거나 틀리면 메서드와 관계없이 404 route.not_found입니다.
func TestTestGrant_WrongSecretIsRouteNotFound(t *testing.T) {
	f := newTestGrantFixture(t)
	f.login(t, "grant01")
	accountID := f.accountOf(t, "grant01").String()

	cases := map[string]*http.Request{
		"비밀 없이 POST":   testGrantRequest(t, http.MethodPost, "", testGrantPath, `{"accountId":"`+accountID+`","days":30}`),
		"틀린 비밀 POST":   testGrantRequest(t, http.MethodPost, "wrong", testGrantPath, `{"accountId":"`+accountID+`","days":30}`),
		"틀린 비밀 DELETE": testGrantRequest(t, http.MethodDelete, "wrong", testGrantPath+"?accountId="+accountID, ""),
		"비밀 없이 GET":    testGrantRequest(t, http.MethodGet, "", testGrantPath, ""),
	}
	for name, req := range cases {
		rec := serve(f.handler, req)
		require.Equal(t, http.StatusNotFound, rec.Code, "%s: %s", name, rec.Body.String())
		assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code, name)
	}
	assert.Zero(t, f.countTestGrants(t))
	assert.NotContains(t, f.logs.String(), testLoginSecret[:10], "비밀은 로그에 남기지 않습니다")
}

// 맞는 비밀에서 POST, DELETE가 아니면 405이고 Allow는 둘입니다.
func TestTestGrant_MethodNotAllowed(t *testing.T) {
	f := newTestGrantFixture(t)

	rec := serve(f.handler, testGrantRequest(t, http.MethodGet, testLoginSecret, testGrantPath, ""))

	require.Equal(t, http.StatusMethodNotAllowed, rec.Code, rec.Body.String())
	assert.Equal(t, "POST, DELETE", rec.Header().Get("Allow"))
	assert.Equal(t, "method.not_allowed", decodeProblem(t, rec).Code)
}

// accountId는 있는 계정의 UUID, days는 1~366 정수입니다. 어기면 400 request.invalid이고 아무것도 적지 않습니다.
func TestTestGrant_InvalidRequest(t *testing.T) {
	f := newTestGrantFixture(t)
	f.login(t, "grant01")
	accountID := f.accountOf(t, "grant01").String()
	unknown := uuid.New().String()

	cases := map[string]struct {
		method, target, body, field, code string
	}{
		"accountId 없음": {http.MethodPost, testGrantPath, `{"days":30}`, "/accountId", "required"},
		"accountId 형식": {http.MethodPost, testGrantPath, `{"accountId":"abc","days":30}`, "/accountId", "format"},
		"accountId 타입": {http.MethodPost, testGrantPath, `{"accountId":12,"days":30}`, "/accountId", "type"},
		"없는 계정":        {http.MethodPost, testGrantPath, `{"accountId":"` + unknown + `","days":30}`, "/accountId", "not_found"},
		"days 없음":      {http.MethodPost, testGrantPath, `{"accountId":"` + accountID + `"}`, "/days", "required"},
		"days 0":       {http.MethodPost, testGrantPath, `{"accountId":"` + accountID + `","days":0}`, "/days", "minimum"},
		"days 367":     {http.MethodPost, testGrantPath, `{"accountId":"` + accountID + `","days":367}`, "/days", "maximum"},
		"days 소수":      {http.MethodPost, testGrantPath, `{"accountId":"` + accountID + `","days":1.5}`, "/days", "type"},
		"DELETE 계정 없음": {http.MethodDelete, testGrantPath, "", "/accountId", "required"},
		"DELETE 계정 형식": {http.MethodDelete, testGrantPath + "?accountId=abc", "", "/accountId", "format"},
		"DELETE 없는 계정": {http.MethodDelete, testGrantPath + "?accountId=" + unknown, "", "/accountId", "not_found"},
	}
	for name, tc := range cases {
		rec := serve(f.handler, testGrantRequest(t, tc.method, testLoginSecret, tc.target, tc.body))
		require.Equal(t, http.StatusBadRequest, rec.Code, "%s: %s", name, rec.Body.String())
		p := decodeProblem(t, rec)
		assert.Equal(t, "request.invalid", p.Code, name)
		require.Len(t, p.Errors, 1, name)
		assert.Equal(t, tc.field, p.Errors[0].Field, name)
		assert.Equal(t, tc.code, p.Errors[0].Code, name)
	}
	assert.Zero(t, f.countTestGrants(t))
}

// 테스트 로그인만 켜고 테스트 광고 제거 기간을 켜지 않으면 경로가 없습니다.
func TestTestGrant_NotEnabledIsRouteNotFound(t *testing.T) {
	f := newTestLoginFixture(t)

	rec := serve(f.handler, testGrantRequest(t, http.MethodPost, testLoginSecret, testGrantPath, `{}`))

	require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
	assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code)
}

// 테스트 로그인(비밀)보다 먼저 켜거나 서비스가 없으면 조립 버그라 panic합니다.
func TestTestGrant_EnableRequiresTestLoginAndService(t *testing.T) {
	real := newRealAuth(t)
	store := billing.NewStore(real.pool, clocktest.New(handlerNow), nil)
	assert.Panics(t, func() { (&httpapi.API{}).EnableTestGrant(store) }, "테스트 로그인 없음")

	api := &httpapi.API{}
	api.EnableTestLogin(testLoginSecret, real.auth)
	assert.Panics(t, func() { api.EnableTestGrant(nil) }, "서비스 없음")
}

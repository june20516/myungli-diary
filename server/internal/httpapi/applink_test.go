package httpapi_test

import (
	"encoding/json"
	"html"
	"net/http"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

// hrefPattern은 안내 페이지의 링크 주소(href 속성 값)를 찾습니다.
var hrefPattern = regexp.MustCompile(`href="([^"]*)"`)

// pageLinks는 안내 페이지 본문의 링크 주소를 HTML 이스케이프를 풀어 돌려줍니다.
func pageLinks(body string) []string {
	var links []string
	for _, match := range hrefPattern.FindAllStringSubmatch(body, -1) {
		links = append(links, html.UnescapeString(match[1]))
	}
	return links
}

// getAppLinkPage는 rawQuery로 GET /auth/apple을 요청합니다.
func getAppLinkPage(t *testing.T, handler http.Handler, rawQuery string) *httptest.ResponseRecorder {
	t.Helper()
	target := "/auth/apple"
	if rawQuery != "" {
		target += "?" + rawQuery
	}
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, target, nil)
	return serve(handler, req)
}

// wantIntentLink는 query를 넘기는 Android intent 링크의 기대값입니다.
func wantIntentLink(t *testing.T, query url.Values) string {
	t.Helper()
	appLink := testAppLink(t)
	return "intent://app.myungli.example/auth/apple?" + query.Encode() +
		"#Intent;scheme=https;package=app.myungli.test;S.browser_fallback_url=" + url.QueryEscape(appLink.StoreURL) + ";end"
}

func TestAppLinkPage_HeadersAndIntentLink(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})

	rec := getAppLinkPage(t, handler, url.Values{"exchange": {testExchangeCode}, "state": {"s 1"}}.Encode())

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "text/html; charset=utf-8", rec.Header().Get("Content-Type"))
	assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))
	assert.Equal(t, "no-referrer", rec.Header().Get("Referrer-Policy"))
	assert.Equal(t, "nosniff", rec.Header().Get("X-Content-Type-Options"))
	assert.Equal(t, "default-src 'none'; style-src 'unsafe-inline'", rec.Header().Get("Content-Security-Policy"))

	body := rec.Body.String()
	assert.Contains(t, body, "명리일기 앱에서 계속해 주세요.")
	assert.NotContains(t, strings.ToLower(body), "<script", "안내 페이지는 스크립트를 쓰지 않습니다")
	wantIntent := wantIntentLink(t, url.Values{"exchange": {testExchangeCode}, "state": {"s 1"}})
	assert.Equal(t, []string{wantIntent, testAppLink(t).StoreURL}, pageLinks(body))
}

func TestAppLinkPage_EscapesQuery(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})
	state := `<script>alert("x")</script>' onmouseover=alert(1)`

	rec := getAppLinkPage(t, handler, url.Values{"exchange": {testExchangeCode}, "state": {state}}.Encode())

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	body := rec.Body.String()
	assert.NotContains(t, body, "<script>")
	assert.NotContains(t, body, `"x"`)
	assert.NotContains(t, body, "' onmouseover")

	links := pageLinks(body)
	require.Len(t, links, 2)
	intent, err := url.Parse(links[0])
	require.NoError(t, err)
	assert.Equal(t, "intent", intent.Scheme)
	assert.Equal(t, state, intent.Query().Get("state"), "state는 인코딩되어 앱에 그대로 전달됩니다")
	assert.Equal(t, testExchangeCode, intent.Query().Get("exchange"))
}

func TestAppLinkPage_MalformedExchangeShowsStoreOnly(t *testing.T) {
	tests := []struct {
		name, rawQuery string
	}{
		{"query 없음", ""},
		{"교환 코드 없음", "state=s"},
		{"오류 결과", "error=user_cancelled_authorize&state=s"},
		{"42자", url.Values{"exchange": {testExchangeCode[1:]}, "state": {"s"}}.Encode()},
		{"44자", url.Values{"exchange": {testExchangeCode + "A"}, "state": {"s"}}.Encode()},
		{"base64url이 아닌 문자", url.Values{"exchange": {"+" + testExchangeCode[1:]}, "state": {"s"}}.Encode()},
		{"패딩", url.Values{"exchange": {testExchangeCode[1:] + "="}, "state": {"s"}}.Encode()},
		{"교환 코드 뒤에 intent 조각", url.Values{"exchange": {testExchangeCode + "#Intent;end"}}.Encode()},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler, _ := newHandlerAPI(t, &httpapi.API{})

			rec := getAppLinkPage(t, handler, tt.rawQuery)

			require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
			assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))
			body := rec.Body.String()
			assert.Contains(t, body, "명리일기 앱에서 계속해 주세요.")
			assert.NotContains(t, body, "intent:")
			assert.Equal(t, []string{testAppLink(t).StoreURL}, pageLinks(body))
		})
	}
}

func TestAppLinkPage_RequestLogHasNoQuery(t *testing.T) {
	handler, _, logs := newHandlerAPIWithLogs(t, &httpapi.API{})

	rec := getAppLinkPage(t, handler, url.Values{"exchange": {testExchangeCode}, "state": {"state-secret"}}.Encode())

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, logs.String(), "GET /auth/apple", "요청 로그는 route를 남깁니다")
	assert.NotContains(t, logs.String(), testExchangeCode)
	assert.NotContains(t, logs.String(), "state-secret")
}

func TestAssetLinks_Content(t *testing.T) {
	appLink := testAppLink(t)
	appLink.CertSHA256 = append(appLink.CertSHA256, "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99")
	handler, _ := newHandlerAPI(t, &httpapi.API{AppLink: appLink})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/.well-known/assetlinks.json", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "application/json", rec.Header().Get("Content-Type"))
	assert.Equal(t, "public, max-age=3600", rec.Header().Get("Cache-Control"))
	want := `[{
		"relation": ["delegate_permission/common.handle_all_urls"],
		"target": {
			"namespace": "android_app",
			"package_name": "app.myungli.test",
			"sha256_cert_fingerprints": [` + mustJSON(t, appLink.CertSHA256[0]) + `, ` + mustJSON(t, appLink.CertSHA256[1]) + `]
		}
	}]`
	assert.JSONEq(t, want, rec.Body.String())
}

func TestAppLinkRoutes_OtherMethodsAre405(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})

	for _, target := range []string{"/auth/apple", "/.well-known/assetlinks.json"} {
		req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, target, nil)
		rec := serve(handler, req)

		assert.Equal(t, http.StatusMethodNotAllowed, rec.Code, target)
		assert.Equal(t, "method.not_allowed", decodeProblem(t, rec).Code, target)
	}
}

// mustJSON은 value를 JSON 문자열로 바꿉니다.
func mustJSON(t *testing.T, value any) string {
	t.Helper()
	encoded, err := json.Marshal(value)
	require.NoError(t, err)
	return string(encoded)
}

package httpapi_test

import (
	"bytes"
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

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/seed"
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
	assert.Contains(t, body, "명리일기 앱에서 이어서 로그인해 주세요.")
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
		{"계약 밖 error 값", "error=invalid_scope&state=s"},
		{"error와 HTML", url.Values{"error": {"<b>server_error</b>"}, "state": {"s"}}.Encode()},
		{"빈 error", "error=&state=s"},
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
			assert.Contains(t, body, "명리일기 앱에서 이어서 로그인해 주세요.")
			assert.NotContains(t, body, "intent:")
			assert.Equal(t, []string{testAppLink(t).StoreURL}, pageLinks(body))
		})
	}
}

func TestAppLinkPage_ContractErrorForwardsToApp(t *testing.T) {
	for _, appError := range []string{"user_cancelled_authorize", "token_invalid", "provider_unavailable", "invalid_request", "server_error"} {
		t.Run(appError, func(t *testing.T) {
			handler, _, logs := newHandlerAPIWithLogs(t, &httpapi.API{})

			rec := getAppLinkPage(t, handler, url.Values{"error": {appError}, "state": {"state-secret"}}.Encode())

			require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
			assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))
			assert.Equal(t, "no-referrer", rec.Header().Get("Referrer-Policy"))
			wantIntent := wantIntentLink(t, url.Values{"error": {appError}, "state": {"state-secret"}})
			assert.Equal(t, []string{wantIntent, testAppLink(t).StoreURL}, pageLinks(rec.Body.String()))
			assert.NotContains(t, logs.String(), "state-secret", "query 값은 로그에 남기지 않습니다")
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

// fakeTemplates는 (slot, key) -> 원문과 슬롯 명세를 가진 content.Templates 대역입니다.
type fakeTemplates struct {
	lang   string
	slots  map[string]seed.Slot
	bodies map[string]string
}

func (f fakeTemplates) Lang() string { return f.lang }

func (f fakeTemplates) Slot(id string) (seed.Slot, bool) {
	slot, ok := f.slots[id]
	return slot, ok
}

func (f fakeTemplates) Body(slot, key, _ string) (string, bool) {
	body, ok := f.bodies[slot+"/"+key]
	return body, ok
}

func (f fakeTemplates) ValueName(string, string) (string, bool) { return "", false }

// appReturnTemplates는 system.apple_return 원고 넷을 가진 lang의 문장 틀입니다. omit 키는 뺍니다.
func appReturnTemplates(lang, title, body, open, install string, omit ...string) fakeTemplates {
	bodies := map[string]string{
		"system.apple_return/apple_return.title":   title,
		"system.apple_return/apple_return.body":    body,
		"system.apple_return/apple_return.open":    open,
		"system.apple_return/apple_return.install": install,
	}
	for _, key := range omit {
		delete(bodies, "system.apple_return/"+key)
	}
	return fakeTemplates{
		lang:   lang,
		slots:  map[string]seed.Slot{"system.apple_return": {ID: "system.apple_return"}},
		bodies: bodies,
	}
}

func appReturnContents() *fakeContents {
	return &fakeContents{active: "v1", templates: map[string]content.Templates{
		"ja": appReturnTemplates("ja", "メオンリ日記", "アプリで続けてください。", "アプリで開く", "アプリをインストール"),
		"en": appReturnTemplates("en", "Myungli Diary", "Please continue in the app. <b>", "Open in app", "Install the app"),
	}}
}

func getAppLinkPageIn(t *testing.T, api *httpapi.API, language string) (*httptest.ResponseRecorder, *bytes.Buffer) {
	t.Helper()
	handler, _, logs := newHandlerAPIWithLogs(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/auth/apple?"+url.Values{"exchange": {testExchangeCode}}.Encode(), nil)
	if language != "" {
		req.Header.Set("Accept-Language", language)
	}
	return serve(handler, req), logs
}

func TestAppLinkPage_RendersScriptInRequestLanguage(t *testing.T) {
	rec, logs := getAppLinkPageIn(t, &httpapi.API{Contents: appReturnContents()}, "ja")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	body := rec.Body.String()
	assert.Contains(t, body, `<html lang="ja">`)
	assert.Contains(t, body, "<title>メオンリ日記</title>")
	assert.Contains(t, body, "<p>アプリで続けてください。</p>")
	assert.Contains(t, body, ">アプリで開く</a>")
	assert.Contains(t, body, ">アプリをインストール</a>")
	assert.NotContains(t, logs.String(), `"severity":"ERROR"`)
	assert.Len(t, pageLinks(body), 2, "교환 코드가 있으면 intent·스토어 링크가 그대로입니다")
}

func TestAppLinkPage_DefaultsToEnglishAndEscapesScript(t *testing.T) {
	rec, _ := getAppLinkPageIn(t, &httpapi.API{Contents: appReturnContents()}, "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	body := rec.Body.String()
	assert.Contains(t, body, `<html lang="en">`)
	assert.Contains(t, body, "<p>Please continue in the app. &lt;b&gt;</p>")
	assert.NotContains(t, body, "<b>")
}

func TestAppLinkPage_FallsBackToKoreanAndLogsOnce(t *testing.T) {
	missingOne := appReturnContents()
	missingOne.templates["ja"] = appReturnTemplates("ja", "t", "b", "o", "i", "apple_return.open")
	noSeed := &noSeedContents{appReturnContents()}
	tests := []struct {
		name string
		api  *httpapi.API
	}{
		{"Contents 없음", &httpapi.API{}},
		{"활성 시드 없음", &httpapi.API{Contents: noSeed}},
		{"그 언어 원고 없음", &httpapi.API{Contents: &fakeContents{active: "v1"}}},
		{"문장 하나가 없음(부분 대체 없음)", &httpapi.API{Contents: missingOne}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec, logs := getAppLinkPageIn(t, tt.api, "ja")

			require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
			body := rec.Body.String()
			assert.Contains(t, body, `<html lang="ko">`)
			assert.Contains(t, body, "<p>명리일기 앱에서 이어서 로그인해 주세요.</p>")
			assert.Contains(t, body, ">앱에서 열기</a>")
			assert.Contains(t, body, ">앱 설치하기</a>")
			assert.Equal(t, 1, strings.Count(logs.String(), `"severity":"ERROR"`), logs.String())
			assert.NotContains(t, logs.String(), testExchangeCode, "교환 코드는 로그에 남기지 않습니다")
		})
	}
}

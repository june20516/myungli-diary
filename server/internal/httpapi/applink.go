package httpapi

import (
	"bytes"
	"encoding/json"
	"html/template"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// appLinkPath는 Apple 웹 콜백이 redirect하는 App Link 경로이자 앱이 열리지 않을 때의 안내 페이지 경로입니다.
const appLinkPath = "/auth/apple"

// assetLinksPath는 Android가 App Link 소유를 확인하는 Digital Asset Links 파일 경로입니다.
const assetLinksPath = "/.well-known/assetlinks.json"

// AppLinkConfig는 Android App Link 설정입니다. 값의 형식은 시작 시점(cli의 parseAuthSettings)에 검증합니다.
type AppLinkConfig struct {
	// Base는 App Link 주소입니다(https, path 없음). Location과 intent 링크의 host가 됩니다.
	Base *url.URL
	// Package는 App Link를 받는 Android 앱의 패키지 이름입니다.
	Package string
	// CertSHA256은 앱 서명 인증서의 SHA-256 지문 목록입니다(대문자 hex, 콜론 구분).
	CertSHA256 []string
	// StoreURL은 앱이 설치되지 않았을 때 보낼 스토어 주소(https)입니다.
	StoreURL string
}

// location은 Base + /auth/apple에 query를 붙인 주소입니다. Base의 path·query·fragment는 쓰지 않습니다.
func (c AppLinkConfig) location(query url.Values) string {
	u := url.URL{Scheme: c.Base.Scheme, Host: c.Base.Host, Path: appLinkPath, RawQuery: query.Encode()}
	return u.String()
}

// intentURL은 Chrome이 앱을 직접 열게 하는 Android intent 링크입니다.
// 앱이 없으면 Chrome이 S.browser_fallback_url(스토어)로 보냅니다.
func (c AppLinkConfig) intentURL(query url.Values) string {
	return "intent://" + c.Base.Host + appLinkPath + "?" + query.Encode() +
		"#Intent;scheme=https;package=" + c.Package +
		";S.browser_fallback_url=" + url.QueryEscape(c.StoreURL) + ";end"
}

// exchangeCodePattern은 교환 코드 형식(256비트 난수의 base64url, 패딩 없음 → 43자)입니다.
var exchangeCodePattern = regexp.MustCompile(`^[A-Za-z0-9_-]{43}$`)

// appLinkPageTemplate은 앱이 열리지 않았을 때 보이는 안내 페이지입니다. 스크립트 없이 링크만 둡니다.
// html/template이 값을 문맥에 맞게 이스케이프합니다.
var appLinkPageTemplate = template.Must(template.New("applink").Parse(`<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>명리일기</title>
<style>body{font-family:sans-serif;margin:2rem;line-height:1.6}a{display:block;margin-top:1rem}</style>
</head>
<body>
<p>명리일기 앱에서 계속해 주세요.</p>
{{if .IntentURL}}<a href="{{.IntentURL}}">앱에서 열기</a>
{{end}}<a href="{{.StoreURL}}">앱 설치하기</a>
</body>
</html>
`))

// appLinkPageData는 안내 페이지 template의 값입니다. IntentURL이 비면 스토어 링크만 보입니다.
type appLinkPageData struct {
	IntentURL template.URL
	StoreURL  string
}

// assetLink는 assetlinks.json의 항목 하나입니다(Digital Asset Links 형식).
type assetLink struct {
	Relation []string        `json:"relation"`
	Target   assetLinkTarget `json:"target"`
}

type assetLinkTarget struct {
	Namespace              string   `json:"namespace"`
	PackageName            string   `json:"package_name"`
	SHA256CertFingerprints []string `json:"sha256_cert_fingerprints"`
}

// staticRoute는 계약 밖의 정적 경로 하나입니다.
type staticRoute struct {
	pattern string
	handler http.Handler
}

// staticRouter는 계약 밖 정적 경로를 내주는 구현입니다. *API가 만족하며, RegisterAPI가 직접 등록합니다.
type staticRouter interface {
	staticRoutes() []staticRoute
}

// staticRoutes는 App Link 안내 페이지와 assetlinks.json 경로입니다. 인증·계약 검증 없이 등록됩니다.
// AppLink 설정이 비어 있으면 시작 시점의 조립 버그이므로 panic합니다.
func (a *API) staticRoutes() []staticRoute {
	c := a.AppLink
	if c.Base == nil || c.Base.Host == "" || c.Package == "" || len(c.CertSHA256) == 0 || c.StoreURL == "" {
		panic("httpapi.API: AppLink의 Base·Package·CertSHA256·StoreURL이 모두 있어야 합니다")
	}
	assetLinks, err := json.Marshal([]assetLink{{
		Relation: []string{"delegate_permission/common.handle_all_urls"},
		Target: assetLinkTarget{
			Namespace:              "android_app",
			PackageName:            c.Package,
			SHA256CertFingerprints: c.CertSHA256,
		},
	}})
	if err != nil {
		panic("httpapi.API: assetlinks.json 만들기: " + err.Error())
	}
	logger := a.logger()
	return []staticRoute{
		{pattern: http.MethodGet + " " + appLinkPath, handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			serveAppLinkPage(c, logger, w, r)
		})},
		{pattern: http.MethodGet + " " + assetLinksPath, handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Cache-Control", "public, max-age=3600")
			writeBody(logger, w, r, assetLinks)
		})},
	}
}

// appLinkErrors는 Apple 웹 콜백이 Location에 담는 error 값입니다(계약 appleCallback 303 설명).
// 안내 페이지는 이 값만 앱에 넘깁니다.
var appLinkErrors = map[string]bool{
	appLinkErrorCancelled:           true,
	appLinkErrorTokenInvalid:        true,
	appLinkErrorProviderUnavailable: true,
	appLinkErrorInvalidRequest:      true,
	appLinkErrorServer:              true,
}

// serveAppLinkPage는 App Link가 앱을 열지 못해 브라우저로 온 요청에 안내 페이지를 줍니다.
// 교환 코드가 형식에 맞거나 error가 계약의 값이면 그 값과 state를 담은 intent 링크와 스토어 링크를,
// 아니면 스토어 링크만 보여 줍니다. query에는 교환 코드가 있어 응답을 캐시하지 않고 Referer로도 내보내지 않으며,
// query 값은 로그에 남기지 않습니다.
func serveAppLinkPage(c AppLinkConfig, logger *slog.Logger, w http.ResponseWriter, r *http.Request) {
	data := appLinkPageData{StoreURL: c.StoreURL}
	if forward, ok := appLinkForwardQuery(r.URL.Query()); ok {
		// intent: scheme은 html/template의 URL 필터가 막으므로 template.URL로 넘깁니다.
		// query 값은 Encode로 percent-encoding되고, 속성 값은 template이 다시 HTML 이스케이프합니다.
		data.IntentURL = template.URL(c.intentURL(forward)) //nolint:gosec // 고정 형식에 인코딩한 값만 넣습니다(위 설명)
	}

	var body bytes.Buffer
	if err := appLinkPageTemplate.Execute(&body, data); err != nil {
		logHandlerError(r.Context(), logger, err)
		problem.Write(w, r, problem.Internal.Problem("Internal server error"))
		return
	}
	header := w.Header()
	header.Set("Content-Type", "text/html; charset=utf-8")
	header.Set("Cache-Control", "no-store")
	header.Set("Referrer-Policy", "no-referrer")
	header.Set("X-Content-Type-Options", "nosniff")
	header.Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
	writeBody(logger, w, r, body.Bytes())
}

// appLinkForwardQuery는 안내 페이지가 intent 링크로 앱에 넘길 query입니다.
// 형식에 맞는 교환 코드(exchange)나 계약의 error 값 하나와, 있으면 state를 담습니다. 넘길 값이 없으면 false입니다.
func appLinkForwardQuery(query url.Values) (url.Values, bool) {
	var forward url.Values
	switch {
	case exchangeCodePattern.MatchString(query.Get("exchange")):
		forward = url.Values{"exchange": {query.Get("exchange")}}
	case appLinkErrors[query.Get("error")]:
		forward = url.Values{"error": {query.Get("error")}}
	default:
		return nil, false
	}
	if query.Has("state") {
		forward.Set("state", query.Get("state"))
	}
	return forward, true
}

// writeBody는 응답 본문을 씁니다. 실패는 대개 클라이언트가 연결을 끊은 것이라 응답을 바꿀 수 없으므로
// debug 로그로만 남깁니다(본문에는 교환 코드가 있을 수 있어 본문은 남기지 않습니다).
func writeBody(logger *slog.Logger, w http.ResponseWriter, r *http.Request, body []byte) {
	if _, err := w.Write(body); err != nil {
		logger.DebugContext(r.Context(), "응답 본문 쓰기 실패", "error", err.Error())
	}
}

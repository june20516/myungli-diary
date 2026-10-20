package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/content"
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
// 문구와 언어는 appLinkPageData가 채웁니다(writing 원고 system.apple_return, P6-15).
// html/template이 값을 문맥에 맞게 이스케이프합니다.
var appLinkPageTemplate = template.Must(template.New("applink").Parse(`<!doctype html>
<html lang="{{.Lang}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{{.Title}}</title>
<style>body{font-family:sans-serif;margin:2rem;line-height:1.6}a{display:block;margin-top:1rem}</style>
</head>
<body>
<p>{{.Body}}</p>
{{if .IntentURL}}<a href="{{.IntentURL}}">{{.Open}}</a>
{{end}}<a href="{{.StoreURL}}">{{.Install}}</a>
</body>
</html>
`))

// appLinkPageData는 안내 페이지 template의 값입니다. IntentURL이 비면 스토어 링크만 보입니다.
type appLinkPageData struct {
	IntentURL template.URL
	StoreURL  string
	appLinkTexts
}

// appLinkTexts는 안내 페이지의 언어와 문구 넷입니다. 한 페이지 안에서 언어가 섞이지 않도록 통째로 고릅니다.
type appLinkTexts struct {
	Lang, Title, Body, Open, Install string
}

// fallbackAppLinkTexts는 활성 시드나 원고를 쓰지 못할 때의 내장 한국어 문구입니다.
// 로그인 복귀 길을 막지 않으려는 것이라 writing 원고(ko)와 같은 뜻으로 두고, 원고가 바뀌어도 따라가지 않습니다.
var fallbackAppLinkTexts = appLinkTexts{
	Lang:    "ko",
	Title:   "명리일기",
	Body:    "명리일기 앱에서 계속해 주세요.",
	Open:    "앱에서 열기",
	Install: "앱 설치하기",
}

// appLinkSlot은 안내 페이지 문구의 writing 슬롯입니다. 키는 아래 네 개이고 매개변수와 호칭은 없습니다.
const appLinkSlot = "system.apple_return"

// renderAppLinkTexts는 활성 시드의 system.apple_return 원고를 lang으로 렌더한 문구 넷입니다.
// 활성 시드나 원고가 없거나 하나라도 렌더하지 못하면 오류를 돌려줍니다.
// 렌더러는 상태가 없어 호출마다 만들어도 되고, 문장별 실패 로그는 호출자가 대체 로그 하나로 남기도록 버립니다.
func (a *API) renderAppLinkTexts(ctx context.Context, lang string) (appLinkTexts, error) {
	if a.Contents == nil {
		return appLinkTexts{}, errors.New("콘텐츠 저장소가 연결되지 않았습니다")
	}
	version, err := a.Contents.Active(ctx)
	if err != nil {
		return appLinkTexts{}, fmt.Errorf("활성 시드 확인: %w", err)
	}
	tpl, err := a.Contents.Templates(ctx, version, lang)
	if err != nil {
		return appLinkTexts{}, fmt.Errorf("문장 틀 읽기: %w", err)
	}
	renderer := content.NewRenderer(slog.New(slog.DiscardHandler))
	texts := appLinkTexts{Lang: lang}
	for _, field := range []struct {
		key string
		dst *string
	}{
		{"apple_return.title", &texts.Title},
		{"apple_return.body", &texts.Body},
		{"apple_return.open", &texts.Open},
		{"apple_return.install", &texts.Install},
	} {
		sentence, ok := renderer.Identifier(ctx, tpl, appLinkSlot, field.key, nil)
		if !ok {
			return appLinkTexts{}, fmt.Errorf("%s 원고를 렌더하지 못했습니다", field.key)
		}
		var text strings.Builder
		for _, segment := range sentence.Text {
			text.WriteString(segment.Text)
		}
		*field.dst = text.String()
	}
	return texts, nil
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
			serveAppLinkPage(a, c, logger, w, r)
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
// query 값은 로그에 남기지 않습니다. 문구는 Accept-Language로 고른 언어의 원고입니다.
func serveAppLinkPage(a *API, c AppLinkConfig, logger *slog.Logger, w http.ResponseWriter, r *http.Request) {
	data := appLinkPageData{StoreURL: c.StoreURL}
	language := LanguageFrom(r.Context())
	texts, err := a.renderAppLinkTexts(r.Context(), language)
	if err != nil {
		// 원고를 못 쓴다고 로그인 복귀 길을 막지 않고, 문구 전체를 내장 한국어로 대체합니다(P6-15).
		logger.ErrorContext(r.Context(), "Apple 복귀 페이지 원고를 쓰지 못해 내장 한국어 문구로 대체합니다",
			"language", language, "error", err.Error())
		texts = fallbackAppLinkTexts
	}
	data.appLinkTexts = texts
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

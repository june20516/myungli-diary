package httpapi

import (
	"bytes"
	"html/template"
	"log/slog"
	"net/http"
	"net/url"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/legal"
)

// legalPathPrefix는 법적 문서 정적 페이지 경로의 앞부분입니다. 경로는 /legal/<문서 이름>입니다(D80).
const legalPathPrefix = "/legal/"

// legalPageTemplate은 법적 문서 페이지입니다. 스크립트 없이 원문 HTML만 둡니다.
// Body는 저장소 원문을 변환할 때 raw HTML을 걸러 낸 조각이라 template.HTML로 그대로 넣습니다(legal/convert).
var legalPageTemplate = template.Must(template.New("legal").Parse(`<!doctype html>
<html lang="{{.Lang}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Title}}</title>
<style>body{font-family:sans-serif;margin:0 auto;padding:1.5rem 1rem;max-width:44rem;line-height:1.7;word-break:keep-all;overflow-wrap:anywhere}table{border-collapse:collapse;display:block;overflow-x:auto}th,td{border:1px solid #ccc;padding:.4rem .6rem;text-align:left;vertical-align:top}</style>
</head>
<body>
<main>
{{.Body}}</main>
</body>
</html>
`))

// legalPageData는 법적 문서 페이지 template의 값입니다.
type legalPageData struct {
	Lang, Title string
	Body        template.HTML
}

// legalPendingTexts는 원문이 아직 없는 문서의 안내(404 페이지)입니다. 원문을 쓰기 전의 임시 상태라 writing 원고 대신 내장 문구를 씁니다.
var legalPendingTexts = map[string]struct{ title, body string }{
	"ko": {"준비 중", "문서를 준비하고 있어요. 잠시 뒤 다시 확인해 주세요."},
	"en": {"Coming soon", "This document is being prepared. Please check back later."},
	"ja": {"準備中", "この文書は準備中です。しばらくしてからもう一度ご確認ください。"},
}

// legalPath는 문서 이름의 정적 페이지 경로입니다.
func legalPath(name string) string {
	return legalPathPrefix + name
}

// legalURL은 base(서비스 도메인, App Link 주소와 같음)의 문서 주소입니다. base의 path·query·fragment는 쓰지 않습니다.
func legalURL(base *url.URL, name string) string {
	u := url.URL{Scheme: base.Scheme, Host: base.Host, Path: legalPath(name)}
	return u.String()
}

// legalRoutes는 법적 문서마다 정적 경로 하나입니다.
func (a *API) legalRoutes() []staticRoute {
	logger := a.logger()
	routes := make([]staticRoute, 0, len(legal.Names))
	for _, name := range legal.Names {
		routes = append(routes, staticRoute{
			pattern: http.MethodGet + " " + legalPath(name),
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				serveLegalPage(a.Legal, name, logger, w, r)
			}),
		})
	}
	return routes
}

// serveLegalPage는 문서 name을 query lang(ko·en·ja, 없거나 모르는 값이면 기본 언어 en)으로 내줍니다.
// 그 언어의 원문이 없으면 404와 준비 중 안내 페이지입니다(다른 언어로 대신하지 않음).
func serveLegalPage(docs legal.Documents, name string, logger *slog.Logger, w http.ResponseWriter, r *http.Request) {
	lang := r.URL.Query().Get("lang")
	if !supportedLanguages[lang] {
		lang = defaultLanguage
	}
	status := http.StatusOK
	data := legalPageData{Lang: lang}
	if doc, ok := docs.Get(lang, name); ok {
		data.Title = doc.Title
		data.Body = template.HTML(doc.HTML) //nolint:gosec // 저장소 원문을 raw HTML 없이 변환한 조각입니다(위 설명).
	} else {
		status = http.StatusNotFound
		pending := legalPendingTexts[lang]
		data.Title = pending.title
		data.Body = template.HTML("<p>" + template.HTMLEscapeString(pending.body) + "</p>\n") //nolint:gosec // 이스케이프한 내장 문구입니다.
	}

	var body bytes.Buffer
	if err := legalPageTemplate.Execute(&body, data); err != nil {
		logHandlerError(r.Context(), logger, err)
		problem.Write(w, r, problem.Internal.Problem("Internal server error"))
		return
	}
	header := w.Header()
	header.Set("Content-Type", "text/html; charset=utf-8")
	if status == http.StatusOK {
		header.Set("Cache-Control", "public, max-age=3600")
	} else {
		header.Set("Cache-Control", "no-store")
	}
	header.Set("X-Content-Type-Options", "nosniff")
	header.Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
	w.WriteHeader(status)
	writeBody(logger, w, r, body.Bytes())
}

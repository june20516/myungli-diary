package httpapi

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/legal"
)

// supportPath는 스토어 지원 URL로 쓰는 지원 페이지 경로입니다(D134, S161).
const supportPath = "/support"

// supportMail은 지원 페이지가 안내하는 문의 메일 주소입니다(E14). 원고의 {email} 자리에 넣고 mailto 링크로 감쌉니다.
const supportMail = "support@myungli-diary.app"

// supportSlot은 지원 페이지 문구의 writing 슬롯입니다(D66, W81). 키는 supportTexts의 열 개입니다.
const supportSlot = "system.support"

// supportPageTemplate은 지원 페이지입니다. 제목과 세 절(문의하기, 계정 삭제, 약관과 정책) 순서이고 스크립트가 없습니다.
// 링크는 같은 언어의 처리방침, 약관 페이지와 문의 메일뿐입니다(D134 ②). 모양은 법적 문서 페이지와 같습니다.
// html/template이 문구를 이스케이프하고, Email만 mailto 링크를 담은 조각입니다(supportEmailHTML).
var supportPageTemplate = template.Must(template.New("support").Parse(`<!doctype html>
<html lang="{{.Lang}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Title}}</title>
<style>body{font-family:sans-serif;margin:0 auto;padding:1.5rem 1rem;max-width:44rem;line-height:1.7;word-break:keep-all;overflow-wrap:anywhere}</style>
</head>
<body>
<main>
<h1>{{.Title}}</h1>
<h2>{{.ContactHead}}</h2>
<p>{{.ContactBody}}</p>
<p>{{.Email}}</p>
<h2>{{.DeleteHead}}</h2>
<p>{{.DeleteBody}}</p>
<p><a href="{{.PrivacyURL}}">{{.DeleteLink}}</a></p>
<h2>{{.LegalHead}}</h2>
<ul>
<li><a href="{{.PrivacyURL}}">{{.Privacy}}</a></li>
<li><a href="{{.TermsURL}}">{{.Terms}}</a></li>
</ul>
</main>
</body>
</html>
`))

// supportTexts는 지원 페이지 한 언어의 문구입니다. 한 페이지 안에서 언어가 섞이지 않도록 통째로 고릅니다.
type supportTexts struct {
	Title, ContactHead, ContactBody, DeleteHead, DeleteBody, DeleteLink, LegalHead, Privacy, Terms string
	// Email은 support.email.body를 렌더해 메일 주소를 mailto 링크로 감싼 HTML 조각입니다.
	Email template.HTML
}

// supportPageData는 지원 페이지 template의 값입니다.
type supportPageData struct {
	Lang                 string
	PrivacyURL, TermsURL string
	supportTexts
}

// supportRoute는 지원 페이지 정적 경로입니다.
func (a *API) supportRoute() staticRoute {
	logger := a.logger()
	return staticRoute{
		pattern: http.MethodGet + " " + supportPath,
		handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			a.serveSupportPage(logger, w, r)
		}),
	}
}

// serveSupportPage는 지원 페이지를 query lang(ko·en·ja, 없거나 모르는 값이면 기본 언어 en)으로 내줍니다.
// 그 언어의 원고를 렌더하지 못하면 다른 언어로 대신하지 않고 404 준비 중 페이지입니다(법적 문서 페이지와 같은 규칙).
func (a *API) serveSupportPage(logger *slog.Logger, w http.ResponseWriter, r *http.Request) {
	lang := r.URL.Query().Get("lang")
	if !supportedLanguages[lang] {
		lang = defaultLanguage
	}
	texts, err := a.renderSupportTexts(r.Context(), lang)
	if err != nil {
		logger.WarnContext(r.Context(), "지원 페이지 원고가 없어 준비 중 페이지를 내줍니다", "lang", lang, "error", err.Error())
		serveLegalPage(a.Legal, supportPendingName, logger, w, r)
		return
	}

	var body bytes.Buffer
	data := supportPageData{
		Lang:         lang,
		PrivacyURL:   legalPath(legal.Privacy) + "?" + url.Values{"lang": {lang}}.Encode(),
		TermsURL:     legalPath(legal.Terms) + "?" + url.Values{"lang": {lang}}.Encode(),
		supportTexts: texts,
	}
	if err := supportPageTemplate.Execute(&body, data); err != nil {
		logHandlerError(r.Context(), logger, err)
		problem.Write(w, r, problem.Internal.Problem("Internal server error"))
		return
	}
	header := w.Header()
	header.Set("Content-Type", "text/html; charset=utf-8")
	header.Set("Cache-Control", "public, max-age=3600")
	header.Set("X-Content-Type-Options", "nosniff")
	header.Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
	w.WriteHeader(http.StatusOK)
	writeBody(logger, w, r, body.Bytes())
}

// supportPendingName은 준비 중 페이지를 내줄 때 쓰는 문서 이름입니다. 법적 문서에 없는 이름이라 늘 404 준비 중 안내가 됩니다.
const supportPendingName = "support"

// renderSupportTexts는 활성 시드의 system.support 원고를 lang으로 렌더한 문구입니다.
// 활성 시드나 원고가 없거나 하나라도 렌더하지 못하면 오류입니다.
// 렌더러는 상태가 없어 호출마다 만들어도 되고, 문장별 실패 로그는 호출자가 경고 하나로 남기도록 버립니다.
func (a *API) renderSupportTexts(ctx context.Context, lang string) (supportTexts, error) {
	if a.Contents == nil {
		return supportTexts{}, errors.New("콘텐츠 저장소가 연결되지 않았습니다")
	}
	version, err := a.Contents.Active(ctx)
	if err != nil {
		return supportTexts{}, fmt.Errorf("활성 시드 확인: %w", err)
	}
	tpl, err := a.Contents.Templates(ctx, version, lang)
	if err != nil {
		return supportTexts{}, fmt.Errorf("문장 틀 읽기: %w", err)
	}
	renderer := content.NewRenderer(slog.New(slog.DiscardHandler))
	renderText := func(key string, params map[string]render.Value) (string, error) {
		sentence, ok := renderer.Identifier(ctx, tpl, supportSlot, key, params, "")
		if !ok {
			return "", fmt.Errorf("%s 원고를 렌더하지 못했습니다", key)
		}
		var text strings.Builder
		for _, segment := range sentence.Text {
			text.WriteString(segment.Text)
		}
		return text.String(), nil
	}

	var texts supportTexts
	for _, field := range []struct {
		key string
		dst *string
	}{
		{"support.title", &texts.Title},
		{"support.contact.head", &texts.ContactHead},
		{"support.contact.body", &texts.ContactBody},
		{"support.delete.head", &texts.DeleteHead},
		{"support.delete.body", &texts.DeleteBody},
		{"support.delete.link", &texts.DeleteLink},
		{"support.legal.head", &texts.LegalHead},
		{"support.legal.privacy", &texts.Privacy},
		{"support.legal.terms", &texts.Terms},
	} {
		if *field.dst, err = renderText(field.key, nil); err != nil {
			return supportTexts{}, err
		}
	}
	email, err := renderText("support.email.body", map[string]render.Value{"email": {Kind: render.ValueText, Text: supportMail}})
	if err != nil {
		return supportTexts{}, err
	}
	texts.Email = supportEmailHTML(email)
	return texts, nil
}

// supportEmailHTML은 렌더한 문장을 이스케이프하고, 그 안의 메일 주소를 mailto 링크로 감쌉니다.
// 주소에는 HTML 특수 문자가 없어 이스케이프 뒤에도 글자 그대로 찾을 수 있습니다.
func supportEmailHTML(sentence string) template.HTML {
	escaped := template.HTMLEscapeString(sentence)
	link := `<a href="mailto:` + supportMail + `">` + supportMail + `</a>`
	return template.HTML(strings.ReplaceAll(escaped, supportMail, link)) //nolint:gosec // 이스케이프한 문장에 고정 주소 링크만 넣습니다.
}

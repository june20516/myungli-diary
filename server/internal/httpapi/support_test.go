package httpapi_test

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/seed"
)

// supportTemplates는 system.support 원고 열 개를 가진 lang의 문장 틀입니다. 문구 앞에 prefix를 붙이고, omit 키는 뺍니다.
func supportTemplates(lang, prefix string, omit ...string) fakeTemplates {
	bodies := map[string]string{}
	for _, key := range []string{
		"support.title", "support.contact.head", "support.contact.body", "support.delete.head", "support.delete.body",
		"support.delete.link", "support.legal.head", "support.legal.privacy", "support.legal.terms",
	} {
		bodies["system.support/"+key] = prefix + " " + key
	}
	bodies["system.support/support.email.body"] = prefix + " 앱을 열 수 없으면 {email}로 보내 주세요. <b>"
	for _, key := range omit {
		delete(bodies, "system.support/"+key)
	}
	return fakeTemplates{
		lang: lang,
		slots: map[string]seed.Slot{"system.support": {
			ID:     "system.support",
			Params: map[string]seed.ParamKind{"email": {Kind: seed.KindText}},
		}},
		bodies: bodies,
	}
}

// getSupport는 contents(nil이면 콘텐츠 저장소 없음)를 쓰는 server에 target을 요청합니다.
func getSupport(t *testing.T, contents *fakeContents, target string) *httptest.ResponseRecorder {
	t.Helper()
	api := &httpapi.API{}
	if contents != nil {
		api.Contents = contents
	}
	handler, _ := newHandlerAPI(t, api)
	return serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, target, nil))
}

// supportContents는 ko, en 원고가 모두 있고 ja는 약관 링크 글자가 빠진 시드입니다.
func supportContents() *fakeContents {
	return &fakeContents{active: "v1", templates: map[string]content.Templates{
		"ko": supportTemplates("ko", "가"),
		"en": supportTemplates("en", "A"),
		"ja": supportTemplates("ja", "ア", "support.legal.terms"),
	}}
}

// 제목과 세 절을 순서대로 그리고, 링크는 같은 언어의 처리방침, 약관과 문의 메일뿐입니다(D134, S161).
func TestSupportPage_RendersSectionsAndLinks(t *testing.T) {
	rec := getSupport(t, supportContents(), "/support?lang=ko")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	body := rec.Body.String()
	assert.Contains(t, body, `<html lang="ko">`)
	assert.Contains(t, body, "<title>가 support.title</title>")
	order := []string{
		"<h1>가 support.title</h1>",
		"<h2>가 support.contact.head</h2>", "<p>가 support.contact.body</p>",
		`<p>가 앱을 열 수 없으면 <a href="mailto:support@myungli-diary.app">support@myungli-diary.app</a>로 보내 주세요. &lt;b&gt;</p>`,
		"<h2>가 support.delete.head</h2>", "<p>가 support.delete.body</p>",
		`<p><a href="/legal/privacy?lang=ko">가 support.delete.link</a></p>`,
		"<h2>가 support.legal.head</h2>",
		`<li><a href="/legal/privacy?lang=ko">가 support.legal.privacy</a></li>`,
		`<li><a href="/legal/terms?lang=ko">가 support.legal.terms</a></li>`,
	}
	last := -1
	for _, part := range order {
		at := strings.Index(body, part)
		require.GreaterOrEqual(t, at, 0, "없음: %s\n%s", part, body)
		assert.Greater(t, at, last, "순서: %s", part)
		last = at
	}
	assert.NotContains(t, body, "<b>", "원고 글자는 이스케이프")
	assert.Equal(t, 4, strings.Count(body, "<a href="), "링크는 메일, 처리방침 둘, 약관뿐")
	header := rec.Header()
	assert.Equal(t, "text/html; charset=utf-8", header.Get("Content-Type"))
	assert.Equal(t, "public, max-age=3600", header.Get("Cache-Control"))
	assert.Equal(t, "nosniff", header.Get("X-Content-Type-Options"))
	assert.Equal(t, "default-src 'none'; style-src 'unsafe-inline'", header.Get("Content-Security-Policy"))
}

// lang이 없거나 모르는 값이면 기본 언어 en입니다.
func TestSupportPage_MissingOrUnknownLangIsEnglish(t *testing.T) {
	for _, target := range []string{"/support", "/support?lang=fr", "/support?lang=KO"} {
		rec := getSupport(t, supportContents(), target)

		require.Equal(t, http.StatusOK, rec.Code, target)
		assert.Contains(t, rec.Body.String(), `<html lang="en">`, target)
		assert.Contains(t, rec.Body.String(), `<a href="/legal/terms?lang=en">A support.legal.terms</a>`, target)
	}
}

// 원고가 하나라도 없거나 활성 시드가 없으면 다른 언어로 대신하지 않고 404 준비 중 페이지입니다.
func TestSupportPage_MissingScriptIsPendingPage(t *testing.T) {
	cases := map[string]struct {
		contents *fakeContents
		target   string
		text     string
	}{
		"키 하나 없음":    {supportContents(), "/support?lang=ja", "この文書は準備中です。"},
		"언어 원고 없음":   {&fakeContents{active: "v1", templates: map[string]content.Templates{}}, "/support?lang=ko", "문서를 준비하고 있어요."},
		"콘텐츠 저장소 없음": {nil, "/support", "This document is being prepared."},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			rec := getSupport(t, tc.contents, tc.target)

			require.Equal(t, http.StatusNotFound, rec.Code)
			assert.Contains(t, rec.Body.String(), tc.text)
			assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"), "원고가 생기면 바로 보이도록 캐시하지 않음")
		})
	}
}

// 내장 시드의 실제 writing 원고(W81)로 세 언어 페이지가 모두 그려지고, 문의 메일이 mailto 링크가 됩니다.
// 원고에서 키가 빠지거나 {email} 자리가 사라지면 여기서 잡습니다.
func TestSupportPage_EmbeddedSeedRendersAllLanguages(t *testing.T) {
	embedded, err := seed.Load()
	require.NoError(t, err)
	templates := map[string]content.Templates{}
	for _, lang := range []string{"ko", "en", "ja"} {
		tpl := fakeTemplates{lang: lang, slots: map[string]seed.Slot{"system.support": embedded.Slots["system.support"]}, bodies: map[string]string{}}
		for _, row := range embedded.Templates {
			if row.Slot == "system.support" && row.Lang == lang {
				tpl.bodies[row.Slot+"/"+row.Key] = row.Body
			}
		}
		templates[lang] = tpl
	}
	contents := &fakeContents{active: embedded.Version, templates: templates}

	for _, lang := range []string{"ko", "en", "ja"} {
		rec := getSupport(t, contents, "/support?lang="+lang)

		require.Equal(t, http.StatusOK, rec.Code, lang)
		body := rec.Body.String()
		assert.Contains(t, body, `<a href="mailto:support@myungli-diary.app">support@myungli-diary.app</a>`, lang)
		assert.Equal(t, 2, strings.Count(body, `href="/legal/privacy?lang=`+lang+`"`), lang)
		assert.Contains(t, body, `href="/legal/terms?lang=`+lang+`"`, lang)
		main := body[strings.Index(body, "<main>"):]
		assert.NotContains(t, main, "{", "남은 자리표시자 없음: "+lang)
	}
}

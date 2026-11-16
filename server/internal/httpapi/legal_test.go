package httpapi_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/legal"
)

// getLegal은 ko 이용약관과 en 개인정보 처리방침만 있는 server에 target을 요청합니다.
func getLegal(t *testing.T, target string) *httptest.ResponseRecorder {
	t.Helper()
	docs, err := legal.New([]legal.Document{
		{Lang: "ko", Name: legal.Terms, Title: "이용약관", HTML: "<h1>이용약관</h1>\n<p>제1조</p>\n"},
		{Lang: "en", Name: legal.Privacy, Title: "Privacy Policy", HTML: "<h1>Privacy Policy</h1>\n"},
	})
	require.NoError(t, err)
	handler, _ := newHandlerAPI(t, &httpapi.API{Legal: docs})
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, target, nil)
	return serve(handler, req)
}

func TestLegalPage_ServesDocumentInRequestedLanguage(t *testing.T) {
	rec := getLegal(t, "/legal/terms?lang=ko")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	body := rec.Body.String()
	assert.Contains(t, body, `<html lang="ko">`)
	assert.Contains(t, body, "<title>이용약관</title>")
	assert.Contains(t, body, "<p>제1조</p>", "원문 HTML을 이스케이프하지 않고 넣음")
	header := rec.Header()
	assert.Equal(t, "text/html; charset=utf-8", header.Get("Content-Type"))
	assert.Equal(t, "public, max-age=3600", header.Get("Cache-Control"))
	assert.Equal(t, "nosniff", header.Get("X-Content-Type-Options"))
	assert.Equal(t, "default-src 'none'; style-src 'unsafe-inline'", header.Get("Content-Security-Policy"))
}

// lang이 없거나 모르는 값이면 기본 언어 en입니다.
func TestLegalPage_MissingOrUnknownLangIsEnglish(t *testing.T) {
	for _, target := range []string{"/legal/privacy", "/legal/privacy?lang=fr", "/legal/privacy?lang=KO"} {
		rec := getLegal(t, target)

		require.Equal(t, http.StatusOK, rec.Code, target)
		assert.Contains(t, rec.Body.String(), `<html lang="en">`, target)
		assert.Contains(t, rec.Body.String(), "<title>Privacy Policy</title>", target)
	}
}

// 그 언어의 원문이 없으면 다른 언어로 대신하지 않고 404 준비 중 페이지입니다.
func TestLegalPage_MissingDocumentIsPendingPage(t *testing.T) {
	cases := []struct {
		target, lang, text string
	}{
		{"/legal/terms?lang=en", "en", "This document is being prepared."},
		{"/legal/privacy?lang=ko", "ko", "문서를 준비하고 있어요."},
		{"/legal/terms?lang=ja", "ja", "この文書は準備中です。"},
	}
	for _, tc := range cases {
		rec := getLegal(t, tc.target)

		require.Equal(t, http.StatusNotFound, rec.Code, tc.target)
		assert.Contains(t, rec.Body.String(), `<html lang="`+tc.lang+`">`, tc.target)
		assert.Contains(t, rec.Body.String(), tc.text, tc.target)
		assert.Equal(t, "text/html; charset=utf-8", rec.Header().Get("Content-Type"))
		assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"), "원문이 생기면 바로 보이도록 캐시하지 않음")
	}
}

func TestLegalPage_EmptyDocumentsArePending(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})
	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/legal/terms", nil))

	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Contains(t, rec.Body.String(), "Coming soon")
}

func TestLegalPage_OnlyGetAndKnownNames(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/legal/terms", nil))
	assert.Equal(t, http.StatusMethodNotAllowed, rec.Code)
	rec = serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/legal/refund", nil))
	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "application/problem+json", rec.Header().Get("Content-Type"), "모르는 문서는 다른 경로처럼 problem 404")
}

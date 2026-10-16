package httpapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

func glossaryContents() *fakeContents {
	return &fakeContents{
		active: "v1",
		glossary: content.Glossary{
			Values: map[string]map[string]string{"element": {"wood": "나무"}, "tag": {"ten_god_rush.siksang": "식상 몰림"}},
			Meanings: map[string][]render.Segment{
				"element.wood": {{Text: "나무", Term: "element.wood"}, {Text: "처럼 자라는 기운"}},
			},
			Hanja: map[string]string{"element.wood": "木"},
		},
	}
}

// getGlossary는 용어 사전 요청을 보냅니다. ifNoneMatch가 비어 있지 않으면 If-None-Match에 싣습니다.
func getGlossary(t *testing.T, api *httpapi.API, target, ifNoneMatch string) (*http.Request, *httptest.ResponseRecorder) {
	t.Helper()
	handler, _ := newHandlerAPI(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, target, nil)
	if ifNoneMatch != "" {
		req.Header.Set("If-None-Match", ifNoneMatch)
	}
	return req, serve(handler, req)
}

func TestGetGlossary_Returns200AndETag(t *testing.T) {
	contents := glossaryContents()
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Contents: contents}

	req, rec := getGlossary(t, api, "/v1/glossary", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, `"v1-ko"`, rec.Header().Get("ETag"))
	assert.Equal(t, "ko", contents.gotGlossaryLang, "lang이 없으면 프로필 언어")
	assert.JSONEq(t, `{
		"seedVersion": "v1",
		"lang": "ko",
		"values": {"element": {"wood": "나무"}, "tag": {"ten_god_rush.siksang": "식상 몰림"}},
		"meanings": {"element.wood": {"segments": [{"text": "나무", "term": "element.wood"}, {"text": "처럼 자라는 기운"}]}},
		"hanja": {"element.wood": "木"}
	}`, rec.Body.String())
}

func TestGetGlossary_IfNoneMatchIs304(t *testing.T) {
	tests := []struct {
		name, ifNoneMatch string
		want              int
	}{
		{"같은 ETag", `"v1-ko"`, http.StatusNotModified},
		{"약한 비교", `W/"v1-ko"`, http.StatusNotModified},
		{"목록 중 하나", `"v0-ko", "v1-ko"`, http.StatusNotModified},
		{"모두", `*`, http.StatusNotModified},
		{"다른 버전", `"v0-ko"`, http.StatusOK},
		{"다른 언어", `"v1-en"`, http.StatusOK},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			contents := glossaryContents()
			api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Contents: contents}

			req, rec := getGlossary(t, api, "/v1/glossary", tt.ifNoneMatch)

			require.Equal(t, tt.want, rec.Code, rec.Body.String())
			expectFortuneContract(t, req, rec)
			assert.Equal(t, `"v1-ko"`, rec.Header().Get("ETag"))
			if tt.want == http.StatusNotModified {
				assert.Empty(t, rec.Body.String(), "304는 본문 없음")
				assert.Zero(t, contents.glossaryCalls, "사전을 만들지 않음")
			}
		})
	}
}

func TestGetGlossary_LangParamOverridesProfile(t *testing.T) {
	contents := glossaryContents()
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Contents: contents}

	req, rec := getGlossary(t, api, "/v1/glossary?lang=en", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, "en", contents.gotGlossaryLang)
	assert.Equal(t, `"v1-en"`, rec.Header().Get("ETag"))
}

func TestGetGlossary_LangParamNeedsNoProfile(t *testing.T) {
	contents := glossaryContents()
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Contents: contents}

	_, rec := getGlossary(t, api, "/v1/glossary?lang=ja", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "ja", contents.gotGlossaryLang)
}

func TestGetGlossary_NoLangAndNoProfileIs409(t *testing.T) {
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Contents: glossaryContents()}

	req, rec := getGlossary(t, api, "/v1/glossary", "")

	require.Equal(t, http.StatusConflict, rec.Code, rec.Body.String())
	assert.Equal(t, "profile.required", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
}

func TestGetGlossary_NoActiveSeedIs503(t *testing.T) {
	contents := glossaryContents()
	contents.active = ""
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Contents: &noSeedContents{contents}}

	_, rec := getGlossary(t, api, "/v1/glossary", "")

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
}

// noSeedContents는 활성 시드가 없는 Contents 대역입니다.
type noSeedContents struct{ *fakeContents }

func (noSeedContents) Active(context.Context) (string, error) { return "", content.ErrNoActiveSeed }

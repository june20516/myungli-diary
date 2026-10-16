package httpapi

import (
	"context"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// GetGlossary는 용어 사전을 돌려줍니다. lang이 없으면 프로필 언어이고, 그때 프로필이 없으면 409 profile.required입니다.
// ETag는 "<시드 버전>-<언어>"(강한 ETag)이며 If-None-Match가 맞으면 본문 없이 304입니다.
// 활성 콘텐츠 시드가 없으면 503 service.unavailable입니다.
func (a *API) GetGlossary(ctx context.Context, req gen.GetGlossaryRequestObject) (gen.GetGlossaryResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Contents == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	var lang string
	if req.Params.Lang != nil {
		lang = string(*req.Params.Lang)
	} else {
		p, err := a.Profiles.Get(ctx, id)
		if err != nil {
			return nil, err
		}
		lang = p.Language
	}
	version, err := a.Contents.Active(ctx)
	if err != nil {
		return nil, err
	}
	etag := glossaryETag(version, lang)
	if req.Params.IfNoneMatch != nil && etagMatches(*req.Params.IfNoneMatch, etag) {
		return gen.GetGlossary304Response{Headers: gen.NotModifiedResponseHeaders{ETag: &etag}}, nil
	}
	g, err := a.Contents.Glossary(ctx, version, lang)
	if err != nil {
		return nil, err
	}
	return gen.GetGlossary200JSONResponse{Body: toGlossary(g), Headers: gen.GetGlossary200ResponseHeaders{ETag: &etag}}, nil
}

// glossaryETag는 용어 사전의 강한 ETag입니다. 시드 버전은 내용 지문이라 (버전, 언어)가 같으면 본문이 같습니다.
func glossaryETag(version, lang string) string {
	return `"` + version + "-" + lang + `"`
}

// etagMatches는 If-None-Match 값이 etag와 맞는지 봅니다(RFC 9110 §13.1.2).
// If-None-Match는 약한 비교라 W/ 접두어를 무시하고, *는 무엇이든 맞습니다. 값은 쉼표로 나뉜 목록일 수 있습니다.
func etagMatches(ifNoneMatch, etag string) bool {
	for candidate := range strings.SplitSeq(ifNoneMatch, ",") {
		candidate = strings.TrimSpace(candidate)
		if candidate == "*" || strings.TrimPrefix(candidate, "W/") == etag {
			return true
		}
	}
	return false
}

// toGlossary는 용어 사전을 계약 Glossary로 옮깁니다. 맵 필드는 비어 있어도 null이 아닌 빈 객체로 씁니다.
func toGlossary(g content.Glossary) gen.Glossary {
	meanings := make(map[string]gen.RenderedText, len(g.Meanings))
	for term, segments := range g.Meanings {
		meanings[term] = renderedText(segments)
	}
	return gen.Glossary{
		SeedVersion: g.SeedVersion,
		Lang:        gen.Language(g.Lang),
		Values:      nonNilMap(g.Values),
		Meanings:    meanings,
		Hanja:       nonNilMap(g.Hanja),
	}
}

// nonNilMap은 nil 맵을 빈 맵으로 바꿉니다. JSON에서 필수 객체 필드가 null이 되지 않게 합니다.
func nonNilMap[K comparable, V any](m map[K]V) map[K]V {
	if m == nil {
		return map[K]V{}
	}
	return m
}

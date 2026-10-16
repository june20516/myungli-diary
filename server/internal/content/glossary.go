package content

import (
	"context"
	"fmt"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/seed"
)

// 용어 사전(Glossary)에 이름을 싣는 슬롯과 그 범주입니다. glossary.value_name은 키의 <범주>가 범주입니다.
const (
	tagLabelSlot    = "daily.tag_label"
	focusReasonSlot = "daily.focus_reason"
	scoreItemSlot   = "calendar.score_item"
	solarTermSlot   = "calendar.solar_term"
	termMeaningSlot = "term.meaning"

	// tagKeyPrefix는 daily.tag_label 키의 접두어입니다. 사전의 tag 범주 키는 이 접두어를 뗀 값입니다.
	tagKeyPrefix = "tag."
	// termMeaningPrefix는 term.meaning 키의 접두어입니다. 뒤가 용어 id입니다.
	termMeaningPrefix = "term."
)

// namedSlotCategory는 키가 그대로 값인 이름 슬롯 -> 사전 범주입니다.
var namedSlotCategory = map[string]string{
	focusReasonSlot: "focus_reason",
	scoreItemSlot:   "score_item",
	solarTermSlot:   "solar_term",
}

// Glossary는 한 시드 버전·한 언어의 용어 사전입니다(계약 Glossary).
type Glossary struct {
	SeedVersion, Lang string
	// Values는 범주 -> (값 -> 이름)입니다. 범주는 glossary.value_name 키의 <범주>와 tag, focus_reason, score_item, solar_term입니다.
	// tag 범주의 값은 daily.tag_label 키에서 tag. 접두어를 뗀 것입니다(예 ten_god_rush.siksang).
	Values map[string]map[string]string
	// Meanings는 용어 id -> 뜻 문장(term.meaning 슬롯, 키 term.<용어 id>)입니다.
	Meanings map[string][]render.Segment
	// Hanja는 용어 id -> 한자 표기입니다. 언어와 상관없고, 원고에 있는 용어만 키가 있습니다.
	Hanja map[string]string
}

// Glossary는 version·lang의 용어 사전을 돌려줍니다. 한 번 만든 것은 메모리에 두고 다시 만들지 않습니다.
// 원고가 렌더되지 않으면(자리표시자 등) 오류이며, 오류 메시지에는 원고 본문을 싣지 않습니다.
func (s *Store) Glossary(ctx context.Context, version, lang string) (Glossary, error) {
	key := cacheKey{version, lang}
	if g, ok := s.cachedGlossary(key); ok {
		return g, nil
	}
	tpl, err := s.Templates(ctx, version, lang)
	if err != nil {
		return Glossary{}, err
	}
	t, ok := tpl.(*templates)
	if !ok {
		return Glossary{}, fmt.Errorf("문장 틀 형식이 잘못됐습니다: %T", tpl)
	}
	g, err := buildGlossary(t, version)
	if err != nil {
		return Glossary{}, err
	}
	rows, err := s.queries.ListHanja(ctx, version)
	if err != nil {
		return Glossary{}, fmt.Errorf("한자 표기 조회: %w", err)
	}
	for _, r := range rows {
		g.Hanja[r.Term] = r.Hanja
	}
	// 같은 키를 동시에 만들면 같은 내용을 두 번 넣을 뿐이라 합치지 않습니다.
	s.glossaryMu.Lock()
	s.glossaries[key] = g
	s.glossaryMu.Unlock()
	return g, nil
}

func (s *Store) cachedGlossary(key cacheKey) (Glossary, bool) {
	s.glossaryMu.Lock()
	defer s.glossaryMu.Unlock()
	g, ok := s.glossaries[key]
	return g, ok
}

// buildGlossary는 문장 틀에서 이름과 뜻을 모읍니다. Hanja는 빈 맵으로 둡니다.
func buildGlossary(t *templates, version string) (Glossary, error) {
	g := Glossary{
		SeedVersion: version,
		Lang:        t.lang,
		Values:      map[string]map[string]string{},
		Meanings:    map[string][]render.Segment{},
		Hanja:       map[string]string{},
	}
	for id, body := range t.bodies {
		if id.variant != seed.VariantSingle {
			continue
		}
		category, value, term := glossaryEntry(id)
		if category == "" && term == "" {
			continue
		}
		segments, err := render.Render(render.Input{Lang: t.lang, Body: body}, t)
		if err != nil {
			return Glossary{}, fmt.Errorf("용어 사전 %s/%s 렌더: %w", id.slot, id.key, err)
		}
		if term != "" {
			g.Meanings[term] = segments
			continue
		}
		if g.Values[category] == nil {
			g.Values[category] = map[string]string{}
		}
		g.Values[category][value] = joinSegments(segments)
	}
	return g, nil
}

// glossaryEntry는 문장 틀이 사전의 어디에 들어가는지 정합니다.
// 이름이면 (범주, 값, ""), 뜻이면 ("", "", 용어 id), 사전에 넣지 않으면 모두 빈 문자열입니다.
func glossaryEntry(id templateID) (category, value, term string) {
	switch id.slot {
	case valueNameSlot:
		if c, v, ok := strings.Cut(id.key, "."); ok {
			return c, v, ""
		}
	case tagLabelSlot:
		if v, ok := strings.CutPrefix(id.key, tagKeyPrefix); ok {
			return "tag", v, ""
		}
	case termMeaningSlot:
		if t, ok := strings.CutPrefix(id.key, termMeaningPrefix); ok {
			return "", "", t
		}
	default:
		if c, ok := namedSlotCategory[id.slot]; ok {
			return c, id.key, ""
		}
	}
	return "", "", ""
}

// joinSegments는 조각의 글자만 이어 붙입니다. 이름에는 용어 토큰 표시가 필요 없습니다.
func joinSegments(segments []render.Segment) string {
	var b strings.Builder
	for _, s := range segments {
		b.WriteString(s.Text)
	}
	return b.String()
}

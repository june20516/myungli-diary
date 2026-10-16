package content_test

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/seed"
)

// glossarySeed는 용어 사전의 모든 범주 원고와 한자 표기를 조금씩 담은 시드입니다.
func glossarySeed(t *testing.T) seed.Seed {
	t.Helper()
	single := func(slot, key, lang, body string) seed.Template {
		return seed.Template{Slot: slot, Key: key, Variant: seed.VariantSingle, Lang: lang, Body: body}
	}
	s := seed.Seed{
		Slots: map[string]seed.Slot{},
		Templates: []seed.Template{
			single("glossary.value_name", "element.wood", "ko", "나무"),
			single("glossary.value_name", "direction8.n", "ko", "북"),
			single("glossary.value_name", "element.wood", "en", "Wood"),
			single("daily.tag_label", "tag.dohwa", "ko", "도화"),
			single("daily.tag_label", "tag.ten_god_rush.siksang", "ko", "식상 몰림"),
			single("daily.focus_reason", "gwiin", "ko", "귀인"),
			single("calendar.score_item", "hap", "ko", "[[합|relation.branch_hap]]"),
			single("calendar.solar_term", "ipchun", "ko", "입춘"),
			single("term.meaning", "term.element.wood", "ko", "[[나무|element.wood]]처럼 자라는 기운이에요."),
			single("daily.guide", "k", "ko", "범주가 아닌 슬롯"),
		},
		Hanja: map[string]string{"element.wood": "木"},
	}
	require.NoError(t, s.Normalize())
	return s
}

func newGlossaryStore(t *testing.T, s seed.Seed) *content.Store {
	t.Helper()
	return newGlossaryStoreWithLog(t, s, discardLog())
}

func newGlossaryStoreWithLog(t *testing.T, s seed.Seed, log *slog.Logger) *content.Store {
	t.Helper()
	pool := dbtest.New(t)
	_, err := content.Apply(context.Background(), pool, s)
	require.NoError(t, err)
	return content.NewStore(pool, clock.System{}, log)
}

func TestStore_Glossary(t *testing.T) {
	s := glossarySeed(t)
	store := newGlossaryStore(t, s)

	ko, err := store.Glossary(context.Background(), s.Version, "ko")
	require.NoError(t, err)
	assert.Equal(t, content.Glossary{
		SeedVersion: s.Version,
		Lang:        "ko",
		Values: map[string]map[string]string{
			"element":      {"wood": "나무"},
			"direction8":   {"n": "북"},
			"tag":          {"dohwa": "도화", "ten_god_rush.siksang": "식상 몰림"},
			"focus_reason": {"gwiin": "귀인"},
			"score_item":   {"hap": "합"},
			"solar_term":   {"ipchun": "입춘"},
		},
		Meanings: map[string][]render.Segment{
			"element.wood": {{Text: "나무", Term: "element.wood"}, {Text: "처럼 자라는 기운이에요."}},
		},
		Hanja: map[string]string{"element.wood": "木"},
	}, ko)

	en, err := store.Glossary(context.Background(), s.Version, "en")
	require.NoError(t, err)
	assert.Equal(t, map[string]map[string]string{"element": {"wood": "Wood"}}, en.Values)
	assert.NotNil(t, en.Meanings)
	assert.Empty(t, en.Meanings, "원고가 없으면 빈 맵")
	assert.Equal(t, map[string]string{"element.wood": "木"}, en.Hanja, "한자는 언어와 상관없음")
}

func TestStore_GlossaryWithoutHanjaIsEmptyMap(t *testing.T) {
	s := testSeed(t, "")
	store := newGlossaryStore(t, s)

	got, err := store.Glossary(context.Background(), s.Version, "ko")
	require.NoError(t, err)
	assert.NotNil(t, got.Hanja)
	assert.Empty(t, got.Hanja)
}

// TestStore_GlossaryEmbeddedSeedRenders는 내장 시드의 용어 사전이 모든 언어에서 렌더되는지 확인합니다.
// 원고에 자리표시자 같은 렌더 오류가 들어오면 여기서 잡힙니다.
func TestStore_GlossaryEmbeddedSeedRenders(t *testing.T) {
	s, err := seed.Load()
	require.NoError(t, err)
	store := newGlossaryStore(t, s)

	for _, lang := range []string{"ko", "en", "ja"} {
		got, err := store.Glossary(context.Background(), s.Version, lang)
		require.NoError(t, err, lang)
		assert.Equal(t, s.Hanja, got.Hanja, lang)
	}
}

// 렌더되지 않는 항목 하나는 그 항목만 빼고 Error 로그를 남깁니다. 로그에는 원고 본문이 없습니다.
func TestStore_GlossarySkipsUnrenderableEntry(t *testing.T) {
	s := glossarySeed(t)
	s.Templates = append(s.Templates,
		seed.Template{Slot: "term.meaning", Key: "term.stem.gap", Variant: seed.VariantSingle, Lang: "ko", Body: "비밀 {param} 본문"},
		seed.Template{Slot: "daily.tag_label", Key: "tag.gongmang", Variant: seed.VariantSingle, Lang: "ko", Body: "[[깨진 토큰"},
	)
	require.NoError(t, s.Normalize())
	var logs bytes.Buffer
	store := newGlossaryStoreWithLog(t, s, slog.New(slog.NewTextHandler(&logs, nil)))

	got, err := store.Glossary(context.Background(), s.Version, "ko")
	require.NoError(t, err, "항목 하나 때문에 사전 전체가 실패하지 않음")
	assert.NotContains(t, got.Meanings, "stem.gap")
	assert.NotContains(t, got.Values["tag"], "gongmang")
	assert.Equal(t, "도화", got.Values["tag"]["dohwa"], "다른 항목은 그대로")
	assert.Contains(t, got.Meanings, "element.wood")

	out := logs.String()
	assert.Equal(t, 2, strings.Count(out, "용어 사전 항목을 만들지 못해"), out)
	assert.Contains(t, out, "slot=term.meaning key=term.stem.gap lang=ko")
	assert.Contains(t, out, "slot=daily.tag_label key=tag.gongmang lang=ko")
	assert.NotContains(t, out, "비밀")
	assert.NotContains(t, out, "깨진")
}

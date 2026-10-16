package convert_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/seed"
	"github.com/june20516/myungli-diary/server/seed/convert"
)

const basicDir = "testdata/basic"

// bodyOf는 시드에서 템플릿 본문을 찾습니다. 없으면 테스트를 실패시킵니다.
func bodyOf(t *testing.T, s seed.Seed, slot, key, variant, lang string) string {
	t.Helper()
	for _, tpl := range s.Templates {
		if tpl.Slot == slot && tpl.Key == key && tpl.Variant == variant && tpl.Lang == lang {
			return tpl.Body
		}
	}
	require.Failf(t, "템플릿 없음", "%s/%s/%s/%s", slot, key, variant, lang)
	return ""
}

func TestRun_MapsTypeAndVariant(t *testing.T) {
	s, _, err := convert.Run(basicDir)
	require.NoError(t, err)

	tests := []struct {
		name, slot, key, variant, lang, want string
	}{
		{"유형은 type 값", "daily.fortune.head", "fortune.a", "care", "ko", "쉬어도 괜찮아요."},
		{"변주 2개 슬롯은 번호", "daily.guide", "guide.a", "2", "ko", "둘"},
		{"그 밖은 single", "glossary.value_name", "direction8.n", "single", "ko", "북"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, bodyOf(t, s, tt.slot, tt.key, tt.variant, tt.lang))
		})
	}
}

func TestRun_MapsSlotSpec(t *testing.T) {
	s, _, err := convert.Run(basicDir)
	require.NoError(t, err)

	head := s.Slots["daily.fortune.head"]
	assert.True(t, head.Vocative)
	assert.Equal(t, seed.RotationType, head.Rotation)
	assert.Equal(t, seed.RotationVariant, s.Slots["daily.guide"].Rotation)
	assert.Equal(t, seed.RotationNone, s.Slots["glossary.value_name"].Rotation)
	assert.Equal(t, map[string]seed.ParamKind{
		"ten_god":  {Kind: seed.KindCategory, Categories: []string{"ten_god", "ten_god_group"}},
		"branches": {Kind: seed.KindList, ListCategory: "branch"},
		"score":    {Kind: seed.KindNumber},
		"title":    {Kind: seed.KindText},
		"x":        {Kind: seed.KindNone},
	}, head.Params)
	assert.NotContains(t, s.Slots, "home.title", "ui 슬롯은 시드에 없어야 합니다")
}

func TestRun_ResolvesBareTermToID(t *testing.T) {
	s, _, err := convert.Run(basicDir)
	require.NoError(t, err)
	assert.Equal(t, "{name}님, [[식상|ten_god_group.siksang]]을 살려 보세요.",
		bodyOf(t, s, "daily.fortune.head", "fortune.a", "advice", "ko"))
}

func TestRun_KeepsExplicitAndParamTokens(t *testing.T) {
	s, _, err := convert.Run(basicDir)
	require.NoError(t, err)
	assert.Equal(t, "[[편관|ten_god.pyeongwan]]과 [[{ten_god}]]의 날이에요.",
		bodyOf(t, s, "daily.fortune.head", "fortune.a", "state", "ko"))
}

func TestRun_AmbiguousBareTermIsError(t *testing.T) {
	// "식신"은 ten_god.siksin(glossary)과 tag.siksang_tag(태그) 두 용어의 이름입니다.
	_, _, err := convert.Run("testdata/ambiguous")
	require.Error(t, err)
	assert.ErrorContains(t, err, "daily.yaml:2")
	assert.ErrorContains(t, err, "ten_god.siksin")
	assert.ErrorContains(t, err, "tag.siksang_tag")
}

func TestRun_SkipsUISlotsAndUnknownFiles(t *testing.T) {
	s, _, err := convert.Run(basicDir)
	require.NoError(t, err)
	for _, tpl := range s.Templates {
		assert.NotEqual(t, "home.title", tpl.Slot)
		assert.NotEqual(t, "unknown.slot", tpl.Slot)
		assert.NotEqual(t, "예시", tpl.Body, "example.yaml은 넣지 않습니다")
	}
}

func TestRun_ReportsMissing(t *testing.T) {
	_, report, err := convert.Run(basicDir)
	require.NoError(t, err)
	// en 원고에는 guide.a 변주 1만 있습니다. 나머지 en 원고는 모두 빠진 것입니다.
	assert.Contains(t, report.Missing, "daily.guide/guide.a/2/en")
	assert.Contains(t, report.Missing, "daily.fortune.head/fortune.a/care/en")
	assert.NotContains(t, report.Missing, "daily.guide/guide.a/1/en")
	assert.NotContains(t, report.Missing, "daily.guide/guide.a/2/ko")
}

func TestRun_IsDeterministic(t *testing.T) {
	first, _, err := convert.Run(basicDir)
	require.NoError(t, err)
	second, _, err := convert.Run(basicDir)
	require.NoError(t, err)

	a, err := first.MarshalIndent()
	require.NoError(t, err)
	b, err := second.MarshalIndent()
	require.NoError(t, err)
	assert.Equal(t, a, b)
	assert.Equal(t, first.Version, second.Version)
	assert.Len(t, first.Version, 16)
}

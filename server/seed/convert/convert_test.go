package convert_test

import (
	"fmt"
	"os"
	"path/filepath"
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

// withLine은 basic 트리를 임시 디렉터리에 복사하고, 슬롯 extra.line의 원고 한 줄(lang)을 더한 경로를 돌려줍니다.
func withLine(t *testing.T, lang, text string) string {
	t.Helper()
	dir := t.TempDir()
	require.NoError(t, os.CopyFS(dir, os.DirFS(basicDir)))
	slot := "- id: extra.line\n  keys: [extra.k]\n  variants: {count: 1}\n"
	require.NoError(t, os.WriteFile(filepath.Join(dir, "slots/content/extra.yaml"), []byte(slot), 0o600))
	line := fmt.Sprintf("# 첫 줄\n- {slot: extra.line, key: extra.k, text: %q}\n", text)
	require.NoError(t, os.WriteFile(filepath.Join(dir, "content", lang, "extra.yaml"), []byte(line), 0o600))
	return dir
}

func TestRun_AmbiguousBareTermIsError(t *testing.T) {
	// "식신"은 ten_god.siksin(glossary)과 tag.siksang_tag(태그) 두 용어의 이름입니다.
	_, _, err := convert.Run(withLine(t, "ko", "[[식신]]을 봅니다."))
	require.Error(t, err)
	assert.ErrorContains(t, err, "extra.yaml:2")
	assert.ErrorContains(t, err, "ten_god.siksin")
	assert.ErrorContains(t, err, "tag.siksang_tag")
}

func TestRun_TokenSyntaxAndExplicitIDErrors(t *testing.T) {
	tests := []struct {
		name, text, wantErr string
	}{
		{"짝 없는 닫기", "식상]]을", "짝이 없는 ]]"},
		{"닫히지 않음", "[[식상을", "닫는 ]]"},
		{"중첩", "[[식[[상]]]]", "문법"},
		{"id가 둘", "[[식상|ten_god.a|b]]", "문법"},
		{"빈 글자", "[[ |ten_god.pyeongwan]]", "문법"},
		{"빈 id", "[[식상|]]", "문법"},
		{"id 형식 아님", "[[식상|아무거나]]", "형식"},
		{"모르는 범주", "[[식상|foo.bar]]", "형식"},
		{"complete 언어 사전에 없는 id", "[[식상|ten_god.nope]]", "사전에 없습니다"},
		{"complete 언어에서 이름 없음", "[[없는말]]", "가진 용어가 없습니다"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := convert.Run(withLine(t, "ko", tt.text))
			require.Error(t, err)
			assert.ErrorContains(t, err, "extra.yaml:2")
			assert.ErrorContains(t, err, tt.wantErr)
		})
	}
}

func TestRun_KnownExplicitIDPasses(t *testing.T) {
	s, _, err := convert.Run(withLine(t, "ko", "[[식상|ten_god_group.siksang]]과 [[도화|tag.dohwa]]"))
	require.NoError(t, err)
	assert.Equal(t, "[[식상|ten_god_group.siksang]]과 [[도화|tag.dohwa]]", bodyOf(t, s, "extra.line", "extra.k", "single", "ko"))
}

func TestRun_KeepsTokenWhenLanguageNamesIncomplete(t *testing.T) {
	// en에는 glossary·태그 이름 원고가 없어 글자를 풀지 못해도 오류가 아닙니다.
	s, _, err := convert.Run(withLine(t, "en", "[[dohwa]] and [[x|ten_god.anything]]"))
	require.NoError(t, err)
	assert.Equal(t, "[[dohwa]] and [[x|ten_god.anything]]", bodyOf(t, s, "extra.line", "extra.k", "single", "en"))
}

func TestRun_UnsupportedLanguageDirIsError(t *testing.T) {
	_, _, err := convert.Run(withLine(t, "ko", "x")) // 기준선: 정상
	require.NoError(t, err)

	dir := withLine(t, "ko", "x")
	require.NoError(t, os.Mkdir(filepath.Join(dir, "content", "fr"), 0o750))
	_, _, err = convert.Run(dir)
	require.Error(t, err)
	assert.ErrorContains(t, err, `"fr"`)
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

func TestRun_ReadsHanja(t *testing.T) {
	s, _, err := convert.Run(basicDir)
	require.NoError(t, err)
	assert.Equal(t, map[string]string{"ten_god.pyeongwan": "偏官", "tag.dohwa": "桃花"}, s.Hanja)
}

func TestRun_MissingHanjaFileIsEmpty(t *testing.T) {
	s, _, err := convert.Run("testdata/complete")
	require.NoError(t, err)
	assert.NotNil(t, s.Hanja)
	assert.Empty(t, s.Hanja)
}

// withHanja는 basic 트리를 임시 디렉터리에 복사하고 content/hanja.yaml을 data로 바꾼 경로를 돌려줍니다.
func withHanja(t *testing.T, data string) string {
	t.Helper()
	dir := t.TempDir()
	require.NoError(t, os.CopyFS(dir, os.DirFS(basicDir)))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "content", "hanja.yaml"), []byte(data), 0o600))
	return dir
}

func TestRun_HanjaChangesVersion(t *testing.T) {
	base, _, err := convert.Run(basicDir)
	require.NoError(t, err)
	changed, _, err := convert.Run(withHanja(t, "- {term: ten_god.pyeongwan, hanja: \"七殺\"}\n"))
	require.NoError(t, err)
	assert.NotEqual(t, base.Version, changed.Version)
}

func TestRun_HanjaFormatErrors(t *testing.T) {
	tests := []struct {
		name, data, wantWhere, wantErr string
	}{
		{"목록이 아님", "term: x\n", "hanja.yaml", "목록"},
		{"항목 형식", "- {term: ten_god.a, hanja: [x]}\n", "hanja.yaml:1", "형식"},
		{"모르는 필드", "- {term: ten_god.a, hanja: \"甲\", lang: ko}\n", "hanja.yaml:1", "형식"},
		{"용어 id 형식", "- {term: 아무거나, hanja: \"甲\"}\n", "hanja.yaml:1", "용어 id"},
		{"빈 한자", "- {term: stem.gap, hanja: \" \"}\n", "hanja.yaml:1", "비어"},
		{"중복", "- {term: stem.gap, hanja: \"甲\"}\n- {term: stem.gap, hanja: \"甲\"}\n", "hanja.yaml:2", "중복"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := convert.Run(withHanja(t, tt.data))
			require.Error(t, err)
			assert.ErrorContains(t, err, tt.wantWhere)
			assert.ErrorContains(t, err, tt.wantErr)
		})
	}
}

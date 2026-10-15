package honorific

import (
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

const josaYAMLPath = "../../../../docs/identity/writing/rules/josa.yaml"

// josa.yaml의 code 문자열을 Code로 바꾸는 표입니다. 비테스트 파일에는 code 문자열을 두지 않습니다.
var codeByYAMLName = map[string]Code{
	"name.empty":           Empty,
	"name.too_long":        TooLong,
	"name.emoji":           Emoji,
	"name.control":         Control,
	"name.invalid_char":    InvalidChar,
	"name.suffix_stripped": SuffixStripped,
	"name.suffix_warning":  SuffixWarning,
}

type nameRulesYAML struct {
	MaxLength      map[string]int      `yaml:"max_length"`
	StripSuffix    map[string][]string `yaml:"strip_suffix"`
	WarnSuffix     map[string][]string `yaml:"warn_suffix"`
	ForbiddenChars []string            `yaml:"forbidden_chars"`
	Examples       []struct {
		Lang  string   `yaml:"lang"`
		Input string   `yaml:"input"`
		Value *string  `yaml:"value"`
		Codes []string `yaml:"codes"`
	} `yaml:"examples"`
}

func loadNameRules(t *testing.T) nameRulesYAML {
	t.Helper()
	data, err := os.ReadFile(josaYAMLPath)
	require.NoError(t, err)
	var doc struct {
		NameRules nameRulesYAML `yaml:"name_rules"`
	}
	require.NoError(t, yaml.Unmarshal(data, &doc))
	return doc.NameRules
}

func TestNormalize_MatchesJosaYAMLExamples(t *testing.T) {
	rules := loadNameRules(t)
	require.Len(t, rules.Examples, 6)
	for _, example := range rules.Examples {
		t.Run(example.Input, func(t *testing.T) {
			var codes []Code
			for _, name := range example.Codes {
				code, ok := codeByYAMLName[name]
				require.True(t, ok, name)
				codes = append(codes, code)
			}
			result := Normalize(example.Lang, example.Input)
			if example.Value == nil {
				require.Len(t, codes, 1)
				assert.Equal(t, "", result.Value)
				assert.Equal(t, codes[0], result.Rejected)
				assert.Empty(t, result.Warnings)
				return
			}
			assert.Equal(t, *example.Value, result.Value)
			assert.Equal(t, None, result.Rejected)
			assert.Equal(t, codes, result.Warnings)
		})
	}
}

func TestRulesMatchJosaYAML(t *testing.T) {
	rules := loadNameRules(t)
	assert.Equal(t, rules.MaxLength, maxLength)
	assert.Equal(t, rules.StripSuffix, stripSuffix)
	assert.Equal(t, rules.WarnSuffix, warnSuffix)
	assert.Equal(t, strings.Join(rules.ForbiddenChars, ""), forbiddenChars)
}

func TestNormalize_RepeatedSuffixStripped(t *testing.T) {
	result := Normalize("ko", "민지님님")
	assert.Equal(t, "민지", result.Value)
	assert.Equal(t, []Code{SuffixStripped}, result.Warnings)

	result = Normalize("ko", "님")
	assert.Equal(t, Empty, result.Rejected)
	assert.Equal(t, "", result.Value)
}

func TestNormalize_Emoji(t *testing.T) {
	for _, raw := range []string{"민지😀", "🇰🇷", "1️⃣"} {
		result := Normalize("ko", raw)
		assert.Equal(t, Emoji, result.Rejected, raw)
		assert.Equal(t, "", result.Value, raw)
	}
}

func TestNormalize_CountsRunesNotBytes(t *testing.T) {
	assert.Equal(t, None, Normalize("ko", "가나다라마바사아자차").Rejected)
	assert.Equal(t, TooLong, Normalize("ko", "가나다라마바사아자차카").Rejected)
	assert.Equal(t, None, Normalize("en", strings.Repeat("a", 20)).Rejected)
	assert.Equal(t, TooLong, Normalize("en", strings.Repeat("a", 21)).Rejected)
}

func TestNormalize_ControlChar(t *testing.T) {
	assert.Equal(t, Control, Normalize("ko", "민\u0007지").Rejected)
}

func TestNormalize_NFCAndTrim(t *testing.T) {
	// 자모로 분해된 "민지"는 NFC로 합쳐서 저장합니다.
	result := Normalize("ko", "민지")
	assert.Equal(t, "민지", result.Value)
	// 앞뒤 유니코드 공백은 제거합니다.
	assert.Equal(t, "Sam", Normalize("en", "　Sam ").Value)
}

func TestNormalize_WarningKinds(t *testing.T) {
	assert.Equal(t, []Code{SuffixStripped}, Normalize("ko", "민지님").Warnings)
	assert.Equal(t, []Code{SuffixWarning}, Normalize("ja", "ゆきさん").Warnings)
	assert.Equal(t, []Code{SuffixWarning}, Normalize("ja", "ゆきちゃん").Warnings)
	assert.Equal(t, []Code{SuffixWarning}, Normalize("ja", "山田様").Warnings)
}

func TestNormalize_StripsPythonWhitespace(t *testing.T) {
	// Python str.strip()은 U+001C~U+001F도 떼므로 기준 구현에 맞춥니다.
	assert.Equal(t, "민지", Normalize("ko", "\x1f민지").Value)
	assert.Equal(t, "민지", Normalize("ko", "민지\x1c").Value)
	assert.Equal(t, Control, Normalize("ko", "민\x1f지").Rejected)
}

func TestNormalize_EmojiBoundary(t *testing.T) {
	assert.Equal(t, Emoji, Normalize("en", "\u00A9").Rejected)
	assert.Equal(t, Emoji, Normalize("en", "🇰🇷").Rejected)
	assert.Equal(t, "#", Normalize("en", "#").Value)
	assert.Equal(t, "1", Normalize("en", "1").Value)
}

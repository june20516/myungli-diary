package render

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

// josaRulesPath는 writing 규칙 원본 위치입니다. 테스트에서만 읽고, 실행 바이너리는 읽지 않습니다.
const josaRulesPath = "../../../../docs/identity/writing/rules/josa.yaml"

// TestJosa_Examples는 josa.yaml의 examples 전부가 Go 판정표와 같은 결과를 내는지 봅니다.
// Go 표와 YAML이 어긋나면 여기서 잡힙니다.
func TestJosa_Examples(t *testing.T) {
	raw, err := os.ReadFile(josaRulesPath)
	require.NoError(t, err)

	var rules struct {
		Examples []struct {
			Text     string `yaml:"text"`
			Expected string `yaml:"expected"`
		} `yaml:"examples"`
	}
	require.NoError(t, yaml.Unmarshal(raw, &rules))
	require.NotEmpty(t, rules.Examples)

	for _, ex := range rules.Examples {
		t.Run(ex.Text, func(t *testing.T) {
			assert.Equal(t, ex.Expected, Josa(ex.Text))
		})
	}
}

func TestJosa_NFDInput(t *testing.T) {
	// 자모가 분리된(NFD) "남색(이)가"
	nfd := "남색(이)가"
	assert.Equal(t, "남색이", Josa(nfd))
}

func TestJosa_UndecidableUsesBothForm(t *testing.T) {
	assert.Equal(t, "さくら이(가)", Josa("さくら(이)가"))
}

func TestJosa_Table(t *testing.T) {
	tests := []struct{ name, in, want string }{
		{"받침 없음 쌍 전부", "나(이)가 나(은)는 나(을)를 나(과)와", "나가 나는 나를 나와"},
		{"ㄹ 받침은 (으)로가 로", "물(으)로", "물로"},
		{"마커 없음", "그대로", "그대로"},
		{"숫자 끝 0 개수 상한", "1000000(이)가", "1000000이"},
		{"소문자 영문", "b(이)가", "b가"},
		{"전각 숫자는 판정 불가", "１(이)가", "１이(가)"},
		{"빈 앞부분은 판정 불가", "(이)가", "이(가)"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, Josa(tt.in))
		})
	}
}

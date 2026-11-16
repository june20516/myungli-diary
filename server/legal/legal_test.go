package legal_test

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/legal"
)

func doc(lang, name string) legal.Document {
	return legal.Document{Lang: lang, Name: name, Title: lang + " " + name, HTML: "<p>" + name + "</p>\n"}
}

// 쓰는 순서는 Languages·Names 순서라 입력 순서와 상관없이 같은 바이트입니다.
func TestMarshal_ParseRoundTripInFixedOrder(t *testing.T) {
	a, err := legal.Marshal([]legal.Document{doc("ja", legal.Terms), doc("ko", legal.Privacy), doc("ko", legal.Terms)})
	require.NoError(t, err)
	b, err := legal.Marshal([]legal.Document{doc("ko", legal.Terms), doc("ja", legal.Terms), doc("ko", legal.Privacy)})
	require.NoError(t, err)
	assert.Equal(t, string(a), string(b))
	assert.Less(t, strings.Index(string(a), `"privacy"`), strings.Index(string(a), `"ja"`))

	docs, err := legal.Parse(a)
	require.NoError(t, err)
	got, ok := docs.Get("ko", legal.Privacy)
	require.True(t, ok)
	assert.Equal(t, doc("ko", legal.Privacy), got)
	_, ok = docs.Get("en", legal.Terms)
	assert.False(t, ok, "원문이 없는 조합")
}

func TestMarshal_EmptyIsEmptyArray(t *testing.T) {
	data, err := legal.Marshal(nil)
	require.NoError(t, err)
	assert.JSONEq(t, `{"documents":[]}`, string(data))
}

func TestParse_Rejects(t *testing.T) {
	for name, data := range map[string]string{
		"JSON 아님":      `{`,
		"documents 없음": `{}`,
		"모르는 언어":       `{"documents":[{"lang":"fr","name":"terms","title":"t","html":"h"}]}`,
		"모르는 이름":       `{"documents":[{"lang":"ko","name":"refund","title":"t","html":"h"}]}`,
		"겹침":           `{"documents":[{"lang":"ko","name":"terms","title":"t","html":"h"},{"lang":"ko","name":"terms","title":"t","html":"h"}]}`,
		"제목 없음":        `{"documents":[{"lang":"ko","name":"terms","title":"","html":"h"}]}`,
	} {
		t.Run(name, func(t *testing.T) {
			_, err := legal.Parse([]byte(data))
			assert.Error(t, err)
		})
	}
}

func TestLoad_EmbeddedFileParses(t *testing.T) {
	_, err := legal.Load()
	require.NoError(t, err)
}

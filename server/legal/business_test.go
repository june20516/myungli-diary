package legal_test

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/legal"
)

// businessInfo는 언어마다 구분되는 가짜 사업자 정보입니다.
func businessInfo(lang string) legal.BusinessInfo {
	return legal.BusinessInfo{
		Name: lang + " 상호 <&>", Representative: lang + " 대표", Address: lang + " 주소",
		RegistrationNumber: "000-00-00000", MailOrderNumber: "제0000-가나-0000호",
	}
}

func businessJSON(t *testing.T, b legal.Business) []byte {
	t.Helper()
	data, err := json.Marshal(b)
	require.NoError(t, err)
	return data
}

func fullBusiness() legal.Business {
	return legal.Business{"ko": businessInfo("ko"), "en": businessInfo("en"), "ja": businessInfo("ja")}
}

func TestParseBusiness_AllLanguagesAndFields(t *testing.T) {
	got, err := legal.ParseBusiness(businessJSON(t, fullBusiness()))
	require.NoError(t, err)
	assert.Equal(t, fullBusiness(), got)
}

func TestParseBusiness_Rejects(t *testing.T) {
	missingLang := fullBusiness()
	delete(missingLang, "ja")
	emptyField := fullBusiness()
	info := emptyField["en"]
	info.Address = " "
	emptyField["en"] = info
	extraLang := fullBusiness()
	extraLang["fr"] = businessInfo("fr")
	nested := fullBusiness()
	info = nested["ko"]
	info.Name = "{{business.name}}"
	nested["ko"] = info

	for name, data := range map[string][]byte{
		"JSON 아님":     []byte(`{`),
		"모르는 필드":      []byte(`{"ko":{"phone":"1"}}`),
		"언어 빠짐":       businessJSON(t, missingLang),
		"빈 값":         businessJSON(t, emptyField),
		"모르는 언어":      businessJSON(t, extraLang),
		"값 안의 빈자리 표기": businessJSON(t, nested),
	} {
		t.Run(name, func(t *testing.T) {
			_, err := legal.ParseBusiness(data)
			require.Error(t, err)
			assert.NotContains(t, err.Error(), "상호", "오류에 값을 담지 않음")
		})
	}
}

func TestCheckPlaceholders(t *testing.T) {
	assert.NoError(t, legal.CheckPlaceholders("상호 {{business.name}}, 번호 {{business.mailOrderNumber}}"))
	assert.NoError(t, legal.CheckPlaceholders("빈자리 없음"))
	assert.ErrorContains(t, legal.CheckPlaceholders("{{business.Name}}"), "모르는 빈자리 표기")
	assert.ErrorContains(t, legal.CheckPlaceholders("{{business.name}"), "빈자리 표기 밖")
	assert.ErrorContains(t, legal.CheckPlaceholders("a }} b"), "빈자리 표기 밖")
}

func TestParse_RejectsUnknownPlaceholder(t *testing.T) {
	_, err := legal.Parse([]byte(`{"documents":[{"lang":"ko","name":"terms","title":"t","html":"<p>{{business.fax}}</p>"}]}`))
	assert.ErrorContains(t, err, "모르는 빈자리 표기")
}

// placeholderDocs는 ko 이용약관에만 빈자리가 있는 문서 묶음입니다.
func placeholderDocs(t *testing.T) legal.Documents {
	t.Helper()
	docs, err := legal.New([]legal.Document{
		{Lang: "ko", Name: legal.Terms, Title: "{{business.name}} 이용약관", HTML: "<p>상호 {{business.name}}, 번호 {{business.registrationNumber}}</p>\n"},
		doc("ko", legal.Privacy),
	})
	require.NoError(t, err)
	return docs
}

func TestFill_ReplacesWithEscapedValues(t *testing.T) {
	filled, dropped := placeholderDocs(t).Fill(fullBusiness())
	assert.Empty(t, dropped)

	terms, ok := filled.Get("ko", legal.Terms)
	require.True(t, ok)
	assert.Equal(t, "ko 상호 <&> 이용약관", terms.Title, "제목은 글자 그대로(페이지 template이 이스케이프)")
	assert.Equal(t, "<p>상호 ko 상호 &lt;&amp;&gt;, 번호 000-00-00000</p>\n", terms.HTML)
	privacy, ok := filled.Get("ko", legal.Privacy)
	require.True(t, ok)
	assert.Equal(t, doc("ko", legal.Privacy), privacy, "빈자리 없는 문서는 그대로")
}

// 값이 없으면 빈자리가 있는 문서만 빠져 준비 중 페이지가 됩니다. 빈자리가 보이는 페이지는 내지 않습니다.
func TestFill_WithoutBusinessDropsPlaceholderDocuments(t *testing.T) {
	docs := placeholderDocs(t)
	filled, dropped := docs.Fill(nil)
	assert.Equal(t, []string{"ko/terms"}, dropped)
	_, ok := filled.Get("ko", legal.Terms)
	assert.False(t, ok)
	_, ok = filled.Get("ko", legal.Privacy)
	assert.True(t, ok)

	_, ok = docs.Get("ko", legal.Terms)
	assert.True(t, ok, "원래 묶음은 바꾸지 않음")
}

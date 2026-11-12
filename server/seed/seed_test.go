package seed_test

import (
	"strings"
	"testing"
	"unicode"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/seed"
)

func TestLoad_EmbeddedSeedParses(t *testing.T) {
	s, err := seed.Load()
	require.NoError(t, err)
	assert.NotEmpty(t, s.Version)
	assert.NotEmpty(t, s.Templates)

	// 내장 파일의 Version은 내용에서 다시 계산한 값과 같아야 합니다(손으로 고친 시드를 잡습니다).
	want := s
	require.NoError(t, want.Normalize())
	assert.Equal(t, want.Version, s.Version)
}

// twelveStageValues는 12운성 값 이름입니다(엔진 TwelveStage, writing 용어 범주 twelve_stage).
var twelveStageValues = []string{
	"jangsaeng", "mokyok", "gwandae", "geonrok", "jewang", "soe",
	"byeong", "sa", "myo", "jeol", "tae", "yang",
}

// 12운성 설명 시트가 뜻을 받도록, 내장 시드에 12운성 값마다 세 언어 뜻(term.meaning)과 한자가 있어야 합니다. (#956, #967)
func TestLoad_TwelveStageMeaningsAndHanja(t *testing.T) {
	s, err := seed.Load()
	require.NoError(t, err)

	meanings := map[string]bool{}
	for _, tpl := range s.Templates {
		if tpl.Slot == "term.meaning" {
			meanings[tpl.Lang+" "+tpl.Key] = true
		}
	}
	for _, value := range twelveStageValues {
		term := "twelve_stage." + value
		for _, lang := range []string{"ko", "en", "ja"} {
			assert.True(t, meanings[lang+" term."+term], "%s 뜻(%s)이 없음", term, lang)
		}
		assert.NotEmpty(t, s.Hanja[term], "%s 한자가 없음", term)
	}
}

// 간지 독음(writing W72, #1075)은 사전 이름 슬롯에 천간 열, 지지 열둘이 세 언어로 있어 Glossary.values의
// stem_reading, branch_reading 범주로 나갑니다. 앱 날짜 머리 "庚申(경신)일"이 이 값을 씁니다(#1069).
func TestLoad_GanjiReadings(t *testing.T) {
	s, err := seed.Load()
	require.NoError(t, err)

	bodies := map[string]string{}
	for _, tpl := range s.Templates {
		if tpl.Slot == "glossary.value_name" {
			bodies[tpl.Lang+" "+tpl.Key] = tpl.Body
		}
	}
	counts := map[string]int{}
	for key := range bodies {
		_, key, _ = strings.Cut(key, " ")
		category, _, _ := strings.Cut(key, ".")
		counts[category]++
	}
	assert.Equal(t, 10*3, counts["stem_reading"], "천간 독음 열 개, 세 언어")
	assert.Equal(t, 12*3, counts["branch_reading"], "지지 독음 열둘, 세 언어")
	assert.Equal(t, "경", bodies["ko stem_reading.gyeong"])
	assert.Equal(t, "신", bodies["ko branch_reading.shin"])
	assert.Equal(t, "きのえ", bodies["ja stem_reading.gap"])
	assert.Equal(t, "Gap", bodies["en stem_reading.gap"])
}

// 잠긴 원전 미리보기(D106)는 문장 앞부분이라, 원전 원고는 뜻, 원문, 출처 순이어야 미리보기가 뜻이 됩니다(D118, #952).
// ko 원고의 첫 줄이 원문(한자)도 출처(「편명」)도 아닌지로 순서를 확인합니다.
func TestLoad_EvidenceSourceStartsWithMeaning(t *testing.T) {
	s, err := seed.Load()
	require.NoError(t, err)

	checked := 0
	for _, tpl := range s.Templates {
		if tpl.Slot != "evidence.source" || tpl.Lang != "ko" {
			continue
		}
		firstLine, _, _ := strings.Cut(tpl.Body, "\n")
		isMeaning := !strings.Contains(firstLine, "「") && !strings.ContainsFunc(firstLine, func(r rune) bool { return unicode.Is(unicode.Han, r) })
		assert.True(t, isMeaning, "%s의 첫 줄이 뜻이 아님: %.40q", tpl.Key, firstLine)
		checked++
	}
	assert.NotZero(t, checked)
}

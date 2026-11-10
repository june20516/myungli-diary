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

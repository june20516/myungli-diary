package city_test

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/text/unicode/norm"

	"github.com/june20516/myungli-diary/server/internal/city"
)

func ids(cities []city.City) []string {
	out := make([]string, 0, len(cities))
	for _, c := range cities {
		out = append(out, c.ID)
	}
	return out
}

func TestSearch_KoreanPrefixPutsSeoulFirst(t *testing.T) {
	got := city.Search("서울", "ko", 20)
	require.NotEmpty(t, got)
	assert.Equal(t, "1835848", got[0].ID)
}

func TestSearch_MatchesEnglishNameEvenInKorean(t *testing.T) {
	got := city.Search("seo", "ko", 50)
	assert.Contains(t, ids(got), "1835848", "ko 요청이어도 영어 이름(Seoul) 앞부분으로 찾습니다")
}

func TestSearch_IgnoresCaseAndNormalizationForm(t *testing.T) {
	nfd := norm.NFD.String("TŌKAMACHI")
	require.NotEqual(t, "TŌKAMACHI", nfd, "NFD 입력이어야 합니다")
	got := city.Search(nfd, "en", 50)
	assert.Contains(t, ids(got), "1850217")
}

func TestSearch_OrdersRequestLanguageMatchesFirstThenByName(t *testing.T) {
	got := city.Search("to", "en", 50)
	require.Greater(t, len(got), 2)

	seenOther := false
	for i, c := range got {
		matches := strings.HasPrefix(strings.ToLower(c.Name("en")), "to")
		if !matches {
			seenOther = true
			continue
		}
		assert.False(t, seenOther, "요청 언어 이름 일치가 뒤에 나왔습니다: %s", c.Name("en"))
		if i > 0 && strings.HasPrefix(strings.ToLower(got[i-1].Name("en")), "to") {
			assert.LessOrEqual(t, got[i-1].Name("en"), c.Name("en"), "요청 언어 이름 순이어야 합니다")
		}
	}
}

func TestSearch_RequestLanguageMatchesComeBeforeOtherLanguageMatches(t *testing.T) {
	for _, tc := range []struct{ lang, query string }{{"ko", "to"}, {"ja", "ab"}} {
		t.Run(tc.lang, func(t *testing.T) {
			got := city.Search(tc.query, tc.lang, 5000)
			matchesRequestLang := func(c city.City) bool {
				return strings.HasPrefix(strings.ToLower(c.Name(tc.lang)), tc.query)
			}
			requestLangCount, otherCount := 0, 0
			seenOther := false
			for _, c := range got {
				if !matchesRequestLang(c) {
					otherCount++
					seenOther = true
					continue
				}
				requestLangCount++
				assert.False(t, seenOther, "요청 언어 일치가 다른 언어 일치 뒤에 나왔습니다: %s", c.Name(tc.lang))
			}
			require.NotZero(t, requestLangCount, "질의가 요청 언어 일치를 포함해야 의미가 있습니다")
			require.NotZero(t, otherCount, "질의가 다른 언어로만 맞는 도시를 포함해야 의미가 있습니다")
		})
	}
}

func TestSearch_BlankQueryIsEmpty(t *testing.T) {
	for _, q := range []string{"", "   ", "\t\n"} {
		got := city.Search(q, "en", 20)
		assert.NotNil(t, got)
		assert.Empty(t, got, "q=%q", q)
	}
}

func TestSearch_OrdersByLowercasedName(t *testing.T) {
	got := city.Search("a", "en", 5000)
	for i := 1; i < len(got); i++ {
		prev, cur := strings.ToLower(got[i-1].Name("en")), strings.ToLower(got[i].Name("en"))
		if strings.HasPrefix(prev, "a") && strings.HasPrefix(cur, "a") {
			assert.LessOrEqual(t, prev, cur)
		}
	}
}

func TestSearch_LimitTruncates(t *testing.T) {
	assert.Len(t, city.Search("a", "en", 3), 3)
}

func TestSearch_NoMatchIsEmptyNotNil(t *testing.T) {
	got := city.Search("zzzzqqqq", "en", 20)
	assert.NotNil(t, got)
	assert.Empty(t, got)
}

func TestSearch_ZeroLimitIsEmpty(t *testing.T) {
	assert.Empty(t, city.Search("seoul", "en", 0))
}

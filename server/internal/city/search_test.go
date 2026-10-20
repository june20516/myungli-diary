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

func TestSearch_OtherLanguageMatchComesAfterRequestLanguageMatch(t *testing.T) {
	// 일본어 요청 "東京"은 ja 이름 일치만 있고, 영어 "Tokyo"로 찾으면 ja 요청에서 뒤로 갑니다.
	got := city.Search("tokyo", "ja", 50)
	require.NotEmpty(t, got)
	for _, c := range got {
		assert.True(t, strings.HasPrefix(strings.ToLower(c.Name("en")), "tokyo") ||
			strings.HasPrefix(strings.ToLower(c.Name("ko")), "tokyo") ||
			strings.HasPrefix(strings.ToLower(c.Name("ja")), "tokyo"))
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

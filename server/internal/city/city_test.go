package city_test

import (
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/city"
)

// 이름 기대값은 GeoNames alternateNamesV2의 선택 규칙(preferred 우선) 결과입니다.
// 서울은 "서울특별시"(preferred)가 "서울"(비preferred)보다, 도쿄 ja는 "東京都"(preferred)가
// "東京"(short)보다 앞섭니다.
func TestLookup_Seoul(t *testing.T) {
	got, ok := city.Lookup("1835848")
	require.True(t, ok)
	assert.Equal(t, "KR", got.Country)
	assert.Equal(t, "Asia/Seoul", got.Timezone)
	assert.Equal(t, "서울특별시", got.Names["ko"])
	assert.Equal(t, "Seoul", got.Names["en"])
	assert.Equal(t, "대한민국", got.CountryName["ko"])
	assert.Equal(t, "Seoul", got.RegionName["en"])
	assert.Greater(t, got.Longitude, 126.0)
	assert.Less(t, got.Longitude, 128.0)
}

func TestLookup_Tokyo(t *testing.T) {
	got, ok := city.Lookup("1850147")
	require.True(t, ok)
	assert.Equal(t, "東京都", got.Names["ja"])
	assert.Equal(t, "도쿄", got.Names["ko"])
	assert.Equal(t, "日本", got.CountryName["ja"])
}

func TestLookup_Unknown(t *testing.T) {
	_, ok := city.Lookup("0")
	assert.False(t, ok)
}

func TestAll_EveryCityHasThreeNames(t *testing.T) {
	all := city.All()
	require.NotEmpty(t, all)
	for _, c := range all {
		for _, lang := range []string{"ko", "en", "ja"} {
			require.NotEmpty(t, c.Names[lang], "도시 %s의 %s 이름", c.ID, lang)
			require.NotEmpty(t, c.CountryName[lang], "도시 %s의 나라 %s 이름", c.ID, lang)
		}
		_, err := time.LoadLocation(c.Timezone)
		require.NoError(t, err, "도시 %s의 시간대 %q", c.ID, c.Timezone)
		require.GreaterOrEqual(t, c.Longitude, -180.0, "도시 %s", c.ID)
		require.LessOrEqual(t, c.Longitude, 180.0, "도시 %s", c.ID)
	}
}

func TestAll_SortedByEnglishName(t *testing.T) {
	all := city.All()
	assert.True(t, sort.SliceIsSorted(all, func(i, j int) bool {
		return strings.ToLower(all[i].Names["en"]) < strings.ToLower(all[j].Names["en"])
	}))
}

func TestAll_ReturnsCopy(t *testing.T) {
	first := city.All()
	id := first[0].ID
	first[0].ID = "changed"
	assert.Equal(t, id, city.All()[0].ID)
}

func TestDataVersion_Is12Hex(t *testing.T) {
	v := city.DataVersion()
	assert.Regexp(t, `^[0-9a-f]{12}$`, v)
}

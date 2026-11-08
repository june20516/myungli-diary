package diary_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/fortune"
)

// statsRecord는 날의 성격과 대표 태그만 정한 날짜 기록입니다. kind가 비면 1.1.0 전 기록처럼 day_kind가 NULL입니다.
func statsRecord(kind string, featured ...fortune.FeaturedTag) *fortune.DayRecord {
	rec := record("x")
	rec.DayKind = kind
	rec.Featured = featured
	return rec
}

func tag(key, polarity string) fortune.FeaturedTag {
	return fortune.FeaturedTag{Key: key, Polarity: fortune.Polarity(polarity)}
}

func dayKindDays(stats diary.Stats) map[string]int {
	out := map[string]int{}
	for _, k := range stats.DayKinds {
		out[k.DayKind] = k.Days
	}
	return out
}

func TestStore_StatsEmptyAccount(t *testing.T) {
	store, acc, _ := setup(t)

	got, err := store.Stats(context.Background(), acc)
	require.NoError(t, err)
	assert.Equal(t, 0, got.EntryCount)
	assert.Equal(t, map[string]int{"gwiin_day": 0, "yongsin_day": 0, "gisin_day": 0, "ordinary_day": 0}, dayKindDays(got))
	assert.NotNil(t, got.TopTags)
	assert.Empty(t, got.TopTags)
}

func TestStore_StatsCountsEntriesAndDays(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	mustCreate(t, store, acc, 1, "a", statsRecord("yongsin_day"))
	mustCreate(t, store, acc, 1, "b", nil)
	mustCreate(t, store, acc, 1, "c", nil)
	mustCreate(t, store, acc, 2, "d", statsRecord("yongsin_day"))
	mustCreate(t, store, acc, 3, "e", statsRecord("gisin_day"))
	mustCreate(t, store, acc, 4, "f", statsRecord(""))
	gone := mustCreate(t, store, acc, 5, "지울 것", statsRecord("gwiin_day"))
	require.NoError(t, store.Delete(ctx, acc, gone.ID))
	removed := mustCreate(t, store, acc, 2, "지울 것", nil)
	require.NoError(t, store.Delete(ctx, acc, removed.ID))
	mustCreate(t, store, newAccount(t, pool), 1, "남의 일기", statsRecord("ordinary_day"))

	got, err := store.Stats(ctx, acc)
	require.NoError(t, err)
	assert.Equal(t, 6, got.EntryCount, "살아 있는 편수, 지운 편과 남의 일기는 빠짐")
	assert.Equal(t, map[string]int{"gwiin_day": 0, "yongsin_day": 2, "gisin_day": 1, "ordinary_day": 0}, dayKindDays(got),
		"같은 날 여러 편은 한 번, 지운 일기만 남은 날과 성격 없는 날은 세지 않음")
	assert.Len(t, got.DayKinds, 4)
}

func TestStore_StatsTopTags(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	mustCreate(t, store, acc, 1, "a", statsRecord("yongsin_day", tag("dohwa", "neutral"), tag("yeokma", "neutral")))
	mustCreate(t, store, acc, 1, "b", nil)
	mustCreate(t, store, acc, 2, "c", statsRecord("yongsin_day", tag("dohwa", "neutral"), tag("cheoneul", "good")))
	mustCreate(t, store, acc, 3, "d", statsRecord("gisin_day", tag("dohwa", "bad"), tag("baekho", "bad")))
	mustCreate(t, store, acc, 4, "e", statsRecord("gisin_day", tag("yeokma", "neutral")))
	gone := mustCreate(t, store, acc, 5, "지울 것", statsRecord("gisin_day", tag("baekho", "bad"), tag("cheoneul", "good")))
	require.NoError(t, store.Delete(ctx, acc, gone.ID))

	got, err := store.Stats(ctx, acc)
	require.NoError(t, err)
	assert.Equal(t, []diary.TagCount{
		{Tag: tag("dohwa", "bad"), Days: 3},
		{Tag: tag("yeokma", "neutral"), Days: 2},
		{Tag: tag("baekho", "bad"), Days: 1},
	}, got.TopTags, "날짜 수 많은 순, 같으면 키 순, 3개까지, polarity는 가장 최근 날짜 값, 지운 일기만 남은 날은 빠짐")
}

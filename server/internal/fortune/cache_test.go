package fortune_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

func TestPostgresCache_RoundTripAndMiss(t *testing.T) {
	ctx := context.Background()
	cache := fortune.NewPostgresCache(dbtest.New(t))
	hash := profile.BirthHash(testBirth())

	chart := fortune.ChartKey{BirthHash: hash, Ruleset: "rs-1", AsOfYear: 2026}
	daily := fortune.DailyKey{BirthHash: hash, Ruleset: "rs-1", Date: profile.LocalDate{Year: 2026, Month: 10, Day: 15}, CurrentTimezone: "Asia/Seoul"}
	month := fortune.MonthKey{BirthHash: hash, Ruleset: "rs-1", Year: 2026, Month: 10, CurrentTimezone: "Asia/Seoul"}

	_, ok, err := cache.GetChart(ctx, chart)
	require.NoError(t, err)
	assert.False(t, ok, "비어 있으면 없음")

	require.NoError(t, cache.PutChart(ctx, chart, []byte("c")))
	require.NoError(t, cache.PutDaily(ctx, daily, []byte("d")))
	require.NoError(t, cache.PutMonth(ctx, month, []byte("m")))
	require.NoError(t, cache.PutChart(ctx, chart, []byte("later")), "같은 키 재저장은 오류 없이 먼저 쓴 값을 유지")

	got, ok, err := cache.GetChart(ctx, chart)
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, []byte("c"), got)
	got, ok, err = cache.GetDaily(ctx, daily)
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, []byte("d"), got)
	got, ok, err = cache.GetMonth(ctx, month)
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, []byte("m"), got)

	other := chart
	other.Ruleset = "rs-2"
	_, ok, err = cache.GetChart(ctx, other)
	require.NoError(t, err)
	assert.False(t, ok, "ruleset이 다르면 없음")
}

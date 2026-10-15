package cachedb_test

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/fortune/cachedb"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

func TestCache_PutIsIdempotent(t *testing.T) {
	ctx := context.Background()
	q := cachedb.New(dbtest.New(t))
	key := cachedb.PutDailyParams{
		BirthHash:       make([]byte, 32),
		RulesetVersion:  "v1",
		Date:            pgtype.Date{Time: time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC), Valid: true},
		CurrentTimezone: "Asia/Seoul",
		Response:        []byte("first"),
	}

	require.NoError(t, q.PutDaily(ctx, key))
	key.Response = []byte("second")
	require.NoError(t, q.PutDaily(ctx, key))

	got, err := q.GetDaily(ctx, cachedb.GetDailyParams{
		BirthHash: key.BirthHash, RulesetVersion: key.RulesetVersion, Date: key.Date, CurrentTimezone: key.CurrentTimezone,
	})
	require.NoError(t, err)
	require.Equal(t, []byte("first"), got)
}

func TestCache_GetMissingReturnsNoRows(t *testing.T) {
	ctx := context.Background()
	q := cachedb.New(dbtest.New(t))
	hash := make([]byte, 32)

	_, err := q.GetChart(ctx, cachedb.GetChartParams{BirthHash: hash, RulesetVersion: "v1", AsOfYear: 2026})
	require.ErrorIs(t, err, pgx.ErrNoRows)
	_, err = q.GetMonth(ctx, cachedb.GetMonthParams{BirthHash: hash, RulesetVersion: "v1", Year: 2026, Month: 10, CurrentTimezone: "Asia/Seoul"})
	require.ErrorIs(t, err, pgx.ErrNoRows)
}

func TestCache_ChartAndMonthRoundTrip(t *testing.T) {
	ctx := context.Background()
	q := cachedb.New(dbtest.New(t))
	hash := make([]byte, 32)

	require.NoError(t, q.PutChart(ctx, cachedb.PutChartParams{BirthHash: hash, RulesetVersion: "v1", AsOfYear: 2026, Response: []byte("chart")}))
	require.NoError(t, q.PutMonth(ctx, cachedb.PutMonthParams{BirthHash: hash, RulesetVersion: "v1", Year: 2026, Month: 10, CurrentTimezone: "Asia/Seoul", Response: []byte("month")}))

	chart, err := q.GetChart(ctx, cachedb.GetChartParams{BirthHash: hash, RulesetVersion: "v1", AsOfYear: 2026})
	require.NoError(t, err)
	require.Equal(t, []byte("chart"), chart)
	month, err := q.GetMonth(ctx, cachedb.GetMonthParams{BirthHash: hash, RulesetVersion: "v1", Year: 2026, Month: 10, CurrentTimezone: "Asia/Seoul"})
	require.NoError(t, err)
	require.Equal(t, []byte("month"), month)
}

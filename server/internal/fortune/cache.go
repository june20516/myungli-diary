package fortune

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/fortune/cachedb"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// ChartKey는 원국 캐시 키입니다.
type ChartKey struct {
	BirthHash [32]byte
	Ruleset   string
	AsOfYear  int
}

// DailyKey는 오늘 운세 캐시 키입니다.
type DailyKey struct {
	BirthHash       [32]byte
	Ruleset         string
	Date            profile.LocalDate
	CurrentTimezone string
}

// MonthKey는 월간 달력 캐시 키입니다.
type MonthKey struct {
	BirthHash       [32]byte
	Ruleset         string
	Year, Month     int
	CurrentTimezone string
}

// ResultCache는 엔진 응답 protobuf bytes를 담습니다. 없으면 (nil, false, nil)입니다.
type ResultCache interface {
	GetChart(ctx context.Context, k ChartKey) ([]byte, bool, error)
	PutChart(ctx context.Context, k ChartKey, response []byte) error
	GetDaily(ctx context.Context, k DailyKey) ([]byte, bool, error)
	PutDaily(ctx context.Context, k DailyKey, response []byte) error
	GetMonth(ctx context.Context, k MonthKey) ([]byte, bool, error)
	PutMonth(ctx context.Context, k MonthKey, response []byte) error
}

type postgresCache struct {
	queries *cachedb.Queries
}

// NewPostgresCache는 PostgreSQL에 엔진 응답을 두는 ResultCache를 만듭니다.
func NewPostgresCache(pool *pgxpool.Pool) ResultCache {
	return &postgresCache{queries: cachedb.New(pool)}
}

// found는 pgx.ErrNoRows를 "없음"으로 바꿉니다.
func found(response []byte, err error) ([]byte, bool, error) {
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	return response, true, nil
}

func pgDate(d profile.LocalDate) pgtype.Date {
	return pgtype.Date{
		Time:  time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC),
		Valid: true,
	}
}

func (c *postgresCache) GetChart(ctx context.Context, k ChartKey) ([]byte, bool, error) {
	return found(c.queries.GetChart(ctx, cachedb.GetChartParams{
		BirthHash: k.BirthHash[:], RulesetVersion: k.Ruleset, AsOfYear: toInt32(k.AsOfYear),
	}))
}

func (c *postgresCache) PutChart(ctx context.Context, k ChartKey, response []byte) error {
	return c.queries.PutChart(ctx, cachedb.PutChartParams{
		BirthHash: k.BirthHash[:], RulesetVersion: k.Ruleset, AsOfYear: toInt32(k.AsOfYear), Response: response,
	})
}

func (c *postgresCache) GetDaily(ctx context.Context, k DailyKey) ([]byte, bool, error) {
	return found(c.queries.GetDaily(ctx, cachedb.GetDailyParams{
		BirthHash: k.BirthHash[:], RulesetVersion: k.Ruleset, Date: pgDate(k.Date), CurrentTimezone: k.CurrentTimezone,
	}))
}

func (c *postgresCache) PutDaily(ctx context.Context, k DailyKey, response []byte) error {
	return c.queries.PutDaily(ctx, cachedb.PutDailyParams{
		BirthHash: k.BirthHash[:], RulesetVersion: k.Ruleset, Date: pgDate(k.Date),
		CurrentTimezone: k.CurrentTimezone, Response: response,
	})
}

func (c *postgresCache) GetMonth(ctx context.Context, k MonthKey) ([]byte, bool, error) {
	return found(c.queries.GetMonth(ctx, cachedb.GetMonthParams{
		BirthHash: k.BirthHash[:], RulesetVersion: k.Ruleset,
		Year: toInt32(k.Year), Month: toInt32(k.Month), CurrentTimezone: k.CurrentTimezone,
	}))
}

func (c *postgresCache) PutMonth(ctx context.Context, k MonthKey, response []byte) error {
	return c.queries.PutMonth(ctx, cachedb.PutMonthParams{
		BirthHash: k.BirthHash[:], RulesetVersion: k.Ruleset,
		Year: toInt32(k.Year), Month: toInt32(k.Month), CurrentTimezone: k.CurrentTimezone, Response: response,
	})
}

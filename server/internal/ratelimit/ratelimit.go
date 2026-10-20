// Package ratelimit은 키별 고정 창 요청 한도를 PostgreSQL에 셉니다.
package ratelimit

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/ratelimit/ratelimitdb"
)

// Limiter는 키별 요청 수를 고정 창으로 셉니다.
type Limiter struct {
	pool *pgxpool.Pool
	clk  clock.Clock
}

// New는 연결 풀과 시계 위에 Limiter를 만듭니다.
func New(pool *pgxpool.Pool, clk clock.Clock) *Limiter {
	return &Limiter{pool: pool, clk: clk}
}

// Allow는 key의 현재 창 요청 수를 하나 올리고 limit 이내인지 알려 줍니다.
// 창은 window 단위로 내림한 시각에 시작하는 고정 창입니다. 한도를 넘어도 센 값은 남습니다.
// 거부되면 retryAfter는 현재 창이 끝날 때까지 남은 시간이고, 허용되면 0입니다.
func (l *Limiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, retryAfter time.Duration, err error) {
	now := l.clk.Now()
	windowStart := now.Truncate(window)
	count, err := ratelimitdb.New(l.pool).IncrementRateLimit(ctx, ratelimitdb.IncrementRateLimitParams{Key: key, WindowStart: windowStart})
	if err != nil {
		return false, 0, fmt.Errorf("요청 한도 집계: %w", err)
	}
	if int(count) <= limit {
		return true, 0, nil
	}
	return false, windowStart.Add(window).Sub(now), nil
}

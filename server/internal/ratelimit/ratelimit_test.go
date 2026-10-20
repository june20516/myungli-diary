package ratelimit_test

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/ratelimit"
)

const (
	testLimit  = 30
	testWindow = time.Minute
)

func newLimiter(t *testing.T, start time.Time) (*ratelimit.Limiter, *clocktest.Fake) {
	t.Helper()
	clk := clocktest.New(start)
	return ratelimit.New(dbtest.New(t), clk), clk
}

func TestAllow_RejectsAfterLimitWithRetryAfterToWindowEnd(t *testing.T) {
	ctx := context.Background()
	limiter, _ := newLimiter(t, time.Date(2026, 10, 20, 9, 0, 15, 0, time.UTC))

	for i := 1; i <= testLimit; i++ {
		allowed, retryAfter, err := limiter.Allow(ctx, "getBirthHour:abc", testLimit, testWindow)
		require.NoError(t, err)
		require.True(t, allowed, "%d번째 요청", i)
		assert.Zero(t, retryAfter)
	}

	allowed, retryAfter, err := limiter.Allow(ctx, "getBirthHour:abc", testLimit, testWindow)
	require.NoError(t, err)
	assert.False(t, allowed, "31번째 요청")
	assert.Equal(t, 45*time.Second, retryAfter, "창 끝(09:01:00)까지 남은 시간")
}

func TestAllow_NextWindowStartsFresh(t *testing.T) {
	ctx := context.Background()
	limiter, clk := newLimiter(t, time.Date(2026, 10, 20, 9, 0, 0, 0, time.UTC))
	for range testLimit + 1 {
		_, _, err := limiter.Allow(ctx, "k", testLimit, testWindow)
		require.NoError(t, err)
	}

	clk.Set(time.Date(2026, 10, 20, 9, 0, 59, 0, time.UTC))
	allowed, retryAfter, err := limiter.Allow(ctx, "k", testLimit, testWindow)
	require.NoError(t, err)
	assert.False(t, allowed, "59초에는 같은 창입니다")
	assert.Equal(t, time.Second, retryAfter)

	clk.Set(time.Date(2026, 10, 20, 9, 1, 1, 0, time.UTC))
	allowed, _, err = limiter.Allow(ctx, "k", testLimit, testWindow)
	require.NoError(t, err)
	assert.True(t, allowed, "61초에는 다음 창의 첫 요청입니다")
}

func TestAllow_KeysAreIndependent(t *testing.T) {
	ctx := context.Background()
	limiter, _ := newLimiter(t, time.Date(2026, 10, 20, 9, 0, 0, 0, time.UTC))
	for range testLimit + 1 {
		_, _, err := limiter.Allow(ctx, "getBirthHour:a", testLimit, testWindow)
		require.NoError(t, err)
	}

	for _, key := range []string{"getBirthHour:b", "convertLunarDate:a"} {
		allowed, _, err := limiter.Allow(ctx, key, testLimit, testWindow)
		require.NoError(t, err)
		assert.True(t, allowed, key)
	}
}

func TestAllow_ConcurrentRequestsAllowExactlyLimit(t *testing.T) {
	ctx := context.Background()
	limiter, _ := newLimiter(t, time.Date(2026, 10, 20, 9, 0, 0, 0, time.UTC))

	var allowedCount atomic.Int64
	var wg sync.WaitGroup
	for range 40 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			allowed, _, err := limiter.Allow(ctx, "k", testLimit, testWindow)
			assert.NoError(t, err)
			if allowed {
				allowedCount.Add(1)
			}
		}()
	}
	wg.Wait()

	assert.EqualValues(t, testLimit, allowedCount.Load())
}

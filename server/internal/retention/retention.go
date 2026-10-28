// Package retention은 job retention이 지우거나 비우는 데이터의 보관 기간과 정리 단계를 담습니다(spec §8.3, S113, S119, S120).
// 허가 취소 재시도(auth)와 합치기 영수증(merge)은 각 패키지가 맡고, cli가 이 패키지의 단계와 함께 돌립니다.
package retention

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/internal/retention/retentiondb"
)

const (
	// CacheTTL은 엔진 결과 캐시(chart·daily·month)를 만든 뒤 남겨 두는 기간입니다(spec §8.3, S120).
	CacheTTL = 30 * 24 * time.Hour
	// IdempotencyTTL은 Idempotency-Key 기록을 남겨 두는 기간입니다(spec §8.3).
	IdempotencyTTL = 24 * time.Hour
	// RateLimitWindow는 요청 한도의 고정 창 길이입니다(S68). 끝난 창은 지웁니다.
	RateLimitWindow = time.Minute
	// ExpiredGrace는 일회용 토큰 행(합치기 토큰, Apple 웹 로그인 교환 코드)을 만료 뒤 남겨 두는 기간입니다.
	ExpiredGrace = 24 * time.Hour
	// InactiveDeviceTTL은 비활성 알림 기기를 마지막으로 본 뒤 남겨 두는 기간입니다(S119).
	InactiveDeviceTTL = 30 * 24 * time.Hour
	// SoftDeleteTTL은 사용자가 지운 일기·일정을 복구할 수 있는 기간입니다. 지나면 내용을 비웁니다(S6).
	SoftDeleteTTL = 30 * 24 * time.Hour
)

// 연 단위 보관 기간입니다(S113). 달력 기준으로 now.AddDate(-n, 0, 0)을 씁니다.
const (
	// PreviewUsageYears는 미리보기 설치 id 해시의 보관 기간입니다.
	PreviewUsageYears = 1
	// RewardYears는 보상형 광고 기록(SSV 콜백과 보상 구간)의 보관 기간입니다.
	RewardYears = 1
	// BillingYears는 결제 기록(webhook 수신, 구매 장부, 결제 구간)의 보관 기간입니다.
	// 결제 동기화가 이보다 오래된 구매를 다시 적지 않도록 billing과 같은 값을 씁니다.
	BillingYears = billing.RecordYears
)

// Step은 정리 단계 하나입니다. Run은 지우거나 비운 행 수를 돌려줍니다.
type Step struct {
	Name string
	Run  func(ctx context.Context) (int64, error)
}

// Store는 정리 쿼리를 실행합니다.
type Store struct {
	pool *pgxpool.Pool
	q    *retentiondb.Queries
	clk  clock.Clock
}

// NewStore는 pool과 시계로 Store를 만듭니다.
func NewStore(pool *pgxpool.Pool, clk clock.Clock) *Store {
	return &Store{pool: pool, q: retentiondb.New(pool), clk: clk}
}

// Steps는 DB만 쓰는 정리 단계를 실행 순서대로 돌려줍니다. 단계마다 그때의 시각을 기준으로 삼습니다.
func (s *Store) Steps() []Step {
	return []Step{
		{Name: "캐시", Run: s.deleteExpiredCaches},
		{Name: "idempotency_keys", Run: s.before(IdempotencyTTL, s.q.DeleteIdempotencyKeysBefore)},
		{Name: "rate_limits", Run: s.before(RateLimitWindow, s.q.DeleteEndedRateLimits)},
		{Name: "refresh_tokens", Run: func(ctx context.Context) (int64, error) {
			return s.q.DeleteExpiredRefreshTokens(ctx, s.clk.Now())
		}},
		{Name: "합치기 토큰", Run: s.before(ExpiredGrace, s.q.DeleteMergeTicketsExpiredBefore)},
		{Name: "Apple 웹 로그인", Run: s.deleteExpiredAppleWebLogins},
		{Name: "알림 기기", Run: s.before(InactiveDeviceTTL, s.q.DeleteInactiveDevicesSeenBefore)},
		{Name: "미리보기 설치 해시", Run: s.yearsBefore(PreviewUsageYears, s.q.DeletePreviewUsageBefore)},
		{Name: "보상 기록", Run: s.deleteRewardRecords},
		{Name: "결제 기록", Run: s.deleteBillingRecords},
		{Name: "지운 일기", Run: s.purgeDeletedDiaries},
		{Name: "지운 일정", Run: s.purgeDeletedSchedules},
	}
}

// before는 now − age를 기준 시각으로 넘기는 단계 함수를 만듭니다.
func (s *Store) before(age time.Duration, del func(context.Context, time.Time) (int64, error)) func(context.Context) (int64, error) {
	return func(ctx context.Context) (int64, error) {
		return del(ctx, s.clk.Now().Add(-age))
	}
}

// yearsBefore는 now에서 years년 전을 기준 시각으로 넘기는 단계 함수를 만듭니다.
func (s *Store) yearsBefore(years int, del func(context.Context, time.Time) (int64, error)) func(context.Context) (int64, error) {
	return func(ctx context.Context) (int64, error) {
		return del(ctx, s.clk.Now().AddDate(-years, 0, 0))
	}
}

// deleteRewardRecords는 1년 지난 보상형 광고 콜백 기록과 1년 전에 끝난 보상 구간을 지웁니다.
func (s *Store) deleteRewardRecords(ctx context.Context) (int64, error) {
	cutoff := s.clk.Now().AddDate(-RewardYears, 0, 0)
	return sum(ctx, cutoff, s.q.DeleteRewardEventsBefore, s.q.DeleteRewardGrantsEndedBefore)
}

// deleteBillingRecords는 5년 지난 결제 기록을 지웁니다. 구매는 남은 구간이 없을 때만 지우므로
// 구간을 먼저 지우고, 둘 사이에 다른 쓰기가 끼지 않도록 한 트랜잭션으로 묶습니다.
func (s *Store) deleteBillingRecords(ctx context.Context) (int64, error) {
	cutoff := s.clk.Now().AddDate(-BillingYears, 0, 0)
	var total int64
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		n, err := sum(ctx, cutoff, q.DeletePaidGrantsEndedBefore, q.DeletePurchasesBefore, q.DeleteBillingEventsBefore)
		total = n
		return err
	})
	return total, err
}

// deleteExpiredAppleWebLogins는 만료 + 1일 지난 Apple 웹 로그인 행을 지우고, 연결되지 않은 행의 Apple 토큰은
// 같은 트랜잭션에서 허가 취소 대기 행으로 넘깁니다. 지운 행 수를 돌려줍니다.
func (s *Store) deleteExpiredAppleWebLogins(ctx context.Context) (int64, error) {
	now := s.clk.Now()
	cutoff := now.Add(-ExpiredGrace)
	var deleted int64
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		_, err := q.QueueUnclaimedAppleWebLoginRevocations(ctx, retentiondb.QueueUnclaimedAppleWebLoginRevocationsParams{Now: now, Cutoff: cutoff})
		if err != nil {
			return err
		}
		deleted, err = q.DeleteAppleWebLoginsExpiredBefore(ctx, cutoff)
		return err
	})
	return deleted, err
}

func (s *Store) purgeDeletedDiaries(ctx context.Context) (int64, error) {
	now := s.clk.Now()
	return s.q.PurgeDeletedDiaries(ctx, retentiondb.PurgeDeletedDiariesParams{Now: now, Cutoff: now.Add(-SoftDeleteTTL)})
}

func (s *Store) purgeDeletedSchedules(ctx context.Context) (int64, error) {
	now := s.clk.Now()
	return s.q.PurgeDeletedSchedules(ctx, retentiondb.PurgeDeletedSchedulesParams{Now: now, Cutoff: now.Add(-SoftDeleteTTL)})
}

func (s *Store) deleteExpiredCaches(ctx context.Context) (int64, error) {
	cutoff := s.clk.Now().Add(-CacheTTL)
	return sum(ctx, cutoff, s.q.DeleteChartCacheBefore, s.q.DeleteDailyCacheBefore, s.q.DeleteMonthCacheBefore)
}

// DeleteStaleRulesetCaches는 current가 아닌 ruleset_version의 캐시를 지웁니다(spec §8.3).
// current는 엔진 GetInfo로 받은 지금 버전이며, 비어 있으면 모든 캐시를 지우게 되므로 거절합니다.
func (s *Store) DeleteStaleRulesetCaches(ctx context.Context, current string) (int64, error) {
	if current == "" {
		return 0, fmt.Errorf("현재 ruleset_version이 비어 있습니다")
	}
	return sum(ctx, current, s.q.DeleteChartCacheOtherVersions, s.q.DeleteDailyCacheOtherVersions, s.q.DeleteMonthCacheOtherVersions)
}

// sum은 같은 인자로 삭제 쿼리 여러 개를 차례로 돌려 지운 수를 더합니다.
func sum[T any](ctx context.Context, arg T, dels ...func(context.Context, T) (int64, error)) (int64, error) {
	var total int64
	for _, del := range dels {
		n, err := del(ctx, arg)
		if err != nil {
			return total, err
		}
		total += n
	}
	return total, nil
}

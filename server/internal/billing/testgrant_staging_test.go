//go:build staging

package billing_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// 테스트 광고 제거 기간은 실제 광고 제거권처럼 ad_free와 insight를 지금부터 days일 동안 줍니다(S125).
func TestTestGrant_GrantsAdFreeAndInsight(t *testing.T) {
	pool := dbtest.New(t)
	store := billing.NewStore(pool, clocktest.New(now), nil)
	accountID := newAccount(t, pool)

	status, err := store.GrantTest(context.Background(), accountID, 30)
	require.NoError(t, err)

	want := now.Add(30 * 24 * time.Hour)
	for name, state := range map[string]billing.State{"ad_free": status.AdFree, "insight": status.Insight} {
		assert.True(t, state.Active, name)
		require.NotNil(t, state.ExpiresAt, name)
		assert.Equal(t, want, state.ExpiresAt.UTC(), name)
		assert.Equal(t, billing.SourceTestGrant, state.Source, name)
	}
	again, err := store.Status(context.Background(), accountID)
	require.NoError(t, err)
	assert.Equal(t, status, again, "부여 응답은 저장된 상태와 같음")

	purchases, err := store.Purchases(context.Background(), accountID)
	require.NoError(t, err)
	assert.Empty(t, purchases, "구매 목록에는 나오지 않음")
}

// days는 1~366입니다. 밖이면 아무것도 적지 않습니다.
func TestTestGrant_RejectsDaysOutOfRange(t *testing.T) {
	pool := dbtest.New(t)
	store := billing.NewStore(pool, clocktest.New(now), nil)
	accountID := newAccount(t, pool)

	for _, days := range []int{0, -1, billing.MaxTestGrantDays + 1} {
		_, err := store.GrantTest(context.Background(), accountID, days)
		require.ErrorIs(t, err, billing.ErrTestGrantDays, "days=%d", days)
	}
	_, err := store.GrantTest(context.Background(), accountID, billing.MaxTestGrantDays)
	require.NoError(t, err)
	assert.Equal(t, 2, testGrantCount(t, pool, accountID))
}

// 없는 계정과 지운 계정에는 주지 않습니다.
func TestTestGrant_RejectsMissingOrDeletedAccount(t *testing.T) {
	pool := dbtest.New(t)
	store := billing.NewStore(pool, clocktest.New(now), nil)
	deleted := newAccount(t, pool)
	_, err := pool.Exec(context.Background(),
		`UPDATE accounts SET status = 'deleted', deleted_at = $2 WHERE id = $1`, deleted, now)
	require.NoError(t, err)

	for name, id := range map[string]uuid.UUID{"없는 계정": uuid.New(), "지운 계정": deleted} {
		_, err := store.GrantTest(context.Background(), id, 30)
		require.ErrorIs(t, err, billing.ErrTestGrantAccount, name)
	}
}

// 회수는 그 계정의 테스트 기간만 지금 끊고, 다른 출처와 다른 계정의 구간은 그대로 둡니다. 두 번 불러도 됩니다.
func TestTestGrant_RevokeEndsOnlyTestGrants(t *testing.T) {
	pool := dbtest.New(t)
	store := billing.NewStore(pool, clocktest.New(now), nil)
	accountID, other := newAccount(t, pool), newAccount(t, pool)
	_, err := store.GrantTest(context.Background(), accountID, 30)
	require.NoError(t, err)
	_, err = store.GrantTest(context.Background(), other, 30)
	require.NoError(t, err)
	reward := now.Add(time.Hour)
	_, err = pool.Exec(context.Background(), `
		INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'insight', 'rewarded_ad', 'reward-1', $2, $3)`, accountID, now, reward)
	require.NoError(t, err)

	status, err := store.RevokeTest(context.Background(), accountID)
	require.NoError(t, err)

	assert.False(t, status.AdFree.Active)
	assert.True(t, status.Insight.Active, "보상형 광고 구간은 남음")
	assert.Equal(t, billing.SourceRewardedAd, status.Insight.Source)
	otherStatus, err := store.Status(context.Background(), other)
	require.NoError(t, err)
	assert.True(t, otherStatus.AdFree.Active, "다른 계정은 그대로")

	_, err = store.RevokeTest(context.Background(), accountID)
	require.NoError(t, err)
}

// 회수도 없는 계정이면 오류라, 오타 난 id로 회수했다고 믿지 않게 합니다.
func TestTestGrant_RevokeRejectsMissingAccount(t *testing.T) {
	pool := dbtest.New(t)
	store := billing.NewStore(pool, clocktest.New(now), nil)

	_, err := store.RevokeTest(context.Background(), uuid.New())

	require.ErrorIs(t, err, billing.ErrTestGrantAccount)
}

// 테스트 기간은 유료 광고 제거권 구간의 시작(NextPassStart)을 미루지 않고 구매 목록에도 나오지 않습니다.
// 유료 구간 쿼리가 출처를 ad_free_pass로 거르는 불변식을 고정합니다.
func TestTestGrant_DoesNotChainWithPaidPass(t *testing.T) {
	f := newSyncFixture(t)
	store := billing.NewStore(f.pool, clocktest.New(now), billing.AdFreeCatalog([]string{testAdFreeProduct}))
	accountID := newAccount(t, f.pool)
	_, err := store.GrantTest(context.Background(), accountID, billing.MaxTestGrantDays)
	require.NoError(t, err)

	f.source.set(accountID, owned("paid", now))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	assertPeriod(t, allGrants(t, f.pool), "paid", now, now.AddDate(0, 1, 0), nil)
	purchases, err := store.Purchases(context.Background(), accountID)
	require.NoError(t, err)
	require.Len(t, purchases, 1, "구매 목록에는 유료 구매만")
	assert.Equal(t, testAdFreeProduct, purchases[0].ProductID)
}

func testGrantCount(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID) int {
	t.Helper()
	var count int
	require.NoError(t, pool.QueryRow(context.Background(),
		`SELECT count(*) FROM entitlement_grants WHERE account_id = $1 AND source = 'test_grant'`, accountID).Scan(&count))
	return count
}

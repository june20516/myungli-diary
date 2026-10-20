package billing_test

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
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

const testAdFreeProduct = "test.ad_free.month"

// fakePurchases는 고객 id별 구매 목록을 돌려주는 가짜 PurchaseSource입니다.
// 동시에 진행 중인 호출 수의 최댓값을 셉니다.
type fakePurchases struct {
	mu        sync.Mutex
	purchases map[string][]billing.Purchase
	err       error
	delay     time.Duration

	inFlight    atomic.Int32
	maxInFlight atomic.Int32
	calls       atomic.Int32
}

func newFakePurchases() *fakePurchases {
	return &fakePurchases{purchases: map[string][]billing.Purchase{}}
}

func (f *fakePurchases) set(accountID uuid.UUID, purchases ...billing.Purchase) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.purchases[accountID.String()] = purchases
}

func (f *fakePurchases) failWith(err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.err = err
}

func (f *fakePurchases) Purchases(_ context.Context, customerID string) ([]billing.Purchase, error) {
	f.calls.Add(1)
	current := f.inFlight.Add(1)
	defer f.inFlight.Add(-1)
	for {
		seen := f.maxInFlight.Load()
		if current <= seen || f.maxInFlight.CompareAndSwap(seen, current) {
			break
		}
	}
	if f.delay > 0 {
		time.Sleep(f.delay)
	}

	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return nil, f.err
	}
	return append([]billing.Purchase(nil), f.purchases[customerID]...), nil
}

func owned(id string, at time.Time) billing.Purchase {
	return billing.Purchase{ID: id, ProductID: testAdFreeProduct, PurchasedAt: at, Production: true}
}

func refunded(id string, at time.Time) billing.Purchase {
	p := owned(id, at)
	p.Refunded = true
	return p
}

// storedGrant는 entitlement_grants 한 행을 비교하기 쉬운 모양으로 읽은 것입니다.
type storedGrant struct {
	AccountID   uuid.UUID
	Entitlement string
	Source      string
	SourceRef   string
	StartsAt    time.Time
	ExpiresAt   time.Time
	RevokedAt   *time.Time
}

func (g storedGrant) String() string {
	return fmt.Sprintf("%s/%s/%s %v~%v revoked=%v", g.Entitlement, g.Source, g.SourceRef, g.StartsAt.UTC(), g.ExpiresAt.UTC(), g.RevokedAt)
}

// allGrants는 표 전체 행을 (source_ref, entitlement, source) 순으로 읽습니다.
func allGrants(t *testing.T, pool *pgxpool.Pool) []storedGrant {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		`SELECT account_id, entitlement, source, source_ref, starts_at, expires_at, revoked_at
		 FROM entitlement_grants ORDER BY source_ref, entitlement, source`)
	require.NoError(t, err)
	defer rows.Close()
	var out []storedGrant
	for rows.Next() {
		var g storedGrant
		require.NoError(t, rows.Scan(&g.AccountID, &g.Entitlement, &g.Source, &g.SourceRef, &g.StartsAt, &g.ExpiresAt, &g.RevokedAt))
		out = append(out, g)
	}
	require.NoError(t, rows.Err())
	return out
}

func findGrant(t *testing.T, grants []storedGrant, entitlement billing.Entitlement, ref string) storedGrant {
	t.Helper()
	for _, g := range grants {
		if g.Entitlement == string(entitlement) && g.SourceRef == ref && g.Source == string(billing.SourceAdFreePass) {
			return g
		}
	}
	t.Fatalf("행 없음: %s %s (전체 %v)", entitlement, ref, grants)
	return storedGrant{}
}

// assertPeriod는 구매 ref의 두 행(ad_free, insight)이 같은 기간이고 취소 상태가 기대와 같은지 봅니다.
func assertPeriod(t *testing.T, grants []storedGrant, ref string, starts, expires time.Time, revokedAt *time.Time) {
	t.Helper()
	for _, entitlement := range []billing.Entitlement{billing.AdFree, billing.Insight} {
		g := findGrant(t, grants, entitlement, ref)
		assert.True(t, g.StartsAt.Equal(starts), "%s %s starts: got %v, want %v", entitlement, ref, g.StartsAt.UTC(), starts)
		assert.True(t, g.ExpiresAt.Equal(expires), "%s %s expires: got %v, want %v", entitlement, ref, g.ExpiresAt.UTC(), expires)
		if revokedAt == nil {
			assert.Nil(t, g.RevokedAt, "%s %s는 취소되지 않음", entitlement, ref)
		} else if assert.NotNil(t, g.RevokedAt, "%s %s는 취소됨", entitlement, ref) {
			assert.True(t, g.RevokedAt.Equal(*revokedAt), "%s %s revoked_at: got %v, want %v", entitlement, ref, g.RevokedAt.UTC(), *revokedAt)
		}
	}
}

type syncFixture struct {
	pool   *pgxpool.Pool
	source *fakePurchases
	clk    *clocktest.Fake
	syncer *billing.Syncer
}

func newSyncFixture(t *testing.T) syncFixture {
	t.Helper()
	pool := dbtest.New(t)
	source := newFakePurchases()
	clk := clocktest.New(now)
	syncer := billing.NewSyncer(pool, source, billing.SyncConfig{AdFreeProductIDs: []string{testAdFreeProduct}}, clk)
	return syncFixture{pool: pool, source: source, clk: clk, syncer: syncer}
}

// 구매 셋: 10월 1일, 10월 10일, 10월 15일. 만료 전 재구매라 이어 붙습니다.
var (
	oct1  = time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	oct10 = time.Date(2026, 10, 10, 0, 0, 0, 0, time.UTC)
	oct15 = time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC)
	nov1  = time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	dec1  = time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)
	jan1  = time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)
)

func TestSyncer_Sync_FirstSync_CreatesRows(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10))

	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	grants := allGrants(t, f.pool)
	require.Len(t, grants, 4)
	for _, g := range grants {
		assert.Equal(t, accountID, g.AccountID)
	}
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	assertPeriod(t, grants, "p2", nov1, dec1, nil)
}

func TestSyncer_Sync_SameList_Idempotent(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	before := allGrants(t, f.pool)

	f.clk.Advance(time.Hour)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	after := allGrants(t, f.pool)
	assert.Equal(t, fmt.Sprint(before), fmt.Sprint(after))
}

func TestSyncer_Sync_MiddleRefunded_RevokesAndPullsLaterForward(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	assertPeriod(t, allGrants(t, f.pool), "p3", dec1, jan1, nil)

	f.clk.Advance(time.Hour)
	refundedAt := f.clk.Now()
	f.source.set(accountID, owned("p1", oct1), refunded("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	grants := allGrants(t, f.pool)
	assert.Len(t, grants, 6, "새 행을 만들지 않고 행을 지우지도 않음")
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	assertPeriod(t, grants, "p2", nov1, dec1, &refundedAt)
	assertPeriod(t, grants, "p3", nov1, dec1, nil)

	// 같은 목록으로 다시 동기화해도 이미 찍힌 revoked_at은 그대로입니다.
	f.clk.Advance(time.Hour)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	assertPeriod(t, allGrants(t, f.pool), "p2", nov1, dec1, &refundedAt)
}

func TestSyncer_Sync_RefundReversed_RestoresRows(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1), refunded("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	f.source.set(accountID, owned("p1", oct1), refunded("p2", oct10), owned("p3", oct15))
	f.clk.Advance(time.Hour)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	f.clk.Advance(time.Hour)
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	grants := allGrants(t, f.pool)
	assert.Len(t, grants, 6)
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	assertPeriod(t, grants, "p2", nov1, dec1, nil)
	assertPeriod(t, grants, "p3", dec1, jan1, nil)
}

func TestSyncer_Sync_AllPurchasesGone_RevokesAll(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	f.source.set(accountID)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	grants := allGrants(t, f.pool)
	assertPeriod(t, grants, "p1", oct1, nov1, &now)
}

func TestSyncer_Sync_OtherSourcesUntouched(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	midnight := time.Date(2026, 10, 21, 0, 0, 0, 0, time.UTC)
	insertGrant(t, f.pool, accountID, grant(billing.Insight, billing.SourceRewardedAd, "tx1", now.Add(-time.Hour), midnight))
	insertGrant(t, f.pool, accountID, grant(billing.AdFree, billing.SourceSubscription, "sub1", oct1, nov1))
	f.source.set(accountID, owned("p1", oct1))

	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	f.source.set(accountID)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	grants := allGrants(t, f.pool)
	require.Len(t, grants, 4)
	for _, g := range grants {
		if g.Source == string(billing.SourceAdFreePass) {
			continue
		}
		assert.Nil(t, g.RevokedAt, "%v는 건드리지 않음", g)
	}
	rewarded := grants[slicesIndex(grants, "tx1")]
	assert.True(t, rewarded.StartsAt.Equal(now.Add(-time.Hour)))
	assert.True(t, rewarded.ExpiresAt.Equal(midnight))
	subscription := grants[slicesIndex(grants, "sub1")]
	assert.True(t, subscription.StartsAt.Equal(oct1))
	assert.True(t, subscription.ExpiresAt.Equal(nov1))
}

func slicesIndex(grants []storedGrant, ref string) int {
	for i, g := range grants {
		if g.SourceRef == ref {
			return i
		}
	}
	return -1
}

func TestSyncer_Sync_OtherAccountRowsUntouched(t *testing.T) {
	f := newSyncFixture(t)
	mine := newAccount(t, f.pool)
	other := newAccount(t, f.pool)
	f.source.set(other, owned("other-p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), other))

	f.source.set(mine)
	require.NoError(t, f.syncer.Sync(context.Background(), mine))

	assertPeriod(t, allGrants(t, f.pool), "other-p1", oct1, nov1, nil)
}

func TestSyncer_Sync_ProviderError_NoChangesAndErrorPreserved(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	before := allGrants(t, f.pool)

	f.source.failWith(fmt.Errorf("구매 목록: %w", billing.ErrProviderUnavailable))
	f.clk.Advance(time.Hour)
	err := f.syncer.Sync(context.Background(), accountID)

	require.Error(t, err)
	assert.ErrorIs(t, err, billing.ErrProviderUnavailable)
	assert.Equal(t, fmt.Sprint(before), fmt.Sprint(allGrants(t, f.pool)))
}

func TestSyncer_Sync_OtherProviderError_Returned(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	configErr := errors.New("RevenueCat 401")
	f.source.failWith(configErr)

	err := f.syncer.Sync(context.Background(), accountID)

	assert.ErrorIs(t, err, configErr)
	assert.False(t, errors.Is(err, billing.ErrProviderUnavailable))
	assert.Empty(t, allGrants(t, f.pool))
}

func TestSyncer_Sync_PurchaseMovedToAnotherAccount_RowFollowsOwner(t *testing.T) {
	f := newSyncFixture(t)
	accountA := newAccount(t, f.pool)
	accountB := newAccount(t, f.pool)
	f.source.set(accountA, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountA))

	// RevenueCat transfer 뒤 p1은 B의 목록에 옵니다.
	f.source.set(accountA)
	f.source.set(accountB, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountB))

	grants := allGrants(t, f.pool)
	require.Len(t, grants, 2)
	for _, g := range grants {
		assert.Equal(t, accountB, g.AccountID, "%v는 지금 주인 B의 행", g)
	}
	assertPeriod(t, grants, "p1", oct1, nov1, nil)

	// A를 다시 동기화해도 B로 옮겨 간 행은 건드리지 않습니다.
	require.NoError(t, f.syncer.Sync(context.Background(), accountA))
	assertPeriod(t, allGrants(t, f.pool), "p1", oct1, nov1, nil)
}

func TestSyncer_Sync_ConcurrentSameAccount_LookupsDoNotOverlap(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	f.source.delay = 50 * time.Millisecond

	const workers = 4
	var wg sync.WaitGroup
	errs := make([]error, workers)
	for i := range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			errs[i] = f.syncer.Sync(context.Background(), accountID)
		}()
	}
	wg.Wait()

	for _, err := range errs {
		require.NoError(t, err)
	}
	assert.Equal(t, int32(workers), f.source.calls.Load())
	assert.Equal(t, int32(1), f.source.maxInFlight.Load(), "같은 계정 조회는 lock 안에서 한 번에 하나")
	assert.Len(t, allGrants(t, f.pool), 2)
}

func TestSyncer_Restore_ReturnsStatusAfterSync(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct10), owned("p2", oct15))

	status, err := f.syncer.Restore(context.Background(), accountID)

	require.NoError(t, err)
	assert.True(t, status.AdFree.Active)
	require.NotNil(t, status.AdFree.ExpiresAt)
	assert.True(t, status.AdFree.ExpiresAt.Equal(time.Date(2026, 12, 10, 0, 0, 0, 0, time.UTC)), "이어 붙인 체인의 끝")
	assert.True(t, status.Insight.Active)
	assert.Equal(t, billing.SourceAdFreePass, status.Insight.Source)
}

func TestSyncer_Restore_ProviderError_Returned(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.failWith(billing.ErrProviderUnavailable)

	_, err := f.syncer.Restore(context.Background(), accountID)

	assert.ErrorIs(t, err, billing.ErrProviderUnavailable)
}

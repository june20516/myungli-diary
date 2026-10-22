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
	// onCall은 목록을 돌려주기 전에 고객 id로 불립니다(동시성 테스트의 만남 지점). nil이면 부르지 않습니다.
	onCall func(customerID string)

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
	if f.onCall != nil {
		f.onCall(customerID)
	}

	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return nil, f.err
	}
	return append([]billing.Purchase(nil), f.purchases[customerID]...), nil
}

// owned는 환불되지 않은 production 구매입니다. 스토어 거래 id는 "store-" + id입니다.
func owned(id string, at time.Time) billing.Purchase {
	return billing.Purchase{
		ID: id, ProductID: testAdFreeProduct, Store: "app_store", StorePurchaseID: "store-" + id,
		PurchasedAt: at, Production: true,
	}
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

// ledgerRow는 purchases 한 행에서 테스트가 보는 값입니다.
type ledgerRow struct {
	Owner           uuid.UUID
	Store           string
	StorePurchaseID *string
	RefundedAt      *time.Time
}

// ledgerOf는 장부의 구매 행을 읽습니다. 없으면 테스트를 멈춥니다.
func ledgerOf(t *testing.T, pool *pgxpool.Pool, purchaseID string) ledgerRow {
	t.Helper()
	var row ledgerRow
	require.NoError(t, pool.QueryRow(context.Background(),
		`SELECT account_id, store, store_purchase_id, refunded_at FROM purchases WHERE id = $1`, purchaseID).
		Scan(&row.Owner, &row.Store, &row.StorePurchaseID, &row.RefundedAt), "장부에 %s 없음", purchaseID)
	return row
}

func ledgerCount(t *testing.T, pool *pgxpool.Pool) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT count(*) FROM purchases`).Scan(&n))
	return n
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
	syncer := billing.NewSyncer(pool, source, billing.SyncConfig{Catalog: billing.AdFreeCatalog([]string{testAdFreeProduct})}, clk)
	return syncFixture{pool: pool, source: source, clk: clk, syncer: syncer}
}

// 구매 셋: 10월 1일, 10월 10일, 10월 15일. 만료 전 재구매라 이어 붙습니다.
var (
	oct1  = time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	oct10 = time.Date(2026, 10, 10, 0, 0, 0, 0, time.UTC)
	oct15 = time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC)
	nov1  = time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	dec1  = time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)
	// dec2는 12/1~1/1(31일) 대기 구간을 11/1로 당겼을 때의 끝입니다. 다시 잇기는 원래 길이를 유지합니다(S108).
	dec2 = time.Date(2026, 12, 2, 0, 0, 0, 0, time.UTC)
	jan1 = time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)
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

	// 장부에 이 계정을 주인으로 적고 스토어와 스토어 거래 id를 남깁니다(webhook 대체 경로가 찾는 값).
	require.Equal(t, 2, ledgerCount(t, f.pool))
	row := ledgerOf(t, f.pool, "p1")
	assert.Equal(t, accountID, row.Owner)
	assert.Equal(t, "app_store", row.Store)
	require.NotNil(t, row.StorePurchaseID)
	assert.Equal(t, "store-p1", *row.StorePurchaseID)
	assert.Nil(t, row.RefundedAt)
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
	assertPeriod(t, grants, "p3", nov1, dec2, nil)
	refundedRow := ledgerOf(t, f.pool, "p2")
	require.NotNil(t, refundedRow.RefundedAt)
	assert.True(t, refundedRow.RefundedAt.Equal(refundedAt))

	// 같은 목록으로 다시 동기화해도 이미 찍힌 revoked_at은 그대로입니다.
	f.clk.Advance(time.Hour)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))
	assertPeriod(t, allGrants(t, f.pool), "p2", nov1, dec1, &refundedAt)
}

// 환불은 장부에 한 번 적으면 되돌리지 않습니다(spec §5.3: 끊은 구간을 다시 잇지 않음).
// RevenueCat 구매 status는 owned·refunded뿐이고 환불 취소 경로가 없어, 목록이 다시 owned로 보여도 장부를 기준으로 둡니다.
func TestSyncer_Sync_RefundRecordedOnce_OwnedAgainKeepsRevoked(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	f.clk.Advance(time.Hour)
	refundedAt := f.clk.Now()
	f.source.set(accountID, owned("p1", oct1), refunded("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	f.clk.Advance(time.Hour)
	f.source.set(accountID, owned("p1", oct1), owned("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	grants := allGrants(t, f.pool)
	assert.Len(t, grants, 6)
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	assertPeriod(t, grants, "p2", nov1, dec1, &refundedAt)
	assertPeriod(t, grants, "p3", nov1, dec2, nil)
}

// 장부에 있는데 목록에서 빠진 구매(transfer로 다른 RevenueCat 고객에게 간 것)는 취소하지 않습니다(spec §5.4).
func TestSync_MissingFromListKeepsGrant(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	f.clk.Advance(time.Hour)
	f.source.set(accountID)
	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	assertPeriod(t, allGrants(t, f.pool), "p1", oct1, nov1, nil)
	assert.Equal(t, accountID, ledgerOf(t, f.pool, "p1").Owner)
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
		assert.Nil(t, g.RevokedAt, "%v는 취소하지 않음", g)
	}
	rewarded := grants[indexByRef(t, grants, "tx1")]
	assert.True(t, rewarded.StartsAt.Equal(now.Add(-time.Hour)))
	assert.True(t, rewarded.ExpiresAt.Equal(midnight))
	subscription := grants[indexByRef(t, grants, "sub1")]
	assert.True(t, subscription.StartsAt.Equal(oct1))
	assert.True(t, subscription.ExpiresAt.Equal(nov1))
}

// indexByRef는 source_ref가 ref인 행의 위치입니다. 없으면 테스트를 멈춥니다.
func indexByRef(t *testing.T, grants []storedGrant, ref string) int {
	t.Helper()
	for i, g := range grants {
		if g.SourceRef == ref {
			return i
		}
	}
	t.Fatalf("행 없음: %s (전체 %v)", ref, grants)
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

// A가 산 구매가 transfer로 B의 RevenueCat 목록에 나타나도 주인은 A 그대로이고 B에는 구간·권한이 없습니다(S107, S83 개정).
func TestSync_TransferDoesNotMoveOwner(t *testing.T) {
	f := newSyncFixture(t)
	accountA := newAccount(t, f.pool)
	accountB := newAccount(t, f.pool)
	f.source.set(accountA, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountA))

	f.clk.Advance(time.Hour)
	f.source.set(accountA)
	f.source.set(accountB, owned("p1", oct1))
	statusB, err := f.syncer.Restore(context.Background(), accountB)
	require.NoError(t, err)

	assert.Equal(t, accountA, ledgerOf(t, f.pool, "p1").Owner)
	grants := allGrants(t, f.pool)
	require.Len(t, grants, 2)
	for _, g := range grants {
		assert.Equal(t, accountA, g.AccountID, "B에는 구간이 없음")
	}
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	assert.False(t, statusB.AdFree.Active)
	assert.False(t, statusB.Insight.Active)
}

// B 목록에서 A가 주인인 구매가 환불로 보이면, 환불을 장부에 적고 A 구간을 now부터 다시 잇습니다(spec §5.4).
func TestSync_RefundSeenByNonOwner(t *testing.T) {
	f := newSyncFixture(t)
	accountA := newAccount(t, f.pool)
	accountB := newAccount(t, f.pool)
	f.source.set(accountA, owned("p1", oct1), owned("p2", oct10), owned("p3", oct15))
	require.NoError(t, f.syncer.Sync(context.Background(), accountA))

	f.clk.Advance(time.Hour)
	refundedAt := f.clk.Now()
	f.source.set(accountB, refunded("p2", oct10))
	require.NoError(t, f.syncer.Sync(context.Background(), accountB))

	row := ledgerOf(t, f.pool, "p2")
	assert.Equal(t, accountA, row.Owner, "주인은 그대로")
	require.NotNil(t, row.RefundedAt)
	assert.True(t, row.RefundedAt.Equal(refundedAt))
	grants := allGrants(t, f.pool)
	require.Len(t, grants, 6)
	for _, g := range grants {
		assert.Equal(t, accountA, g.AccountID, "B에는 구간이 없음")
	}
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	assertPeriod(t, grants, "p2", nov1, dec1, &refundedAt)
	assertPeriod(t, grants, "p3", nov1, dec2, nil)

	// 이미 환불로 적힌 다른 주인 구매는 A lock을 잡으러 다시 시작하지 않습니다(조회 1번으로 끝남).
	callsBefore := f.source.calls.Load()
	f.clk.Advance(time.Hour)
	require.NoError(t, f.syncer.Sync(context.Background(), accountB))
	assert.EqualValues(t, 1, f.source.calls.Load()-callsBefore)
	assertPeriod(t, allGrants(t, f.pool), "p2", nov1, dec1, &refundedAt)
}

// A와 B가 서로의 구매 환불을 동시에 보면 두 동기화 모두 다른 주인 lock이 필요합니다.
// 두 첫 조회가 각자 자기 계정 lock을 쥔 채 만나게 해(서로 다른 lock을 같은 순간 쥔 상태) 둘 다 deadline 안에 끝나는지 봅니다.
func TestSync_ConcurrentCrossAccountNoDeadlock(t *testing.T) {
	f := newSyncFixture(t)
	accountA := newAccount(t, f.pool)
	accountB := newAccount(t, f.pool)
	f.source.set(accountA, owned("pa", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), accountA))
	f.source.set(accountB, owned("pb", oct10))
	require.NoError(t, f.syncer.Sync(context.Background(), accountB))

	f.clk.Advance(time.Hour)
	refundedAt := f.clk.Now()
	f.source.set(accountA, owned("pa", oct1), refunded("pb", oct10))
	f.source.set(accountB, owned("pb", oct10), refunded("pa", oct1))

	// 두 계정의 첫 조회는 서로 기다렸다가 함께 돌아갑니다. 그 순간 A 동기화는 A lock, B 동기화는 B lock을 쥐고 있습니다.
	var seen sync.Map
	var arrived atomic.Int32
	met := make(chan struct{})
	f.source.onCall = func(customerID string) {
		if _, again := seen.LoadOrStore(customerID, true); again {
			return
		}
		if arrived.Add(1) == 2 {
			close(met)
		}
		select {
		case <-met:
		case <-time.After(5 * time.Second):
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	errs := make(chan error, 2)
	for _, id := range []uuid.UUID{accountA, accountB} {
		go func() { errs <- f.syncer.Sync(ctx, id) }()
	}
	deadline := time.After(10 * time.Second)
	for range 2 {
		select {
		case err := <-errs:
			require.NoError(t, err)
		case <-deadline:
			t.Fatal("deadline 10s 안에 두 동기화가 끝나지 않음")
		}
	}

	select {
	case <-met:
	default:
		t.Fatal("두 첫 조회가 만나지 않아 겹친 lock 상황을 만들지 못함")
	}
	// 앞선 동기화 2번 + 계정마다 (자기 lock 판 1번, 두 lock 판 1번). deadlock으로 트랜잭션을 다시 실행했다면 조회가 더 많습니다.
	assert.EqualValues(t, 6, f.source.calls.Load())
	grants := allGrants(t, f.pool)
	assertPeriod(t, grants, "pa", oct1, nov1, &refundedAt)
	assertPeriod(t, grants, "pb", oct10, time.Date(2026, 11, 10, 0, 0, 0, 0, time.UTC), &refundedAt)
	assert.Equal(t, accountA, findGrant(t, grants, billing.AdFree, "pa").AccountID)
	assert.Equal(t, accountB, findGrant(t, grants, billing.AdFree, "pb").AccountID)
	assert.Equal(t, accountA, ledgerOf(t, f.pool, "pa").Owner)
	assert.Equal(t, accountB, ledgerOf(t, f.pool, "pb").Owner)
}

// productionOnly면 sandbox 구매는 장부에 적지 않습니다(spec §5.5, P7).
func TestSync_ProductionOnly_SandboxNotRecorded(t *testing.T) {
	pool := dbtest.New(t)
	source := newFakePurchases()
	syncer := billing.NewSyncer(pool, source, billing.SyncConfig{
		Catalog:        billing.AdFreeCatalog([]string{testAdFreeProduct}),
		ProductionOnly: true,
	}, clocktest.New(now))
	accountID := newAccount(t, pool)
	sandbox := owned("sandbox", oct1)
	sandbox.Production = false
	source.set(accountID, sandbox, owned("prod", oct10))

	require.NoError(t, syncer.Sync(context.Background(), accountID))

	assert.Equal(t, 1, ledgerCount(t, pool))
	assert.Equal(t, accountID, ledgerOf(t, pool, "prod").Owner)
	assertPeriod(t, allGrants(t, pool), "prod", oct10, time.Date(2026, 11, 10, 0, 0, 0, 0, time.UTC), nil)
}

// 목록 밖 상품은 장부에만 적고 구간을 만들지 않습니다(spec §5.1).
func TestSync_UnknownProduct_LedgerOnly(t *testing.T) {
	f := newSyncFixture(t)
	accountID := newAccount(t, f.pool)
	other := owned("other", oct1)
	other.ProductID = "test.something.else"
	f.source.set(accountID, other)

	require.NoError(t, f.syncer.Sync(context.Background(), accountID))

	assert.Equal(t, accountID, ledgerOf(t, f.pool, "other").Owner)
	assert.Empty(t, allGrants(t, f.pool))
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

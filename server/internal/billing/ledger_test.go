package billing

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// ledgerFixture는 장부 테스트의 DB와 쿼리입니다.
type ledgerFixture struct {
	pool *pgxpool.Pool
	q    *billingdb.Queries
}

func newLedgerFixture(t *testing.T) ledgerFixture {
	t.Helper()
	pool := dbtest.New(t)
	return ledgerFixture{pool: pool, q: billingdb.New(pool)}
}

func (f ledgerFixture) newAccount(t *testing.T) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, f.pool.QueryRow(context.Background(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
	return id
}

// record는 구매를 장부에 적고 오류가 없음을 확인합니다.
func (f ledgerFixture) record(t *testing.T, accountID uuid.UUID, p Purchase, now time.Time) (uuid.UUID, bool) {
	t.Helper()
	owner, created, err := recordPurchaseTx(context.Background(), f.q, accountID, p, testProducts, now)
	require.NoError(t, err)
	return owner, created
}

func (f ledgerFixture) refund(t *testing.T, purchaseID string, at time.Time) bool {
	t.Helper()
	changed, err := markRefundedTx(context.Background(), f.q, purchaseID, at)
	require.NoError(t, err)
	return changed
}

func (f ledgerFixture) rechain(t *testing.T, accountID uuid.UUID, now time.Time) {
	t.Helper()
	require.NoError(t, rechainFromTx(context.Background(), f.q, accountID, now))
}

// segment는 entitlement_grants의 광고 제거권 행 하나입니다.
type segment struct {
	Entitlement string
	StartsAt    time.Time
	ExpiresAt   time.Time
	RevokedAt   *time.Time
}

// segments는 계정의 구매 refID 구간 행을 권한 이름 순으로 읽습니다.
func (f ledgerFixture) segments(t *testing.T, accountID uuid.UUID, refID string) []segment {
	t.Helper()
	rows, err := f.pool.Query(context.Background(),
		`SELECT entitlement, starts_at, expires_at, revoked_at FROM entitlement_grants
		 WHERE account_id = $1 AND source = 'ad_free_pass' AND source_ref = $2 ORDER BY entitlement`, accountID, refID)
	require.NoError(t, err)
	defer rows.Close()
	var out []segment
	for rows.Next() {
		var s segment
		require.NoError(t, rows.Scan(&s.Entitlement, &s.StartsAt, &s.ExpiresAt, &s.RevokedAt))
		out = append(out, s)
	}
	require.NoError(t, rows.Err())
	return out
}

// assertSegment는 구매 refID가 ad_free·insight 두 구간을 같은 기간·취소 상태로 가졌는지 봅니다.
func (f ledgerFixture) assertSegment(t *testing.T, accountID uuid.UUID, refID string, starts, expires time.Time, revokedAt *time.Time) {
	t.Helper()
	got := f.segments(t, accountID, refID)
	require.Len(t, got, 2, "%s 구간은 ad_free·insight 두 행", refID)
	assert.Equal(t, string(AdFree), got[0].Entitlement)
	assert.Equal(t, string(Insight), got[1].Entitlement)
	for _, s := range got {
		assert.True(t, s.StartsAt.Equal(starts), "%s %s starts: got %v, want %v", refID, s.Entitlement, s.StartsAt.UTC(), starts)
		assert.True(t, s.ExpiresAt.Equal(expires), "%s %s expires: got %v, want %v", refID, s.Entitlement, s.ExpiresAt.UTC(), expires)
		if revokedAt == nil {
			assert.Nil(t, s.RevokedAt, "%s %s는 취소되지 않음", refID, s.Entitlement)
		} else if assert.NotNil(t, s.RevokedAt, "%s %s는 취소됨", refID, s.Entitlement) {
			assert.True(t, s.RevokedAt.Equal(*revokedAt), "%s %s revoked_at: got %v, want %v", refID, s.Entitlement, s.RevokedAt.UTC(), *revokedAt)
		}
	}
}

// insertPendingSegment는 합치기(Task 12)가 넣는 것처럼 구매 refID의 대기 구간 두 행을 직접 넣습니다.
func (f ledgerFixture) insertPendingSegment(t *testing.T, accountID uuid.UUID, refID string, starts, expires time.Time) {
	t.Helper()
	for _, entitlement := range []Entitlement{AdFree, Insight} {
		require.NoError(t, f.q.InsertPassGrant(context.Background(), billingdb.InsertPassGrantParams{
			AccountID: accountID, Entitlement: string(entitlement), SourceRef: refID, StartsAt: starts, ExpiresAt: expires,
		}))
	}
}

func ledgerPurchase(id string, at time.Time) Purchase {
	return Purchase{ID: id, ProductID: testIOSProduct, Store: "app_store", PurchasedAt: at, Production: true}
}

func TestRecordPurchase_FirstWriterOwns(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	now := utc(2026, 10, 5, 0)
	p := ledgerPurchase("pur_first", now)

	owner, created := f.record(t, a, p, now)
	assert.Equal(t, a, owner)
	assert.True(t, created)

	owner, created = f.record(t, b, p, now.Add(time.Hour))
	assert.Equal(t, a, owner, "처음 적은 계정이 주인")
	assert.False(t, created)
	assert.Empty(t, f.segments(t, b, p.ID), "주인이 아닌 계정에는 구간이 없음")
	f.assertSegment(t, a, p.ID, now, utc(2026, 11, 5, 0), nil)

	var accountID, originalID uuid.UUID
	var store string
	require.NoError(t, f.pool.QueryRow(context.Background(),
		"SELECT account_id, original_account_id, store FROM purchases WHERE id = $1", p.ID).Scan(&accountID, &originalID, &store))
	assert.Equal(t, a, accountID)
	assert.Equal(t, a, originalID)
	assert.Equal(t, "app_store", store)
}

func TestRecordPurchase_ChainsAfterExistingEnd(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)

	f.record(t, a, ledgerPurchase("pur_1", utc(2026, 10, 5, 0)), utc(2026, 10, 5, 0))
	f.record(t, a, ledgerPurchase("pur_2", utc(2026, 10, 20, 0)), utc(2026, 10, 20, 0))

	f.assertSegment(t, a, "pur_1", utc(2026, 10, 5, 0), utc(2026, 11, 5, 0), nil)
	f.assertSegment(t, a, "pur_2", utc(2026, 11, 5, 0), utc(2026, 12, 5, 0), nil)
}

func TestRecordPurchase_UsesProductMonths(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	catalog := Catalog{"test.pass.quarter": {Months: 3, Entitlements: []Entitlement{AdFree, Insight}}}
	p := Purchase{ID: "pur_quarter", ProductID: "test.pass.quarter", Store: "play_store", PurchasedAt: utc(2026, 11, 30, 0), Production: true}

	_, _, err := recordPurchaseTx(context.Background(), f.q, a, p, catalog, utc(2026, 11, 30, 0))
	require.NoError(t, err)

	f.assertSegment(t, a, p.ID, utc(2026, 11, 30, 0), utc(2027, 2, 28, 0), nil)
}

func TestRecordPurchase_UnknownProductHasNoGrant(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	p := Purchase{ID: "pur_unknown", ProductID: "test.unknown", Store: "app_store", PurchasedAt: utc(2026, 10, 5, 0), Production: true}

	owner, created := f.record(t, a, p, utc(2026, 10, 5, 0))

	assert.Equal(t, a, owner)
	assert.True(t, created, "목록에 없는 상품도 장부에 적음")
	assert.Empty(t, f.segments(t, a, p.ID))
}

func TestRecordPurchase_RefundedHasNoGrant(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 12, 0)
	p := ledgerPurchase("pur_refunded", utc(2026, 10, 5, 0))
	p.Refunded = true

	_, created := f.record(t, a, p, now)

	assert.True(t, created)
	assert.Empty(t, f.segments(t, a, p.ID))
	var refundedAt *time.Time
	require.NoError(t, f.pool.QueryRow(context.Background(), "SELECT refunded_at FROM purchases WHERE id = $1", p.ID).Scan(&refundedAt))
	require.NotNil(t, refundedAt)
	assert.True(t, refundedAt.Equal(now), "처음 본 시각을 환불 시각으로 적음")
}

func TestMarkRefunded_OnlyOnce(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	f.record(t, a, ledgerPurchase("pur_1", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))

	assert.True(t, f.refund(t, "pur_1", utc(2026, 10, 10, 0)))
	assert.False(t, f.refund(t, "pur_1", utc(2026, 10, 11, 0)), "이미 환불된 구매는 바꾸지 않음")
	assert.False(t, f.refund(t, "pur_missing", utc(2026, 10, 11, 0)), "장부에 없는 구매")

	var refundedAt time.Time
	require.NoError(t, f.pool.QueryRow(context.Background(), "SELECT refunded_at FROM purchases WHERE id = 'pur_1'").Scan(&refundedAt))
	assert.True(t, refundedAt.Equal(utc(2026, 10, 10, 0)))
}

func TestRechainFrom_RefundCutsAndPullsLater(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_1", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))
	f.record(t, a, ledgerPurchase("pur_2", utc(2026, 10, 3, 0)), utc(2026, 10, 3, 0))
	f.assertSegment(t, a, "pur_2", utc(2026, 11, 1, 0), utc(2026, 12, 1, 0), nil)

	require.True(t, f.refund(t, "pur_1", now))
	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_1", utc(2026, 10, 1, 0), utc(2026, 11, 1, 0), &now)
	// 대기 구간은 원래 길이(11/1~12/1 = 30일)를 유지해 now부터 붙습니다.
	f.assertSegment(t, a, "pur_2", now, now.Add(30*24*time.Hour), nil)
}

func TestRechainFrom_KeepsPastSegments(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_past", utc(2026, 9, 1, 0)), utc(2026, 9, 1, 0))
	f.record(t, a, ledgerPurchase("pur_now", utc(2026, 10, 5, 0)), utc(2026, 10, 5, 0))

	require.True(t, f.refund(t, "pur_past", now))
	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_past", utc(2026, 9, 1, 0), utc(2026, 10, 1, 0), nil)
	f.assertSegment(t, a, "pur_now", utc(2026, 10, 5, 0), utc(2026, 11, 5, 0), nil)
}

func TestRechainFrom_ActiveKeepsStart(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_active", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))
	// 합치기처럼, 사용 중 구간보다 먼저 산 다른 계정 구매의 남은 12일이 대기 구간으로 들어옵니다.
	f.record(t, b, ledgerPurchase("pur_merged", utc(2026, 9, 20, 0)), utc(2026, 9, 20, 0))
	f.insertPendingSegment(t, a, "pur_merged", utc(2026, 12, 1, 0), utc(2026, 12, 13, 0))

	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_active", utc(2026, 10, 1, 0), utc(2026, 11, 1, 0), nil)
	f.assertSegment(t, a, "pur_merged", utc(2026, 11, 1, 0), utc(2026, 11, 13, 0), nil)
	f.assertSegment(t, b, "pur_merged", utc(2026, 9, 20, 0), utc(2026, 10, 20, 0), nil)
}

func TestRechainFrom_NoChangeIsStable(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_1", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))
	f.record(t, a, ledgerPurchase("pur_2", utc(2026, 10, 3, 0)), utc(2026, 10, 3, 0))

	f.rechain(t, a, now)
	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_1", utc(2026, 10, 1, 0), utc(2026, 11, 1, 0), nil)
	f.assertSegment(t, a, "pur_2", utc(2026, 11, 1, 0), utc(2026, 12, 1, 0), nil)
}

func TestRechainFrom_StartingNowIsActive(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_now", now), now)
	// 사용 중 구간보다 먼저 산 구매의 대기 구간입니다. pur_now를 대기로 보면 구매 순서대로 pur_merged가 앞에 붙습니다.
	f.record(t, b, ledgerPurchase("pur_merged", utc(2026, 9, 20, 0)), utc(2026, 9, 20, 0))
	f.insertPendingSegment(t, a, "pur_merged", utc(2026, 12, 1, 0), utc(2026, 12, 13, 0))

	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_now", now, utc(2026, 11, 10, 0), nil)
	f.assertSegment(t, a, "pur_merged", utc(2026, 11, 10, 0), utc(2026, 11, 22, 0), nil)
}

func TestRechainFrom_EndingNowIsPast(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_ended", utc(2026, 9, 10, 0)), utc(2026, 9, 10, 0))

	require.True(t, f.refund(t, "pur_ended", now))
	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_ended", utc(2026, 9, 10, 0), now, nil)
}

func TestRechainFrom_SamePurchaseTimeOrdersByID(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	boughtAt := utc(2026, 10, 5, 0)
	f.record(t, a, ledgerPurchase("pur_0", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))
	// 장부에 적은 순서는 b, a라 처음 구간도 b가 앞입니다.
	f.record(t, a, ledgerPurchase("pur_b", boughtAt), boughtAt)
	f.record(t, a, ledgerPurchase("pur_a", boughtAt), boughtAt)
	f.assertSegment(t, a, "pur_b", utc(2026, 11, 1, 0), utc(2026, 12, 1, 0), nil)
	f.assertSegment(t, a, "pur_a", utc(2026, 12, 1, 0), utc(2027, 1, 1, 0), nil)

	require.True(t, f.refund(t, "pur_0", now))
	f.rechain(t, a, now)

	// 다시 이을 때는 구매 id 순(a 31일, b 30일)입니다.
	aEnd := now.Add(31 * 24 * time.Hour)
	f.assertSegment(t, a, "pur_a", now, aEnd, nil)
	f.assertSegment(t, a, "pur_b", aEnd, aEnd.Add(30*24*time.Hour), nil)
}

func TestRechainFrom_RefundedActivePullsAllPending(t *testing.T) {
	f := newLedgerFixture(t)
	a := f.newAccount(t)
	now := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_1", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))
	f.record(t, a, ledgerPurchase("pur_2", utc(2026, 10, 2, 0)), utc(2026, 10, 2, 0))
	f.record(t, a, ledgerPurchase("pur_3", utc(2026, 10, 3, 0)), utc(2026, 10, 3, 0))
	f.assertSegment(t, a, "pur_3", utc(2026, 12, 1, 0), utc(2027, 1, 1, 0), nil)

	require.True(t, f.refund(t, "pur_1", now))
	f.rechain(t, a, now)

	f.assertSegment(t, a, "pur_1", utc(2026, 10, 1, 0), utc(2026, 11, 1, 0), &now)
	secondEnd := now.Add(30 * 24 * time.Hour) // 11/1~12/1
	f.assertSegment(t, a, "pur_2", now, secondEnd, nil)
	f.assertSegment(t, a, "pur_3", secondEnd, secondEnd.Add(31*24*time.Hour), nil) // 12/1~1/1
}

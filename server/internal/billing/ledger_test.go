package billing

import (
	"context"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// testLog는 장부 함수에 넘기는 버리는 logger입니다.
var testLog = slog.New(slog.DiscardHandler)

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
	owner, created, err := recordPurchaseTx(context.Background(), f.q, testLog, accountID, p, testProducts, now)
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

	_, _, err := recordPurchaseTx(context.Background(), f.q, testLog, a, p, catalog, utc(2026, 11, 30, 0))
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

// 스토어 거래 id가 비어 있으면 같은 거래로 보지 않고 각각 적습니다. 다른 스토어의 같은 값도 다른 거래입니다.
func TestRecordPurchase_StoreTransactionMatchNeedsSameStoreAndValue(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	at := utc(2026, 10, 5, 0)

	_, created := f.record(t, a, ledgerPurchase("pur_empty_1", at), at)
	assert.True(t, created)
	_, created = f.record(t, b, ledgerPurchase("pur_empty_2", at), at)
	assert.True(t, created, "빈 스토어 거래 id는 맞춰 보지 않음")

	apple := ledgerPurchase("pur_apple", at)
	apple.StorePurchaseID = "tx-1"
	_, created = f.record(t, a, apple, at)
	assert.True(t, created)
	play := ledgerPurchase("pur_play", at)
	play.Store, play.StorePurchaseID = "play_store", "tx-1"
	owner, created := f.record(t, b, play, at)
	assert.True(t, created, "다른 스토어의 같은 값은 다른 거래")
	assert.Equal(t, b, owner)

	alias := ledgerPurchase("pur_apple_alias", at)
	alias.StorePurchaseID = "tx-1"
	owner, created = f.record(t, b, alias, at)
	assert.False(t, created)
	assert.Equal(t, a, owner, "같은 스토어 거래면 기존 행의 주인")
	assert.Empty(t, f.segments(t, b, "pur_apple_alias"))
}

// move는 한 트랜잭션에서 from의 구매를 to로 옮기고 commit합니다(합치기, spec §5.3·§6.3).
func (f ledgerFixture) move(t *testing.T, from, to uuid.UUID, now time.Time) {
	t.Helper()
	ctx := context.Background()
	tx, err := f.pool.Begin(ctx)
	require.NoError(t, err)
	defer func() { _ = tx.Rollback(ctx) }()
	require.NoError(t, MovePurchasesTx(ctx, tx, from, to, now))
	require.NoError(t, tx.Commit(ctx))
}

// ledgerOwner는 구매의 지금 주인, 처음 산 계정, 합친 시각입니다.
func (f ledgerFixture) ledgerOwner(t *testing.T, purchaseID string) (owner, original uuid.UUID, mergedAt *time.Time) {
	t.Helper()
	require.NoError(t, f.pool.QueryRow(context.Background(),
		"SELECT account_id, original_account_id, merged_at FROM purchases WHERE id = $1", purchaseID).Scan(&owner, &original, &mergedAt))
	return owner, original, mergedAt
}

// D88 ① 예: 10/20에 합치면 A가 11/5에 끝나고 B가 12일 남았으므로 A 끝은 11/17입니다.
// B 쪽 행은 남고 지금(10/20)에서 끊깁니다. 대기 구간은 구매 시각 순으로 A 끝에 붙습니다.
func TestMovePurchasesTx_AppendsRemainingToTarget(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	now := utc(2026, 10, 20, 0)

	f.record(t, a, ledgerPurchase("pur_a", utc(2026, 10, 5, 0)), utc(2026, 10, 5, 0))         // 10/5–11/5 사용 중
	f.record(t, a, ledgerPurchase("pur_a_later", utc(2026, 10, 15, 0)), utc(2026, 10, 15, 0)) // 11/5–12/5 대기
	f.record(t, b, ledgerPurchase("pur_b_old", utc(2026, 8, 1, 0)), utc(2026, 8, 1, 0))       // 8/1–9/1 끝남
	f.record(t, b, ledgerPurchase("pur_b", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))         // 10/1–11/1 사용 중, 12일 남음
	f.record(t, b, ledgerPurchase("pur_b_next", utc(2026, 10, 10, 0)), utc(2026, 10, 10, 0))  // 11/1–12/1 대기, 30일
	unknown := Purchase{ID: "pur_b_unknown", ProductID: "test.unknown", Store: "app_store", PurchasedAt: utc(2026, 9, 1, 0), Production: true}
	f.record(t, b, unknown, utc(2026, 9, 1, 0))

	f.move(t, b, a, now)

	// B 쪽: 사용 중 구간은 지금에서 끝나고, 대기 구간은 시작 전이라 끊김(revoked)으로 남습니다. 끝난 구간은 그대로입니다.
	f.assertSegment(t, b, "pur_b", utc(2026, 10, 1, 0), now, nil)
	f.assertSegment(t, b, "pur_b_next", utc(2026, 11, 1, 0), utc(2026, 12, 1, 0), &now)
	f.assertSegment(t, b, "pur_b_old", utc(2026, 8, 1, 0), utc(2026, 9, 1, 0), nil)

	// A 쪽: 사용 중 구간 끝(11/5)부터 구매 시각 순(pur_b 10/1, pur_b_next 10/10, pur_a_later 10/15)으로 붙습니다.
	f.assertSegment(t, a, "pur_a", utc(2026, 10, 5, 0), utc(2026, 11, 5, 0), nil)
	f.assertSegment(t, a, "pur_b", utc(2026, 11, 5, 0), utc(2026, 11, 17, 0), nil)
	f.assertSegment(t, a, "pur_b_next", utc(2026, 11, 17, 0), utc(2026, 12, 17, 0), nil)
	f.assertSegment(t, a, "pur_a_later", utc(2026, 12, 17, 0), utc(2027, 1, 16, 0), nil)
	assert.Empty(t, f.segments(t, a, "pur_b_old"), "끝난 구간은 옮기지 않습니다")
	assert.Empty(t, f.segments(t, a, "pur_b_unknown"))

	// 구간이 없는 구매(끝난 것·목록 밖 상품)도 장부 주인은 A입니다.
	for _, id := range []string{"pur_b", "pur_b_next", "pur_b_old", "pur_b_unknown"} {
		owner, original, mergedAt := f.ledgerOwner(t, id)
		assert.Equal(t, a, owner, id)
		assert.Equal(t, b, original, "%s 처음 산 계정은 그대로", id)
		if assert.NotNil(t, mergedAt, id) {
			assert.True(t, mergedAt.Equal(now), id)
		}
	}
	owner, original, mergedAt := f.ledgerOwner(t, "pur_a")
	assert.Equal(t, a, owner)
	assert.Equal(t, a, original)
	assert.Nil(t, mergedAt, "A가 원래 가진 구매는 합친 시각이 없습니다")
}

// 지금 막 시작한 B 구간은 지금에서 끊으면 길이가 0이라(CHECK expires_at > starts_at) 끊김으로 남기고, 전체 길이를 A에 붙입니다.
// A에 구간이 없으면 지금부터 씁니다.
func TestMovePurchasesTx_SegmentStartingNowIsRevokedOnSource(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	now := utc(2026, 10, 20, 0)
	f.record(t, b, ledgerPurchase("pur_b", now), now) // 10/20–11/20

	f.move(t, b, a, now)

	f.assertSegment(t, b, "pur_b", now, utc(2026, 11, 20, 0), &now)
	f.assertSegment(t, a, "pur_b", now, utc(2026, 11, 20, 0), nil)
}

// 환불된 구매의 끊긴 구간과 보상형 광고 구간은 옮기지 않습니다. 환불된 구매도 장부 주인은 A로 옮깁니다.
func TestMovePurchasesTx_SkipsRevokedAndRewardedGrants(t *testing.T) {
	f := newLedgerFixture(t)
	a, b := f.newAccount(t), f.newAccount(t)
	now := utc(2026, 10, 20, 0)
	f.record(t, b, ledgerPurchase("pur_refunded", utc(2026, 10, 10, 0)), utc(2026, 10, 10, 0))
	f.refund(t, "pur_refunded", utc(2026, 10, 15, 0))
	f.rechain(t, b, utc(2026, 10, 15, 0))
	_, err := f.pool.Exec(context.Background(), `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'insight', 'rewarded_ad', 'reward-1', $2, $3)`, b, now.Add(-time.Hour), now.Add(time.Hour))
	require.NoError(t, err)

	f.move(t, b, a, now)

	assert.Empty(t, f.segments(t, a, "pur_refunded"))
	owner, _, _ := f.ledgerOwner(t, "pur_refunded")
	assert.Equal(t, a, owner)
	var rewarded int
	require.NoError(t, f.pool.QueryRow(context.Background(),
		"SELECT count(*) FROM entitlement_grants WHERE account_id = $1 AND source = 'rewarded_ad'", a).Scan(&rewarded))
	assert.Zero(t, rewarded)
}

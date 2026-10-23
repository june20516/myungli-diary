package billing

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

// 구매 목록 테스트의 "지금"입니다.
var purchasesNow = utc(2026, 10, 20, 12)

func purchaseOf(id, productID string, at time.Time) Purchase {
	p := ledgerPurchase(id, at)
	p.ProductID = productID
	return p
}

func TestPurchases_StatusesAndPeriods(t *testing.T) {
	f := newLedgerFixture(t)
	store := NewStore(f.pool, clocktest.New(purchasesNow))
	a := f.newAccount(t)

	expiredAt, activeAt, pendingAt := utc(2026, 9, 1, 0), utc(2026, 10, 10, 0), utc(2026, 10, 12, 0)
	f.record(t, a, ledgerPurchase("pur_expired", expiredAt), expiredAt)
	f.record(t, a, ledgerPurchase("pur_active", activeAt), activeAt)
	f.record(t, a, ledgerPurchase("pur_pending", pendingAt), pendingAt)
	f.record(t, a, purchaseOf("pur_owned", "test.other.product", utc(2026, 10, 1, 0)), utc(2026, 10, 1, 0))
	// 시작 전에 환불한 구매: 구간이 있었지만 쓰지 않았으므로 period가 없습니다.
	beforeStart := utc(2026, 10, 13, 0)
	f.record(t, a, ledgerPurchase("pur_refund_before", beforeStart), beforeStart)
	f.refund(t, "pur_refund_before", utc(2026, 10, 14, 0))
	f.rechain(t, a, utc(2026, 10, 14, 0))

	got, err := store.Purchases(context.Background(), a)
	require.NoError(t, err)

	byID := map[string]PurchaseItem{}
	var order []string
	for _, item := range got {
		byID[item.ProductID+"|"+item.PurchasedAt.UTC().Format(time.RFC3339)] = item
		order = append(order, item.PurchasedAt.UTC().Format(time.RFC3339))
	}
	assert.Len(t, got, 5)
	// 최근 구매 먼저입니다.
	for i := 1; i < len(got); i++ {
		assert.False(t, got[i-1].PurchasedAt.Before(got[i].PurchasedAt), "순서: %v", order)
	}

	find := func(at time.Time) PurchaseItem {
		t.Helper()
		item, ok := byID[testIOSProduct+"|"+at.Format(time.RFC3339)]
		require.True(t, ok, "구매 %v", at)
		return item
	}
	expired := find(expiredAt)
	assert.Equal(t, "expired", expired.Status)
	require.NotNil(t, expired.Period)
	assert.True(t, expired.Period.StartsAt.Equal(expiredAt))
	assert.True(t, expired.Period.EndsAt.Equal(utc(2026, 10, 1, 0)))

	active := find(activeAt)
	assert.Equal(t, "active", active.Status)
	require.NotNil(t, active.Period)
	assert.True(t, active.Period.StartsAt.Equal(activeAt))
	assert.True(t, active.Period.EndsAt.Equal(utc(2026, 11, 10, 0)))

	pending := find(pendingAt)
	assert.Equal(t, "pending", pending.Status)
	require.NotNil(t, pending.Period)
	assert.True(t, pending.Period.StartsAt.Equal(utc(2026, 11, 10, 0)))

	refundedBefore := find(beforeStart)
	assert.Equal(t, "refunded", refundedBefore.Status)
	assert.Nil(t, refundedBefore.Period, "시작 전에 환불되면 period가 없습니다")

	owned := byID["test.other.product|"+utc(2026, 10, 1, 0).Format(time.RFC3339)]
	assert.Equal(t, "owned", owned.Status)
	assert.Nil(t, owned.Period)
}

func TestPurchases_RefundedAfterStartKeepsUsedPeriod(t *testing.T) {
	f := newLedgerFixture(t)
	store := NewStore(f.pool, clocktest.New(purchasesNow))
	a := f.newAccount(t)
	boughtAt, refundedAt := utc(2026, 10, 10, 0), utc(2026, 10, 15, 0)
	f.record(t, a, ledgerPurchase("pur_used", boughtAt), boughtAt)
	f.refund(t, "pur_used", refundedAt)
	f.rechain(t, a, refundedAt)

	got, err := store.Purchases(context.Background(), a)
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.Equal(t, "refunded", got[0].Status)
	require.NotNil(t, got[0].Period)
	assert.True(t, got[0].Period.StartsAt.Equal(boughtAt))
	assert.True(t, got[0].Period.EndsAt.Equal(refundedAt), "쓴 구간은 끊은 시각까지입니다: %v", got[0].Period.EndsAt)
}

func TestPurchases_OnlyThisAccountSegment(t *testing.T) {
	f := newLedgerFixture(t)
	store := NewStore(f.pool, clocktest.New(purchasesNow))
	a, b := f.newAccount(t), f.newAccount(t)
	boughtAt := utc(2026, 10, 10, 0)
	f.record(t, a, ledgerPurchase("pur_merged", boughtAt), boughtAt)
	// 합친 뒤 모습: 구매 주인은 A, B 구간은 B 껍데기 계정에 남고 A 구간은 대기 구간입니다.
	_, err := f.pool.Exec(context.Background(), `UPDATE entitlement_grants SET account_id = $1 WHERE account_id = $2`, b, a)
	require.NoError(t, err)
	f.insertPendingSegment(t, a, "pur_merged", utc(2026, 11, 1, 0), utc(2026, 11, 20, 0))

	got, err := store.Purchases(context.Background(), a)
	require.NoError(t, err)
	require.Len(t, got, 1, "구간 행이 둘이어도 구매는 한 줄입니다")
	assert.Equal(t, "pending", got[0].Status)
	require.NotNil(t, got[0].Period)
	assert.True(t, got[0].Period.StartsAt.Equal(utc(2026, 11, 1, 0)))
	assert.True(t, got[0].Period.EndsAt.Equal(utc(2026, 11, 20, 0)))

	// B는 구매의 주인이 아니므로 목록이 비어 있습니다.
	other, err := store.Purchases(context.Background(), b)
	require.NoError(t, err)
	assert.Empty(t, other)
}

func TestPurchases_NoPurchasesIsEmptyNotNil(t *testing.T) {
	f := newLedgerFixture(t)
	store := NewStore(f.pool, clocktest.New(purchasesNow))

	got, err := store.Purchases(context.Background(), f.newAccount(t))
	require.NoError(t, err)
	assert.NotNil(t, got)
	assert.Empty(t, got)
}

// insight만 주는 기간 상품도 이 계정 구간으로 period가 나옵니다(spec §5.6).
func TestPurchases_InsightOnlyProductHasPeriod(t *testing.T) {
	f := newLedgerFixture(t)
	store := NewStore(f.pool, clocktest.New(purchasesNow))
	a := f.newAccount(t)
	catalog := Catalog{"test.insight.month": {Months: 1, Entitlements: []Entitlement{Insight}}}
	boughtAt := utc(2026, 10, 10, 0)
	_, _, err := recordPurchaseTx(context.Background(), f.q, testLog, a, purchaseOf("pur_insight", "test.insight.month", boughtAt), catalog, boughtAt)
	require.NoError(t, err)

	got, err := store.Purchases(context.Background(), a)
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.Equal(t, PurchaseActive, got[0].Status)
	require.NotNil(t, got[0].Period)
	assert.True(t, got[0].Period.StartsAt.Equal(boughtAt))
	assert.True(t, got[0].Period.EndsAt.Equal(utc(2026, 11, 10, 0)))
}

func TestPurchaseItemOf(t *testing.T) {
	starts, expires := utc(2026, 10, 10, 0), utc(2026, 11, 10, 0)
	middle := utc(2026, 10, 20, 0)
	at := func(t time.Time) *time.Time { return &t }
	segment := func(revokedAt, refundedAt *time.Time) billingdb.ListAccountPurchasesRow {
		return billingdb.ListAccountPurchasesRow{
			ProductID: testIOSProduct, PurchasedAt: starts, RefundedAt: refundedAt,
			SegmentStartsAt: at(starts), SegmentExpiresAt: at(expires), SegmentRevokedAt: revokedAt,
		}
	}
	tests := []struct {
		name       string
		row        billingdb.ListAccountPurchasesRow
		now        time.Time
		wantStatus string
		wantPeriod *Period
	}{
		{"시작 시각이면 active", segment(nil, nil), starts, PurchaseActive, &Period{starts, expires}},
		{"시작 전이면 pending", segment(nil, nil), starts.Add(-time.Second), PurchasePending, &Period{starts, expires}},
		{"끝 시각이면 expired", segment(nil, nil), expires, PurchaseExpired, &Period{starts, expires}},
		{"합치기로 시작 전에 끊긴 구간은 expired, period 없음", segment(at(starts.Add(-time.Hour)), nil), starts.Add(-2 * time.Hour), PurchaseExpired, nil},
		{"끊은 시각이 시작 시각이면 period 없음", segment(at(starts), nil), middle, PurchaseExpired, nil},
		{"쓰던 중 끊긴 구간은 끊은 시각까지", segment(at(middle), nil), middle.Add(time.Hour), PurchaseExpired, &Period{starts, middle}},
		{"환불 전 사용 중", segment(nil, nil), middle, PurchaseActive, &Period{starts, expires}},
		{"환불 뒤는 refunded, 쓴 구간까지", segment(at(middle), at(middle)), middle.Add(time.Hour), PurchaseRefunded, &Period{starts, middle}},
		{"구간 없는 구매는 owned", billingdb.ListAccountPurchasesRow{ProductID: "test.other", PurchasedAt: starts}, middle, PurchaseOwned, nil},
		{"구간 없는 환불 구매는 refunded", billingdb.ListAccountPurchasesRow{ProductID: "test.other", PurchasedAt: starts, RefundedAt: at(middle)}, middle, PurchaseRefunded, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := purchaseItemOf(tt.row, tt.now)
			assert.Equal(t, tt.wantStatus, got.Status)
			if tt.wantPeriod == nil {
				assert.Nil(t, got.Period)
				return
			}
			require.NotNil(t, got.Period)
			assert.True(t, got.Period.StartsAt.Equal(tt.wantPeriod.StartsAt), "starts %v", got.Period.StartsAt)
			assert.True(t, got.Period.EndsAt.Equal(tt.wantPeriod.EndsAt), "ends %v", got.Period.EndsAt)
		})
	}
}

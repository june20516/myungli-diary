package billing

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
)

// 구매 상태입니다. 계약의 열린 enum PurchaseStatus 값입니다.
const (
	PurchaseActive   = "active"
	PurchasePending  = "pending"
	PurchaseExpired  = "expired"
	PurchaseRefunded = "refunded"
	PurchaseOwned    = "owned"
)

// Period는 이 유저 계정의 사용 구간입니다.
type Period struct {
	StartsAt, EndsAt time.Time
}

// PurchaseItem은 구매 목록의 한 줄입니다(spec §5.5).
type PurchaseItem struct {
	ProductID   string
	PurchasedAt time.Time
	Status      string
	// Period는 기간 상품만 있습니다. 환불된 구매는 실제로 쓴 구간이고, 시작 전에 환불됐으면 nil입니다.
	Period *Period
}

// Purchases는 계정이 주인인 구매를 최근 구매 먼저 돌려줍니다(S109).
// 구간은 이 계정의 행 하나(권한 이름 순 첫 행)만 봅니다. 한 구매의 권한 행은 같은 구간이고, 합친 구매의 다른 계정 구간은 읽지 않습니다.
func (s *Store) Purchases(ctx context.Context, accountID uuid.UUID) ([]PurchaseItem, error) {
	rows, err := billingdb.New(s.pool).ListAccountPurchases(ctx, accountID)
	if err != nil {
		return nil, fmt.Errorf("구매 목록 조회: %w", err)
	}
	now := s.clk.Now()
	items := make([]PurchaseItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, purchaseItemOf(row, s.catalog, now))
	}
	return items, nil
}

// purchaseItemOf는 장부 행과 지금 시각으로 상태와 구간을 정합니다.
// 취소된 구간은 취소 시각에서 끊기므로(환불·합치기), 구간 끝은 원래 끝과 취소 시각 중 이른 것입니다.
// 끝이 시작보다 늦지 않으면(시작 전 환불·취소) 쓴 구간이 없어 period를 주지 않습니다.
//
// 이 계정의 구간이 없는 구매는 상품 목록으로 나눕니다. 기간 상품(목록에 있고 Months > 0)이면 이 계정에서 쓸 기간이
// 남지 않은 것이라(합치기 전에 끝난 B 구매 등) expired이고, 목록 밖 상품이면 owned입니다. 환불이면 둘 다 refunded입니다.
func purchaseItemOf(row billingdb.ListAccountPurchasesRow, catalog Catalog, now time.Time) PurchaseItem {
	item := PurchaseItem{ProductID: row.ProductID, PurchasedAt: row.PurchasedAt}
	if row.SegmentStartsAt == nil || row.SegmentExpiresAt == nil {
		switch {
		case row.RefundedAt != nil:
			item.Status = PurchaseRefunded
		case catalog[row.ProductID].Months > 0:
			item.Status = PurchaseExpired
		default:
			item.Status = PurchaseOwned
		}
		return item
	}

	starts, ends := *row.SegmentStartsAt, *row.SegmentExpiresAt
	revoked := row.SegmentRevokedAt != nil
	if revoked && row.SegmentRevokedAt.Before(ends) {
		ends = *row.SegmentRevokedAt
	}
	if ends.After(starts) {
		item.Period = &Period{StartsAt: starts, EndsAt: ends}
	}

	switch {
	case row.RefundedAt != nil:
		item.Status = PurchaseRefunded
	case now.Before(starts) && !revoked:
		item.Status = PurchasePending
	case revoked || !now.Before(*row.SegmentExpiresAt):
		item.Status = PurchaseExpired
	default:
		item.Status = PurchaseActive
	}
	return item
}

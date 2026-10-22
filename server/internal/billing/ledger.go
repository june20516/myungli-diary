package billing

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
)

// 구매 장부(purchases)와 광고 제거권 사용 구간(entitlement_grants, 출처 ad_free_pass)을 다루는 함수입니다(spec §5.2·§5.3).
// 모두 호출한 쪽의 트랜잭션 안에서 계정 advisory lock(S82)을 잡은 뒤 부른다고 봅니다.
// recordPurchaseTx의 경합 처리는 READ COMMITTED에 기댑니다. 두 계정이 같은 구매를 동시에 적으면 늦은 INSERT는
// 앞 트랜잭션의 commit을 기다려 0행이 되고, 이어지는 PurchaseOwner 조회가 그 commit된 주인을 봅니다.

// recordPurchaseTx는 구매를 장부에 적습니다(S107).
//
//   - 장부에 없으면 accountID를 주인·처음 산 계정으로 적고 created = true입니다. catalog에 있는 상품이고 환불되지 않았으면
//     상품의 권한마다 사용 구간을 놓습니다(starts_at = max(구매 시각, 이 계정의 같은 권한 구간 끝), expires_at = starts_at + Months개월).
//   - 이미 있으면 아무것도 바꾸지 않고 지금 주인을 돌려줍니다(created = false). 환불 반영은 markRefundedTx 몫입니다.
//
// 처음 적을 때 이미 환불된 구매는 환불 시각을 알 수 없어 now로 적습니다. production 필터는 호출한 쪽이 적용합니다.
func recordPurchaseTx(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, p Purchase, catalog Catalog, now time.Time) (owner uuid.UUID, created bool, err error) {
	var refundedAt *time.Time
	if p.Refunded {
		refundedAt = &now
	}
	inserted, err := q.InsertPurchase(ctx, billingdb.InsertPurchaseParams{
		ID:          p.ID,
		AccountID:   accountID,
		ProductID:   p.ProductID,
		Store:           p.Store,
		StorePurchaseID: p.StorePurchaseID,
		PurchasedAt:     p.PurchasedAt,
		RefundedAt:      refundedAt,
		Production:      p.Production,
	})
	if err != nil {
		return uuid.Nil, false, fmt.Errorf("구매 장부 기록(%s): %w", p.ID, err)
	}
	if inserted == 0 {
		owner, err := q.PurchaseOwner(ctx, p.ID)
		if err != nil {
			return uuid.Nil, false, fmt.Errorf("구매 주인 조회(%s): %w", p.ID, err)
		}
		return owner, false, nil
	}

	product, ok := catalog[p.ProductID]
	if !ok || p.Refunded {
		return accountID, true, nil
	}
	for _, entitlement := range product.Entitlements {
		if err := placeSegment(ctx, q, accountID, entitlement, p, product.Months); err != nil {
			return uuid.Nil, false, err
		}
	}
	return accountID, true, nil
}

// placeSegment는 구매 p의 entitlement 구간을 이 계정의 같은 권한 구간 끝에 이어 놓습니다(S108, D61).
func placeSegment(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, entitlement Entitlement, p Purchase, months int) error {
	startsAt, err := q.NextPassStart(ctx, billingdb.NextPassStartParams{
		PurchasedAt: p.PurchasedAt,
		AccountID:   accountID,
		Entitlement: string(entitlement),
	})
	if err != nil {
		return fmt.Errorf("구간 시작 계산(%s %s): %w", entitlement, p.ID, err)
	}
	err = q.InsertPassGrant(ctx, billingdb.InsertPassGrantParams{
		AccountID:   accountID,
		Entitlement: string(entitlement),
		SourceRef:   p.ID,
		StartsAt:    startsAt,
		ExpiresAt:   addMonths(startsAt, months),
	})
	if err != nil {
		return fmt.Errorf("구간 저장(%s %s): %w", entitlement, p.ID, err)
	}
	return nil
}

// markRefundedTx는 장부의 구매를 환불로 적습니다. 처음 적었을 때만 changed = true이고,
// 이미 환불됐거나 장부에 없는 구매면 false입니다. 구간 정리는 주인 계정의 rechainFromTx 몫입니다.
func markRefundedTx(ctx context.Context, q *billingdb.Queries, purchaseID string, refundedAt time.Time) (changed bool, err error) {
	rows, err := q.MarkPurchaseRefunded(ctx, billingdb.MarkPurchaseRefundedParams{RefundedAt: refundedAt, ID: purchaseID})
	if err != nil {
		return false, fmt.Errorf("구매 환불 기록(%s): %w", purchaseID, err)
	}
	return rows > 0, nil
}

// rechainFromTx는 계정의 광고 제거권 구간을 now부터 다시 잇습니다(S108). 권한마다 따로 봅니다.
//
//  1. 이미 끝난 구간(expires_at <= now)은 환불이어도 바꾸지 않습니다.
//  2. 환불된 구매의 남은 구간은 revoked_at = now로 끊고 이어 붙이기에서 뺍니다.
//  3. 사용 중 구간(starts_at <= now < expires_at)은 시작·끝을 그대로 둡니다.
//  4. 대기 구간(starts_at > now)은 원래 길이를 유지한 채 구매 시각·구매 id 순으로 max(now, 앞 구간 끝)부터 다시 붙입니다.
//
// 사용 중 구간은 옮기지 않으므로 구매 순서와 상관없이 대기 구간보다 앞에 둡니다. 합치기(Task 12)가 사용 중 구간보다
// 먼저 산 구매의 대기 구간을 넣어도 사용 중 구간과 겹치지 않습니다.
func rechainFromTx(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, now time.Time) error {
	segments, err := q.ListPassSegments(ctx, accountID)
	if err != nil {
		return fmt.Errorf("구간 조회: %w", err)
	}

	byEntitlement := make(map[string][]billingdb.ListPassSegmentsRow)
	var entitlementOrder []string
	for _, segment := range segments {
		if _, seen := byEntitlement[segment.Entitlement]; !seen {
			entitlementOrder = append(entitlementOrder, segment.Entitlement)
		}
		byEntitlement[segment.Entitlement] = append(byEntitlement[segment.Entitlement], segment)
	}
	for _, entitlement := range entitlementOrder {
		if err := rechainEntitlement(ctx, q, accountID, byEntitlement[entitlement], now); err != nil {
			return err
		}
	}
	return nil
}

// rechainEntitlement는 권한 하나의 구간(구매 순)에 rechainFromTx 규칙을 적용합니다.
func rechainEntitlement(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, segments []billingdb.ListPassSegmentsRow, now time.Time) error {
	chainEnd := now
	var pending []billingdb.ListPassSegmentsRow
	for _, segment := range segments {
		switch {
		case !segment.ExpiresAt.After(now):
			continue
		case segment.Refunded:
			err := q.RevokeGrant(ctx, billingdb.RevokeGrantParams{Now: now, ID: segment.ID, AccountID: accountID})
			if err != nil {
				return fmt.Errorf("환불 구간 취소(%d): %w", segment.ID, err)
			}
		case !segment.StartsAt.After(now):
			chainEnd = latest(chainEnd, segment.ExpiresAt)
		default:
			pending = append(pending, segment)
		}
	}

	for _, segment := range pending {
		startsAt := chainEnd
		expiresAt := startsAt.Add(segment.ExpiresAt.Sub(segment.StartsAt))
		chainEnd = expiresAt
		if startsAt.Equal(segment.StartsAt) {
			continue
		}
		err := q.SetGrantPeriod(ctx, billingdb.SetGrantPeriodParams{
			StartsAt:  startsAt,
			ExpiresAt: expiresAt,
			ID:        segment.ID,
			AccountID: accountID,
		})
		if err != nil {
			return fmt.Errorf("대기 구간 옮기기(%d): %w", segment.ID, err)
		}
	}
	return nil
}

func latest(a, b time.Time) time.Time {
	if b.After(a) {
		return b
	}
	return a
}

// addMonths는 UTC 달력으로 months개월 뒤 같은 날 같은 시각을 돌려줍니다(P7-3, D61).
// 그 달에 그 날이 없으면 그 달 마지막 날입니다(1월 31일 + 1개월 → 2월 28일·29일).
// time.AddDate는 넘친 날을 다음 달로 넘기므로(3월 3일) 쓰지 않습니다.
func addMonths(t time.Time, months int) time.Time {
	t = t.UTC()
	year, month, day := t.Date()
	targetMonth := month + time.Month(months)
	// time.Date의 0일은 앞 달의 마지막 날이라, targetMonth+1의 0일이 targetMonth의 마지막 날입니다.
	lastDayOfTargetMonth := time.Date(year, targetMonth+1, 0, 0, 0, 0, 0, time.UTC).Day()
	day = min(day, lastDayOfTargetMonth)
	hour, minute, second := t.Clock()
	return time.Date(year, targetMonth, day, hour, minute, second, t.Nanosecond(), time.UTC)
}

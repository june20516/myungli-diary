package billing

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

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
//     catalog에 없는 상품이면 Warn 로그를 남깁니다(S124).
//   - 이미 있으면 아무것도 바꾸지 않고 지금 주인을 돌려줍니다(created = false). 환불 반영은 markRefundedTx 몫입니다.
//   - 같은 스토어 거래(store, store_purchase_id)가 다른 구매 id로 이미 있으면 새로 적지 않고 그 행의 주인을 돌려주며
//     구간도 만들지 않습니다(created = false, Warn 로그). D88 ①은 transfer·다른 App User ID 복원 뒤에도 RevenueCat 구매 id가
//     같다고 보지만 확인하지 못했으므로, 그 전제가 깨져도 한 거래에 주인이 둘 생기지 않게 막습니다(spec §5.2).
//     빈 스토어 거래 id는 맞춰 보지 않습니다. 같은 거래를 두 트랜잭션이 서로 다른 구매 id로 동시에 처음 적으면 둘 다 들어갈 수 있습니다.
//
// 처음 적을 때 이미 환불된 구매는 환불 시각을 알 수 없어 now로 적습니다. production 필터는 호출한 쪽이 적용합니다.
func recordPurchaseTx(ctx context.Context, q *billingdb.Queries, log *slog.Logger, accountID uuid.UUID, p Purchase, catalog Catalog, now time.Time) (owner uuid.UUID, created bool, err error) {
	if p.StorePurchaseID != "" {
		owner, found, err := sameStoreTransactionOwner(ctx, q, log, accountID, p)
		if err != nil || found {
			return owner, false, err
		}
	}

	var refundedAt *time.Time
	if p.Refunded {
		refundedAt = &now
	}
	inserted, err := q.InsertPurchase(ctx, billingdb.InsertPurchaseParams{
		ID:              p.ID,
		AccountID:       accountID,
		ProductID:       p.ProductID,
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
	if !ok {
		// 장부에 적힌 구매는 설정을 고쳐도 구간이 생기지 않으므로, AD_FREE_PRODUCT_IDS 실수를 바로 알 수 있게 남깁니다(S124).
		log.WarnContext(ctx, "목록 밖 상품이라 사용 구간을 만들지 않음",
			"purchaseId", p.ID, "productId", p.ProductID, "store", p.Store, "accountId", accountID)
		return accountID, true, nil
	}
	if p.Refunded {
		return accountID, true, nil
	}
	for _, entitlement := range product.Entitlements {
		if err := placeSegment(ctx, q, accountID, entitlement, p, product.Months); err != nil {
			return uuid.Nil, false, err
		}
	}
	return accountID, true, nil
}

// sameStoreTransactionOwner는 p와 같은 스토어 거래를 다른 구매 id로 먼저 적은 행이 있으면 found = true와 돌려줄 주인을 줍니다.
// p 자신이 이미 장부에 있으면 p의 주인입니다. 로그에는 구매 id 둘과 계정 id만 남기고 스토어 거래 id는 남기지 않습니다.
func sameStoreTransactionOwner(ctx context.Context, q *billingdb.Queries, log *slog.Logger, accountID uuid.UUID, p Purchase) (owner uuid.UUID, found bool, err error) {
	existing, err := q.PurchaseBySameStoreTransaction(ctx, billingdb.PurchaseBySameStoreTransactionParams{
		Store:           p.Store,
		StorePurchaseID: p.StorePurchaseID,
		ID:              p.ID,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, false, fmt.Errorf("같은 스토어 거래 조회(%s): %w", p.ID, err)
	}

	own, err := q.PurchaseOwner(ctx, p.ID)
	switch {
	case err == nil:
		return own, true, nil
	case !errors.Is(err, pgx.ErrNoRows):
		return uuid.Nil, false, fmt.Errorf("구매 주인 조회(%s): %w", p.ID, err)
	}
	log.WarnContext(ctx, "같은 스토어 거래가 다른 구매 id로 장부에 있어 새로 적지 않음",
		"purchaseId", p.ID, "existingPurchaseId", existing.ID, "accountId", accountID, "ownerId", existing.AccountID)
	return existing.AccountID, true, nil
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

// LockAccountsTx는 계정들의 결제 advisory lock(S82)을 tx 안에서 한 번에 잡습니다. 트랜잭션이 끝나면 풀립니다.
// 결제 동기화와 같은 lock·순서라, 합치기처럼 billing 밖에서 구매 장부를 바꾸는 트랜잭션이 동기화와 차례를 지키게 합니다.
func LockAccountsTx(ctx context.Context, tx pgx.Tx, ids ...uuid.UUID) error {
	return lockBillingAccounts(ctx, tx, ids...)
}

// MovePurchasesTx는 계정 합치기에서 from(B)의 구매를 to(A)로 옮깁니다(spec §5.3·§6.3, D88 ①).
//
//   - from의 아직 끝나지 않은 광고 제거권 구간을 now에서 끊습니다. B 쪽 행은 남습니다. 사용 중 구간은 expires_at = now로 끝내고,
//     아직 시작하지 않았거나 now에 막 시작한 구간은 끝을 now로 두면 길이가 0이라(CHECK expires_at > starts_at) revoked_at = now로 끊습니다.
//   - 끊기 전 남은 길이(expires_at - max(starts_at, now))로 to 쪽에 같은 권한·구매의 구간을 to의 구간 끝에 놓고,
//     rechainFromTx(to, now)로 to의 대기 구간을 구매 시각 순으로 다시 잇습니다.
//   - from이 주인인 구매는 구간이 없는 것(끝남·환불·목록 밖 상품)까지 모두 주인을 to로 바꾸고 merged_at = now를 적습니다.
//
// lock은 잡지 않습니다. 호출자가 같은 tx에서 LockAccountsTx(from, to)로 두 계정의 결제 lock을 먼저 잡아야 합니다.
func MovePurchasesTx(ctx context.Context, tx pgx.Tx, from, to uuid.UUID, now time.Time) error {
	q := billingdb.New(tx)
	segments, err := q.ListMovablePassSegments(ctx, billingdb.ListMovablePassSegmentsParams{AccountID: from, Now: now})
	if err != nil {
		return fmt.Errorf("옮길 구간 조회: %w", err)
	}
	for _, segment := range segments {
		if err := cutSegmentAt(ctx, q, from, segment, now); err != nil {
			return err
		}
	}

	if err := q.MovePurchasesOwner(ctx, billingdb.MovePurchasesOwnerParams{ToAccountID: to, Now: now, FromAccountID: from}); err != nil {
		return fmt.Errorf("구매 주인 옮기기: %w", err)
	}

	// 끊은 순서(권한, B 사슬 순)대로 A 끝에 붙인 뒤 다시 잇기가 A의 대기 구간 전체를 구매 시각 순으로 맞춥니다.
	for _, segment := range segments {
		if err := appendRemaining(ctx, q, to, segment, now); err != nil {
			return err
		}
	}
	if err := rechainFromTx(ctx, q, to, now); err != nil {
		return fmt.Errorf("합친 구간 다시 잇기: %w", err)
	}
	return nil
}

// cutSegmentAt은 from 쪽 구간을 now에서 끊습니다. 사용 중이면 끝을 now로, 시작 전이거나 now에 시작했으면 취소로 둡니다.
func cutSegmentAt(ctx context.Context, q *billingdb.Queries, from uuid.UUID, segment billingdb.ListMovablePassSegmentsRow, now time.Time) error {
	if segment.StartsAt.Before(now) {
		if err := q.EndGrantAt(ctx, billingdb.EndGrantAtParams{Now: now, ID: segment.ID, AccountID: from}); err != nil {
			return fmt.Errorf("옮길 구간 끝내기(%d): %w", segment.ID, err)
		}
		return nil
	}
	if err := q.RevokeGrant(ctx, billingdb.RevokeGrantParams{Now: now, ID: segment.ID, AccountID: from}); err != nil {
		return fmt.Errorf("옮길 구간 끊기(%d): %w", segment.ID, err)
	}
	return nil
}

// appendRemaining은 from 구간의 남은 길이로 to 쪽 구간을 to의 같은 권한 구간 끝(없으면 now)에 놓습니다.
func appendRemaining(ctx context.Context, q *billingdb.Queries, to uuid.UUID, segment billingdb.ListMovablePassSegmentsRow, now time.Time) error {
	remaining := segment.ExpiresAt.Sub(latest(segment.StartsAt, now))
	startsAt, err := q.NextPassStart(ctx, billingdb.NextPassStartParams{
		PurchasedAt: now,
		AccountID:   to,
		Entitlement: segment.Entitlement,
	})
	if err != nil {
		return fmt.Errorf("합친 구간 시작 계산(%s %s): %w", segment.Entitlement, segment.SourceRef, err)
	}
	err = q.InsertPassGrant(ctx, billingdb.InsertPassGrantParams{
		AccountID:   to,
		Entitlement: segment.Entitlement,
		SourceRef:   segment.SourceRef,
		StartsAt:    startsAt,
		ExpiresAt:   startsAt.Add(remaining),
	})
	if err != nil {
		return fmt.Errorf("합친 구간 저장(%s %s): %w", segment.Entitlement, segment.SourceRef, err)
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

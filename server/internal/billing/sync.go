package billing

import (
	"cmp"
	"context"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// billingLockSQL은 한 계정의 광고 제거권 동기화를 트랜잭션 하나씩 차례로 하게 하는 advisory lock입니다(P7-6).
// 동시에 온 webhook·구매 복원이 lock을 잡은 뒤 RevenueCat을 조회하므로, 먼저 조회한 오래된 목록이
// 나중에 조회한 새 목록의 조정 결과를 덮지 않습니다. 트랜잭션이 끝나면 자동으로 풀립니다.
//
// 키 도출: 두 int4 키 형식 (billingLockClass, hashtext(계정 id 문자열))을 씁니다(content.selectionLockSQL과 같은 방식).
//   - PostgreSQL은 bigint 키 하나 형식과 int4 키 둘 형식을 서로 다른 lock으로 다룹니다. 시드 적재·goose migration lock은 bigint 형식이라 겹치지 않습니다.
//   - 첫 키 billingLockClass는 이 용도의 고정값이라 문장 선택 lock(첫 키 "sel")과 겹치지 않습니다.
//   - 둘째 키는 32비트 해시라 서로 다른 계정이 같은 값을 가질 수 있습니다. 그때는 두 계정이 잠시 차례로 기다릴 뿐 결과는 같습니다.
const billingLockSQL = "SELECT pg_advisory_xact_lock($1::int4, hashtext($2::text))"

// billingLockClass는 billingLockSQL의 첫 키입니다("bil"의 ASCII).
const billingLockClass int32 = 0x62696c

// PurchaseSource는 고객의 구매 목록을 알려 줍니다. *RevenueCat이 만족합니다.
type PurchaseSource interface {
	Purchases(ctx context.Context, customerID string) ([]Purchase, error)
}

var _ PurchaseSource = (*RevenueCat)(nil)

// SyncConfig는 광고 제거권 동기화 설정입니다(P7-2).
type SyncConfig struct {
	// Catalog는 사용 구간을 만드는 상품 목록입니다. 목록 밖 상품은 무시합니다.
	Catalog Catalog
	// ProductionOnly가 true면 production 구매만 셉니다(APP_ENV가 prod일 때).
	ProductionOnly bool
}

// Syncer는 RevenueCat 구매 목록으로 계정의 광고 제거권 행을 다시 계산해 맞춥니다.
type Syncer struct {
	pool           *pgxpool.Pool
	source         PurchaseSource
	catalog        Catalog
	productionOnly bool
	clk            clock.Clock
	store          *Store
}

// NewSyncer는 Syncer를 만듭니다.
func NewSyncer(pool *pgxpool.Pool, src PurchaseSource, cfg SyncConfig, clk clock.Clock) *Syncer {
	return &Syncer{
		pool:           pool,
		source:         src,
		catalog:        cfg.Catalog,
		productionOnly: cfg.ProductionOnly,
		clk:            clk,
		store:          NewStore(pool, clk),
	}
}

// grantKey는 계정 안에서 ad_free_pass 행 하나를 가리킵니다. 표의 unique (entitlement, source, source_ref) 중 source는 늘 ad_free_pass입니다.
type grantKey struct {
	entitlement Entitlement
	sourceRef   string
}

// Sync는 계정의 구매 목록을 다시 조회해 ad_free_pass 행을 맞춥니다(P7-4·P7-5·P7-6).
//
//   - 계정 advisory lock을 잡은 뒤 같은 트랜잭션 안에서 구매 목록을 조회하고 조정합니다.
//   - 원하는 행(adFreeGrants)은 없으면 넣고, 기간이 다르거나 취소돼 있으면 고칩니다.
//   - 원하는 집합에 없는 이 계정의 ad_free_pass 행은 revoked_at = now입니다(이미 찍혀 있으면 그대로). 행을 지우지 않습니다.
//   - rewarded_ad·subscription 출처 행은 건드리지 않습니다.
//
// 조회 오류는 감싸서 돌려주고(errors.Is로 ErrProviderUnavailable을 확인할 수 있음) 아무 행도 바꾸지 않습니다.
func (s *Syncer) Sync(ctx context.Context, accountID uuid.UUID) error {
	// InTx가 fn을 다시 실행할 수 있습니다. fn은 매번 처음부터 조회하고 원하는 상태로 맞추므로 결과가 같습니다.
	return postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, billingLockSQL, billingLockClass, accountID.String()); err != nil {
			return fmt.Errorf("결제 동기화 잠금: %w", err)
		}

		purchases, err := s.source.Purchases(ctx, accountID.String())
		if err != nil {
			return fmt.Errorf("구매 목록 조회(계정 %s): %w", accountID, err)
		}
		return s.reconcile(ctx, billingdb.New(tx), accountID, adFreeGrants(purchases, s.catalog, s.productionOnly))
	})
}

// reconcile은 계정의 ad_free_pass 행을 want에 맞춥니다(P7-5).
//
// UpsertGrant는 다른 계정에 있던 같은 구매 행을 이 계정으로 옮깁니다(transfer). lock은 계정별이라, transfer 전에 조회한
// 원래 계정의 오래된 목록이 새 주인보다 늦게 upsert하면 행이 원래 계정으로 되돌아가고, 원래 계정의 다음 동기화가 그 행을 취소해
// 새 주인이 다시 동기화할 때까지 권한이 빠질 수 있습니다. TRANSFER 이벤트 하나에 transferred_from·transferred_to가 함께 오고 webhook이 그 계정들을 모두 동기화하므로(P7-7) 결국 수렴해 받아들입니다.
func (s *Syncer) reconcile(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, want []Grant) error {
	wanted := make(map[grantKey]bool, len(want))
	for _, g := range want {
		wanted[grantKey{entitlement: g.Entitlement, sourceRef: g.SourceRef}] = true
		err := q.UpsertGrant(ctx, billingdb.UpsertGrantParams{
			AccountID:   accountID,
			Entitlement: string(g.Entitlement),
			Source:      string(g.Source),
			SourceRef:   g.SourceRef,
			StartsAt:    g.StartsAt,
			ExpiresAt:   g.ExpiresAt,
		})
		if err != nil {
			return fmt.Errorf("권한 행 저장(%s %s): %w", g.Entitlement, g.SourceRef, err)
		}
	}

	existing, err := q.ListAdFreePassGrants(ctx, accountID)
	if err != nil {
		return fmt.Errorf("광고 제거권 행 조회: %w", err)
	}
	now := s.clk.Now()
	for _, row := range existing {
		key := grantKey{entitlement: Entitlement(row.Entitlement), sourceRef: row.SourceRef}
		if wanted[key] || row.RevokedAt != nil {
			continue
		}
		if err := q.RevokeGrant(ctx, billingdb.RevokeGrantParams{Now: now, ID: row.ID, AccountID: accountID}); err != nil {
			return fmt.Errorf("권한 행 취소(%s %s): %w", row.Entitlement, row.SourceRef, err)
		}
	}
	return nil
}

// Restore는 구매 복원입니다. 동기화한 뒤 계정의 권한 상태를 돌려줍니다.
func (s *Syncer) Restore(ctx context.Context, accountID uuid.UUID) (Status, error) {
	if err := s.Sync(ctx, accountID); err != nil {
		return Status{}, err
	}
	return s.store.Status(ctx, accountID)
}

// adFreeGrants는 구매 목록에서 광고 제거권 행을 계산합니다(P7-3·P7-4, D61).
//
// catalog에 있는 상품의 환불되지 않은 구매만 셉니다. productionOnly면 sandbox 구매도 뺍니다.
// 구매를 (구매일, id) 순으로 놓고 starts_at = max(직전 만료일, 구매일), expires_at = starts_at + 1개월로 이어 붙입니다.
// 구매 하나는 같은 기간의 ad_free·insight 두 행(출처 ad_free_pass, source_ref = 구매 id)이 됩니다(D60 ③).
// 입력 slice는 바꾸지 않습니다.
func adFreeGrants(purchases []Purchase, catalog Catalog, productionOnly bool) []Grant {
	counted := make([]Purchase, 0, len(purchases))
	for _, p := range purchases {
		if p.Refunded || !inCatalog(catalog, p.ProductID) || (productionOnly && !p.Production) {
			continue
		}
		counted = append(counted, p)
	}
	slices.SortFunc(counted, func(a, b Purchase) int {
		if c := a.PurchasedAt.Compare(b.PurchasedAt); c != 0 {
			return c
		}
		return cmp.Compare(a.ID, b.ID)
	})

	var grants []Grant
	var previousExpiry time.Time
	for _, p := range counted {
		startsAt := p.PurchasedAt.UTC()
		if previousExpiry.After(startsAt) {
			startsAt = previousExpiry
		}
		expiresAt := addMonth(startsAt)
		for _, entitlement := range catalog[p.ProductID].Entitlements {
			grants = append(grants, Grant{
				Entitlement: entitlement,
				Source:      SourceAdFreePass,
				SourceRef:   p.ID,
				StartsAt:    startsAt,
				ExpiresAt:   expiresAt,
			})
		}
		previousExpiry = expiresAt
	}
	return grants
}

func inCatalog(catalog Catalog, productID string) bool {
	_, ok := catalog[productID]
	return ok
}

// addMonth는 UTC 달력으로 한 달 뒤 같은 날 같은 시각을 돌려줍니다(P7-3).
// 다음 달에 그 날이 없으면 그 달 마지막 날입니다(1월 31일 → 2월 28일·29일).
// time.AddDate는 넘친 날을 다음 달로 넘기므로(3월 3일) 쓰지 않습니다.
func addMonth(t time.Time) time.Time {
	t = t.UTC()
	year, month, day := t.Date()
	// time.Date의 0일은 앞 달의 마지막 날이라, month+2의 0일이 다음 달의 마지막 날입니다.
	lastDayOfNextMonth := time.Date(year, month+2, 0, 0, 0, 0, 0, time.UTC).Day()
	day = min(day, lastDayOfNextMonth)
	hour, minute, second := t.Clock()
	return time.Date(year, month+1, day, hour, minute, second, t.Nanosecond(), time.UTC)
}

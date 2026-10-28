package billing

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// 계정 advisory lock(S82)은 한 계정의 결제 동기화를 트랜잭션 하나씩 차례로 하게 합니다(P7-6).
// 동시에 온 webhook·구매 복원이 lock을 잡은 뒤 RevenueCat을 조회하므로, 먼저 조회한 오래된 목록이
// 나중에 조회한 새 목록의 결과를 덮지 않습니다. 트랜잭션이 끝나면 자동으로 풀립니다.
//
// 키 도출: 두 int4 키 형식 (billingLockClass, hashtext(계정 id 문자열))을 씁니다(content.selectionLockSQL과 같은 방식).
//   - PostgreSQL은 bigint 키 하나 형식과 int4 키 둘 형식을 서로 다른 lock으로 다룹니다. 시드 적재·goose migration lock은 bigint 형식이라 겹치지 않습니다.
//   - 첫 키 billingLockClass는 이 용도의 고정값이라 문장 선택 lock(첫 키 "sel")과 겹치지 않습니다.
//   - 둘째 키는 32비트 해시라 서로 다른 계정이 같은 값을 가질 수 있습니다. 그때는 두 계정이 잠시 차례로 기다릴 뿐 결과는 같습니다.
const (
	// billingLockKeysSQL은 계정 id들의 둘째 키를 중복 없이 오름차순으로 돌려줍니다.
	billingLockKeysSQL = "SELECT DISTINCT hashtext(id) AS lock_key FROM unnest($1::text[]) AS id ORDER BY lock_key"
	// billingLockSQL은 키 하나의 lock을 잡습니다.
	billingLockSQL = "SELECT pg_advisory_xact_lock($1::int4, $2::int4)"
)

// billingLockClass는 계정 advisory lock의 첫 키입니다("bil"의 ASCII).
const billingLockClass int32 = 0x62696c

// RecordYears는 결제 기록(webhook 수신, 구매 장부, 결제 구간)의 보관 기간입니다(S113). job retention이 이 기간이 지난
// 기록을 지우고(S120), Sync는 결제일이 이 기간보다 오래된 구매를 장부에 적지 않아 지운 기록을 되살리지 않습니다.
const RecordYears = 5

// maxLockRounds는 Sync가 잠글 계정을 늘려 다시 시작하는 횟수 상한입니다.
// 첫 판에 자기 계정, 둘째 판에 다른 주인 계정까지 잡으면 끝나고, 그 사이 합치기로 주인이 바뀐 경우를 위해 여유를 둡니다.
const maxLockRounds = 4

// PurchaseSource는 고객의 구매 목록을 알려 줍니다. *RevenueCat이 만족합니다.
type PurchaseSource interface {
	Purchases(ctx context.Context, customerID string) ([]Purchase, error)
}

var _ PurchaseSource = (*RevenueCat)(nil)

// SyncConfig는 결제 동기화 설정입니다(P7-2, spec §5.1).
type SyncConfig struct {
	// Catalog는 사용 구간을 만드는 상품 목록입니다. 목록 밖 상품은 장부에만 적습니다.
	Catalog Catalog
	// ProductionOnly가 true면 production 구매만 장부에 적습니다(APP_ENV가 prod일 때).
	ProductionOnly bool
	// Logger는 장부 기록의 경고를 남깁니다. nil이면 버립니다.
	Logger *slog.Logger
}

// Syncer는 계정의 RevenueCat 구매 목록으로 구매 장부와 사용 구간을 맞춥니다(spec §5.4).
type Syncer struct {
	pool           *pgxpool.Pool
	source         PurchaseSource
	catalog        Catalog
	productionOnly bool
	clk            clock.Clock
	store          *Store
	log            *slog.Logger
}

// NewSyncer는 Syncer를 만듭니다.
func NewSyncer(pool *pgxpool.Pool, src PurchaseSource, cfg SyncConfig, clk clock.Clock) *Syncer {
	return &Syncer{
		pool:           pool,
		source:         src,
		catalog:        cfg.Catalog,
		productionOnly: cfg.ProductionOnly,
		clk:            clk,
		store:          NewStore(pool, clk, cfg.Catalog),
		log:            cmp.Or(cfg.Logger, slog.New(slog.DiscardHandler)),
	}
}

// needLocksError는 이 판에서 잡지 않은 주인 계정의 구간을 고쳐야 해서 그 계정까지 잡고 다시 시작해야 한다는 뜻입니다.
// 트랜잭션을 되돌리려고 fn이 돌려주는 내부 값이고 Sync 밖으로 나가지 않습니다.
type needLocksError struct {
	accountIDs []uuid.UUID
}

func (e *needLocksError) Error() string {
	return fmt.Sprintf("잠그지 않은 주인 계정 %d개", len(e.accountIDs))
}

// Sync는 계정의 구매 목록을 다시 조회해 구매 장부와 사용 구간을 맞춥니다(spec §5.4, S107·S108).
//
//   - 장부에 없는 구매는 이 계정을 주인으로 적고, 상품 목록에 있으면 구간을 놓습니다(recordPurchaseTx).
//   - 장부에 있는 구매는 주인을 바꾸지 않습니다. 목록에서 환불로 보이면 장부에 환불을 적고 주인 계정을 now부터 다시 잇습니다.
//   - 장부에 있는데 목록에 없는 구매는 취소하지 않습니다. 기준은 장부입니다.
//   - rewarded_ad·subscription 출처 행은 건드리지 않습니다.
//
// 잠금: 계정 advisory lock을 잡은 뒤 같은 트랜잭션 안에서 목록을 조회하고 적습니다. 다른 주인 계정의 구간을 고쳐야 하면
// 이미 잡은 lock 뒤에 더 잡지 않고(deadlock을 피함), 트랜잭션을 되돌린 뒤 그 계정까지 lockBillingAccounts로 한 번에 잡고 다시 시작합니다.
//
// 조회 오류는 감싸서 돌려주고(errors.Is로 ErrProviderUnavailable을 확인할 수 있음) 아무 행도 바꾸지 않습니다.
func (s *Syncer) Sync(ctx context.Context, accountID uuid.UUID) error {
	locked := []uuid.UUID{accountID}
	for range maxLockRounds {
		// InTx가 fn을 다시 실행할 수 있습니다. fn은 매번 처음부터 조회해 적으므로 결과가 같습니다.
		err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
			if err := lockBillingAccounts(ctx, tx, locked...); err != nil {
				return err
			}
			return s.syncLocked(ctx, billingdb.New(tx), accountID, locked)
		})
		var need *needLocksError
		if !errors.As(err, &need) {
			return err
		}
		locked = appendMissing(locked, need.accountIDs...)
	}
	return fmt.Errorf("결제 동기화(계정 %s): 잠글 계정을 %d번 늘려도 끝나지 않았습니다", accountID, maxLockRounds)
}

// syncLocked는 locked 계정의 lock을 잡은 트랜잭션에서 accountID의 목록을 장부에 적습니다.
// locked에 없는 주인 계정의 구간을 고쳐야 하면 그 계정들을 needLocksError로 돌려줍니다(트랜잭션은 되돌아감).
func (s *Syncer) syncLocked(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, locked []uuid.UUID) error {
	purchases, err := s.source.Purchases(ctx, accountID.String())
	if err != nil {
		return fmt.Errorf("구매 목록 조회(계정 %s): %w", accountID, err)
	}

	now := s.clk.Now()
	recordCutoff := now.AddDate(-RecordYears, 0, 0)
	var rechainOwners, unlockedOwners []uuid.UUID
	for _, p := range s.ledgerOrder(purchases) {
		if p.PurchasedAt.Before(recordCutoff) {
			// 보관 기간이 지난 구매는 job retention이 지웠거나 곧 지울 기록이라 적지도 고치지도 않습니다(S120).
			continue
		}
		owner, created, err := recordPurchaseTx(ctx, q, s.log, accountID, p, s.catalog, now)
		if err != nil {
			return err
		}
		if created || !p.Refunded {
			continue
		}
		if !slices.Contains(locked, owner) {
			// 잠그지 않은 주인의 구매는 쓰지 않고 읽기만 합니다. 이미 환불로 적혀 있으면 할 일이 없어 다시 시작하지 않습니다.
			alreadyRefunded, err := q.PurchaseRefunded(ctx, p.ID)
			if err != nil {
				return fmt.Errorf("구매 환불 조회(%s): %w", p.ID, err)
			}
			if !alreadyRefunded {
				unlockedOwners = appendMissing(unlockedOwners, owner)
			}
			continue
		}
		changed, err := markRefundedTx(ctx, q, p.ID, now)
		if err != nil {
			return err
		}
		if changed {
			rechainOwners = appendMissing(rechainOwners, owner)
		}
	}
	if len(unlockedOwners) > 0 {
		return &needLocksError{accountIDs: unlockedOwners}
	}

	for _, owner := range rechainOwners {
		if err := rechainFromTx(ctx, q, owner, now); err != nil {
			return fmt.Errorf("구간 다시 잇기(계정 %s): %w", owner, err)
		}
	}
	return nil
}

// ledgerOrder는 장부에 적을 구매를 (구매 시각, id) 순으로 돌려줍니다. 새 구간이 구매 순서대로 이어 붙도록 정렬합니다(S108).
// productionOnly면 sandbox 구매를 뺍니다(P7). 입력 slice는 바꾸지 않습니다.
func (s *Syncer) ledgerOrder(purchases []Purchase) []Purchase {
	ordered := make([]Purchase, 0, len(purchases))
	for _, p := range purchases {
		if s.productionOnly && !p.Production {
			continue
		}
		ordered = append(ordered, p)
	}
	slices.SortFunc(ordered, func(a, b Purchase) int {
		if c := a.PurchasedAt.Compare(b.PurchasedAt); c != 0 {
			return c
		}
		return cmp.Compare(a.ID, b.ID)
	})
	return ordered
}

// lockBillingAccounts는 계정들의 advisory lock을 한 번에 잡습니다(S82, spec §5.4).
//
// 모든 호출이 같은 전역 순서로 잡아야 두 트랜잭션이 서로의 lock을 기다리는 일이 없습니다. 실제로 잡는 것은
// 계정 id가 아니라 둘째 키(hashtext)라서, 계정 id 순으로 잡으면 해시가 겹친 두 계정이 순서를 뒤집을 수 있습니다.
// 그래서 키를 중복 없이 오름차순으로 정해 그 순서로 잡습니다. 같은 키를 두 번 잡지 않으므로 해시가 겹쳐도 안전합니다.
func lockBillingAccounts(ctx context.Context, tx pgx.Tx, ids ...uuid.UUID) error {
	idStrings := make([]string, len(ids))
	for i, id := range ids {
		idStrings[i] = id.String()
	}
	rows, err := tx.Query(ctx, billingLockKeysSQL, idStrings)
	if err != nil {
		return fmt.Errorf("결제 동기화 잠금 키: %w", err)
	}
	keys, err := pgx.CollectRows(rows, pgx.RowTo[int32])
	if err != nil {
		return fmt.Errorf("결제 동기화 잠금 키: %w", err)
	}
	for _, key := range keys {
		if _, err := tx.Exec(ctx, billingLockSQL, billingLockClass, key); err != nil {
			return fmt.Errorf("결제 동기화 잠금: %w", err)
		}
	}
	return nil
}

// appendMissing은 list에 없는 id만 차례로 더합니다.
func appendMissing(list []uuid.UUID, ids ...uuid.UUID) []uuid.UUID {
	for _, id := range ids {
		if !slices.Contains(list, id) {
			list = append(list, id)
		}
	}
	return list
}

// Restore는 구매 복원입니다. 동기화한 뒤 계정의 권한 상태를 돌려줍니다.
func (s *Syncer) Restore(ctx context.Context, accountID uuid.UUID) (Status, error) {
	if err := s.Sync(ctx, accountID); err != nil {
		return Status{}, err
	}
	return s.store.Status(ctx, accountID)
}

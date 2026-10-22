package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const insertPurchase = `INSERT INTO purchases (id, account_id, original_account_id, product_id, store, purchased_at, production)
	VALUES ($1, $2, $3, 'product.month', 'app_store', now(), true)`

func TestSchema00016_Purchases(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, id := range []string{accountA, accountB} {
		if err := insertActive(ctx, pool, id); err != nil {
			t.Fatal(err)
		}
	}

	// refunded_at·merged_at은 NULL을 허용하고, 합친 구매는 account_id와 original_account_id가 다를 수 있습니다.
	if _, err := pool.Exec(ctx, insertPurchase, "txn-1", accountA, accountB); err != nil {
		t.Fatalf("구매 삽입: %v", err)
	}
	var refundedNull, mergedNull bool
	if err := pool.QueryRow(ctx, `SELECT refunded_at IS NULL, merged_at IS NULL FROM purchases WHERE id = 'txn-1'`).Scan(&refundedNull, &mergedNull); err != nil {
		t.Fatal(err)
	}
	if !refundedNull || !mergedNull {
		t.Errorf("refunded_at NULL = %v, merged_at NULL = %v, want 둘 다 true", refundedNull, mergedNull)
	}

	// id는 PK입니다.
	if _, err := pool.Exec(ctx, insertPurchase, "txn-1", accountA, accountA); err == nil {
		t.Error("같은 구매 id를 두 번 넣을 수 있습니다")
	}

	// 두 계정 FK는 RESTRICT라 구매가 있는 계정 행은 지울 수 없습니다.
	for _, id := range []string{accountA, accountB} {
		_, err := pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1`, id)
		wantSQLState(t, err, foreignKeyViolation)
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.TableName != "purchases" {
			t.Errorf("계정 %s 삭제를 막은 표 = %s, want purchases", id, pgErr.TableName)
		}
	}

	// 없는 계정은 두 열 모두 거절합니다.
	_, err := pool.Exec(ctx, insertPurchase, "txn-2", "00000000-0000-7000-8000-0000000000ff", accountA)
	wantSQLState(t, err, foreignKeyViolation)
	_, err = pool.Exec(ctx, insertPurchase, "txn-3", accountA, "00000000-0000-7000-8000-0000000000ff")
	wantSQLState(t, err, foreignKeyViolation)

	// 목록 조회용 인덱스가 있습니다.
	var indexDef string
	if err := pool.QueryRow(ctx, `SELECT indexdef FROM pg_indexes WHERE tablename = 'purchases' AND indexdef LIKE '%account_id, purchased_at DESC%'`).Scan(&indexDef); err != nil {
		t.Errorf("(account_id, purchased_at DESC) 인덱스 조회: %v", err)
	}

	// webhook 대체 경로가 스토어 거래 id로 주인을 찾는 인덱스가 있고, 열은 비어 있을 수 있습니다(spec §5.4).
	if err := pool.QueryRow(ctx, `SELECT indexdef FROM pg_indexes WHERE tablename = 'purchases' AND indexdef LIKE '%(store_purchase_id)%'`).Scan(&indexDef); err != nil {
		t.Errorf("(store_purchase_id) 인덱스 조회: %v", err)
	}
	var storePurchaseNull bool
	if err := pool.QueryRow(ctx, `SELECT store_purchase_id IS NULL FROM purchases WHERE id = 'txn-1'`).Scan(&storePurchaseNull); err != nil || !storePurchaseNull {
		t.Errorf("store_purchase_id NULL = %v, err = %v, want true", storePurchaseNull, err)
	}
}

func TestSchema00016_GrantsUniquePerAccount(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, id := range []string{accountA, accountB} {
		if err := insertActive(ctx, pool, id); err != nil {
			t.Fatal(err)
		}
	}

	if err := insertGrantRow(ctx, pool, accountA); err != nil {
		t.Fatalf("A 구간: %v", err)
	}
	if err := insertGrantRow(ctx, pool, accountB); err != nil {
		t.Errorf("같은 (entitlement, source, source_ref)를 다른 계정에 넣을 수 없습니다: %v", err)
	}
	if err := insertGrantRow(ctx, pool, accountA); err == nil {
		t.Error("같은 계정에 같은 (entitlement, source, source_ref)를 두 번 넣을 수 있습니다")
	}
}

// 00016은 장부 이전 동기화가 만든 광고 제거권 구간을 지우고, 다른 출처 행은 남깁니다.
func TestSchema00016_DropsPrePurchaseLedgerPassGrants(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := postgres.MigrateDownTo(ctx, pool, 15); err != nil {
		t.Fatal(err)
	}
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatal(err)
	}
	if err := insertGrantRow(ctx, pool, accountA); err != nil {
		t.Fatalf("옛 광고 제거권 구간: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'insight', 'rewarded_ad', 'ssv-1', now(), now() + interval '1 day')`, accountA); err != nil {
		t.Fatalf("보상형 광고 행: %v", err)
	}
	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatal(err)
	}

	var passRows, rewardedRows int
	if err := pool.QueryRow(ctx, `SELECT count(*) FILTER (WHERE source = 'ad_free_pass'), count(*) FILTER (WHERE source = 'rewarded_ad')
		FROM entitlement_grants`).Scan(&passRows, &rewardedRows); err != nil {
		t.Fatal(err)
	}
	if passRows != 0 || rewardedRows != 1 {
		t.Errorf("ad_free_pass %d행, rewarded_ad %d행, want 0행·1행", passRows, rewardedRows)
	}
}

func insertGrantRow(ctx context.Context, pool *pgxpool.Pool, accountID string) error {
	_, err := pool.Exec(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'ad_free_pass', 'txn-1', now(), now() + interval '1 month')`, accountID)
	return err
}

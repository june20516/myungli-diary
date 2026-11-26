package postgres_test

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const insertOpsAudit = `INSERT INTO ops_audit (id, at, actor, channel, action, purpose, reason, target)
	VALUES ($1, now() - $2::interval, 'op@example.com', 'cli', $3, $4, '사유', '{}')`

// 감사 행은 고칠 수 없습니다(UPDATE 거절).
func TestOpsAudit_UpdateRejected(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	id := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, insertOpsAudit, id, "0 seconds", "grant", nil); err != nil {
		t.Fatalf("INSERT: %v", err)
	}

	if _, err := pool.Exec(ctx, `UPDATE ops_audit SET reason = 'x' WHERE id = $1`, id); err == nil {
		t.Error("ops_audit UPDATE가 성공했습니다")
	}
}

// 감사 행은 2년이 지난 것만 지울 수 있습니다.
func TestOpsAudit_DeleteOnlyOlderThanTwoYears(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	oldID, recentID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, insertOpsAudit, oldID, "2 years 1 day", "grant", nil); err != nil {
		t.Fatalf("오래된 행 INSERT: %v", err)
	}
	if _, err := pool.Exec(ctx, insertOpsAudit, recentID, "1 year", "grant", nil); err != nil {
		t.Fatalf("최근 행 INSERT: %v", err)
	}

	if _, err := pool.Exec(ctx, `DELETE FROM ops_audit WHERE id = $1`, recentID); err == nil {
		t.Error("2년이 안 된 행 DELETE가 성공했습니다")
	}
	if _, err := pool.Exec(ctx, `DELETE FROM ops_audit WHERE id = $1`, oldID); err != nil {
		t.Errorf("2년이 지난 행 DELETE: %v", err)
	}
}

// 목적은 content_view에만 있고, content_view에는 반드시 있습니다.
func TestOpsAudit_PurposeRequiredOnlyForView(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	if _, err := pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "0 seconds", "content_view", nil); err == nil {
		t.Error("purpose 없는 content_view가 들어갔습니다")
	}
	if _, err := pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "0 seconds", "grant", "inquiry"); err == nil {
		t.Error("purpose가 있는 grant가 들어갔습니다")
	}
	if _, err := pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "0 seconds", "content_view", "inquiry"); err != nil {
		t.Errorf("purpose 있는 content_view INSERT: %v", err)
	}
}

// 운영자 부여의 출처 operator를 받습니다.
func TestEntitlementGrants_OperatorSourceAllowed(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	accountID := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', now())`, accountID); err != nil {
		t.Fatalf("계정 INSERT: %v", err)
	}

	_, err := pool.Exec(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'operator', 'ref-1', now(), now() + interval '1 day')`, accountID)
	if err != nil {
		t.Errorf("source operator INSERT: %v", err)
	}
}

// 00029를 되돌렸다가 다시 적용할 수 있고, 되돌리면 operator 행이 사라집니다.
func TestMigrate_OpsDownUp(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	accountID := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', now())`, accountID); err != nil {
		t.Fatalf("계정 INSERT: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'operator', 'ref-1', now(), now() + interval '1 day')`, accountID); err != nil {
		t.Fatalf("operator 행 INSERT: %v", err)
	}

	if err := postgres.MigrateDownTo(ctx, pool, 28); err != nil {
		t.Fatalf("MigrateDownTo(28): %v", err)
	}
	var operatorRows int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM entitlement_grants WHERE source = 'operator'`).Scan(&operatorRows); err != nil || operatorRows != 0 {
		t.Fatalf("되돌린 뒤 operator 행 = %d (err %v), want 0", operatorRows, err)
	}
	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatalf("다시 up: %v", err)
	}
}

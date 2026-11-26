package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const insertOpsAudit = `INSERT INTO ops_audit (id, at, actor, channel, action, purpose, reason, target)
	VALUES ($1, now() - $2::interval, 'op@example.com', 'cli', $3, $4, '사유', '{}')`

const (
	raiseException = "P0001" // trigger의 RAISE EXCEPTION
)

// requirePgError는 err가 PostgreSQL 오류이고 SQLSTATE 코드(와 비어 있지 않으면 constraint 이름)가 같은지 확인합니다.
func requirePgError(t *testing.T, err error, code, constraint string) {
	t.Helper()
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		t.Errorf("PostgreSQL 오류를 기대했지만 %v", err)
		return
	}
	if pgErr.Code != code || (constraint != "" && pgErr.ConstraintName != constraint) {
		t.Errorf("오류 = %s(constraint %q), want %s(constraint %q): %v", pgErr.Code, pgErr.ConstraintName, code, constraint, err)
	}
}

// 감사 행은 고칠 수 없습니다(UPDATE 거절).
func TestOpsAudit_UpdateRejected(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	id := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, insertOpsAudit, id, "0 seconds", "grant", nil); err != nil {
		t.Fatalf("INSERT: %v", err)
	}

	_, err := pool.Exec(ctx, `UPDATE ops_audit SET reason = 'x' WHERE id = $1`, id)
	requirePgError(t, err, raiseException, "")
}

// 감사 표는 비울 수 없습니다(행 trigger는 TRUNCATE를 막지 못해 문장 trigger가 따로 있음).
func TestOpsAudit_TruncateRejected(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if _, err := pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "3 years", "grant", nil); err != nil {
		t.Fatalf("INSERT: %v", err)
	}

	_, err := pool.Exec(ctx, `TRUNCATE ops_audit`)
	requirePgError(t, err, raiseException, "")
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

	_, err := pool.Exec(ctx, `DELETE FROM ops_audit WHERE id = $1`, recentID)
	requirePgError(t, err, raiseException, "")
	if _, err := pool.Exec(ctx, `DELETE FROM ops_audit WHERE id = $1`, oldID); err != nil {
		t.Errorf("2년이 지난 행 DELETE: %v", err)
	}
}

// 목적은 content_view에만 있고, content_view에는 반드시 있습니다.
func TestOpsAudit_PurposeRequiredOnlyForView(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	_, err := pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "0 seconds", "content_view", nil)
	requirePgError(t, err, checkViolation, "ops_audit_purpose_for_view")
	_, err = pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "0 seconds", "grant", "inquiry")
	requirePgError(t, err, checkViolation, "ops_audit_purpose_for_view")
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
	var tableExists bool
	if err := pool.QueryRow(ctx, `SELECT to_regclass('ops_audit') IS NOT NULL`).Scan(&tableExists); err != nil || tableExists {
		t.Errorf("되돌린 뒤 ops_audit 표 존재 = %v (err %v), want false", tableExists, err)
	}
	var canRead, canUpdateAccounts bool
	err := pool.QueryRow(ctx, `SELECT has_table_privilege('myungli_ops', 'diaries', 'SELECT'),
		has_column_privilege('myungli_ops', 'accounts', 'updated_at', 'UPDATE')`).Scan(&canRead, &canUpdateAccounts)
	if err != nil || canRead || canUpdateAccounts {
		t.Errorf("되돌린 뒤 myungli_ops 권한 diaries SELECT = %v, accounts.updated_at UPDATE = %v (err %v), want 모두 false", canRead, canUpdateAccounts, err)
	}

	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatalf("다시 up: %v", err)
	}
	if err := pool.QueryRow(ctx, `SELECT has_table_privilege('myungli_ops', 'diaries', 'SELECT')`).Scan(&canRead); err != nil || !canRead {
		t.Errorf("다시 up 뒤 myungli_ops diaries SELECT = %v (err %v), want true", canRead, err)
	}
	// retention은 myungli_app 역할로 돌므로 감사 행 DELETE는 되고 UPDATE는 안 되어야 합니다.
	var appCanDelete, appCanUpdate bool
	err = pool.QueryRow(ctx, `SELECT has_table_privilege('myungli_app', 'ops_audit', 'DELETE'),
		has_table_privilege('myungli_app', 'ops_audit', 'UPDATE')`).Scan(&appCanDelete, &appCanUpdate)
	if err != nil || !appCanDelete || appCanUpdate {
		t.Errorf("myungli_app ops_audit DELETE = %v, UPDATE = %v (err %v), want true, false", appCanDelete, appCanUpdate, err)
	}
}

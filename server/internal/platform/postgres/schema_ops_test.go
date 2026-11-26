package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// insertOpsAudit의 at은 trigger(ops_audit_stamp)가 now()로 덮습니다. 과거 행이 필요하면 insertOldOpsAudit을 씁니다.
const insertOpsAudit = `INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, purpose, reason, target)
	VALUES ($1, now() - $2::interval, 'op@example.com', 'sub-1', 'ops_api', $3, $4, '사유', '{}')`

// insertOldOpsAudit은 trigger를 끄고 ago만큼 지난 감사 행을 넣습니다.
func insertOldOpsAudit(t *testing.T, pool *pgxpool.Pool, id uuid.UUID, ago string) {
	t.Helper()
	dbtest.ExecWithoutTriggers(t, pool, insertOpsAudit, id, ago, "grant", nil)
}

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
	insertOldOpsAudit(t, pool, uuid.Must(uuid.NewV7()), "3 years")

	_, err := pool.Exec(ctx, `TRUNCATE ops_audit`)
	requirePgError(t, err, raiseException, "")
}

// 감사 행은 2년이 지난 것만 지울 수 있습니다.
func TestOpsAudit_DeleteOnlyOlderThanTwoYears(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	oldID, recentID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	insertOldOpsAudit(t, pool, oldID, "2 years 1 day")
	insertOldOpsAudit(t, pool, recentID, "1 year")

	_, err := pool.Exec(ctx, `DELETE FROM ops_audit WHERE id = $1`, recentID)
	requirePgError(t, err, raiseException, "")
	if _, err := pool.Exec(ctx, `DELETE FROM ops_audit WHERE id = $1`, oldID); err != nil {
		t.Errorf("2년이 지난 행 DELETE: %v", err)
	}
}

// 감사 행의 at은 언제나 DB now()입니다. 넣는 값으로 바꿀 수 없고, actor는 넣은 값 그대로입니다.
func TestOpsAudit_StampSetsAtOnly(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	id := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, `INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, reason, target)
		VALUES ($1, now() - interval '3 years', 'someone@example.com', 'sub-9', 'ops_api', 'grant', '사유', '{}')`, id); err != nil {
		t.Fatalf("ops_api 행 INSERT: %v", err)
	}

	var actor, actorSub string
	var recent bool
	if err := pool.QueryRow(ctx, `SELECT actor, actor_sub, at > now() - interval '1 minute' FROM ops_audit WHERE id = $1`, id).Scan(&actor, &actorSub, &recent); err != nil {
		t.Fatalf("행 읽기: %v", err)
	}
	if actor != "someone@example.com" || actorSub != "sub-9" || !recent {
		t.Errorf("actor = %q, actor_sub = %q, 최근 시각 = %v, want someone@example.com, sub-9, true", actor, actorSub, recent)
	}
}

// ops_api 밖의 channel은 trigger나 CHECK가 거절합니다. 경로가 하나뿐이라는 것을 DB가 강제합니다.
func TestOpsAudit_RejectsNonOpsAPIChannel(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	const insert = `INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, reason, target)
		VALUES (gen_random_uuid(), now(), 'op@example.com', 'sub-1', 'cli', 'grant', '사유', '{}')`
	// 열 CHECK가 trigger보다 먼저 닿지 않으므로(BEFORE trigger가 먼저) trigger의 예외가 옵니다.
	_, err := pool.Exec(ctx, insert)
	requirePgError(t, err, raiseException, "")
	var rows int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM ops_audit`).Scan(&rows); err != nil || rows != 0 {
		t.Errorf("감사 행 = %d (err %v), want 0", rows, err)
	}
	// myungli_ops로 SET ROLE해도 같습니다.
	err = asRole(t, pool, postgres.OpsRole, insert)
	requirePgError(t, err, raiseException, "")
}

// 실행자 sub는 비울 수 없습니다.
func TestOpsAudit_ActorSubRequired(t *testing.T) {
	pool := dbtest.New(t)
	_, err := pool.Exec(context.Background(), `INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, reason, target)
		VALUES (gen_random_uuid(), now(), 'op@example.com', '', 'ops_api', 'grant', '사유', '{}')`)
	requirePgError(t, err, checkViolation, "")
}

// 앱 런타임(myungli_app)은 감사 행을 쓸 수 없습니다. retention용 DELETE는 남습니다.
func TestOpsAudit_AppRoleCannotInsert(t *testing.T) {
	pool := dbtest.New(t)
	err := asRole(t, pool, "myungli_app", `INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, reason, target)
		VALUES (gen_random_uuid(), now(), 'x', 'sub-1', 'ops_api', 'grant', '사유', '{}')`)
	requirePgError(t, err, insufficientPrivilege, "")
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

// 00029를 되돌렸다가 다시 적용할 수 있고, 되돌리면 operator 행이 사라지고 myungli_ops 권한이 거두어집니다.
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
	if err := pool.QueryRow(ctx, `SELECT to_regclass('ops_audit') IS NOT NULL`).Scan(&tableExists); err != nil || !tableExists {
		t.Errorf("되돌린 뒤 ops_audit 표 존재 = %v (err %v), want true(감사 기록은 남음)", tableExists, err)
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
	// retention은 myungli_app 역할로 돌므로 감사 행 DELETE는 되고 UPDATE와 INSERT는 안 되어야 합니다.
	var appCanDelete, appCanUpdate, appCanInsert bool
	err = pool.QueryRow(ctx, `SELECT has_table_privilege('myungli_app', 'ops_audit', 'DELETE'),
		has_table_privilege('myungli_app', 'ops_audit', 'UPDATE'),
		has_table_privilege('myungli_app', 'ops_audit', 'INSERT')`).Scan(&appCanDelete, &appCanUpdate, &appCanInsert)
	if err != nil || !appCanDelete || appCanUpdate || appCanInsert {
		t.Errorf("myungli_app ops_audit DELETE = %v, UPDATE = %v, INSERT = %v (err %v), want true, false, false", appCanDelete, appCanUpdate, appCanInsert, err)
	}
}

// 00029를 되돌려도 감사 행은 남고, 다시 적용해도 성공합니다(보관 의무가 있는 기록을 지우지 않음).
func TestMigrate_OpsDownKeepsAudit(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	id := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, insertOpsAudit, id, "0 seconds", "grant", nil); err != nil {
		t.Fatalf("감사 INSERT: %v", err)
	}

	if err := postgres.MigrateDownTo(ctx, pool, 28); err != nil {
		t.Fatalf("MigrateDownTo(28): %v", err)
	}
	var rows int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM ops_audit WHERE id = $1`, id).Scan(&rows); err != nil || rows != 1 {
		t.Fatalf("되돌린 뒤 감사 행 = %d (err %v), want 1", rows, err)
	}
	var canInsert bool
	if err := pool.QueryRow(ctx, `SELECT has_table_privilege('myungli_ops', 'ops_audit', 'INSERT')`).Scan(&canInsert); err != nil || canInsert {
		t.Errorf("되돌린 뒤 myungli_ops ops_audit INSERT = %v (err %v), want false", canInsert, err)
	}

	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatalf("다시 up: %v", err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM ops_audit WHERE id = $1`, id).Scan(&rows); err != nil || rows != 1 {
		t.Errorf("다시 up 뒤 감사 행 = %d (err %v), want 1", rows, err)
	}
	if err := pool.QueryRow(ctx, `SELECT has_table_privilege('myungli_ops', 'ops_audit', 'INSERT')`).Scan(&canInsert); err != nil || !canInsert {
		t.Errorf("다시 up 뒤 myungli_ops ops_audit INSERT = %v (err %v), want true", canInsert, err)
	}
}

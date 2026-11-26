package postgres_test

import (
	"context"
	"errors"
	"slices"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// createRole은 역할을 만들고, 테스트가 끝나면 지웁니다. 역할은 cluster 전체라 이름에 테스트별 접미사를 붙여 씁니다.
// 구성원 관계는 DB마다 따로 있어, 지우기 전에 구성원 관계와 권한을 먼저 거둡니다.
func createRole(t *testing.T, pool *pgxpool.Pool, name, attribute string) {
	t.Helper()
	quoted := pgx.Identifier{name}.Sanitize()
	if _, err := pool.Exec(context.Background(), "CREATE ROLE "+quoted+" "+attribute); err != nil {
		t.Fatalf("역할 %s 만들기: %v", name, err)
	}
	t.Cleanup(func() {
		ctx := context.Background()
		_, _ = pool.Exec(ctx, "REVOKE "+pgx.Identifier{postgres.OpsRole}.Sanitize()+" FROM "+quoted)
		_, _ = pool.Exec(ctx, "DROP ROLE IF EXISTS "+quoted)
	})
}

func isOpsMember(t *testing.T, pool *pgxpool.Pool, name string) bool {
	t.Helper()
	var member bool
	if err := pool.QueryRow(context.Background(), `SELECT pg_has_role($1, $2, 'MEMBER')`, name, postgres.OpsRole).Scan(&member); err != nil {
		t.Fatalf("%s 소속 확인: %v", name, err)
	}
	return member
}

// 사람 IAM 사용자(로그인 가능, 이름에 @, .iam으로 끝나지 않음)만 운영자 역할에 넣고, 이미 구성원이면 목록에 넣지 않습니다.
func TestGrantOpsRole_OnlyHumanIAMUsers(t *testing.T) {
	ctx := context.Background()
	dbtest.LockCluster(t)
	pool := dbtest.New(t)
	suffix := uuid.NewString()[:8]
	human := "op-" + suffix + "@example.com"
	service := "server-" + suffix + "@proj.iam"
	noLogin := "nologin-" + suffix + "@example.com"
	createRole(t, pool, human, "LOGIN")
	createRole(t, pool, service, "LOGIN")
	createRole(t, pool, noLogin, "NOLOGIN")

	// 다른 테스트가 같은 cluster에 만든 사람 역할이 섞일 수 있어, 이 테스트의 역할이 들어갔는지로 확인합니다.
	granted, err := postgres.GrantOpsRole(ctx, pool)
	if err != nil {
		t.Fatalf("GrantOpsRole: %v", err)
	}
	if !slices.Contains(granted, human) {
		t.Errorf("GrantOpsRole = %v, want %s 포함", granted, human)
	}
	if slices.Contains(granted, service) || slices.Contains(granted, noLogin) {
		t.Errorf("GrantOpsRole = %v, 서비스 계정이나 로그인 불가 역할이 들어갔습니다", granted)
	}
	if !isOpsMember(t, pool, human) {
		t.Errorf("%s가 %s 구성원이 아닙니다", human, postgres.OpsRole)
	}
	if isOpsMember(t, pool, service) || isOpsMember(t, pool, noLogin) {
		t.Errorf("서비스 계정이나 로그인 불가 역할이 %s 구성원입니다", postgres.OpsRole)
	}

	again, err := postgres.GrantOpsRole(ctx, pool)
	if err != nil {
		t.Fatalf("두 번째 GrantOpsRole: %v", err)
	}
	if slices.Contains(again, human) {
		t.Errorf("이미 구성원인 %s가 다시 목록에 들어갔습니다: %v", human, again)
	}
}

// 운영자 역할은 운영 명령이 읽지 않는 민감 칸(제공자 subject, Apple 토큰, 알림 token, 출생 정보 해시)을 읽지 못합니다.
func TestOpsRole_SensitiveColumnsHidden(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, c := range []struct{ table, column string }{
		{"auth_identities", "subject"},
		{"auth_identities", "apple_refresh_token"},
		{"auth_identities", "apple_token_key_id"},
		{"devices", "fcm_token"},
		{"devices", "token_hash"},
		{"profiles", "birth_hash"},
		{"profiles", "notify_time"},
	} {
		var canRead bool
		if err := pool.QueryRow(ctx, `SELECT has_column_privilege($1, $2, $3, 'SELECT')`, postgres.OpsRole, c.table, c.column).Scan(&canRead); err != nil {
			t.Fatalf("%s.%s 권한 확인: %v", c.table, c.column, err)
		}
		if canRead {
			t.Errorf("%s가 %s.%s를 읽을 수 있습니다", postgres.OpsRole, c.table, c.column)
		}
	}
	for _, statement := range []string{
		`SELECT subject FROM auth_identities`,
		`SELECT * FROM devices`,
		`SELECT birth_hash FROM profiles`,
	} {
		err := asRole(t, pool, postgres.OpsRole, statement)
		var pgErr *pgconn.PgError
		if !errors.As(err, &pgErr) || pgErr.Code != insufficientPrivilege {
			t.Errorf("%s: 권한 오류(%s)를 기대했지만 %v", statement, insufficientPrivilege, err)
		}
	}
	if err := asRole(t, pool, postgres.OpsRole, `SELECT provider, created_at FROM auth_identities ORDER BY created_at, id`); err != nil {
		t.Errorf("auth_identities 허용 칸 SELECT: %v", err)
	}
}

// 운영자 역할은 읽는 표(일부는 칸 단위) SELECT, 감사 INSERT와 SELECT, 부여 INSERT와 회수(revoked_at),
// 계정 행 잠금용 accounts UPDATE(updated_at)만 할 수 있습니다.
func TestOpsRole_Privileges(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	accountID := uuid.Must(uuid.NewV7())
	if _, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', now())`, accountID); err != nil {
		t.Fatalf("계정 INSERT: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'operator', 'ref-1', now(), now() + interval '1 day')`, accountID); err != nil {
		t.Fatalf("부여 INSERT: %v", err)
	}
	if _, err := pool.Exec(ctx, insertOpsAudit, uuid.Must(uuid.NewV7()), "0 seconds", "grant", nil); err != nil {
		t.Fatalf("감사 INSERT: %v", err)
	}

	allowed := []string{
		`SELECT 1 FROM diaries`,
		`SELECT 1 FROM accounts FOR SHARE`,
		// 운영자 부여가 계정 행을 FOR SHARE로 잠그려면 accounts의 UPDATE 권한이 한 칸 필요합니다(migration 00029).
		`UPDATE accounts SET updated_at = updated_at WHERE false`,
		`INSERT INTO ops_audit (id, at, actor, channel, action, reason, target) VALUES (gen_random_uuid(), now(), 'op@example.com', 'cli', 'grant', '사유', '{}')`,
		`INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
			VALUES ('` + accountID.String() + `', 'insight', 'operator', 'ref-2', now(), now() + interval '1 day')`,
		`UPDATE entitlement_grants SET revoked_at = now()`,
	}
	for _, statement := range allowed {
		if err := asRole(t, pool, postgres.OpsRole, statement); err != nil {
			t.Errorf("%s: %v", statement, err)
		}
	}

	denied := []string{
		`DELETE FROM ops_audit`,
		`UPDATE ops_audit SET reason = 'x'`,
		`UPDATE entitlement_grants SET expires_at = now() + interval '2 days'`,
		`INSERT INTO diaries (id, account_id, date, body) VALUES (gen_random_uuid(), '` + accountID.String() + `', current_date, 'x')`,
		`UPDATE accounts SET status = 'active'`,
	}
	for _, statement := range denied {
		err := asRole(t, pool, postgres.OpsRole, statement)
		var pgErr *pgconn.PgError
		if !errors.As(err, &pgErr) || pgErr.Code != insufficientPrivilege {
			t.Errorf("%s: 권한 오류(%s)를 기대했지만 %v", statement, insufficientPrivilege, err)
		}
	}
}

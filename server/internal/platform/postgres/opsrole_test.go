package postgres_test

import (
	"context"
	"errors"
	"strings"
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

// GrantOpsUser는 지정한 DB 사용자만 운영자 역할에 넣고, 다시 불러도 성공합니다. 빈 이름은 거절합니다.
func TestGrantOpsUser(t *testing.T) {
	ctx := context.Background()
	dbtest.LockCluster(t)
	pool := dbtest.New(t)
	suffix := uuid.NewString()[:8]
	target := "ops-" + suffix
	other := "other-" + suffix
	createRole(t, pool, target, "LOGIN")
	createRole(t, pool, other, "LOGIN")

	for i := range 2 {
		if err := postgres.GrantOpsUser(ctx, pool, target); err != nil {
			t.Fatalf("%d번째 GrantOpsUser: %v", i+1, err)
		}
	}
	if !isOpsMember(t, pool, target) {
		t.Errorf("%s가 %s 구성원이 아닙니다", target, postgres.OpsRole)
	}
	if isOpsMember(t, pool, other) {
		t.Errorf("지정하지 않은 %s가 %s 구성원입니다", other, postgres.OpsRole)
	}
	if err := postgres.GrantOpsUser(ctx, pool, ""); err == nil {
		t.Error("빈 이름에 GrantOpsUser가 성공했습니다")
	}
}

func grant(t *testing.T, pool *pgxpool.Pool, role, member string) {
	t.Helper()
	statement := "GRANT " + pgx.Identifier{role}.Sanitize() + " TO " + pgx.Identifier{member}.Sanitize()
	if _, err := pool.Exec(context.Background(), statement); err != nil {
		t.Fatalf("%s 구성원 지정: %v", role, err)
	}
}

// 런타임이 ops 구성원, ops가 app 구성원, ops 밖의 다른 ops 구성원은 각각 오류이고 정상이면 nil입니다.
func TestCheckRoleSeparation(t *testing.T) {
	ctx := context.Background()
	dbtest.LockCluster(t)
	pool := dbtest.New(t)
	suffix := uuid.NewString()[:8]
	runtimeUser, opsUser, extra := "rt-"+suffix, "ops-"+suffix, "extra-"+suffix
	for _, name := range []string{runtimeUser, opsUser, extra} {
		createRole(t, pool, name, "LOGIN")
	}
	t.Cleanup(func() {
		for _, name := range []string{runtimeUser, opsUser, extra} {
			_, _ = pool.Exec(context.Background(), "REVOKE "+postgres.AppRole+" FROM "+pgx.Identifier{name}.Sanitize())
		}
	})
	// 같은 cluster의 다른 DB에 남은 구성원이 섞이지 않도록, 이 테스트가 시작할 때 ops 구성원이 없어야 합니다.
	var existing int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM pg_auth_members WHERE roleid = $1::regrole`, postgres.OpsRole).Scan(&existing); err != nil || existing != 0 {
		t.Skipf("cluster에 %s 구성원이 이미 %d명 있습니다(err %v)", postgres.OpsRole, existing, err)
	}

	grant(t, pool, postgres.OpsRole, opsUser)
	grant(t, pool, postgres.AppRole, runtimeUser)
	if err := postgres.CheckRoleSeparation(ctx, pool, runtimeUser, opsUser); err != nil {
		t.Fatalf("정상 구성: %v", err)
	}

	grant(t, pool, postgres.OpsRole, extra)
	err := postgres.CheckRoleSeparation(ctx, pool, runtimeUser, opsUser)
	if !errors.Is(err, postgres.ErrUnexpectedOpsMember) {
		t.Errorf("그 밖의 ops 구성원: err = %v, want ErrUnexpectedOpsMember", err)
	} else if strings.Contains(err.Error(), extra) {
		t.Errorf("오류 문구에 구성원 이름이 들어갔습니다: %v", err)
	}
	if _, err := pool.Exec(ctx, "REVOKE "+postgres.OpsRole+" FROM "+pgx.Identifier{extra}.Sanitize()); err != nil {
		t.Fatalf("REVOKE: %v", err)
	}

	grant(t, pool, postgres.AppRole, opsUser)
	if err := postgres.CheckRoleSeparation(ctx, pool, runtimeUser, opsUser); !errors.Is(err, postgres.ErrOpsInAppRole) {
		t.Errorf("ops가 app 구성원: err = %v, want ErrOpsInAppRole", err)
	}
	if _, err := pool.Exec(ctx, "REVOKE "+postgres.AppRole+" FROM "+pgx.Identifier{opsUser}.Sanitize()); err != nil {
		t.Fatalf("REVOKE: %v", err)
	}

	grant(t, pool, postgres.OpsRole, runtimeUser)
	if err := postgres.CheckRoleSeparation(ctx, pool, runtimeUser, opsUser); !errors.Is(err, postgres.ErrRuntimeInOpsRole) {
		t.Errorf("런타임이 ops 구성원: err = %v, want ErrRuntimeInOpsRole", err)
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
		`INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, reason, target) VALUES (gen_random_uuid(), now(), 'op@example.com', 'sub-1', 'ops_api', 'grant', '사유', '{}')`,
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

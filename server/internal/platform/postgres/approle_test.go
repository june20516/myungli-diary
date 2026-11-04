package postgres_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const insufficientPrivilege = "42501"

// newRuntimeRole은 로그인 역할 하나를 만들어 AppRole 구성원으로 두고 그 이름을 돌려줍니다. 역할은 cluster 전체라 이름에 난수를 붙입니다.
func newRuntimeRole(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	ctx := context.Background()
	name := "runtime_" + uuid.NewString()[:8]
	if _, err := pool.Exec(ctx, "CREATE ROLE "+pgx.Identifier{name}.Sanitize()+" LOGIN"); err != nil {
		t.Fatalf("역할 만들기: %v", err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), "DROP ROLE IF EXISTS "+pgx.Identifier{name}.Sanitize())
	})
	if err := postgres.GrantAppRole(ctx, pool, name); err != nil {
		t.Fatalf("GrantAppRole: %v", err)
	}
	// 이미 구성원이어도 오류가 아닙니다(배포마다 migrate가 부름).
	if err := postgres.GrantAppRole(ctx, pool, name); err != nil {
		t.Fatalf("두 번째 GrantAppRole: %v", err)
	}
	return name
}

// asRole은 role로 바꾼 트랜잭션 안에서 statement를 실행하고 오류를 돌려줍니다. 트랜잭션은 늘 되돌립니다.
func asRole(t *testing.T, pool *pgxpool.Pool, role, statement string, args ...any) error {
	t.Helper()
	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("트랜잭션 시작: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, "SET LOCAL ROLE "+pgx.Identifier{role}.Sanitize()); err != nil {
		t.Fatalf("SET ROLE: %v", err)
	}
	_, err = tx.Exec(ctx, statement, args...)
	return err
}

// AppRole 구성원(런타임)은 표를 읽고 쓰지만, 표를 만들거나 바꾸거나 지우지 못하고 trigger를 끄지 못합니다(S137).
func TestAppRole_RuntimeCanReadWriteButNotChangeSchema(t *testing.T) {
	pool := dbtest.New(t)
	role := newRuntimeRole(t, pool)
	id := uuid.Must(uuid.NewV7()).String()

	if err := asRole(t, pool, role, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)`, id, time.Now()); err != nil {
		t.Fatalf("INSERT: %v", err)
	}
	for _, statement := range []string{
		`SELECT count(*) FROM accounts`,
		`UPDATE accounts SET last_active_at = now() WHERE false`,
		`DELETE FROM rate_limits WHERE false`,
	} {
		if err := asRole(t, pool, role, statement); err != nil {
			t.Errorf("%s: %v", statement, err)
		}
	}

	for _, statement := range []string{
		`CREATE TABLE runtime_should_not_create (id int)`,
		`DROP TABLE rate_limits`,
		`ALTER TABLE accounts ADD COLUMN runtime_extra int`,
		`ALTER TABLE accounts DISABLE TRIGGER ALL`,
		`TRUNCATE rate_limits`,
		`CREATE ROLE runtime_should_not_create_role`,
	} {
		err := asRole(t, pool, role, statement)
		var pgErr *pgconn.PgError
		if !errors.As(err, &pgErr) || pgErr.Code != insufficientPrivilege {
			t.Errorf("%s: 권한 오류(%s)를 기대했지만 %v", statement, insufficientPrivilege, err)
		}
	}
}

// migration 뒤에 만든 표에도 AppRole 권한이 기본으로 갑니다(ALTER DEFAULT PRIVILEGES).
func TestAppRole_DefaultPrivilegesCoverNewTables(t *testing.T) {
	pool := dbtest.New(t)
	role := newRuntimeRole(t, pool)
	table := fmt.Sprintf("later_table_%s", uuid.NewString()[:8])
	if _, err := pool.Exec(context.Background(), "CREATE TABLE "+pgx.Identifier{table}.Sanitize()+" (id bigserial PRIMARY KEY, v int)"); err != nil {
		t.Fatalf("표 만들기: %v", err)
	}

	if err := asRole(t, pool, role, "INSERT INTO "+pgx.Identifier{table}.Sanitize()+" (v) VALUES (1)"); err != nil {
		t.Errorf("새 표 INSERT(sequence 포함): %v", err)
	}
}

// 이름이 비어 있으면 오류입니다.
func TestGrantAppRole_RequiresMember(t *testing.T) {
	if err := postgres.GrantAppRole(context.Background(), dbtest.New(t), ""); err == nil {
		t.Error("빈 이름에 오류가 없습니다")
	}
}

// cloudsqlsuperuser 구성원이면 ErrRuntimeHasSuperuser이고, 아니거나 그 역할이 없는 DB면 nil입니다.
func TestCheckRuntimeNotSuperuser(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	role := newRuntimeRole(t, pool)

	// 테스트 DB에는 cloudsqlsuperuser가 없을 수 있습니다(다른 테스트가 만들었을 수도 있음).
	if err := postgres.CheckRuntimeNotSuperuser(ctx, pool, role); err != nil {
		t.Fatalf("구성원이 아닌데 오류: %v", err)
	}

	if _, err := pool.Exec(ctx, `DO $$ BEGIN CREATE ROLE cloudsqlsuperuser NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$`); err != nil {
		t.Fatalf("cloudsqlsuperuser 만들기: %v", err)
	}
	if _, err := pool.Exec(ctx, "GRANT cloudsqlsuperuser TO "+pgx.Identifier{role}.Sanitize()); err != nil {
		t.Fatalf("GRANT: %v", err)
	}
	if err := postgres.CheckRuntimeNotSuperuser(ctx, pool, role); !errors.Is(err, postgres.ErrRuntimeHasSuperuser) {
		t.Fatalf("구성원인데 오류 = %v, want ErrRuntimeHasSuperuser", err)
	}
}

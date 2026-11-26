package cli

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/seed"
)

func runCLI(t *testing.T, args ...string) (int, string) {
	t.Helper()
	code, _, stderr := runCLIWithEnv(t, nil, args...)
	return code, stderr
}

// runCLIWithEnv는 환경 변수를 주입해 실행하고 종료 코드, stdout, stderr를 돌려줍니다.
func runCLIWithEnv(t *testing.T, env map[string]string, args ...string) (int, string, string) {
	t.Helper()
	var stdout, stderr bytes.Buffer
	getenv := func(key string) string { return env[key] }
	code := Run(context.Background(), args, getenv, &stdout, &stderr)
	return code, stdout.String(), stderr.String()
}

func TestRun_NoArgs_PrintsUsageAndExits2(t *testing.T) {
	code, stderr := runCLI(t)
	if code != 2 {
		t.Errorf("종료 코드 = %d, want 2", code)
	}
	if !strings.Contains(stderr, "usage:") {
		t.Errorf("stderr에 usage: 없음: %q", stderr)
	}
}

func TestRun_UnknownCommand_Exits2(t *testing.T) {
	code, stderr := runCLI(t, "nope")
	if code != 2 {
		t.Errorf("종료 코드 = %d, want 2", code)
	}
	if !strings.Contains(stderr, `unknown command "nope"`) {
		t.Errorf("stderr에 unknown command 없음: %q", stderr)
	}
}

func TestRun_JobWithoutName_Exits2(t *testing.T) {
	if code, _ := runCLI(t, "job"); code != 2 {
		t.Errorf("종료 코드 = %d, want 2", code)
	}
}

func TestRun_UnknownJob_Exits2(t *testing.T) {
	if code, _ := runCLI(t, "job", "x"); code != 2 {
		t.Errorf("종료 코드 = %d, want 2", code)
	}
}

func TestRun_MigrateWithoutDirection_Exits2(t *testing.T) {
	if code, _ := runCLI(t, "migrate"); code != 2 {
		t.Errorf("종료 코드 = %d, want 2", code)
	}
}

func TestRun_MigrateWithoutDatabaseURL_Exits1(t *testing.T) {
	code, stderr := runCLI(t, "migrate", "up")
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr, "DATABASE_URL") {
		t.Errorf("stderr에 DATABASE_URL 안내 없음: %q", stderr)
	}
}

func TestRun_MigrateUnreachableDatabase_FailsFastWithCauseWithoutPassword(t *testing.T) {
	env := map[string]string{"DATABASE_URL": "postgres://u:s3cr3t-pw@127.0.0.1:1/x"} //nolint:gosec // 비밀번호가 로그에 새지 않는지 확인하려는 가짜 값입니다

	start := time.Now()
	code, _, stderr := runCLIWithEnv(t, env, "migrate", "up")
	elapsed := time.Since(start)

	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if elapsed > 6*time.Second {
		t.Errorf("종료까지 %v 걸렸습니다, want 6초 이내", elapsed)
	}
	if !strings.Contains(stderr, "DB 연결") || !strings.Contains(stderr, "127.0.0.1:1") {
		t.Errorf("stderr 로그에 연결 실패 원인이 없습니다: %q", stderr)
	}
	if strings.Contains(stderr, "s3cr3t-pw") {
		t.Errorf("로그에 비밀번호가 포함됨: %q", stderr)
	}
}

// migrationFileCount는 migration 디렉터리의 파일 수입니다. migration을 더하면 함께 올립니다.
const migrationFileCount = 29

func TestRun_MigrateDownUp_AppliesToDatabase(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	env := map[string]string{"DATABASE_URL": pool.Config().ConnString()}

	for _, direction := range []string{"down", "up"} {
		if code, _, stderr := runCLIWithEnv(t, env, "migrate", direction); code != 0 {
			t.Fatalf("migrate %s 종료 코드 = %d, stderr = %q", direction, code, stderr)
		}
	}

	statuses, err := postgres.Status(ctx, pool)
	if err != nil {
		t.Fatalf("Status: %v", err)
	}
	if len(statuses) != migrationFileCount {
		t.Fatalf("migrate up 뒤 status = %+v, want migration %d개", statuses, migrationFileCount)
	}
	for _, status := range statuses {
		if !status.Applied {
			t.Errorf("migrate up 뒤 status = %+v, want 모두 applied", statuses)
			break
		}
	}
}

// createLoginRole은 테스트가 끝나면 지우는 로그인 역할을 만듭니다. 구성원 관계는 지우기 전에 거둡니다.
func createLoginRole(t *testing.T, pool *pgxpool.Pool, prefix string) string {
	t.Helper()
	name := prefix + strings.ReplaceAll(uuid.NewString()[:8], "-", "")
	quoted := pgx.Identifier{name}.Sanitize()
	if _, err := pool.Exec(context.Background(), "CREATE ROLE "+quoted+" LOGIN"); err != nil {
		t.Fatalf("역할 만들기: %v", err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), "DROP ROLE IF EXISTS "+quoted) })
	return name
}

func hasRoleMember(t *testing.T, pool *pgxpool.Pool, member, role string) bool {
	t.Helper()
	var isMember bool
	if err := pool.QueryRow(context.Background(), `SELECT pg_has_role($1, $2, 'MEMBER')`, member, role).Scan(&isMember); err != nil {
		t.Fatalf("%s 소속 확인: %v", member, err)
	}
	return isMember
}

// DB_RUNTIME_USER와 DB_OPS_USER가 있으면 migrate up 뒤 각각 읽기와 쓰기 권한 묶음(myungli_app, S137),
// 운영자 권한 묶음(myungli_ops, #1321)의 구성원으로 둡니다. 없는 사용자면 실패해 배포의 migrate 단계가 멈춥니다.
func TestRunMigrate_OpsUser(t *testing.T) {
	dbtest.LockCluster(t)
	pool := dbtest.New(t)
	runtimeUser := createLoginRole(t, pool, "runtime_cli_")
	opsUser := createLoginRole(t, pool, "ops_user_cli_")
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), "REVOKE "+postgres.OpsRole+" FROM "+pgx.Identifier{opsUser}.Sanitize())
		_, _ = pool.Exec(context.Background(), "REVOKE "+postgres.AppRole+" FROM "+pgx.Identifier{runtimeUser}.Sanitize())
	})
	env := map[string]string{"DATABASE_URL": pool.Config().ConnString(), "DB_RUNTIME_USER": runtimeUser, "DB_OPS_USER": opsUser}

	code, _, stderr := runCLIWithEnv(t, env, "migrate", "up")
	if code != 0 {
		t.Fatalf("migrate up 종료 코드 = %d, stderr = %q", code, stderr)
	}
	if !hasRoleMember(t, pool, runtimeUser, postgres.AppRole) {
		t.Errorf("런타임 사용자가 %s 구성원이 아닙니다", postgres.AppRole)
	}
	if !hasRoleMember(t, pool, opsUser, postgres.OpsRole) {
		t.Errorf("운영 API 사용자가 %s 구성원이 아닙니다", postgres.OpsRole)
	}
	if hasRoleMember(t, pool, runtimeUser, postgres.OpsRole) || hasRoleMember(t, pool, opsUser, postgres.AppRole) {
		t.Error("두 사용자의 권한이 섞였습니다")
	}
	for _, name := range []string{runtimeUser, opsUser} {
		if strings.Contains(stderr, name) {
			t.Errorf("로그에 DB 사용자 이름이 남았습니다: %q", stderr)
		}
	}

	// 다시 돌려도 성공합니다.
	if code, _, stderr := runCLIWithEnv(t, env, "migrate", "up"); code != 0 {
		t.Errorf("두 번째 migrate up 종료 코드 = %d, stderr = %q", code, stderr)
	}

	// 없는 사용자는 배포를 멈춥니다(오류에 이름이 없어야 합니다).
	missing := "no_such_user_" + strings.ReplaceAll(uuid.NewString()[:8], "-", "")
	for key, other := range map[string]string{"DB_RUNTIME_USER": "DB_OPS_USER", "DB_OPS_USER": "DB_RUNTIME_USER"} {
		bad := map[string]string{"DATABASE_URL": env["DATABASE_URL"], key: missing, other: env[other]}
		code, _, stderr := runCLIWithEnv(t, bad, "migrate", "up")
		if code == 0 {
			t.Errorf("%s가 없는 사용자인데 migrate up이 성공했습니다", key)
		}
		if strings.Contains(stderr, missing) {
			t.Errorf("%s 실패 로그에 사용자 이름이 남았습니다: %q", key, stderr)
		}
	}
}

// 둘 중 하나만 있으면 설정 오류이고, 어느 역할도 지정하지 않습니다.
func TestRunMigrate_OpsUserRequiresBoth(t *testing.T) {
	pool := dbtest.New(t)
	user := createLoginRole(t, pool, "only_one_")
	for _, key := range []string{"DB_RUNTIME_USER", "DB_OPS_USER"} {
		env := map[string]string{"DATABASE_URL": pool.Config().ConnString(), key: user}
		code, _, stderr := runCLIWithEnv(t, env, "migrate", "up")
		if code == 0 {
			t.Errorf("%s만 있는데 migrate up이 성공했습니다", key)
		}
		if strings.Contains(stderr, user) {
			t.Errorf("로그에 사용자 이름이 남았습니다: %q", stderr)
		}
	}
	if hasRoleMember(t, pool, user, postgres.AppRole) || hasRoleMember(t, pool, user, postgres.OpsRole) {
		t.Error("설정 오류인데 역할이 지정됐습니다")
	}
}

// local과 테스트는 둘 다 비어도 되고, 배포 환경(staging, prod)은 둘 다 있어야 합니다.
func TestRunMigrate_OpsUserOnlyRequiredInDeployedEnv(t *testing.T) {
	pool := dbtest.New(t)
	for _, appEnv := range []string{"", "local"} {
		env := map[string]string{"DATABASE_URL": pool.Config().ConnString(), "APP_ENV": appEnv}
		if code, _, stderr := runCLIWithEnv(t, env, "migrate", "up"); code != 0 {
			t.Errorf("APP_ENV=%q migrate up 종료 코드 = %d, stderr = %q", appEnv, code, stderr)
		}
	}
	env := map[string]string{"DATABASE_URL": pool.Config().ConnString(), "APP_ENV": "staging"}
	if code, _, _ := runCLIWithEnv(t, env, "migrate", "up"); code == 0 {
		t.Error("staging에서 두 사용자 없이 migrate up이 성공했습니다")
	}
}

func TestRun_MigrateStatus_WritesTableToStdout(t *testing.T) {
	pool := dbtest.New(t)
	env := map[string]string{"DATABASE_URL": pool.Config().ConnString()}

	code, stdout, stderr := runCLIWithEnv(t, env, "migrate", "status")
	if code != 0 {
		t.Fatalf("종료 코드 = %d, stderr = %q", code, stderr)
	}
	if !strings.Contains(stdout, "Applied") || !strings.Contains(stdout, "00001_init.sql") {
		t.Errorf("stdout에 상태 표가 없습니다: %q", stdout)
	}
	if strings.Contains(stderr, "Applied") {
		t.Errorf("상태 표가 stderr로 갔습니다: %q", stderr)
	}
}

func TestRun_MigrateDownWithNothingApplied_Exits1WithClearLog(t *testing.T) {
	pool := dbtest.New(t)
	env := map[string]string{"DATABASE_URL": pool.Config().ConnString()}

	// migration 파일을 다 되돌려야 적용된 것이 없어집니다.
	for i := 1; i <= migrationFileCount; i++ {
		if code, _, stderr := runCLIWithEnv(t, env, "migrate", "down"); code != 0 {
			t.Fatalf("%d번째 down 종료 코드 = %d, stderr = %q", i, code, stderr)
		}
	}
	code, _, stderr := runCLIWithEnv(t, env, "migrate", "down")
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr, "되돌릴 migration이 없습니다") {
		t.Errorf("stderr에 명확한 안내가 없습니다: %q", stderr)
	}
}

func TestRun_ExtraArgs_Exits2(t *testing.T) {
	for _, args := range [][]string{{"serve", "x"}, {"seed", "x"}} {
		code, stderr := runCLI(t, args...)
		if code != 2 {
			t.Errorf("%v: 종료 코드 = %d, want 2", args, code)
		}
		if want := "usage: server " + args[0]; strings.TrimSpace(stderr) != want {
			t.Errorf("%v: stderr = %q, want %q", args, stderr, want)
		}
	}
}

func TestRunSeed_AppliesEmbeddedSeed(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	env := map[string]string{"DATABASE_URL": pool.Config().ConnString()}

	embedded, err := seed.Load()
	if err != nil {
		t.Fatalf("seed.Load: %v", err)
	}
	// 두 번 돌려도 성공해야 합니다(배포마다 돕니다).
	for i := 0; i < 2; i++ {
		if code, _, stderr := runCLIWithEnv(t, env, "seed"); code != 0 {
			t.Fatalf("%d번째 seed 종료 코드 = %d, stderr = %q", i+1, code, stderr)
		}
	}

	version, err := content.NewStore(pool, clock.System{}, slog.New(slog.DiscardHandler)).Active(ctx)
	if err != nil {
		t.Fatalf("Active: %v", err)
	}
	if version != embedded.Version {
		t.Errorf("활성 버전 = %q, want %q", version, embedded.Version)
	}
	var count int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM content_templates WHERE seed_version = $1", version).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != len(embedded.Templates) {
		t.Errorf("문장 틀 수 = %d, want %d", count, len(embedded.Templates))
	}
}

func TestRunSeed_WithoutDatabaseURL_Exits1(t *testing.T) {
	code, stderr := runCLI(t, "seed")
	if code != 1 || !strings.Contains(stderr, "DATABASE_URL") {
		t.Errorf("종료 코드 = %d, stderr = %q, want 1과 DATABASE_URL 안내", code, stderr)
	}
}

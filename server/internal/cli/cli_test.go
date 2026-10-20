package cli

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"testing"
	"time"

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

func TestRun_NotImplementedJob_Exits1(t *testing.T) {
	code, stderr := runCLI(t, "job", "notify")
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr, "not implemented") {
		t.Errorf("stderr에 not implemented 없음: %q", stderr)
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
const migrationFileCount = 9

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

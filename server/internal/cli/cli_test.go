package cli

import (
	"bytes"
	"context"
	"strings"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
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
	if len(statuses) != 2 || !statuses[0].Applied || !statuses[1].Applied {
		t.Errorf("migrate up 뒤 status = %+v, want 00001, 00002 applied", statuses)
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

	// migration 파일이 둘이므로 둘 다 되돌려야 적용된 것이 없어집니다.
	for i := 1; i <= 2; i++ {
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

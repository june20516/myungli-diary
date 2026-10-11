package cli

import (
	"bytes"
	"context"
	"strings"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

func runCLI(t *testing.T, args ...string) (int, string) {
	t.Helper()
	var stderr bytes.Buffer
	getenv := func(string) string { return "" }
	code := Run(context.Background(), args, getenv, &stderr)
	return code, stderr.String()
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

func TestRun_MigrateUnreachableDatabase_Exits1WithoutLeakingPassword(t *testing.T) {
	var stderr bytes.Buffer
	getenv := func(key string) string {
		if key == "DATABASE_URL" {
			return "postgres://u:s3cr3t-pw@127.0.0.1:1/x"
		}
		return ""
	}
	code := Run(context.Background(), []string{"migrate", "status"}, getenv, &stderr)
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if stderr.Len() == 0 {
		t.Error("실패 원인이 로그로 남지 않았습니다")
	}
	if strings.Contains(stderr.String(), "s3cr3t-pw") {
		t.Errorf("로그에 비밀번호가 포함됨: %q", stderr.String())
	}
}

func TestRun_MigrateDownUp_AppliesToDatabase(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	getenv := func(key string) string {
		if key == "DATABASE_URL" {
			return pool.Config().ConnString()
		}
		return ""
	}

	for _, direction := range []string{"down", "up", "status"} {
		var stderr bytes.Buffer
		if code := Run(ctx, []string{"migrate", direction}, getenv, &stderr); code != 0 {
			t.Fatalf("migrate %s 종료 코드 = %d, stderr = %q", direction, code, stderr.String())
		}
	}

	statuses, err := postgres.Status(ctx, pool)
	if err != nil {
		t.Fatalf("Status: %v", err)
	}
	if len(statuses) != 1 || !statuses[0].Applied {
		t.Errorf("migrate up 뒤 status = %+v, want 00001 applied", statuses)
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

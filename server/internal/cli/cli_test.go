package cli

import (
	"bytes"
	"context"
	"strings"
	"testing"
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

// 유효한 migrate 입력은 아직 동작이 없어 ErrNotImplemented로 exit 1이 됩니다.
// Task 5에서 실제 마이그레이션이 연결되면 이 테스트도 그에 맞게 바뀝니다.
func TestRun_MigrateUp_NotImplementedYet_Exits1(t *testing.T) {
	code, stderr := runCLI(t, "migrate", "up")
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr, "not implemented") {
		t.Errorf("stderr에 not implemented 없음: %q", stderr)
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

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

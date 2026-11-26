package opsapi_test

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/opsapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

func TestAllowlist_Normalizes(t *testing.T) {
	list := opsapi.ParseAllowlist(" Op@Example.com ,x@y.z")

	for _, email := range []string{"op@example.com", "OP@EXAMPLE.COM", " x@y.z "} {
		if !list.Allows(email) {
			t.Errorf("Allows(%q) = false, want true", email)
		}
	}
	if list.Allows("other@example.com") {
		t.Error("목록에 없는 메일을 허용했습니다")
	}
}

func TestAllowlist_EmptyRejectsEveryone(t *testing.T) {
	for _, raw := range []string{"", "  ", ",, ,"} {
		list := opsapi.ParseAllowlist(raw)
		if list.Allows("") || list.Allows("op@example.com") {
			t.Errorf("ParseAllowlist(%q)가 누군가를 허용했습니다", raw)
		}
	}
}

// writeOperators는 운영자 목록 파일을 씁니다(Secret 볼륨의 파일 대신).
func writeOperators(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("목록 파일 쓰기: %v", err)
	}
}

func allows(t *testing.T, source opsapi.OperatorSource, email string) (bool, error) {
	t.Helper()
	list, err := source.Operators(context.Background())
	return list.Allows(email), err
}

// 파일 목록은 TTL(1분) 동안 다시 읽지 않고, TTL이 지나면 새 내용을 읽습니다(운영자 빼기 반영).
func TestFileOperators_RereadsAfterTTL(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operators")
	writeOperators(t, path, " Op@Example.com ,b@example.com\n")
	clk := clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC))
	source := opsapi.NewFileOperators(path, clk)

	if ok, err := allows(t, source, "op@example.com"); err != nil || !ok {
		t.Fatalf("처음 읽기: ok=%v err=%v", ok, err)
	}
	writeOperators(t, path, "b@example.com")
	clk.Advance(opsapi.OperatorsTTL - time.Second)
	if ok, _ := allows(t, source, "op@example.com"); !ok {
		t.Error("TTL 안에서는 캐시한 목록을 씁니다")
	}
	clk.Advance(time.Second)
	if ok, err := allows(t, source, "op@example.com"); err != nil || ok {
		t.Errorf("TTL이 지나면 뺀 운영자를 거절해야 합니다: ok=%v err=%v", ok, err)
	}
	if ok, _ := allows(t, source, "b@example.com"); !ok {
		t.Error("남은 운영자는 허용합니다")
	}
}

// 파일을 읽지 못하면 마지막 목록을 쓰지 않고 오류(fail-closed)이고, 파일이 돌아오면 다시 읽습니다.
func TestFileOperators_FailClosed(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operators")
	writeOperators(t, path, "op@example.com")
	clk := clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC))
	source := opsapi.NewFileOperators(path, clk)
	if ok, err := allows(t, source, "op@example.com"); err != nil || !ok {
		t.Fatalf("처음 읽기: ok=%v err=%v", ok, err)
	}

	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	clk.Advance(opsapi.OperatorsTTL)
	ok, err := allows(t, source, "op@example.com")
	if !errors.Is(err, opsapi.ErrOperatorsUnavailable) || ok {
		t.Fatalf("파일 없음: ok=%v err=%v, want ErrOperatorsUnavailable", ok, err)
	}
	if strings.Contains(err.Error(), "op@example.com") {
		t.Errorf("오류에 메일이 들어갔습니다: %v", err)
	}
	// 실패는 캐시하지 않습니다. 같은 시각이어도 다음 호출이 다시 읽습니다.
	writeOperators(t, path, "op@example.com")
	if ok, err := allows(t, source, "op@example.com"); err != nil || !ok {
		t.Errorf("파일이 돌아온 뒤: ok=%v err=%v", ok, err)
	}
}

// 목록 파일이 64 KiB를 넘으면 읽지 않고 오류입니다.
func TestFileOperators_RejectsLargeFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operators")
	writeOperators(t, path, strings.Repeat("a", 64<<10+1))
	source := opsapi.NewFileOperators(path, clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC)))
	if _, err := allows(t, source, "a"); !errors.Is(err, opsapi.ErrOperatorsUnavailable) {
		t.Errorf("큰 파일: err = %v, want ErrOperatorsUnavailable", err)
	}
}

// 고정 목록(local의 OPS_OPERATORS)도 같은 원천으로 쓸 수 있습니다.
func TestAllowlist_IsOperatorSource(t *testing.T) {
	var source opsapi.OperatorSource = opsapi.ParseAllowlist("op@example.com")
	if ok, err := allows(t, source, "OP@example.com"); err != nil || !ok {
		t.Errorf("고정 목록: ok=%v err=%v", ok, err)
	}
}

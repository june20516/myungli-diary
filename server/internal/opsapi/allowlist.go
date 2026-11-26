package opsapi

import (
	"context"
	"errors"
	"io"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// Allowlist는 운영 명령을 실행할 수 있는 운영자 메일 집합입니다(Secret OPS_OPERATORS의 내용).
// 비어 있으면 누구도 허용하지 않습니다.
type Allowlist struct {
	emails map[string]struct{}
}

// ParseAllowlist는 쉼표로 구분한 메일 목록을 읽습니다.
// 각 항목은 앞뒤 공백을 지우고 소문자로 바꾸며, 빈 항목은 버립니다.
func ParseAllowlist(raw string) Allowlist {
	emails := make(map[string]struct{})
	for _, item := range strings.Split(raw, ",") {
		if email := normalizeEmail(item); email != "" {
			emails[email] = struct{}{}
		}
	}
	return Allowlist{emails: emails}
}

// Allows는 메일이 허용 목록에 있는지 돌려줍니다. 비교는 공백 제거와 소문자 기준입니다.
func (a Allowlist) Allows(email string) bool {
	normalized := normalizeEmail(email)
	if normalized == "" {
		return false
	}
	_, ok := a.emails[normalized]
	return ok
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// OperatorSource는 요청마다 지금의 운영자 허용 목록을 돌려줍니다.
// 목록을 읽지 못하면 오류를 돌려주고, 호출자는 마지막으로 읽은 목록으로 통과시키지 않고 거절합니다(fail-closed).
type OperatorSource interface {
	Operators(ctx context.Context) (Allowlist, error)
}

// Operators는 고정 목록을 그대로 돌려줍니다. local의 OPS_OPERATORS 환경 변수와 시험이 씁니다.
func (a Allowlist) Operators(context.Context) (Allowlist, error) {
	return a, nil
}

// ErrOperatorsUnavailable은 운영자 목록 파일을 읽지 못했다는 뜻입니다. 경로와 내용은 담지 않습니다.
var ErrOperatorsUnavailable = errors.New("운영자 목록을 읽을 수 없습니다")

// OperatorsTTL은 운영자 목록 파일을 다시 읽는 간격입니다. 운영자를 빼면 늦어도 이 시간 뒤에는 떠 있는 인스턴스도 거절합니다.
const OperatorsTTL = time.Minute

// maxOperatorsFileBytes는 운영자 목록 파일의 크기 상한입니다(Secret Manager 값 상한과 같은 64 KiB).
const maxOperatorsFileBytes = 64 << 10

// operatorsReadTimeout은 운영자 목록 파일 한 번 읽기의 상한입니다. Cloud Run은 볼륨의 secret을 읽을 때 Secret Manager에서
// 값을 가져오므로 읽기가 느려질 수 있습니다. 상한을 넘으면 기다리던 요청을 503으로 돌려보냅니다(fail-closed).
const operatorsReadTimeout = 5 * time.Second

// FileOperators는 운영자 목록 파일(Secret OPS_OPERATORS의 Cloud Run 볼륨 마운트, 버전 latest)을 TTL마다 다시 읽습니다.
// Cloud Run은 볼륨의 secret을 읽을 때마다 Secret Manager의 latest 값을 가져오므로, 새 버전을 넣으면
// 재배포 없이 다음 읽기에 반영됩니다(https://docs.cloud.google.com/run/docs/configuring/services/secrets).
// 읽기에 실패하면 캐시를 버리고 오류를 돌려주며, 실패는 캐시하지 않아 다음 요청이 다시 읽습니다.
//
// 잠금은 둘입니다. mu는 캐시 상태만 짧게 지키고 파일 읽기 동안 잡지 않습니다. refresh(크기 1 채널 세마포어)는 다시 읽기를
// 한 번에 하나로 묶어, TTL이 지난 순간 몰린 요청이 파일을 여러 번 읽지 않게 합니다(singleflight와 같은 효과).
// 캐시가 유효한 요청은 refresh를 기다리지 않습니다. TTL이 지난 뒤의 요청은 새 목록을 기다려야 하므로(옛 목록으로 통과시키지 않음)
// 세마포어 대기와 읽기 모두 요청 ctx를 따르고, 취소되면 ErrOperatorsUnavailable입니다(fail-closed).
// 캐시 무효화는 실제 읽기가 실패하거나 시간 초과일 때만 합니다. 요청 하나의 취소는 캐시를 건드리지 않습니다.
type FileOperators struct {
	path  string
	clock clock.Clock
	// read와 readTimeout은 시험이 바꿉니다.
	read        func(path string) (string, error)
	readTimeout time.Duration

	refresh chan struct{}

	mu       sync.Mutex
	cached   Allowlist
	loadedAt time.Time
	valid    bool
}

// NewFileOperators는 path의 운영자 목록을 TTL(OperatorsTTL)마다 다시 읽는 원천을 만듭니다.
func NewFileOperators(path string, clk clock.Clock) *FileOperators {
	return &FileOperators{
		path: path, clock: clk, read: readOperatorsFile, readTimeout: operatorsReadTimeout,
		refresh: make(chan struct{}, 1),
	}
}

// Operators는 TTL 안이면 캐시한 목록을, 아니면 파일을 다시 읽은 목록을 돌려줍니다.
// 시계가 뒤로 가면(loadedAt보다 이른 시각) TTL이 지난 것으로 보고 다시 읽습니다.
func (f *FileOperators) Operators(ctx context.Context) (Allowlist, error) {
	if list, ok := f.fresh(); ok {
		return list, nil
	}
	select {
	case f.refresh <- struct{}{}:
	case <-ctx.Done():
		return Allowlist{}, ErrOperatorsUnavailable
	}
	defer func() { <-f.refresh }()
	// 기다리는 동안 다른 요청이 다시 읽었으면 그 결과를 씁니다.
	if list, ok := f.fresh(); ok {
		return list, nil
	}
	raw, err := f.readWithTimeout(ctx)
	if errors.Is(err, errReadCanceled) {
		// 이 요청이 취소됐을 뿐이라 캐시는 그대로 둡니다(TTL이 지나 어차피 쓰이지 않음).
		return Allowlist{}, ErrOperatorsUnavailable
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if err != nil {
		f.cached, f.valid = Allowlist{}, false
		return Allowlist{}, err
	}
	f.cached, f.loadedAt, f.valid = ParseAllowlist(raw), f.clock.Now(), true
	return f.cached, nil
}

// fresh는 TTL 안의 캐시가 있으면 그것을 돌려줍니다.
func (f *FileOperators) fresh() (Allowlist, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	now := f.clock.Now()
	if f.valid && !now.Before(f.loadedAt) && now.Sub(f.loadedAt) < OperatorsTTL {
		return f.cached, true
	}
	return Allowlist{}, false
}

// errReadCanceled는 읽는 동안 요청 ctx가 취소됐다는 내부 표시입니다. 호출자는 ErrOperatorsUnavailable로 바꿔 돌려줍니다.
var errReadCanceled = errors.New("운영자 목록 읽기를 기다리던 요청이 취소됐습니다")

// readWithTimeout은 파일 읽기를 readTimeout 또는 ctx 취소까지만 기다립니다. 시간 초과는 ErrOperatorsUnavailable,
// ctx 취소는 errReadCanceled이고,
// 끝나지 않은 읽기는 버퍼 있는 채널에 결과를 남기고 끝나므로 goroutine이 묶이지 않습니다.
func (f *FileOperators) readWithTimeout(ctx context.Context) (string, error) {
	type result struct {
		raw string
		err error
	}
	done := make(chan result, 1)
	go func() {
		raw, err := f.read(f.path)
		done <- result{raw: raw, err: err}
	}()
	timer := time.NewTimer(f.readTimeout)
	defer timer.Stop()
	select {
	case r := <-done:
		return r.raw, r.err
	case <-timer.C:
		return "", ErrOperatorsUnavailable
	case <-ctx.Done():
		return "", errReadCanceled
	}
}

// readOperatorsFile은 목록 파일을 64 KiB까지 읽습니다. 넘거나 읽지 못하면 ErrOperatorsUnavailable입니다.
func readOperatorsFile(path string) (string, error) {
	file, err := os.Open(path) //nolint:gosec // 경로는 배포 설정(OPS_OPERATORS_FILE)이 정한 Secret 볼륨 파일입니다.
	if err != nil {
		return "", ErrOperatorsUnavailable
	}
	defer func() { _ = file.Close() }()
	raw, err := io.ReadAll(io.LimitReader(file, maxOperatorsFileBytes+1))
	if err != nil || len(raw) > maxOperatorsFileBytes {
		return "", ErrOperatorsUnavailable
	}
	return string(raw), nil
}

package engine_test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

func newTestVersions(fake *enginetest.Fake) *engine.Versions {
	return engine.NewVersions(fake, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func infoWith(rulesetVersion string) func() (*enginev1.InfoResponse, error) {
	return func() (*enginev1.InfoResponse, error) {
		return &enginev1.InfoResponse{EngineVersion: "test", RulesetVersion: rulesetVersion}, nil
	}
}

func TestVersions_UnknownBeforeFirstRefresh(t *testing.T) {
	v := newTestVersions(&enginetest.Fake{})

	_, err := v.Current()

	require.ErrorIs(t, err, engine.ErrVersionUnknown)
}

func TestVersions_RefreshUpdates(t *testing.T) {
	fake := &enginetest.Fake{Info: infoWith("rs-1")}
	v := newTestVersions(fake)

	require.NoError(t, v.Refresh(context.Background()))
	got, err := v.Current()
	require.NoError(t, err)
	require.Equal(t, "rs-1", got)

	fake.Info = infoWith("rs-2")
	require.NoError(t, v.Refresh(context.Background()))
	got, err = v.Current()
	require.NoError(t, err)
	require.Equal(t, "rs-2", got)
}

func TestVersions_FailureKeepsLastValue(t *testing.T) {
	fake := &enginetest.Fake{Info: infoWith("rs-1")}
	v := newTestVersions(fake)
	require.NoError(t, v.Refresh(context.Background()))

	fake.Info = func() (*enginev1.InfoResponse, error) { return nil, engine.ErrUnavailable }

	require.ErrorIs(t, v.Refresh(context.Background()), engine.ErrUnavailable)
	got, err := v.Current()
	require.NoError(t, err)
	require.Equal(t, "rs-1", got)
}

func TestVersions_EmptyRulesetVersionIsRejected(t *testing.T) {
	fake := &enginetest.Fake{Info: infoWith("")}
	v := newTestVersions(fake)

	require.Error(t, v.Refresh(context.Background()))
	_, err := v.Current()
	require.ErrorIs(t, err, engine.ErrVersionUnknown)

	fake.Info = infoWith("rs-1")
	require.NoError(t, v.Refresh(context.Background()))
	fake.Info = infoWith("")
	require.Error(t, v.Refresh(context.Background()))
	got, err := v.Current()
	require.NoError(t, err)
	require.Equal(t, "rs-1", got)
}

func TestVersions_RunStopsOnCancel(t *testing.T) {
	fake := &enginetest.Fake{}
	v := newTestVersions(fake)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	done := make(chan struct{})

	go func() {
		v.Run(ctx, time.Hour)
		close(done)
	}()

	require.Eventually(t, func() bool { return fake.InfoCalls.Load() >= 1 }, 2*time.Second, 5*time.Millisecond)
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("ctx 취소 뒤에도 Run이 반환하지 않았습니다")
	}
	got, err := v.Current()
	require.NoError(t, err)
	require.Equal(t, "rs-1", got)
}

// lockedBuffer는 여러 goroutine이 쓰는 로그를 읽기 위한 동시성 안전 버퍼입니다.
type lockedBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *lockedBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *lockedBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

func TestVersions_RunRecoversAfterFirstFailureAndLogsWarn(t *testing.T) {
	var calls atomic.Int64
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		if calls.Add(1) == 1 {
			return nil, engine.ErrUnavailable
		}
		return &enginev1.InfoResponse{RulesetVersion: "rs-9"}, nil
	}}
	logs := &lockedBuffer{}
	v := engine.NewVersions(fake, slog.New(slog.NewTextHandler(logs, nil)))
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	done := make(chan struct{})

	go func() {
		v.Run(ctx, 10*time.Millisecond)
		close(done)
	}()

	require.Eventually(t, func() bool {
		got, err := v.Current()
		return err == nil && got == "rs-9"
	}, 2*time.Second, 5*time.Millisecond)
	cancel()
	<-done

	require.Contains(t, logs.String(), "level=WARN")
	require.Contains(t, logs.String(), "engine unavailable")
	require.NotContains(t, logs.String(), "context canceled")
}

func TestVersions_RunDoesNotLogCancelOnShutdown(t *testing.T) {
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		return nil, fmt.Errorf("엔진 GetInfo: %w", context.Canceled)
	}}
	logs := &lockedBuffer{}
	v := engine.NewVersions(fake, slog.New(slog.NewTextHandler(logs, nil)))
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	done := make(chan struct{})

	go func() {
		v.Run(ctx, time.Hour)
		close(done)
	}()
	require.Eventually(t, func() bool { return fake.InfoCalls.Load() >= 1 }, 2*time.Second, 5*time.Millisecond)
	cancel()
	<-done

	require.False(t, strings.Contains(logs.String(), "canceled"), logs.String())
}

func TestVersions_RunWithNonPositiveIntervalRefreshesOnceAndWaits(t *testing.T) {
	fake := &enginetest.Fake{}
	logs := &lockedBuffer{}
	v := engine.NewVersions(fake, slog.New(slog.NewTextHandler(logs, nil)))
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	done := make(chan struct{})

	go func() {
		v.Run(ctx, 0)
		close(done)
	}()

	require.Eventually(t, func() bool { return fake.InfoCalls.Load() == 1 }, 2*time.Second, 5*time.Millisecond)
	select {
	case <-done:
		t.Fatal("ctx 취소 전에 Run이 반환했습니다")
	case <-time.After(50 * time.Millisecond):
	}
	cancel()
	<-done
	require.Equal(t, int64(1), fake.InfoCalls.Load())
	require.Contains(t, logs.String(), "level=WARN")
}

func TestVersions_RunRetriesWithBackoffWhileVersionUnknown(t *testing.T) {
	var calls atomic.Int64
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		if calls.Add(1) <= 2 {
			return nil, engine.ErrUnavailable
		}
		return &enginev1.InfoResponse{RulesetVersion: "rs-3"}, nil
	}}
	v := newTestVersions(fake)
	v.SetInitialBackoffForTest(5 * time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	done := make(chan struct{})

	go func() {
		v.Run(ctx, time.Hour) // 정상 주기가 1시간이어도 값을 모르는 동안은 짧은 backoff로 다시 시도합니다.
		close(done)
	}()

	require.Eventually(t, func() bool {
		got, err := v.Current()
		return err == nil && got == "rs-3"
	}, 2*time.Second, 5*time.Millisecond)
	cancel()
	<-done
}

// 값을 알면 Ensure는 엔진을 부르지 않습니다.
func TestVersions_EnsureReturnsKnownValueWithoutEngine(t *testing.T) {
	var calls atomic.Int64
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		calls.Add(1)
		return &enginev1.InfoResponse{RulesetVersion: "rs-1"}, nil
	}}
	v := newTestVersions(fake)
	require.NoError(t, v.Refresh(context.Background()))

	got, err := v.Ensure(context.Background())

	require.NoError(t, err)
	require.Equal(t, "rs-1", got)
	require.EqualValues(t, 1, calls.Load(), "Refresh 한 번만")
}

// 값을 모르면 동시에 온 Ensure가 GetInfo 하나를 함께 기다리고 같은 값을 받습니다(S132, cold start 직후 첫 요청들).
func TestVersions_EnsureWaitsForOneSharedRefresh(t *testing.T) {
	release := make(chan struct{})
	var calls atomic.Int64
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		calls.Add(1)
		<-release
		return &enginev1.InfoResponse{RulesetVersion: "rs-1"}, nil
	}}
	v := newTestVersions(fake)

	const callers = 5
	var wg sync.WaitGroup
	results := make(chan string, callers)
	for range callers {
		wg.Go(func() {
			got, err := v.Ensure(context.Background())
			require.NoError(t, err)
			results <- got
		})
	}
	// 모든 호출자가 같은 Refresh를 기다리기 시작할 시간을 줍니다.
	require.Eventually(t, func() bool { return calls.Load() == 1 }, time.Second, time.Millisecond)
	time.Sleep(20 * time.Millisecond)
	close(release)
	wg.Wait()
	close(results)

	for got := range results {
		require.Equal(t, "rs-1", got)
	}
	require.EqualValues(t, 1, calls.Load())
}

// Refresh가 실패하면 ErrVersionUnknown과 엔진 오류를 함께 돌려주고, 다음 Ensure가 다시 시도합니다.
func TestVersions_EnsureFailureIsVersionUnknownAndRetriesNextTime(t *testing.T) {
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) { return nil, engine.ErrTimeout }}
	v := newTestVersions(fake)

	_, err := v.Ensure(context.Background())
	require.ErrorIs(t, err, engine.ErrVersionUnknown)
	require.ErrorIs(t, err, engine.ErrTimeout)

	fake.Info = infoWith("rs-1")
	got, err := v.Ensure(context.Background())
	require.NoError(t, err)
	require.Equal(t, "rs-1", got)
}

// 호출자 ctx가 끝나면 기다림을 멈추고 ctx 오류를 돌려주며, 진행 중인 Refresh는 끝까지 돌아 값을 채웁니다.
func TestVersions_EnsureStopsWaitingOnCallerCancel(t *testing.T) {
	release := make(chan struct{})
	fake := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		<-release
		return &enginev1.InfoResponse{RulesetVersion: "rs-1"}, nil
	}}
	v := newTestVersions(fake)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := v.Ensure(ctx)
	require.ErrorIs(t, err, context.Canceled)

	close(release)
	require.Eventually(t, func() bool {
		got, err := v.Current()
		return err == nil && got == "rs-1"
	}, time.Second, time.Millisecond)
}

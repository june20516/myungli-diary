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

package engine_test

import (
	"context"
	"io"
	"log/slog"
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

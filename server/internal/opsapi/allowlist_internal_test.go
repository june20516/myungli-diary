package opsapi

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

// 읽기가 상한을 넘으면 기다리지 않고 ErrOperatorsUnavailable이고(fail-closed), 캐시를 쓰지 않습니다.
func TestFileOperators_ReadTimeout(t *testing.T) {
	release := make(chan struct{})
	t.Cleanup(func() { close(release) })
	source := NewFileOperators("unused", clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC)))
	source.readTimeout = 20 * time.Millisecond
	source.read = func(string) (string, error) {
		<-release
		return "op@example.com", nil
	}

	_, err := source.Operators(context.Background())
	assert.ErrorIs(t, err, ErrOperatorsUnavailable)
}

// TTL이 지난 순간 몰린 요청은 파일을 한 번만 읽고 같은 결과를 씁니다. 캐시가 유효한 동안에는 읽지 않습니다.
func TestFileOperators_SingleRefresh(t *testing.T) {
	var reads atomic.Int32
	gate := make(chan struct{})
	source := NewFileOperators("unused", clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC)))
	source.read = func(string) (string, error) {
		reads.Add(1)
		<-gate
		return "op@example.com", nil
	}

	var wg sync.WaitGroup
	errs := make(chan error, 10)
	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			list, err := source.Operators(context.Background())
			if err == nil && !list.Allows("op@example.com") {
				err = errors.New("목록에 운영자가 없습니다")
			}
			errs <- err
		}()
	}
	time.Sleep(20 * time.Millisecond)
	close(gate)
	wg.Wait()
	close(errs)
	for err := range errs {
		require.NoError(t, err)
	}
	assert.Equal(t, int32(1), reads.Load())
}

// 다른 요청이 느리게 다시 읽는 동안 기다리던 요청은 ctx가 취소되면 곧바로 ErrOperatorsUnavailable로 돌아옵니다.
// 그 취소는 캐시를 무효화하지 않아, 읽기가 끝나면 그 결과가 캐시에 남습니다.
func TestFileOperators_WaiterFollowsContext(t *testing.T) {
	started := make(chan struct{})
	gate := make(chan struct{})
	var reads atomic.Int32
	source := NewFileOperators("unused", clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC)))
	source.read = func(string) (string, error) {
		if reads.Add(1) == 1 {
			close(started)
		}
		<-gate
		return "op@example.com", nil
	}

	readerDone := make(chan error, 1)
	go func() {
		_, err := source.Operators(context.Background())
		readerDone <- err
	}()
	<-started

	ctx, cancel := context.WithCancel(context.Background())
	waiterDone := make(chan error, 1)
	go func() {
		_, err := source.Operators(ctx)
		waiterDone <- err
	}()
	cancel()
	select {
	case err := <-waiterDone:
		assert.ErrorIs(t, err, ErrOperatorsUnavailable)
	case <-time.After(time.Second):
		t.Fatal("취소된 대기 요청이 돌아오지 않았습니다")
	}

	close(gate)
	require.NoError(t, <-readerDone)
	list, err := source.Operators(context.Background())
	require.NoError(t, err)
	assert.True(t, list.Allows("op@example.com"), "대기 요청의 취소가 캐시를 무효화하지 않음")
	assert.Equal(t, int32(1), reads.Load())
}

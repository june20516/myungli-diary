package engine

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// 호출자 ctx가 취소된 뒤 UNAVAILABLE이 와도 재시도 가드가 rpc를 다시 부르지 않는지 호출 횟수로 확인합니다.
func TestCall_DoesNotRetryWhenCallerContextCanceled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	var rpcCalls int
	rpc := func(context.Context, *struct{}, ...grpc.CallOption) (*struct{}, error) {
		rpcCalls++
		cancel()
		return nil, status.Error(codes.Unavailable, "")
	}

	_, err := call(ctx, "Test", rpc, &struct{}{})

	require.ErrorIs(t, err, context.Canceled)
	assert.Equal(t, 1, rpcCalls)
}

func TestCall_RetriesUnavailableWhileContextAlive(t *testing.T) {
	var rpcCalls int
	rpc := func(context.Context, *struct{}, ...grpc.CallOption) (*struct{}, error) {
		rpcCalls++
		return nil, status.Error(codes.Unavailable, "")
	}

	_, err := call(context.Background(), "Test", rpc, &struct{}{})

	require.ErrorIs(t, err, ErrUnavailable)
	assert.Equal(t, 2, rpcCalls)
}

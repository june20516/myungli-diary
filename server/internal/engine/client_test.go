package engine_test

import (
	"context"
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// scriptedServer는 호출마다 미리 정한 결과를 돌려주고, 호출 횟수와 받은 deadline의 남은 시간을 기록하는 엔진 서버입니다.
type scriptedServer struct {
	enginev1.UnimplementedMyungliEngineServer

	calls     atomic.Int64
	mu        sync.Mutex
	remaining []time.Duration
	// respond는 n번째(1부터) 호출의 결과를 정합니다.
	respond func(n int64) error
}

func (s *scriptedServer) GetChart(ctx context.Context, _ *enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
	n := s.calls.Add(1)
	if deadline, ok := ctx.Deadline(); ok {
		s.mu.Lock()
		s.remaining = append(s.remaining, time.Until(deadline))
		s.mu.Unlock()
	}
	if err := s.respond(n); err != nil {
		return nil, err
	}
	return &enginev1.ChartResponse{}, nil
}

func (s *scriptedServer) GetInfo(context.Context, *enginev1.InfoRequest) (*enginev1.InfoResponse, error) {
	n := s.calls.Add(1)
	if err := s.respond(n); err != nil {
		return nil, err
	}
	return &enginev1.InfoResponse{EngineVersion: "e", RulesetVersion: "r"}, nil
}

// newTestClient는 bufconn 위에 서버를 띄우고 거기에 연결한 Client를 돌려줍니다.
func newTestClient(t *testing.T, srv enginev1.MyungliEngineServer) *engine.Client {
	t.Helper()
	listener := bufconn.Listen(1 << 20)
	grpcServer := grpc.NewServer()
	enginev1.RegisterMyungliEngineServer(grpcServer, srv)
	go func() { _ = grpcServer.Serve(listener) }()
	t.Cleanup(grpcServer.Stop)

	client, err := engine.NewClient(
		engine.ClientConfig{Addr: "passthrough:///bufnet"},
		grpc.WithContextDialer(func(context.Context, string) (net.Conn, error) { return listener.Dial() }),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	require.NoError(t, err)
	t.Cleanup(func() { _ = client.Close() })
	return client
}

func TestClient_MapsStatusToSentinel(t *testing.T) {
	tests := []struct {
		name      string
		code      codes.Code
		want      error
		wantCalls int64
	}{
		{"InvalidArgument", codes.InvalidArgument, engine.ErrInvalidArgument, 1},
		{"OutOfRange", codes.OutOfRange, engine.ErrOutOfRange, 1},
		{"Internal", codes.Internal, engine.ErrInternal, 1},
		{"DeadlineExceeded", codes.DeadlineExceeded, engine.ErrTimeout, 1},
		{"Unavailable", codes.Unavailable, engine.ErrUnavailable, 2},
		{"Unknown", codes.Unknown, engine.ErrInternal, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := &scriptedServer{respond: func(int64) error { return status.Error(tt.code, "detail") }}
			client := newTestClient(t, srv)

			_, err := client.GetChart(context.Background(), &enginev1.ChartRequest{})

			require.ErrorIs(t, err, tt.want)
			assert.Equal(t, tt.wantCalls, srv.calls.Load())
		})
	}
}

func TestClient_RetriesUnavailableOnce(t *testing.T) {
	srv := &scriptedServer{respond: func(n int64) error {
		if n == 1 {
			return status.Error(codes.Unavailable, "")
		}
		return nil
	}}
	client := newTestClient(t, srv)

	resp, err := client.GetChart(context.Background(), &enginev1.ChartRequest{})

	require.NoError(t, err)
	assert.NotNil(t, resp)
	assert.EqualValues(t, 2, srv.calls.Load())
}

func TestClient_RetriesGetInfoToo(t *testing.T) {
	srv := &scriptedServer{respond: func(n int64) error {
		if n == 1 {
			return status.Error(codes.Unavailable, "")
		}
		return nil
	}}
	client := newTestClient(t, srv)

	info, err := client.GetInfo(context.Background())

	require.NoError(t, err)
	assert.Equal(t, "r", info.GetRulesetVersion())
	assert.EqualValues(t, 2, srv.calls.Load())
}

func TestClient_DoesNotRetryOtherCodes(t *testing.T) {
	srv := &scriptedServer{respond: func(int64) error { return status.Error(codes.Internal, "") }}
	client := newTestClient(t, srv)

	_, err := client.GetChart(context.Background(), &enginev1.ChartRequest{})

	require.ErrorIs(t, err, engine.ErrInternal)
	assert.EqualValues(t, 1, srv.calls.Load())
}

func TestClient_DoesNotRetryWhenCallerContextCanceled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	srv := &scriptedServer{respond: func(int64) error {
		cancel()
		return status.Error(codes.Unavailable, "")
	}}
	client := newTestClient(t, srv)

	_, err := client.GetChart(ctx, &enginev1.ChartRequest{})

	require.Error(t, err)
	assert.EqualValues(t, 1, srv.calls.Load())
}

func TestClient_AppliesDeadline(t *testing.T) {
	srv := &scriptedServer{respond: func(int64) error { return nil }}
	client := newTestClient(t, srv)

	_, err := client.GetChart(context.Background(), &enginev1.ChartRequest{})

	require.NoError(t, err)
	require.Len(t, srv.remaining, 1)
	assert.Positive(t, srv.remaining[0])
	assert.LessOrEqual(t, srv.remaining[0], 3*time.Second)
}

func TestClient_CallerShorterDeadlineWins(t *testing.T) {
	srv := &scriptedServer{respond: func(int64) error { return nil }}
	client := newTestClient(t, srv)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	_, err := client.GetChart(ctx, &enginev1.ChartRequest{})

	require.NoError(t, err)
	require.Len(t, srv.remaining, 1)
	assert.LessOrEqual(t, srv.remaining[0], time.Second)
}

func TestClient_ErrorTextHasNoStatusMessage(t *testing.T) {
	srv := &scriptedServer{respond: func(int64) error { return status.Error(codes.InvalidArgument, "1990-01-01") }}
	client := newTestClient(t, srv)

	_, err := client.GetChart(context.Background(), &enginev1.ChartRequest{})

	require.Error(t, err)
	assert.NotContains(t, err.Error(), "1990")
	_, isStatus := status.FromError(err)
	assert.False(t, isStatus, "원래 gRPC 상태가 오류 체인에 남으면 안 됩니다")
}

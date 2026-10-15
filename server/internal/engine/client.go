package engine

import (
	"context"
	"crypto/tls"
	"fmt"
	"time"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/status"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// callTimeout은 엔진 호출 한 번(시도마다)의 deadline입니다(D41).
const callTimeout = 3 * time.Second

// ClientConfig는 엔진 연결 설정입니다.
type ClientConfig struct {
	Addr     string // host:port
	Audience string // 비어 있으면 h2c(로컬). 있으면 TLS(시스템 루트) + 이 audience의 Google ID token
}

// Client는 gRPC로 엔진을 부르는 Engine 구현입니다.
type Client struct {
	conn   *grpc.ClientConn
	engine enginev1.MyungliEngineClient
}

var _ Engine = (*Client)(nil)

// NewClient는 엔진에 대한 gRPC 연결을 만듭니다. opts는 뒤에 붙으므로 테스트의 bufconn dialer 등으로 덮어쓸 수 있습니다.
func NewClient(cfg ClientConfig, opts ...grpc.DialOption) (*Client, error) {
	dialOpts := []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}
	if cfg.Audience != "" {
		// NewClient에 ctx를 받지 않으므로 Background를 씁니다. token source는 이후 RPC마다 토큰을 갱신하며
		// 이 ctx에는 deadline이 필요 없습니다.
		tokenSource, err := idtoken.NewTokenSource(context.Background(), cfg.Audience)
		if err != nil {
			return nil, fmt.Errorf("엔진 ID token 준비: %w", err)
		}
		dialOpts = []grpc.DialOption{
			grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12})),
			grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
		}
	}
	dialOpts = append(dialOpts, opts...)

	conn, err := grpc.NewClient(cfg.Addr, dialOpts...)
	if err != nil {
		return nil, fmt.Errorf("엔진 연결 생성: %w", err)
	}
	return &Client{conn: conn, engine: enginev1.NewMyungliEngineClient(conn)}, nil
}

// Close는 엔진 연결을 닫습니다.
func (c *Client) Close() error { return c.conn.Close() }

func (c *Client) GetChart(ctx context.Context, req *enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
	return call(ctx, "GetChart", c.engine.GetChart, req)
}

func (c *Client) GetDaily(ctx context.Context, req *enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
	return call(ctx, "GetDaily", c.engine.GetDaily, req)
}

func (c *Client) GetMonthCalendar(ctx context.Context, req *enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
	return call(ctx, "GetMonthCalendar", c.engine.GetMonthCalendar, req)
}

func (c *Client) GetBirthHour(ctx context.Context, req *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
	return call(ctx, "GetBirthHour", c.engine.GetBirthHour, req)
}

func (c *Client) GetInfo(ctx context.Context) (*enginev1.InfoResponse, error) {
	return call(ctx, "GetInfo", c.engine.GetInfo, &enginev1.InfoRequest{})
}

// call은 RPC 한 번에 3초 deadline을 걸고, UNAVAILABLE이면 한 번 더(새 3초) 부릅니다.
// 호출자 ctx가 이미 끝났으면 다시 부르지 않습니다. 실패는 sentinel로 분류해 돌려줍니다.
func call[Req, Resp any](
	ctx context.Context,
	name string,
	rpc func(context.Context, *Req, ...grpc.CallOption) (*Resp, error),
	req *Req,
) (*Resp, error) {
	resp, err := attempt(ctx, rpc, req)
	if status.Code(err) == codes.Unavailable && ctx.Err() == nil {
		resp, err = attempt(ctx, rpc, req)
	}
	if err != nil {
		return nil, classify(name, err)
	}
	return resp, nil
}

// attempt는 deadline을 걸어 RPC를 한 번 부릅니다. 호출자 ctx에 더 짧은 deadline이 있으면 그것이 우선합니다.
func attempt[Req, Resp any](
	ctx context.Context,
	rpc func(context.Context, *Req, ...grpc.CallOption) (*Resp, error),
	req *Req,
) (*Resp, error) {
	ctx, cancel := context.WithTimeout(ctx, callTimeout)
	defer cancel()
	return rpc(ctx, req)
}

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

// callTimeout은 엔진 호출 첫 시도의 deadline입니다. 떠 있는 엔진에는 충분한 시간입니다(S27).
const callTimeout = 3 * time.Second

// coldStartTimeout은 첫 시도가 timeout이나 UNAVAILABLE로 끝났을 때 다시 부르는 시도의 deadline입니다(S132).
// 엔진은 0개까지 줄어들 수 있어 cold start(staging 실측 약 5.5초)가 늘 일어나고, 첫 시도가 깨운 인스턴스가
// 뜨는 동안 기다릴 수 있어야 합니다.
const coldStartTimeout = 10 * time.Second

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

func (c *Client) ConvertLunarDate(ctx context.Context, req *enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
	return call(ctx, "ConvertLunarDate", c.engine.ConvertLunarDate, req)
}

// call은 RPC를 callTimeout으로 부르고, UNAVAILABLE이나 DEADLINE_EXCEEDED면 coldStartTimeout으로 한 번 더 부릅니다.
// 엔진 RPC는 계산만 하므로 다시 불러도 결과가 같습니다(S132). 호출자 ctx가 이미 끝났으면 다시 부르지 않습니다.
// 실패는 sentinel로 분류해 돌려줍니다.
func call[Req, Resp any](
	ctx context.Context,
	name string,
	rpc func(context.Context, *Req, ...grpc.CallOption) (*Resp, error),
	req *Req,
) (*Resp, error) {
	resp, err := attempt(ctx, callTimeout, rpc, req)
	if retryable(err) && callerContextError(ctx) == nil {
		resp, err = attempt(ctx, coldStartTimeout, rpc, req)
	}
	if err != nil {
		return nil, classify(ctx, name, err)
	}
	return resp, nil
}

// retryable은 다시 불러 볼 만한 실패인지입니다. 엔진이 뜨는 중이거나(UNAVAILABLE) 첫 시도 deadline이 지난 경우입니다.
func retryable(err error) bool {
	switch status.Code(err) {
	case codes.Unavailable, codes.DeadlineExceeded:
		return true
	default:
		return false
	}
}

// attempt는 timeout deadline을 걸어 RPC를 한 번 부릅니다. 호출자 ctx에 더 짧은 deadline이 있으면 그것이 우선합니다.
func attempt[Req, Resp any](
	ctx context.Context,
	timeout time.Duration,
	rpc func(context.Context, *Req, ...grpc.CallOption) (*Resp, error),
	req *Req,
) (*Resp, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	return rpc(ctx, req)
}

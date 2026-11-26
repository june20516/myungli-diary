package cli

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/opsapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

// iapKeyHTTPTimeout은 IAP 공개키를 받는 요청의 전체 제한입니다.
const iapKeyHTTPTimeout = 10 * time.Second

// fixedIdentity는 local 개발용 고정 신원입니다. 서명 헤더를 보지 않고 항상 같은 신원을 돌려줍니다.
// opsapi가 아니라 cli에 둔 것은 인증을 우회하는 구현이 운영 API 패키지의 공개 표면에 남지 않게 하려는 것이고,
// 오직 ops-serve가 APP_ENV=local에서만 조립합니다(config.LoadOps가 다른 환경에서는 설정 자체를 거절합니다).
type fixedIdentity struct{ identity opsapi.Identity }

func (f fixedIdentity) Verify(context.Context, string) (opsapi.Identity, error) {
	return f.identity, nil
}

// runOpsServe는 IAP 뒤의 운영 API 서버를 시작하고 ctx가 취소되면 처리 중인 요청을 마친 뒤 종료합니다.
// 앱 서버(serve)와 다른 Cloud Run 서비스이고 DB에는 자기 서비스 계정(IAM 사용자)으로 붙습니다.
// 배포 환경(staging, prod)에서는 CLOUD_SQL_INSTANCE와 IAP_AUDIENCE가 필수이고 OPS_DEV_IDENTITY는 기동 실패입니다.
func runOpsServe(ctx context.Context, args []string, getenv func(string) string, _, stderr io.Writer) error {
	if len(args) != 0 {
		return usageErrorf("usage: server ops-serve")
	}
	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	opsCfg, err := config.LoadOps(getenv)
	if err != nil {
		return err
	}
	if cfg.Env != "local" && cfg.CloudSQLInstance == "" {
		return errors.New("CLOUD_SQL_INSTANCE가 필요합니다(APP_ENV가 local일 때만 비워 둘 수 있습니다)")
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	authenticator, err := newOpsAuthenticator(opsCfg)
	if err != nil {
		logger.ErrorContext(ctx, "운영자 인증 준비 실패", "error", err)
		return &loggedError{err: err}
	}
	if opsCfg.DevIdentity != nil {
		// 신원 값은 남기지 않습니다. 이 모드는 local에서만 가능합니다.
		logger.WarnContext(ctx, "OPS_DEV_IDENTITY의 고정 신원으로 IAP 검증 없이 시작합니다", "env", cfg.Env)
	}

	pool, closeDB, err := openDatabase(ctx, cfg)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer closeDB()

	handler, err := opsapi.NewHandler(opsapi.Deps{
		Service:   ops.NewService(pool),
		Verifier:  authenticator,
		Allowlist: opsapi.ParseAllowlist(opsCfg.Operators),
		Logger:    logger,
	})
	if err != nil {
		logger.ErrorContext(ctx, "운영 API 조립 실패", "error", err)
		return &loggedError{err: err}
	}

	var listenConfig net.ListenConfig
	listener, err := listenConfig.Listen(ctx, "tcp", net.JoinHostPort("", strconv.Itoa(cfg.Port)))
	if err != nil {
		logger.ErrorContext(ctx, "포트 열기 실패", "port", cfg.Port, "error", err)
		return &loggedError{err: err}
	}
	logger.InfoContext(ctx, "운영 API 서버 시작", "port", cfg.Port, "env", cfg.Env)
	if err := serveHTTP(ctx, listener, handler, logger); err != nil {
		logger.ErrorContext(ctx, "운영 API 서버 종료 오류", "error", err)
		return &loggedError{err: err}
	}
	logger.InfoContext(ctx, "운영 API 서버 종료")
	return nil
}

// newOpsAuthenticator는 설정에 맞는 인증기를 만듭니다. 고정 신원이 있으면(local 전용) 그것을, 아니면 IAP 서명 검증기를 씁니다.
// 공개키 주소는 고정 값이고 환경 변수로 바꿀 수 없습니다.
func newOpsAuthenticator(cfg config.OpsConfig) (opsapi.Authenticator, error) {
	if cfg.DevIdentity != nil {
		return fixedIdentity{identity: *cfg.DevIdentity}, nil
	}
	keys, err := opsapi.NewHTTPKeySource(&http.Client{Timeout: iapKeyHTTPTimeout}, opsapi.IAPPublicKeyURL, clock.System{})
	if err != nil {
		return nil, err
	}
	return opsapi.NewVerifier(keys, cfg.Audience, clock.System{})
}

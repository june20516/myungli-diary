package cli

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

const (
	readHeaderTimeout = 10 * time.Second
	shutdownTimeout   = 10 * time.Second
)

// runServe는 HTTP 서버를 시작하고 ctx가 취소되면 처리 중인 요청을 마친 뒤 종료합니다.
// P1의 serve는 DB를 열지 않습니다(DB를 쓰는 핸들러는 이후 계획에서 추가합니다).
func runServe(ctx context.Context, args []string, getenv func(string) string, _, stderr io.Writer) error {
	if len(args) != 0 {
		return usageErrorf("usage: server serve")
	}
	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	// 계약(내장 spec)으로 요청을 검증하고, 아직 구현하지 않은 operation은 501로 답합니다.
	spec, err := gen.GetSwagger()
	if err != nil {
		logger.ErrorContext(ctx, "계약 읽기 실패", "error", err)
		return &loggedError{err: err}
	}
	deps := httpapi.Deps{Logger: logger, Clock: clock.System{}}
	validate := httpapi.ValidateRequests(spec)
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, httpapi.Unimplemented{}, deps, validate)
	})

	listener, err := net.Listen("tcp", net.JoinHostPort("", strconv.Itoa(cfg.Port)))
	if err != nil {
		logger.ErrorContext(ctx, "포트 열기 실패", "port", cfg.Port, "error", err)
		return &loggedError{err: err}
	}

	logger.InfoContext(ctx, "서버 시작", "port", cfg.Port, "env", cfg.Env)
	if err := serveHTTP(ctx, listener, handler, logger); err != nil {
		logger.ErrorContext(ctx, "서버 종료 오류", "error", err)
		return &loggedError{err: err}
	}
	logger.InfoContext(ctx, "서버 종료")
	return nil
}

// serveHTTP는 listener로 handler를 서비스합니다.
// ctx가 취소되면 Shutdown을 shutdownTimeout 안에서 호출해 처리 중인 요청을 끝까지 응답합니다.
func serveHTTP(ctx context.Context, listener net.Listener, handler http.Handler, logger *slog.Logger) error {
	server := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: readHeaderTimeout,
		// net/http 내부 오류도 구조화 로그로 남깁니다.
		ErrorLog: slog.NewLogLogger(logger.Handler(), slog.LevelWarn),
	}

	serveErr := make(chan error, 1)
	go func() { serveErr <- server.Serve(listener) }()

	select {
	case err := <-serveErr:
		// Shutdown 전에 Serve가 끝나는 것은 시작 실패 같은 비정상 종료입니다.
		return fmt.Errorf("serve: %w", err)
	case <-ctx.Done():
	}

	// ctx는 이미 취소됐으므로 종료 제한 시간은 새 ctx에서 시작합니다.
	shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), shutdownTimeout)
	defer cancel()
	logger.InfoContext(shutdownCtx, "종료 신호 수신, 처리 중인 요청을 마칩니다")
	if err := server.Shutdown(shutdownCtx); err != nil {
		// 제한 시간 안에 끝나지 않은 연결은 강제로 닫습니다.
		_ = server.Close()
		return fmt.Errorf("shutdown: %w", err)
	}
	if err := <-serveErr; !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("serve: %w", err)
	}
	return nil
}

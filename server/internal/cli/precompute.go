package cli

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
	"github.com/june20516/myungli-diary/server/internal/precompute"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// precomputeDeps는 precomputeJob이 쓰는 것입니다. 테스트는 엔진 대역과 고정 시계를 넣습니다.
type precomputeDeps struct {
	Pool   *pgxpool.Pool
	Engine engine.Engine
	Clock  clock.Clock
	Logger *slog.Logger
}

// runPrecompute는 설정을 읽고 DB와 엔진에 연결해 precompute를 실행합니다(spec §8.1, P8-3).
// DB와 엔진 설정만 읽고 serve 전체 설정은 요구하지 않습니다.
func runPrecompute(ctx context.Context, getenv func(string) string, stderr io.Writer) error {
	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	engineCfg, err := config.LoadEngine(getenv)
	if err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	pool, closeDB, err := openDatabase(ctx, cfg)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer closeDB()

	engineClient, err := engine.NewClient(engine.ClientConfig{Addr: engineCfg.Addr, Audience: engineCfg.Audience})
	if err != nil {
		logger.ErrorContext(ctx, "엔진 client 생성 실패", "error", err)
		return &loggedError{err: err}
	}
	defer func() { _ = engineClient.Close() }()

	deps := precomputeDeps{Pool: pool, Engine: engineClient, Clock: clock.System{}, Logger: logger}
	if err := precomputeJob(ctx, deps); err != nil {
		logger.ErrorContext(ctx, "precompute 실패", "error", err)
		return &loggedError{err: err}
	}
	return nil
}

// precomputeJob은 엔진의 현재 ruleset_version을 받은 뒤 대상 사용자의 다음 날 결과로 캐시를 채웁니다.
func precomputeJob(ctx context.Context, deps precomputeDeps) error {
	versions := engine.NewVersions(deps.Engine, deps.Logger)
	if err := versions.Refresh(ctx); err != nil {
		return fmt.Errorf("엔진 버전 조회: %w", err)
	}
	service := fortune.NewService(deps.Engine, versions, fortune.NewPostgresCache(deps.Pool), deps.Logger)
	_, err := precompute.Run(ctx, precompute.Deps{
		Profiles: func(ctx context.Context, activeSince time.Time, after uuid.UUID, limit int32) ([]profile.ActiveProfile, error) {
			return profile.ListActiveProfiles(ctx, deps.Pool, activeSince, after, limit)
		},
		Fortune: service,
		Clock:   deps.Clock,
		Logger:  deps.Logger,
	})
	return err
}

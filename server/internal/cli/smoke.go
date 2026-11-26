package cli

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"time"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

// smokeDeadline은 한 번 실행의 상한입니다. 엔진 cold start를 기다릴 여유를 두되 Job timeout(900s, jobs.tf)보다 짧게 둡니다.
const smokeDeadline = 5 * time.Minute

// runSmoke는 배포 뒤 조합 확인(D147 ①, S169)을 실행합니다. DB(콘텐츠 시드 읽기)와 엔진 설정만 읽습니다.
// 문장을 만들지 못한 일이 하나라도 있거나 엔진, 저장소 호출이 실패하면 종료 코드 1로 끝나 배포 workflow가 실패합니다.
func runSmoke(ctx context.Context, getenv func(string) string, stderr io.Writer) error {
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

	systemClock := clock.System{}
	jobCtx, cancel := context.WithTimeout(ctx, smokeDeadline)
	defer cancel()
	report, err := fortune.RunSmoke(jobCtx, fortune.SmokeConfig{
		Engine: engineClient,
		Store:  content.NewStore(pool, systemClock, logger),
		Clock:  systemClock,
		Logger: logger,
	})
	if err != nil {
		logger.ErrorContext(ctx, "조합 확인 실패", "checks", report.Checks, "error", err)
		return &loggedError{err: err}
	}
	return smokeOutcome(ctx, logger, report)
}

// smokeOutcome은 결과를 로그로 남기고, 문장을 만들지 못한 일이 있으면 오류를 돌려줍니다.
// 실패마다 렌더 실패 로그의 칸(slot, key, variant, lang, error)을 한 줄씩 남겨 workflow 실패에서 바로 찾게 합니다.
func smokeOutcome(ctx context.Context, logger *slog.Logger, report fortune.SmokeReport) error {
	if len(report.Failures) == 0 {
		logger.InfoContext(ctx, "조합 확인 통과", "checks", report.Checks)
		return nil
	}
	for _, f := range report.Failures {
		attrs := make([]any, 0, 2*len(f.Attrs)+2)
		attrs = append(attrs, "failure", f.Message)
		for k, v := range f.Attrs {
			attrs = append(attrs, k, v)
		}
		logger.ErrorContext(ctx, "조합 확인: 문장을 만들지 못함", attrs...)
	}
	err := fmt.Errorf("조합 확인: %d개 화면 가운데 문장을 만들지 못한 일 %d건", report.Checks, len(report.Failures))
	logger.ErrorContext(ctx, "조합 확인 실패", "checks", report.Checks, "failures", len(report.Failures))
	return &loggedError{err: err}
}

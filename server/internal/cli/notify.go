package cli

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/oauth2/google"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/notify"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// notifyDeadline은 한 번 실행의 상한입니다. 실행은 보낼 시각이 다음 5분 안에 오는 사용자를 그 시각까지 기다렸다 보내므로(D109),
// 그 5분에 발송 여유 3분을 더합니다. Job timeout(900초)보다 짧고, 다음 실행과 겹쳐도 notification_log claim이
// 두 번 발송을 막습니다(S129). 상한에 닿아 시작하지 못한 사용자는 60분 창 안의 다음 실행이 보냅니다.
const notifyDeadline = 8 * time.Minute

// notifyDeps는 notifyJob이 쓰는 것입니다. 테스트는 엔진 대역, 기록하는 Sender, 고정 시계를 넣습니다.
type notifyDeps struct {
	Pool   *pgxpool.Pool
	Engine engine.Engine
	Sender notify.Sender
	Clock  clock.Clock
	Logger *slog.Logger
}

// pushComposer는 fortune.Views.PushBody를 notify.Composer로 씁니다.
type pushComposer struct{ views *fortune.Views }

func (c pushComposer) Body(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (string, error) {
	return c.views.PushBody(ctx, accountID, p, date)
}

// runNotify는 설정을 읽고 DB, 엔진, FCM을 조립해 아침 알림을 보냅니다(spec §8.2, P8-4).
// DB, 엔진 설정과 GOOGLE_CLOUD_PROJECT만 읽습니다. FCM 인증은 ADC(Cloud Run 서비스 계정)입니다.
func runNotify(ctx context.Context, getenv func(string) string, stderr io.Writer) error {
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
	if cfg.GCPProjectID == "" {
		return errors.New("GOOGLE_CLOUD_PROJECT가 필요합니다(FCM 프로젝트)")
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)
	jobCtx, cancel := context.WithTimeout(ctx, notifyDeadline)
	defer cancel()

	httpClient, err := google.DefaultClient(jobCtx, notify.FCMScope)
	if err != nil {
		logger.ErrorContext(ctx, "FCM 인증 준비 실패", "error", err)
		return &loggedError{err: err}
	}
	fcm, err := notify.NewFCM(notify.FCMConfig{ProjectID: cfg.GCPProjectID, HTTPClient: httpClient})
	if err != nil {
		return err
	}

	systemClock := clock.System{}
	connectStarted := systemClock.Now()
	pool, closeDB, err := openDatabase(jobCtx, cfg)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer closeDB()
	logger.InfoContext(ctx, "notify DB 연결", "connect_ms", systemClock.Now().Sub(connectStarted).Milliseconds())

	engineClient, err := engine.NewClient(engine.ClientConfig{Addr: engineCfg.Addr, Audience: engineCfg.Audience})
	if err != nil {
		logger.ErrorContext(ctx, "엔진 client 생성 실패", "error", err)
		return &loggedError{err: err}
	}
	defer func() { _ = engineClient.Close() }()

	deps := notifyDeps{Pool: pool, Engine: engineClient, Sender: fcm, Clock: systemClock, Logger: logger}
	if err := notifyJob(jobCtx, deps); err != nil {
		logger.ErrorContext(ctx, "notify 실패", "error", err)
		return &loggedError{err: err}
	}
	return nil
}

// notifyJob은 알림 대상에게 그날 총운 머리 문장(호칭 없음)을 보냅니다. 엔진 버전은 대상이 있을 때만 받습니다.
// 근거 열람 권한은 알림 문장에 쓰이지 않아 AlwaysLocked로 둡니다(결제 설정 불필요).
func notifyJob(ctx context.Context, deps notifyDeps) error {
	versions := engine.NewVersions(deps.Engine, deps.Logger)
	service := fortune.NewService(deps.Engine, versions, fortune.NewPostgresCache(deps.Pool), deps.Logger)
	views := fortune.NewViews(service, content.NewStore(deps.Pool, deps.Clock, deps.Logger), content.NewRenderer(deps.Logger),
		fortune.AlwaysLocked{}, deps.Clock, deps.Logger)
	_, err := notify.Run(ctx, notify.Deps{
		Ledger:   notify.NewStore(deps.Pool),
		Sender:   deps.Sender,
		Composer: pushComposer{views: views},
		Prepare: func(ctx context.Context) error {
			if err := versions.Refresh(ctx); err != nil {
				return fmt.Errorf("엔진 버전 조회: %w", err)
			}
			return nil
		},
		Clock:  deps.Clock,
		Logger: deps.Logger,
	})
	return err
}

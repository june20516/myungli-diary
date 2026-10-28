package cli

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/merge"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	retentionpkg "github.com/june20516/myungli-diary/server/internal/retention"
)

// retentionDeps는 job retention이 바깥에서 받는 의존성입니다.
type retentionDeps struct {
	Pool   *pgxpool.Pool
	Clock  clock.Clock
	Logger *slog.Logger
	HTTP   *http.Client
	// Providers는 제공자 엔드포인트 주소입니다. KakaoUnlink·AppleRevoke만 쓰며, 빈 값은 실제 제공자 주소를 씁니다.
	Providers providerURLs
	// Engine은 이전 ruleset_version 캐시 정리에서 지금 버전(GetInfo)을 묻는 엔진입니다.
	Engine engine.Engine
}

// runRetention은 설정을 읽고 DB에 연결해 retention을 실행합니다.
// DB, 허가 취소에 필요한 설정(카카오 admin key, Apple client_secret 서명 키, token 암호화 키), 엔진 주소만 읽고 검사합니다.
// serve 전체 설정(JWT 서명 키, 제공자 앱 ID 등)은 요구하지 않습니다.
func runRetention(ctx context.Context, getenv func(string) string, stderr io.Writer) error {
	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	revocationCfg, err := config.LoadRevocation(getenv)
	if err != nil {
		return err
	}
	engineCfg, err := config.LoadEngine(getenv)
	if err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	pool, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer pool.Close()

	engineClient, err := engine.NewClient(engine.ClientConfig{Addr: engineCfg.Addr, Audience: engineCfg.Audience})
	if err != nil {
		logger.ErrorContext(ctx, "엔진 client 생성 실패", "error", err)
		return &loggedError{err: err}
	}
	defer func() { _ = engineClient.Close() }()

	if err := retention(ctx, revocationCfg, retentionDeps{
		Pool:   pool,
		Clock:  clock.System{},
		Logger: logger,
		HTTP:   newProviderHTTPClient(),
		Engine: engineClient,
	}); err != nil {
		logger.ErrorContext(ctx, "retention 실패", "error", err)
		return &loggedError{err: err}
	}
	return nil
}

// retention은 보관 기간이 지난 데이터를 정리하고(spec §8.3, S113, S119, S120), 시각이 된 허가 취소 대기 행을 다시 시도합니다(S106).
// 단계마다 따로 실행해 한 단계가 실패해도 나머지 단계(특히 법정 보관 기간 정리)를 끝내고, 실패는 모아 job 실패로 돌려줍니다.
// Apple 웹 로그인 정리가 허가 취소 대기 행을 만들 수 있으므로 허가 취소 재시도는 마지막에 돕니다.
// 제공자 호출이 실패한 행은 대기 행에 남으므로 오류가 아닙니다.
func retention(ctx context.Context, cfg config.RevocationConfig, deps retentionDeps) error {
	store := retentionpkg.NewStore(deps.Pool, deps.Clock)
	steps := append(store.Steps(),
		retentionpkg.Step{Name: "합치기 영수증", Run: func(ctx context.Context) (int64, error) {
			return merge.DeleteExpiredReceipts(ctx, deps.Pool, deps.Clock.Now())
		}},
		retentionpkg.Step{Name: "이전 ruleset_version 캐시", Run: func(ctx context.Context) (int64, error) {
			return deleteStaleRulesetCaches(ctx, store, deps.Engine)
		}},
		retentionpkg.Step{Name: "허가 취소 재시도", Run: func(ctx context.Context) (int64, error) {
			return retryRevocations(ctx, cfg, deps)
		}},
	)

	var errs []error
	for _, step := range steps {
		n, err := step.Run(ctx)
		if err != nil {
			deps.Logger.ErrorContext(ctx, step.Name+" 정리 실패", "step", step.Name, "error", err)
			errs = append(errs, fmt.Errorf("%s: %w", step.Name, err))
			continue
		}
		deps.Logger.InfoContext(ctx, step.Name+" 완료", "step", step.Name, "rows", n)
	}
	return errors.Join(errs...)
}

// deleteStaleRulesetCaches는 엔진에 지금 ruleset_version을 물어 그 밖의 버전 캐시를 지웁니다.
func deleteStaleRulesetCaches(ctx context.Context, store *retentionpkg.Store, eng engine.Engine) (int64, error) {
	if eng == nil {
		return 0, errors.New("엔진이 없습니다")
	}
	info, err := eng.GetInfo(ctx)
	if err != nil {
		return 0, err
	}
	return store.DeleteStaleRulesetCaches(ctx, info.GetRulesetVersion())
}

// retryRevocations는 허가 취소 설정으로 제공자 client를 만들고 시각이 된 대기 행을 다시 시도해 시도한 수를 돌려줍니다.
func retryRevocations(ctx context.Context, cfg config.RevocationConfig, deps retentionDeps) (int64, error) {
	box, err := parseTokenBox(cfg.TokenKeyID, cfg.TokenKey, cfg.TokenPreviousKeyID, cfg.TokenPreviousKey)
	if err != nil {
		return 0, err
	}
	appleKey, err := parseApplePrivateKey(cfg.AppleKeyID, cfg.ApplePrivateKeyPEM)
	if err != nil {
		return 0, err
	}
	kakao, err := provider.NewKakaoUnlinker(provider.KakaoConfig{
		AdminKey:  cfg.KakaoAdminKey,
		UnlinkURL: deps.Providers.KakaoUnlink,
		HTTP:      deps.HTTP,
	})
	if err != nil {
		return 0, fmt.Errorf("provider kakao: %w", err)
	}
	apple, err := provider.NewAppleRevoker(provider.AppleConfig{
		TeamID:     cfg.AppleTeamID,
		KeyID:      cfg.AppleKeyID,
		PrivateKey: appleKey.Private,
		RevokeURL:  deps.Providers.AppleRevoke,
		HTTP:       deps.HTTP,
		Clock:      deps.Clock,
	})
	if err != nil {
		return 0, fmt.Errorf("provider apple: %w", err)
	}

	revocations := auth.NewRevocations(deps.Pool, kakao, apple, box, deps.Clock, deps.Logger)
	attempted, err := revocations.RetryDue(ctx)
	return int64(attempted), err
}

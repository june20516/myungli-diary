package cli

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// retentionDeps는 job retention이 바깥에서 받는 의존성입니다.
type retentionDeps struct {
	Pool   *pgxpool.Pool
	Clock  clock.Clock
	Logger *slog.Logger
	HTTP   *http.Client
	// Providers는 제공자 엔드포인트 주소입니다. 빈 값은 실제 제공자 주소를 씁니다.
	Providers providerURLs
}

// runRetention은 설정을 읽고 DB에 연결해 retention을 실행합니다.
// 허가 취소에 필요한 설정(DB, 카카오 admin key, Apple client_secret 서명 키, token 암호화 키)만 읽고 검사합니다.
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
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	pool, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer pool.Close()

	if err := retention(ctx, revocationCfg, retentionDeps{
		Pool:   pool,
		Clock:  clock.System{},
		Logger: logger,
		HTTP:   newProviderHTTPClient(),
	}); err != nil {
		logger.ErrorContext(ctx, "retention 실패", "error", err)
		return &loggedError{err: err}
	}
	return nil
}

// retention은 시각이 된 허가 취소 대기 행을 다시 시도합니다(S106).
// 제공자 호출이 실패한 행은 대기 행에 남으므로 오류가 아니고, 설정·DB 오류만 실패로 돌려줍니다.
func retention(ctx context.Context, cfg config.RevocationConfig, deps retentionDeps) error {
	box, err := parseTokenBox(cfg.TokenKeyID, cfg.TokenKey, cfg.TokenPreviousKeyID, cfg.TokenPreviousKey)
	if err != nil {
		return err
	}
	appleKey, err := parseApplePrivateKey(cfg.AppleKeyID, cfg.ApplePrivateKeyPEM)
	if err != nil {
		return err
	}
	kakao, err := provider.NewKakaoUnlinker(provider.KakaoConfig{
		AdminKey:  cfg.KakaoAdminKey,
		UnlinkURL: deps.Providers.KakaoUnlink,
		HTTP:      deps.HTTP,
	})
	if err != nil {
		return fmt.Errorf("provider kakao: %w", err)
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
		return fmt.Errorf("provider apple: %w", err)
	}

	revocations := auth.NewRevocations(deps.Pool, kakao, apple, box, deps.Clock, deps.Logger)
	attempted, err := revocations.RetryDue(ctx)
	if err != nil {
		return err
	}
	deps.Logger.InfoContext(ctx, "허가 취소 재시도 완료", "attempted", attempted)
	return nil
}

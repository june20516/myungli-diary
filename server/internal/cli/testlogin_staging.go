//go:build staging

package cli

import (
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
)

// testLoginSettings는 staging 테스트 로그인(S24) 설정입니다. 빈 값(secret 없음)이면 켜지 않습니다.
type testLoginSettings struct {
	secret string
}

// loadTestLogin은 TEST_LOGIN_SECRET을 읽습니다. staging 빌드에서는 비었거나 짧으면 시작에 실패합니다.
func loadTestLogin(getenv func(string) string) (testLoginSettings, error) {
	cfg, err := config.LoadTestLogin(getenv)
	if err != nil {
		return testLoginSettings{}, err
	}
	return testLoginSettings{secret: cfg.Secret}, nil
}

// enable은 api에 Bearer 인증의 보상형 광고 보상(S131) 라우트를 켜고, 비밀이 있으면 테스트 로그인 라우트와
// 같은 비밀을 쓰는 테스트 광고 제거 기간(S125) 라우트를 켭니다. RegisterAPI 전에 불러야 합니다.
// 권한 상태 계산에 상품 목록이 필요 없어 빈 catalog로 Store를 만듭니다.
func (s testLoginSettings) enable(api *httpapi.API, service *auth.Service, pool *pgxpool.Pool, clk clock.Clock, logger *slog.Logger) {
	store := billing.NewStore(pool, clk, nil)
	api.EnableTestReward(billing.NewTestRewards(billing.NewRewards(pool, clk, logger), store))
	if s.secret == "" {
		return
	}
	api.EnableTestLogin(s.secret, service)
	api.EnableTestGrant(store)
}

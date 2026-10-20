//go:build staging

package cli

import (
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
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

// enable은 비밀이 있으면 api에 테스트 로그인 라우트를 켭니다. RegisterAPI 전에 불러야 합니다.
func (s testLoginSettings) enable(api *httpapi.API, service *auth.Service) {
	if s.secret == "" {
		return
	}
	api.EnableTestLogin(s.secret, service)
}

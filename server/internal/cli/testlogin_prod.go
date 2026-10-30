//go:build !staging

package cli

import (
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// prod 빌드(staging tag 없음)에는 테스트 로그인(S24)과 테스트 광고 제거 기간(S125)이 없습니다. TEST_LOGIN_SECRET도 읽지 않습니다.

// testLoginSettings는 prod 빌드에서 비어 있습니다.
type testLoginSettings struct{}

// loadTestLogin은 prod 빌드에서 아무것도 읽지 않습니다.
func loadTestLogin(func(string) string) (testLoginSettings, error) { return testLoginSettings{}, nil }

// enable은 prod 빌드에서 아무것도 하지 않습니다.
func (testLoginSettings) enable(*httpapi.API, *auth.Service, *pgxpool.Pool, clock.Clock) {}

//go:build !staging

package cli

import (
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

// prod 빌드(staging tag 없음)에는 테스트 로그인이 없습니다(S24). TEST_LOGIN_SECRET도 읽지 않습니다.

// testLoginSettings는 prod 빌드에서 비어 있습니다.
type testLoginSettings struct{}

// loadTestLogin은 prod 빌드에서 아무것도 읽지 않습니다.
func loadTestLogin(func(string) string) (testLoginSettings, error) { return testLoginSettings{}, nil }

// enable은 prod 빌드에서 아무것도 하지 않습니다.
func (testLoginSettings) enable(*httpapi.API, *auth.Service) {}

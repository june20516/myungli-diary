//go:build !staging

package httpapi

import "net/http"

// prod 빌드(staging tag 없음)의 테스트 로그인 자리입니다. 라우트와 핸들러는 testlogin_staging.go 등 staging 파일에만 있습니다(S24, S125, S131).

// testLoginHolder는 prod 빌드에서 빈 struct입니다. API의 embed 자리만 맞춥니다.
type testLoginHolder struct{}

// testLoginRoutes는 prod 빌드에서 등록할 경로가 없습니다. API에 embed되어 staticRoutes가 부릅니다.
func (testLoginHolder) testLoginRoutes(func(Operation, http.Handler) http.Handler) []staticRoute {
	return nil
}

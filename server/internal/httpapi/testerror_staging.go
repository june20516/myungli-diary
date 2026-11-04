//go:build staging

package httpapi

import (
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// staging 시험 오류(S133)입니다. 알림 정책(O1)이 메일까지 닿는지 확인하려고 일부러 500을 냅니다.
// build tag staging에만 있고 테스트 로그인(S24)의 비밀 헤더로 보호합니다(틀리면 404). REST 계약 밖입니다.

// testErrorPath는 staging 시험 오류 경로입니다. GET만 받습니다.
const testErrorPath = "/test/v1/server-error"

// serveTestError는 비밀을 먼저 확인하고(틀리면 404 route.not_found), GET이면 Error 로그를 남기고 500 internal을 씁니다.
func (a *API) serveTestError(state *testLoginState, w http.ResponseWriter, r *http.Request) {
	if !state.secretMatches(r.Header.Get(testLoginSecretHeader)) {
		writeRouteNotFound(w, r)
		return
	}
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", http.MethodGet)
		problem.Write(w, r, problem.MethodNotAllowed.Problem("Method not allowed"))
		return
	}
	a.logger().ErrorContext(r.Context(), "staging 시험 오류(O1 알림 확인)")
	problem.Write(w, r, problem.Internal.Problem("Internal server error"))
}

//go:build staging

package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// staging 클라이언트 IP 확인(S135)입니다. 공개 주소(Firebase Hosting rewrite)를 거친 요청의 X-Forwarded-For 모양을 보고
// TRUSTED_PROXY_HOPS를 정하려고 둡니다. build tag staging에만 있고 테스트 로그인(S24)의 비밀 헤더로 보호합니다(틀리면 404).
// 부른 사람 자신의 요청 헤더만 돌려주며 로그에 남기지 않습니다. REST 계약 밖입니다.

// testClientIPPath는 staging 클라이언트 IP 확인 경로입니다. GET만 받습니다.
const testClientIPPath = "/test/v1/client-ip"

// testClientIPResponse는 받은 X-Forwarded-For 값(쉼표로 나눈 순서 그대로)과 RemoteAddr입니다.
type testClientIPResponse struct {
	XForwardedFor []string `json:"xForwardedFor"`
	RemoteAddr    string   `json:"remoteAddr"`
}

// serveTestClientIP는 비밀을 먼저 확인하고(틀리면 404 route.not_found), GET이면 받은 헤더를 돌려줍니다.
func (a *API) serveTestClientIP(state *testLoginState, w http.ResponseWriter, r *http.Request) {
	if !state.secretMatches(r.Header.Get(testLoginSecretHeader)) {
		writeRouteNotFound(w, r)
		return
	}
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", http.MethodGet)
		problem.Write(w, r, problem.MethodNotAllowed.Problem("Method not allowed"))
		return
	}
	body := testClientIPResponse{XForwardedFor: []string{}, RemoteAddr: r.RemoteAddr}
	for _, part := range strings.Split(strings.Join(r.Header.Values("X-Forwarded-For"), ","), ",") {
		if part = strings.TrimSpace(part); part != "" {
			body.XForwardedFor = append(body.XForwardedFor, part)
		}
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		writeHandlerError(Deps{Logger: a.logger()}, w, r, err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	writeBody(a.logger(), w, r, encoded)
}

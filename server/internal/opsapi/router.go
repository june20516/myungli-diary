package opsapi

import (
	"log/slog"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/ops"
)

// Deps는 운영 API 핸들러가 쓰는 의존성입니다.
type Deps struct {
	Service   *ops.Service
	Verifier  *Verifier
	Allowlist Allowlist
	Logger    *slog.Logger
}

// NewHandler는 운영 API(/ops/v1/...)의 http.Handler를 만듭니다.
//
// 처리 순서는 본문 상한(64 KiB), 접근 로그, 메서드(POST만), IAP 검증(401, 키 없음 503),
// CSRF 검사(403), 허용 목록(403), 핸들러입니다. 거절은 감사 행을 남기지 않습니다.
// 메서드를 mux 패턴에 넣지 않고 직접 검사하는 것은 405와 404도 JSON으로 답하려는 것입니다.
func NewHandler(deps Deps) http.Handler {
	mux := http.NewServeMux()
	for path, command := range commands() {
		inner := commandHandler(deps, command)
		chain := requirePost(authenticate(deps.Verifier, csrfGuard(authorize(deps.Allowlist, inner))))
		mux.Handle(path, chain)
	}
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		writeError(w, newAPIError(http.StatusNotFound, codeNotFound, "없는 경로입니다"))
	})
	return limitBody(accessLog(deps.Logger, mux))
}

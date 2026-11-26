package opsapi

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// Deps는 운영 API 핸들러가 쓰는 의존성입니다.
type Deps struct {
	Service  *ops.Service
	Verifier Authenticator
	// Operators는 요청마다 운영자 허용 목록을 돌려줍니다. 배포 환경은 FileOperators(Secret 볼륨, TTL 1분)입니다.
	Operators OperatorSource
	Logger    *slog.Logger
	// Clock은 콘텐츠 열람 상한의 시계입니다. 비면 시스템 시계입니다.
	Clock clock.Clock
}

// NewHandler는 운영 API(/ops/v1/...)의 http.Handler를 만듭니다.
//
// 처리 순서는 본문 상한(64 KiB), 접근 로그, 메서드(POST만), IAP 검증(401, 키 없음 503),
// CSRF 검사(403), 허용 목록(403, 목록 읽기 실패 503), 콘텐츠 열람 상한(429, 콘텐츠 세 경로만), 핸들러입니다.
// 허용 목록 밖 거절만 감사 행(denied)을 남기고 그 밖의 거절은 남기지 않습니다.
// 메서드를 mux 패턴에 넣지 않고 직접 검사하는 것은 405와 404도 JSON으로 답하려는 것입니다.
// Service, Verifier, Operators, Logger 중 비어 있는 것이 있으면 기동 때 잡도록 오류를 돌려줍니다.
func NewHandler(deps Deps) (http.Handler, error) {
	if deps.Service == nil || deps.Verifier == nil || deps.Operators == nil || deps.Logger == nil {
		return nil, errors.New("opsapi: Service, Verifier, Operators, Logger가 모두 필요합니다")
	}
	if deps.Clock == nil {
		deps.Clock = clock.System{}
	}
	// 상한은 경로마다가 아니라 콘텐츠 세 경로를 합쳐 세므로 limiter 하나를 나눠 씁니다.
	contentLimiter := newRateLimiter(deps.Clock, contentViewLimit, contentViewWindow)
	mux := http.NewServeMux()
	for path, command := range commands() {
		inner := commandHandler(deps, command)
		if contentPaths[path] {
			inner = limitRate(contentLimiter, inner)
		}
		chain := requirePost(authenticate(deps.Verifier, csrfGuard(authorize(deps, path, inner))))
		mux.Handle(path, chain)
	}
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		writeError(w, newAPIError(http.StatusNotFound, codeNotFound, "없는 경로입니다"))
	})
	return limitBody(accessLog(deps.Logger, mux)), nil
}

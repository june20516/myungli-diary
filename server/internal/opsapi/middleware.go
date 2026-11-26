package opsapi

import (
	"context"
	"errors"
	"log/slog"
	"mime"
	"net/http"
	"time"

	"github.com/june20516/myungli-diary/server/internal/ops"
)

const (
	// maxBodyBytes는 요청 본문 상한(64 KiB)입니다.
	maxBodyBytes = 64 << 10
	// opsHeader는 단순 요청으로는 붙일 수 없는 사용자 정의 헤더입니다(CSRF 방어).
	opsHeader = "X-Myungli-Ops"
)

type actorKey struct{}

// actorFrom은 IAP 검증을 통과한 실행자를 컨텍스트에서 꺼냅니다.
func actorFrom(ctx context.Context) ops.Actor {
	actor, _ := ctx.Value(actorKey{}).(ops.Actor)
	return actor
}

// statusRecorder는 응답 상태 코드를 기억합니다.
type statusRecorder struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (r *statusRecorder) WriteHeader(status int) {
	if !r.wroteHeader {
		r.status, r.wroteHeader = status, true
	}
	r.ResponseWriter.WriteHeader(status)
}

func (r *statusRecorder) Write(p []byte) (int, error) {
	if !r.wroteHeader {
		r.WriteHeader(http.StatusOK)
	}
	return r.ResponseWriter.Write(p)
}

// accessLog는 method, route, status, latencyMs만 남깁니다. 쿼리, 헤더, 본문, 신원은 남기지 않습니다.
// route는 mux가 정한 등록 패턴이라 요청 값이 들어가지 않습니다. mux가 같은 요청 객체에 채우므로 처리 뒤에 읽습니다.
func accessLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now() //nolint:forbidigo // latency 측정은 monotonic clock이 필요합니다.
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		defer func() {
			route := r.Pattern
			if route == "" || route == "/" {
				route = "unmatched"
			}
			logger.InfoContext(r.Context(), "request",
				"method", r.Method,
				"route", route,
				"status", rec.status,
				"latencyMs", time.Since(start).Milliseconds(),
			)
		}()
		next.ServeHTTP(rec, r)
	})
}

// limitBody는 요청 본문을 64 KiB로 제한합니다.
func limitBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
		next.ServeHTTP(w, r)
	})
}

// requirePost는 POST 이외의 메서드를 405로 거절합니다.
func requirePost(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.Header().Set("Allow", http.MethodPost)
			writeError(w, newAPIError(http.StatusMethodNotAllowed, codeInvalidInput, "POST만 받습니다"))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// authenticate는 IAP 서명 헤더를 검증해 실행자를 컨텍스트에 둡니다. 실패는 401, 공개키 없음은 503입니다.
func authenticate(verifier Authenticator, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		identity, err := verifier.Verify(r.Context(), r.Header.Get(AssertionHeader))
		switch {
		case err == nil:
		case errors.Is(err, ErrKeysUnavailable):
			writeError(w, newAPIError(http.StatusServiceUnavailable, codeUnavailable, "인증 키를 구할 수 없습니다. 잠시 뒤 다시 시도하세요"))
			return
		default:
			writeError(w, newAPIError(http.StatusUnauthorized, codeUnauthenticated, "인증되지 않았습니다"))
			return
		}
		ctx := context.WithValue(r.Context(), actorKey{}, ops.Actor{Email: identity.Email, Subject: identity.Subject})
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// csrfGuard는 브라우저의 교차 출처 요청과 쿠키 경로를 막습니다. 이 API는 CLI의 Bearer 호출만 받습니다.
// 사용자 정의 헤더 필수, Content-Type JSON 필수, Origin 거절, Sec-Fetch-Site는 none만 허용합니다.
func csrfGuard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mediaType, _, _ := mime.ParseMediaType(r.Header.Get("Content-Type"))
		site := r.Header.Values("Sec-Fetch-Site")
		if r.Header.Get(opsHeader) != "1" ||
			mediaType != "application/json" ||
			len(r.Header.Values("Origin")) > 0 ||
			(len(site) > 0 && (len(site) != 1 || site[0] != "none")) {
			writeError(w, newAPIError(http.StatusForbidden, codeForbidden, "허용되지 않는 요청입니다"))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// authorize는 허용 목록에 없는 운영자를 403으로 거절합니다.
// 목록을 읽지 못하면 마지막 목록으로 통과시키지 않고 503으로 거절합니다(fail-closed). 403이 아니라 503인 것은
// 운영자에게 "권한이 빠졌다"가 아니라 "서버 쪽 문제라 다시 시도하거나 알려야 한다"를 알리려는 것이고, 어느 쪽이든 명령은 실행되지 않습니다.
// 허용 목록 밖 거절은 IAP가 검증한 실행자와 경로(route, 등록 패턴)를 감사 행(action denied)으로 남깁니다.
// 기록이 실패해도 응답은 그대로 403이고 로그에는 kind만 남깁니다.
// IAP 실패(401)와 CSRF 거절(403)은 이 앞에서 끝나 기록하지 않습니다(신원이 없거나 형식 문제).
func authorize(deps Deps, route string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		allowlist, err := deps.Operators.Operators(r.Context())
		if err != nil {
			deps.Logger.ErrorContext(r.Context(), "운영자 목록 읽기 실패", "kind", "operators_unavailable")
			writeError(w, newAPIError(http.StatusServiceUnavailable, codeUnavailable, "운영자 목록을 읽을 수 없습니다. 잠시 뒤 다시 시도하세요"))
			return
		}
		actor := actorFrom(r.Context())
		if !allowlist.Allows(actor.Email) {
			if err := deps.Service.RecordDenied(r.Context(), actor, route); err != nil {
				deps.Logger.ErrorContext(r.Context(), "거절 기록 실패", "kind", errorKind(err))
			}
			writeError(w, newAPIError(http.StatusForbidden, codeForbidden, "운영 권한이 없습니다"))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// limitRate는 운영자(IAP sub)마다 limiter의 상한을 넘은 요청을 429 rate_limited로 거절합니다.
func limitRate(limiter *rateLimiter, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !limiter.allow(actorFrom(r.Context()).Subject) {
			writeError(w, newAPIError(http.StatusTooManyRequests, codeRateLimited,
				"콘텐츠 열람은 운영자마다 1분에 30건까지입니다. 잠시 뒤 다시 시도하세요"))
			return
		}
		next.ServeHTTP(w, r)
	})
}

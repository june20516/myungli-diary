package httpapi

import (
	"net/http"
	"runtime/debug"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// statusRecorder는 응답 상태와 헤더 전송 여부를 기록합니다.
type statusRecorder struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (s *statusRecorder) WriteHeader(status int) {
	if !s.wroteHeader {
		s.status = status
		s.wroteHeader = true
	}
	s.ResponseWriter.WriteHeader(status)
}

func (s *statusRecorder) Write(b []byte) (int, error) {
	if !s.wroteHeader {
		s.WriteHeader(http.StatusOK)
	}
	return s.ResponseWriter.Write(b)
}

// Unwrap은 http.ResponseController가 원래 writer의 기능(Flush 등)에 닿게 합니다.
func (s *statusRecorder) Unwrap() http.ResponseWriter { return s.ResponseWriter }

// asRecorder는 w가 이미 statusRecorder면 그대로, 아니면 감싸서 돌려줍니다.
func asRecorder(w http.ResponseWriter) *statusRecorder {
	if rec, ok := w.(*statusRecorder); ok {
		return rec
	}
	return &statusRecorder{ResponseWriter: w, status: http.StatusOK}
}

// recoverPanic은 handler의 panic을 잡아 500 problem으로 바꿉니다.
// stack은 로그에만 남기고 응답에는 넣지 않습니다.
func recoverPanic(deps Deps, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec := asRecorder(w)
		defer func() {
			value := recover()
			if value == nil {
				return
			}
			// 클라이언트 연결 중단을 알리는 관례적 panic은 net/http가 처리하도록 다시 던집니다.
			if value == http.ErrAbortHandler {
				panic(value)
			}
			deps.Logger.ErrorContext(r.Context(), "panic 복구", "panic", value, "stack", string(debug.Stack()))
			// 이미 응답을 보냈다면 problem을 덧쓸 수 없습니다.
			if !rec.wroteHeader {
				problem.Write(rec, r, problem.New(http.StatusInternalServerError, "internal", "Internal server error"))
			}
		}()
		next.ServeHTTP(rec, r)
	})
}

// limitBody는 요청 본문을 maxBodyBytes로 제한합니다.
// Content-Length가 상한을 넘으면 핸들러를 부르지 않고 바로 413을 냅니다.
func limitBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ContentLength > maxBodyBytes {
			writeTooLarge(w, r)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
		next.ServeHTTP(w, r)
	})
}

// accessLog는 요청마다 method, route(등록 패턴), status, latencyMs를 남깁니다.
// 실제 경로 값, query, 본문은 개인정보가 섞일 수 있어 남기지 않습니다.
// panic이면 복구 미들웨어가 500을 내므로 그 상태로 기록한 뒤 panic을 다시 던집니다.
func accessLog(deps Deps, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := deps.Clock.Now()
		rec := asRecorder(w)
		panicked := true
		defer func() {
			status := rec.status
			if panicked {
				status = http.StatusInternalServerError
			}
			route := r.Pattern
			if route == "" {
				route = "unmatched"
			}
			deps.Logger.InfoContext(r.Context(), "request",
				"method", r.Method,
				"route", route,
				"status", status,
				"latencyMs", deps.Clock.Now().Sub(start).Milliseconds(),
			)
		}()
		next.ServeHTTP(rec, r)
		panicked = false
	})
}

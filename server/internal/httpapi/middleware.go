package httpapi

import (
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// traceIDHeader는 logging.WithTrace가 응답에 싣는 헤더 이름입니다.
const traceIDHeader = "X-Trace-Id"

// statusRecorder는 응답 상태와 헤더 전송 여부를 기록합니다.
type statusRecorder struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (s *statusRecorder) WriteHeader(status int) {
	// 1xx는 최종 응답이 아니므로 상태로 기록하지 않습니다.
	if !s.wroteHeader && status >= http.StatusOK {
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

// Unwrap은 원래 writer를 돌려줍니다. 이 recorder는 http.Flusher 등을 직접 구현하지 않으므로
// Flush 같은 기능은 w.(http.Flusher)가 아니라 http.NewResponseController(w)로 써야 합니다.
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
// 이미 응답을 보냈다면 problem을 덧쓸 수 없으므로 연결을 끊어 클라이언트가 잘린 응답을 알게 합니다.
func recoverPanic(deps Deps, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec := asRecorder(w)
		defer func() {
			value := recover()
			if value == nil {
				return
			}
			// 연결 중단을 알리는 관례적 panic은 net/http가 처리하도록 다시 던집니다.
			if value == http.ErrAbortHandler { //nolint:errorlint // recover 값은 error가 아닌 any이고 net/http도 ==로 비교합니다
				panic(value)
			}
			deps.Logger.ErrorContext(r.Context(), "panic 복구", "panic", value, "stack", string(debug.Stack()))
			if rec.wroteHeader {
				panic(http.ErrAbortHandler)
			}
			// 핸들러가 설정하다 만 헤더가 problem 응답에 섞이지 않게 비우되 trace id는 유지합니다.
			// header.Del은 키를 정규화하므로 map에 직접 넣은 비정규화 키(예 "x-leak")를 지우지 못해 delete를 씁니다.
			header := rec.Header()
			for key := range header {
				if !strings.EqualFold(key, traceIDHeader) {
					delete(header, key)
				}
			}
			problem.Write(rec, r, problem.Internal.Problem("Internal server error"))
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
// status는 recorder가 본 실제 응답 상태입니다. panic이 전파되면(연결 중단) aborted: true로 남기고,
// 이때 실제로 쓴 상태가 없으면 status는 0입니다. 기록한 뒤 panic을 다시 던져 net/http가 연결을 끊게 합니다.
func accessLog(deps Deps, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now() //nolint:forbidigo // latency 측정은 monotonic clock이 필요합니다(Clock.System은 UTC로 monotonic을 지움)
		rec := asRecorder(w)
		defer func() {
			panicValue := recover()
			aborted := panicValue != nil
			status := rec.status
			if aborted && !rec.wroteHeader {
				status = 0
			}
			route := r.Pattern
			if route == "" {
				route = "unmatched"
			}
			attrs := []any{
				"method", r.Method,
				"route", route,
				"status", status,
				"latencyMs", time.Since(start).Milliseconds(),
			}
			if aborted {
				attrs = append(attrs, "aborted", true)
			}
			deps.Logger.InfoContext(r.Context(), "request", attrs...)
			if aborted {
				panic(panicValue)
			}
		}()
		next.ServeHTTP(rec, r)
	})
}

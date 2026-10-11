// Package httpapi는 HTTP 서버의 공통 뼈대(미들웨어, 오류 응답, 라우팅 보정)를 제공합니다.
package httpapi

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

// maxBodyBytes는 요청 본문 상한(1 MiB)입니다.
const maxBodyBytes = 1 << 20

// Deps는 핸들러가 쓰는 공용 의존성입니다. DB는 DB를 쓰는 핸들러가 생기기 전까지 nil일 수 있습니다.
type Deps struct {
	Logger *slog.Logger
	Clock  clock.Clock
	DB     *pgxpool.Pool
}

// NewHandler는 공통 미들웨어를 입힌 http.Handler를 만듭니다.
// 미들웨어는 바깥부터 trace, panic 복구, 본문 상한, 접근 로그 순서입니다.
// routes가 nil이 아니면 mux에 경로를 등록하게 합니다.
func NewHandler(deps Deps, routes func(mux *http.ServeMux)) http.Handler {
	mux := http.NewServeMux()
	registerHealthz(mux)
	if routes != nil {
		routes(mux)
	}

	var handler http.Handler = newRouter(mux)
	handler = accessLog(deps, handler)
	handler = limitBody(handler)
	handler = recoverPanic(deps, handler)
	return logging.WithTrace(handler)
}

// registerHealthz는 GET /healthz를 등록합니다. OpenAPI 생성 라우트로 옮길 때 이 함수만 지웁니다.
func registerHealthz(mux *http.ServeMux) {
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})
}

// newRouter는 ServeMux가 내는 평문 404·405를 problem+json으로 바꿉니다.
func newRouter(mux *http.ServeMux) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler, pattern := mux.Handler(r)
		if pattern != "" {
			mux.ServeHTTP(w, r)
			return
		}

		// 패턴이 없으면 ServeMux가 고른 핸들러(404, 405, 경로 정리 redirect)의 상태만 확인합니다.
		probe := &probeWriter{header: http.Header{}}
		handler.ServeHTTP(probe, r)
		switch probe.status {
		case http.StatusNotFound:
			problem.Write(w, r, problem.New(http.StatusNotFound, "route.not_found", "Route not found"))
		case http.StatusMethodNotAllowed:
			w.Header().Set("Allow", probe.header.Get("Allow"))
			problem.Write(w, r, problem.New(http.StatusMethodNotAllowed, "method.not_allowed", "Method not allowed"))
		default:
			handler.ServeHTTP(w, r)
		}
	})
}

// probeWriter는 ServeMux 내장 핸들러의 상태와 헤더만 모으고 본문은 버립니다.
type probeWriter struct {
	header http.Header
	status int
}

func (p *probeWriter) Header() http.Header { return p.header }
func (p *probeWriter) WriteHeader(status int) {
	if p.status == 0 {
		p.status = status
	}
}
func (p *probeWriter) Write(b []byte) (int, error) {
	p.WriteHeader(http.StatusOK)
	return len(b), nil
}

// DecodeJSON은 요청 본문을 v로 읽습니다. 실패하면 problem 응답을 쓰고 false를 돌려줍니다.
// 본문이 상한을 넘으면 413 request.too_large, JSON이 아니면 400 request.invalid_json입니다.
func DecodeJSON(w http.ResponseWriter, r *http.Request, v any) bool {
	err := json.NewDecoder(r.Body).Decode(v)
	if err == nil {
		return true
	}
	var tooLarge *http.MaxBytesError
	if errors.As(err, &tooLarge) {
		writeTooLarge(w, r)
		return false
	}
	problem.Write(w, r, problem.New(http.StatusBadRequest, "request.invalid_json", "Request body is not valid JSON"))
	return false
}

func writeTooLarge(w http.ResponseWriter, r *http.Request) {
	problem.Write(w, r, problem.New(http.StatusRequestEntityTooLarge, "request.too_large", "Request body is too large"))
}

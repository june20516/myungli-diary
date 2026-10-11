package httpapi_test

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

// newTestHandler는 로그를 buffer에 모으는 Handler를 만듭니다.
func newTestHandler(t *testing.T, routes func(mux *http.ServeMux)) (http.Handler, *bytes.Buffer) {
	t.Helper()
	logs := &bytes.Buffer{}
	deps := httpapi.Deps{
		Logger: logging.New(logs, slog.LevelDebug, ""),
		Clock:  clocktest.New(time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC)),
	}
	return httpapi.NewHandler(deps, routes), logs
}

func serve(handler http.Handler, req *http.Request) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec
}

func decodeProblem(t *testing.T, rec *httptest.ResponseRecorder) problem.Problem {
	t.Helper()
	if got := rec.Header().Get("Content-Type"); got != "application/problem+json" {
		t.Errorf("Content-Type = %q, want application/problem+json", got)
	}
	var p problem.Problem
	if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil {
		t.Fatalf("problem 파싱: %v, body = %q", err, rec.Body.String())
	}
	if p.TraceID == "" {
		t.Error("traceId가 비어 있습니다")
	}
	if want := "https://api.myungli.app/problems/" + p.Code; p.Type != want {
		t.Errorf("type = %q, want %q", p.Type, want)
	}
	return p
}

func TestHandler_Healthz(t *testing.T) {
	handler, _ := newTestHandler(t, nil)

	rec := serve(handler, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"status":"ok"}` {
		t.Errorf("body = %q", got)
	}
}

func TestHandler_UnknownRoute(t *testing.T) {
	handler, _ := newTestHandler(t, nil)

	rec := serve(handler, httptest.NewRequest(http.MethodGet, "/nope", nil))

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "route.not_found" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestHandler_MethodNotAllowed(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /v1/x", func(w http.ResponseWriter, _ *http.Request) {})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodDelete, "/v1/x", nil))

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want 405", rec.Code)
	}
	if got := rec.Header().Get("Allow"); !strings.Contains(got, "GET") {
		t.Errorf("Allow = %q, want GET 포함", got)
	}
	if p := decodeProblem(t, rec); p.Code != "method.not_allowed" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestHandler_PanicRecovered(t *testing.T) {
	handler, logs := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /boom", func(http.ResponseWriter, *http.Request) {
			panic("secret-internal-detail")
		})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodGet, "/boom", nil))

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "internal" {
		t.Errorf("code = %q", p.Code)
	}
	if strings.Contains(rec.Body.String(), "secret-internal-detail") || strings.Contains(rec.Body.String(), "goroutine") {
		t.Errorf("응답에 panic 내용이나 stack이 노출됨: %q", rec.Body.String())
	}
	if !strings.Contains(logs.String(), "stack") || !strings.Contains(logs.String(), "goroutine") {
		t.Errorf("로그에 stack이 없습니다: %q", logs.String())
	}
}

func TestHandler_BodyTooLarge(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/x", func(w http.ResponseWriter, r *http.Request) {
			var v map[string]any
			if !httpapi.DecodeJSON(w, r, &v) {
				return
			}
			w.WriteHeader(http.StatusNoContent)
		})
	})
	// Content-Length를 알 수 없는 스트림으로 보내 읽는 도중 상한에 걸리게 합니다.
	body := io.MultiReader(strings.NewReader(`{"a":"`), strings.NewReader(strings.Repeat("x", 5<<20)), strings.NewReader(`"}`))
	req := httptest.NewRequest(http.MethodPost, "/v1/x", body)
	req.ContentLength = -1

	rec := serve(handler, req)

	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want 413", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "request.too_large" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestHandler_BodyTooLargeByContentLength(t *testing.T) {
	called := false
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/x", func(http.ResponseWriter, *http.Request) { called = true })
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/x", strings.NewReader(strings.Repeat("x", 5<<20)))

	rec := serve(handler, req)

	if rec.Code != http.StatusRequestEntityTooLarge || called {
		t.Fatalf("status = %d, called = %v, want 413 and 핸들러 미호출", rec.Code, called)
	}
	if p := decodeProblem(t, rec); p.Code != "request.too_large" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestDecodeJSON_InvalidJSON(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/x", func(w http.ResponseWriter, r *http.Request) {
			var v map[string]any
			httpapi.DecodeJSON(w, r, &v)
		})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodPost, "/v1/x", strings.NewReader("{not json")))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "request.invalid_json" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestHandler_AccessLog_UsesRoutePatternNotActualPath(t *testing.T) {
	handler, logs := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /v1/diaries/{date}", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusTeapot)
		})
	})

	serve(handler, httptest.NewRequest(http.MethodGet, "/v1/diaries/1990-05-17?token=secret", nil))

	var entry map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(logs.Bytes()), &entry); err != nil {
		t.Fatalf("로그 파싱: %v, logs = %q", err, logs.String())
	}
	if entry["method"] != "GET" || entry["route"] != "GET /v1/diaries/{date}" || entry["status"] != float64(418) {
		t.Errorf("접근 로그 필드 = %v", entry)
	}
	if _, ok := entry["latencyMs"]; !ok {
		t.Errorf("latencyMs 없음: %v", entry)
	}
	if strings.Contains(logs.String(), "1990-05-17") || strings.Contains(logs.String(), "secret") {
		t.Errorf("로그에 실제 경로 값이나 query가 남음: %q", logs.String())
	}
}

func TestHandler_TraceHeaderOnResponse(t *testing.T) {
	handler, _ := newTestHandler(t, nil)

	rec := serve(handler, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rec.Header().Get("X-Trace-Id") == "" {
		t.Error("X-Trace-Id 헤더가 없습니다")
	}
}

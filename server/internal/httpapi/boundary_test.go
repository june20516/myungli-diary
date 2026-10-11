package httpapi_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

func TestDecodeJSON_TrailingData(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/x", func(w http.ResponseWriter, r *http.Request) {
			var v map[string]any
			httpapi.DecodeJSON(w, r, &v)
		})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodPost, "/v1/x", strings.NewReader(`{} {}`)))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "request.malformed" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestDecodeJSON_AcceptsSingleValueWithTrailingWhitespace(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/x", func(w http.ResponseWriter, r *http.Request) {
			var v map[string]any
			if httpapi.DecodeJSON(w, r, &v) {
				w.WriteHeader(http.StatusNoContent)
			}
		})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodPost, "/v1/x", strings.NewReader("{\"a\":1}\n")))

	if rec.Code != http.StatusNoContent {
		t.Errorf("status = %d, want 204", rec.Code)
	}
}

// lastAccessLog는 로그에서 마지막 접근 로그 항목을 찾아 돌려줍니다.
func lastAccessLog(t *testing.T, logs *bytes.Buffer) map[string]any {
	t.Helper()
	var found map[string]any
	for _, line := range strings.Split(strings.TrimSpace(logs.String()), "\n") {
		var entry map[string]any
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			t.Fatalf("로그 파싱: %v, line = %q", err, line)
		}
		if entry["message"] == "request" {
			found = entry
		}
	}
	if found == nil {
		t.Fatalf("접근 로그가 없습니다: %q", logs.String())
	}
	return found
}

func TestHandler_AccessLog_RecordsActualStatusOfPanicAnd413(t *testing.T) {
	handler, logs := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /boom", func(http.ResponseWriter, *http.Request) { panic("x") })
		mux.HandleFunc("POST /v1/x", func(http.ResponseWriter, *http.Request) {})
	})

	serve(handler, httptest.NewRequest(http.MethodGet, "/boom", nil))
	if got := lastAccessLog(t, logs)["status"]; got != float64(500) {
		t.Errorf("panic 요청 로그 status = %v, want 500", got)
	}

	serve(handler, httptest.NewRequest(http.MethodPost, "/v1/x", strings.NewReader(strings.Repeat("x", 5<<20))))
	if got := lastAccessLog(t, logs)["status"]; got != float64(413) {
		t.Errorf("413 요청 로그 status = %v, want 413", got)
	}
}

func TestHandler_PanicBeforeHeader_ClearsHeadersButKeepsTraceID(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /boom", func(w http.ResponseWriter, _ *http.Request) {
			w.Header().Set("X-Leak", "partial")
			w.Header().Set("Set-Cookie", "a=b")
			panic("x")
		})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodGet, "/boom", nil))

	if rec.Header().Get("X-Leak") != "" || rec.Header().Get("Set-Cookie") != "" {
		t.Errorf("핸들러가 설정한 헤더가 남음: %v", rec.Header())
	}
	if rec.Header().Get("X-Trace-Id") == "" {
		t.Error("X-Trace-Id가 지워졌습니다")
	}
	if p := decodeProblem(t, rec); p.Code != "internal" {
		t.Errorf("code = %q", p.Code)
	}
}

// servePanics는 요청 처리 중 전파된 panic 값을 돌려줍니다.
func servePanics(handler http.Handler, req *http.Request) (recovered any) {
	defer func() { recovered = recover() }()
	handler.ServeHTTP(httptest.NewRecorder(), req)
	return nil
}

func TestHandler_PanicAfterHeader_AbortsConnection(t *testing.T) {
	handler, logs := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /boom", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("partial"))
			panic("x")
		})
	})

	got := servePanics(handler, httptest.NewRequest(http.MethodGet, "/boom", nil))

	if got != http.ErrAbortHandler {
		t.Errorf("전파된 panic = %v, want http.ErrAbortHandler", got)
	}
	if !strings.Contains(logs.String(), "stack") {
		t.Errorf("로그에 stack이 없습니다: %q", logs.String())
	}
}

func TestHandler_ErrAbortHandlerIsRethrownWithoutErrorLog(t *testing.T) {
	handler, logs := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /abort", func(http.ResponseWriter, *http.Request) { panic(http.ErrAbortHandler) })
	})

	got := servePanics(handler, httptest.NewRequest(http.MethodGet, "/abort", nil))

	if got != http.ErrAbortHandler {
		t.Errorf("전파된 panic = %v, want http.ErrAbortHandler", got)
	}
	if strings.Contains(logs.String(), "panic 복구") {
		t.Errorf("ErrAbortHandler는 오류로 기록하지 않아야 합니다: %q", logs.String())
	}
}

func TestHandler_HeadHealthz(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequest(http.MethodHead, "/healthz", nil))

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", rec.Code)
	}
}

func TestHandler_MethodNotAllowed_AllowHeaderExactValue(t *testing.T) {
	handler, _ := newTestHandler(t, func(mux *http.ServeMux) {
		mux.HandleFunc("GET /v1/x", func(http.ResponseWriter, *http.Request) {})
	})

	rec := serve(handler, httptest.NewRequest(http.MethodDelete, "/v1/x", nil))

	if got := rec.Header().Get("Allow"); got != "GET, HEAD" {
		t.Errorf("Allow = %q, want %q", got, "GET, HEAD")
	}
}

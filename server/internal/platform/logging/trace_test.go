package logging_test

import (
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

var traceIDPattern = regexp.MustCompile(`^[0-9a-f]{32}$`)

func serveWithTrace(t *testing.T, traceparent string) (string, *httptest.ResponseRecorder) {
	t.Helper()
	var ctxTraceID string
	handler := logging.WithTrace(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctxTraceID = logging.TraceID(r.Context())
	}))
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	if traceparent != "" {
		req.Header.Set("traceparent", traceparent)
	}
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return ctxTraceID, rec
}

func TestWithTrace_ParsesTraceparent(t *testing.T) {
	got, rec := serveWithTrace(t, "00-"+sampleTraceID+"-00f067aa0ba902b7-01")

	if got != sampleTraceID {
		t.Errorf("TraceID = %q, want %q", got, sampleTraceID)
	}
	if h := rec.Header().Get("X-Trace-Id"); h != sampleTraceID {
		t.Errorf("X-Trace-Id = %q, want %q", h, sampleTraceID)
	}
}

func TestWithTrace_GeneratesWhenMissingOrInvalid(t *testing.T) {
	invalid := []string{
		"",
		"garbage",
		"00-" + sampleTraceID + "-00f067aa0ba902b7",
		"00-4BF92F3577B34DA6A3CE929D0E0E4736-00f067aa0ba902b7-01",
		"00-00000000000000000000000000000000-00f067aa0ba902b7-01",
		"00-" + sampleTraceID + "-0000000000000000-01",
		"00-" + sampleTraceID + "-00f067aa0ba902b7-01-extra",
		"00-" + sampleTraceID[:31] + "g-00f067aa0ba902b7-01",
	}
	seen := map[string]bool{}
	for _, traceparent := range invalid {
		got, rec := serveWithTrace(t, traceparent)
		if !traceIDPattern.MatchString(got) {
			t.Errorf("traceparent %q: TraceID = %q, 32자리 소문자 hex가 아닙니다", traceparent, got)
		}
		if got == sampleTraceID {
			t.Errorf("traceparent %q: 잘못된 입력에서 값을 가져왔습니다", traceparent)
		}
		if h := rec.Header().Get("X-Trace-Id"); h != got {
			t.Errorf("traceparent %q: X-Trace-Id = %q, want %q", traceparent, h, got)
		}
		seen[got] = true
	}
	if len(seen) != len(invalid) {
		t.Errorf("생성된 trace id는 서로 달라야 합니다: %d개 중 고유 %d개", len(invalid), len(seen))
	}
}

func TestTraceID_EmptyWithoutValue(t *testing.T) {
	if got := logging.TraceID(t.Context()); got != "" {
		t.Errorf("TraceID = %q, want empty", got)
	}
}

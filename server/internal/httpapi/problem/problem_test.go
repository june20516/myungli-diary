package problem_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

func newRequest(traceID string) *http.Request {
	r := httptest.NewRequest(http.MethodGet, "/x", nil)
	return r.WithContext(logging.ContextWithTraceID(r.Context(), traceID))
}

func TestWrite_SetsHeadersAndFields(t *testing.T) {
	rec := httptest.NewRecorder()
	p := problem.New(422, "diary.future_date", "Diary date is in the future")

	problem.Write(rec, newRequest("abc123"), p)

	if rec.Code != 422 {
		t.Errorf("status = %d, want 422", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/problem+json" {
		t.Errorf("Content-Type = %q", got)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("본문 파싱: %v", err)
	}
	want := map[string]any{
		"type":    "https://api.myungli.app/problems/diary.future_date",
		"title":   "Diary date is in the future",
		"status":  float64(422),
		"code":    "diary.future_date",
		"traceId": "abc123",
	}
	for key, value := range want {
		if body[key] != value {
			t.Errorf("%s = %v, want %v", key, body[key], value)
		}
	}
	for _, key := range []string{"detail", "errors"} {
		if _, ok := body[key]; ok {
			t.Errorf("빈 %s는 내보내지 않아야 합니다", key)
		}
	}
}

func TestWrite_IncludesDetailAndErrors(t *testing.T) {
	rec := httptest.NewRecorder()
	p := problem.New(400, "request.invalid", "Invalid request")
	p.Detail = "see errors"
	p.Errors = []problem.FieldError{{Field: "date", Code: "required"}}

	problem.Write(rec, newRequest("t"), p)

	var body problem.Problem
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("본문 파싱: %v", err)
	}
	if body.Detail != "see errors" || len(body.Errors) != 1 || body.Errors[0].Field != "date" {
		t.Errorf("body = %+v", body)
	}
}

func TestWrite_401AddsWWWAuthenticate(t *testing.T) {
	rec := httptest.NewRecorder()

	problem.Write(rec, newRequest("t"), problem.New(401, "auth.invalid_token", "Invalid token"))

	if got := rec.Header().Get("WWW-Authenticate"); got != `Bearer error="invalid_token"` {
		t.Errorf("WWW-Authenticate = %q", got)
	}
}

func TestWrite_Non401OmitsWWWAuthenticate(t *testing.T) {
	rec := httptest.NewRecorder()

	problem.Write(rec, newRequest("t"), problem.New(403, "auth.forbidden", "Forbidden"))

	if got := rec.Header().Get("WWW-Authenticate"); got != "" {
		t.Errorf("WWW-Authenticate = %q, want empty", got)
	}
}

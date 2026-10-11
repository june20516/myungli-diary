// Package problem은 RFC 9457 application/problem+json 오류 응답을 만듭니다.
package problem

import (
	"encoding/json"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

const (
	contentType = "application/problem+json"
	typePrefix  = "https://api.myungli.app/problems/"
)

// FieldError는 검증에 실패한 필드 하나입니다.
type FieldError struct {
	Field string `json:"field"`
	Code  string `json:"code"`
}

// Problem은 오류 응답 본문입니다. 빈 Detail과 Errors는 내보내지 않습니다.
type Problem struct {
	Type    string       `json:"type"`
	Title   string       `json:"title"`
	Status  int          `json:"status"`
	Code    string       `json:"code"`
	TraceID string       `json:"traceId"`
	Detail  string       `json:"detail,omitempty"`
	Errors  []FieldError `json:"errors,omitempty"`
}

// New는 상태, 오류 코드, 제목으로 Problem을 만듭니다. Type과 TraceID는 Write가 채웁니다.
func New(status int, code, title string) Problem {
	return Problem{Status: status, Code: code, Title: title}
}

// Write는 Problem을 응답으로 씁니다. Type은 코드로, TraceID는 요청 ctx에서 채웁니다.
// 상태가 401이면 WWW-Authenticate 헤더도 붙입니다.
func Write(w http.ResponseWriter, r *http.Request, p Problem) {
	p.Type = typePrefix + p.Code
	p.TraceID = logging.TraceID(r.Context())

	w.Header().Set("Content-Type", contentType)
	if p.Status == http.StatusUnauthorized {
		w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
	}
	w.WriteHeader(p.Status)
	// 헤더를 이미 보냈으므로 쓰기 실패(연결 끊김)는 호출자가 할 수 있는 일이 없습니다.
	_ = json.NewEncoder(w).Encode(p)
}

// Package problem은 RFC 9457 application/problem+json 오류 응답을 만듭니다.
package problem

import (
	"encoding/json"
	"net/http"
	"time"

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
	// MergeToken과 ExpiresAt은 auth.identity_in_use 409에만 담는 합치기 토큰과 그 만료 시각입니다.
	MergeToken string     `json:"mergeToken,omitempty"`
	ExpiresAt  *time.Time `json:"expiresAt,omitempty"`
}

// New는 상태, 오류 코드, 제목으로 Problem을 만듭니다. Type과 TraceID는 Write가 채웁니다.
func New(status int, code, title string) Problem {
	return Problem{Status: status, Code: code, Title: title}
}

// Write는 Problem을 응답으로 씁니다. Type은 코드로, TraceID는 요청 ctx에서 채웁니다.
// WWW-Authenticate는 붙이지 않습니다. bearer 인증 실패는 WriteBearerChallenge를 씁니다.
func Write(w http.ResponseWriter, r *http.Request, p Problem) {
	p.Type = typePrefix + p.Code
	p.TraceID = logging.TraceID(r.Context())

	w.Header().Set("Content-Type", contentType)
	w.WriteHeader(p.Status)
	// 헤더를 이미 보냈으므로 쓰기 실패(연결 끊김)는 호출자가 할 수 있는 일이 없습니다.
	_ = json.NewEncoder(w).Encode(p)
}

// WriteBearerChallenge는 bearer 인증에 실패한 요청의 401 Problem을 RFC 6750 WWW-Authenticate 헤더와 함께 씁니다.
// 계약상 이 헤더는 bearer 요청의 401에만 붙으므로, webhook 서명 실패 같은 그 밖의 401은 Write를 씁니다.
func WriteBearerChallenge(w http.ResponseWriter, r *http.Request, p Problem) {
	w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
	Write(w, r, p)
}

package logging

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"
)

const (
	traceparentHeader = "traceparent"
	traceIDHeader     = "X-Trace-Id"

	traceIDLength  = 32
	parentIDLength = 16
	flagsLength    = 2
)

type traceIDKey struct{}

// ContextWithTraceID는 trace id를 담은 ctx를 돌려줍니다.
func ContextWithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, traceIDKey{}, traceID)
}

// TraceID는 ctx에 담긴 trace id를 돌려줍니다. 없으면 빈 문자열입니다.
func TraceID(ctx context.Context) string {
	traceID, _ := ctx.Value(traceIDKey{}).(string)
	return traceID
}

// WithTrace는 요청마다 trace id를 정해 ctx와 응답 헤더 X-Trace-Id에 담는 미들웨어입니다.
// W3C traceparent가 올바르면 그 trace id를 쓰고, 없거나 형식이 틀리면 새로 만듭니다.
func WithTrace(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		traceID, ok := parseTraceparent(r.Header.Get(traceparentHeader))
		if !ok {
			traceID = newTraceID()
		}
		w.Header().Set(traceIDHeader, traceID)
		next.ServeHTTP(w, r.WithContext(ContextWithTraceID(r.Context(), traceID)))
	})
}

// parseTraceparent는 "00-<32hex>-<16hex>-<2hex>" 형식에서 trace id를 꺼냅니다.
// hex는 소문자만 받고, trace id와 parent id가 모두 0이면 W3C 규격상 무효입니다.
func parseTraceparent(header string) (string, bool) {
	parts := strings.Split(header, "-")
	if len(parts) != 4 || parts[0] != "00" {
		return "", false
	}
	traceID, parentID, flags := parts[1], parts[2], parts[3]
	if !isLowerHex(traceID, traceIDLength) || !isLowerHex(parentID, parentIDLength) || !isLowerHex(flags, flagsLength) {
		return "", false
	}
	if isAllZero(traceID) || isAllZero(parentID) {
		return "", false
	}
	return traceID, true
}

func isLowerHex(s string, length int) bool {
	if len(s) != length {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') {
			return false
		}
	}
	return true
}

func isAllZero(s string) bool {
	return strings.Trim(s, "0") == ""
}

// newTraceID는 crypto/rand로 32자리 소문자 hex trace id를 만듭니다.
func newTraceID() string {
	// rand.Read는 Go 1.24부터 실패 시 프로세스를 종료하므로 오류를 따로 다루지 않습니다.
	buf := make([]byte, traceIDLength/2)
	rand.Read(buf)
	if isAllZero(hex.EncodeToString(buf)) {
		buf[0] = 1
	}
	return hex.EncodeToString(buf)
}

package httpapi_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

func TestClientIP(t *testing.T) {
	tests := []struct {
		name        string
		forwarded   []string
		remoteAddr  string
		trustedHops int
		want        string
	}{
		{"한 홉이면 오른쪽 끝 값(앞의 위조 값 무시)", []string{"1.1.1.1, 203.0.113.7"}, "10.0.0.1:4000", 1, "203.0.113.7"},
		{"헤더 없으면 RemoteAddr 호스트", nil, "10.0.0.1:4000", 1, "10.0.0.1"},
		{"홉보다 짧은 헤더면 RemoteAddr", []string{"203.0.113.7"}, "10.0.0.1:4000", 2, "10.0.0.1"},
		{"두 홉이면 오른쪽에서 둘째", []string{"1.1.1.1, 203.0.113.7, 10.0.0.9"}, "10.0.0.1:4000", 2, "203.0.113.7"},
		{"홉 0이면 헤더를 믿지 않음", []string{"203.0.113.7"}, "10.0.0.1:4000", 0, "10.0.0.1"},
		{"헤더가 여러 줄이어도 이은 것처럼", []string{"1.1.1.1", "203.0.113.7"}, "10.0.0.1:4000", 1, "203.0.113.7"},
		{"IP가 아닌 값이면 RemoteAddr", []string{"garbage"}, "10.0.0.1:4000", 1, "10.0.0.1"},
		{"IPv6는 정규화", []string{"2001:DB8::1"}, "10.0.0.1:4000", 1, "2001:db8::1"},
		{"RemoteAddr의 IPv6 호스트", nil, "[2001:db8::2]:4000", 1, "2001:db8::2"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/", nil)
			req.RemoteAddr = tt.remoteAddr
			for _, v := range tt.forwarded {
				req.Header.Add("X-Forwarded-For", v)
			}
			assert.Equal(t, tt.want, httpapi.ClientIP(req, tt.trustedHops))
		})
	}
}

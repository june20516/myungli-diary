package provider

import (
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestNewJWKSClient_TimeoutCapsAtRequestTimeout(t *testing.T) {
	tests := []struct {
		name string
		base time.Duration
		want time.Duration
	}{
		{"원본 Timeout 없음", 0, requestTimeout},
		{"원본이 더 김", time.Minute, requestTimeout},
		{"원본이 더 짧음", time.Second, time.Second},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			base := &http.Client{Timeout: tt.base}

			got := newJWKSClient(base)

			assert.Equal(t, tt.want, got.Timeout)
			assert.Equal(t, tt.base, base.Timeout, "원본 client는 바꾸지 않습니다")
			assert.IsType(t, jwksTransport{}, got.Transport)
		})
	}
}

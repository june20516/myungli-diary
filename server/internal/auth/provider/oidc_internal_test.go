package provider

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

func TestJWKSFailureReason(t *testing.T) {
	// client Timeout 오류는 실제 http.Client로 만듭니다. 이 오류는 context.DeadlineExceeded로도 판별됩니다.
	release := make(chan struct{})
	hanging := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { <-release }))
	t.Cleanup(hanging.Close)
	t.Cleanup(func() { close(release) })
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, hanging.URL, nil)
	require.NoError(t, err)
	resp, clientTimeoutErr := (&http.Client{Timeout: 50 * time.Millisecond}).Do(req)
	if resp != nil {
		closeBody(resp.Body)
	}
	require.Error(t, clientTimeoutErr)
	require.ErrorIs(t, clientTimeoutErr, context.DeadlineExceeded, "순서가 중요한 이유: client Timeout도 DeadlineExceeded입니다")

	tests := []struct {
		name   string
		err    error
		want   string
		wantOK bool
	}{
		{"jwksFetchError", fmt.Errorf("x: %w", &jwksFetchError{reason: "상태 500"}), "상태 500", true},
		{"client timeout", clientTimeoutErr, "client timeout", true},
		{"요청 deadline", fmt.Errorf("x: %w", context.DeadlineExceeded), "요청 deadline 초과", true},
		{"요청 취소", context.Canceled, "요청 취소", true},
		{"JWKS와 무관한 오류", errors.New("bad signature"), "", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := jwksFailureReason(tt.err)

			assert.Equal(t, tt.wantOK, ok)
			assert.Equal(t, tt.want, got)
		})
	}
}

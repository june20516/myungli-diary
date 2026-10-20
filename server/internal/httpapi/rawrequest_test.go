package httpapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// runStrict는 middleware를 operationID로 감싼 핸들러를 실행하고 핸들러가 ctx에서 읽은 RawRequest를 돌려줍니다.
func runStrict(t *testing.T, operationID string, req *http.Request) RawRequest {
	t.Helper()
	var got RawRequest
	handler := func(ctx context.Context, _ http.ResponseWriter, _ *http.Request, _ any) (any, error) {
		got = RawRequestFrom(ctx)
		return nil, nil
	}
	wrapped := withRawRequest("revenuecatWebhook", "admobRewardCallback")(handler, operationID)
	_, err := wrapped(req.Context(), httptest.NewRecorder(), req, nil)
	require.NoError(t, err)
	return got
}

func TestWithRawRequest_TargetOperations_PutAuthorizationAndRawQuery(t *testing.T) {
	// 생성 코드는 operationID를 Go 이름(첫 글자 대문자)으로 넘깁니다.
	for _, operationID := range []string{"RevenuecatWebhook", "AdmobRewardCallback", "revenuecatWebhook"} {
		t.Run(operationID, func(t *testing.T) {
			req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/webhooks/x?b=2&a=%2B1&signature=s%3D", nil)
			req.Header.Set("Authorization", "Bearer secret")

			got := runStrict(t, operationID, req)

			assert.Equal(t, RawRequest{Authorization: "Bearer secret", RawQuery: "b=2&a=%2B1&signature=s%3D"}, got)
		})
	}
}

func TestWithRawRequest_OtherOperations_Empty(t *testing.T) {
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me?x=1", nil)
	req.Header.Set("Authorization", "Bearer token")

	got := runStrict(t, "GetMe", req)

	assert.Equal(t, RawRequest{}, got)
}

func TestRawRequestFrom_NoValue_Empty(t *testing.T) {
	assert.Equal(t, RawRequest{}, RawRequestFrom(t.Context()))
}

package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

// runStrict는 middleware를 operationID로 감싼 핸들러를 실행하고 핸들러가 ctx에서 읽은 RawRequest를 돌려줍니다.
func runStrict(t *testing.T, operationID string, req *http.Request) RawRequest {
	t.Helper()
	var got RawRequest
	handler := func(ctx context.Context, _ http.ResponseWriter, _ *http.Request, _ any) (any, error) {
		got = RawRequestFrom(ctx)
		return nil, nil
	}
	wrapped := withRawRequest(operationRevenuecatWebhook, operationAdmobRewardCallback)(handler, operationID)
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

// TestWithRawRequest_RegisteredOperationsMatchGeneratedIDs는 register.go가 넘기는 상수가
// 생성 코드가 strict middleware에 넘기는 operationID(Go 이름)와 맞는지 확인합니다.
// 생성 코드의 strictHandler는 operationID 자리에 GetSpec의 operationId(Go 이름)와 같은 문자열을 넘깁니다.
func TestWithRawRequest_RegisteredOperationsMatchGeneratedIDs(t *testing.T) {
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	generated := map[string]string{}
	for _, item := range spec.Paths.Map() {
		for _, op := range item.Operations() {
			generated[contractOperationID(op.OperationID)] = op.OperationID
		}
	}

	for _, operation := range []string{operationRevenuecatWebhook, operationAdmobRewardCallback} {
		goName, ok := generated[operation]
		require.True(t, ok, "계약에 %q operation이 없습니다", operation)
		req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/x?q=1", nil)
		assert.Equal(t, "q=1", runStrict(t, goName, req).RawQuery, "%s(%s)에 RawRequest가 들어가야 합니다", operation, goName)
	}
}

// rawQueryCapture는 admobRewardCallback에서 핸들러가 받은 RawRequest를 기록하는 구현입니다.
type rawQueryCapture struct {
	Unimplemented
	got RawRequest
}

func (c *rawQueryCapture) AdmobRewardCallback(ctx context.Context, _ gen.AdmobRewardCallbackRequestObject) (gen.AdmobRewardCallbackResponseObject, error) {
	c.got = RawRequestFrom(ctx)
	return gen.AdmobRewardCallback200Response{}, nil
}

// TestRegisterAPI_AdmobRewardCallbackReceivesRawQuery는 RegisterAPI 경로 전체(계약 검증·strict 생성 코드)를 거쳐
// admobRewardCallback 핸들러가 원본 쿼리를 바이트 그대로 받는지 확인합니다.
func TestRegisterAPI_AdmobRewardCallbackReceivesRawQuery(t *testing.T) {
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	logger := slog.New(slog.DiscardHandler)
	deps := Deps{Logger: logger, Clock: clocktest.New(time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC))}
	routes := Routes{
		Spec:     spec,
		Validate: ValidateRequests(spec, logger),
		Authenticate: func(_ Operation, next http.Handler) http.Handler {
			return next
		},
	}
	impl := &rawQueryCapture{}
	mux := http.NewServeMux()
	RegisterAPI(mux, impl, deps, routes)

	rawQuery := "ad_network=1&key_id=3335741209&signature=MEUCIQ%3D&timestamp=1507770365237823&transaction_id=t%2Bx&user_id=a+b"
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/webhooks/admob-ssv?"+rawQuery, nil)
	req.Header.Set("Authorization", "Bearer ssv")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, RawRequest{Authorization: "Bearer ssv", RawQuery: rawQuery}, impl.got)
}

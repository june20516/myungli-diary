package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// fakeEntitlements는 EntitlementService 대역입니다.
type fakeEntitlements struct {
	status billing.Status
	err    error
}

func (f fakeEntitlements) Status(context.Context, uuid.UUID) (billing.Status, error) {
	return f.status, f.err
}

// activeStatus는 광고 제거권과 `source`가 `ad_free_pass`인 insight가 모두 유효한 상태입니다.
func activeStatus() (billing.Status, time.Time) {
	expires := handlerNow.AddDate(0, 1, 0)
	return billing.Status{
		AdFree:  billing.State{Active: true, ExpiresAt: &expires},
		Insight: billing.State{Active: true, ExpiresAt: &expires, Source: billing.SourceAdFreePass},
	}, expires
}

func getJSON(t *testing.T, api *httpapi.API, path string) (*httptest.ResponseRecorder, *http.Request, func(*httptest.ResponseRecorder, *http.Request)) {
	t.Helper()
	handler, spec := newHandlerAPI(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, path, nil)
	rec := serve(handler, req)
	return rec, req, func(rec *httptest.ResponseRecorder, req *http.Request) { expectContractResponse(t, spec, req, rec) }
}

func meAPI(ent httpapi.EntitlementService) *httpapi.API {
	accts := &fakeAccounts{me: account.Me{AccountID: fixedAccountID, Access: account.Access{Status: account.StatusActive}}}
	return &httpapi.API{Accounts: accts, Profiles: &fakeProfiles{}, Entitlements: ent}
}

func TestGetMe_FillsEntitlementsFromService(t *testing.T) {
	status, expires := activeStatus()
	rec, req, check := getJSON(t, meAPI(fakeEntitlements{status: status}), "/v1/me")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check(rec, req)
	var got gen.Me
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.AdFree.Active)
	require.NotNil(t, got.AdFree.ExpiresAt)
	assert.True(t, expires.Equal(*got.AdFree.ExpiresAt))
	assert.True(t, got.Insight.Active)
	require.NotNil(t, got.Insight.Source)
	assert.Equal(t, gen.AdFreePass, *got.Insight.Source)
}

func TestGetMe_InactiveEntitlementsOmitExpiryAndSource(t *testing.T) {
	rec, req, check := getJSON(t, meAPI(fakeEntitlements{}), "/v1/me")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check(rec, req)
	assert.Contains(t, rec.Body.String(), `"adFree":{"active":false}`)
	assert.Contains(t, rec.Body.String(), `"insight":{"active":false}`)
}

func TestGetMe_WithoutEntitlementsIsUnavailable(t *testing.T) {
	rec, req, check := getJSON(t, meAPI(nil), "/v1/me")

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	check(rec, req)
}

func TestGetMe_EntitlementErrorIs500(t *testing.T) {
	rec, req, check := getJSON(t, meAPI(fakeEntitlements{err: errors.New("db down")}), "/v1/me")

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	check(rec, req)
}

func TestGetEntitlements_ReturnsStatus(t *testing.T) {
	status, expires := activeStatus()
	rec, req, check := getJSON(t, &httpapi.API{Entitlements: fakeEntitlements{status: status}}, "/v1/me/entitlements")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check(rec, req)
	var got gen.Entitlements
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.AdFree.Active)
	require.NotNil(t, got.Insight.ExpiresAt)
	assert.True(t, expires.Equal(*got.Insight.ExpiresAt))
	require.NotNil(t, got.Insight.Source)
	assert.Equal(t, gen.AdFreePass, *got.Insight.Source)
}

func TestGetEntitlements_InactiveOmitsExpiryAndSource(t *testing.T) {
	rec, req, check := getJSON(t, &httpapi.API{Entitlements: fakeEntitlements{}}, "/v1/me/entitlements")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check(rec, req)
	assert.JSONEq(t, `{"adFree":{"active":false},"insight":{"active":false}}`, rec.Body.String())
}

func TestGetEntitlements_WithoutServiceIsUnavailable(t *testing.T) {
	rec, req, check := getJSON(t, &httpapi.API{}, "/v1/me/entitlements")

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	check(rec, req)
}

func TestGetEntitlements_ErrorIs500(t *testing.T) {
	rec, req, check := getJSON(t, &httpapi.API{Entitlements: fakeEntitlements{err: errors.New("db down")}}, "/v1/me/entitlements")

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	check(rec, req)
}

// webhookSecret은 fakeWebhooks가 맞다고 보는 Authorization 값입니다.
const webhookSecret = "Bearer webhook-secret-value" //nolint:gosec // 테스트 대역의 가짜 값이며 자격 증명이 아닙니다

// fakeWebhooks는 RevenueCatWebhooks 대역입니다.
type fakeWebhooks struct {
	handleErr error
	calls     int
	gotBody   map[string]any
}

func (f *fakeWebhooks) Authorized(header string) bool { return header == webhookSecret }

func (f *fakeWebhooks) Handle(_ context.Context, body map[string]any) error {
	f.calls++
	f.gotBody = body
	return f.handleErr
}

const webhookPayload = `{"api_version":"1.0","event":{"id":"evt-1","type":"RENEWAL","store":"payload-marker-value"}}`

func postWebhook(t *testing.T, api *httpapi.API, authorization string) (*httptest.ResponseRecorder, *bytes.Buffer, func()) {
	t.Helper()
	handler, spec, logs := newHandlerAPIWithLogs(t, api)
	req := newBodyRequest(t, http.MethodPost, "/webhooks/revenuecat", contentTypeJSON, webhookPayload)
	if authorization != "" {
		req.Header.Set("Authorization", authorization)
	}
	rec := serve(handler, req)
	return rec, logs, func() { expectContractResponse(t, spec, req, rec) }
}

// assertNoSecretsLogged는 로그에 Authorization 값과 webhook 본문이 없는지 봅니다.
func assertNoSecretsLogged(t *testing.T, logs *bytes.Buffer) {
	t.Helper()
	assert.NotContains(t, logs.String(), "webhook-secret-value")
	assert.NotContains(t, logs.String(), "payload-marker-value")
}

func TestRevenuecatWebhook_Success_200WithoutBody(t *testing.T) {
	hooks := &fakeWebhooks{}
	rec, logs, check := postWebhook(t, &httpapi.API{Webhooks: hooks}, webhookSecret)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check()
	assert.Empty(t, rec.Body.String())
	assert.Equal(t, 1, hooks.calls)
	event, ok := hooks.gotBody["event"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, "evt-1", event["id"])
	assertNoSecretsLogged(t, logs)
}

func TestRevenuecatWebhook_WrongAuthorization_401(t *testing.T) {
	for _, authorization := range []string{"", "Bearer other"} {
		t.Run(authorization, func(t *testing.T) {
			hooks := &fakeWebhooks{}
			rec, logs, check := postWebhook(t, &httpapi.API{Webhooks: hooks}, authorization)

			require.Equal(t, http.StatusUnauthorized, rec.Code, rec.Body.String())
			check()
			assert.Equal(t, "auth.token_invalid", decodeProblem(t, rec).Code)
			assert.Empty(t, rec.Header().Get("WWW-Authenticate"), "webhook 401에는 challenge를 붙이지 않습니다")
			assert.Zero(t, hooks.calls)
			assertNoSecretsLogged(t, logs)
		})
	}
}

func TestRevenuecatWebhook_InvalidEvent_400(t *testing.T) {
	hooks := &fakeWebhooks{handleErr: fmt.Errorf("감쌈: %w", billing.ErrWebhookInvalid)}
	rec, logs, check := postWebhook(t, &httpapi.API{Webhooks: hooks}, webhookSecret)

	require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
	check()
	assert.Equal(t, "request.invalid", decodeProblem(t, rec).Code)
	assertNoSecretsLogged(t, logs)
}

func TestRevenuecatWebhook_HandleError_500(t *testing.T) {
	// 동기화 중 RevenueCat 장애도 webhook에서는 500입니다(RevenueCat이 재전송).
	for _, handleErr := range []error{errors.New("db down"), fmt.Errorf("동기화: %w", billing.ErrProviderUnavailable)} {
		t.Run(handleErr.Error(), func(t *testing.T) {
			rec, logs, check := postWebhook(t, &httpapi.API{Webhooks: &fakeWebhooks{handleErr: handleErr}}, webhookSecret)

			require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
			check()
			assert.Equal(t, "internal", decodeProblem(t, rec).Code)
			assert.Contains(t, logs.String(), `"severity":"ERROR"`)
			assertNoSecretsLogged(t, logs)
		})
	}
}

func TestRevenuecatWebhook_Unconfigured_500WithErrorLog(t *testing.T) {
	rec, logs, check := postWebhook(t, &httpapi.API{}, webhookSecret)

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	check()
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
	assert.Contains(t, logs.String(), `"severity":"ERROR"`)
	assertNoSecretsLogged(t, logs)
}

// fakeRestorer는 PurchaseRestorer 대역입니다.
type fakeRestorer struct {
	status     billing.Status
	err        error
	gotAccount uuid.UUID
}

func (f *fakeRestorer) Restore(_ context.Context, accountID uuid.UUID) (billing.Status, error) {
	f.gotAccount = accountID
	return f.status, f.err
}

func postRestore(t *testing.T, api *httpapi.API) (*httptest.ResponseRecorder, func()) {
	t.Helper()
	handler, spec := newHandlerAPI(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/billing/restore", nil)
	rec := serve(handler, req)
	return rec, func() { expectContractResponse(t, spec, req, rec) }
}

func TestRestorePurchases_ReturnsEntitlements(t *testing.T) {
	status, expires := activeStatus()
	restorer := &fakeRestorer{status: status}
	rec, check := postRestore(t, &httpapi.API{Purchases: restorer})

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check()
	assert.Equal(t, fixedAccountID, restorer.gotAccount)
	var got gen.Entitlements
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.AdFree.Active)
	require.NotNil(t, got.AdFree.ExpiresAt)
	assert.True(t, expires.Equal(*got.AdFree.ExpiresAt))
	require.NotNil(t, got.Insight.Source)
	assert.Equal(t, gen.AdFreePass, *got.Insight.Source)
}

func TestRestorePurchases_ProviderUnavailable_503(t *testing.T) {
	restorer := &fakeRestorer{err: fmt.Errorf("구매 목록 조회: %w", billing.ErrProviderUnavailable)}
	rec, check := postRestore(t, &httpapi.API{Purchases: restorer})

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	check()
	assert.Equal(t, "billing.provider_unavailable", decodeProblem(t, rec).Code)
}

func TestRestorePurchases_Unconfigured_503(t *testing.T) {
	rec, check := postRestore(t, &httpapi.API{})

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	check()
	assert.Equal(t, "billing.provider_unavailable", decodeProblem(t, rec).Code)
}

func TestRestorePurchases_OtherError_500(t *testing.T) {
	rec, check := postRestore(t, &httpapi.API{Purchases: &fakeRestorer{err: errors.New("db down")}})

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	check()
}

func TestRestorePurchases_RequiresBearer(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/billing/restore", nil))

	expectBearerFailure(t, rec, "auth.token_invalid")
}

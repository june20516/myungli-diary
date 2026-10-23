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

// fakeRewardVerifier는 RewardVerifier 대역입니다.
type fakeRewardVerifier struct {
	callback billing.RewardCallback
	err      error
	gotQuery string
}

func (f *fakeRewardVerifier) Verify(_ context.Context, rawQuery string) (billing.RewardCallback, error) {
	f.gotQuery = rawQuery
	return f.callback, f.err
}

// fakeRewards는 RewardGranter 대역입니다.
type fakeRewards struct {
	err       error
	calls     int
	gotQuery  string
	gotCaller billing.RewardCallback
}

func (f *fakeRewards) Grant(_ context.Context, cb billing.RewardCallback, rawQuery string) error {
	f.calls++
	f.gotCaller = cb
	f.gotQuery = rawQuery
	return f.err
}

// rewardQuery는 서명 값에 로그에 남으면 안 되는 표식이 든 원본 쿼리입니다. 퍼센트 인코딩과 +를 그대로 둡니다.
const rewardQuery = "ad_network=5450213213286189855&ad_unit=123&key_id=3335741209&reward_item=insight&timestamp=1507770365237&transaction_id=tx%2B1&user_id=a-b&signature=signature-marker-value"

func getReward(t *testing.T, api *httpapi.API) (*httptest.ResponseRecorder, *bytes.Buffer, func()) {
	t.Helper()
	handler, spec, logs := newHandlerAPIWithLogs(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/webhooks/admob-ssv?"+rewardQuery, nil)
	rec := serve(handler, req)
	return rec, logs, func() { expectContractResponse(t, spec, req, rec) }
}

func TestAdmobRewardCallback_Success_PassesRawQueryAndReturns200WithoutBody(t *testing.T) {
	verifier := &fakeRewardVerifier{callback: billing.RewardCallback{TransactionID: "tx+1", UserID: "a-b"}}
	rewards := &fakeRewards{}
	rec, logs, check := getReward(t, &httpapi.API{RewardVerifier: verifier, Rewards: rewards})

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check()
	assert.Empty(t, rec.Body.String())
	assert.Equal(t, rewardQuery, verifier.gotQuery, "원본 쿼리를 계약 검증 뒤에도 같은 문자열로 넘깁니다")
	assert.Equal(t, 1, rewards.calls)
	assert.Equal(t, rewardQuery, rewards.gotQuery)
	assert.Equal(t, "tx+1", rewards.gotCaller.TransactionID)
	assert.NotContains(t, logs.String(), "signature-marker-value")
}

func TestAdmobRewardCallback_VerifyErrors_MapToProblem(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{"서명", fmt.Errorf("감쌈: %w", billing.ErrRewardSignature), http.StatusUnauthorized, "reward.invalid_signature"},
		{"만료", billing.ErrRewardExpired, http.StatusUnauthorized, "reward.expired"},
		{"키 목록", fmt.Errorf("감쌈: %w", billing.ErrRewardKeysUnavailable), http.StatusServiceUnavailable, "service.unavailable"},
		{"그 밖", errors.New("예상 못 한 오류 " + rewardQuery), http.StatusInternalServerError, "internal"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rewards := &fakeRewards{}
			rec, logs, check := getReward(t, &httpapi.API{RewardVerifier: &fakeRewardVerifier{err: tt.err}, Rewards: rewards})

			require.Equal(t, tt.status, rec.Code, rec.Body.String())
			check()
			assert.Contains(t, rec.Body.String(), tt.code)
			assert.Zero(t, rewards.calls, "검증 실패면 권한을 부여하지 않습니다")
			assert.NotContains(t, logs.String(), "signature-marker-value")
		})
	}
}

func TestAdmobRewardCallback_GrantError_500(t *testing.T) {
	rec, logs, check := getReward(t, &httpapi.API{
		RewardVerifier: &fakeRewardVerifier{},
		Rewards:        &fakeRewards{err: errors.New("db down")},
	})

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	check()
	assert.Contains(t, rec.Body.String(), `"code":"internal"`)
	assert.NotContains(t, logs.String(), "signature-marker-value")
}

func TestAdmobRewardCallback_MissingDependency_503(t *testing.T) {
	tests := []struct {
		name string
		api  *httpapi.API
	}{
		{"둘 다 없음", &httpapi.API{}},
		{"Rewards 없음", &httpapi.API{RewardVerifier: &fakeRewardVerifier{}}},
		{"RewardVerifier 없음", &httpapi.API{Rewards: &fakeRewards{}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec, _, check := getReward(t, tt.api)

			require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
			check()
			assert.Contains(t, rec.Body.String(), "service.unavailable")
		})
	}
}

// fakeLedger는 PurchaseLister 대역입니다.
type fakeLedger struct {
	items      []billing.PurchaseItem
	err        error
	gotAccount uuid.UUID
}

func (f *fakeLedger) Purchases(_ context.Context, accountID uuid.UUID) ([]billing.PurchaseItem, error) {
	f.gotAccount = accountID
	return f.items, f.err
}

func TestListPurchases_Handler(t *testing.T) {
	started := handlerNow.AddDate(0, 0, -3)
	ledger := &fakeLedger{items: []billing.PurchaseItem{
		{ProductID: "test.ad_free.month", PurchasedAt: started, Status: billing.PurchaseActive,
			Period: &billing.Period{StartsAt: started, EndsAt: started.AddDate(0, 1, 0)}},
		{ProductID: "test.other.product", PurchasedAt: started.AddDate(0, -1, 0), Status: billing.PurchaseOwned},
	}}
	rec, req, check := getJSON(t, &httpapi.API{Ledger: ledger}, "/v1/me/purchases")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	check(rec, req)
	assert.Equal(t, fixedAccountID, ledger.gotAccount)
	var got gen.PurchaseList
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	require.Len(t, got.Items, 2)
	assert.Equal(t, gen.PurchaseStatus("active"), got.Items[0].Status)
	require.NotNil(t, got.Items[0].Period)
	assert.True(t, got.Items[0].Period.EndsAt.Equal(started.AddDate(0, 1, 0)))
	assert.Equal(t, gen.PurchaseStatus("owned"), got.Items[1].Status)
	assert.Nil(t, got.Items[1].Period, "기간 없는 상품은 period가 없습니다")
}

func TestListPurchases_EmptyIsEmptyArray(t *testing.T) {
	rec, _, _ := getJSON(t, &httpapi.API{Ledger: &fakeLedger{}}, "/v1/me/purchases")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.JSONEq(t, `{"items":[]}`, rec.Body.String())
}

func TestListPurchases_Unconfigured_503(t *testing.T) {
	rec, _, _ := getJSON(t, &httpapi.API{}, "/v1/me/purchases")

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
}

func TestListPurchases_Error_500(t *testing.T) {
	rec, _, _ := getJSON(t, &httpapi.API{Ledger: &fakeLedger{err: errors.New("db down")}}, "/v1/me/purchases")

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
}

func TestListPurchases_RequiresBearer(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me/purchases", nil))

	expectBearerFailure(t, rec, "auth.token_invalid")
}

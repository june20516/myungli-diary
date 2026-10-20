package httpapi_test

import (
	"context"
	"encoding/json"
	"errors"
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

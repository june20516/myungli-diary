package httpapi_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

func TestGetMe_ActiveShowsRequiredConsents(t *testing.T) {
	accts := &fakeAccounts{me: account.Me{
		AccountID: fixedAccountID,
		Access:    account.Access{Status: account.StatusActive, ConsentRequired: true},
		RequiredConsents: []account.ConsentDocument{
			{Document: account.Privacy, Version: "1"}, {Document: account.Terms, Version: "1"},
		},
	}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.Me
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Len(t, got.RequiredConsents, 2)
	assert.False(t, got.HasProfile)
	assert.False(t, got.AdFree.Active)
	assert.False(t, got.Insight.Active)
	assert.NotContains(t, rec.Body.String(), "status")
	assert.NotContains(t, rec.Body.String(), "deletionScheduledAt")
}

func TestGetMe_HasProfileTrue(t *testing.T) {
	accts := &fakeAccounts{me: account.Me{AccountID: fixedAccountID, Access: account.Access{Status: account.StatusActive}}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{exists: true}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.Me
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.HasProfile)
}

func TestGetMe_NoRequiredConsentsIsEmptyArray(t *testing.T) {
	accts := &fakeAccounts{me: account.Me{AccountID: fixedAccountID, Access: account.Access{Status: account.StatusActive}}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), `"requiredConsents":[]`)
	expectContractResponse(t, spec, req, rec)
}

func TestGetMe_PendingDeletionOmitsStatusAndSchedule(t *testing.T) {
	at := handlerNow.AddDate(0, 0, 30)
	accts := &fakeAccounts{me: account.Me{
		AccountID: fixedAccountID,
		Access:    account.Access{Status: account.StatusPendingDeletion, DeletionScheduledAt: &at},
	}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.NotContains(t, rec.Body.String(), "status")
	assert.NotContains(t, rec.Body.String(), "deletionScheduledAt")
}

func TestGetMe_UnknownAccountIs401(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: &fakeAccounts{err: account.ErrNotFound}, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code)
	expectContractResponse(t, spec, req, rec)
}

func TestAgreeConsents_Returns204(t *testing.T) {
	accts := &fakeAccounts{}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Profiles: &fakeProfiles{}})

	req := newBodyRequest(t, http.MethodPost, "/v1/me/consents", contentTypeJSON,
		`{"documents":[{"document":"terms","version":"1"},{"document":"privacy","version":"1"}]}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Equal(t, []account.ConsentDocument{{Document: account.Terms, Version: "1"}, {Document: account.Privacy, Version: "1"}}, accts.gotDocs)
}

func TestAgreeConsents_StaleVersionIs422WithPointer(t *testing.T) {
	accts := &fakeAccounts{agreeErr: &account.ConsentVersionMismatchError{Index: 1}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Profiles: &fakeProfiles{}})

	req := newBodyRequest(t, http.MethodPost, "/v1/me/consents", contentTypeJSON,
		`{"documents":[{"document":"terms","version":"1"},{"document":"privacy","version":"0"}]}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "consent.version_mismatch", p.Code)
	require.Len(t, p.Errors, 1)
	assert.Equal(t, "/documents/1/version", p.Errors[0].Field)
	assert.Equal(t, "consent.version_mismatch", p.Errors[0].Code)
	expectContractResponse(t, spec, req, rec)
}

func TestDeleteMe_Returns204WithoutBody(t *testing.T) {
	at := handlerNow.AddDate(0, 0, 30)
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: &fakeAccounts{scheduledAt: at}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodDelete, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Empty(t, rec.Body.String())
}

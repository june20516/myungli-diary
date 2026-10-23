package httpapi_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
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
	requireNoDeletionFields(t, rec.Body.Bytes())
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

// Me에는 계정 상태와 삭제 예정 시각이 없습니다(draft.15).
func TestGetMe_OmitsStatusAndSchedule(t *testing.T) {
	accts := &fakeAccounts{me: account.Me{
		AccountID: fixedAccountID,
		Access:    account.Access{Status: account.StatusActive},
	}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	requireNoDeletionFields(t, rec.Body.Bytes())
}

// requireNoDeletionFields는 Me 응답의 최상위에 계정 상태·삭제 예정 필드가 없는지 JSON key로 확인합니다.
func requireNoDeletionFields(t *testing.T, body []byte) {
	t.Helper()
	var raw map[string]any
	require.NoError(t, json.Unmarshal(body, &raw))
	assert.NotContains(t, raw, "status")
	assert.NotContains(t, raw, "deletionScheduledAt")
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
	accts := &fakeAccounts{}
	handler, spec := newHandlerAPI(t, &httpapi.API{Accounts: accts})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodDelete, "/v1/me", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Empty(t, rec.Body.String())
	assert.Equal(t, []uuid.UUID{fixedAccountID}, accts.deleted)
}

// 실제 계정 서비스와 bearer 관문으로, 삭제 뒤 같은 access token은 401 auth.token_invalid입니다.
func TestDeleteMe_SameAccessTokenIs401Afterwards(t *testing.T) {
	real := newRealAuth(t)
	accountID := uuid.Must(uuid.NewV7())
	require.NoError(t, authdb.New(real.pool).CreateAccount(t.Context(), authdb.CreateAccountParams{ID: accountID, LastActiveAt: handlerNow}))
	accessToken, _, err := real.access.Issue(accountID)
	require.NoError(t, err)

	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	api := &httpapi.API{Accounts: real.accounts, Entitlements: fakeEntitlements{}, Profiles: &fakeProfiles{}, Logger: deps.Logger, AppLink: testAppLink(t)}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, api, deps, httpapi.Routes{
			Spec:         spec,
			Validate:     httpapi.ValidateRequests(spec, deps.Logger),
			Authenticate: httpapi.BearerAuth(real.access, real.accounts, deps.Logger),
		})
	})
	request := func(method string) *http.Request {
		req := httptest.NewRequestWithContext(t.Context(), method, "/v1/me", nil)
		req.Header.Set("Authorization", "Bearer "+accessToken)
		return req
	}

	// 약관 동의 전이어도 deleteMe는 열려 있습니다.
	deleteReq := request(http.MethodDelete)
	deleted := serve(handler, deleteReq)
	require.Equal(t, http.StatusNoContent, deleted.Code, deleted.Body.String())
	expectContractResponse(t, spec, deleteReq, deleted)

	meReq := request(http.MethodGet)
	me := serve(handler, meReq)
	expectBearerFailure(t, me, "auth.token_invalid")
	expectContractResponse(t, spec, meReq, me)
}

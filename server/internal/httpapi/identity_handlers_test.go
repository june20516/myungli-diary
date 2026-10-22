package httpapi_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

func (f *fakeAuth) LoginLine(context.Context, string, string) (auth.LoginResult, error) {
	return f.login, f.err
}

func (f *fakeAuth) LoginGoogle(context.Context, string, string) (auth.LoginResult, error) {
	return f.login, f.err
}

func (f *fakeAuth) ListIdentities(context.Context, uuid.UUID) ([]auth.LinkedIdentity, error) {
	return f.identities, f.err
}

func (f *fakeAuth) LinkIdentity(_ context.Context, _ uuid.UUID, providerName string, proof auth.LinkProof) (auth.LinkResult, error) {
	f.gotProvider, f.gotLinkProof = providerName, proof
	return f.linkResult, f.linkErr
}

func (f *fakeAuth) UnlinkIdentity(_ context.Context, _ uuid.UUID, providerName string) error {
	f.gotProvider = providerName
	return f.unlinkErr
}

var (
	identityLinkedAt = time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)
	identityMergeAt  = time.Date(2026, 10, 13, 9, 10, 0, 0, time.UTC)
)

func TestLoginLine_ReturnsLoginResponse(t *testing.T) {
	fa := &fakeAuth{login: auth.LoginResult{AccountID: testAccountID, Tokens: testTokenPair(), IsNewAccount: true}}
	accts := &fakeAccounts{me: account.Me{AccountID: testAccountID, Access: account.Access{Status: account.StatusActive, ConsentRequired: true}}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa, Accounts: accts})

	req := postJSON(t, "/v1/auth/line", kakaoBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.LoginResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.True(t, got.IsNewAccount)
	assert.True(t, got.ConsentRequired)
	assert.Equal(t, "access", got.Tokens.AccessToken)
}

func TestLoginGoogle_ProviderInvalidIs401(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: &fakeAuth{err: auth.ErrProviderTokenInvalid}, Accounts: &fakeAccounts{}})

	req := postJSON(t, "/v1/auth/google", kakaoBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Equal(t, "auth.provider_token_invalid", decodeProblem(t, rec).Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
	expectContractResponse(t, spec, req, rec)
}

func TestListIdentities_ReturnsProvidersInOrder(t *testing.T) {
	fa := &fakeAuth{identities: []auth.LinkedIdentity{
		{Provider: "kakao", LinkedAt: identityLinkedAt},
		{Provider: "line", LinkedAt: identityLinkedAt.Add(time.Hour)},
	}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me/identities", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.JSONEq(t, `{"items":[
		{"provider":"kakao","linkedAt":"2026-10-01T03:00:00Z"},
		{"provider":"line","linkedAt":"2026-10-01T04:00:00Z"}]}`, rec.Body.String())
	assert.NotContains(t, rec.Body.String(), "subject")
}

func TestLinkIdentity_StatusByResult(t *testing.T) {
	list := []auth.LinkedIdentity{{Provider: "kakao", LinkedAt: identityLinkedAt}, {Provider: "google", LinkedAt: identityLinkedAt}}
	tests := []struct {
		name       string
		fake       *fakeAuth
		wantStatus int
		wantCode   string
	}{
		{name: "만들었으면 201", fake: &fakeAuth{identities: list, linkResult: auth.LinkResult{Created: true}}, wantStatus: http.StatusCreated},
		{name: "이미 있으면 200", fake: &fakeAuth{identities: list}, wantStatus: http.StatusOK},
		{name: "같은 제공자가 이미 붙음", fake: &fakeAuth{linkErr: auth.ErrProviderTaken}, wantStatus: http.StatusConflict, wantCode: "auth.provider_taken"},
		{name: "삭제 대기 계정의 연결", fake: &fakeAuth{linkErr: auth.ErrIdentityPendingDeletion}, wantStatus: http.StatusConflict, wantCode: "auth.identity_pending_deletion"},
		{
			name: "증명 조합 위반", wantStatus: http.StatusBadRequest, wantCode: "request.invalid",
			fake: &fakeAuth{linkErr: &auth.InvalidProofError{Field: "/exchangeCode", Code: "additionalProperties"}},
		},
		{name: "교환 코드 거절", fake: &fakeAuth{linkErr: auth.ErrExchangeInvalid}, wantStatus: http.StatusUnauthorized, wantCode: "auth.exchange_invalid"},
		{name: "제공자 토큰 거절", fake: &fakeAuth{linkErr: auth.ErrProviderTokenInvalid}, wantStatus: http.StatusUnauthorized, wantCode: "auth.provider_token_invalid"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler, spec := newHandlerAPI(t, &httpapi.API{Auth: tt.fake})

			req := postJSON(t, "/v1/me/identities/google", `{"idToken":"i","nonce":"0123456789abcdef"}`)
			rec := serve(handler, req)

			require.Equal(t, tt.wantStatus, rec.Code, rec.Body.String())
			expectContractResponse(t, spec, req, rec)
			assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
			if tt.wantCode == "" {
				assert.JSONEq(t, `{"items":[
					{"provider":"kakao","linkedAt":"2026-10-01T03:00:00Z"},
					{"provider":"google","linkedAt":"2026-10-01T03:00:00Z"}]}`, rec.Body.String())
				return
			}
			p := decodeProblem(t, rec)
			assert.Equal(t, tt.wantCode, p.Code)
			assert.Empty(t, p.MergeToken, "합치기 토큰은 identity_in_use에만 있습니다")
			assert.Nil(t, p.ExpiresAt)
			if tt.wantStatus == http.StatusBadRequest {
				assert.Equal(t, "request.invalid", p.Code)
				require.Len(t, p.Errors, 1)
				assert.Equal(t, "/exchangeCode", p.Errors[0].Field)
				assert.Equal(t, "additionalProperties", p.Errors[0].Code)
			} else {
				assert.Empty(t, p.Errors)
			}
		})
	}
}

func TestLinkIdentity_InUseCarriesMergeToken(t *testing.T) {
	fa := &fakeAuth{linkErr: &auth.IdentityInUseError{MergeToken: "tok", ExpiresAt: identityMergeAt}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

	req := postJSON(t, "/v1/me/identities/line", kakaoBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusConflict, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var raw map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
	assert.Equal(t, "auth.identity_in_use", raw["code"])
	assert.Equal(t, "tok", raw["mergeToken"])
	assert.Equal(t, "2026-10-13T09:10:00Z", raw["expiresAt"])
}

func TestLinkIdentity_PassesProofFields(t *testing.T) {
	fa := &fakeAuth{identities: nil, linkResult: auth.LinkResult{Created: true}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

	req := postJSON(t, "/v1/me/identities/apple", `{"idToken":"i","authorizationCode":"a","exchangeCode":"`+testExchangeCode+`","nonce":"0123456789abcdef"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Equal(t, "apple", fa.gotProvider)
	assert.Equal(t, auth.LinkProof{IDToken: "i", AuthorizationCode: "a", ExchangeCode: testExchangeCode, RawNonce: "0123456789abcdef"}, fa.gotLinkProof)
}

func TestUnlinkIdentity_Status(t *testing.T) {
	tests := []struct {
		name       string
		err        error
		wantStatus int
		wantCode   string
	}{
		{name: "떼기 성공", wantStatus: http.StatusNoContent},
		{name: "마지막 연결", err: auth.ErrLastIdentity, wantStatus: http.StatusConflict, wantCode: "auth.last_identity"},
		{name: "없는 연결", err: auth.ErrIdentityNotFound, wantStatus: http.StatusNotFound, wantCode: "auth.identity_not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fa := &fakeAuth{unlinkErr: tt.err}
			handler, spec := newHandlerAPI(t, &httpapi.API{Auth: fa})

			req := httptest.NewRequestWithContext(t.Context(), http.MethodDelete, "/v1/me/identities/google", nil)
			rec := serve(handler, req)

			require.Equal(t, tt.wantStatus, rec.Code, rec.Body.String())
			expectContractResponse(t, spec, req, rec)
			assert.Equal(t, "google", fa.gotProvider)
			if tt.wantCode != "" {
				p := decodeProblem(t, rec)
				assert.Equal(t, tt.wantCode, p.Code)
				assert.Empty(t, p.Errors)
			}
		})
	}
}

func TestIdentityOperations_RequireConsent(t *testing.T) {
	gate := fakeGate{access: account.Access{Status: account.StatusActive, ConsentRequired: true}}
	handler := newBearerHandler(t, fakeVerifier{}, gate)

	for _, tt := range []struct{ method, target, body string }{
		{http.MethodGet, "/v1/me/identities", ""},
		{http.MethodPost, "/v1/me/identities/google", kakaoBody},
		{http.MethodDelete, "/v1/me/identities/google", ""},
	} {
		t.Run(tt.method+" "+tt.target, func(t *testing.T) {
			rec := serve(handler, bearerRequest(t, tt.method, tt.target, tt.body))

			require.Equal(t, http.StatusForbidden, rec.Code, rec.Body.String())
			assert.Equal(t, "consent.required", decodeProblem(t, rec).Code)
		})
	}
}

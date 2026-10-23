package httpapi_test

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

const validAccessToken = "valid-token"

var testAccountID = uuid.MustParse("0192f0a0-0000-7000-8000-000000000001")

// fakeVerifier는 validAccessToken만 testAccountID로 받아들이고, 그 밖의 토큰에는 err를 돌려줍니다.
type fakeVerifier struct {
	err error
}

func (f fakeVerifier) Verify(tokenString string) (uuid.UUID, error) {
	if tokenString == validAccessToken {
		return testAccountID, nil
	}
	if f.err != nil {
		return uuid.Nil, f.err
	}
	return uuid.Nil, token.ErrAccessInvalid
}

// fakeGate는 정해 둔 접근 상태나 오류를 돌려줍니다.
type fakeGate struct {
	access account.Access
	err    error
}

func (f fakeGate) Access(_ context.Context, id uuid.UUID) (account.Access, error) {
	if id != testAccountID {
		return account.Access{}, account.ErrNotFound
	}
	return f.access, f.err
}

// newBearerHandler는 계약 라우트 전체를 미구현 핸들러로 등록하고 bearer 라우트에 BearerAuth를 씌운 Handler를 만듭니다.
func newBearerHandler(t *testing.T, verifier httpapi.AccessTokenVerifier, gate httpapi.AccountGate) http.Handler {
	t.Helper()
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: httpapi.BearerAuth(verifier, gate, deps.Logger),
	}
	return httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, httpapi.Unimplemented{}, deps, routes)
	})
}

func activeGate() fakeGate {
	return fakeGate{access: account.Access{Status: account.StatusActive}}
}

// bearerRequest는 validAccessToken을 실은 요청을 만듭니다. body가 비어 있지 않으면 JSON 본문으로 보냅니다.
func bearerRequest(t *testing.T, method, target, body string) *http.Request {
	t.Helper()
	var req *http.Request
	if body == "" {
		req = httptest.NewRequestWithContext(t.Context(), method, target, nil)
	} else {
		req = newBodyRequest(t, method, target, contentTypeJSON, body)
	}
	req.Header.Set("Authorization", "Bearer "+validAccessToken)
	return req
}

// expectBearerFailure는 401과 code, WWW-Authenticate가 있는지, 필드 오류가 없는지 확인합니다.
func expectBearerFailure(t *testing.T, rec *httptest.ResponseRecorder, code string) {
	t.Helper()
	require.Equal(t, http.StatusUnauthorized, rec.Code, "body = %s", rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, code, p.Code)
	assert.Empty(t, p.Errors)
	assert.NotEmpty(t, rec.Header().Get("WWW-Authenticate"))
}

func TestBearer_MissingTokenWithInvalidBodyIs401(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	rec := serve(handler, newBodyRequest(t, http.MethodPost, "/v1/me/consents", contentTypeJSON, `{}`))

	expectBearerFailure(t, rec, "auth.token_invalid")
}

func TestBearer_MalformedAuthorizationIs401(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	tests := []struct {
		name   string
		header string
	}{
		{name: "scheme만", header: "Bearer"},
		{name: "빈 토큰", header: "Bearer "},
		{name: "다른 scheme", header: "Basic " + validAccessToken},
		{name: "구분자 없음", header: "Bearer" + validAccessToken},
		{name: "모르는 토큰", header: "Bearer other"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
			req.Header.Set("Authorization", tt.header)

			expectBearerFailure(t, serve(handler, req), "auth.token_invalid")
		})
	}
}

func TestBearer_ExpiredTokenIs401Expired(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{err: token.ErrAccessExpired}, activeGate())

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
	req.Header.Set("Authorization", "Bearer expired")

	expectBearerFailure(t, serve(handler, req), "auth.token_expired")
}

func TestBearer_SchemeIsCaseInsensitive(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	for _, scheme := range []string{"bearer", "BEARER", "bEaReR"} {
		t.Run(scheme, func(t *testing.T) {
			req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil)
			req.Header.Set("Authorization", scheme+" "+validAccessToken)

			rec := serve(handler, req)

			assert.Equal(t, http.StatusNotImplemented, rec.Code, "body = %s", rec.Body.String())
		})
	}
}

func TestBearer_PublicRoutesSkipAuthentication(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	rec := serve(handler, newBodyRequest(t, http.MethodPost, "/v1/auth/refresh", contentTypeJSON, `{"refreshToken":"r"}`))
	assert.Equal(t, http.StatusNotImplemented, rec.Code, "body = %s", rec.Body.String())

	rec = serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/healthz", nil))
	assert.Equal(t, http.StatusOK, rec.Code, "body = %s", rec.Body.String())
}

// 공개 라우트는 bearer가 틀려도 인증하지 않으므로 401이 되지 않습니다.
func TestBearer_PublicRoutesIgnoreInvalidAuthorization(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/healthz", nil)
	req.Header.Set("Authorization", "Bearer other")

	assert.Equal(t, http.StatusOK, serve(handler, req).Code)
}

func TestBearer_ConsentRequiredBlocksOtherOperations(t *testing.T) {
	gate := fakeGate{access: account.Access{Status: account.StatusActive, ConsentRequired: true}}
	handler := newBearerHandler(t, fakeVerifier{}, gate)

	rec := serve(handler, bearerRequest(t, http.MethodGet, "/v1/chart", ""))
	require.Equal(t, http.StatusForbidden, rec.Code, "body = %s", rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "consent.required", p.Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))

	allowed := []struct {
		method, target, body string
	}{
		{http.MethodGet, "/v1/me", ""},
		{http.MethodDelete, "/v1/me", ""},
		{http.MethodPost, "/v1/auth/logout", `{"refreshToken":"r"}`},
		{http.MethodPost, "/v1/me/consents", `{"documents":[{"document":"terms","version":"1"}]}`},
		// 로그아웃 전에 알림을 멈추려고 부르므로 동의 전에도 엽니다(S92).
		{http.MethodDelete, "/v1/devices/00000000-0000-0000-0000-000000000001", ""},
	}
	for _, tt := range allowed {
		t.Run(tt.method+" "+tt.target, func(t *testing.T) {
			rec := serve(handler, bearerRequest(t, tt.method, tt.target, tt.body))

			// 관문을 통과하면 미구현 핸들러가 501로 답합니다.
			assert.Equal(t, http.StatusNotImplemented, rec.Code, "body = %s", rec.Body.String())
		})
	}
}

func TestBearer_DeletedOrUnknownAccountIs401(t *testing.T) {
	tests := []struct {
		name string
		gate fakeGate
	}{
		{name: "삭제된 계정", gate: fakeGate{access: account.Access{Status: account.StatusDeleted}}},
		{name: "없는 계정", gate: fakeGate{err: account.ErrNotFound}},
		{name: "감싼 없는 계정", gate: fakeGate{err: fmt.Errorf("계정 조회: %w", account.ErrNotFound)}},
		{name: "모르는 상태", gate: fakeGate{access: account.Access{Status: "unknown"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := newBearerHandler(t, fakeVerifier{}, tt.gate)

			expectBearerFailure(t, serve(handler, bearerRequest(t, http.MethodGet, "/v1/me", "")), "auth.token_invalid")
		})
	}
}

func TestBearer_GateDBDownIs503(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, fakeGate{err: fmt.Errorf("acquire: %w", &pgconn.ConnectError{})})

	rec := serve(handler, bearerRequest(t, http.MethodGet, "/v1/me", ""))

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
}

func TestBearer_GateUnknownErrorIs500(t *testing.T) {
	handler := newBearerHandler(t, fakeVerifier{}, fakeGate{err: errors.New("boom")})

	rec := serve(handler, bearerRequest(t, http.MethodGet, "/v1/me", ""))

	require.Equal(t, http.StatusInternalServerError, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
}

func TestBearerAuth_PutsAccountInContext(t *testing.T) {
	want := account.Access{Status: account.StatusActive, ConsentRequired: true}
	deps, _ := newTestDeps()
	authenticate := httpapi.BearerAuth(fakeVerifier{}, fakeGate{access: want}, deps.Logger)

	var (
		gotID     uuid.UUID
		gotAccess account.Access
		gotOK     bool
	)
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotID, gotAccess, gotOK = httpapi.AccountFrom(r.Context())
		w.WriteHeader(http.StatusNoContent)
	})
	handler := authenticate(httpapi.Operation{ID: "getMe", Bearer: true}, next)

	rec := serve(handler, bearerRequest(t, http.MethodGet, "/v1/me", ""))

	require.Equal(t, http.StatusNoContent, rec.Code)
	assert.True(t, gotOK)
	assert.Equal(t, testAccountID, gotID)
	assert.Equal(t, want, gotAccess)
}

func TestAccountFrom_EmptyContext(t *testing.T) {
	_, _, ok := httpapi.AccountFrom(t.Context())

	assert.False(t, ok)
}

func TestRegisterAPI_EveryBearerOperationIsGuarded(t *testing.T) {
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	handler := newBearerHandler(t, fakeVerifier{}, activeGate())

	guarded := 0
	for path, item := range spec.Paths.Map() {
		for method, operation := range item.Operations() {
			requirements := spec.Security
			if operation.Security != nil {
				requirements = *operation.Security
			}
			if !requiresBearer(requirements) {
				continue
			}
			guarded++
			// 인증이 검증보다 먼저이므로 path parameter 값은 계약에 맞지 않아도 됩니다.
			target := strings.NewReplacer("{", "", "}", "").Replace(path)
			t.Run(operation.OperationID, func(t *testing.T) {
				rec := serve(handler, httptest.NewRequestWithContext(t.Context(), method, target, nil))

				expectBearerFailure(t, rec, "auth.token_invalid")
			})
		}
	}
	assert.Positive(t, guarded)
}

// Authenticate가 받는 Operation.ID 집합은 원본 계약(api/openapi.yaml)에서 security가 bearerAuth인 operationId
// 집합과 같아야 합니다. 관문의 허용 목록이 계약 표기(예 "getMe")를 쓰므로, 내장 spec의 operationId 표기가
// 계약과 달라지거나 bearer 분류가 어긋나면 여기서 실패합니다.
func TestRegisterAPI_PassesContractOperationIDs(t *testing.T) {
	contract, err := openapi3.NewLoader().LoadFromFile(contractSpecPath)
	require.NoError(t, err)
	want := map[string]bool{}
	for _, item := range contract.Paths.Map() {
		for _, operation := range item.Operations() {
			requirements := contract.Security
			if operation.Security != nil {
				requirements = *operation.Security
			}
			if requiresBearer(requirements) {
				want[operation.OperationID] = true
			}
		}
	}
	require.NotEmpty(t, want)

	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	got := map[string]bool{}
	routes := httpapi.Routes{
		Spec:     spec,
		Validate: func(next http.Handler) http.Handler { return next },
		Authenticate: func(op httpapi.Operation, next http.Handler) http.Handler {
			assert.True(t, op.Bearer, op.ID)
			got[op.ID] = true
			return next
		},
	}

	httpapi.RegisterAPI(http.NewServeMux(), httpapi.Unimplemented{}, deps, routes)

	assert.Equal(t, want, got)
}

// contractSpecPath는 이 패키지 디렉터리에서 본 원본 계약 파일 경로입니다.
const contractSpecPath = "../../api/openapi.yaml"

func requiresBearer(requirements openapi3.SecurityRequirements) bool {
	for _, requirement := range requirements {
		if _, ok := requirement["bearerAuth"]; ok {
			return true
		}
	}
	return false
}

func TestRegisterAPI_PanicsOnPatternMissingFromSpec(t *testing.T) {
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	// 계약에서 operation 하나를 뺀 사본으로 등록하면 생성 코드의 pattern을 찾지 못합니다.
	trimmed := *spec
	trimmed.Paths = openapi3.NewPaths()
	for path, item := range spec.Paths.Map() {
		if path != "/v1/chart" {
			trimmed.Paths.Set(path, item)
		}
	}
	deps, _ := newTestDeps()
	routes := httpapi.Routes{
		Spec:         &trimmed,
		Validate:     func(next http.Handler) http.Handler { return next },
		Authenticate: func(_ httpapi.Operation, next http.Handler) http.Handler { return next },
	}

	assert.Panics(t, func() {
		httpapi.RegisterAPI(http.NewServeMux(), httpapi.Unimplemented{}, deps, routes)
	})
}

package httpapi_test

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

//nolint:gosec // 테스트용 값이며 실제 자격 증명이 아닙니다
const validAppCheckToken = "valid-app-check"

// fakeAppCheck는 validAppCheckToken만 통과시키고, 그 밖의 토큰에는 err를 돌려줍니다(nil이면 ErrTokenInvalid).
type fakeAppCheck struct {
	err   error
	calls int
}

func (f *fakeAppCheck) Verify(_ context.Context, token string) error {
	f.calls++
	if token == validAppCheckToken {
		return nil
	}
	if f.err != nil {
		return f.err
	}
	return fmt.Errorf("%w: 테스트", provider.ErrTokenInvalid)
}

// newAppCheckHandler는 계약 라우트 전체를 미구현 핸들러로 등록하고 appCheck 라우트에 RequireAppCheck을 씌운 Handler를 만듭니다.
// verifier가 nil이면 Routes.AppCheck도 nil입니다.
func newAppCheckHandler(t *testing.T, verifier httpapi.AppCheckVerifier) http.Handler {
	t.Helper()
	handler, _ := newAppCheckHandlerWithLogs(t, verifier)
	return handler
}

// newAppCheckHandlerWithLogs는 newAppCheckHandler와 같고, 로그가 쌓이는 buffer를 함께 돌려줍니다.
func newAppCheckHandlerWithLogs(t *testing.T, verifier httpapi.AppCheckVerifier) (http.Handler, *bytes.Buffer) {
	t.Helper()
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, logs := newTestDeps()
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: authenticateFixedAccount,
	}
	if verifier != nil {
		routes.AppCheck = httpapi.RequireAppCheck(verifier, deps.Logger)
	}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, httpapi.Unimplemented{}, deps, routes)
	})
	return handler, logs
}

const birthHourBody = `{"installationId":"install-1","calendar":"solar","date":{"year":1990,"month":5,"day":15},"isLeapMonth":false,"time":"10:30"}`

func birthHourRequest(t *testing.T, appCheckToken string) *http.Request {
	t.Helper()
	req := newBodyRequest(t, http.MethodPost, "/v1/birth-hour", contentTypeJSON, birthHourBody)
	if appCheckToken != "" {
		req.Header.Set("X-Firebase-AppCheck", appCheckToken)
	}
	return req
}

func TestAppCheck_MissingHeaderIs401(t *testing.T) {
	handler := newAppCheckHandler(t, &fakeAppCheck{})

	rec := serve(handler, birthHourRequest(t, ""))

	require.Equal(t, http.StatusUnauthorized, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "app_check.invalid", decodeProblem(t, rec).Code)
}

func TestAppCheck_InvalidTokenIs401BeforeContractValidation(t *testing.T) {
	handler := newAppCheckHandler(t, &fakeAppCheck{})
	req := newBodyRequest(t, http.MethodPost, "/v1/birth-hour", contentTypeJSON, `{}`)
	req.Header.Set("X-Firebase-AppCheck", "other")

	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code, "본문이 틀려도 App Check가 먼저입니다. body = %s", rec.Body.String())
	assert.Equal(t, "app_check.invalid", decodeProblem(t, rec).Code)
}

func TestAppCheck_JWKSOutageIs503AndLogged(t *testing.T) {
	handler, logs := newAppCheckHandlerWithLogs(t, &fakeAppCheck{err: fmt.Errorf("%w: JWKS 조회 실패: 상태 500", provider.ErrUnavailable)})

	rec := serve(handler, birthHourRequest(t, "secret-token-value"))

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	assert.Equal(t, 1, strings.Count(logs.String(), "App Check 검증 불가"), "logs = %s", logs.String())
	assert.Contains(t, logs.String(), "getBirthHour")
	assert.Contains(t, logs.String(), "JWKS 조회 실패")
	assert.NotContains(t, logs.String(), "secret-token-value")
}

func TestAppCheck_InvalidTokenIsNotLogged(t *testing.T) {
	handler, logs := newAppCheckHandlerWithLogs(t, &fakeAppCheck{})

	rec := serve(handler, birthHourRequest(t, "secret-token-value"))

	require.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.NotContains(t, logs.String(), "App Check 검증")
	assert.NotContains(t, logs.String(), "secret-token-value")
}

func TestAppCheck_DuplicateHeaderIs401(t *testing.T) {
	verifier := &fakeAppCheck{}
	handler := newAppCheckHandler(t, verifier)
	req := birthHourRequest(t, validAppCheckToken)
	req.Header.Add("X-Firebase-AppCheck", validAppCheckToken)

	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "app_check.invalid", decodeProblem(t, rec).Code)
	assert.Zero(t, verifier.calls)
}

func TestAppCheck_ValidTokenReachesContractValidation(t *testing.T) {
	handler := newAppCheckHandler(t, &fakeAppCheck{})
	req := newBodyRequest(t, http.MethodPost, "/v1/birth-hour", contentTypeJSON, `{}`)
	req.Header.Set("X-Firebase-AppCheck", validAppCheckToken)

	rec := serve(handler, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code, "통과하면 계약 검증이 이어집니다. body = %s", rec.Body.String())
}

func TestAppCheck_ValidTokenReachesHandler(t *testing.T) {
	handler := newAppCheckHandler(t, &fakeAppCheck{})

	rec := serve(handler, birthHourRequest(t, validAppCheckToken))

	// Unimplemented 핸들러는 501을 돌려줍니다(401·503·400이 아니면 핸들러까지 온 것입니다).
	assert.Equal(t, http.StatusNotImplemented, rec.Code, "body = %s", rec.Body.String())
}

func TestAppCheck_AllAppCheckOperationsAreGuarded(t *testing.T) {
	handler := newAppCheckHandler(t, &fakeAppCheck{})
	for _, target := range []string{"/v1/preview", "/v1/birth-hour", "/v1/lunar-date"} {
		t.Run(target, func(t *testing.T) {
			req := newBodyRequest(t, http.MethodPost, target, contentTypeJSON, `{}`)

			rec := serve(handler, req)

			require.Equal(t, http.StatusUnauthorized, rec.Code, "body = %s", rec.Body.String())
			assert.Equal(t, "app_check.invalid", decodeProblem(t, rec).Code)
		})
	}
}

func TestAppCheck_OperationWithoutAppCheckIsNotChecked(t *testing.T) {
	verifier := &fakeAppCheck{}
	handler := newAppCheckHandler(t, verifier)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/cities?q=서울", nil))

	assert.NotEqual(t, http.StatusUnauthorized, rec.Code, "body = %s", rec.Body.String())
	assert.Zero(t, verifier.calls)
}

func TestAppCheck_NilRoutesAppCheckIs503AndLogged(t *testing.T) {
	handler, logs := newAppCheckHandlerWithLogs(t, nil)

	rec := serve(handler, birthHourRequest(t, validAppCheckToken))

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	assert.Equal(t, 1, strings.Count(logs.String(), "App Check 검증기가 설정되지 않았습니다"), "logs = %s", logs.String())
	assert.NotContains(t, logs.String(), validAppCheckToken)
}

func TestRegisterAPI_PanicsOnSecurityAlternatives(t *testing.T) {
	tests := []struct {
		name         string
		requirements openapi3.SecurityRequirements
	}{
		{"서로 다른 scheme", openapi3.SecurityRequirements{{"appCheck": []string{}}, {"bearerAuth": []string{}}}},
		{"선택적 인증(빈 requirement)과 scheme", openapi3.SecurityRequirements{{}, {"bearerAuth": []string{}}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			spec, err := gen.GetSpec()
			require.NoError(t, err)
			spec.Paths.Value("/v1/birth-hour").Post.Security = &tt.requirements
			deps, _ := newTestDeps()
			routes := httpapi.Routes{
				Spec:         spec,
				Validate:     func(next http.Handler) http.Handler { return next },
				Authenticate: authenticateFixedAccount,
				AppCheck:     passAppCheck,
			}

			assert.Panics(t, func() {
				httpapi.RegisterAPI(http.NewServeMux(), httpapi.Unimplemented{}, deps, routes)
			})
		})
	}
}

// Operation.AppCheck은 원본 계약(api/openapi.yaml)에서 security가 appCheck인 operationId 집합과 같아야 합니다.
func TestRegisterAPI_PassesAppCheckOperations(t *testing.T) {
	contract, err := openapi3.NewLoader().LoadFromFile(contractSpecPath)
	require.NoError(t, err)
	want := map[string]bool{}
	for _, item := range contract.Paths.Map() {
		for _, operation := range item.Operations() {
			requirements := contract.Security
			if operation.Security != nil {
				requirements = *operation.Security
			}
			for _, requirement := range requirements {
				if _, ok := requirement["appCheck"]; ok {
					want[operation.OperationID] = true
				}
			}
		}
	}
	assert.Equal(t, map[string]bool{"createPreview": true, "getBirthHour": true, "convertLunarDate": true}, want)

	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	got := map[string]bool{}
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     func(next http.Handler) http.Handler { return next },
		Authenticate: func(_ httpapi.Operation, next http.Handler) http.Handler { return next },
		AppCheck: func(op httpapi.Operation, next http.Handler) http.Handler {
			assert.True(t, op.AppCheck, op.ID)
			got[op.ID] = true
			return next
		},
	}

	httpapi.RegisterAPI(http.NewServeMux(), httpapi.Unimplemented{}, deps, routes)

	assert.Equal(t, want, got)
}

//go:build !staging

package httpapi_test

import (
	"net/http"
	"reflect"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

// prod 빌드(staging tag 없음)에는 테스트 로그인 라우트가 없어 404이고 test 계정이 생기지 않습니다(S24, spec §13.2).
func TestLogin_TestRouteAbsentInProdBuild(t *testing.T) {
	real := newRealAuth(t)
	handler, _ := newHandlerAPI(t, &httpapi.API{Auth: real.auth, Accounts: real.accounts})

	// 테스트 광고 제거 기간 경로(S125)도 없습니다.
	for _, path := range []string{testLoginPath, "/test/v1/billing/ad-free"} {
		for _, method := range []string{http.MethodPost, http.MethodGet, http.MethodDelete} {
			req := newBodyRequest(t, method, path, contentTypeJSON, `{"label":"e2e01"}`)
			req.Header.Set(testLoginSecretHeader, "any-secret-value-any-secret-value")
			rec := serve(handler, req)
			require.Equal(t, http.StatusNotFound, rec.Code, "%s %s: %s", method, path, rec.Body.String())
			assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code)
		}
	}
	assert.Zero(t, real.countTestIdentities(t))
}

// prod 빌드에는 테스트 로그인 진입점(auth.Service.LoginTest, httpapi.API.EnableTestLogin)과
// 테스트 광고 제거 기간 진입점(billing.Store.GrantTest·RevokeTest, httpapi.API.EnableTestGrant)이 컴파일되지 않습니다.
// 이름으로 찾으므로 시그니처가 바뀌어도 진입점이 prod에 새어 들어오면 잡힙니다.
func TestLogin_TestEntryPointsAbsentInProdBuild(t *testing.T) {
	_, hasLoginTest := reflect.TypeFor[*auth.Service]().MethodByName("LoginTest")
	assert.False(t, hasLoginTest, "auth.Service.LoginTest가 prod 빌드에 있습니다")
	_, hasEnable := reflect.TypeFor[*httpapi.API]().MethodByName("EnableTestLogin")
	assert.False(t, hasEnable, "httpapi.API.EnableTestLogin이 prod 빌드에 있습니다")
	_, hasEnableGrant := reflect.TypeFor[*httpapi.API]().MethodByName("EnableTestGrant")
	assert.False(t, hasEnableGrant, "httpapi.API.EnableTestGrant가 prod 빌드에 있습니다")
	for _, name := range []string{"GrantTest", "RevokeTest"} {
		_, has := reflect.TypeFor[*billing.Store]().MethodByName(name)
		assert.False(t, has, "billing.Store.%s가 prod 빌드에 있습니다", name)
	}
}

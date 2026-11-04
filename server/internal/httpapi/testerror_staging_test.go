//go:build staging

package httpapi_test

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// testErrorPath는 staging 시험 오류(S133)의 경로입니다.
const testErrorPath = "/test/v1/server-error"

// 맞는 비밀로 GET하면 Error 로그를 남기고 500 internal입니다.
func TestTestError_ReturnsInternalWithErrorLog(t *testing.T) {
	f := newTestLoginFixture(t)

	rec := serve(f.handler, testGrantRequest(t, http.MethodGet, testLoginSecret, testErrorPath, ""))

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
	assert.Contains(t, f.logs.String(), "staging 시험 오류")
	assert.NotContains(t, f.logs.String(), testLoginSecret[:10], "비밀은 로그에 남기지 않습니다")
}

// 비밀이 없거나 틀리면 메서드와 관계없이 404 route.not_found입니다.
func TestTestError_WrongSecretIsRouteNotFound(t *testing.T) {
	f := newTestLoginFixture(t)

	for name, req := range map[string]*http.Request{
		"비밀 없음":      testGrantRequest(t, http.MethodGet, "", testErrorPath, ""),
		"틀린 비밀":      testGrantRequest(t, http.MethodGet, "wrong", testErrorPath, ""),
		"틀린 비밀 POST": testGrantRequest(t, http.MethodPost, "wrong", testErrorPath, ""),
	} {
		rec := serve(f.handler, req)
		require.Equal(t, http.StatusNotFound, rec.Code, "%s: %s", name, rec.Body.String())
		assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code, name)
	}
}

// 맞는 비밀에서 GET이 아니면 405이고 Allow는 GET입니다.
func TestTestError_MethodNotAllowed(t *testing.T) {
	f := newTestLoginFixture(t)

	rec := serve(f.handler, testGrantRequest(t, http.MethodPost, testLoginSecret, testErrorPath, ""))

	require.Equal(t, http.StatusMethodNotAllowed, rec.Code, rec.Body.String())
	assert.Equal(t, http.MethodGet, rec.Header().Get("Allow"))
}

//go:build staging

package httpapi_test

import (
	"encoding/json"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// testClientIPPath는 staging 클라이언트 IP 확인(S135)의 경로입니다.
const testClientIPPath = "/test/v1/client-ip"

// 맞는 비밀로 GET하면 받은 X-Forwarded-For를 순서대로 나눠 RemoteAddr와 함께 돌려줍니다.
func TestTestClientIP_EchoesForwardedFor(t *testing.T) {
	f := newTestLoginFixture(t)
	req := testGrantRequest(t, http.MethodGet, testLoginSecret, testClientIPPath, "")
	req.Header.Add("X-Forwarded-For", "203.0.113.7, 66.249.1.2")
	req.Header.Add("X-Forwarded-For", "35.191.0.1")
	req.RemoteAddr = "169.254.1.1:5555"

	rec := serve(f.handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))
	var got struct {
		XForwardedFor []string `json:"xForwardedFor"`
		RemoteAddr    string   `json:"remoteAddr"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, []string{"203.0.113.7", "66.249.1.2", "35.191.0.1"}, got.XForwardedFor)
	assert.Equal(t, "169.254.1.1:5555", got.RemoteAddr)
}

// 비밀이 없거나 틀리면 404 route.not_found, 맞는 비밀에서 GET이 아니면 405입니다.
func TestTestClientIP_GuardsSecretAndMethod(t *testing.T) {
	f := newTestLoginFixture(t)

	for name, req := range map[string]*http.Request{
		"비밀 없음": testGrantRequest(t, http.MethodGet, "", testClientIPPath, ""),
		"틀린 비밀": testGrantRequest(t, http.MethodGet, "wrong", testClientIPPath, ""),
	} {
		rec := serve(f.handler, req)
		require.Equal(t, http.StatusNotFound, rec.Code, name)
		assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code, name)
	}
	rec := serve(f.handler, testGrantRequest(t, http.MethodPost, testLoginSecret, testClientIPPath, ""))
	require.Equal(t, http.StatusMethodNotAllowed, rec.Code)
	assert.Equal(t, http.MethodGet, rec.Header().Get("Allow"))
}

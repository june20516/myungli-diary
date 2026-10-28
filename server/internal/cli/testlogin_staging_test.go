//go:build staging

package cli

import (
	"bytes"
	"net/http"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// staging 빌드의 serve는 TEST_LOGIN_SECRET이 없으면 시작하지 않습니다(S24).
func TestServe_RequiresTestLoginSecretInStaging(t *testing.T) {
	for name, value := range map[string]string{"없음": "", "짧음": "short-secret"} {
		env := testAuthEnv(t)
		env["TEST_LOGIN_SECRET"] = value
		env["PORT"] = freePort(t)
		env["DATABASE_URL"] = "postgres://x@127.0.0.1:1/x"
		var stdout, stderr bytes.Buffer

		code := Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)

		assert.Equal(t, 1, code, name)
		assert.Contains(t, stderr.String(), "TEST_LOGIN_SECRET", name)
		if value != "" {
			assert.NotContains(t, stderr.String(), value, "%s: 오류에 값을 담지 않습니다", name)
		}
	}
}

// serve 조립에 테스트 로그인을 켜면 그 토큰으로 계약 라우트(약관 동의)를 쓸 수 있습니다.
func TestServe_AssemblesTestLogin(t *testing.T) {
	const secret = "staging-test-login-secret-0123456789" //nolint:gosec // 테스트 값이며 실제 자격 증명이 아닙니다
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.TestLogin = testLoginSettings{secret: secret}
	})

	req, err := http.NewRequestWithContext(t.Context(), http.MethodPost, env.url+"/test/v1/auth/login", strings.NewReader(`{"label":"e2e01"}`))
	require.NoError(t, err)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Test-Login-Secret", secret)
	login := env.send(req)
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	assert.Equal(t, true, login.body["consentRequired"])

	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	assert.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)
}

// staging 빌드는 APP_ENV가 prod면 시작하지 않습니다. 테스트 로그인이 든 바이너리가 prod에 배포되는 것을 막습니다.
func TestServe_StagingBuildRefusesProdEnv(t *testing.T) {
	env := testAuthEnv(t)
	env["APP_ENV"] = "prod"
	env["ENGINE_AUDIENCE"] = "https://engine.example.run.app"
	env["PORT"] = freePort(t)
	env["DATABASE_URL"] = "postgres://x@127.0.0.1:1/x"
	var stdout, stderr bytes.Buffer

	code := Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr.String(), "APP_ENV")
	assert.Contains(t, stderr.String(), "prod")
	assert.NotContains(t, stderr.String(), env["TEST_LOGIN_SECRET"], "오류에 비밀을 담지 않습니다")
}

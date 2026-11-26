package cli

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/opsapi"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

const (
	testAudience    = "/projects/123/locations/asia-northeast3/services/server-ops"
	testDevIdentity = "dev-op@example.com,dev-sub-1"
)

// deployedOpsEnv는 staging의 올바른 운영 서버 설정입니다. 시험이 한 항목씩 빼거나 바꿔 쓰는 바탕입니다.
func deployedOpsEnv() map[string]string {
	return map[string]string{
		"APP_ENV":            "staging",
		"DATABASE_URL":       "user=ops-sa dbname=myungli sslmode=disable",
		"CLOUD_SQL_INSTANCE": "project:region:instance",
		"IAP_AUDIENCE":       testAudience,
		"OPS_OPERATORS":      "op@example.com",
	}
}

func TestOpsServe_RequiresCloudSQLInDeployedEnv(t *testing.T) {
	for _, appEnv := range []string{"staging", "prod"} {
		t.Run(appEnv, func(t *testing.T) {
			env := deployedOpsEnv()
			env["APP_ENV"] = appEnv
			delete(env, "CLOUD_SQL_INSTANCE")

			code, _, stderr := runCLIWithEnv(t, env, "ops-serve")
			assert.Equal(t, 1, code)
			assert.Contains(t, stderr, "CLOUD_SQL_INSTANCE")
		})
	}
}

func TestOpsServe_DevIdentityRejectedOutsideLocal(t *testing.T) {
	env := deployedOpsEnv()
	env["OPS_DEV_IDENTITY"] = testDevIdentity

	code, _, stderr := runCLIWithEnv(t, env, "ops-serve")
	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "OPS_DEV_IDENTITY")
	assert.NotContains(t, stderr, "dev-op@example.com", "오류에 메일 값을 담지 않습니다")
}

func TestOpsServe_RequiresAudience(t *testing.T) {
	t.Run("배포 환경", func(t *testing.T) {
		env := deployedOpsEnv()
		delete(env, "IAP_AUDIENCE")

		code, _, stderr := runCLIWithEnv(t, env, "ops-serve")
		assert.Equal(t, 1, code)
		assert.Contains(t, stderr, "IAP_AUDIENCE")
	})
	t.Run("local이어도 고정 신원이 없으면", func(t *testing.T) {
		env := map[string]string{"APP_ENV": "local", "DATABASE_URL": "postgres://x@localhost/x"}

		code, _, stderr := runCLIWithEnv(t, env, "ops-serve")
		assert.Equal(t, 1, code)
		assert.Contains(t, stderr, "IAP_AUDIENCE")
	})
}

func TestOpsServe_RejectsArguments(t *testing.T) {
	code, _, stderr := runCLIWithEnv(t, deployedOpsEnv(), "ops-serve", "extra")
	assert.Equal(t, 2, code)
	assert.Contains(t, stderr, "usage: server ops-serve")
}

func TestOpsServe_LocalDevIdentityServes(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	port := freePort(t)
	env := map[string]string{
		"APP_ENV":          "local",
		"PORT":             port,
		"DATABASE_URL":     dbtest.NewURL(t),
		"OPS_DEV_IDENTITY": testDevIdentity,
		"OPS_OPERATORS":    "dev-op@example.com",
	}
	var stdout, stderr bytes.Buffer
	done := make(chan int, 1)
	go func() {
		done <- Run(ctx, []string{"ops-serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	}()

	url := "http://127.0.0.1:" + port + "/ops/v1/accounts:show"
	client := &http.Client{Timeout: 2 * time.Second}
	t.Cleanup(client.CloseIdleConnections)

	// 고정 신원도 CSRF 검사를 거칩니다. 사용자 정의 헤더가 없으면 403입니다.
	require.Eventually(t, func() bool {
		status, err := postJSON(ctx, client, url, false)
		return err == nil && status == http.StatusForbidden
	}, 5*time.Second, 50*time.Millisecond, "헤더 없는 요청은 403")
	// 헤더를 갖추면 인증과 허용 목록을 지나 본문 검사(400)에 닿습니다.
	status, err := postJSON(ctx, client, url, true)
	require.NoError(t, err)
	assert.Equal(t, http.StatusBadRequest, status)

	cancel()
	select {
	case code := <-done:
		assert.Equal(t, 0, code, "stderr = %q", stderr.String())
	case <-time.After(5 * time.Second):
		t.Fatal("ctx 취소 뒤 ops-serve가 종료되지 않았습니다")
	}
	assert.Contains(t, stderr.String(), "고정 신원")
	assert.NotContains(t, stderr.String(), "dev-op@example.com", "로그에 메일 값을 담지 않습니다")
}

// postJSON은 빈 JSON 본문을 POST하고 상태 코드를 돌려줍니다. withOpsHeader가 거짓이면 사용자 정의 헤더를 뺍니다.
func postJSON(ctx context.Context, client *http.Client, url string, withOpsHeader bool) (int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, strings.NewReader("{}"))
	if err != nil {
		return 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	if withOpsHeader {
		req.Header.Set("X-Myungli-Ops", "1")
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	_ = resp.Body.Close()
	return resp.StatusCode, nil
}

// serve와 ops-serve는 서로의 경로를 내지 않습니다(서비스를 나눈 보안 경계).
func TestRouters_Separated(t *testing.T) {
	appServer := newFlowEnv(t)

	opsHandler, err := opsapi.NewHandler(opsapi.Deps{
		Service:   ops.NewService(dbtest.New(t)),
		Verifier:  fixedIdentity{identity: opsapi.Identity{Email: "dev-op@example.com", Subject: "dev-sub-1"}},
		Allowlist: opsapi.ParseAllowlist("dev-op@example.com"),
		Logger:    slog.New(slog.DiscardHandler),
	})
	require.NoError(t, err)
	opsServer := httptest.NewServer(opsHandler)
	t.Cleanup(opsServer.Close)

	appResp := appServer.do(http.MethodPost, "/ops/v1/accounts:show", "", map[string]any{})
	assert.Equal(t, http.StatusNotFound, appResp.status, "serve에는 운영 API 경로가 없습니다")

	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, opsServer.URL+"/v1/daily", nil)
	require.NoError(t, err)
	resp, err := opsServer.Client().Do(req)
	require.NoError(t, err)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusNotFound, resp.StatusCode, "ops-serve에는 앱 경로가 없습니다")
}

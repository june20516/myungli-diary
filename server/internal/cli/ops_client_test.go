package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// 시험용 비밀 값입니다. 어떤 출력에도 나오면 안 됩니다.
//
//nolint:gosec // 테스트용 가짜 값이며 비밀이 아닙니다
const (
	testOpsClientID     = "client-123.apps.googleusercontent.com"
	testOpsClientSecret = "cs-SECRET-client"
	testOpsRefreshToken = "rt-SECRET-refresh"
	testOpsIDToken      = "idt-SECRET-idtoken"
)

// recordedOpsRequest는 가짜 운영 API가 받은 요청 하나입니다.
type recordedOpsRequest struct {
	method string
	path   string
	header http.Header
	body   map[string]any
}

// opsHarness는 가짜 운영 API, 가짜 token endpoint, 로컬 값 폴더를 묶습니다.
type opsHarness struct {
	t        *testing.T
	localDir string
	api      *httptest.Server
	token    *httptest.Server

	mu          sync.Mutex
	requests    []recordedOpsRequest
	tokenCalls  int
	apiStatus   int
	apiBody     string
	tokenStatus int
	tokenBody   string
}

func newOpsHarness(t *testing.T) *opsHarness {
	t.Helper()
	h := &opsHarness{t: t, localDir: t.TempDir(), apiStatus: http.StatusOK, apiBody: "{}", tokenStatus: http.StatusOK}
	h.tokenBody = `{"access_token":"at","token_type":"Bearer","expires_in":3600,"id_token":"` + testOpsIDToken + `"}`

	h.api = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body map[string]any
		_ = json.Unmarshal(raw, &body)
		h.mu.Lock()
		h.requests = append(h.requests, recordedOpsRequest{method: r.Method, path: r.URL.Path, header: r.Header.Clone(), body: body})
		status, respBody := h.apiStatus, h.apiBody
		h.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, respBody)
	}))
	t.Cleanup(h.api.Close)

	h.token = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		h.mu.Lock()
		h.tokenCalls++
		status, respBody := h.tokenStatus, h.tokenBody
		h.mu.Unlock()
		assert.Equal(t, "refresh_token", r.PostForm.Get("grant_type"))
		assert.Equal(t, testOpsRefreshToken, r.PostForm.Get("refresh_token"))
		assert.Equal(t, testOpsClientID, r.PostForm.Get("client_id"))
		assert.Equal(t, testOpsClientSecret, r.PostForm.Get("client_secret"))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, respBody)
	}))
	t.Cleanup(h.token.Close)

	h.writeCredentials(t, "staging", 0o600)
	return h
}

// writeCredentials는 ops login이 남기는 파일을 직접 씁니다.
func (h *opsHarness) writeCredentials(t *testing.T, env string, perm os.FileMode) string {
	t.Helper()
	dir := filepath.Join(h.localDir, "server", env)
	require.NoError(t, os.MkdirAll(dir, 0o700))
	path := filepath.Join(dir, "ops-oauth.json")
	raw, err := json.Marshal(map[string]string{
		"apiUrl": h.api.URL, "clientId": testOpsClientID, "clientSecret": testOpsClientSecret, "refreshToken": testOpsRefreshToken,
	})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(path, raw, 0o600))
	require.NoError(t, os.Chmod(path, perm))
	return path
}

func (h *opsHarness) respond(status int, body any) {
	h.t.Helper()
	raw, ok := body.(string)
	if !ok {
		encoded, err := json.Marshal(body)
		require.NoError(h.t, err)
		raw = string(encoded)
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	h.apiStatus, h.apiBody = status, raw
}

func (h *opsHarness) deps() opsDeps {
	return opsDeps{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		tokenURL:   h.token.URL,
		authURL:    "https://accounts.example.test/o/oauth2/auth",
		openBrowser: func(context.Context, string) error {
			h.t.Error("로그인 외 명령이 브라우저를 열었습니다")
			return nil
		},
	}
}

func (h *opsHarness) getenv(key string) string {
	if key == "MYUNGLI_LOCAL_DIR" {
		return h.localDir
	}
	return ""
}

// run은 ops 명령을 실행하고 Run과 같은 규칙으로 종료 코드를 정합니다. 어떤 출력에도 비밀 값이 없는지 매번 확인합니다.
func (h *opsHarness) run(t *testing.T, deps opsDeps, args ...string) (int, string, string) {
	t.Helper()
	var stdout, stderr bytes.Buffer
	err := newOpsCommand(deps)(context.Background(), args, h.getenv, &stdout, &stderr)
	code := exitCode("ops", err, &stderr)
	assertNoOpsSecrets(t, stdout.String()+stderr.String())
	return code, stdout.String(), stderr.String()
}

func assertNoOpsSecrets(t *testing.T, output string) {
	t.Helper()
	for _, secret := range []string{testOpsClientSecret, testOpsRefreshToken, testOpsIDToken} {
		assert.NotContains(t, output, secret, "출력에 비밀 값이 있습니다")
	}
}

func (h *opsHarness) recorded() []recordedOpsRequest {
	h.mu.Lock()
	defer h.mu.Unlock()
	return append([]recordedOpsRequest(nil), h.requests...)
}

func (h *opsHarness) tokenCallCount() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.tokenCalls
}

func TestOpsClient_Commands(t *testing.T) {
	account := uuid.New()
	entry := uuid.New()
	auditID := uuid.New()
	rows := []billing.GrantRow{{ID: 7, Entitlement: billing.AdFree, Source: billing.SourceOperator, SourceRef: auditID.String(), StartsAt: opsAt, ExpiresAt: opsAt.Add(24 * time.Hour)}}
	memo := "메모\x1b[31m"
	clock := "09:30"
	honorific := "수아"
	purpose := "inquiry"
	summary := ops.AccountSummary{
		Account:    ops.AccountInfo{ID: account, Status: "active", CreatedAt: opsAt, LastActiveAt: opsAt},
		Identities: []ops.IdentityInfo{{Provider: "google", LinkedAt: opsAt}},
		Devices:    []ops.DeviceInfo{}, Grants: rows, Purchases: []ops.PurchaseInfo{},
	}
	diary := ops.DiaryView{Entries: []ops.DiaryEntry{{ID: entry, Date: profile.LocalDate{Year: 2026, Month: 11, Day: 20}, Body: "본문\x1b[2J", CreatedAt: opsAt, UpdatedAt: opsAt}}, Tags: []string{"맑음"}}
	schedule := ops.ScheduleView{Entries: []ops.ScheduleEntry{{ID: entry, Date: profile.LocalDate{Year: 2026, Month: 11, Day: 21}, Time: &clock, Title: "약속", Memo: &memo}}, DeletedCount: 1}
	profileView := ops.ProfileView{Honorific: &honorific, Language: "ko", CurrentTimezone: "Asia/Seoul", BirthDate: &profile.LocalDate{Year: 1990, Month: 5, Day: 7}}
	records := []ops.AuditRecord{{ID: auditID, At: opsAt, Actor: "op@example.com", ActorSub: "accounts.google.com:1", Channel: "ops_api", Action: "account_show", AccountID: &account, Purpose: &purpose, Reason: opsReason, Target: json.RawMessage(`{"accountId":"` + account.String() + `"}`)}}

	tests := []struct {
		name     string
		args     []string
		path     string
		body     map[string]any
		response any
		print    func(w io.Writer) error
	}{
		{
			name: "account show 계정", args: []string{"account", "show", "--account", account.String()},
			path: "/ops/v1/accounts:show", body: map[string]any{"accountId": account.String(), "reason": opsReason},
			response: summary, print: func(w io.Writer) error { return printAccountSummary(w, summary) },
		},
		{
			name: "account show 거래", args: []string{"account", "show", "--store-transaction", "GPA.1-2"},
			path: "/ops/v1/accounts:show", body: map[string]any{"storeTransaction": "GPA.1-2", "reason": opsReason},
			response: summary, print: func(w io.Writer) error { return printAccountSummary(w, summary) },
		},
		{
			name: "grant days", args: []string{"grant", "--account", account.String(), "--entitlement", "ad_free", "--days", "30"},
			path: "/ops/v1/grants", body: map[string]any{"accountId": account.String(), "entitlement": "ad_free", "days": float64(30), "reason": opsReason},
			response: ops.GrantResult{AuditID: auditID, Grants: rows},
			print:    func(w io.Writer) error { return printGrantResult(w, ops.GrantResult{AuditID: auditID, Grants: rows}) },
		},
		{
			name: "grant until", args: []string{"grant", "--account", account.String(), "--entitlement", "insight", "--until", "2026-12-31T09:00:00+09:00"},
			path: "/ops/v1/grants", body: map[string]any{"accountId": account.String(), "entitlement": "insight", "until": "2026-12-31T09:00:00+09:00", "reason": opsReason},
			response: ops.GrantResult{AuditID: auditID, Grants: rows},
			print:    func(w io.Writer) error { return printGrantResult(w, ops.GrantResult{AuditID: auditID, Grants: rows}) },
		},
		{
			name: "revoke", args: []string{"revoke", "--account", account.String(), "--grant", "7"},
			path: "/ops/v1/grants:revoke", body: map[string]any{"accountId": account.String(), "grantId": float64(7), "reason": opsReason},
			response: ops.RevokeResult{AuditID: auditID, Before: rows, After: rows},
			print: func(w io.Writer) error {
				return printRevokeResult(w, ops.RevokeResult{AuditID: auditID, Before: rows, After: rows})
			},
		},
		{
			name: "content diary 날짜", args: []string{"content", "diary", "--account", account.String(), "--date", "2026-11-20", "--purpose", "inquiry"},
			path: "/ops/v1/content:diary", body: map[string]any{"accountId": account.String(), "date": "2026-11-20", "purpose": "inquiry", "reason": opsReason},
			response: diary, print: func(w io.Writer) error { return printDiaryView(w, diary) },
		},
		{
			name: "content schedule id", args: []string{"content", "schedule", "--account", account.String(), "--id", entry.String(), "--purpose", "incident"},
			path: "/ops/v1/content:schedule", body: map[string]any{"accountId": account.String(), "id": entry.String(), "purpose": "incident", "reason": opsReason},
			response: schedule, print: func(w io.Writer) error { return printScheduleView(w, schedule) },
		},
		{
			name: "content profile", args: []string{"content", "profile", "--account", account.String(), "--purpose", "legal"},
			path: "/ops/v1/content:profile", body: map[string]any{"accountId": account.String(), "purpose": "legal", "reason": opsReason},
			response: profileView, print: func(w io.Writer) error { return printProfileView(w, profileView) },
		},
		{
			name: "audit list", args: []string{"audit", "list", "--account", account.String(), "--since", "2026-11-01", "--limit", "5"},
			path: "/ops/v1/audit:list", body: map[string]any{"accountId": account.String(), "since": "2026-11-01", "limit": float64(5), "reason": opsReason},
			response: records, print: func(w io.Writer) error { return printAuditRecords(w, records) },
		},
	}
	for _, tt := range tests {
		for _, asJSON := range []bool{false, true} {
			name := tt.name
			if asJSON {
				name += " --json"
			}
			t.Run(name, func(t *testing.T) {
				h := newOpsHarness(t)
				h.respond(http.StatusOK, tt.response)
				args := append(append([]string{}, tt.args...), "--env", "staging", "--reason", opsReason)
				if asJSON {
					args = append(args, "--json")
				}

				code, stdout, stderr := h.run(t, h.deps(), args...)
				require.Equal(t, 0, code, stderr)
				assert.Empty(t, stderr)

				requests := h.recorded()
				require.Len(t, requests, 1)
				got := requests[0]
				assert.Equal(t, http.MethodPost, got.method)
				assert.Equal(t, tt.path, got.path)
				assert.Equal(t, tt.body, got.body)
				assert.Equal(t, "Bearer "+testOpsIDToken, got.header.Get("Authorization"))
				assert.Equal(t, "1", got.header.Get("X-Myungli-Ops"))
				assert.Equal(t, "application/json", got.header.Get("Content-Type"))
				assert.Empty(t, got.header.Values("Origin"))
				assert.Empty(t, got.header.Values("Sec-Fetch-Site"))
				assert.Equal(t, 1, h.tokenCallCount())

				var want bytes.Buffer
				if asJSON {
					require.NoError(t, writeOpsJSON(&want, tt.response))
				} else {
					require.NoError(t, tt.print(&want))
				}
				assert.Equal(t, want.String(), stdout)
				assert.NotContains(t, stdout, "\x1b", "표는 제어문자를 바꾸고 JSON은 이스케이프합니다")
			})
		}
	}
}

func TestOpsClient_ErrorStatus(t *testing.T) {
	tests := []struct {
		status int
		code   int
	}{
		{http.StatusBadRequest, 2},
		{http.StatusUnauthorized, 1},
		{http.StatusForbidden, 1},
		{http.StatusNotFound, 1},
		{http.StatusConflict, 1},
		{http.StatusInternalServerError, 1},
		{http.StatusServiceUnavailable, 1},
	}
	for _, tt := range tests {
		t.Run(http.StatusText(tt.status), func(t *testing.T) {
			h := newOpsHarness(t)
			h.respond(tt.status, map[string]string{"code": "x", "message": "거절\x1b[31m 이유\n둘째 줄"})
			code, stdout, stderr := h.run(t, h.deps(), "account", "show", "--env", "staging", "--account", uuid.NewString(), "--reason", opsReason)
			assert.Equal(t, tt.code, code)
			assert.Empty(t, stdout)
			assert.Equal(t, "ops: 거절�[31m 이유 둘째 줄\n", stderr)
		})
	}

	t.Run("JSON이 아닌 오류 응답", func(t *testing.T) {
		h := newOpsHarness(t)
		h.respond(http.StatusUnauthorized, "<html>Invalid IAP credentials</html>")
		code, stdout, stderr := h.run(t, h.deps(), "account", "show", "--env", "staging", "--account", uuid.NewString(), "--reason", opsReason)
		assert.Equal(t, 1, code)
		assert.Empty(t, stdout)
		assert.Equal(t, "ops: 운영 API가 HTTP 401로 답했습니다\n", stderr)
	})

	t.Run("리디렉션은 따르지 않음", func(t *testing.T) {
		h := newOpsHarness(t)
		h.mu.Lock()
		h.apiStatus, h.apiBody = http.StatusFound, ""
		h.mu.Unlock()
		code, _, stderr := h.run(t, h.deps(), "account", "show", "--env", "staging", "--account", uuid.NewString(), "--reason", opsReason)
		assert.Equal(t, 1, code)
		assert.Equal(t, "ops: 운영 API가 HTTP 302로 답했습니다\n", stderr)
		assert.Len(t, h.recorded(), 1)
	})

	t.Run("성공 응답 형식 틀림", func(t *testing.T) {
		h := newOpsHarness(t)
		h.respond(http.StatusOK, "not json")
		code, stdout, stderr := h.run(t, h.deps(), "account", "show", "--env", "staging", "--account", uuid.NewString(), "--reason", opsReason)
		assert.Equal(t, 1, code)
		assert.Empty(t, stdout)
		assert.Contains(t, stderr, "ops: 운영 API 응답을 읽지 못했습니다")
	})
}

func TestOpsClient_TokenErrors(t *testing.T) {
	args := []string{"account", "show", "--env", "staging", "--account", uuid.NewString(), "--reason", opsReason}

	t.Run("refresh 실패", func(t *testing.T) {
		h := newOpsHarness(t)
		h.tokenStatus = http.StatusBadRequest
		// token endpoint가 비밀 값을 되돌려 보내도 출력에 넣지 않습니다.
		h.tokenBody = `{"error":"invalid_grant","error_description":"` + testOpsRefreshToken + " " + testOpsClientSecret + `"}`
		code, stdout, stderr := h.run(t, h.deps(), args...)
		assert.Equal(t, 1, code)
		assert.Empty(t, stdout)
		assert.Contains(t, stderr, "ID token을 받지 못했습니다")
		assert.Contains(t, stderr, "invalid_grant")
		assert.Contains(t, stderr, "server ops login --env staging")
		assert.Empty(t, h.recorded(), "token이 없으면 API를 부르지 않습니다")
	})

	t.Run("id_token 없음", func(t *testing.T) {
		h := newOpsHarness(t)
		h.tokenBody = `{"access_token":"at","token_type":"Bearer","expires_in":3600}`
		code, _, stderr := h.run(t, h.deps(), args...)
		assert.Equal(t, 1, code)
		assert.Contains(t, stderr, "id_token")
		assert.Empty(t, h.recorded())
	})

	t.Run("파일 없음", func(t *testing.T) {
		h := newOpsHarness(t)
		prodArgs := append([]string{}, args...)
		prodArgs[3] = "prod"
		code, _, stderr := h.run(t, h.deps(), prodArgs...)
		assert.Equal(t, 1, code)
		assert.Contains(t, stderr, "server ops login --env prod")
		assert.Equal(t, 0, h.tokenCallCount())
		assert.Empty(t, h.recorded())
	})

	t.Run("권한 644", func(t *testing.T) {
		h := newOpsHarness(t)
		h.writeCredentials(t, "staging", 0o644)
		code, _, stderr := h.run(t, h.deps(), args...)
		assert.Equal(t, 1, code)
		assert.Contains(t, stderr, "600")
		assert.Equal(t, 0, h.tokenCallCount())
		assert.Empty(t, h.recorded())
	})

	t.Run("칸 빠짐", func(t *testing.T) {
		h := newOpsHarness(t)
		path := filepath.Join(h.localDir, "server", "staging", "ops-oauth.json")
		require.NoError(t, os.WriteFile(path, []byte(`{"apiUrl":"`+h.api.URL+`","clientId":"c"}`), 0o600))
		code, _, stderr := h.run(t, h.deps(), args...)
		assert.Equal(t, 1, code)
		assert.Contains(t, stderr, "server ops login --env staging")
		assert.Equal(t, 0, h.tokenCallCount())
	})
}

func TestOpsClient_UsageErrorsBeforeNetwork(t *testing.T) {
	account := uuid.NewString()
	tests := []struct {
		name string
		args []string
	}{
		{"하위 명령 없음", nil},
		{"env 없음", []string{"account", "show", "--account", account, "--reason", opsReason}},
		{"env 틀림", []string{"account", "show", "--env", "dev", "--account", account, "--reason", opsReason}},
		{"사유 없음", []string{"account", "show", "--env", "staging", "--account", account}},
		{"days 범위", []string{"grant", "--env", "staging", "--account", account, "--entitlement", "ad_free", "--days", "0", "--reason", opsReason}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h := newOpsHarness(t)
			code, stdout, _ := h.run(t, h.deps(), tt.args...)
			assert.Equal(t, 2, code)
			assert.Empty(t, stdout)
			assert.Equal(t, 0, h.tokenCallCount())
			assert.Empty(t, h.recorded())
		})
	}
}

// TestOps_RunUsesClient는 server ops가 Run에서 운영 API 클라이언트로 이어지고, 사용법에 ops login이 있음을 확인합니다.
func TestOps_RunUsesClient(t *testing.T) {
	code, stdout, stderr := runCLIWithEnv(t, map[string]string{"MYUNGLI_LOCAL_DIR": t.TempDir()}, "ops")
	assert.Equal(t, 2, code)
	assert.Empty(t, stdout)
	assert.Contains(t, stderr, "login --env staging|prod --api-url")

	code, _, stderr = runCLIWithEnv(t, map[string]string{"MYUNGLI_LOCAL_DIR": t.TempDir()},
		"ops", "account", "show", "--env", "staging", "--account", uuid.NewString(), "--reason", opsReason)
	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "server ops login --env staging")

	_, stderr = runCLI(t)
	assert.Contains(t, stderr, "ops login|account|grant|revoke|content|audit")
}

// loginHarness는 ops login 시험의 가짜 OAuth 서버입니다.
type loginHarness struct {
	*opsHarness
	clientDir string

	mu        sync.Mutex
	exchanges []url.Values
	authURL   *url.URL
}

func newLoginHarness(t *testing.T) *loginHarness {
	t.Helper()
	h := &loginHarness{opsHarness: newOpsHarness(t)}
	h.token.Config.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		h.mu.Lock()
		h.exchanges = append(h.exchanges, r.PostForm)
		h.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"access_token":"at","token_type":"Bearer","expires_in":3600,"refresh_token":"`+testOpsRefreshToken+`","id_token":"`+testOpsIDToken+`"}`)
	})
	h.clientDir = filepath.Join(h.localDir, "server", "prod")
	require.NoError(t, os.MkdirAll(h.clientDir, 0o700))
	client := `{"installed":{"client_id":"` + testOpsClientID + `","client_secret":"` + testOpsClientSecret + `","redirect_uris":["http://localhost"]}}`
	require.NoError(t, os.WriteFile(filepath.Join(h.clientDir, "ops-oauth-client.json"), []byte(client), 0o600))
	return h
}

// browser는 브라우저 대신 인증 주소를 읽고, 리디렉션 주소로 code와 state를 보냅니다.
func (h *loginHarness) browser(t *testing.T, mutate func(query url.Values)) func(context.Context, string) error {
	return func(_ context.Context, raw string) error {
		authURL, err := url.Parse(raw)
		require.NoError(t, err)
		h.mu.Lock()
		h.authURL = authURL
		h.mu.Unlock()
		query := authURL.Query()
		callback := url.Values{"code": {"auth-code"}, "state": {query.Get("state")}}
		if mutate != nil {
			mutate(callback)
		}
		// 가짜 브라우저는 루프백 리디렉션 주소로 실제 GET을 보냅니다.
		req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, query.Get("redirect_uri")+"?"+callback.Encode(), nil)
		require.NoError(t, err)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		_ = resp.Body.Close()
		return nil
	}
}

func TestOpsLogin_WritesCredentials(t *testing.T) {
	h := newLoginHarness(t)
	deps := h.deps()
	deps.openBrowser = h.browser(t, nil)

	code, stdout, stderr := h.run(t, deps, "login", "--env", "prod", "--api-url", "https://server-ops-abc.a.run.app/")
	require.Equal(t, 0, code, stderr)
	assert.Empty(t, stdout)

	h.mu.Lock()
	authURL, exchanges := h.authURL, h.exchanges
	h.mu.Unlock()
	require.NotNil(t, authURL)
	query := authURL.Query()
	assert.Equal(t, "accounts.example.test", authURL.Host)
	assert.Equal(t, testOpsClientID, query.Get("client_id"))
	assert.Equal(t, "openid email", query.Get("scope"))
	assert.Equal(t, "offline", query.Get("access_type"))
	assert.Equal(t, "consent", query.Get("prompt"))
	assert.Equal(t, "S256", query.Get("code_challenge_method"))
	assert.NotEmpty(t, query.Get("code_challenge"))
	assert.GreaterOrEqual(t, len(query.Get("state")), 32)
	redirect, err := url.Parse(query.Get("redirect_uri"))
	require.NoError(t, err)
	assert.Equal(t, "127.0.0.1", redirect.Hostname())
	assert.Contains(t, stderr, authURL.String(), "인증 주소를 stderr에도 씁니다")

	require.Len(t, exchanges, 1)
	assert.Equal(t, "authorization_code", exchanges[0].Get("grant_type"))
	assert.Equal(t, "auth-code", exchanges[0].Get("code"))
	assert.NotEmpty(t, exchanges[0].Get("code_verifier"))
	assert.Equal(t, query.Get("redirect_uri"), exchanges[0].Get("redirect_uri"))

	path := filepath.Join(h.clientDir, "ops-oauth.json")
	info, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
	raw, err := os.ReadFile(path) //nolint:gosec // 시험 임시 폴더의 경로입니다
	require.NoError(t, err)
	var saved map[string]string
	require.NoError(t, json.Unmarshal(raw, &saved))
	assert.Equal(t, map[string]string{
		"apiUrl": "https://server-ops-abc.a.run.app", "clientId": testOpsClientID, "clientSecret": testOpsClientSecret, "refreshToken": testOpsRefreshToken,
	}, saved)
	entries, err := os.ReadDir(h.clientDir)
	require.NoError(t, err)
	assert.Len(t, entries, 2, "임시 파일이 남지 않습니다")
}

func TestOpsLogin_RejectsBadCallback(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(url.Values)
		want   string
	}{
		{"동의 거절", func(q url.Values) { q.Del("code"); q.Set("error", "access_denied") }, "access_denied"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h := newLoginHarness(t)
			deps := h.deps()
			deps.openBrowser = h.browser(t, tt.mutate)
			code, _, stderr := h.run(t, deps, "login", "--env", "prod", "--api-url", "https://ops.example.test")
			assert.Equal(t, 1, code)
			assert.Contains(t, stderr, tt.want)
			h.mu.Lock()
			assert.Empty(t, h.exchanges, "code를 바꾸지 않습니다")
			h.mu.Unlock()
			_, err := os.Stat(filepath.Join(h.clientDir, "ops-oauth.json"))
			assert.ErrorIs(t, err, os.ErrNotExist)
		})
	}
}

func TestOpsLogin_UsageAndClientFile(t *testing.T) {
	tests := []struct {
		name string
		args []string
		code int
		want string
	}{
		{"api-url 없음", []string{"login", "--env", "prod"}, 2, "--api-url"},
		{"env 없음", []string{"login", "--api-url", "https://ops.example.test"}, 2, "--env"},
		{"http 원격", []string{"login", "--env", "prod", "--api-url", "http://ops.example.test"}, 2, "https"},
		{"주소 아님", []string{"login", "--env", "prod", "--api-url", "ops.example.test"}, 2, "https"},
		{"query 있음", []string{"login", "--env", "prod", "--api-url", "https://ops.example.test/?a=1"}, 2, "--api-url"},
		{"클라이언트 파일 없음", []string{"login", "--env", "staging", "--api-url", "https://ops.example.test"}, 1, "ops-oauth-client.json"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h := newLoginHarness(t)
			deps := h.deps()
			deps.openBrowser = func(context.Context, string) error {
				t.Error("브라우저를 열기 전에 끝나야 합니다")
				return nil
			}
			code, _, stderr := h.run(t, deps, tt.args...)
			assert.Equal(t, tt.code, code)
			assert.Contains(t, stderr, tt.want)
		})
	}
}

func TestValidateOpsAPIURL_AllowsLocalHTTP(t *testing.T) {
	for _, raw := range []string{"http://127.0.0.1:8080", "http://[::1]:9000/", "https://ops.example.test/base"} {
		_, err := validateOpsAPIURL(raw)
		assert.NoError(t, err, raw)
	}
	normalized, err := validateOpsAPIURL("https://ops.example.test/base/")
	require.NoError(t, err)
	assert.Equal(t, "https://ops.example.test/base", normalized)
	for _, raw := range []string{"", "ftp://ops.example.test", "https://user:pw@ops.example.test", "https://ops.example.test#x", "http://10.0.0.1", "http://localhost:9000"} {
		_, err := validateOpsAPIURL(raw)
		assert.Error(t, err, raw)
	}
}

// TestOpsLogin_IgnoresStrayCallbacks는 콜백 경로가 아니거나 state가 맞지 않는 요청이 400만 받고,
// 로그인은 그 뒤에 오는 올바른 콜백으로 끝나는지 확인합니다.
func TestOpsLogin_IgnoresStrayCallbacks(t *testing.T) {
	h := newLoginHarness(t)
	deps := h.deps()
	correct := h.browser(t, nil)
	deps.openBrowser = func(ctx context.Context, raw string) error {
		authURL, err := url.Parse(raw)
		require.NoError(t, err)
		redirect := authURL.Query().Get("redirect_uri")
		state := authURL.Query().Get("state")
		for _, stray := range []string{
			redirect + "favicon.ico?" + url.Values{"state": {state}, "code": {"stray"}}.Encode(),
			redirect + "?" + url.Values{"state": {"other"}, "code": {"evil"}}.Encode(),
			redirect + "?" + url.Values{"state": {"other"}, "error": {"access_denied"}}.Encode(),
		} {
			req, err := http.NewRequestWithContext(ctx, http.MethodGet, stray, nil)
			require.NoError(t, err)
			resp, err := http.DefaultClient.Do(req)
			require.NoError(t, err)
			_ = resp.Body.Close()
			assert.Equal(t, http.StatusBadRequest, resp.StatusCode, stray)
		}
		return correct(ctx, raw)
	}

	code, _, stderr := h.run(t, deps, "login", "--env", "prod", "--api-url", "https://ops.example.test")
	require.Equal(t, 0, code, stderr)
	h.mu.Lock()
	defer h.mu.Unlock()
	require.Len(t, h.exchanges, 1)
	assert.Equal(t, "auth-code", h.exchanges[0].Get("code"))
}

func TestOpsLogin_RejectsGroupWritableDir(t *testing.T) {
	h := newLoginHarness(t)
	require.NoError(t, os.Chmod(h.clientDir, 0o770)) //nolint:gosec // 거절되는지 보려고 일부러 넓힌 권한입니다
	deps := h.deps()
	deps.openBrowser = func(context.Context, string) error {
		t.Error("브라우저를 열기 전에 끝나야 합니다")
		return nil
	}
	code, _, stderr := h.run(t, deps, "login", "--env", "prod", "--api-url", "https://ops.example.test")
	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "쓰기 권한")
	_, err := os.Stat(filepath.Join(h.clientDir, "ops-oauth.json"))
	assert.ErrorIs(t, err, os.ErrNotExist)
}

// 자격 파일을 읽을 때도 담은 폴더에 그룹 쓰기 권한이 있으면 거절합니다(파일 자체는 600이어도).
func TestLoadOpsCredentials_RejectsGroupWritableDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "server", "prod")
	require.NoError(t, os.MkdirAll(dir, 0o700))
	path := filepath.Join(dir, "ops-oauth.json")
	require.NoError(t, os.WriteFile(path, []byte(`{"apiUrl":"https://ops.example.test","clientId":"c","clientSecret":"s","refreshToken":"r"}`), 0o600))
	_, err := loadOpsCredentials(path, "prod")
	require.NoError(t, err, "권한이 좁은 폴더는 통과합니다")

	require.NoError(t, os.Chmod(dir, 0o770)) //nolint:gosec // 거절되는지 보려고 일부러 넓힌 권한입니다
	_, err = loadOpsCredentials(path, "prod")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "쓰기 권한")
}

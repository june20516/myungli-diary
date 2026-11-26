package opsapi_test

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/opsapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

const (
	operatorEmail   = "op@example.com"
	operatorSubject = "accounts.google.com:1234"
	// 사유는 개인정보 없는 문의 번호입니다. 로그에 나오면 안 되는 표식으로도 씁니다.
	secretReason = "문의-비밀사유-77" //nolint:gosec // 시험용 표식 문자열입니다.
)

// opsEnv는 운영 API 핸들러와 실제 DB, 로그 버퍼를 묶은 시험 환경입니다.
type opsEnv struct {
	handler http.Handler
	pool    *pgxpool.Pool
	key     *ecdsa.PrivateKey
	logs    *bytes.Buffer
}

type envOption func(*opsapi.Deps)

func newEnv(t *testing.T, options ...envOption) *opsEnv {
	t.Helper()
	key := newKey(t)
	pool := dbtest.New(t)
	logs := &bytes.Buffer{}
	deps := opsapi.Deps{
		Service:   ops.NewService(pool),
		Verifier:  newVerifier(t, key),
		Operators: opsapi.ParseAllowlist(" Op@Example.com , other@example.com "),
		Logger:    slog.New(slog.NewJSONHandler(logs, nil)),
	}
	for _, option := range options {
		option(&deps)
	}
	handler, err := opsapi.NewHandler(deps)
	require.NoError(t, err)
	return &opsEnv{handler: handler, pool: pool, key: key, logs: logs}
}

// request는 한 번의 호출을 기술합니다. 기본값은 허용된 운영자의 올바른 호출입니다.
type request struct {
	method  string
	path    string
	body    string
	headers map[string]string
	// omit은 기본 헤더 중 빼는 것입니다.
	omit []string
}

func (e *opsEnv) do(t *testing.T, r request) *httptest.ResponseRecorder {
	t.Helper()
	if r.method == "" {
		r.method = http.MethodPost
	}
	req := httptest.NewRequestWithContext(context.Background(), r.method, r.path, strings.NewReader(r.body))
	req.Header.Set(opsapi.AssertionHeader, sign(t, e.key, "k1", validClaims()))
	req.Header.Set("X-Myungli-Ops", "1")
	req.Header.Set("Content-Type", "application/json")
	for _, name := range r.omit {
		req.Header.Del(name)
	}
	for name, value := range r.headers {
		req.Header.Set(name, value)
	}
	rec := httptest.NewRecorder()
	e.handler.ServeHTTP(rec, req)
	return rec
}

// post는 올바른 헤더로 JSON 본문을 보냅니다.
func (e *opsEnv) post(t *testing.T, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	return e.do(t, request{path: path, body: body})
}

type errorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func decodeError(t *testing.T, rec *httptest.ResponseRecorder) errorBody {
	t.Helper()
	var body errorBody
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body), rec.Body.String())
	return body
}

func (e *opsEnv) auditCount(t *testing.T) int {
	t.Helper()
	var n int
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT count(*) FROM ops_audit`).Scan(&n))
	return n
}

func (e *opsEnv) insertAccount(t *testing.T) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), `INSERT INTO accounts (id, status, last_active_at, created_at)
		VALUES (gen_random_uuid(), 'active', now(), now()) RETURNING id`).Scan(&id))
	return id
}

func (e *opsEnv) exec(t *testing.T, query string, args ...any) {
	t.Helper()
	_, err := e.pool.Exec(context.Background(), query, args...)
	require.NoError(t, err)
}

func jsonBody(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	require.NoError(t, err)
	return string(raw)
}

func TestHandlers_CSRFGuard(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	body := jsonBody(t, map[string]any{"accountId": account, "reason": secretReason})

	tests := []struct {
		name string
		req  request
	}{
		{"사용자 정의 헤더 없음", request{path: "/ops/v1/accounts:show", body: body, omit: []string{"X-Myungli-Ops"}}},
		{"사용자 정의 헤더 값이 1이 아님", request{path: "/ops/v1/accounts:show", body: body, headers: map[string]string{"X-Myungli-Ops": "0"}}},
		{"form 본문", request{path: "/ops/v1/accounts:show", body: "accountId=" + account.String(), headers: map[string]string{"Content-Type": "application/x-www-form-urlencoded"}}},
		{"Content-Type 없음", request{path: "/ops/v1/accounts:show", body: body, omit: []string{"Content-Type"}}},
		{"Origin 있음", request{path: "/ops/v1/accounts:show", body: body, headers: map[string]string{"Origin": "https://evil.example"}}},
		{"cross-site", request{path: "/ops/v1/accounts:show", body: body, headers: map[string]string{"Sec-Fetch-Site": "cross-site"}}},
		{"same-origin", request{path: "/ops/v1/accounts:show", body: body, headers: map[string]string{"Sec-Fetch-Site": "same-origin"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := env.do(t, tt.req)
			assert.Equal(t, http.StatusForbidden, rec.Code)
			assert.Equal(t, "forbidden", decodeError(t, rec).Code)
		})
	}
	assert.Zero(t, env.auditCount(t), "거절은 감사 행을 남기지 않습니다")

	t.Run("Sec-Fetch-Site none과 charset 붙은 JSON은 통과", func(t *testing.T) {
		rec := env.do(t, request{path: "/ops/v1/accounts:show", body: body, headers: map[string]string{
			"Sec-Fetch-Site": "none", "Content-Type": "application/json; charset=utf-8",
		}})
		assert.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	})
}

func TestHandlers_Authentication(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	body := jsonBody(t, map[string]any{"accountId": account, "reason": secretReason})

	t.Run("서명 헤더 없음은 401", func(t *testing.T) {
		rec := env.do(t, request{path: "/ops/v1/accounts:show", body: body, omit: []string{opsapi.AssertionHeader}})
		assert.Equal(t, http.StatusUnauthorized, rec.Code)
		assert.Equal(t, "unauthenticated", decodeError(t, rec).Code)
	})
	t.Run("잘못된 서명은 401", func(t *testing.T) {
		rec := env.do(t, request{path: "/ops/v1/accounts:show", body: body, headers: map[string]string{opsapi.AssertionHeader: "a.b.c"}})
		assert.Equal(t, http.StatusUnauthorized, rec.Code)
		assert.Equal(t, "unauthenticated", decodeError(t, rec).Code)
	})
	t.Run("메일 헤더만으로는 인증되지 않음", func(t *testing.T) {
		rec := env.do(t, request{
			path: "/ops/v1/accounts:show", body: body, omit: []string{opsapi.AssertionHeader},
			headers: map[string]string{"x-goog-authenticated-user-email": "accounts.google.com:" + operatorEmail},
		})
		assert.Equal(t, http.StatusUnauthorized, rec.Code)
	})
	assert.Zero(t, env.auditCount(t))
}

func TestHandlers_KeysUnavailable(t *testing.T) {
	key := newKey(t)
	verifier := mustVerifier(t, staticKeys{err: errors.New("down")}, clocktest.New(testNow))
	env := newEnv(t, func(d *opsapi.Deps) { d.Verifier = verifier })
	rec := env.do(t, request{path: "/ops/v1/accounts:show", body: `{}`, headers: map[string]string{opsapi.AssertionHeader: sign(t, key, "k1", validClaims())}})
	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)
	assert.Equal(t, "unavailable", decodeError(t, rec).Code)
	assert.Zero(t, env.auditCount(t))
}

func TestHandlers_Allowlist(t *testing.T) {
	account := uuid.New()
	body := jsonBody(t, map[string]any{"accountId": account, "reason": secretReason})

	tests := []struct {
		name      string
		allowlist opsapi.Allowlist
	}{
		{"목록 밖", opsapi.ParseAllowlist("someone@example.com")},
		{"빈 목록", opsapi.ParseAllowlist("")},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := newEnv(t, func(d *opsapi.Deps) { d.Operators = tt.allowlist })
			rec := env.post(t, "/ops/v1/grants", body)
			assert.Equal(t, http.StatusForbidden, rec.Code)
			assert.Equal(t, "forbidden", decodeError(t, rec).Code)

			// IAP 검증을 통과한 실행자는 거절도 기록합니다. 본문(계정, 사유)은 읽지 않고 경로만 남깁니다.
			var action, actor, actorSub, target string
			var accountID *uuid.UUID
			require.NoError(t, env.pool.QueryRow(context.Background(),
				`SELECT action, actor, actor_sub, target::text, account_id FROM ops_audit`).Scan(&action, &actor, &actorSub, &target, &accountID))
			assert.Equal(t, "denied", action)
			assert.Equal(t, operatorEmail, actor)
			assert.Equal(t, operatorSubject, actorSub)
			assert.JSONEq(t, `{"route":"/ops/v1/grants"}`, target)
			assert.Nil(t, accountID)
			assert.Equal(t, 1, env.auditCount(t))
		})
	}
}

// 거절 기록이 실패해도 응답은 그대로 403이고, 로그에는 kind만 남습니다.
func TestHandlers_DeniedAuditFailureKeeps403(t *testing.T) {
	env := newEnv(t, func(d *opsapi.Deps) { d.Operators = opsapi.ParseAllowlist("someone@example.com") })
	env.pool.Close()

	rec := env.post(t, "/ops/v1/grants", jsonBody(t, map[string]any{"accountId": uuid.New(), "reason": secretReason}))
	assert.Equal(t, http.StatusForbidden, rec.Code)
	assert.Equal(t, "forbidden", decodeError(t, rec).Code)
	out := env.logs.String()
	assert.Contains(t, out, `"kind"`)
	for _, forbidden := range []string{operatorEmail, operatorSubject, secretReason, "closed pool"} {
		assert.NotContains(t, out, forbidden)
	}
}

// failingOperators는 운영자 목록을 읽지 못하는 원천입니다.
type failingOperators struct{}

func (failingOperators) Operators(context.Context) (opsapi.Allowlist, error) {
	return opsapi.Allowlist{}, opsapi.ErrOperatorsUnavailable
}

// 운영자 목록을 읽지 못하면 마지막 목록으로 통과시키지 않고 503으로 거절합니다. 거절 행은 남기지 않습니다.
func TestHandlers_OperatorsUnavailable(t *testing.T) {
	env := newEnv(t, func(d *opsapi.Deps) { d.Operators = failingOperators{} })
	rec := env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"accountId": uuid.New(), "reason": secretReason}))
	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)
	assert.Equal(t, "unavailable", decodeError(t, rec).Code)
	assert.Zero(t, env.auditCount(t))
	assert.Contains(t, env.logs.String(), `"kind":"operators_unavailable"`)
	assert.NotContains(t, env.logs.String(), operatorEmail)
}

// 콘텐츠 열람 세 경로는 합쳐서 운영자(sub)마다 분당 30건까지이고, 넘으면 429 rate_limited입니다.
// 다른 경로는 세지 않고, 1분이 지나면 다시 됩니다.
func TestHandlers_ContentRateLimit(t *testing.T) {
	clk := clocktest.New(testNow)
	env := newEnv(t, func(d *opsapi.Deps) { d.Clock = clk })
	paths := []string{"/ops/v1/content:diary", "/ops/v1/content:schedule", "/ops/v1/content:profile"}
	for i := range 30 {
		rec := env.post(t, paths[i%len(paths)], `{}`)
		require.Equal(t, http.StatusBadRequest, rec.Code, "%d번째: %s", i+1, rec.Body.String())
	}
	rec := env.post(t, "/ops/v1/content:diary", `{}`)
	assert.Equal(t, http.StatusTooManyRequests, rec.Code)
	assert.Equal(t, "rate_limited", decodeError(t, rec).Code)
	assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))

	// 콘텐츠 밖 경로는 상한에 걸리지 않습니다.
	assert.Equal(t, http.StatusBadRequest, env.post(t, "/ops/v1/accounts:show", `{}`).Code)

	// 다른 운영자는 따로 셉니다.
	other := validClaims()
	other["sub"], other["email"] = "accounts.google.com:5678", "other@example.com"
	rec = env.do(t, request{path: "/ops/v1/content:diary", body: `{}`, headers: map[string]string{opsapi.AssertionHeader: sign(t, env.key, "k1", other)}})
	assert.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())

	clk.Advance(time.Minute)
	assert.Equal(t, http.StatusBadRequest, env.post(t, "/ops/v1/content:diary", `{}`).Code)
}

func TestHandlers_ResponseHeaders(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	cases := map[string]*httptest.ResponseRecorder{
		"성공":        env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"accountId": account, "reason": secretReason})),
		"입력 오류":     env.post(t, "/ops/v1/accounts:show", `{`),
		"401":       env.do(t, request{path: "/ops/v1/accounts:show", omit: []string{opsapi.AssertionHeader}}),
		"405":       env.do(t, request{method: http.MethodGet, path: "/ops/v1/accounts:show"}),
		"없는 경로 404": env.post(t, "/ops/v1/nothing", `{}`),
	}
	for name, rec := range cases {
		assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"), name)
		assert.Equal(t, "application/json", rec.Header().Get("Content-Type"), name)
	}
}

func TestHandlers_MethodNotAllowed(t *testing.T) {
	env := newEnv(t)
	for _, method := range []string{http.MethodGet, http.MethodPut, http.MethodDelete} {
		rec := env.do(t, request{method: method, path: "/ops/v1/grants"})
		assert.Equal(t, http.StatusMethodNotAllowed, rec.Code, method)
		assert.Equal(t, http.MethodPost, rec.Header().Get("Allow"), method)
	}
	assert.Zero(t, env.auditCount(t))
}

func TestHandlers_BodyTooLarge(t *testing.T) {
	env := newEnv(t)
	body := `{"reason":"` + strings.Repeat("가", 30000) + `"}` // 90 KB 이상
	rec := env.post(t, "/ops/v1/audit:list", body)
	assert.Equal(t, http.StatusRequestEntityTooLarge, rec.Code)
	assert.Equal(t, "invalid_input", decodeError(t, rec).Code)
	assert.Zero(t, env.auditCount(t))
}

func TestHandlers_RejectsUnknownFields(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)

	bad := map[string]string{
		"알 수 없는 칸":   jsonBody(t, map[string]any{"accountId": account, "reason": secretReason, "extra": 1}),
		"snake_case": jsonBody(t, map[string]any{"account_id": account, "reason": secretReason}),
		"뒤에 다른 값":    jsonBody(t, map[string]any{"accountId": account, "reason": secretReason}) + ` {}`,
		"배열":         `[]`,
		"null":       `null`,
		"문자열":        `"x"`,
		"빈 본문":       ``,
		"형식이 다른 칸":   `{"accountId": 5, "reason": "x"}`,
	}
	for name, body := range bad {
		rec := env.post(t, "/ops/v1/accounts:show", body)
		assert.Equal(t, http.StatusBadRequest, rec.Code, name)
		assert.Equal(t, "invalid_input", decodeError(t, rec).Code, name)
	}
	assert.Zero(t, env.auditCount(t))
}

func TestHandlers_InputErrors(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	id := account.String()

	tests := []struct {
		name string
		path string
		body map[string]any
	}{
		{"사유에 @", "/ops/v1/accounts:show", map[string]any{"accountId": id, "reason": "a@b.com"}},
		{"사유 없음", "/ops/v1/accounts:show", map[string]any{"accountId": id}},
		{"계정 id 형식", "/ops/v1/accounts:show", map[string]any{"accountId": "not-a-uuid", "reason": secretReason}},
		{"계정 열쇠 없음", "/ops/v1/accounts:show", map[string]any{"reason": secretReason}},
		{"계정 열쇠 둘", "/ops/v1/accounts:show", map[string]any{"accountId": id, "storeTransaction": "tx-1", "reason": secretReason}},
		{"거래 id 형식", "/ops/v1/accounts:show", map[string]any{"storeTransaction": "한글", "reason": secretReason}},
		{"부여 종류", "/ops/v1/grants", map[string]any{"accountId": id, "entitlement": "gold", "days": 3, "reason": secretReason}},
		{"기간 없음", "/ops/v1/grants", map[string]any{"accountId": id, "entitlement": "ad_free", "reason": secretReason}},
		{"기간 둘", "/ops/v1/grants", map[string]any{"accountId": id, "entitlement": "ad_free", "days": 3, "until": "2030-01-01T00:00:00Z", "reason": secretReason}},
		{"일수 범위", "/ops/v1/grants", map[string]any{"accountId": id, "entitlement": "ad_free", "days": 367, "reason": secretReason}},
		{"until 형식", "/ops/v1/grants", map[string]any{"accountId": id, "entitlement": "ad_free", "until": "2030-01-01", "reason": secretReason}},
		{"회수 grantId 0", "/ops/v1/grants:revoke", map[string]any{"accountId": id, "grantId": 0, "reason": secretReason}},
		{"목적 없음", "/ops/v1/content:diary", map[string]any{"accountId": id, "date": "2026-11-20", "reason": secretReason}},
		{"날짜와 id 둘", "/ops/v1/content:diary", map[string]any{"accountId": id, "date": "2026-11-20", "id": uuid.NewString(), "purpose": "inquiry", "reason": secretReason}},
		{"날짜 형식", "/ops/v1/content:schedule", map[string]any{"accountId": id, "date": "20261120", "purpose": "inquiry", "reason": secretReason}},
		{"없는 날짜", "/ops/v1/content:schedule", map[string]any{"accountId": id, "date": "2026-02-30", "purpose": "inquiry", "reason": secretReason}},
		{"일정 id 형식", "/ops/v1/content:schedule", map[string]any{"accountId": id, "id": "x", "purpose": "inquiry", "reason": secretReason}},
		{"프로필 목적", "/ops/v1/content:profile", map[string]any{"accountId": id, "purpose": "curiosity", "reason": secretReason}},
		{"감사 조건 없음", "/ops/v1/audit:list", map[string]any{"reason": secretReason}},
		{"since 형식", "/ops/v1/audit:list", map[string]any{"since": "2026-11-20T00:00:00Z", "reason": secretReason}},
		{"limit 음수", "/ops/v1/audit:list", map[string]any{"accountId": id, "limit": -1, "reason": secretReason}},
		{"limit 범위", "/ops/v1/audit:list", map[string]any{"accountId": id, "limit": 1001, "reason": secretReason}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := env.post(t, tt.path, jsonBody(t, tt.body))
			assert.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
			got := decodeError(t, rec)
			assert.Equal(t, "invalid_input", got.Code)
			assert.NotEmpty(t, got.Message)
		})
	}
	assert.Zero(t, env.auditCount(t), "입력 오류는 감사 행을 남기지 않습니다")
}

type auditRow struct {
	Actor, ActorSub, Channel, Action, Reason string
	AccountID                                *uuid.UUID
}

func (e *opsEnv) lastAudit(t *testing.T) auditRow {
	t.Helper()
	var row auditRow
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`SELECT actor, actor_sub, channel, action, reason, account_id FROM ops_audit ORDER BY at DESC, id DESC LIMIT 1`).
		Scan(&row.Actor, &row.ActorSub, &row.Channel, &row.Action, &row.Reason, &row.AccountID))
	return row
}

func (e *opsEnv) wantAudit(t *testing.T, action string, account uuid.UUID) {
	t.Helper()
	got := e.lastAudit(t)
	assert.Equal(t, operatorEmail, got.Actor)
	assert.Equal(t, operatorSubject, got.ActorSub)
	assert.Equal(t, "ops_api", got.Channel)
	assert.Equal(t, action, got.Action)
	assert.Equal(t, secretReason, got.Reason)
	require.NotNil(t, got.AccountID)
	assert.Equal(t, account, *got.AccountID)
}

func decodeMap(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	var out map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &out))
	return out
}

func TestHandlers_AccountsShow(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)

	got := decodeMap(t, env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"accountId": account, "reason": secretReason})))
	assert.Equal(t, account.String(), got["account"].(map[string]any)["id"])
	assert.Contains(t, got, "identities")
	assert.Contains(t, got, "purchases")
	env.wantAudit(t, "account_show", account)

	env.exec(t, `INSERT INTO purchases (id, account_id, original_account_id, product_id, store, store_purchase_id, purchased_at, production)
		VALUES (gen_random_uuid(), $1, $1, 'ad_free_monthly', 'app_store', 'tx-abc.1', now(), false)`, account)
	got = decodeMap(t, env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"storeTransaction": "tx-abc.1", "reason": secretReason})))
	assert.Equal(t, account.String(), got["account"].(map[string]any)["id"])
}

func TestHandlers_AccountsShow_AmbiguousTransaction(t *testing.T) {
	env := newEnv(t)
	first, second := env.insertAccount(t), env.insertAccount(t)
	for _, account := range []uuid.UUID{first, second} {
		env.exec(t, `INSERT INTO purchases (id, account_id, original_account_id, product_id, store, store_purchase_id, purchased_at, production)
			VALUES (gen_random_uuid(), $1, $1, 'ad_free_monthly', 'app_store', 'dup-tx', now(), false)`, account)
	}
	rec := env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"storeTransaction": "dup-tx", "reason": secretReason}))
	assert.Equal(t, http.StatusConflict, rec.Code)
	got := decodeError(t, rec)
	assert.Equal(t, "conflict", got.Code)
	assert.Contains(t, got.Message, first.String())
	assert.Contains(t, got.Message, second.String())
	assert.Equal(t, 1, env.auditCount(t), "모호한 거래도 감사 행은 남습니다")
}

func TestHandlers_AccountNotFound(t *testing.T) {
	env := newEnv(t)
	rec := env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"accountId": uuid.New(), "reason": secretReason}))
	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "not_found", decodeError(t, rec).Code)
	assert.Equal(t, 1, env.auditCount(t), "계정이 없어도 감사 행은 남습니다")

	rec = env.post(t, "/ops/v1/content:diary", jsonBody(t, map[string]any{"accountId": uuid.New(), "date": "2026-11-20", "purpose": "inquiry", "reason": secretReason}))
	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "not_found", decodeError(t, rec).Code)
}

func TestHandlers_GrantAndRevoke(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)

	granted := decodeMap(t, env.post(t, "/ops/v1/grants", jsonBody(t, map[string]any{
		"accountId": account, "entitlement": "ad_free", "days": 7, "reason": secretReason,
	})))
	env.wantAudit(t, "grant", account)
	grants := granted["grants"].([]any)
	require.Len(t, grants, 2)
	assert.NotEmpty(t, granted["auditId"])
	grantID := int64(grants[0].(map[string]any)["id"].(float64))

	revoked := decodeMap(t, env.post(t, "/ops/v1/grants:revoke", jsonBody(t, map[string]any{
		"accountId": account, "grantId": grantID, "reason": secretReason,
	})))
	env.wantAudit(t, "revoke", account)
	assert.Contains(t, revoked, "before")
	assert.Contains(t, revoked, "after")

	rec := env.post(t, "/ops/v1/grants:revoke", jsonBody(t, map[string]any{"accountId": account, "grantId": grantID, "reason": secretReason}))
	assert.Equal(t, http.StatusConflict, rec.Code, "이미 끝난 권한")
	assert.Equal(t, "conflict", decodeError(t, rec).Code)

	until := time.Now().UTC().Add(48 * time.Hour).Format(time.RFC3339) //nolint:forbidigo // 시험 입력일 뿐입니다.
	untilGrant := env.post(t, "/ops/v1/grants", jsonBody(t, map[string]any{"accountId": account, "entitlement": "insight", "until": until, "reason": secretReason}))
	assert.Equal(t, http.StatusOK, untilGrant.Code, untilGrant.Body.String())
}

func TestHandlers_GrantStatusMapping(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)

	t.Run("ad_free_pass 회수는 409", func(t *testing.T) {
		var grantID int64
		require.NoError(t, env.pool.QueryRow(context.Background(), `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
			VALUES ($1, 'ad_free', 'ad_free_pass', 'pass-1', now() - interval '1 hour', now() + interval '1 hour') RETURNING id`, account).Scan(&grantID))
		rec := env.post(t, "/ops/v1/grants:revoke", jsonBody(t, map[string]any{"accountId": account, "grantId": grantID, "reason": secretReason}))
		assert.Equal(t, http.StatusConflict, rec.Code)
		assert.Equal(t, "conflict", decodeError(t, rec).Code)
		assert.Zero(t, env.auditCount(t), "회수 불가는 감사 행을 남기지 않습니다")
	})
	t.Run("없는 권한 행은 404", func(t *testing.T) {
		rec := env.post(t, "/ops/v1/grants:revoke", jsonBody(t, map[string]any{"accountId": account, "grantId": 999999, "reason": secretReason}))
		assert.Equal(t, http.StatusNotFound, rec.Code)
		assert.Equal(t, "not_found", decodeError(t, rec).Code)
		assert.Zero(t, env.auditCount(t), "권한 행 없음은 감사 행을 남기지 않습니다")
	})
	t.Run("지운 계정 부여는 409", func(t *testing.T) {
		deleted := env.insertAccount(t)
		env.exec(t, `UPDATE accounts SET status = 'deleted', deleted_at = now() WHERE id = $1`, deleted)
		rec := env.post(t, "/ops/v1/grants", jsonBody(t, map[string]any{"accountId": deleted, "entitlement": "ad_free", "days": 3, "reason": secretReason}))
		assert.Equal(t, http.StatusConflict, rec.Code)
		assert.Equal(t, "conflict", decodeError(t, rec).Code)
		assert.Zero(t, env.auditCount(t), "지운 계정 부여는 감사 행을 남기지 않습니다")
	})
	t.Run("없는 계정 부여는 404", func(t *testing.T) {
		rec := env.post(t, "/ops/v1/grants", jsonBody(t, map[string]any{"accountId": uuid.New(), "entitlement": "ad_free", "days": 3, "reason": secretReason}))
		assert.Equal(t, http.StatusNotFound, rec.Code)
		assert.Equal(t, "not_found", decodeError(t, rec).Code)
		assert.Zero(t, env.auditCount(t), "없는 계정 부여는 감사 행을 남기지 않습니다")
	})
}

func TestHandlers_Content(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	diaryID := uuid.New()
	scheduleID := uuid.New()
	env.exec(t, `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version) VALUES ($1, '2026-11-20', '{}', '[]'::jsonb, 'v1')`, account)
	env.exec(t, `INSERT INTO diaries (id, account_id, date, body, created_at, updated_at) VALUES ($1, $2, '2026-11-20', '일기 본문', now(), now())`, diaryID, account)
	env.exec(t, `INSERT INTO schedules (id, account_id, date, all_day, title) VALUES ($1, $2, '2026-11-20', true, '일정 제목')`, scheduleID, account)

	diary := decodeMap(t, env.post(t, "/ops/v1/content:diary", jsonBody(t, map[string]any{
		"accountId": account, "date": "2026-11-20", "purpose": "inquiry", "reason": secretReason,
	})))
	assert.Len(t, diary["entries"], 1)
	env.wantAudit(t, "content_view", account)

	byID := decodeMap(t, env.post(t, "/ops/v1/content:diary", jsonBody(t, map[string]any{
		"accountId": account, "id": diaryID, "purpose": "legal", "reason": secretReason,
	})))
	assert.Len(t, byID["entries"], 1)

	schedule := decodeMap(t, env.post(t, "/ops/v1/content:schedule", jsonBody(t, map[string]any{
		"accountId": account, "id": scheduleID, "purpose": "incident", "reason": secretReason,
	})))
	assert.Len(t, schedule["entries"], 1)
	env.wantAudit(t, "content_view", account)

	rec := env.post(t, "/ops/v1/content:profile", jsonBody(t, map[string]any{"accountId": account, "purpose": "policy", "reason": secretReason}))
	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "profile_not_found", decodeError(t, rec).Code)
	env.wantAudit(t, "content_view", account)

	env.exec(t, `INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
		birth_year, birth_month, birth_day, birth_time_status, birth_time, gender, birth_timezone, birth_place_status, birth_city_id, longitude, notify_status, birth_hash)
		VALUES ($1, '비밀호칭', 'ko', 'Asia/Seoul', 'solar', false, 1990, 5, 17, 'known', '07:30', 'female', 'Asia/Seoul', 'city', 'seoul', 126.978, 'not_asked', decode(repeat('ab', 32), 'hex'))`, account)
	profile := decodeMap(t, env.post(t, "/ops/v1/content:profile", jsonBody(t, map[string]any{"accountId": account, "purpose": "policy", "reason": secretReason})))
	assert.NotEmpty(t, profile)
}

func TestHandlers_AuditList(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"accountId": account, "reason": secretReason}))

	byAccount := env.post(t, "/ops/v1/audit:list", jsonBody(t, map[string]any{"accountId": account, "limit": 10, "reason": secretReason}))
	require.Equal(t, http.StatusOK, byAccount.Code, byAccount.Body.String())
	var records []map[string]any
	require.NoError(t, json.Unmarshal(byAccount.Body.Bytes(), &records))
	require.Len(t, records, 1)
	assert.Equal(t, operatorEmail, records[0]["actor"])
	assert.Equal(t, operatorSubject, records[0]["actorSub"])
	env.wantAudit(t, "audit_list", account)

	since := env.post(t, "/ops/v1/audit:list", jsonBody(t, map[string]any{"since": "2020-01-01", "reason": secretReason}))
	require.Equal(t, http.StatusOK, since.Code, since.Body.String())
	assert.True(t, strings.HasPrefix(since.Body.String(), "["), "빈 결과도 JSON 배열이어야 합니다")
}

func TestHandlers_InternalErrorIsOpaque(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	env.pool.Close()

	rec := env.post(t, "/ops/v1/accounts:show", jsonBody(t, map[string]any{"accountId": account, "reason": secretReason}))
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	got := decodeError(t, rec)
	assert.Equal(t, "internal", got.Code)
	assert.Equal(t, "내부 오류입니다", got.Message)
	assert.NotContains(t, env.logs.String(), "closed pool", "오류 원문은 로그에 넣지 않습니다")
	assert.Contains(t, env.logs.String(), `"kind"`)
}

func TestHandlers_LogsHaveNoSensitiveValues(t *testing.T) {
	env := newEnv(t)
	account := env.insertAccount(t)
	env.exec(t, `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version) VALUES ($1, '2026-11-20', '{}', '[]'::jsonb, 'v1')`, account)
	env.exec(t, `INSERT INTO diaries (id, account_id, date, body, created_at, updated_at) VALUES (gen_random_uuid(), $1, '2026-11-20', '로그에-나오면-안되는-본문', now(), now())`, account)

	env.post(t, "/ops/v1/content:diary", jsonBody(t, map[string]any{"accountId": account, "date": "2026-11-20", "purpose": "legal", "reason": secretReason}))
	env.post(t, "/ops/v1/accounts:show?reason=쿼리-비밀", jsonBody(t, map[string]any{"accountId": account, "reason": secretReason}))
	env.post(t, "/ops/v1/accounts:show", `{`)
	env.do(t, request{path: "/ops/v1/accounts:show", omit: []string{opsapi.AssertionHeader}})
	env.post(t, "/ops/v1/nothing", `{}`)

	out := env.logs.String()
	require.NotEmpty(t, out)
	for _, forbidden := range []string{secretReason, "legal", operatorEmail, "example.com", operatorSubject, "로그에-나오면-안되는-본문", "쿼리-비밀", account.String(), "Bearer"} {
		assert.NotContains(t, out, forbidden)
	}

	assert.Contains(t, out, `"route":"unmatched"`, "없는 경로는 unmatched로 남습니다")
	dec := json.NewDecoder(strings.NewReader(out))
	for {
		var line map[string]any
		if err := dec.Decode(&line); errors.Is(err, io.EOF) {
			break
		} else {
			require.NoError(t, err)
		}
		assert.ElementsMatch(t, []string{"time", "level", "msg", "method", "route", "status", "latencyMs"}, mapKeys(line))
		assert.Contains(t, []any{"/ops/v1/accounts:show", "/ops/v1/content:diary", "unmatched"}, line["route"], "route는 등록 패턴입니다")
	}
}

func mapKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	return keys
}

func TestNewHandler_RejectsMissingDeps(t *testing.T) {
	key := newKey(t)
	full := opsapi.Deps{
		Service:   &ops.Service{},
		Verifier:  newVerifier(t, key),
		Operators: opsapi.ParseAllowlist(""),
		Logger:    slog.New(slog.NewJSONHandler(io.Discard, nil)),
	}
	for name, mutate := range map[string]func(*opsapi.Deps){
		"Operators": func(d *opsapi.Deps) { d.Operators = nil },
		"Service":   func(d *opsapi.Deps) { d.Service = nil },
		"Verifier":  func(d *opsapi.Deps) { d.Verifier = nil },
		"Logger":    func(d *opsapi.Deps) { d.Logger = nil },
	} {
		deps := full
		mutate(&deps)
		handler, err := opsapi.NewHandler(deps)
		assert.Error(t, err, name)
		assert.Nil(t, handler, name)
	}
	handler, err := opsapi.NewHandler(full)
	assert.NoError(t, err)
	assert.NotNil(t, handler)
}

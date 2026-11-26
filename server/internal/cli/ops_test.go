package cli

import (
	"context"
	"encoding/json"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const opsReason = "문의 대응"

// opsEnv는 migration을 적용한 빈 DB의 환경 변수입니다.
func opsEnv(t *testing.T) (map[string]string, *pgxpool.Pool) {
	t.Helper()
	databaseURL := dbtest.NewURL(t)
	pool, err := postgres.Open(context.Background(), databaseURL)
	require.NoError(t, err)
	t.Cleanup(pool.Close)
	return map[string]string{"DATABASE_URL": databaseURL}, pool
}

func opsAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		`INSERT INTO accounts (id, status, last_active_at, created_at) VALUES (gen_random_uuid(), 'active', now(), now()) RETURNING id`).Scan(&id))
	return id
}

func TestOps_UsageErrors(t *testing.T) {
	account := uuid.NewString()
	longReason := strings.Repeat("가", 501)
	tests := []struct {
		name string
		args []string
	}{
		{"하위 명령 없음", []string{"ops"}},
		{"모르는 하위 명령", []string{"ops", "nope"}},
		{"account show 없이 account", []string{"ops", "account"}},
		{"사유 없음", []string{"ops", "account", "show", "--account", account}},
		{"사유 줄바꿈", []string{"ops", "account", "show", "--account", account, "--reason", "a\nb"}},
		{"사유 501자", []string{"ops", "account", "show", "--account", account, "--reason", longReason}},
		{"account와 store-transaction 둘 다", []string{"ops", "account", "show", "--account", account, "--store-transaction", "t1", "--reason", opsReason}},
		{"account와 store-transaction 없음", []string{"ops", "account", "show", "--reason", opsReason}},
		{"account uuid 아님", []string{"ops", "account", "show", "--account", "x", "--reason", opsReason}},
		{"모르는 인자", []string{"ops", "account", "show", "--account", account, "--reason", opsReason, "--bogus"}},
		{"남는 위치 인자", []string{"ops", "account", "show", "--account", account, "--reason", opsReason, "extra"}},
		{"목적 틀림", []string{"ops", "content", "profile", "--account", account, "--purpose", "curious", "--reason", opsReason}},
		{"목적 없음", []string{"ops", "content", "profile", "--account", account, "--reason", opsReason}},
		{"date와 id 둘 다", []string{"ops", "content", "diary", "--account", account, "--date", "2026-11-20", "--id", uuid.NewString(), "--purpose", "inquiry", "--reason", opsReason}},
		{"date와 id 없음", []string{"ops", "content", "diary", "--account", account, "--purpose", "inquiry", "--reason", opsReason}},
		{"date 형식", []string{"ops", "content", "schedule", "--account", account, "--date", "2026-02-30", "--purpose", "inquiry", "--reason", opsReason}},
		{"profile에 date", []string{"ops", "content", "profile", "--account", account, "--date", "2026-11-20", "--purpose", "inquiry", "--reason", opsReason}},
		{"content 종류 틀림", []string{"ops", "content", "all", "--account", account, "--purpose", "inquiry", "--reason", opsReason}},
		{"days 0", []string{"ops", "grant", "--account", account, "--entitlement", "ad_free", "--days", "0", "--reason", opsReason}},
		{"days 367", []string{"ops", "grant", "--account", account, "--entitlement", "ad_free", "--days", "367", "--reason", opsReason}},
		{"days와 until 둘 다", []string{"ops", "grant", "--account", account, "--entitlement", "ad_free", "--days", "3", "--until", "2030-01-01T00:00:00Z", "--reason", opsReason}},
		{"days와 until 없음", []string{"ops", "grant", "--account", account, "--entitlement", "ad_free", "--reason", opsReason}},
		{"until 형식", []string{"ops", "grant", "--account", account, "--entitlement", "ad_free", "--until", "내일", "--reason", opsReason}},
		{"entitlement 틀림", []string{"ops", "grant", "--account", account, "--entitlement", "vip", "--days", "3", "--reason", opsReason}},
		{"grant id 없음", []string{"ops", "revoke", "--account", account, "--reason", opsReason}},
		{"audit list 조건 없음", []string{"ops", "audit", "list", "--reason", opsReason}},
		{"audit limit 범위", []string{"ops", "audit", "list", "--account", account, "--limit", "1001", "--reason", opsReason}},
		{"audit limit 0", []string{"ops", "audit", "list", "--account", account, "--limit", "0", "--reason", opsReason}},
		{"audit since 형식", []string{"ops", "audit", "list", "--since", "11/20", "--reason", opsReason}},
		{"audit list 아님", []string{"ops", "audit", "--account", account, "--reason", opsReason}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// DATABASE_URL이 비어 있어도 종료 코드 2이면 DB에 붙기 전에 끝난 것입니다(붙으려 하면 1).
			code, stdout, stderr := runCLIWithEnv(t, nil, tt.args...)
			assert.Equal(t, 2, code, "stderr = %q", stderr)
			assert.Empty(t, stdout)
			assert.NotEmpty(t, stderr)
		})
	}
}

func TestOps_NoDatabaseURL_Exits1(t *testing.T) {
	code, _, stderr := runCLIWithEnv(t, nil, "ops", "account", "show", "--account", uuid.NewString(), "--reason", opsReason)
	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "DATABASE_URL")
}

func TestOps_AccountShowText(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "account", "show", "--account", id.String(), "--reason", opsReason)

	require.Equal(t, 0, code, "stderr = %q", stderr)
	assert.Empty(t, stderr)
	for _, section := range []string{"[계정]", "[로그인 수단]", "[기기]", "[권한 상태]", "[권한 행]", "[구매]"} {
		assert.Contains(t, stdout, section)
	}
	assert.Contains(t, stdout, id.String())
}

func TestOps_AccountShowNotFound_Exits1(t *testing.T) {
	env, _ := opsEnv(t)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "account", "show", "--account", uuid.NewString(), "--reason", opsReason)

	assert.Equal(t, 1, code)
	assert.Empty(t, stdout)
	assert.Equal(t, "ops: 계정을 찾을 수 없습니다\n", stderr)
}

func TestOps_AccountShowAmbiguousTransaction_ListsCandidates(t *testing.T) {
	env, pool := opsEnv(t)
	first, second := opsAccount(t, pool), opsAccount(t, pool)
	for _, id := range []uuid.UUID{first, second} {
		_, err := pool.Exec(context.Background(), `INSERT INTO purchases (id, account_id, original_account_id, product_id, store, store_purchase_id, purchased_at, production)
			VALUES (gen_random_uuid(), $1, $1, 'ad_free_monthly', 'app_store', 'dup-tx', now(), false)`, id)
		require.NoError(t, err)
	}

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "account", "show", "--store-transaction", "dup-tx", "--reason", opsReason)

	assert.Equal(t, 1, code)
	assert.Empty(t, stdout)
	assert.Contains(t, stderr, first.String())
	assert.Contains(t, stderr, second.String())
	assert.Equal(t, 1, strings.Count(stderr, "\n"), "오류는 한 줄이어야 합니다: %q", stderr)
}

func TestOps_GrantThenRevokeJSON(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "grant", "--account", id.String(), "--entitlement", "ad_free", "--days", "30", "--reason", opsReason, "--json")
	require.Equal(t, 0, code, "stderr = %q", stderr)
	var granted struct {
		AuditID string `json:"auditId"`
		Grants  []struct {
			ID          int64  `json:"id"`
			Entitlement string `json:"entitlement"`
			Source      string `json:"source"`
			SourceRef   string `json:"sourceRef"`
			ExpiresAt   string `json:"expiresAt"`
		} `json:"grants"`
	}
	require.NoError(t, json.Unmarshal([]byte(stdout), &granted), stdout)
	require.Len(t, granted.Grants, 2)
	assert.Equal(t, "operator", granted.Grants[0].Source)
	assert.Equal(t, granted.AuditID, granted.Grants[0].SourceRef)
	assert.NotEmpty(t, granted.Grants[0].ExpiresAt)
	// ad_free 묶음은 ad_free와 insight 두 행입니다.
	entitlements := []string{granted.Grants[0].Entitlement, granted.Grants[1].Entitlement}
	assert.ElementsMatch(t, []string{"ad_free", "insight"}, entitlements)

	// 부여 직후 계정 조회 JSON에는 권한 상태 키가 camelCase로 나옵니다.
	code, stdout, stderr = runCLIWithEnv(t, env, "ops", "account", "show", "--account", id.String(), "--reason", opsReason, "--json")
	require.Equal(t, 0, code, "stderr = %q", stderr)
	var shown map[string]any
	require.NoError(t, json.Unmarshal([]byte(stdout), &shown), stdout)
	status, ok := shown["status"].(map[string]any)
	require.True(t, ok, stdout)
	adFree, ok := status["adFree"].(map[string]any)
	require.True(t, ok, stdout)
	assert.Equal(t, true, adFree["active"])
	assert.Contains(t, status, "insight")
	assert.Contains(t, shown["account"], "lastActiveAt")

	code, stdout, stderr = runCLIWithEnv(t, env, "ops", "revoke", "--account", id.String(), "--grant", jsonInt(granted.Grants[0].ID), "--reason", opsReason, "--json")
	require.Equal(t, 0, code, "stderr = %q", stderr)
	var revoked struct {
		AuditID string `json:"auditId"`
		Before  []struct {
			RevokedAt *string `json:"revokedAt"`
		} `json:"before"`
		After []struct {
			RevokedAt *string `json:"revokedAt"`
		} `json:"after"`
	}
	require.NoError(t, json.Unmarshal([]byte(stdout), &revoked), stdout)
	require.Len(t, revoked.After, 2)
	for i := range revoked.After {
		assert.Nil(t, revoked.Before[i].RevokedAt)
		assert.NotNil(t, revoked.After[i].RevokedAt)
	}
	assert.NotEqual(t, granted.AuditID, revoked.AuditID)
}

func jsonInt(n int64) string {
	b, _ := json.Marshal(n)
	return string(b)
}

func TestOps_GrantAndRevokeTextEndWithAuditLine(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	until := time.Now().UTC().Add(48 * time.Hour).Format(time.RFC3339)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "grant", "--account", id.String(), "--entitlement", "insight", "--until", until, "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)
	lines := strings.Split(strings.TrimSpace(stdout), "\n")
	last := lines[len(lines)-1]
	require.True(t, strings.HasPrefix(last, "감사 기록 "), stdout)
	_, err := uuid.Parse(strings.TrimPrefix(last, "감사 기록 "))
	require.NoError(t, err)

	var grantID int64
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT id FROM entitlement_grants WHERE account_id = $1`, id).Scan(&grantID))
	code, stdout, stderr = runCLIWithEnv(t, env, "ops", "revoke", "--account", id.String(), "--grant", jsonInt(grantID), "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)
	assert.Contains(t, stdout, "[회수 전]")
	assert.Contains(t, stdout, "감사 기록 ")

	// 같은 행을 다시 회수하면 거절이고 종료 코드 1입니다.
	code, _, stderr = runCLIWithEnv(t, env, "ops", "revoke", "--account", id.String(), "--grant", jsonInt(grantID), "--reason", opsReason)
	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "이미 끝난 권한")
}

func TestOps_GrantServiceRejectionsExit2(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	past := time.Now().UTC().Add(-time.Hour).Format(time.RFC3339)

	code, _, stderr := runCLIWithEnv(t, env, "ops", "grant", "--account", id.String(), "--entitlement", "insight", "--until", past, "--reason", opsReason)

	assert.Equal(t, 2, code, "stderr = %q", stderr)
}

const opsDiaryBody = "오늘은 비밀스러운 본문입니다 sentinel-body"

func TestOps_ContentBodyOnlyOnStdout(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	_, err := pool.Exec(context.Background(), `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
		VALUES ($1, '2026-11-20', ARRAY['a'], '[]'::jsonb, 'v1')`, id)
	require.NoError(t, err)
	_, err = pool.Exec(context.Background(), `INSERT INTO diaries (id, account_id, date, body, created_at, updated_at) VALUES (gen_random_uuid(), $1, '2026-11-20', $2, now(), now())`, id, opsDiaryBody)
	require.NoError(t, err)

	args := []string{"ops", "content", "diary", "--account", id.String(), "--date", "2026-11-20", "--purpose", "inquiry", "--reason", opsReason}
	code, stdout, stderr := runCLIWithEnv(t, env, args...)
	require.Equal(t, 0, code, "stderr = %q", stderr)
	assert.Contains(t, stdout, opsDiaryBody)
	assert.NotContains(t, stderr, opsDiaryBody)
	assert.Empty(t, stderr)

	// JSON은 날짜가 문자열이고 키가 camelCase입니다.
	code, stdout, stderr = runCLIWithEnv(t, env, append(args, "--json")...)
	require.Equal(t, 0, code, "stderr = %q", stderr)
	assert.Empty(t, stderr)
	var view struct {
		Entries []struct {
			Date      string `json:"date"`
			Body      string `json:"body"`
			CreatedAt string `json:"createdAt"`
		} `json:"entries"`
		DeletedCount *int     `json:"deletedCount"`
		Tags         []string `json:"tags"`
	}
	require.NoError(t, json.Unmarshal([]byte(stdout), &view), stdout)
	require.Len(t, view.Entries, 1)
	assert.Equal(t, "2026-11-20", view.Entries[0].Date)
	assert.Equal(t, opsDiaryBody, view.Entries[0].Body)
	assert.NotEmpty(t, view.Entries[0].CreatedAt)
	assert.NotNil(t, view.DeletedCount)
}

func TestOps_ContentScheduleAndProfileJSON(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	_, err := pool.Exec(context.Background(), `INSERT INTO schedules (id, account_id, date, all_day, title, memo) VALUES (gen_random_uuid(), $1, '2026-11-21', true, '병원', '메모 본문')`, id)
	require.NoError(t, err)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "content", "schedule", "--account", id.String(), "--date", "2026-11-21", "--purpose", "incident", "--reason", opsReason, "--json")
	require.Equal(t, 0, code, "stderr = %q", stderr)
	var schedule struct {
		Entries []struct {
			Date   string  `json:"date"`
			AllDay bool    `json:"allDay"`
			Memo   *string `json:"memo"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal([]byte(stdout), &schedule), stdout)
	require.Len(t, schedule.Entries, 1)
	assert.Equal(t, "2026-11-21", schedule.Entries[0].Date)
	assert.True(t, schedule.Entries[0].AllDay)

	// 프로필 행이 없으면 계정 없음과 같이 종료 코드 1입니다.
	code, _, stderr = runCLIWithEnv(t, env, "ops", "content", "profile", "--account", id.String(), "--purpose", "legal", "--reason", opsReason)
	assert.Equal(t, 1, code)
	assert.Equal(t, "ops: 계정을 찾을 수 없습니다\n", stderr)
}

func TestOps_AuditListJSON(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	code, _, stderr := runCLIWithEnv(t, env, "ops", "account", "show", "--account", id.String(), "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "audit", "list", "--account", id.String(), "--limit", "5", "--reason", opsReason, "--json")
	require.Equal(t, 0, code, "stderr = %q", stderr)
	var records []struct {
		Action    string  `json:"action"`
		Channel   string  `json:"channel"`
		AccountID *string `json:"accountId"`
		Reason    string  `json:"reason"`
	}
	require.NoError(t, json.Unmarshal([]byte(stdout), &records), stdout)
	require.Len(t, records, 1)
	assert.Equal(t, "account_show", records[0].Action)
	assert.Equal(t, "cli", records[0].Channel)

	code, stdout, stderr = runCLIWithEnv(t, env, "ops", "audit", "list", "--since", "2020-01-01", "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)
	assert.Contains(t, stdout, "account_show")
	assert.Contains(t, stdout, "audit_list")
}

// opsRole은 연결 가능한 DB 사용자를 만들고 그 사용자로 붙는 환경 변수를 돌려줍니다. member면 운영자 역할 구성원입니다.
func opsRole(t *testing.T, pool *pgxpool.Pool, env map[string]string, member bool) (string, map[string]string) {
	t.Helper()
	ctx := context.Background()
	name := "ops_cli_" + strings.ReplaceAll(uuid.NewString()[:8], "-", "")
	quoted := pgx.Identifier{name}.Sanitize()
	_, err := pool.Exec(ctx, "CREATE ROLE "+quoted+" LOGIN PASSWORD 'pw'")
	require.NoError(t, err)
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), "DROP ROLE IF EXISTS "+quoted) })
	if member {
		_, err = pool.Exec(ctx, "GRANT "+pgx.Identifier{postgres.OpsRole}.Sanitize()+" TO "+quoted)
		require.NoError(t, err)
	}
	parsed, err := url.Parse(env["DATABASE_URL"])
	require.NoError(t, err)
	parsed.User = url.UserPassword(name, "pw")
	return name, map[string]string{"DATABASE_URL": parsed.String()}
}

func TestOps_ActorIsSessionUser(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	name, roleEnv := opsRole(t, pool, env, true)

	code, _, stderr := runCLIWithEnv(t, roleEnv, "ops", "account", "show", "--account", id.String(), "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)

	var actor, channel string
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT actor, channel FROM ops_audit`).Scan(&actor, &channel))
	assert.Equal(t, name, actor)
	assert.Equal(t, "cli", channel)
}

func TestOps_NonOperatorRole_Exits1WithGuidance(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	name, roleEnv := opsRole(t, pool, env, false)

	code, stdout, stderr := runCLIWithEnv(t, roleEnv, "ops", "account", "show", "--account", id.String(), "--reason", opsReason)

	assert.Equal(t, 1, code)
	assert.Empty(t, stdout)
	assert.Equal(t, "ops: DB 사용자 "+name+"에 운영자 역할이 없습니다. runbook '운영자 등록'을 보세요\n", stderr)
}

func TestOps_UntilOffsetIsStoredAsUTC(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	expires := time.Now().UTC().Add(48 * time.Hour).Truncate(time.Second)
	until := expires.In(time.FixedZone("KST", 9*3600)).Format(time.RFC3339)
	require.True(t, strings.HasSuffix(until, "+09:00"), until)

	code, _, stderr := runCLIWithEnv(t, env, "ops", "grant", "--account", id.String(), "--entitlement", "insight", "--until", until, "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)

	var target string
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT target->>'expiresAt' FROM ops_audit WHERE action = 'grant'`).Scan(&target))
	assert.Equal(t, expires.Format(time.RFC3339), target)
	var stored time.Time
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT expires_at FROM entitlement_grants WHERE account_id = $1`, id).Scan(&stored))
	assert.True(t, expires.Equal(stored), "stored = %v, want %v", stored, expires)
}

func TestOps_AuditSinceIsUTCMidnightBoundary(t *testing.T) {
	env, pool := opsEnv(t)
	for _, at := range []string{"2026-10-31T23:59:59Z", "2026-11-01T00:00:00Z"} {
		_, err := pool.Exec(context.Background(), `INSERT INTO ops_audit (id, at, actor, channel, action, reason, target)
			VALUES (gen_random_uuid(), $1, 'seed', 'cli', 'account_show', $2, '{}')`, at, "경계 "+at)
		require.NoError(t, err)
	}

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "audit", "list", "--since", "2026-11-01", "--reason", opsReason, "--json")
	require.Equal(t, 0, code, "stderr = %q", stderr)
	var records []struct {
		Reason string `json:"reason"`
	}
	require.NoError(t, json.Unmarshal([]byte(stdout), &records), stdout)
	var seeded []string
	for _, record := range records {
		if strings.HasPrefix(record.Reason, "경계 ") {
			seeded = append(seeded, record.Reason)
		}
	}
	assert.Equal(t, []string{"경계 2026-11-01T00:00:00Z"}, seeded)
}

func TestOps_JSONEmptyListsAreArrays(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)

	_, stdout, _ := runCLIWithEnv(t, env, "ops", "account", "show", "--account", id.String(), "--reason", opsReason, "--json")
	for _, key := range []string{"identities", "devices", "grants", "purchases"} {
		assert.Contains(t, stdout, `"`+key+`": []`, stdout)
	}

	_, stdout, _ = runCLIWithEnv(t, env, "ops", "content", "diary", "--account", id.String(), "--date", "2026-11-20", "--purpose", "inquiry", "--reason", opsReason, "--json")
	assert.Contains(t, stdout, `"entries": []`)
	assert.Contains(t, stdout, `"tags": []`)

	_, stdout, _ = runCLIWithEnv(t, env, "ops", "content", "schedule", "--account", id.String(), "--date", "2026-11-20", "--purpose", "inquiry", "--reason", opsReason, "--json")
	assert.Contains(t, stdout, `"entries": []`)

	_, stdout, _ = runCLIWithEnv(t, env, "ops", "audit", "list", "--since", "2999-01-01", "--reason", opsReason, "--json")
	assert.Equal(t, "[]", strings.TrimSpace(stdout))
}

func TestOps_TextStripsTerminalControlCharacters(t *testing.T) {
	env, pool := opsEnv(t)
	id := opsAccount(t, pool)
	body := "빨강\x1b[31m글자\u009b끝\n둘째 줄\t탭"
	_, err := pool.Exec(context.Background(), `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
		VALUES ($1, '2026-11-20', ARRAY['a'], '[]'::jsonb, 'v1')`, id)
	require.NoError(t, err)
	_, err = pool.Exec(context.Background(), `INSERT INTO diaries (id, account_id, date, body, created_at, updated_at) VALUES (gen_random_uuid(), $1, '2026-11-20', $2, now(), now())`, id, body)
	require.NoError(t, err)

	code, stdout, stderr := runCLIWithEnv(t, env, "ops", "content", "diary", "--account", id.String(), "--date", "2026-11-20", "--purpose", "inquiry", "--reason", opsReason)
	require.Equal(t, 0, code, "stderr = %q", stderr)
	assert.NotContains(t, stdout, "\x1b")
	assert.NotContains(t, stdout, "\u009b")
	assert.Contains(t, stdout, "빨강�[31m글자�끝\n둘째 줄\t탭")

	// JSON은 이스케이프되어 그대로입니다.
	_, stdout, _ = runCLIWithEnv(t, env, "ops", "content", "diary", "--account", id.String(), "--date", "2026-11-20", "--purpose", "inquiry", "--reason", opsReason, "--json")
	assert.NotContains(t, stdout, "\x1b")
	assert.Contains(t, stdout, `\u001b[31m`)
}

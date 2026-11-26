package cli

import (
	"bytes"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

const opsReason = "문의 대응"

// TestOps_UsageErrors는 인자 해석(parseOps) 표입니다. 각 사례 끝에 --env staging을 붙여 환경이 아닌 다른 원인으로 거절되는지 봅니다.
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
			// 인자 해석은 네트워크에 붙지 않습니다. 첫 인자 "ops"는 떼고 넘깁니다.
			args := append(append([]string{}, tt.args[1:]...), "--env", "staging")
			_, err := parseOps(args)
			var usage *usageError
			assert.ErrorAs(t, err, &usage)
		})
	}
}

func TestSanitizeTerminal_ReplacesBidiControls(t *testing.T) {
	for _, r := range []rune{'\u061C', '\u200E', '\u200F', '\u202A', '\u202B', '\u202C', '\u202D', '\u202E', '\u2066', '\u2067', '\u2068', '\u2069'} {
		assert.Equal(t, "가\ufffd나", sanitizeTerminal("가"+string(r)+"나"), "U+%04X", r)
	}
	// 범위 바로 바깥 글자(U+061B, U+061D, U+200D, U+2070)와 보통 글자, 탭, 줄바꿈은 그대로입니다.
	assert.Equal(t, "\u061b\u061da\u200db\u2070c 한글\t\n", sanitizeTerminal("\u061b\u061da\u200db\u2070c 한글\t\n"))
}

// 출력 함수는 DB 없이 구조체로 만들어 확인합니다.

var opsAt = time.Date(2026, 11, 20, 3, 4, 5, 0, time.UTC)

func renderOps(t *testing.T, print func(w io.Writer) error) string {
	t.Helper()
	var out bytes.Buffer
	require.NoError(t, print(&out))
	return out.String()
}

func TestOps_JSONEmptyListsAreArrays(t *testing.T) {
	summary := ops.AccountSummary{
		Identities: []ops.IdentityInfo{}, Devices: []ops.DeviceInfo{}, Grants: []billing.GrantRow{}, Purchases: []ops.PurchaseInfo{},
	}
	out := renderOps(t, func(w io.Writer) error { return writeOpsJSON(w, summary) })
	for _, key := range []string{"identities", "devices", "grants", "purchases"} {
		assert.Contains(t, out, `"`+key+`": []`, out)
	}
	assert.Contains(t, out, `"adFree"`)
	assert.Contains(t, out, `"insight"`)

	out = renderOps(t, func(w io.Writer) error {
		return writeOpsJSON(w, ops.DiaryView{Entries: []ops.DiaryEntry{}, Tags: []string{}})
	})
	assert.Contains(t, out, `"entries": []`)
	assert.Contains(t, out, `"tags": []`)

	out = renderOps(t, func(w io.Writer) error { return writeOpsJSON(w, []ops.AuditRecord{}) })
	assert.Equal(t, "[]", strings.TrimSpace(out))
}

func TestOps_JSONKeysAreCamelCaseAndDatesAreStrings(t *testing.T) {
	revoked := opsAt.Add(time.Hour)
	result := ops.GrantResult{AuditID: uuid.New(), Grants: []billing.GrantRow{{
		ID: 7, Entitlement: billing.AdFree, Source: billing.SourceOperator, SourceRef: "grp-1", StartsAt: opsAt, ExpiresAt: opsAt.Add(24 * time.Hour), RevokedAt: &revoked,
	}}}
	out := renderOps(t, func(w io.Writer) error { return writeOpsJSON(w, result) })
	for _, want := range []string{`"auditId"`, `"sourceRef": "grp-1"`, `"expiresAt": "2026-11-21T03:04:05Z"`, `"startsAt"`, `"revokedAt"`, `"entitlement": "ad_free"`} {
		assert.Contains(t, out, want, out)
	}

	out = renderOps(t, func(w io.Writer) error {
		return writeOpsJSON(w, ops.ProfileView{BirthDate: &profile.LocalDate{Year: 1990, Month: 5, Day: 7}})
	})
	assert.Contains(t, out, `"birthDate": "1990-05-07"`)
}

func TestOps_TextStripsTerminalControlCharacters(t *testing.T) {
	body := "빨강\x1b[31m글자\u009b끝\n둘째 줄\t탭"
	view := ops.DiaryView{Entries: []ops.DiaryEntry{{ID: uuid.New(), Date: profile.LocalDate{Year: 2026, Month: 11, Day: 20}, Body: body, CreatedAt: opsAt, UpdatedAt: opsAt}}}

	out := renderOps(t, func(w io.Writer) error { return printDiaryView(w, view) })
	assert.NotContains(t, out, "\x1b")
	assert.NotContains(t, out, "\u009b")
	assert.Contains(t, out, "빨강�[31m글자�끝\n둘째 줄\t탭")

	// JSON은 이스케이프되어 그대로입니다.
	out = renderOps(t, func(w io.Writer) error { return writeOpsJSON(w, view) })
	assert.NotContains(t, out, "\x1b")
	assert.Contains(t, out, `\u001b[31m`)
}

func TestOps_TextStripsControlCharactersInProfileAndAudit(t *testing.T) {
	honorific := "수아\x1b[2J"
	out := renderOps(t, func(w io.Writer) error {
		return printProfileView(w, ops.ProfileView{Honorific: &honorific, Language: "ko"})
	})
	assert.NotContains(t, out, "\x1b")
	assert.Contains(t, out, "수아�[2J")

	out = renderOps(t, func(w io.Writer) error {
		return printAuditRecords(w, []ops.AuditRecord{{
			ID: uuid.New(), At: opsAt, Actor: "op@example.com", ActorSub: "sub\x1b[1", Channel: "ops_api", Action: "account_show",
			Reason: "색\x1b[31m사유", Target: json.RawMessage(`{}`),
		}})
	})
	assert.NotContains(t, out, "\x1b")
	assert.Contains(t, out, "색�[31m사유")
	assert.Contains(t, out, "sub�[1")
}

func TestOps_AuditRecordsShowActorSubAndTarget(t *testing.T) {
	account := uuid.New()
	record := ops.AuditRecord{
		ID: uuid.New(), At: opsAt, Actor: "op@example.com", ActorSub: "accounts.google.com:123", Channel: "ops_api", Action: "account_show",
		AccountID: &account, Reason: "문의", Target: json.RawMessage(`{"accountId": "` + account.String() + `"}`),
	}
	out := renderOps(t, func(w io.Writer) error { return printAuditRecords(w, []ops.AuditRecord{record}) })
	header, row, _ := strings.Cut(out, "\n")
	assert.Contains(t, header, "실행자 sub")
	assert.Less(t, strings.Index(header, "실행자 sub"), strings.Index(header, "경로"), "sub 열은 actor 옆입니다")
	assert.Contains(t, header, "대상")
	assert.Contains(t, row, "op@example.com")
	assert.Contains(t, row, "accounts.google.com:123")
	assert.Contains(t, row, `{"accountId": "`+account.String()+`"}`, "target JSON이 자르지 않고 한 칸에 나옵니다")

	out = renderOps(t, func(w io.Writer) error { return writeOpsJSON(w, []ops.AuditRecord{record}) })
	assert.Contains(t, out, `"actor": "op@example.com"`)
	assert.Contains(t, out, `"actorSub": "accounts.google.com:123"`)
}

func TestOps_GrantAndRevokeTextEndWithAuditLine(t *testing.T) {
	auditID := uuid.New()
	rows := []billing.GrantRow{{ID: 1, Entitlement: billing.AdFree, Source: billing.SourceOperator, StartsAt: opsAt, ExpiresAt: opsAt.Add(time.Hour)}}
	out := renderOps(t, func(w io.Writer) error { return printGrantResult(w, ops.GrantResult{AuditID: auditID, Grants: rows}) })
	assert.True(t, strings.HasSuffix(out, "감사 기록 "+auditID.String()+"\n"), out)

	out = renderOps(t, func(w io.Writer) error {
		return printRevokeResult(w, ops.RevokeResult{AuditID: auditID, Before: rows, After: rows})
	})
	assert.Contains(t, out, "[회수 전]")
	assert.Contains(t, out, "[회수 뒤]")
	assert.True(t, strings.HasSuffix(out, "감사 기록 "+auditID.String()+"\n"), out)
}

func TestOps_AccountSummaryTextShowsSections(t *testing.T) {
	out := renderOps(t, func(w io.Writer) error {
		return printAccountSummary(w, ops.AccountSummary{Account: ops.AccountInfo{ID: uuid.New(), Status: "active", CreatedAt: opsAt, LastActiveAt: opsAt}})
	})
	for _, section := range []string{"[계정]", "[로그인 수단]", "[기기]", "[권한 상태]", "[권한 행]", "[구매]"} {
		assert.Contains(t, out, section)
	}
}

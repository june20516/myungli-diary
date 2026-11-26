package ops

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

func seedAudit(t *testing.T, svc *Service, accountID uuid.UUID, at time.Time, reason string) {
	t.Helper()
	// trigger가 at을 덮어쓰므로 끄고 넣습니다.
	dbtest.ExecWithoutTriggers(t, svc.pool, `INSERT INTO ops_audit (id, at, actor, actor_sub, channel, action, account_id, reason, target)
		VALUES (gen_random_uuid(), $1, 'seed', 'seed-sub', 'ops_api', 'account_show', $2, $3, '{}')`, at, accountID, reason)
}

func TestAuditList_FiltersAndAuditsItself(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()
	a, b := uuid.New(), uuid.New()
	seedAudit(t, svc, a, testNow.Add(-3*time.Hour), "첫째")
	seedAudit(t, svc, a, testNow.Add(-2*time.Hour), "둘째")
	seedAudit(t, svc, b, testNow.Add(-time.Hour), "셋째")

	got, err := svc.AuditList(ctx, testActor, AuditFilter{AccountID: &a}, "점검")
	require.NoError(t, err)
	require.Len(t, got, 2)
	assert.Equal(t, "둘째", got[0].Reason, "최근 기록이 먼저")
	assert.Equal(t, "첫째", got[1].Reason)
	assert.Equal(t, "seed", got[0].Actor)
	assert.Equal(t, "seed-sub", got[0].ActorSub)
	assert.JSONEq(t, `{}`, string(got[0].Target))

	rows := auditRows(t, pool)
	require.Len(t, rows, 4)
	last := rows[3]
	assert.Equal(t, "audit_list", last.Action)
	assert.Equal(t, "점검", last.Reason)
	require.NotNil(t, last.AccountID)
	assert.Equal(t, a, *last.AccountID)
	assert.Contains(t, last.Target, a.String())
	for _, record := range got {
		assert.NotEqual(t, "audit_list", record.Action, "이번 조회의 감사 행은 결과에 들어가지 않습니다")
	}
}

func TestAuditList_SinceAndAccountCombineWithAnd(t *testing.T) {
	svc, _ := newTestService(t)
	a, b := uuid.New(), uuid.New()
	seedAudit(t, svc, a, testNow.Add(-5*time.Hour), "오래된 a")
	seedAudit(t, svc, a, testNow.Add(-time.Hour), "최근 a")
	seedAudit(t, svc, b, testNow.Add(-time.Hour), "최근 b")
	since := testNow.Add(-2 * time.Hour)

	got, err := svc.AuditList(context.Background(), testActor, AuditFilter{AccountID: &a, Since: &since}, "점검")
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.Equal(t, "최근 a", got[0].Reason)
}

func TestAuditList_DefaultLimitIs100(t *testing.T) {
	svc, _ := newTestService(t)
	a := uuid.New()
	for range 101 {
		seedAudit(t, svc, a, testNow.Add(-time.Hour), "행")
	}

	got, err := svc.AuditList(context.Background(), testActor, AuditFilter{AccountID: &a}, "점검")
	require.NoError(t, err)
	assert.Len(t, got, 100)
}

func TestAuditList_SinceAndLimit(t *testing.T) {
	svc, _ := newTestService(t)
	ctx := context.Background()
	a := uuid.New()
	for i := range 5 {
		seedAudit(t, svc, a, testNow.Add(-time.Duration(5-i)*time.Hour), "행")
	}
	since := testNow.Add(-3 * time.Hour)

	got, err := svc.AuditList(ctx, testActor, AuditFilter{Since: &since}, "점검")
	require.NoError(t, err)
	assert.Len(t, got, 3)

	got, err = svc.AuditList(ctx, testActor, AuditFilter{Since: &since, Limit: 2}, "점검")
	require.NoError(t, err)
	assert.Len(t, got, 2)
}

func TestAuditList_RequiresFilter(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()

	_, err := svc.AuditList(ctx, testActor, AuditFilter{}, "점검")
	assert.ErrorIs(t, err, ErrAuditFilter)
	a := uuid.New()
	_, err = svc.AuditList(ctx, testActor, AuditFilter{AccountID: &a, Limit: 1001}, "점검")
	assert.ErrorIs(t, err, ErrAuditFilter)
	_, err = svc.AuditList(ctx, testActor, AuditFilter{AccountID: &a, Limit: -1}, "점검")
	assert.ErrorIs(t, err, ErrAuditFilter)
	_, err = svc.AuditList(ctx, testActor, AuditFilter{AccountID: &a}, "")
	assert.ErrorIs(t, err, ErrReason)
	assert.Empty(t, auditRows(t, pool))
}

// TestService_EmptyResultsAreJSONArrays는 빈 목록이 JSON null이 아니라 []로 나가는지 확인합니다.
func TestService_EmptyResultsAreJSONArrays(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()
	id := insertAccount(t, pool)

	summary, err := svc.AccountSummary(ctx, testActor, AccountKey{AccountID: id}, "문의")
	require.NoError(t, err)
	raw, err := json.Marshal(summary)
	require.NoError(t, err)
	for _, key := range []string{"identities", "devices", "grants", "purchases"} {
		assert.Contains(t, string(raw), `"`+key+`":[]`)
	}

	diary, err := svc.ViewDiary(ctx, testActor, byDate(id, viewDate))
	require.NoError(t, err)
	raw, err = json.Marshal(diary)
	require.NoError(t, err)
	assert.Contains(t, string(raw), `"entries":[]`)
	assert.Contains(t, string(raw), `"tags":[]`)

	since := time.Date(2999, 1, 1, 0, 0, 0, 0, time.UTC)
	records, err := svc.AuditList(ctx, testActor, AuditFilter{Since: &since}, "점검")
	require.NoError(t, err)
	raw, err = json.Marshal(records)
	require.NoError(t, err)
	assert.Equal(t, "[]", string(raw))
}

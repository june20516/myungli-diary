package ops

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func seedAudit(t *testing.T, svc *Service, accountID uuid.UUID, at time.Time, reason string) {
	t.Helper()
	_, err := svc.pool.Exec(context.Background(), `INSERT INTO ops_audit (id, at, actor, channel, action, account_id, reason, target)
		VALUES (gen_random_uuid(), $1, 'seed', 'cli', 'account_show', $2, $3, '{}')`, at, accountID, reason)
	require.NoError(t, err)
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
	assert.JSONEq(t, `{}`, string(got[0].Target))

	rows := auditRows(t, pool)
	require.Len(t, rows, 4)
	last := rows[3]
	assert.Equal(t, "audit_list", last.Action)
	assert.Equal(t, "점검", last.Reason)
	require.NotNil(t, last.AccountID)
	assert.Equal(t, a, *last.AccountID)
	assert.Contains(t, last.Target, a.String())
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

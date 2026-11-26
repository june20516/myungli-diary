package ops

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

func grantCount(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT count(*) FROM entitlement_grants WHERE account_id = $1`, accountID).Scan(&n))
	return n
}

func TestGrant_SourceRefIsAuditID(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	expires := testNow.Add(30 * 24 * time.Hour)

	res, err := svc.Grant(context.Background(), testActor, GrantRequest{AccountID: id, Kind: billing.OperatorAdFree, ExpiresAt: expires, Reason: "보상"})
	require.NoError(t, err)
	require.Len(t, res.Grants, 2)
	for _, g := range res.Grants {
		assert.Equal(t, res.AuditID.String(), g.SourceRef)
		assert.Equal(t, billing.SourceOperator, g.Source)
	}

	var (
		gotID         uuid.UUID
		target, after string
		beforeNull    bool
		accountID     uuid.UUID
		action        string
	)
	require.NoError(t, pool.QueryRow(context.Background(),
		`SELECT id, action, account_id, target::text, before IS NULL, after::text FROM ops_audit`).Scan(&gotID, &action, &accountID, &target, &beforeNull, &after))
	assert.Equal(t, res.AuditID, gotID)
	assert.Equal(t, "grant", action)
	assert.Equal(t, id, accountID)
	assert.JSONEq(t, `{"kind":"ad_free","expiresAt":"2026-12-26T03:00:00Z"}`, target)
	assert.True(t, beforeNull)
	var rows []billing.GrantRow
	require.NoError(t, json.Unmarshal([]byte(after), &rows))
	assert.Len(t, rows, 2)
}

func TestGrant_PeriodBounds(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	ctx := context.Background()
	limit := testNow.Add(366 * 24 * time.Hour)

	for name, expires := range map[string]time.Time{
		"지금과 같음":     testNow,
		"지금 1초 전":    testNow.Add(-time.Second),
		"366일 1초 초과": limit.Add(time.Second),
	} {
		_, err := svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: billing.OperatorInsight, ExpiresAt: expires, Reason: "r"})
		assert.ErrorIs(t, err, ErrGrantPeriod, name)
	}
	assert.Empty(t, auditRows(t, pool))
	assert.Zero(t, grantCount(t, pool, id))

	_, err := svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: billing.OperatorInsight, ExpiresAt: limit, Reason: "r"})
	require.NoError(t, err)
}

func TestGrant_RejectsUnknownKindAndBadInput(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	ctx := context.Background()
	expires := testNow.Add(time.Hour)

	_, err := svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: "pass", ExpiresAt: expires, Reason: "r"})
	assert.ErrorIs(t, err, ErrGrantKind)
	_, err = svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: billing.OperatorAdFree, ExpiresAt: expires, Reason: " "})
	assert.ErrorIs(t, err, ErrReason)
	_, err = svc.Grant(ctx, Actor{}, GrantRequest{AccountID: id, Kind: billing.OperatorAdFree, ExpiresAt: expires, Reason: "r"})
	assert.ErrorIs(t, err, ErrActor)
	assert.Empty(t, auditRows(t, pool))
}

func TestGrant_InactiveAccountRejectedNoAudit(t *testing.T) {
	svc, pool := newTestService(t)
	_, err := svc.Grant(context.Background(), testActor, GrantRequest{AccountID: uuid.New(), Kind: billing.OperatorAdFree, ExpiresAt: testNow.Add(time.Hour), Reason: "r"})
	assert.ErrorIs(t, err, billing.ErrAccountNotActive)
	assert.Empty(t, auditRows(t, pool))
}

func TestRevoke_AdFreeBundleRevokesBoth(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	ctx := context.Background()
	granted, err := svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: billing.OperatorAdFree, ExpiresAt: testNow.Add(time.Hour), Reason: "r"})
	require.NoError(t, err)

	res, err := svc.Revoke(ctx, testActor, RevokeRequest{AccountID: id, GrantID: granted.Grants[0].ID, Reason: "철회"})
	require.NoError(t, err)
	require.Len(t, res.Before, 2)
	require.Len(t, res.After, 2)
	for i := range res.After {
		assert.Nil(t, res.Before[i].RevokedAt)
		require.NotNil(t, res.After[i].RevokedAt)
		assert.True(t, res.After[i].RevokedAt.Equal(testNow))
	}

	var action, target string
	var beforeJSON, afterJSON []byte
	require.NoError(t, pool.QueryRow(ctx, `SELECT action, target::text, before, after FROM ops_audit WHERE id = $1`, res.AuditID).Scan(&action, &target, &beforeJSON, &afterJSON))
	assert.Equal(t, "revoke", action)
	assert.JSONEq(t, `{"grantId":`+jsonInt(granted.Grants[0].ID)+`}`, target)
	assert.NotEmpty(t, beforeJSON)
	assert.NotEmpty(t, afterJSON)
}

func jsonInt(n int64) string {
	b, _ := json.Marshal(n)
	return string(b)
}

func TestRevoke_PassGrantRejectedNoAudit(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	ctx := context.Background()
	var grantID int64
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'ad_free_pass', 'pass-1', $2, $3) RETURNING id`, id, testNow.Add(-time.Hour), testNow.Add(time.Hour)).Scan(&grantID))

	_, err := svc.Revoke(ctx, testActor, RevokeRequest{AccountID: id, GrantID: grantID, Reason: "r"})
	assert.ErrorIs(t, err, billing.ErrGrantNotRevocable)
	assert.Empty(t, auditRows(t, pool))
}

func TestRevoke_NotFoundAndAlreadyEnded(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	ctx := context.Background()

	_, err := svc.Revoke(ctx, testActor, RevokeRequest{AccountID: id, GrantID: 0, Reason: "r"})
	assert.ErrorIs(t, err, billing.ErrGrantNotFound)
	_, err = svc.Revoke(ctx, testActor, RevokeRequest{AccountID: id, GrantID: 999999, Reason: "r"})
	assert.ErrorIs(t, err, billing.ErrGrantNotFound)

	granted, err := svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: billing.OperatorInsight, ExpiresAt: testNow.Add(time.Hour), Reason: "r"})
	require.NoError(t, err)
	_, err = svc.Revoke(ctx, testActor, RevokeRequest{AccountID: id, GrantID: granted.Grants[0].ID, Reason: "r"})
	require.NoError(t, err)
	_, err = svc.Revoke(ctx, testActor, RevokeRequest{AccountID: id, GrantID: granted.Grants[0].ID, Reason: "r"})
	assert.ErrorIs(t, err, billing.ErrGrantAlreadyEnded)
	assert.Len(t, auditRows(t, pool), 2, "부여와 첫 회수만 남습니다")
}

func TestGrant_AuditFailureRollsBackGrant(t *testing.T) {
	dbtest.LockCluster(t)
	_, pool := newTestService(t)
	id := insertAccount(t, pool)
	svc := newNoAuditService(t, pool)

	res, err := svc.Grant(context.Background(), testActor, GrantRequest{AccountID: id, Kind: billing.OperatorAdFree, ExpiresAt: testNow.Add(time.Hour), Reason: "r"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "permission denied")
	assert.Equal(t, GrantResult{}, res)
	assert.Zero(t, grantCount(t, pool, id))
	assert.Empty(t, auditRows(t, pool))
}

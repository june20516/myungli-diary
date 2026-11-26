package ops

import (
	"context"
	"encoding/json"
	"strconv"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
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
	var rows []map[string]any
	require.NoError(t, json.Unmarshal([]byte(after), &rows))
	require.Len(t, rows, 2)
	for i, row := range rows {
		assert.ElementsMatch(t, []string{"id", "entitlement", "source", "sourceRef", "startsAt", "expiresAt", "revokedAt"}, mapKeys(row))
		assert.Equal(t, res.AuditID.String(), row["sourceRef"])
		assert.Equal(t, "operator", row["source"])
		assert.Equal(t, string(res.Grants[i].Entitlement), row["entitlement"])
		assert.Equal(t, "2026-12-26T03:00:00Z", row["expiresAt"])
		assert.Equal(t, "2026-11-26T03:00:00Z", row["startsAt"])
		assert.Nil(t, row["revokedAt"])
	}
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
	assert.JSONEq(t, `{"grantId":`+strconv.FormatInt(granted.Grants[0].ID, 10)+`}`, target)
	var beforeRows, afterRows []map[string]any
	require.NoError(t, json.Unmarshal(beforeJSON, &beforeRows))
	require.NoError(t, json.Unmarshal(afterJSON, &afterRows))
	require.Len(t, beforeRows, 2)
	require.Len(t, afterRows, 2)
	for i := range afterRows {
		assert.Contains(t, beforeRows[i], "revokedAt")
		assert.Nil(t, beforeRows[i]["revokedAt"])
		assert.Equal(t, "2026-11-26T03:00:00Z", afterRows[i]["revokedAt"])
		assert.Equal(t, granted.Grants[i].SourceRef, afterRows[i]["sourceRef"])
		assert.EqualValues(t, granted.Grants[i].ID, afterRows[i]["id"])
	}
}

func mapKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
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
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr)
	assert.Equal(t, "42501", pgErr.Code)
	assert.Contains(t, pgErr.Message, "ops_audit", "권한 행 INSERT 뒤 감사 INSERT가 실패해야 합니다")
	assert.Equal(t, GrantResult{}, res)
	assert.Zero(t, grantCount(t, pool, id))
	assert.Empty(t, auditRows(t, pool))
}

// 일수로 준 만료는 Service 시각 기준이고, 만료 시각과 일수 중 정확히 하나만 받습니다.
func TestGrant_DaysCountFromServiceNow(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	ctx := context.Background()

	for name, req := range map[string]GrantRequest{
		"둘 다 없음": {},
		"둘 다 있음": {ExpiresAt: testNow.Add(time.Hour), Days: 1},
		"일수 367": {Days: 367},
		"일수 음수":  {Days: -1},
	} {
		req.AccountID, req.Kind, req.Reason = id, billing.OperatorInsight, "r"
		_, err := svc.Grant(ctx, testActor, req)
		assert.ErrorIs(t, err, ErrGrantPeriod, name)
	}
	assert.Empty(t, auditRows(t, pool))

	res, err := svc.Grant(ctx, testActor, GrantRequest{AccountID: id, Kind: billing.OperatorInsight, Days: 366, Reason: "r"})
	require.NoError(t, err)
	require.Len(t, res.Grants, 1)
	assert.Equal(t, testNow, res.Grants[0].StartsAt)
	assert.Equal(t, testNow.Add(366*24*time.Hour), res.Grants[0].ExpiresAt)
}

// 기본 Service는 DB 시각을 씁니다. 부여 시작과 감사 행 at이 같은 트랜잭션의 now()입니다.
func TestGrant_DefaultNowIsDBTransactionTime(t *testing.T) {
	pool := dbtest.New(t)
	svc := NewService(pool)
	id := insertAccount(t, pool)

	res, err := svc.Grant(context.Background(), testActor, GrantRequest{AccountID: id, Kind: billing.OperatorInsight, Days: 1, Reason: "r"})
	require.NoError(t, err)
	var at time.Time
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT at FROM ops_audit WHERE id = $1`, res.AuditID).Scan(&at))
	require.Len(t, res.Grants, 1)
	assert.True(t, at.Equal(res.Grants[0].StartsAt), "at = %v, startsAt = %v", at, res.Grants[0].StartsAt)
	assert.Equal(t, res.Grants[0].StartsAt.Add(24*time.Hour), res.Grants[0].ExpiresAt)
}

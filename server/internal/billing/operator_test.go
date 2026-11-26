package billing_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

func grantOperator(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, kind billing.OperatorKind) ([]billing.GrantRow, error) {
	t.Helper()
	var rows []billing.GrantRow
	err := postgres.InTx(context.Background(), pool, func(tx pgx.Tx) error {
		var err error
		rows, err = billing.GrantOperatorTx(context.Background(), tx, accountID, kind, "ref-1", now, now.Add(30*24*time.Hour))
		return err
	})
	return rows, err
}

func revokeGroup(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, grantID int64) (before, after []billing.GrantRow, err error) {
	t.Helper()
	err = postgres.InTx(context.Background(), pool, func(tx pgx.Tx) error {
		var err error
		before, after, err = billing.RevokeGroupTx(context.Background(), tx, accountID, grantID, now)
		return err
	})
	return before, after, err
}

func listGrants(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID) []billing.GrantRow {
	t.Helper()
	rows, err := billing.ListGrantsTx(context.Background(), pool, accountID)
	require.NoError(t, err)
	return rows
}

func grantIDOf(t *testing.T, rows []billing.GrantRow, entitlement billing.Entitlement) int64 {
	t.Helper()
	for _, r := range rows {
		if r.Entitlement == entitlement {
			return r.ID
		}
	}
	require.FailNow(t, "해당 권한 행이 없음", string(entitlement))
	return 0
}

func TestGrantOperator_AdFreeGivesBothRows(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)

	rows, err := grantOperator(t, pool, accountID, billing.OperatorAdFree)
	require.NoError(t, err)

	require.Len(t, rows, 2)
	for _, r := range rows {
		assert.Equal(t, billing.SourceOperator, r.Source)
		assert.Equal(t, "ref-1", r.SourceRef)
		assert.Nil(t, r.RevokedAt)
	}
	assert.ElementsMatch(t, []billing.Entitlement{billing.AdFree, billing.Insight}, []billing.Entitlement{rows[0].Entitlement, rows[1].Entitlement})

	status, err := billing.NewStore(pool, clocktest.New(now), nil).Status(context.Background(), accountID)
	require.NoError(t, err)
	assert.True(t, status.AdFree.Active)
	assert.True(t, status.Insight.Active)
	assert.Equal(t, billing.SourceOperator, status.Insight.Source)
}

func TestGrantOperator_InsightOnly(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)

	rows, err := grantOperator(t, pool, accountID, billing.OperatorInsight)
	require.NoError(t, err)

	require.Len(t, rows, 1)
	assert.Equal(t, billing.Insight, rows[0].Entitlement)
	status, err := billing.NewStore(pool, clocktest.New(now), nil).Status(context.Background(), accountID)
	require.NoError(t, err)
	assert.False(t, status.AdFree.Active)
	assert.True(t, status.Insight.Active)
}

func TestGrantOperator_MissingAccount(t *testing.T) {
	pool := dbtest.New(t)
	accountID := uuid.New()

	_, err := grantOperator(t, pool, accountID, billing.OperatorAdFree)

	require.ErrorIs(t, err, billing.ErrAccountMissing)
	assert.NotErrorIs(t, err, billing.ErrAccountNotActive)
}

func TestGrantOperator_RejectsInactiveAccount(t *testing.T) {
	pool := dbtest.New(t)
	var accountID uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		`INSERT INTO accounts (id, status, last_active_at, deleted_at)
		 VALUES (gen_random_uuid(), 'deleted', now(), now()) RETURNING id`).Scan(&accountID))

	_, err := grantOperator(t, pool, accountID, billing.OperatorAdFree)

	require.ErrorIs(t, err, billing.ErrAccountNotActive)
	assert.Empty(t, listGrants(t, pool, accountID))
}

func TestRevokeGroup_OperatorBundleRevokesBoth(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	granted, err := grantOperator(t, pool, accountID, billing.OperatorAdFree)
	require.NoError(t, err)

	before, after, err := revokeGroup(t, pool, accountID, grantIDOf(t, granted, billing.Insight))
	require.NoError(t, err)

	require.Len(t, before, 2)
	require.Len(t, after, 2)
	for _, r := range before {
		assert.Nil(t, r.RevokedAt)
	}
	for _, r := range after {
		require.NotNil(t, r.RevokedAt)
		assert.True(t, now.Equal(*r.RevokedAt))
	}
	for _, r := range listGrants(t, pool, accountID) {
		assert.NotNil(t, r.RevokedAt)
	}
}

func TestRevokeGroup_RewardedAdSingleRow(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceRewardedAd, "tx-1", now.Add(-time.Hour), now.Add(time.Hour)))
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceRewardedAd, "tx-2", now.Add(-time.Hour), now.Add(2*time.Hour)))
	rows := listGrants(t, pool, accountID)
	target := grantIDOf(t, rows, billing.AdFree)

	before, after, err := revokeGroup(t, pool, accountID, target)
	require.NoError(t, err)

	require.Len(t, before, 1)
	require.Len(t, after, 1)
	assert.Equal(t, target, after[0].ID)
	assert.NotNil(t, after[0].RevokedAt)
	revoked := 0
	for _, r := range listGrants(t, pool, accountID) {
		if r.RevokedAt != nil {
			revoked++
		}
	}
	assert.Equal(t, 1, revoked)
}

func TestRevokeGroup_RejectsPassGrant(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceAdFreePass, "p-1", now.Add(-time.Hour), now.Add(time.Hour)))
	id := listGrants(t, pool, accountID)[0].ID

	_, _, err := revokeGroup(t, pool, accountID, id)

	require.ErrorIs(t, err, billing.ErrGrantNotRevocable)
	assert.Nil(t, listGrants(t, pool, accountID)[0].RevokedAt)
}

func TestRevokeGroup_OtherAccountGrantNotFound(t *testing.T) {
	pool := dbtest.New(t)
	owner, other := newAccount(t, pool), newAccount(t, pool)
	granted, err := grantOperator(t, pool, owner, billing.OperatorInsight)
	require.NoError(t, err)

	_, _, err = revokeGroup(t, pool, other, granted[0].ID)

	require.ErrorIs(t, err, billing.ErrGrantNotFound)
	assert.Nil(t, listGrants(t, pool, owner)[0].RevokedAt)
}

func TestRevokeGroup_AlreadyEnded(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	granted, err := grantOperator(t, pool, accountID, billing.OperatorAdFree)
	require.NoError(t, err)
	id := granted[0].ID
	_, _, err = revokeGroup(t, pool, accountID, id)
	require.NoError(t, err)

	_, _, err = revokeGroup(t, pool, accountID, id)
	require.ErrorIs(t, err, billing.ErrGrantAlreadyEnded)

	// 만료된 행도 이미 끝난 것입니다.
	expired := newAccount(t, pool)
	insertGrant(t, pool, expired, grant(billing.AdFree, billing.SourceRewardedAd, "old", now.Add(-2*time.Hour), now.Add(-time.Hour)))
	_, _, err = revokeGroup(t, pool, expired, listGrants(t, pool, expired)[0].ID)
	require.ErrorIs(t, err, billing.ErrGrantAlreadyEnded)
}

func TestListGrants_AllRowsNewestStartFirst(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceRewardedAd, "a", now.Add(-3*time.Hour), now.Add(-2*time.Hour)))
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceRewardedAd, "b", now.Add(-time.Hour), now.Add(time.Hour)))

	rows := listGrants(t, pool, accountID)

	require.Len(t, rows, 2)
	assert.Equal(t, "b", rows[0].SourceRef)
	assert.Equal(t, "a", rows[1].SourceRef)
}

// 묶음 일부만 끝났으면 활성 행만 취소하고, 이미 끝난 행은 그대로 둡니다.
func TestRevokeGroup_PartiallyEndedBundleRevokesOnlyLive(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	granted, err := grantOperator(t, pool, accountID, billing.OperatorAdFree)
	require.NoError(t, err)
	earlier := now.Add(-time.Hour)
	_, err = pool.Exec(context.Background(),
		"UPDATE entitlement_grants SET revoked_at = $1 WHERE id = $2", earlier, grantIDOf(t, granted, billing.Insight))
	require.NoError(t, err)

	before, after, err := revokeGroup(t, pool, accountID, grantIDOf(t, granted, billing.AdFree))
	require.NoError(t, err)

	require.Len(t, before, 2)
	require.Len(t, after, 2)
	for _, r := range before {
		if r.Entitlement == billing.Insight {
			require.NotNil(t, r.RevokedAt)
		} else {
			assert.Nil(t, r.RevokedAt)
		}
	}
	for _, r := range after {
		require.NotNil(t, r.RevokedAt)
		if r.Entitlement == billing.Insight {
			assert.True(t, earlier.Equal(*r.RevokedAt), "이미 취소된 행의 시각은 그대로")
		} else {
			assert.True(t, now.Equal(*r.RevokedAt))
		}
	}
}

// 만료된 운영자 묶음은 이미 끝난 것입니다.
func TestRevokeGroup_ExpiredOperatorBundleAlreadyEnded(t *testing.T) {
	pool := dbtest.New(t)
	accountID := newAccount(t, pool)
	var rows []billing.GrantRow
	err := postgres.InTx(context.Background(), pool, func(tx pgx.Tx) error {
		var err error
		rows, err = billing.GrantOperatorTx(context.Background(), tx, accountID, billing.OperatorAdFree, "old",
			now.Add(-48*time.Hour), now.Add(-24*time.Hour))
		return err
	})
	require.NoError(t, err)

	_, _, err = revokeGroup(t, pool, accountID, rows[0].ID)

	require.ErrorIs(t, err, billing.ErrGrantAlreadyEnded)
}

// 같은 source_ref 문자열의 operator 행이 다른 계정에 있어도 회수는 그 계정 행을 건드리지 않습니다.
// 유일 제약 (entitlement, source, source_ref) 때문에 owner에는 insight 한 행, 다른 계정에는 ad_free 행을 둡니다.
// 묶음 조회나 회수 쿼리에서 account_id 조건이 빠지면 before/after에 다른 계정 행이 섞여 실패합니다.
func TestRevokeGroup_SameSourceRefOtherAccountUntouched(t *testing.T) {
	pool := dbtest.New(t)
	owner, other := newAccount(t, pool), newAccount(t, pool)
	ownerRows, err := grantOperator(t, pool, owner, billing.OperatorInsight)
	require.NoError(t, err)
	require.Len(t, ownerRows, 1)
	require.Equal(t, "ref-1", ownerRows[0].SourceRef)
	insertGrant(t, pool, other, grant(billing.AdFree, billing.SourceOperator, "ref-1", now, now.Add(time.Hour)))

	before, after, err := revokeGroup(t, pool, owner, ownerRows[0].ID)
	require.NoError(t, err)

	require.Len(t, before, 1)
	require.Len(t, after, 1)
	assert.Equal(t, ownerRows[0].ID, before[0].ID)
	assert.Equal(t, ownerRows[0].ID, after[0].ID)
	assert.Equal(t, "ref-1", after[0].SourceRef)
	otherRows := listGrants(t, pool, other)
	require.Len(t, otherRows, 1)
	assert.Equal(t, "ref-1", otherRows[0].SourceRef)
	assert.Nil(t, otherRows[0].RevokedAt)
}

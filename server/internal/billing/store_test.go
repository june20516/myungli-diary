package billing_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// Store가 fortune.Insight를 만족하는지 컴파일 시점에 확인합니다.
var _ fortune.Insight = (*billing.Store)(nil)

var now = time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC)

func newAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
	return id
}

type grantRow struct {
	grant     billing.Grant
	revokedAt *time.Time
}

func insertGrant(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, row grantRow) {
	t.Helper()
	g := row.grant
	_, err := pool.Exec(context.Background(),
		`INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at, revoked_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		accountID, string(g.Entitlement), string(g.Source), g.SourceRef, g.StartsAt, g.ExpiresAt, row.revokedAt)
	require.NoError(t, err)
}

func grant(entitlement billing.Entitlement, source billing.Source, ref string, starts, expires time.Time) grantRow {
	return grantRow{grant: billing.Grant{Entitlement: entitlement, Source: source, SourceRef: ref, StartsAt: starts, ExpiresAt: expires}}
}

func newStore(t *testing.T) (*billing.Store, *pgxpool.Pool) {
	t.Helper()
	pool := dbtest.New(t)
	return billing.NewStore(pool, clocktest.New(now), nil), pool
}

func TestStore_Status_NoRows_BothInactive(t *testing.T) {
	store, pool := newStore(t)

	status, err := store.Status(context.Background(), newAccount(t, pool))

	require.NoError(t, err)
	assert.Equal(t, billing.Status{}, status)
	assert.Nil(t, status.AdFree.ExpiresAt)
	assert.Nil(t, status.Insight.ExpiresAt)
}

func TestStore_Status_ValidAdFree_ActiveWithExpiry(t *testing.T) {
	store, pool := newStore(t)
	accountID := newAccount(t, pool)
	expires := now.AddDate(0, 0, 10)
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceAdFreePass, "p1", now.AddDate(0, 0, -5), expires))

	status, err := store.Status(context.Background(), accountID)

	require.NoError(t, err)
	assert.True(t, status.AdFree.Active)
	require.NotNil(t, status.AdFree.ExpiresAt)
	assert.True(t, status.AdFree.ExpiresAt.Equal(expires))
	assert.Equal(t, billing.SourceAdFreePass, status.AdFree.Source)
	assert.False(t, status.Insight.Active, "insight 행이 없으면 광고 제거권과 따로 inactive")
}

func TestStore_Status_RevokedOrFuture_Inactive(t *testing.T) {
	store, pool := newStore(t)
	accountID := newAccount(t, pool)
	revoked := grant(billing.AdFree, billing.SourceAdFreePass, "refunded", now.AddDate(0, 0, -5), now.AddDate(0, 0, 10))
	revokedAt := now.AddDate(0, 0, -1)
	revoked.revokedAt = &revokedAt
	insertGrant(t, pool, accountID, revoked)
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceAdFreePass, "future", now.Add(time.Hour), now.AddDate(0, 1, 0)))
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceAdFreePass, "expired", now.AddDate(0, -2, 0), now.Add(-time.Hour)))

	status, err := store.Status(context.Background(), accountID)

	require.NoError(t, err)
	assert.Equal(t, billing.State{}, status.AdFree)
}

func TestStore_Status_ChainedGrants_ExpiryIsLastOfChain(t *testing.T) {
	store, pool := newStore(t)
	accountID := newAccount(t, pool)
	current := now.AddDate(0, 0, 5)
	next := now.AddDate(0, 1, 5)
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceAdFreePass, "p1", now.AddDate(0, 0, -25), current))
	insertGrant(t, pool, accountID, grant(billing.AdFree, billing.SourceAdFreePass, "p2", current, next))

	status, err := store.Status(context.Background(), accountID)

	require.NoError(t, err)
	assert.True(t, status.AdFree.Active)
	require.NotNil(t, status.AdFree.ExpiresAt)
	assert.True(t, status.AdFree.ExpiresAt.Equal(next), "이어 붙인 뒤 행의 만료")
}

func TestStore_Status_OverlappingInsight_LatestExpirySourceWins(t *testing.T) {
	store, pool := newStore(t)
	accountID := newAccount(t, pool)
	midnight := time.Date(2026, 10, 21, 0, 0, 0, 0, time.UTC)
	nextMonth := now.AddDate(0, 1, 0)
	insertGrant(t, pool, accountID, grant(billing.Insight, billing.SourceRewardedAd, "tx1", now.Add(-time.Hour), midnight))
	insertGrant(t, pool, accountID, grant(billing.Insight, billing.SourceAdFreePass, "p1", now.AddDate(0, 0, -1), nextMonth))

	status, err := store.Status(context.Background(), accountID)

	require.NoError(t, err)
	assert.True(t, status.Insight.Active)
	assert.Equal(t, billing.SourceAdFreePass, status.Insight.Source)
	require.NotNil(t, status.Insight.ExpiresAt)
	assert.True(t, status.Insight.ExpiresAt.Equal(nextMonth))
}

func TestStore_Status_OtherAccountRows_NotMixed(t *testing.T) {
	store, pool := newStore(t)
	mine := newAccount(t, pool)
	other := newAccount(t, pool)
	insertGrant(t, pool, other, grant(billing.AdFree, billing.SourceAdFreePass, "p1", now.AddDate(0, 0, -1), now.AddDate(0, 1, 0)))
	insertGrant(t, pool, other, grant(billing.Insight, billing.SourceAdFreePass, "p1", now.AddDate(0, 0, -1), now.AddDate(0, 1, 0)))

	status, err := store.Status(context.Background(), mine)

	require.NoError(t, err)
	assert.Equal(t, billing.Status{}, status)
}

func TestStore_Unlocked_MatchesInsightActive(t *testing.T) {
	store, pool := newStore(t)
	accountID := newAccount(t, pool)

	unlocked, err := store.Unlocked(context.Background(), accountID)
	require.NoError(t, err)
	assert.False(t, unlocked)

	insertGrant(t, pool, accountID, grant(billing.Insight, billing.SourceRewardedAd, "tx1", now.Add(-time.Hour), now.Add(time.Hour)))

	unlocked, err = store.Unlocked(context.Background(), accountID)
	require.NoError(t, err)
	assert.True(t, unlocked)
}

func TestStore_Status_SameExpiry_LaterRowSourceWins(t *testing.T) {
	store, pool := newStore(t)
	accountID := newAccount(t, pool)
	expires := now.AddDate(0, 0, 3)
	insertGrant(t, pool, accountID, grant(billing.Insight, billing.SourceRewardedAd, "tx1", now.Add(-time.Hour), expires))
	insertGrant(t, pool, accountID, grant(billing.Insight, billing.SourceAdFreePass, "p1", now.Add(-time.Hour), expires))

	status, err := store.Status(context.Background(), accountID)

	require.NoError(t, err)
	assert.Equal(t, billing.SourceAdFreePass, status.Insight.Source, "만료가 같으면 나중에 만든 행")
}

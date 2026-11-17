package billing_test

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

type rewardFixture struct {
	pool    *pgxpool.Pool
	rewards *billing.Rewards
	store   *billing.Store
	logs    *bytes.Buffer
}

func newRewardFixture(t *testing.T) rewardFixture {
	t.Helper()
	pool := dbtest.New(t)
	logs := &bytes.Buffer{}
	clk := clocktest.New(now)
	return rewardFixture{
		pool:    pool,
		rewards: billing.NewRewards(pool, clk, logging.New(logs, slog.LevelDebug, "")),
		store:   billing.NewStore(pool, clk, nil),
		logs:    logs,
	}
}

func insertProfile(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, timezone string) {
	t.Helper()
	_, err := pool.Exec(context.Background(),
		`INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
			birth_year, birth_month, birth_day, birth_time_status, gender, birth_timezone, birth_place_status,
			notify_status, birth_hash)
		 VALUES ($1, '벗', 'ko', $2, 'solar', false, 1990, 3, 14, 'unknown', 'female', 'Asia/Seoul',
			'not_asked', 'not_asked', $3)`,
		accountID, timezone, bytes.Repeat([]byte{0x5A}, 32))
	require.NoError(t, err)
}

type rewardEventRow struct {
	AccountID  uuid.NullUUID
	AdUnit     *string
	RewardItem *string
	CallbackAt time.Time
	Source     string
}

func rewardEvents(t *testing.T, pool *pgxpool.Pool, transactionID string) []rewardEventRow {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		"SELECT account_id, ad_unit, reward_item, callback_at, source FROM reward_events WHERE transaction_id = $1", transactionID)
	require.NoError(t, err)
	defer rows.Close()
	var out []rewardEventRow
	for rows.Next() {
		var row rewardEventRow
		require.NoError(t, rows.Scan(&row.AccountID, &row.AdUnit, &row.RewardItem, &row.CallbackAt, &row.Source))
		out = append(out, row)
	}
	require.NoError(t, rows.Err())
	return out
}

type rewardGrantRow struct {
	Entitlement, Source, SourceRef string
	StartsAt, ExpiresAt            time.Time
}

func rewardGrants(t *testing.T, pool *pgxpool.Pool) []rewardGrantRow {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		"SELECT entitlement, source, source_ref, starts_at, expires_at FROM entitlement_grants ORDER BY id")
	require.NoError(t, err)
	defer rows.Close()
	var out []rewardGrantRow
	for rows.Next() {
		var row rewardGrantRow
		require.NoError(t, rows.Scan(&row.Entitlement, &row.Source, &row.SourceRef, &row.StartsAt, &row.ExpiresAt))
		out = append(out, row)
	}
	require.NoError(t, rows.Err())
	return out
}

func callback(txID, userID string) billing.RewardCallback {
	return billing.RewardCallback{TransactionID: txID, UserID: userID, AdUnit: "123", RewardItem: "insight", Timestamp: now}
}

func TestRewards_Grant_AccountWithProfile_GrantsForTwoHours(t *testing.T) {
	f := newRewardFixture(t)
	accountID := newAccount(t, f.pool)
	insertProfile(t, f.pool, accountID, "Asia/Seoul")

	cb := callback("tx-1", accountID.String())
	cb.Timestamp = now.Add(-30 * time.Second)
	require.NoError(t, f.rewards.Grant(context.Background(), cb))

	events := rewardEvents(t, f.pool, "tx-1")
	require.Len(t, events, 1)
	assert.Equal(t, accountID, events[0].AccountID.UUID)
	assert.True(t, events[0].AccountID.Valid)
	assert.True(t, cb.Timestamp.Equal(events[0].CallbackAt), "콜백 시각은 서명된 SSV timestamp입니다")
	assert.Equal(t, "ssv", events[0].Source)
	require.NotNil(t, events[0].AdUnit)
	assert.Equal(t, "123", *events[0].AdUnit)
	grants := rewardGrants(t, f.pool)
	require.Len(t, grants, 1)
	assert.Equal(t, "insight", grants[0].Entitlement)
	assert.Equal(t, "rewarded_ad", grants[0].Source)
	assert.Equal(t, "tx-1", grants[0].SourceRef)
	assert.True(t, now.Equal(grants[0].StartsAt))
	// 처리한 시각부터 2시간(D132): now = 2026-10-20 12:00 UTC -> 14:00 UTC
	assert.True(t, time.Date(2026, 10, 20, 14, 0, 0, 0, time.UTC).Equal(grants[0].ExpiresAt), grants[0].ExpiresAt.String())

	status, err := f.store.Status(context.Background(), accountID)
	require.NoError(t, err)
	assert.True(t, status.Insight.Active)
	assert.Equal(t, billing.SourceRewardedAd, status.Insight.Source)
}

// 기간은 계정 시간대와 상관없이 처리 시각부터 2시간입니다(D132). 프로필이 없거나 시간대가 달라도 같습니다.
func TestRewards_Grant_ExpiryIgnoresTimezone(t *testing.T) {
	for name, timezone := range map[string]string{
		"프로필 없음":    "",
		"뉴욕":        "America/New_York",
		"날짜 변경선 근처": "Pacific/Apia",
	} {
		t.Run(name, func(t *testing.T) {
			f := newRewardFixture(t)
			accountID := newAccount(t, f.pool)
			if timezone != "" {
				insertProfile(t, f.pool, accountID, timezone)
			}

			require.NoError(t, f.rewards.Grant(context.Background(), callback("tx-1", accountID.String())))

			grants := rewardGrants(t, f.pool)
			require.Len(t, grants, 1)
			assert.True(t, now.Add(2*time.Hour).Equal(grants[0].ExpiresAt), grants[0].ExpiresAt.String())
		})
	}
}

func TestRewards_Grant_SameTransactionTwice_OneRowEach(t *testing.T) {
	f := newRewardFixture(t)
	accountID := newAccount(t, f.pool)

	require.NoError(t, f.rewards.Grant(context.Background(), callback("tx-1", accountID.String())))
	require.NoError(t, f.rewards.Grant(context.Background(), callback("tx-1", accountID.String())))

	assert.Len(t, rewardEvents(t, f.pool, "tx-1"), 1)
	assert.Len(t, rewardGrants(t, f.pool), 1)
}

func TestRewards_Grant_SameTransactionConcurrently_OneRowEach(t *testing.T) {
	f := newRewardFixture(t)
	accountID := newAccount(t, f.pool)

	const callers = 8
	errs := make([]error, callers)
	var wg sync.WaitGroup
	for i := range callers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			errs[i] = f.rewards.Grant(context.Background(), callback("tx-1", accountID.String()))
		}()
	}
	wg.Wait()

	for _, err := range errs {
		require.NoError(t, err)
	}
	assert.Len(t, rewardEvents(t, f.pool, "tx-1"), 1)
	assert.Len(t, rewardGrants(t, f.pool), 1)
}

func TestRewards_Grant_NoAccount_RecordsOnlyAndWarns(t *testing.T) {
	unknown := uuid.NewString()
	tests := []struct {
		name   string
		userID string
	}{
		{"user_id 없음", ""},
		{"UUID 아님", "not-a-uuid"},
		{"없는 계정", unknown},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newRewardFixture(t)

			require.NoError(t, f.rewards.Grant(context.Background(), callback("tx-1", tt.userID)))

			events := rewardEvents(t, f.pool, "tx-1")
			require.Len(t, events, 1)
			assert.False(t, events[0].AccountID.Valid)
			assert.Empty(t, rewardGrants(t, f.pool))
			assert.Contains(t, f.logs.String(), `"severity":"WARNING"`)
			assert.Contains(t, f.logs.String(), "tx-1")
			if tt.userID == "not-a-uuid" {
				assert.NotContains(t, f.logs.String(), "not-a-uuid", "UUID가 아닌 user_id 원문은 남기지 않습니다")
			}
		})
	}
}

func TestRewards_Grant_NoAccount_DuplicateCallbackWarnsOnce(t *testing.T) {
	f := newRewardFixture(t)
	cb := callback("tx-1", uuid.NewString())

	require.NoError(t, f.rewards.Grant(context.Background(), cb))
	require.NoError(t, f.rewards.Grant(context.Background(), cb))
	require.NoError(t, f.rewards.Grant(context.Background(), cb))

	assert.Equal(t, 1, strings.Count(f.logs.String(), `"severity":"WARNING"`), "중복 콜백은 Warn을 늘리지 않습니다")
}

func TestRewards_Grant_DeletedAccount_StillGrants(t *testing.T) {
	f := newRewardFixture(t)
	accountID := newAccount(t, f.pool)
	_, err := f.pool.Exec(context.Background(), "UPDATE accounts SET status = 'deleted', deleted_at = now() WHERE id = $1", accountID)
	require.NoError(t, err)

	require.NoError(t, f.rewards.Grant(context.Background(), callback("tx-1", accountID.String())))

	assert.Len(t, rewardGrants(t, f.pool), 1)
}

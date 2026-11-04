//go:build staging

package billing_test

import (
	"context"
	"net/url"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
)

// staging 보상은 SSV와 같은 처리를 탑니다: 계정 시간대의 다음 자정까지 rewarded_ad 근거 열람, user_id는 토큰의 계정(S131).
func TestTestReward_GrantsLikeSSV(t *testing.T) {
	f := newRewardFixture(t)
	rewards := billing.NewTestRewards(f.rewards, f.store)
	accountID := newAccount(t, f.pool)
	insertProfile(t, f.pool, accountID, "Asia/Seoul")

	cb := callback("test-tx-1", "someone-else")
	status, err := rewards.GrantTestReward(context.Background(), accountID, cb)
	require.NoError(t, err)

	assert.True(t, status.Insight.Active)
	assert.Equal(t, billing.SourceRewardedAd, status.Insight.Source)
	require.NotNil(t, status.Insight.ExpiresAt)
	// now = 2026-10-20 12:00 UTC = 21:00 KST -> 다음 자정 10-21 00:00 KST = 10-20 15:00 UTC
	assert.True(t, time.Date(2026, 10, 20, 15, 0, 0, 0, time.UTC).Equal(*status.Insight.ExpiresAt))
	assert.False(t, status.AdFree.Active, "광고 제거는 주지 않음")

	events := rewardEvents(t, f.pool, "test-tx-1")
	require.Len(t, events, 1)
	assert.Equal(t, accountID, events[0].AccountID.UUID, "본문의 user_id가 아니라 토큰의 계정")
	raw, err := url.ParseQuery(events[0].RawQuery)
	require.NoError(t, err)
	assert.Equal(t, url.Values{
		"transaction_id": {"test-tx-1"},
		"user_id":        {accountID.String()},
		"ad_unit":        {"123"},
		"reward_item":    {"insight"},
		"timestamp":      {"1792497600000"},
		"test_reward":    {"1"},
	}, raw, "SSV와 같은 키에 테스트 표시")
}

// 같은 transactionId를 다시 보내면 새로 부여하지 않고 지금 상태를 돌려줍니다.
func TestTestReward_SameTransactionIsIdempotent(t *testing.T) {
	f := newRewardFixture(t)
	rewards := billing.NewTestRewards(f.rewards, f.store)
	accountID := newAccount(t, f.pool)

	first, err := rewards.GrantTestReward(context.Background(), accountID, callback("test-tx-1", ""))
	require.NoError(t, err)
	again, err := rewards.GrantTestReward(context.Background(), accountID, callback("test-tx-1", ""))
	require.NoError(t, err)

	assert.Equal(t, first, again)
	assert.Len(t, rewardGrants(t, f.pool), 1)
}

// timestamp가 지금에서 SSV 허용 차이(1시간)를 넘으면 ErrRewardExpired이고 아무것도 적지 않습니다.
func TestTestReward_RejectsTimestampOutsideTolerance(t *testing.T) {
	f := newRewardFixture(t)
	rewards := billing.NewTestRewards(f.rewards, f.store)
	accountID := newAccount(t, f.pool)

	for name, at := range map[string]time.Time{
		"1시간 넘게 지남": now.Add(-time.Hour - time.Second),
		"1시간 넘게 미래": now.Add(time.Hour + time.Second),
	} {
		cb := callback("test-tx-"+name, "")
		cb.Timestamp = at
		_, err := rewards.GrantTestReward(context.Background(), accountID, cb)
		require.ErrorIs(t, err, billing.ErrRewardExpired, name)
	}
	assert.Empty(t, rewardGrants(t, f.pool))

	cb := callback("test-tx-edge", "")
	cb.Timestamp = now.Add(-time.Hour)
	_, err := rewards.GrantTestReward(context.Background(), accountID, cb)
	require.NoError(t, err, "정확히 1시간은 허용")
}

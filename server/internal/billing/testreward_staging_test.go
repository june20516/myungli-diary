//go:build staging

package billing_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
)

// staging 보상은 SSV와 같은 처리를 탑니다: 처리 시각부터 2시간 rewarded_ad 근거 열람(D132), user_id는 토큰의 계정(S131).
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
	// now = 2026-10-20 12:00 UTC -> 2시간 뒤 14:00 UTC
	assert.True(t, time.Date(2026, 10, 20, 14, 0, 0, 0, time.UTC).Equal(*status.Insight.ExpiresAt))
	assert.False(t, status.AdFree.Active, "광고 제거는 주지 않음")

	events := rewardEvents(t, f.pool, "test-tx-1")
	require.Len(t, events, 1)
	assert.Equal(t, accountID, events[0].AccountID.UUID, "본문의 user_id가 아니라 토큰의 계정")
	assert.Equal(t, "test", events[0].Source, "staging 테스트 보상은 출처 test로 SSV 콜백과 구분합니다")
	assert.True(t, cb.Timestamp.Equal(events[0].CallbackAt))
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

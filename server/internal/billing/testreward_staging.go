//go:build staging

package billing

import (
	"context"
	"fmt"
	"net/url"
	"strconv"

	"github.com/google/uuid"
)

// staging에서 서명 없이 보상형 광고 보상을 받는 기능입니다(S131). build tag staging에만 있어 prod 바이너리에는 없습니다.
// 테스트 광고에는 SSV 콜백이 오지 않아, 앱이 광고를 다 본 뒤 SSV와 같은 값을 직접 보냅니다.

// testRewardMarker는 reward_events.raw_query에서 이 경로로 들어온 보상을 SSV 콜백과 구분하는 키입니다.
const testRewardMarker = "test_reward"

// TestRewards는 서명 검증만 건너뛰고 SSV와 같은 보상 처리(Rewards.Grant)를 탄 뒤 권한 상태를 돌려줍니다.
type TestRewards struct {
	rewards *Rewards
	store   *Store
}

// NewTestRewards는 TestRewards를 만듭니다. store는 권한 상태 계산에만 씁니다.
func NewTestRewards(rewards *Rewards, store *Store) *TestRewards {
	return &TestRewards{rewards: rewards, store: store}
}

// GrantTestReward는 cb를 계정 accountID의 보상으로 기록하고 부여한 뒤 권한 상태를 돌려줍니다.
// cb.Timestamp가 지금에서 SSV와 같은 허용 차이(rewardTimestampTolerance)를 넘으면 ErrRewardExpired입니다.
// cb.UserID는 accountID로 덮어씁니다. 같은 transaction_id가 이미 있으면(다른 계정의 것이라도) 아무것도 바꾸지 않고
// 지금 상태를 돌려줍니다(SSV와 같은 멱등).
func (t *TestRewards) GrantTestReward(ctx context.Context, accountID uuid.UUID, cb RewardCallback) (Status, error) {
	if diff := t.rewards.clk.Now().Sub(cb.Timestamp); diff > rewardTimestampTolerance || diff < -rewardTimestampTolerance {
		return Status{}, ErrRewardExpired
	}
	cb.UserID = accountID.String()
	if err := t.rewards.Grant(ctx, cb, testRewardRawQuery(cb)); err != nil {
		return Status{}, err
	}
	status, err := t.store.Status(ctx, accountID)
	if err != nil {
		return Status{}, fmt.Errorf("테스트 보상 뒤 권한 상태: %w", err)
	}
	return status, nil
}

// testRewardRawQuery는 SSV 쿼리와 같은 키로 값을 적고 테스트 표시를 더한 문자열입니다(서명 없음).
func testRewardRawQuery(cb RewardCallback) string {
	values := url.Values{
		"transaction_id": {cb.TransactionID},
		"user_id":        {cb.UserID},
		"ad_unit":        {cb.AdUnit},
		"reward_item":    {cb.RewardItem},
		"timestamp":      {strconv.FormatInt(cb.Timestamp.UnixMilli(), 10)},
		testRewardMarker: {"1"},
	}
	return values.Encode()
}

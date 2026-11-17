package billing

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// Rewards는 서명이 검증된 보상형 광고 콜백을 기록하고 근거 열람(insight) 권한을 부여합니다.
type Rewards struct {
	pool *pgxpool.Pool
	clk  clock.Clock
	log  *slog.Logger
}

// NewRewards는 Rewards를 만듭니다.
func NewRewards(pool *pgxpool.Pool, clk clock.Clock, log *slog.Logger) *Rewards {
	return &Rewards{pool: pool, clk: clk, log: log}
}

// rewardedAdDuration은 보상형 광고 한 편으로 근거 열람을 여는 기간입니다. 보상을 처리한 시각부터 셉니다(D132).
const rewardedAdDuration = 2 * time.Hour

// rewardSource는 reward_events.source 값입니다. 서명을 검증한 SSV 콜백과 staging 테스트 보상(S131)을 구분합니다.
type rewardSource string

const (
	rewardSourceSSV  rewardSource = "ssv"
	rewardSourceTest rewardSource = "test"
)

// Grant는 서명을 검증한 SSV 콜백을 기록하고 부여합니다(grant, 출처 ssv).
func (r *Rewards) Grant(ctx context.Context, cb RewardCallback) error {
	return r.grant(ctx, cb, rewardSourceSSV)
}

// grant는 콜백을 reward_events에 한 번만 기록하고, 계정이 있으면 insight를 출처 rewarded_ad로
// 처리한 시각부터 rewardedAdDuration 동안 부여합니다(P7-14, D132).
// 기록은 거래 id, 계정, 광고 단위, 보상 항목, 콜백 시각, 출처뿐이고 원본 쿼리는 남기지 않습니다(D137 ③, S164).
//
// 모두 한 트랜잭션입니다. 같은 transaction_id가 이미 있으면(동시에 온 경우 포함) 아무것도 바꾸지 않고 nil입니다.
// user_id가 없거나 UUID가 아니거나 모르는 계정이면 account_id NULL로 기록만 하고 Warn 로그를 남깁니다(재시도를 막음).
// 지운 계정(deleted 껍데기)도 그대로 기록하고 부여합니다. 권한 부여 기록은 계정 삭제가 남기는 표입니다(S105).
func (r *Rewards) grant(ctx context.Context, cb RewardCallback, source rewardSource) error {
	now := r.clk.Now()
	// InTx가 fn을 다시 실행할 수 있습니다. fn은 매번 처음부터 판단하고 쓰므로 결과가 같습니다.
	return postgres.InTx(ctx, r.pool, func(tx pgx.Tx) error {
		queries := billingdb.New(tx)

		accountID, noAccountReason, err := r.findAccount(ctx, queries, cb)
		if err != nil {
			return err
		}

		inserted, err := queries.InsertRewardEvent(ctx, billingdb.InsertRewardEventParams{
			TransactionID: cb.TransactionID,
			AccountID:     uuid.NullUUID{UUID: accountID, Valid: accountID != uuid.Nil},
			AdUnit:        pgtype.Text{String: cb.AdUnit, Valid: cb.AdUnit != ""},
			RewardItem:    pgtype.Text{String: cb.RewardItem, Valid: cb.RewardItem != ""},
			CallbackAt:    cb.Timestamp,
			Source:        string(source),
			ReceivedAt:    now,
		})
		if err != nil {
			return fmt.Errorf("보상 기록(transaction %s): %w", cb.TransactionID, err)
		}
		if inserted == 0 {
			return nil
		}
		if accountID == uuid.Nil {
			r.log.WarnContext(ctx, "보상 콜백 계정 없음", "transactionId", cb.TransactionID, "reason", noAccountReason)
			return nil
		}

		err = queries.InsertRewardedAdGrant(ctx, billingdb.InsertRewardedAdGrantParams{
			AccountID: accountID,
			SourceRef: cb.TransactionID,
			StartsAt:  now,
			ExpiresAt: now.Add(rewardedAdDuration),
		})
		if err != nil {
			return fmt.Errorf("보상 권한 부여(transaction %s): %w", cb.TransactionID, err)
		}
		return nil
	})
}

// findAccount는 콜백의 user_id가 가리키는 계정을 찾습니다. 없으면 uuid.Nil과 그 사유를 돌려줍니다.
// 로그는 호출한 쪽이 새 기록일 때 한 번만 남깁니다(중복 콜백마다 반복하지 않음). user_id 원문은 로그에 쓰지 않습니다.
func (r *Rewards) findAccount(ctx context.Context, queries *billingdb.Queries, cb RewardCallback) (accountID uuid.UUID, noAccountReason string, err error) {
	if cb.UserID == "" {
		return uuid.Nil, "user_id 없음", nil
	}
	parsed, err := uuid.Parse(cb.UserID)
	if err != nil {
		return uuid.Nil, "user_id가 UUID 아님", nil
	}
	found, err := queries.ExistingAccountIDs(ctx, []uuid.UUID{parsed})
	if err != nil {
		return uuid.Nil, "", fmt.Errorf("보상 계정 조회(transaction %s): %w", cb.TransactionID, err)
	}
	if len(found) == 0 {
		return uuid.Nil, "모르는 계정 " + parsed.String(), nil
	}
	return found[0], "", nil
}

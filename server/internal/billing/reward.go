package billing

import (
	"context"
	"errors"
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

// Grant는 콜백을 reward_events에 한 번만 기록하고, 계정이 있으면 insight를 출처 rewarded_ad로
// 계정 현재 시간대의 다음 자정까지 부여합니다(P7-14). rawQuery는 원본 쿼리 전체입니다.
//
// 모두 한 트랜잭션입니다. 같은 transaction_id가 이미 있으면(동시에 온 경우 포함) 아무것도 바꾸지 않고 nil입니다.
// user_id가 없거나 UUID가 아니거나 모르는 계정이면 account_id NULL로 기록만 하고 Warn 로그를 남깁니다(재시도를 막음).
// pending_deletion·deleted 계정도 그대로 기록하고 부여합니다.
// 프로필이 없으면 UTC 자정이고, 프로필의 시간대 이름을 읽지 못하면(저장 시 검증하므로 버그) UTC로 계산하고 Error 로그를 남깁니다.
func (r *Rewards) Grant(ctx context.Context, cb RewardCallback, rawQuery string) error {
	now := r.clk.Now()
	// InTx가 fn을 다시 실행할 수 있습니다. fn은 매번 처음부터 판단하고 쓰므로 결과가 같습니다.
	return postgres.InTx(ctx, r.pool, func(tx pgx.Tx) error {
		queries := billingdb.New(tx)

		accountID, err := r.findAccount(ctx, queries, cb)
		if err != nil {
			return err
		}

		inserted, err := queries.InsertRewardEvent(ctx, billingdb.InsertRewardEventParams{
			TransactionID: cb.TransactionID,
			AccountID:     uuid.NullUUID{UUID: accountID, Valid: accountID != uuid.Nil},
			AdUnit:        pgtype.Text{String: cb.AdUnit, Valid: cb.AdUnit != ""},
			RewardItem:    pgtype.Text{String: cb.RewardItem, Valid: cb.RewardItem != ""},
			RawQuery:      rawQuery,
			ReceivedAt:    now,
		})
		if err != nil {
			return fmt.Errorf("보상 기록(transaction %s): %w", cb.TransactionID, err)
		}
		if inserted == 0 {
			return nil
		}
		if accountID == uuid.Nil {
			r.log.WarnContext(ctx, "보상 콜백 계정 없음", "transactionId", cb.TransactionID)
			return nil
		}

		loc, err := r.accountLocation(ctx, queries, accountID)
		if err != nil {
			return err
		}
		err = queries.InsertRewardedAdGrant(ctx, billingdb.InsertRewardedAdGrantParams{
			AccountID: accountID,
			SourceRef: cb.TransactionID,
			StartsAt:  now,
			ExpiresAt: nextMidnight(now, loc),
		})
		if err != nil {
			return fmt.Errorf("보상 권한 부여(transaction %s): %w", cb.TransactionID, err)
		}
		return nil
	})
}

// findAccount는 콜백의 user_id가 가리키는 계정을 찾습니다. 없으면 uuid.Nil입니다.
// user_id 원문은 UUID일 때만 로그에 남깁니다.
func (r *Rewards) findAccount(ctx context.Context, queries *billingdb.Queries, cb RewardCallback) (uuid.UUID, error) {
	if cb.UserID == "" {
		return uuid.Nil, nil
	}
	parsed, err := uuid.Parse(cb.UserID)
	if err != nil {
		return uuid.Nil, nil
	}
	found, err := queries.ExistingAccountIDs(ctx, []uuid.UUID{parsed})
	if err != nil {
		return uuid.Nil, fmt.Errorf("보상 계정 조회(transaction %s): %w", cb.TransactionID, err)
	}
	if len(found) == 0 {
		r.log.WarnContext(ctx, "보상 콜백 모르는 계정", "transactionId", cb.TransactionID, "userId", parsed.String())
		return uuid.Nil, nil
	}
	return found[0], nil
}

// accountLocation은 프로필의 현재 시간대입니다. 프로필이 없으면 UTC입니다.
func (r *Rewards) accountLocation(ctx context.Context, queries *billingdb.Queries, accountID uuid.UUID) (*time.Location, error) {
	name, err := queries.AccountCurrentTimezone(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return time.UTC, nil
	}
	if err != nil {
		return nil, fmt.Errorf("프로필 시간대 조회(계정 %s): %w", accountID, err)
	}
	loc, err := time.LoadLocation(name)
	if err != nil {
		r.log.ErrorContext(ctx, "프로필 시간대를 읽지 못해 UTC로 계산합니다", "accountId", accountID, "timezone", name, "error", err.Error())
		return time.UTC, nil
	}
	return loc, nil
}

// nextMidnight는 now 다음에 오는 loc의 자정입니다. 정각 자정이면 그다음 날 자정입니다.
// 서머타임 전환일에도 달력 날짜로 구하므로 그 날의 길이(23·25시간)를 따릅니다.
func nextMidnight(now time.Time, loc *time.Location) time.Time {
	local := now.In(loc)
	return time.Date(local.Year(), local.Month(), local.Day()+1, 0, 0, 0, 0, loc)
}

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

		accountID, noAccountReason, err := r.findAccount(ctx, queries, cb)
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
			r.log.WarnContext(ctx, "보상 콜백 계정 없음", "transactionId", cb.TransactionID, "reason", noAccountReason)
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
//
// 자정이 서머타임 gap에 걸리는 시간대(예: America/Santiago, America/Havana)에서는 그 자정이 존재하지 않고
// time.Date가 그 날의 앞 시각(전날 23시)을 줄 수 있습니다. 그러면 하루가 일찍 끝나므로,
// 결과의 달력 날짜가 다음 날이 될 때까지 한 시간씩 더해 그 날의 첫 유효 시각(예: 01:00)으로 맞춥니다.
//
// 달력 날짜가 통째로 사라진 날(Pacific/Apia 2011-12-30)에는 목표 날짜가 존재하지 않아 보정이 끝나지 않으므로
// 반복을 maxMidnightAdjust번으로 막고, 넘으면 UTC 기준 다음 자정으로 폴백합니다.
// 그 시간대의 하루를 정확히 맞추는 것보다 부여가 반드시 끝나고 now 이후라는 보장이 중요하고,
// UTC 자정은 항상 now보다 늦으며 하루 안에 끝나 너그럽지도 인색하지도 않은 합리적인 값이기 때문입니다.
func nextMidnight(now time.Time, loc *time.Location) time.Time {
	local := now.In(loc)
	year, month, day := local.Year(), local.Month(), local.Day()+1
	next := time.Date(year, month, day, 0, 0, 0, 0, loc)
	wantYear, wantMonth, wantDay := time.Date(year, month, day, 0, 0, 0, 0, time.UTC).Date()
	for range maxMidnightAdjust {
		y, m, d := next.Date()
		if next.After(now) && y == wantYear && m == wantMonth && d == wantDay {
			return next
		}
		next = next.Add(time.Hour)
	}
	utc := now.UTC()
	return time.Date(utc.Year(), utc.Month(), utc.Day()+1, 0, 0, 0, 0, time.UTC)
}

// maxMidnightAdjust는 nextMidnight가 한 시간씩 더해 보는 최대 횟수입니다. 서머타임 gap은 길어야 몇 시간입니다.
const maxMidnightAdjust = 48

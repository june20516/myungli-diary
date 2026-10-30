//go:build staging

package billing

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// staging에서 결제 없이 계정에 광고 제거 기간을 주고 거두는 기능입니다(S125). build tag staging에만 있어 prod 바이너리에는 없습니다.

// MaxTestGrantDays는 테스트 광고 제거 기간 한 번에 줄 수 있는 가장 긴 일수입니다.
const MaxTestGrantDays = 366

var (
	// ErrTestGrantDays는 days가 1~MaxTestGrantDays 밖이라는 뜻입니다.
	ErrTestGrantDays = errors.New("테스트 광고 제거 기간 일수가 범위 밖입니다")
	// ErrTestGrantAccount는 기간을 줄 계정이 없거나 지운 계정이라는 뜻입니다.
	ErrTestGrantAccount = errors.New("테스트 광고 제거 기간을 줄 계정이 없습니다")
)

// testGrantEntitlements는 실제 광고 제거권(AdFreeCatalog)과 같은 권한입니다.
var testGrantEntitlements = []Entitlement{AdFree, Insight}

// GrantTest는 계정에 지금부터 days일 동안 광고 제거와 근거 열람 권한을 출처 test_grant로 주고 권한 상태를 돌려줍니다.
// 구매 장부에는 적지 않으므로 구매 목록에 나오지 않고, 이미 있는 구간과 이어 붙이지 않습니다.
func (s *Store) GrantTest(ctx context.Context, accountID uuid.UUID, days int) (Status, error) {
	if days < 1 || days > MaxTestGrantDays {
		return Status{}, ErrTestGrantDays
	}
	now := s.clk.Now()
	sourceRef := uuid.NewString()
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := billingdb.New(tx)
		if err := lockActiveAccount(ctx, q, accountID); err != nil {
			return err
		}
		for _, entitlement := range testGrantEntitlements {
			err := q.InsertTestGrant(ctx, billingdb.InsertTestGrantParams{
				AccountID: accountID, Entitlement: string(entitlement), SourceRef: sourceRef,
				StartsAt: now, ExpiresAt: now.Add(time.Duration(days) * 24 * time.Hour),
			})
			if err != nil {
				return fmt.Errorf("테스트 광고 제거 기간 기록: %w", err)
			}
		}
		return nil
	})
	if err != nil {
		return Status{}, err
	}
	return s.Status(ctx, accountID)
}

// RevokeTest는 계정의 끝나지 않은 테스트 광고 제거 기간을 지금 끊고 권한 상태를 돌려줍니다.
// 다른 출처의 구간은 건드리지 않고, 끊을 기간이 없어도 오류가 아닙니다. 없는 계정이나 지운 계정이면 ErrTestGrantAccount입니다.
func (s *Store) RevokeTest(ctx context.Context, accountID uuid.UUID) (Status, error) {
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := billingdb.New(tx)
		if err := lockActiveAccount(ctx, q, accountID); err != nil {
			return err
		}
		if _, err := q.RevokeTestGrants(ctx, billingdb.RevokeTestGrantsParams{Now: s.clk.Now(), AccountID: accountID}); err != nil {
			return fmt.Errorf("테스트 광고 제거 기간 회수: %w", err)
		}
		return nil
	})
	if err != nil {
		return Status{}, err
	}
	return s.Status(ctx, accountID)
}

// lockActiveAccount는 계정 행을 FOR SHARE로 잡고, 없거나 지운 계정이면 ErrTestGrantAccount를 돌려줍니다.
func lockActiveAccount(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID) error {
	active, err := q.LockActiveAccountForTestGrant(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && !active) {
		return ErrTestGrantAccount
	}
	if err != nil {
		return fmt.Errorf("계정 확인: %w", err)
	}
	return nil
}

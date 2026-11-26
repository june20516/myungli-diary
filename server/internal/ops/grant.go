package ops

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/billing"
)

// 운영자 부여 기간의 상한입니다.
const (
	maxGrantDays   = 366
	maxGrantPeriod = maxGrantDays * 24 * time.Hour
)

// 권한 부여의 사용법 오류입니다.
var (
	// ErrGrantPeriod는 만료가 지금과 같거나 이전이거나 지금부터 366일을 넘을 때,
	// 또는 만료 시각과 일수 중 정확히 하나가 아니거나 일수가 1~366이 아닐 때입니다.
	ErrGrantPeriod = errors.New("만료는 지금보다 뒤이고 지금부터 366일 이내여야 합니다")
	// ErrGrantKind는 부여 종류가 ad_free, insight가 아닐 때입니다.
	ErrGrantKind = errors.New("부여 종류는 ad_free, insight 중 하나여야 합니다")
)

// GrantRequest는 권한 부여 요청입니다. 만료는 ExpiresAt(시각)과 Days(DB 시각 기준 일수) 중 정확히 하나로 줍니다.
type GrantRequest struct {
	AccountID uuid.UUID
	Kind      billing.OperatorKind
	ExpiresAt time.Time
	Days      int
	Reason    string
}

// GrantResult는 부여 결과입니다. 만든 권한 행의 source_ref는 AuditID 문자열입니다.
type GrantResult struct {
	AuditID uuid.UUID          `json:"auditId"`
	Grants  []billing.GrantRow `json:"grants"`
}

// RevokeRequest는 권한 회수 요청입니다. GrantID는 묶음에 속한 행 아무거나 가리켜도 됩니다.
type RevokeRequest struct {
	AccountID uuid.UUID
	GrantID   int64
	Reason    string
}

// RevokeResult는 회수 결과입니다. Before는 회수 전, After는 회수 뒤 묶음입니다.
type RevokeResult struct {
	AuditID uuid.UUID          `json:"auditId"`
	Before  []billing.GrantRow `json:"before"`
	After   []billing.GrantRow `json:"after"`
}

// grantTarget은 부여 감사 행의 target입니다. 만료는 UTC 시각(time.Time)이고 JSON에서는 RFC 3339로 직렬화됩니다.
type grantTarget struct {
	Kind      billing.OperatorKind `json:"kind"`
	ExpiresAt time.Time            `json:"expiresAt"`
}

// revokeTarget은 회수 감사 행의 target입니다.
type revokeTarget struct {
	GrantID int64 `json:"grantId"`
}

// Grant는 계정에 운영자 권한을 줍니다. 권한 행과 감사 행이 한 트랜잭션이고,
// 권한 행의 source_ref는 감사 행 id입니다. 거절되면 아무것도 남지 않습니다.
func (s *Service) Grant(ctx context.Context, actor Actor, req GrantRequest) (GrantResult, error) {
	if err := validateActor(actor); err != nil {
		return GrantResult{}, err
	}
	reason, err := ValidateReason(req.Reason)
	if err != nil {
		return GrantResult{}, err
	}
	if req.Kind != billing.OperatorAdFree && req.Kind != billing.OperatorInsight {
		return GrantResult{}, ErrGrantKind
	}
	if req.ExpiresAt.IsZero() == (req.Days == 0) || req.Days < 0 || req.Days > maxGrantDays {
		return GrantResult{}, ErrGrantPeriod
	}

	auditID := uuid.New()
	var grants []billing.GrantRow
	err = s.inTx(ctx, func(tx pgx.Tx) error {
		grants = nil
		// 기간 검사와 부여 시작은 DB 시각 기준입니다. 거절하면 트랜잭션을 되돌려 아무것도 남지 않습니다.
		now, err := s.now(ctx, tx)
		if err != nil {
			return err
		}
		expiresAt := req.ExpiresAt.UTC()
		if req.Days > 0 {
			expiresAt = now.Add(time.Duration(req.Days) * 24 * time.Hour)
		}
		if !expiresAt.After(now) || expiresAt.After(now.Add(maxGrantPeriod)) {
			return ErrGrantPeriod
		}
		rows, err := billing.GrantOperatorTx(ctx, tx, req.AccountID, req.Kind, auditID.String(), now, expiresAt)
		if err != nil {
			return err
		}
		grants = rows
		accountID := req.AccountID
		return recordTx(ctx, tx, auditID, Entry{
			Actor: actor, Action: ActionGrant, AccountID: &accountID, Reason: reason,
			Target: grantTarget{Kind: req.Kind, ExpiresAt: expiresAt},
			After:  rows,
		})
	})
	if err != nil {
		return GrantResult{}, err
	}
	return GrantResult{AuditID: auditID, Grants: grants}, nil
}

// Revoke는 권한 묶음을 거둡니다. 권한 행 변경과 감사 행이 한 트랜잭션입니다.
// 회수할 수 없는 출처, 없는 행, 이미 끝난 권한은 billing 오류로 거절하고 아무것도 남기지 않습니다.
func (s *Service) Revoke(ctx context.Context, actor Actor, req RevokeRequest) (RevokeResult, error) {
	if err := validateActor(actor); err != nil {
		return RevokeResult{}, err
	}
	reason, err := ValidateReason(req.Reason)
	if err != nil {
		return RevokeResult{}, err
	}
	if req.GrantID <= 0 {
		return RevokeResult{}, billing.ErrGrantNotFound
	}

	auditID := uuid.New()
	var before, after []billing.GrantRow
	err = s.inTx(ctx, func(tx pgx.Tx) error {
		before, after = nil, nil
		// 회수 시각과 만료 판단은 DB 시각 기준입니다.
		now, err := s.now(ctx, tx)
		if err != nil {
			return err
		}
		b, a, err := billing.RevokeGroupTx(ctx, tx, req.AccountID, req.GrantID, now)
		if err != nil {
			return err
		}
		before, after = b, a
		accountID := req.AccountID
		return recordTx(ctx, tx, auditID, Entry{
			Actor: actor, Action: ActionRevoke, AccountID: &accountID, Reason: reason,
			Target: revokeTarget{GrantID: req.GrantID}, Before: b, After: a,
		})
	})
	if err != nil {
		return RevokeResult{}, err
	}
	if before == nil {
		before = []billing.GrantRow{}
	}
	if after == nil {
		after = []billing.GrantRow{}
	}
	return RevokeResult{AuditID: auditID, Before: before, After: after}, nil
}

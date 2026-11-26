package ops

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/ops/opsdb"
)

// 감사 기록 조회의 한도입니다.
const (
	defaultAuditLimit = 100
	maxAuditLimit     = 1000
)

// ErrAuditFilter는 감사 기록 조회 조건이 잘못됐을 때입니다. 계정과 시작 시각 중 하나는 있어야 하고 Limit은 0~1000입니다.
var ErrAuditFilter = errors.New("감사 기록 조회는 계정 또는 시작 시각 중 하나가 필요하고 Limit은 0~1000이어야 합니다")

// AuditFilter는 감사 기록 조회 조건입니다. AccountID와 Since 중 하나 이상이 있어야 합니다.
// Limit이 0이면 100건입니다.
type AuditFilter struct {
	AccountID *uuid.UUID
	Since     *time.Time
	Limit     int
}

// AuditRecord는 감사 행 한 건입니다. 표 칸 그대로입니다.
type AuditRecord struct {
	ID        uuid.UUID       `json:"id"`
	At        time.Time       `json:"at"`
	Actor     string          `json:"actor"`
	ActorSub  string          `json:"actorSub"`
	Channel   string          `json:"channel"`
	Action    string          `json:"action"`
	AccountID *uuid.UUID      `json:"accountId"`
	Purpose   *string         `json:"purpose"`
	Reason    string          `json:"reason"`
	Target    json.RawMessage `json:"target"`
	Before    json.RawMessage `json:"before"`
	After     json.RawMessage `json:"after"`
}

// auditListTarget은 감사 기록 조회 행의 target입니다. 조회에 쓴 조건을 남깁니다. 칸은 AuditFilter와 같아야 합니다(형 변환).
type auditListTarget struct {
	AccountID *uuid.UUID `json:"accountId,omitempty"`
	Since     *time.Time `json:"since,omitempty"`
	Limit     int        `json:"limit"`
}

// AuditList는 감사 기록을 최근 순으로 돌려줍니다.
// 조회와 감사 행 쓰기가 한 트랜잭션이라, 감사 행이 커밋되지 않으면 결과를 돌려주지 않습니다.
// 이 조회가 남기는 감사 행은 결과에 들어가지 않습니다.
func (s *Service) AuditList(ctx context.Context, actor Actor, filter AuditFilter, reason string) ([]AuditRecord, error) {
	if err := validateActor(actor); err != nil {
		return nil, err
	}
	reason, err := ValidateReason(reason)
	if err != nil {
		return nil, err
	}
	if filter.AccountID == nil && filter.Since == nil || filter.Limit < 0 || filter.Limit > maxAuditLimit {
		return nil, ErrAuditFilter
	}
	if filter.Limit == 0 {
		filter.Limit = defaultAuditLimit
	}

	auditID := uuid.New()
	var records []AuditRecord
	err = s.inTx(ctx, func(tx pgx.Tx) error {
		records = nil
		params := opsdb.ListOpsAuditParams{Since: filter.Since, RowLimit: int32(filter.Limit)} //nolint:gosec // Limit은 1000 이하로 검사했습니다.
		if filter.AccountID != nil {
			params.AccountID = uuid.NullUUID{UUID: *filter.AccountID, Valid: true}
		}
		rows, err := opsdb.New(tx).ListOpsAudit(ctx, params)
		if err != nil {
			return fmt.Errorf("감사 기록 조회: %w", err)
		}
		records = make([]AuditRecord, 0, len(rows))
		for _, row := range rows {
			records = append(records, toAuditRecord(row))
		}
		return recordTx(ctx, tx, auditID, Entry{
			Actor: actor, Action: ActionAuditList, AccountID: filter.AccountID, Reason: reason,
			Target: auditListTarget(filter),
		})
	})
	if err != nil {
		return nil, err
	}
	return records, nil
}

func toAuditRecord(row opsdb.OpsAudit) AuditRecord {
	record := AuditRecord{
		ID: row.ID, At: row.At, Actor: row.Actor, ActorSub: row.ActorSub, Channel: row.Channel, Action: row.Action, Reason: row.Reason,
		Target: row.Target, Before: row.Before, After: row.After,
	}
	if row.AccountID.Valid {
		id := row.AccountID.UUID
		record.AccountID = &id
	}
	if row.Purpose.Valid {
		purpose := row.Purpose.String
		record.Purpose = &purpose
	}
	return record
}

package billing

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
)

// 운영자가 ops 명령으로 권한을 주고 거두는 기능입니다(#1321).
// 함수는 호출한 쪽의 트랜잭션 안에서 돌고, 감사 행도 같은 트랜잭션에 적습니다.

// OperatorKind는 운영자가 줄 수 있는 권한 묶음입니다.
type OperatorKind string

// 운영자 부여 종류입니다.
const (
	// OperatorAdFree는 광고 제거(ad_free)와 근거 열람(insight)을 함께 줍니다. 실제 광고 제거권과 같은 구성입니다.
	OperatorAdFree OperatorKind = "ad_free"
	// OperatorInsight는 근거 열람(insight)만 줍니다.
	OperatorInsight OperatorKind = "insight"
)

var (
	// ErrAccountNotActive는 권한을 줄 계정이 없거나 active가 아니라는 뜻입니다.
	ErrAccountNotActive = errors.New("활성 계정이 아닙니다")
	// ErrGrantNotFound는 그 계정에 해당 권한 행이 없다는 뜻입니다.
	ErrGrantNotFound = errors.New("권한 행을 찾을 수 없습니다")
	// ErrGrantNotRevocable은 운영자 부여와 보상형 광고 밖의 출처라 회수할 수 없다는 뜻입니다.
	ErrGrantNotRevocable = errors.New("회수할 수 없는 출처의 권한입니다")
	// ErrGrantAlreadyEnded는 회수할 묶음이 이미 모두 취소되었거나 만료되었다는 뜻입니다.
	ErrGrantAlreadyEnded = errors.New("이미 끝난 권한입니다")
)

// GrantRow는 entitlement_grants 한 행입니다. 취소와 만료된 행도 담습니다.
type GrantRow struct {
	ID                  int64
	Entitlement         Entitlement
	Source              Source
	SourceRef           string
	StartsAt, ExpiresAt time.Time
	RevokedAt           *time.Time
}

// operatorEntitlements는 부여 종류별로 만들 권한 행입니다.
var operatorEntitlements = map[OperatorKind][]Entitlement{
	OperatorAdFree:  {AdFree, Insight},
	OperatorInsight: {Insight},
}

// GrantOperatorTx는 계정에 kind에 맞는 권한 행을 출처 operator로 적고, 적은 행을 돌려줍니다.
// 한 번의 부여는 같은 sourceRef를 공유하며, 계정이 active가 아니면 ErrAccountNotActive입니다.
func GrantOperatorTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, kind OperatorKind, sourceRef string, startsAt, expiresAt time.Time) ([]GrantRow, error) {
	entitlements, ok := operatorEntitlements[kind]
	if !ok {
		return nil, fmt.Errorf("알 수 없는 운영자 부여 종류: %q", kind)
	}
	q := billingdb.New(tx)
	if err := requireActiveAccount(ctx, q, accountID); err != nil {
		return nil, err
	}
	rows := make([]GrantRow, 0, len(entitlements))
	for _, entitlement := range entitlements {
		row, err := q.InsertOperatorGrant(ctx, billingdb.InsertOperatorGrantParams{
			AccountID: accountID, Entitlement: string(entitlement), SourceRef: sourceRef,
			StartsAt: startsAt, ExpiresAt: expiresAt,
		})
		if err != nil {
			return nil, fmt.Errorf("운영자 권한 기록: %w", err)
		}
		rows = append(rows, toGrantRow(row))
	}
	return rows, nil
}

// RevokeGroupTx는 grantID 행의 출처를 보고 회수합니다.
// 출처가 operator면 같은 sourceRef 묶음 전부를, rewarded_ad면 그 행만 now로 취소합니다.
// 취소 전 묶음(before)과 취소 뒤 묶음(after)을 돌려줍니다. 끝나지 않은 행이 없으면 ErrGrantAlreadyEnded입니다.
func RevokeGroupTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, grantID int64, now time.Time) (before, after []GrantRow, err error) {
	q := billingdb.New(tx)
	target, err := q.GrantByID(ctx, billingdb.GrantByIDParams{ID: grantID, AccountID: accountID})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, ErrGrantNotFound
	}
	if err != nil {
		return nil, nil, fmt.Errorf("권한 행 조회: %w", err)
	}

	var group []GrantRow
	switch Source(target.Source) {
	case SourceOperator:
		found, err := q.GrantsBySourceRef(ctx, billingdb.GrantsBySourceRefParams{
			AccountID: accountID, Source: target.Source, SourceRef: target.SourceRef,
		})
		if err != nil {
			return nil, nil, fmt.Errorf("권한 묶음 조회: %w", err)
		}
		for _, row := range found {
			group = append(group, toGrantRow(row))
		}
	case SourceRewardedAd:
		group = []GrantRow{toGrantRow(target)}
	default:
		return nil, nil, ErrGrantNotRevocable
	}

	before = group
	after = make([]GrantRow, 0, len(group))
	revoked := false
	for _, row := range group {
		if row.RevokedAt != nil || !row.ExpiresAt.After(now) {
			after = append(after, row)
			continue
		}
		updated, err := q.RevokeGrantByID(ctx, billingdb.RevokeGrantByIDParams{ID: row.ID, AccountID: accountID, Now: now})
		if err != nil {
			return nil, nil, fmt.Errorf("권한 회수: %w", err)
		}
		after = append(after, toGrantRow(updated))
		revoked = true
	}
	if !revoked {
		return nil, nil, ErrGrantAlreadyEnded
	}
	return before, after, nil
}

// ListGrantsTx는 계정의 권한 행을 취소와 만료까지 전부, 최근 시작이 먼저인 순서로 돌려줍니다.
func ListGrantsTx(ctx context.Context, q billingdb.DBTX, accountID uuid.UUID) ([]GrantRow, error) {
	found, err := billingdb.New(q).ListAccountGrants(ctx, accountID)
	if err != nil {
		return nil, fmt.Errorf("권한 행 목록: %w", err)
	}
	rows := make([]GrantRow, 0, len(found))
	for _, row := range found {
		rows = append(rows, toGrantRow(row))
	}
	return rows, nil
}

func toGrantRow(row billingdb.EntitlementGrant) GrantRow {
	return GrantRow{
		ID: row.ID, Entitlement: Entitlement(row.Entitlement), Source: Source(row.Source), SourceRef: row.SourceRef,
		StartsAt: row.StartsAt, ExpiresAt: row.ExpiresAt, RevokedAt: row.RevokedAt,
	}
}

// requireActiveAccount는 계정 행을 FOR SHARE로 잡고, 없거나 active가 아니면 ErrAccountNotActive를 돌려줍니다.
func requireActiveAccount(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID) error {
	status, err := q.LockAccountStatus(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && status != "active") {
		return ErrAccountNotActive
	}
	if err != nil {
		return fmt.Errorf("계정 확인: %w", err)
	}
	return nil
}

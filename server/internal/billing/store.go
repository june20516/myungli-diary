// Package billing는 결제와 보상형 광고로 생긴 권한(광고 제거, 근거 열람)을 PostgreSQL에 기록하고 판정합니다.
package billing

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// Entitlement는 권한 종류입니다(D60).
type Entitlement string

// 권한 종류입니다.
const (
	AdFree  Entitlement = "ad_free"
	Insight Entitlement = "insight"
)

// Source는 권한이 생긴 출처입니다.
type Source string

// 권한 출처입니다.
const (
	SourceAdFreePass   Source = "ad_free_pass"
	SourceRewardedAd   Source = "rewarded_ad"
	SourceSubscription Source = "subscription"
)

// Grant는 권한 한 건입니다. entitlement_grants의 한 행에 대응합니다.
type Grant struct {
	Entitlement Entitlement
	Source      Source
	SourceRef   string
	StartsAt    time.Time
	ExpiresAt   time.Time
}

// State는 권한 하나의 현재 상태입니다. Active가 false면 ExpiresAt은 nil이고 Source는 비어 있습니다.
type State struct {
	Active    bool
	ExpiresAt *time.Time
	Source    Source
}

// Status는 계정의 권한 상태입니다.
type Status struct {
	AdFree, Insight State
}

// Store는 권한 기록을 읽어 판정합니다.
type Store struct {
	pool *pgxpool.Pool
	clk  clock.Clock
}

// NewStore는 연결 풀과 시계 위에 Store를 만듭니다.
func NewStore(pool *pgxpool.Pool, clk clock.Clock) *Store {
	return &Store{pool: pool, clk: clk}
}

// Status는 계정의 권한 상태를 계산합니다(P7-15).
// 권한이 유효한 조건은 취소되지 않았고 starts_at ≤ now < expires_at인 행이 하나라도 있는 것입니다.
// ExpiresAt은 취소되지 않았고 아직 만료되지 않은 행 중 가장 늦은 만료이고, Source는 그 행의 출처입니다.
func (s *Store) Status(ctx context.Context, accountID uuid.UUID) (Status, error) {
	now := s.clk.Now()
	rows, err := billingdb.New(s.pool).ListLiveGrants(ctx, billingdb.ListLiveGrantsParams{AccountID: accountID, Now: now})
	if err != nil {
		return Status{}, fmt.Errorf("권한 행 조회: %w", err)
	}

	started := map[Entitlement]bool{}
	latest := map[Entitlement]billingdb.ListLiveGrantsRow{}
	// 행은 (expires_at, id) 오름차순이라, 만료가 같으면 나중에 만든 행(id가 큰 행)이 이깁니다.
	for _, row := range rows {
		entitlement := Entitlement(row.Entitlement)
		if !row.StartsAt.After(now) {
			started[entitlement] = true
		}
		if current, ok := latest[entitlement]; !ok || !row.ExpiresAt.Before(current.ExpiresAt) {
			latest[entitlement] = row
		}
	}

	return Status{
		AdFree:  stateOf(started[AdFree], latest[AdFree]),
		Insight: stateOf(started[Insight], latest[Insight]),
	}, nil
}

// Unlocked는 계정이 근거 열람(insight) 권한을 가졌는지 돌려줍니다. fortune.Insight를 만족합니다.
func (s *Store) Unlocked(ctx context.Context, accountID uuid.UUID) (bool, error) {
	status, err := s.Status(ctx, accountID)
	if err != nil {
		return false, err
	}
	return status.Insight.Active, nil
}

func stateOf(active bool, latest billingdb.ListLiveGrantsRow) State {
	if !active {
		return State{}
	}
	expiresAt := latest.ExpiresAt
	return State{Active: true, ExpiresAt: &expiresAt, Source: Source(latest.Source)}
}

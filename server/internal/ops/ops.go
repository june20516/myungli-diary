// Package ops는 운영 명령(#1321)의 Service입니다.
// 모든 공개 함수는 Actor와 사유를 먼저 검사하고, 감사 행과 데이터 접근을 한 트랜잭션에서 합니다.
// CLI와 출시 뒤 어드민 API가 같은 Service를 씁니다.
package ops

import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// 호출자가 errors.Is로 구분하는 사용법 오류입니다.
var (
	// ErrReason은 사유가 비었거나 500자를 넘거나 개행을 포함할 때입니다.
	ErrReason = errors.New("사유는 앞뒤 공백을 뗀 뒤 1~500자이고 줄바꿈을 포함할 수 없습니다")
	// ErrPurpose는 목적이 inquiry, incident, policy, legal이 아닐 때입니다.
	ErrPurpose = errors.New("목적은 inquiry, incident, policy, legal 중 하나여야 합니다")
	// ErrActor는 실행자 ID가 비었거나 채널을 모를 때입니다.
	ErrActor = errors.New("실행자 ID가 비었거나 채널을 알 수 없습니다")
)

// Channel은 운영 명령이 들어온 경로입니다.
type Channel string

// 운영 명령 경로입니다.
const (
	ChannelCLI      Channel = "cli"
	ChannelAdminAPI Channel = "admin_api"
)

// Actor는 운영 명령을 실행한 사람과 경로입니다.
type Actor struct {
	ID      string
	Channel Channel
}

// validateActor는 실행자 ID가 비어 있지 않고 채널이 알려진 값인지 검사합니다.
func validateActor(a Actor) error {
	if strings.TrimSpace(a.ID) == "" {
		return ErrActor
	}
	switch a.Channel {
	case ChannelCLI, ChannelAdminAPI:
		return nil
	default:
		return ErrActor
	}
}

// Service는 운영 명령을 실행합니다.
type Service struct {
	pool *pgxpool.Pool
	clk  clock.Clock
}

// NewService는 Service를 만듭니다.
func NewService(pool *pgxpool.Pool, clk clock.Clock) *Service {
	return &Service{pool: pool, clk: clk}
}

// inTx는 fn을 트랜잭션 하나 안에서 실행합니다. 감사 행과 데이터 접근이 함께 커밋되거나 함께 취소됩니다.
func (s *Service) inTx(ctx context.Context, fn func(pgx.Tx) error) error {
	return postgres.InTx(ctx, s.pool, fn)
}

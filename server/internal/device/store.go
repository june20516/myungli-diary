package device

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/device/devicedb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// deviceLockSQL은 한 계정의 기기 등록을 트랜잭션 하나씩 차례로 하게 합니다.
// 동시에 온 등록이 각자 활성 기기를 세면 상한을 함께 넘길 수 있어서 계정 단위로 묶습니다. 트랜잭션이 끝나면 자동으로 풀립니다.
// 키 도출은 content.selectionLockSQL과 같은 두 int4 키 형식이고, 첫 키 deviceLockClass로 다른 lock과 겹치지 않습니다.
const deviceLockSQL = "SELECT pg_advisory_xact_lock($1::int4, hashtext($2::text))"

// deviceLockClass는 deviceLockSQL의 첫 키입니다("dev"의 ASCII).
const deviceLockClass int32 = 0x646576

// Store는 PostgreSQL 알림 기기 저장소입니다.
type Store struct {
	pool *pgxpool.Pool
	clk  clock.Clock
}

// NewStore는 연결 풀 위에 저장소를 만듭니다. 마지막으로 본 시각은 clk에서 받습니다.
func NewStore(pool *pgxpool.Pool, clk clock.Clock) *Store {
	return &Store{pool: pool, clk: clk}
}

// Register는 토큰을 계정의 활성 기기로 등록합니다. created는 처음 보는 토큰일 때만 true입니다.
// 이미 있는 토큰이면 같은 id를 유지한 채 주인·platform·마지막으로 본 시각을 바꾸고 다시 활성으로 둡니다.
// 그 뒤 계정의 활성 기기가 MaxActivePerAccount를 넘으면 가장 오래 보지 못한 기기부터 비활성으로 바꿉니다.
func (s *Store) Register(ctx context.Context, accountID uuid.UUID, token string, platform Platform) (Device, bool, error) {
	var (
		registered Device
		created    bool
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, deviceLockSQL, deviceLockClass, accountID.String()); err != nil {
			return fmt.Errorf("알림 기기 lock: %w", err)
		}
		id, err := uuid.NewV7()
		if err != nil {
			return fmt.Errorf("알림 기기 id 생성: %w", err)
		}
		q := devicedb.New(tx)
		row, err := q.UpsertDevice(ctx, devicedb.UpsertDeviceParams{
			ID: id, AccountID: accountID, FcmToken: token, Platform: string(platform), SeenAt: s.clk.Now(),
		})
		if err != nil {
			return fmt.Errorf("알림 기기 등록: %w", err)
		}
		if _, err := q.DeactivateOverflowDevices(ctx, devicedb.DeactivateOverflowDevicesParams{
			AccountID: accountID, MaxActive: MaxActivePerAccount,
		}); err != nil {
			return fmt.Errorf("알림 기기 상한 적용: %w", err)
		}
		registered = Device{ID: row.ID, Platform: Platform(row.Platform)}
		created = row.Inserted
		return nil
	})
	if err != nil {
		return Device{}, false, err
	}
	return registered, created, nil
}

// Deactivate는 계정의 기기를 비활성으로 바꿉니다. 이미 비활성이어도 성공이고, 없거나 남의 기기면 ErrNotFound입니다.
func (s *Store) Deactivate(ctx context.Context, accountID, id uuid.UUID) error {
	n, err := devicedb.New(s.pool).DeactivateDevice(ctx, devicedb.DeactivateDeviceParams{ID: id, AccountID: accountID})
	if err != nil {
		return fmt.Errorf("알림 기기 해제: %w", err)
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

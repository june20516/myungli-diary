// Package preview는 비로그인 미리보기의 설치별 1회 사용 기록을 PostgreSQL에 남깁니다.
package preview

import (
	"context"
	"crypto/sha256"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/preview/previewdb"
)

// Usage는 설치마다 미리보기를 한 번만 쓰게 기록합니다. 저장하는 값은 설치 id의 SHA-256뿐입니다(D50·D58).
type Usage struct {
	pool *pgxpool.Pool
}

// NewUsage는 연결 풀 위에 Usage를 만듭니다.
func NewUsage(pool *pgxpool.Pool) *Usage {
	return &Usage{pool: pool}
}

// Claim은 설치를 선점합니다. 새로 선점하면 true, 이미 쓴 설치면 false입니다.
// 한 문장(INSERT … ON CONFLICT DO NOTHING)이라 동시에 불러도 하나만 true입니다.
func (u *Usage) Claim(ctx context.Context, installationID string) (bool, error) {
	rows, err := previewdb.New(u.pool).ClaimPreviewUsage(ctx, deviceHash(installationID))
	if err != nil {
		return false, fmt.Errorf("미리보기 사용 선점: %w", err)
	}
	return rows == 1, nil
}

// Release는 선점을 풀어 같은 설치가 다시 쓸 수 있게 합니다. 없는 기록이면 아무 일도 하지 않습니다.
func (u *Usage) Release(ctx context.Context, installationID string) error {
	if err := previewdb.New(u.pool).ReleasePreviewUsage(ctx, deviceHash(installationID)); err != nil {
		return fmt.Errorf("미리보기 사용 해제: %w", err)
	}
	return nil
}

// deviceHash는 설치 id의 SHA-256(32바이트)입니다.
func deviceHash(installationID string) []byte {
	sum := sha256.Sum256([]byte(installationID))
	return sum[:]
}

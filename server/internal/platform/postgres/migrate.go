package postgres

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"path"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"github.com/june20516/myungli-diary/server/db"
)

// MigrationStatus는 migration 파일 하나의 적용 상태입니다.
type MigrationStatus struct {
	// Source는 migration 파일 이름입니다(예: 00001_init.sql).
	Source  string
	Applied bool
}

// ErrNothingToRollBack은 적용된 migration이 없어 down으로 되돌릴 것이 없을 때 반환됩니다.
var ErrNothingToRollBack = errors.New("되돌릴 migration이 없습니다")

// Migrate는 migration을 실행합니다. direction은 up(전부 적용) 또는 down(하나 되돌림)입니다.
//
// 처음 계획(up/down/status)과 달리 status는 받지 않습니다. 출력이 필요한 status는 Status의 결과를
// 호출자가 주입된 writer에 쓰도록 했습니다. 그래서 Migrate는 어디에도 출력하지 않습니다.
// 적용된 migration이 없을 때 down은 ErrNothingToRollBack을 반환합니다.
func Migrate(ctx context.Context, pool *pgxpool.Pool, direction string) error {
	if direction != "up" && direction != "down" {
		return fmt.Errorf("알 수 없는 migrate 방향 %q", direction)
	}

	provider, closeProvider, err := newProvider(pool)
	if err != nil {
		return err
	}
	defer closeProvider()

	if direction == "up" {
		_, err = provider.Up(ctx)
	} else {
		_, err = provider.Down(ctx)
	}
	switch {
	case direction == "down" && (errors.Is(err, goose.ErrNoNextVersion) || errors.Is(err, goose.ErrNoCurrentVersion)):
		return ErrNothingToRollBack
	case err != nil:
		return fmt.Errorf("migrate %s: %w", direction, err)
	}
	return nil
}

// Status는 모든 migration 파일의 적용 상태를 파일 순서대로 반환합니다.
func Status(ctx context.Context, pool *pgxpool.Pool) ([]MigrationStatus, error) {
	provider, closeProvider, err := newProvider(pool)
	if err != nil {
		return nil, err
	}
	defer closeProvider()

	gooseStatuses, err := provider.Status(ctx)
	if err != nil {
		return nil, fmt.Errorf("migrate status: %w", err)
	}
	statuses := make([]MigrationStatus, 0, len(gooseStatuses))
	for _, s := range gooseStatuses {
		statuses = append(statuses, MigrationStatus{
			Source:  path.Base(s.Source.Path),
			Applied: s.State == goose.StateApplied,
		})
	}
	return statuses, nil
}

// migrationsFS는 embed된 파일에서 migrations 디렉터리를 루트로 잘라 냅니다.
func migrationsFS() fs.FS {
	sub, err := fs.Sub(db.Migrations, "migrations")
	if err != nil {
		// 고정 경로라 실패하면 빌드 설정 오류입니다.
		panic(fmt.Sprintf("embed된 migrations를 열 수 없습니다: %v", err))
	}
	return sub
}

// newProvider는 풀을 database/sql 연결로 감싸 goose provider를 만듭니다.
// 반환된 함수로 provider가 쓰는 *sql.DB를 닫으며, 원래 pool은 닫지 않습니다.
func newProvider(pool *pgxpool.Pool) (*goose.Provider, func(), error) {
	sqlDB := stdlib.OpenDBFromPool(pool)
	provider, err := goose.NewProvider(goose.DialectPostgres, sqlDB, migrationsFS())
	if err != nil {
		_ = sqlDB.Close()
		return nil, nil, fmt.Errorf("goose provider: %w", err)
	}
	return provider, func() { _ = provider.Close() }, nil
}

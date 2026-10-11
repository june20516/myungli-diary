package postgres

import (
	"context"
	"fmt"
	"io/fs"
	"os"
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

// Migrate는 migration을 실행합니다. direction은 up(전부 적용), down(하나 되돌림), status(상태를 stdout에 출력)입니다.
func Migrate(ctx context.Context, pool *pgxpool.Pool, direction string) error {
	if direction == "status" {
		return printStatus(ctx, pool)
	}
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
	if err != nil {
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

func printStatus(ctx context.Context, pool *pgxpool.Pool) error {
	statuses, err := Status(ctx, pool)
	if err != nil {
		return err
	}
	for _, status := range statuses {
		state := "Pending"
		if status.Applied {
			state = "Applied"
		}
		fmt.Fprintf(os.Stdout, "%-8s %s\n", state, status.Source)
	}
	return nil
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

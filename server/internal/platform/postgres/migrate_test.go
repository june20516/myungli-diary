package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// dbtest.New는 이미 migration을 적용한 DB를 주므로, 먼저 down으로 되돌린 뒤 down → up → down → up을 확인합니다.
func TestMigrate_UpDownUp(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	for _, direction := range []string{"down", "up", "down", "up"} {
		if err := postgres.Migrate(ctx, pool, direction); err != nil {
			t.Fatalf("Migrate(%s): %v", direction, err)
		}
	}

	statuses, err := postgres.Status(ctx, pool)
	if err != nil {
		t.Fatalf("Status: %v", err)
	}
	wantSources := []string{"00001_init.sql", "00002_accounts_auth.sql", "00003_apple_web_logins.sql", "00004_profiles_caches.sql", "00005_content.sql", "00006_diaries.sql", "00007_schedules.sql", "00008_idempotency_keys.sql", "00009_rate_limits.sql", "00010_preview_usage.sql"}
	if len(statuses) != len(wantSources) {
		t.Fatalf("status = %+v, want %v applied", statuses, wantSources)
	}
	for i, want := range wantSources {
		if statuses[i].Source != want || !statuses[i].Applied {
			t.Errorf("status = %+v, want %v applied", statuses, wantSources)
			break
		}
	}
}

func TestMigrate_UnknownDirection(t *testing.T) {
	pool := dbtest.New(t)
	for _, direction := range []string{"sideways", "status"} {
		if err := postgres.Migrate(context.Background(), pool, direction); err == nil {
			t.Errorf("%q는 Migrate가 받지 않는 방향인데 오류가 없습니다", direction)
		}
	}
}

func TestMigrate_DownWithNothingApplied_ReturnsErrNothingToRollBack(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	// migration 파일이 열이므로 열 다 되돌려야 적용된 것이 없어집니다.
	for i := 1; i <= 10; i++ {
		if err := postgres.Migrate(ctx, pool, "down"); err != nil {
			t.Fatalf("%d번째 down: %v", i, err)
		}
	}
	if err := postgres.Migrate(ctx, pool, "down"); !errors.Is(err, postgres.ErrNothingToRollBack) {
		t.Errorf("열한 번째 down 오류 = %v, want ErrNothingToRollBack", err)
	}
}

func TestInit_SetUpdatedAtExists(t *testing.T) {
	pool := dbtest.New(t)

	var found int
	err := pool.QueryRow(context.Background(), "SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at'").Scan(&found)
	if err != nil {
		t.Fatalf("set_updated_at 조회: %v", err)
	}
}

func TestInit_SetUpdatedAtTouchesRow(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	// 풀의 연결이 여러 개일 수 있으므로 한 연결에서 TEMP 테이블을 만들고 씁니다.
	conn, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatalf("Acquire: %v", err)
	}
	defer conn.Release()

	_, err = conn.Exec(ctx, `
		CREATE TEMP TABLE sample (id int PRIMARY KEY, updated_at timestamptz NOT NULL DEFAULT '2000-01-01');
		CREATE TRIGGER sample_set_updated_at BEFORE UPDATE ON sample
			FOR EACH ROW EXECUTE FUNCTION set_updated_at();
		INSERT INTO sample (id) VALUES (1);
		UPDATE sample SET id = 1 WHERE id = 1;`)
	if err != nil {
		t.Fatalf("준비: %v", err)
	}
	var touched bool
	if err := conn.QueryRow(ctx, "SELECT updated_at > '2000-01-02' FROM sample").Scan(&touched); err != nil {
		t.Fatalf("조회: %v", err)
	}
	if !touched {
		t.Error("UPDATE 뒤 updated_at이 갱신되지 않았습니다")
	}
}

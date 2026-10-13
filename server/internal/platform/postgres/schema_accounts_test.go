package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const (
	checkViolation      = "23514"
	uniqueViolation     = "23505"
	foreignKeyViolation = "23503"
)

// wantSQLState는 err가 PostgreSQL 오류이고 SQLSTATE가 want와 같은지 확인합니다.
func wantSQLState(t *testing.T, err error, want string) {
	t.Helper()
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		t.Fatalf("PostgreSQL 오류를 기대했지만 %v", err)
	}
	if pgErr.Code != want {
		t.Errorf("SQLSTATE = %s (%s), want %s", pgErr.Code, pgErr.Message, want)
	}
}

// insertAccount는 계정 한 행을 넣고 그 결과 오류를 돌려줍니다.
func insertAccount(ctx context.Context, pool *pgxpool.Pool, id, status string, deletionRequested, anonymized bool) error {
	deletionAt, anonymizedAt := "NULL", "NULL"
	if deletionRequested {
		deletionAt = "now()"
	}
	if anonymized {
		anonymizedAt = "now()"
	}
	_, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, deletion_requested_at, anonymized_at, last_active_at)
		VALUES ($1, $2, `+deletionAt+`, `+anonymizedAt+`, now())`, id, status)
	return err
}

const (
	accountA = "00000000-0000-7000-8000-000000000001"
	accountB = "00000000-0000-7000-8000-000000000002"
)

func TestSchema_AccountStatusRequiresMatchingTimestamps(t *testing.T) {
	tests := []struct {
		name              string
		status            string
		deletionRequested bool
		anonymized        bool
		wantState         string // 빈 문자열이면 성공해야 합니다.
	}{
		{"active 정상", "active", false, false, ""},
		{"pending_deletion 정상", "pending_deletion", true, false, ""},
		{"deleted 정상", "deleted", true, true, ""},
		{"active인데 deletion_requested_at 있음", "active", true, false, checkViolation},
		{"pending_deletion인데 deletion_requested_at 없음", "pending_deletion", false, false, checkViolation},
		{"pending_deletion인데 anonymized_at 있음", "pending_deletion", true, true, checkViolation},
		{"deleted인데 anonymized_at 없음", "deleted", true, false, checkViolation},
		{"알 수 없는 status", "banned", false, false, checkViolation},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := dbtest.New(t)
			err := insertAccount(context.Background(), pool, accountA, tt.status, tt.deletionRequested, tt.anonymized)
			if tt.wantState == "" {
				if err != nil {
					t.Fatalf("성공해야 하는데 %v", err)
				}
				return
			}
			wantSQLState(t, err, tt.wantState)
		})
	}
}

func TestSchema_KakaoIdentityRejectsAppleColumns(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
		t.Fatal(err)
	}
	_, err := pool.Exec(ctx, `INSERT INTO auth_identities
		(id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
		VALUES ('00000000-0000-7000-8000-0000000000a1', $1, 'kakao', 'k-1', '\x01', 'key', 'client')`, accountA)
	wantSQLState(t, err, checkViolation)
}

func TestSchema_AppleTokenColumnsComeTogether(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
		t.Fatal(err)
	}
	_, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject, apple_refresh_token)
		VALUES ('00000000-0000-7000-8000-0000000000a1', $1, 'apple', 'a-1', '\x01')`, accountA)
	wantSQLState(t, err, checkViolation)

	// 세 열이 모두 있으면 apple 연결은 저장됩니다.
	_, err = pool.Exec(ctx, `INSERT INTO auth_identities
		(id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
		VALUES ('00000000-0000-7000-8000-0000000000a2', $1, 'apple', 'a-2', '\x01', 'key', 'client')`, accountA)
	if err != nil {
		t.Fatalf("세 열이 모두 있는 apple 연결은 저장돼야 합니다: %v", err)
	}
}

func TestSchema_IdentityUniquePerProviderSubject(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, id := range []string{accountA, accountB} {
		if err := insertAccount(ctx, pool, id, "active", false, false); err != nil {
			t.Fatal(err)
		}
	}
	_, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
		VALUES ('00000000-0000-7000-8000-0000000000a1', $1, 'kakao', 'same')`, accountA)
	if err != nil {
		t.Fatal(err)
	}
	_, err = pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
		VALUES ('00000000-0000-7000-8000-0000000000a2', $1, 'kakao', 'same')`, accountB)
	wantSQLState(t, err, uniqueViolation)
}

func TestSchema_AccountsCannotBeDeletedWhileReferenced(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
		VALUES ('00000000-0000-7000-8000-0000000000a1', $1, 'kakao', 'k-1')`, accountA); err != nil {
		t.Fatal(err)
	}
	_, err := pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1`, accountA)
	wantSQLState(t, err, foreignKeyViolation)
}

func TestSchema_MigrationDownUp(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	// 최신 migration(계정·인증 스키마)을 내렸다가 다시 올립니다.
	for _, direction := range []string{"down", "up"} {
		if err := postgres.Migrate(ctx, pool, direction); err != nil {
			t.Fatalf("Migrate(%s): %v", direction, err)
		}
	}
	if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
		t.Fatalf("다시 올린 뒤 accounts에 쓸 수 있어야 합니다: %v", err)
	}
}

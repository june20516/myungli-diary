package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const (
	identityLine = "00000000-0000-7000-8000-0000000000b1"
)

// wantConstraint는 err가 위반한 제약 이름이 want와 같은지 확인합니다.
func wantConstraint(t *testing.T, err error, want string) {
	t.Helper()
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		t.Fatalf("PostgreSQL 오류를 기대했지만 %v", err)
	}
	if pgErr.ConstraintName != want {
		t.Errorf("제약 = %s, want %s", pgErr.ConstraintName, want)
	}
}

func TestSchema_LineGoogleIdentities(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, id := range []string{accountA, accountB} {
		if err := insertAccount(ctx, pool, id, "active", false, false); err != nil {
			t.Fatal(err)
		}
	}
	insert := func(id, account, provider, subject, apple string) error {
		_, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject`+apple+`)
			VALUES ($1, $2, $3, $4`+map[bool]string{true: `, '\x01', 'key', 'client'`, false: ``}[apple != ""]+`)`, id, account, provider, subject)
		return err
	}
	const withApple = `, apple_refresh_token, apple_token_key_id, apple_client_id`

	if err := insert(identityLine, accountA, "line", "line-1", ""); err != nil {
		t.Fatalf("line 연결: %v", err)
	}
	if err := insert("00000000-0000-7000-8000-0000000000b2", accountA, "google", "google-1", ""); err != nil {
		t.Fatalf("google 연결: %v", err)
	}
	for _, provider := range []string{"line", "google"} {
		err := insert("00000000-0000-7000-8000-0000000000b3", accountB, provider, provider+"-apple", withApple)
		wantSQLState(t, err, checkViolation)
		wantConstraint(t, err, "auth_identities_line_google_without_apple")
	}

	if err := insert("00000000-0000-7000-8000-0000000000b4", accountA, "kakao", "kakao-1", ""); err != nil {
		t.Fatal(err)
	}
	err := insert("00000000-0000-7000-8000-0000000000b5", accountA, "kakao", "kakao-2", "")
	wantSQLState(t, err, uniqueViolation)
	wantConstraint(t, err, "auth_identities_account_provider_key")
}

func TestSchema_MergeTicketFollowsIdentityAndRestrictsAccounts(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, id := range []string{accountA, accountB} {
		if err := insertAccount(ctx, pool, id, "active", false, false); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
		VALUES ($1, $2, 'line', 'line-1')`, identityLine, accountB); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
		VALUES (gen_random_uuid(), '\x01', $1, $2, $3, now() + interval '10 minutes')`, accountA, accountB, identityLine); err != nil {
		t.Fatal(err)
	}

	// 계정은 토큰이 가리키는 동안 지울 수 없습니다(RESTRICT).
	_, err := pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1`, accountA)
	wantSQLState(t, err, foreignKeyViolation)
	wantConstraint(t, err, "account_merge_tickets_account_id_fkey")

	// 붙이려던 연결이 지워지면 토큰도 사라집니다(CASCADE).
	if _, err := pool.Exec(ctx, `DELETE FROM auth_identities WHERE id = $1`, identityLine); err != nil {
		t.Fatal(err)
	}
	var tickets int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM account_merge_tickets`).Scan(&tickets); err != nil {
		t.Fatal(err)
	}
	if tickets != 0 {
		t.Errorf("합치기 토큰 = %d개, want 0", tickets)
	}
}

func TestSchema_Migration00014Down(t *testing.T) {
	ctx := context.Background()
	t.Run("표와 제약이 사라집니다", func(t *testing.T) {
		pool := dbtest.New(t)
		if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
			t.Fatal(err)
		}
		if err := postgres.Migrate(ctx, pool, "down"); err != nil { // 00014만 내립니다.
			t.Fatal(err)
		}
		var exists bool
		if err := pool.QueryRow(ctx, `SELECT to_regclass('account_merge_tickets') IS NOT NULL`).Scan(&exists); err != nil {
			t.Fatal(err)
		}
		if exists {
			t.Error("account_merge_tickets가 남았습니다")
		}
		_, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
			VALUES ($1, $2, 'line', 'line-1')`, identityLine, accountA)
		wantSQLState(t, err, checkViolation)
		wantConstraint(t, err, "auth_identities_provider_check")
		for i, subject := range []string{"k-1", "k-2"} { // 계정당 제공자 하나 제약이 사라집니다.
			if _, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
				VALUES (gen_random_uuid(), $1, 'kakao', $2)`, accountA, subject); err != nil {
				t.Fatalf("kakao 연결 %d: %v", i, err)
			}
		}
	})

	t.Run("line 행이 남아 있으면 되돌리기가 CHECK 위반으로 실패합니다", func(t *testing.T) {
		pool := dbtest.New(t)
		if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
			t.Fatal(err)
		}
		if _, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
			VALUES ($1, $2, 'line', 'line-1')`, identityLine, accountA); err != nil {
			t.Fatal(err)
		}
		err := postgres.Migrate(ctx, pool, "down")
		var pgErr *pgconn.PgError
		if !errors.As(err, &pgErr) || pgErr.Code != checkViolation {
			t.Errorf("Migrate(down) = %v, want CHECK 위반", err)
		}
	})
}

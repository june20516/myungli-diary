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

// insertActive는 active 계정 한 행을 넣고 그 결과 오류를 돌려줍니다. 지금 스키마와 00014 이하 스키마 모두에서 됩니다.
func insertActive(ctx context.Context, pool *pgxpool.Pool, id string) error {
	_, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', now())`, id)
	return err
}

// insertLegacyAccount는 00014 이하 스키마(deletion_requested_at·anonymized_at이 있던 때)에 계정 한 행을 넣습니다.
func insertLegacyAccount(ctx context.Context, pool *pgxpool.Pool, id, status string, deletionRequested, anonymized bool) error {
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

// 00002의 옛 CHECK입니다. 00015가 바꾸므로 00014까지 내린 스키마에서 확인합니다.
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
			ctx := context.Background()
			pool := dbtest.New(t)
			if err := postgres.MigrateDownTo(ctx, pool, 14); err != nil {
				t.Fatal(err)
			}
			err := insertLegacyAccount(ctx, pool, accountA, tt.status, tt.deletionRequested, tt.anonymized)
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
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatal(err)
	}
	_, err := pool.Exec(ctx, `INSERT INTO auth_identities
		(id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
		VALUES ('00000000-0000-7000-8000-0000000000a1', $1, 'kakao', 'k-1', '\x01', 'key', 'client')`, accountA)
	wantSQLState(t, err, checkViolation)
}

func TestSchema_AppleTokenColumnsComeTogether(t *testing.T) {
	tests := []struct {
		name      string
		token     string // SQL 리터럴. 'NULL'이면 비어 있는 열입니다.
		keyID     string
		clientID  string
		wantState string
	}{
		{"세 열 모두 있음", `'\x01'`, `'key'`, `'client'`, ""},
		{"세 열 모두 없음", "NULL", "NULL", "NULL", ""},
		{"token만 있음", `'\x01'`, "NULL", "NULL", checkViolation},
		{"key_id만 있음", "NULL", `'key'`, "NULL", checkViolation},
		{"client_id만 있음", "NULL", "NULL", `'client'`, checkViolation},
		{"client_id만 없음", `'\x01'`, `'key'`, "NULL", checkViolation},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx := context.Background()
			pool := dbtest.New(t)
			if err := insertActive(ctx, pool, accountA); err != nil {
				t.Fatal(err)
			}
			_, err := pool.Exec(ctx, `INSERT INTO auth_identities
				(id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
				VALUES ('00000000-0000-7000-8000-0000000000a1', $1, 'apple', 'a-1', `+tt.token+`, `+tt.keyID+`, `+tt.clientID+`)`, accountA)
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

func TestSchema_IdentityUniquePerProviderSubject(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	for _, id := range []string{accountA, accountB} {
		if err := insertActive(ctx, pool, id); err != nil {
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
	if err := insertActive(ctx, pool, accountA); err != nil {
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
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatalf("다시 올린 뒤 accounts에 쓸 수 있어야 합니다: %v", err)
	}
}

func TestSchema_RefreshTokenHashIsUnique(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatal(err)
	}
	const insert = `INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at)
		VALUES ($1, $2, '\xabcd', '00000000-0000-7000-8000-0000000000f1', now())`
	if _, err := pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000b1", accountA); err != nil {
		t.Fatal(err)
	}
	_, err := pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000b2", accountA)
	wantSQLState(t, err, uniqueViolation)
}

func TestSchema_RefreshTokenUsedAndReplacedComeTogether(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatal(err)
	}
	const (
		usedID = "00000000-0000-7000-8000-0000000000c1"
		nextID = "00000000-0000-7000-8000-0000000000c2"
	)
	const insert = `INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at)
		VALUES ($1, $2, $3, '00000000-0000-7000-8000-0000000000f1', now())`
	for i, id := range []string{usedID, nextID} {
		if _, err := pool.Exec(ctx, insert, id, accountA, []byte{byte(i + 1)}); err != nil {
			t.Fatal(err)
		}
	}

	tests := []struct {
		name string
		sql  string
		want string
	}{
		{name: "used_at만 있음", sql: `UPDATE refresh_tokens SET used_at = now() WHERE id = $1`, want: checkViolation},
		{name: "replaced_by_id만 있음", sql: `UPDATE refresh_tokens SET replaced_by_id = '` + nextID + `' WHERE id = $1`, want: checkViolation},
		{name: "없는 토큰을 가리킴", sql: `UPDATE refresh_tokens SET used_at = now(), replaced_by_id = '00000000-0000-7000-8000-0000000000c9' WHERE id = $1`, want: foreignKeyViolation},
		{name: "둘 다 있음", sql: `UPDATE refresh_tokens SET used_at = now(), replaced_by_id = '` + nextID + `' WHERE id = $1`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := pool.Exec(ctx, tt.sql, usedID)
			if tt.want == "" {
				if err != nil {
					t.Fatal(err)
				}
				return
			}
			wantSQLState(t, err, tt.want)
		})
	}
}

func TestSchema_ConsentDocumentAndUniqueness(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatal(err)
	}
	const insert = `INSERT INTO consents (id, account_id, document, version, agreed_at) VALUES ($1, $2, $3, $4, now())`

	_, err := pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000c1", accountA, "marketing", "v1")
	wantSQLState(t, err, checkViolation)

	if _, err := pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000c2", accountA, "terms", "v1"); err != nil {
		t.Fatal(err)
	}
	// 다른 문서나 다른 버전은 따로 저장됩니다.
	if _, err := pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000c3", accountA, "privacy", "v1"); err != nil {
		t.Fatalf("다른 document는 저장돼야 합니다: %v", err)
	}
	if _, err := pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000c4", accountA, "terms", "v2"); err != nil {
		t.Fatalf("다른 version은 저장돼야 합니다: %v", err)
	}
	_, err = pool.Exec(ctx, insert, "00000000-0000-7000-8000-0000000000c5", accountA, "terms", "v1")
	wantSQLState(t, err, uniqueViolation)
}

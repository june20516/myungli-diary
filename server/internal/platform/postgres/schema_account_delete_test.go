package postgres_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const insertRevocation = `INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at)
	VALUES ($1, $2, gen_random_uuid(), $3, $4, $5, now())`

func TestSchema00015_ProviderRevocationsHasNoFK(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertActive(ctx, pool, accountA); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject)
		VALUES ($1, $2, 'kakao', 'kakao-1')`, identityLine, accountA); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO provider_revocations (provider, subject, identity_id, next_attempt_at)
		VALUES ('kakao', 'kakao-1', $1, now())`, identityLine); err != nil {
		t.Fatal(err)
	}

	// 원래 연결과 계정 행을 지워도(FK가 없으므로) 대기 행은 남아야 합니다.
	if _, err := pool.Exec(ctx, `DELETE FROM auth_identities WHERE id = $1`, identityLine); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1`, accountA); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM provider_revocations`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Errorf("허가 취소 대기 = %d행, want 1", count)
	}
}

func TestSchema00015_ProviderRevocationsConstraints(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	tests := []struct {
		name      string
		provider  string
		subject   any
		token     any
		keyID     any
		clientID  any
		wantState string // 빈 문자열이면 성공해야 합니다.
	}{
		{"kakao는 Apple 열 없이 성공", "kakao", "k-1", nil, nil, nil, ""},
		{"apple은 Apple 열 전부와 성공", "apple", nil, []byte{1}, "key", "client", ""},
		{"kakao에 Apple 열이 있으면 거절", "kakao", "k-1", []byte{1}, "key", "client", checkViolation},
		{"kakao에 subject가 없으면 거절", "kakao", nil, nil, nil, nil, checkViolation},
		{"apple에 Apple 열이 일부만 있으면 거절", "apple", nil, []byte{1}, nil, nil, checkViolation},
		{"apple에 Apple 열이 없으면 거절", "apple", nil, nil, nil, nil, checkViolation},
		{"line은 거절", "line", "l-1", nil, nil, nil, checkViolation},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := pool.Exec(ctx, insertRevocation, tt.provider, tt.subject, tt.token, tt.keyID, tt.clientID)
			if tt.wantState == "" {
				if err != nil {
					t.Fatalf("INSERT: %v", err)
				}
				return
			}
			wantSQLState(t, err, tt.wantState)
		})
	}
}

func TestSchema00015_ReactionTalliesRejectsNonPositiveCount(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	const insert = `INSERT INTO reaction_tallies (message_key, variant, reaction, count) VALUES ('m', 'v', 'like', $1)`
	_, err := pool.Exec(ctx, insert, 0)
	wantSQLState(t, err, checkViolation)
	if _, err := pool.Exec(ctx, insert, 1); err != nil {
		t.Fatalf("count 1: %v", err)
	}
	_, err = pool.Exec(ctx, insert, 2)
	wantSQLState(t, err, uniqueViolation)
}

func TestSchema00015_DeletedAtBackfill(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := postgres.MigrateDownTo(ctx, pool, 14); err != nil {
		t.Fatal(err)
	}
	// 두 시각이 달라야 coalesce 우선순위(anonymized_at 먼저)를 구분할 수 있습니다.
	requestedAt := time.Date(2026, 10, 1, 9, 0, 0, 0, time.UTC)
	anonymizedAt := requestedAt.Add(24 * time.Hour)
	if _, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, deletion_requested_at, anonymized_at, last_active_at)
		VALUES ($1, 'deleted', $2, $3, now())`, accountA, requestedAt, anonymizedAt); err != nil {
		t.Fatal(err)
	}
	if err := insertActive(ctx, pool, accountB); err != nil {
		t.Fatal(err)
	}
	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatal(err)
	}

	if got := deletedAtOf(t, ctx, pool, accountA); got == nil || !got.Equal(anonymizedAt) {
		t.Errorf("deleted 행의 deleted_at = %v, want anonymized_at %v", got, anonymizedAt)
	}
	if got := deletedAtOf(t, ctx, pool, accountB); got != nil {
		t.Errorf("active 행의 deleted_at = %v, want NULL", got)
	}
}

// deletedAtOf는 계정의 deleted_at을 읽습니다.
func deletedAtOf(t *testing.T, ctx context.Context, pool *pgxpool.Pool, id string) *time.Time {
	t.Helper()
	var deletedAt *time.Time
	if err := pool.QueryRow(ctx, `SELECT deleted_at FROM accounts WHERE id = $1`, id).Scan(&deletedAt); err != nil {
		t.Fatal(err)
	}
	return deletedAt
}

func TestSchema00015_AccountStatus(t *testing.T) {
	tests := []struct {
		name      string
		status    string
		deletedAt string // SQL 리터럴입니다.
		wantState string // 빈 문자열이면 성공해야 합니다.
	}{
		{"active 정상", "active", "NULL", ""},
		{"deleted 정상", "deleted", "now()", ""},
		{"active인데 deleted_at 있음", "active", "now()", checkViolation},
		{"deleted인데 deleted_at 없음", "deleted", "NULL", checkViolation},
		{"pending_deletion은 없어진 값", "pending_deletion", "NULL", checkViolation},
		{"알 수 없는 status", "banned", "NULL", checkViolation},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := dbtest.New(t)
			_, err := pool.Exec(context.Background(), `INSERT INTO accounts (id, status, deleted_at, last_active_at)
				VALUES ($1, $2, `+tt.deletedAt+`, now())`, accountA, tt.status)
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

// columnExists는 표에 열이 있는지 알려 줍니다.
func columnExists(t *testing.T, ctx context.Context, pool *pgxpool.Pool, table, column string) bool {
	t.Helper()
	var exists bool
	if err := pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM information_schema.columns
		WHERE table_name = $1 AND column_name = $2)`, table, column).Scan(&exists); err != nil {
		t.Fatal(err)
	}
	return exists
}

func TestSchema00015_DropsLegacyColumns(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	for _, c := range []struct{ table, column string }{
		{"accounts", "deletion_requested_at"},
		{"accounts", "anonymized_at"},
		{"auth_identities", "provider_disconnected_at"},
	} {
		if columnExists(t, ctx, pool, c.table, c.column) {
			t.Errorf("%s.%s가 남았습니다", c.table, c.column)
		}
	}
}

// 남은 삭제 대기 계정(staging)은 Up이 그 자리에서 지우고 deleted로 바꿉니다(spec §3.2).
func TestSchema00015_PendingAccountsDeleted(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := postgres.MigrateDownTo(ctx, pool, 14); err != nil {
		t.Fatal(err)
	}
	requestedAt := time.Date(2026, 10, 1, 9, 0, 0, 0, time.UTC)
	if _, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, deletion_requested_at, last_active_at)
		VALUES ($1, 'pending_deletion', $2, now())`, accountA, requestedAt); err != nil {
		t.Fatal(err)
	}
	if err := insertActive(ctx, pool, accountB); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{accountA, accountB} {
		seedPersonalData(t, ctx, pool, id)
	}

	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatal(err)
	}

	var status string
	var deletedAt *time.Time
	if err := pool.QueryRow(ctx, `SELECT status, deleted_at FROM accounts WHERE id = $1`, accountA).Scan(&status, &deletedAt); err != nil {
		t.Fatal(err)
	}
	if status != "deleted" || deletedAt == nil || !deletedAt.Equal(requestedAt) {
		t.Errorf("삭제 대기 계정 = (%s, %v), want (deleted, %v)", status, deletedAt, requestedAt)
	}
	for table, query := range personalDataCounts {
		if got := countRows(t, ctx, pool, query, accountA); got != 0 {
			t.Errorf("삭제 대기 계정의 %s = %d행, want 0", table, got)
		}
		if got := countRows(t, ctx, pool, query, accountB); got != 1 {
			t.Errorf("active 계정의 %s = %d행, want 1(그대로)", table, got)
		}
	}
	if got := countRows(t, ctx, pool, `SELECT count(*) FROM chart_cache WHERE birth_hash = $1`, birthHashOf(accountA)); got != 0 {
		t.Errorf("삭제 대기 계정의 차트 캐시 = %d행, want 0", got)
	}
	// 카카오 허가 취소는 계정 삭제와 같이 대기 행으로 남겨 재시도 job이 처리합니다.
	if got := countRows(t, ctx, pool, `SELECT count(*) FROM provider_revocations WHERE provider = 'kakao' AND subject = $1`,
		subjectOf(accountA)); got != 1 {
		t.Errorf("삭제 대기 계정의 허가 취소 대기 = %d행, want 1", got)
	}
	if got := countRows(t, ctx, pool, `SELECT count(*) FROM reaction_tallies`); got != 0 {
		t.Errorf("반응 집계 = %d행, want 0(staging 데이터라 더하지 않음)", got)
	}
}

// personalDataCounts는 seedPersonalData가 채운 표마다 계정의 행 수를 세는 쿼리입니다.
var personalDataCounts = map[string]string{ //nolint:gosec // 표 이름(refresh_tokens 등)이며 비밀 값이 아닙니다
	"profiles":         `SELECT count(*) FROM profiles WHERE account_id = $1`,
	"diaries":          `SELECT count(*) FROM diaries WHERE account_id = $1`,
	"diary_days":       `SELECT count(*) FROM diary_days WHERE account_id = $1`,
	"schedules":        `SELECT count(*) FROM schedules WHERE account_id = $1`,
	"daily_selections": `SELECT count(*) FROM daily_selections WHERE account_id = $1`,
	"reactions": `SELECT count(*) FROM reactions r JOIN daily_selections s ON s.id = r.selection_id
		WHERE s.account_id = $1`,
	"rotation_state":   `SELECT count(*) FROM rotation_state WHERE account_id = $1`,
	"consents":         `SELECT count(*) FROM consents WHERE account_id = $1`,
	"auth_identities":  `SELECT count(*) FROM auth_identities WHERE account_id = $1`,
	"refresh_tokens":   `SELECT count(*) FROM refresh_tokens WHERE account_id = $1`,
	"idempotency_keys": `SELECT count(*) FROM idempotency_keys WHERE account_id = $1`,
}

// birthHashOf·subjectOf는 계정 id에서 겹치지 않는 출생 해시와 카카오 subject를 만듭니다.
func birthHashOf(id string) []byte {
	return []byte(fmt.Sprintf("%032s", id[len(id)-12:]))
}

func subjectOf(id string) string {
	return "kakao-" + id[len(id)-12:]
}

// seedPersonalData는 00014 스키마에서 계정의 개인 데이터 표마다 한 행씩 채웁니다.
func seedPersonalData(t *testing.T, ctx context.Context, pool *pgxpool.Pool, id string) {
	t.Helper()
	hash := birthHashOf(id)
	exec := func(sql string, args ...any) {
		t.Helper()
		if _, err := pool.Exec(ctx, sql, args...); err != nil {
			t.Fatalf("%s: %v", sql, err)
		}
	}
	exec(`INSERT INTO content_seeds (version, slots) VALUES ('seed-v1', '{}') ON CONFLICT DO NOTHING`)
	exec(`INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
			birth_year, birth_month, birth_day, birth_time_status, gender, birth_timezone, birth_place_status,
			notify_status, birth_hash)
		VALUES ($1, '벗', 'ko', 'Asia/Seoul', 'solar', false, 1990, 3, 14, 'unknown', 'female', 'Asia/Seoul',
			'not_asked', 'not_asked', $2)`, id, hash)
	exec(`INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
		VALUES ($1, '2026-10-12', '{}', '[]', 'r1')`, id)
	exec(`INSERT INTO diaries (id, account_id, date, body) VALUES (gen_random_uuid(), $1, '2026-10-12', '일기')`, id)
	exec(`INSERT INTO schedules (id, account_id, date, all_day, title) VALUES (gen_random_uuid(), $1, '2026-10-21', true, '회의')`, id)
	var selectionID int64
	if err := pool.QueryRow(ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-12', 'overall', $2, 'msg.a', 'v1', 'seed-v1') RETURNING id`, id, hash).Scan(&selectionID); err != nil {
		t.Fatal(err)
	}
	exec(`INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')`, selectionID)
	exec(`INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, 'msg.a', 'v2')`, id)
	exec(`INSERT INTO consents (id, account_id, document, version, agreed_at) VALUES (gen_random_uuid(), $1, 'terms', '1', now())`, id)
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES (gen_random_uuid(), $1, 'kakao', $2)`, id, subjectOf(id))
	exec(`INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at)
		VALUES (gen_random_uuid(), $1, $2, gen_random_uuid(), now() + interval '1 hour')`, id, hash)
	exec(`INSERT INTO idempotency_keys (account_id, key, request_hash, created_at) VALUES ($1, 'k1', $2, now())`, id, hash)
	exec(`INSERT INTO chart_cache (birth_hash, ruleset_version, as_of_year, response) VALUES ($1, 'r1', 2026, '\x00')`, hash)
}

// countRows는 SELECT count(*) 쿼리의 결과를 돌려줍니다.
func countRows(t *testing.T, ctx context.Context, pool *pgxpool.Pool, query string, args ...any) int {
	t.Helper()
	var n int
	if err := pool.QueryRow(ctx, query, args...).Scan(&n); err != nil {
		t.Fatalf("%s: %v", query, err)
	}
	return n
}

func TestSchema00015_DownRestores(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	deletedAt := time.Date(2026, 10, 20, 9, 0, 0, 0, time.UTC)
	if _, err := pool.Exec(ctx, `INSERT INTO accounts (id, status, deleted_at, last_active_at)
		VALUES ($1, 'deleted', $2, now())`, accountA, deletedAt); err != nil {
		t.Fatal(err)
	}
	if err := postgres.MigrateDownTo(ctx, pool, 14); err != nil {
		t.Fatal(err)
	}

	for _, table := range []string{"provider_revocations", "reaction_tallies"} {
		var exists bool
		if err := pool.QueryRow(ctx, `SELECT to_regclass($1) IS NOT NULL`, table).Scan(&exists); err != nil {
			t.Fatal(err)
		}
		if exists {
			t.Errorf("%s가 남았습니다", table)
		}
	}
	if columnExists(t, ctx, pool, "accounts", "deleted_at") {
		t.Error("accounts.deleted_at이 남았습니다")
	}
	for _, c := range []struct{ table, column string }{
		{"accounts", "deletion_requested_at"},
		{"accounts", "anonymized_at"},
		{"auth_identities", "provider_disconnected_at"},
	} {
		if !columnExists(t, ctx, pool, c.table, c.column) {
			t.Errorf("%s.%s가 되돌아오지 않았습니다", c.table, c.column)
		}
	}

	// 지운 계정은 deleted로 남고, 옛 CHECK를 만족하도록 옛 두 시각을 deleted_at으로 채웁니다.
	var status string
	var requestedAt, anonymizedAt *time.Time
	if err := pool.QueryRow(ctx, `SELECT status, deletion_requested_at, anonymized_at FROM accounts WHERE id = $1`,
		accountA).Scan(&status, &requestedAt, &anonymizedAt); err != nil {
		t.Fatal(err)
	}
	if status != "deleted" || requestedAt == nil || !requestedAt.Equal(deletedAt) || anonymizedAt == nil || !anonymizedAt.Equal(deletedAt) {
		t.Errorf("Down 뒤 지운 계정 = (%s, %v, %v), want (deleted, %v, %v)", status, requestedAt, anonymizedAt, deletedAt, deletedAt)
	}
	// 옛 status 값과 옛 CHECK가 되돌아옵니다.
	if err := insertLegacyAccount(ctx, pool, accountB, "pending_deletion", true, false); err != nil {
		t.Errorf("Down 뒤 pending_deletion INSERT: %v", err)
	}
	wantSQLState(t, insertLegacyAccount(ctx, pool, "00000000-0000-7000-8000-000000000003", "deleted", true, false), checkViolation)
}

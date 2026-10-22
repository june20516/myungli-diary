package postgres_test

import (
	"context"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const insertRevocation = `INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at)
	VALUES ($1, $2, gen_random_uuid(), $3, $4, $5, now())`

func TestSchema00015_ProviderRevocationsHasNoFK(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := insertAccount(ctx, pool, accountA, "active", false, false); err != nil {
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
	if err := insertAccount(ctx, pool, accountA, "deleted", true, true); err != nil {
		t.Fatal(err)
	}
	if err := insertAccount(ctx, pool, accountB, "active", false, false); err != nil {
		t.Fatal(err)
	}
	// 두 시각이 달라야 coalesce 우선순위(anonymized_at 먼저)를 구분할 수 있습니다.
	if _, err := pool.Exec(ctx, `UPDATE accounts SET deletion_requested_at = now() - interval '2 days',
		anonymized_at = now() - interval '1 day' WHERE id = $1`, accountA); err != nil {
		t.Fatal(err)
	}
	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatal(err)
	}

	var deletedAtSet, matchesAnonymized, differsFromRequested bool
	if err := pool.QueryRow(ctx, `SELECT deleted_at IS NOT NULL, deleted_at = anonymized_at, deleted_at <> deletion_requested_at
		FROM accounts WHERE id = $1`, accountA).Scan(&deletedAtSet, &matchesAnonymized, &differsFromRequested); err != nil {
		t.Fatal(err)
	}
	if !deletedAtSet || !matchesAnonymized || !differsFromRequested {
		t.Errorf("deleted_at 채움 = %v, anonymized_at과 같음 = %v, deletion_requested_at과 다름 = %v, want 모두 true",
			deletedAtSet, matchesAnonymized, differsFromRequested)
	}
	if err := pool.QueryRow(ctx, `SELECT deleted_at IS NOT NULL FROM accounts WHERE id = $1`, accountB).Scan(&deletedAtSet); err != nil {
		t.Fatal(err)
	}
	if deletedAtSet {
		t.Error("active 행의 deleted_at이 채워졌습니다")
	}
}

func TestSchema00015_DownRestores(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
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
	var column bool
	if err := pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM information_schema.columns
		WHERE table_name = 'accounts' AND column_name = 'deleted_at')`).Scan(&column); err != nil {
		t.Fatal(err)
	}
	if column {
		t.Error("accounts.deleted_at이 남았습니다")
	}
}

package db_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

func newAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
	return id
}

// insertIdentity는 연결 행을 넣고 id와 오류를 돌려줍니다. withApple이면 Apple 토큰 열을 채웁니다.
func insertIdentity(pool *pgxpool.Pool, accountID uuid.UUID, provider, subject string, withApple bool) (uuid.UUID, error) {
	id := uuid.Must(uuid.NewV7())
	var token, keyID, clientID any
	if withApple {
		token, keyID, clientID = []byte{1}, "b1", "client"
	}
	_, err := pool.Exec(context.Background(),
		`INSERT INTO auth_identities (id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`, id, accountID, provider, subject, token, keyID, clientID)
	return id, err
}

func constraintName(t *testing.T, err error) string {
	t.Helper()
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr)
	return pgErr.ConstraintName
}

func TestMigration00014_IdentitiesMulti(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	account := newAccount(t, pool)

	lineID, err := insertIdentity(pool, account, "line", "line-1", false)
	require.NoError(t, err, "line 연결을 허용합니다")
	_, err = insertIdentity(pool, account, "google", "google-1", false)
	require.NoError(t, err, "google 연결을 허용합니다")

	other := newAccount(t, pool)
	_, err = insertIdentity(pool, other, "line", "line-2", true)
	assert.Equal(t, "auth_identities_line_google_without_apple", constraintName(t, err), "line 연결에는 Apple 토큰이 없습니다")
	_, err = insertIdentity(pool, other, "google", "google-2", true)
	assert.Equal(t, "auth_identities_line_google_without_apple", constraintName(t, err), "google 연결에도 Apple 토큰이 없습니다")

	_, err = insertIdentity(pool, account, "kakao", "kakao-1", false)
	require.NoError(t, err)
	_, err = insertIdentity(pool, account, "kakao", "kakao-2", false)
	assert.Equal(t, "auth_identities_account_provider_key", constraintName(t, err), "한 계정에 같은 제공자 연결은 하나입니다")

	// 합치기 토큰은 붙이려던 연결이 지워지면 함께 사라집니다.
	_, err = pool.Exec(ctx,
		`INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
		 VALUES (gen_random_uuid(), '\x01', $1, $2, $3, now() + interval '10 minutes')`, account, other, lineID)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, `DELETE FROM auth_identities WHERE id = $1`, lineID)
	require.NoError(t, err)
	var tickets int
	require.NoError(t, pool.QueryRow(ctx, `SELECT count(*) FROM account_merge_tickets`).Scan(&tickets))
	assert.Zero(t, tickets)

	// 계정 행은 합치기 토큰이 남아 있으면 지울 수 없습니다(RESTRICT).
	keepID, err := insertIdentity(pool, account, "line", "line-3", false)
	require.NoError(t, err)
	_, err = pool.Exec(ctx,
		`INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
		 VALUES (gen_random_uuid(), '\x02', $1, $2, $3, now() + interval '10 minutes')`, account, other, keepID)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1`, other)
	require.Error(t, err)
}

func TestMigration00014_DownRestoresPreviousShape(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	account := newAccount(t, pool)
	_, err := insertIdentity(pool, account, "kakao", "kakao-1", false)
	require.NoError(t, err)

	require.NoError(t, postgres.Migrate(ctx, pool, "down")) // 00014만 내립니다.

	var exists bool
	require.NoError(t, pool.QueryRow(ctx, `SELECT to_regclass('account_merge_tickets') IS NOT NULL`).Scan(&exists))
	assert.False(t, exists, "합치기 토큰 표가 사라집니다")
	_, err = insertIdentity(pool, account, "line", "line-1", false)
	assert.Equal(t, "auth_identities_provider_check", constraintName(t, err), "line은 다시 거절됩니다")
	_, err = insertIdentity(pool, account, "kakao", "kakao-2", false)
	assert.NoError(t, err, "계정당 제공자 하나 제약이 사라집니다")

	// 다시 올리려면 UNIQUE에 걸리는 행을 먼저 정리해야 합니다.
	_, err = pool.Exec(ctx, `DELETE FROM auth_identities WHERE subject = 'kakao-2'`)
	require.NoError(t, err)
	require.NoError(t, postgres.Migrate(ctx, pool, "up"))
}

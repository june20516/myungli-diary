package diary_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// insertOldDiary는 00013 이전 모양(태그 열이 diaries에 있음)으로 일기 행을 직접 넣습니다.
func insertOldDiary(t *testing.T, pool *pgxpool.Pool, account uuid.UUID, date, createdAt string, deleted bool, tags []string, ruleset string) {
	t.Helper()
	deletedAt := "NULL"
	if deleted {
		deletedAt = "'" + createdAt + "'"
	}
	_, err := pool.Exec(context.Background(),
		`INSERT INTO diaries (id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version, created_at, deleted_at)
		 VALUES (gen_random_uuid(), $1, $2::date, $3, $4, '[]'::jsonb, NULL, $5, $6::timestamptz, `+deletedAt+`)`,
		account, date, "본문 "+tags[0], tags, ruleset, createdAt)
	require.NoError(t, err)
}

func TestMigration00013_SplitsDayRecords(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	require.NoError(t, postgres.Migrate(ctx, pool, "down")) // 00013만 내립니다.
	account := newAccount(t, pool)

	insertOldDiary(t, pool, account, "2026-10-12", "2026-10-12T09:00:00Z", false, []string{"a"}, "r2")
	insertOldDiary(t, pool, account, "2026-10-12", "2026-10-12T08:00:00Z", true, []string{"old"}, "r1")
	insertOldDiary(t, pool, account, "2026-10-13", "2026-10-13T08:00:00Z", true, []string{"first"}, "r1")
	insertOldDiary(t, pool, account, "2026-10-13", "2026-10-13T09:00:00Z", true, []string{"second"}, "r2")

	require.NoError(t, postgres.Migrate(ctx, pool, "up"))

	rows, err := pool.Query(ctx,
		`SELECT date::text, all_tags, ruleset_version FROM diary_days WHERE account_id = $1 ORDER BY date`, account)
	require.NoError(t, err)
	defer rows.Close()
	type dayRow struct {
		Date    string
		Tags    []string
		Ruleset string
	}
	var got []dayRow
	for rows.Next() {
		var r dayRow
		require.NoError(t, rows.Scan(&r.Date, &r.Tags, &r.Ruleset))
		got = append(got, r)
	}
	require.NoError(t, rows.Err())
	assert.Equal(t, []dayRow{
		{"2026-10-12", []string{"a"}, "r2"},     // 살아 있는 행 우선
		{"2026-10-13", []string{"first"}, "r1"}, // 지운 행만 있으면 가장 먼저 만든 행
	}, got)

	var total, deleted int
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT count(*), count(deleted_at) FROM diaries WHERE account_id = $1`, account).Scan(&total, &deleted))
	assert.Equal(t, 4, total)
	assert.Equal(t, 3, deleted)

	var bodies int
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT count(*) FROM diaries WHERE account_id = $1 AND body LIKE '본문 %'`, account).Scan(&bodies))
	assert.Equal(t, 4, bodies)
}

func TestMigration00013_DownRestoresColumns(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	account := newAccount(t, pool)

	_, err := pool.Exec(ctx,
		`INSERT INTO diary_days (account_id, date, all_tags, featured_tags, guide_question, ruleset_version)
		 VALUES ($1, '2026-10-12', '{x,y}', '[{"key":"x","polarity":"good"}]', '[{"text":"질문"}]', 'r3')`, account)
	require.NoError(t, err)
	_, err = pool.Exec(ctx,
		`INSERT INTO diaries (id, account_id, date, body) VALUES (gen_random_uuid(), $1, '2026-10-12', '본문')`, account)
	require.NoError(t, err)

	require.NoError(t, postgres.Migrate(ctx, pool, "down"))

	var (
		tags     []string
		featured string
		guide    string
		ruleset  string
	)
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT all_tags, featured_tags::text, guide_question::text, ruleset_version FROM diaries WHERE account_id = $1`, account).
		Scan(&tags, &featured, &guide, &ruleset))
	assert.Equal(t, []string{"x", "y"}, tags)
	assert.JSONEq(t, `[{"key":"x","polarity":"good"}]`, featured)
	assert.JSONEq(t, `[{"text":"질문"}]`, guide)
	assert.Equal(t, "r3", ruleset)

	var exists bool
	require.NoError(t, pool.QueryRow(ctx, `SELECT to_regclass('diary_days') IS NOT NULL`).Scan(&exists))
	assert.False(t, exists)
}

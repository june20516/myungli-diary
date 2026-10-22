package diary_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

func mustTime(t *testing.T, value string) time.Time {
	t.Helper()
	parsed, err := time.Parse(time.RFC3339, value)
	require.NoError(t, err)
	return parsed
}

// insertOldDiary는 00013 이전 모양(태그 열이 diaries에 있음)으로 일기 행을 직접 넣습니다.
// 지운 행이면 deleted_at을 created_at과 같은 시각으로 채웁니다.
func insertOldDiary(t *testing.T, pool *pgxpool.Pool, account uuid.UUID, date, createdAt string, deleted bool, tags []string, ruleset string) {
	t.Helper()
	var deletedAt *time.Time
	if deleted {
		value := mustTime(t, createdAt)
		deletedAt = &value
	}
	_, err := pool.Exec(context.Background(),
		`INSERT INTO diaries (id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version, created_at, deleted_at)
		 VALUES (gen_random_uuid(), $1, $2::date, $3, $4, '[]'::jsonb, NULL, $5, $6::timestamptz, $7::timestamptz)`,
		account, date, "본문 "+tags[0], tags, ruleset, createdAt, deletedAt)
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

	type dayRow struct {
		Date      string
		Tags      []string
		Ruleset   string
		CreatedAt time.Time
	}
	rows, err := pool.Query(ctx,
		`SELECT date::text, all_tags, ruleset_version, created_at FROM diary_days WHERE account_id = $1 ORDER BY date`, account)
	require.NoError(t, err)
	defer rows.Close()
	var gotDays []dayRow
	for rows.Next() {
		var r dayRow
		require.NoError(t, rows.Scan(&r.Date, &r.Tags, &r.Ruleset, &r.CreatedAt))
		gotDays = append(gotDays, r)
	}
	require.NoError(t, rows.Err())
	require.Len(t, gotDays, 2)
	// 살아 있는 행 우선 / 지운 행만 있으면 가장 먼저 만든 행. created_at은 고른 행의 값입니다.
	assert.Equal(t, "2026-10-12", gotDays[0].Date)
	assert.Equal(t, []string{"a"}, gotDays[0].Tags)
	assert.Equal(t, "r2", gotDays[0].Ruleset)
	assert.True(t, mustTime(t, "2026-10-12T09:00:00Z").Equal(gotDays[0].CreatedAt), gotDays[0].CreatedAt)
	assert.Equal(t, "2026-10-13", gotDays[1].Date)
	assert.Equal(t, []string{"first"}, gotDays[1].Tags)
	assert.Equal(t, "r1", gotDays[1].Ruleset)
	assert.True(t, mustTime(t, "2026-10-13T08:00:00Z").Equal(gotDays[1].CreatedAt), gotDays[1].CreatedAt)

	type diaryRow struct {
		Date    string
		Body    string
		Deleted bool
	}
	diaryRows, err := pool.Query(ctx,
		`SELECT date::text, body, deleted_at IS NOT NULL FROM diaries WHERE account_id = $1 ORDER BY date, created_at`, account)
	require.NoError(t, err)
	defer diaryRows.Close()
	var gotDiaries []diaryRow
	for diaryRows.Next() {
		var r diaryRow
		require.NoError(t, diaryRows.Scan(&r.Date, &r.Body, &r.Deleted))
		gotDiaries = append(gotDiaries, r)
	}
	require.NoError(t, diaryRows.Err())
	assert.Equal(t, []diaryRow{
		{"2026-10-12", "본문 old", true},
		{"2026-10-12", "본문 a", false},
		{"2026-10-13", "본문 first", true},
		{"2026-10-13", "본문 second", true},
	}, gotDiaries)
}

func TestMigration00013_DownRestoresColumns(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	account := newAccount(t, pool)

	_, err := pool.Exec(ctx,
		`INSERT INTO diary_days (account_id, date, all_tags, featured_tags, guide_question, ruleset_version)
		 VALUES ($1, '2026-10-12', '{x,y}', '[{"key":"x","polarity":"good"}]', '[{"text":"질문"}]', 'r3')`, account)
	require.NoError(t, err)
	updatedAt := mustTime(t, "2026-10-14T01:02:03Z")
	// 살아 있는 행 하나와 지운 행 하나. 둘 다 수정 시각을 정해 둡니다.
	_, err = pool.Exec(ctx,
		`INSERT INTO diaries (id, account_id, date, body, updated_at, deleted_at) VALUES
		 (gen_random_uuid(), $1, '2026-10-12', '살아 있음', $2, NULL),
		 (gen_random_uuid(), $1, '2026-10-12', '지움', $2, $2)`, account, updatedAt)
	require.NoError(t, err)

	require.NoError(t, postgres.Migrate(ctx, pool, "down"))

	rows, err := pool.Query(ctx,
		`SELECT body, all_tags, featured_tags::text, guide_question::text, ruleset_version, updated_at
		 FROM diaries WHERE account_id = $1 ORDER BY body`, account)
	require.NoError(t, err)
	defer rows.Close()
	count := 0
	for rows.Next() {
		var (
			body, featured, guide, ruleset string
			tags                           []string
			gotUpdatedAt                   time.Time
		)
		require.NoError(t, rows.Scan(&body, &tags, &featured, &guide, &ruleset, &gotUpdatedAt))
		assert.Equal(t, []string{"x", "y"}, tags, body)
		assert.JSONEq(t, `[{"key":"x","polarity":"good"}]`, featured, body)
		assert.JSONEq(t, `[{"text":"질문"}]`, guide, body)
		assert.Equal(t, "r3", ruleset, body)
		assert.True(t, updatedAt.Equal(gotUpdatedAt), "%s: updated_at = %v, want %v", body, gotUpdatedAt, updatedAt)
		count++
	}
	require.NoError(t, rows.Err())
	assert.Equal(t, 2, count)

	var exists bool
	require.NoError(t, pool.QueryRow(ctx, `SELECT to_regclass('diary_days') IS NOT NULL`).Scan(&exists))
	assert.False(t, exists)

	var indexes int
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT count(*) FROM pg_indexes WHERE tablename = 'diaries' AND indexname IN ('diaries_one_per_day', 'diaries_all_tags')`).Scan(&indexes))
	assert.Equal(t, 2, indexes)

	nullable := map[string]string{}
	columnRows, err := pool.Query(ctx,
		`SELECT column_name, is_nullable FROM information_schema.columns
		 WHERE table_name = 'diaries' AND column_name IN ('all_tags', 'featured_tags', 'ruleset_version', 'guide_question')`)
	require.NoError(t, err)
	defer columnRows.Close()
	for columnRows.Next() {
		var name, isNullable string
		require.NoError(t, columnRows.Scan(&name, &isNullable))
		nullable[name] = isNullable
	}
	require.NoError(t, columnRows.Err())
	assert.Equal(t, map[string]string{
		"all_tags": "NO", "featured_tags": "NO", "ruleset_version": "NO", "guide_question": "YES",
	}, nullable)
}

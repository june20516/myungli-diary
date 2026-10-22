package diary_test

import (
	"context"
	"math"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

func newAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
	return id
}

func day(d int) profile.LocalDate { return profile.LocalDate{Year: 2026, Month: 10, Day: d} }

// record는 tags를 AllTags로 가진 날짜 기록입니다. 대표 태그와 가이드 질문은 고정 값입니다.
func record(tags ...string) *fortune.DayRecord {
	return &fortune.DayRecord{
		AllTags:        tags,
		Featured:       []fortune.FeaturedTag{{Key: "dohwa", Polarity: fortune.Polarity("neutral")}},
		GuideQuestion:  []render.Segment{{Text: "오늘은 "}, {Text: "비견", Term: "term.ten_god.bigyeon"}, {Text: "을 느꼈나요?"}},
		RulesetVersion: "r1",
	}
}

func setup(t *testing.T) (*diary.Store, uuid.UUID, *pgxpool.Pool) {
	t.Helper()
	pool := dbtest.New(t)
	return diary.NewStore(pool), newAccount(t, pool), pool
}

// mustCreate는 date에 일기를 한 편 만듭니다. 그날 첫 편이면 record를 적습니다.
func mustCreate(t *testing.T, store *diary.Store, acc uuid.UUID, d int, body string, rec *fortune.DayRecord) diary.Entry {
	t.Helper()
	e, err := store.CreateEntry(context.Background(), acc, day(d), body, rec)
	require.NoError(t, err)
	return e
}

func countLive(t *testing.T, pool *pgxpool.Pool, acc uuid.UUID, d int) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(context.Background(),
		"SELECT count(*) FROM diaries WHERE account_id = $1 AND date = $2 AND deleted_at IS NULL", acc, profile.PgDate(day(d))).Scan(&n))
	return n
}

func TestStore_CreateFirstEntryWritesDayRecord(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	exists, err := store.DayExists(ctx, acc, day(10))
	require.NoError(t, err)
	assert.False(t, exists)

	rec := record("dohwa", "a")
	got := mustCreate(t, store, acc, 10, "처음", rec)

	assert.NotEqual(t, uuid.Nil, got.ID)
	assert.Equal(t, day(10), got.Date)
	assert.Equal(t, "처음", got.Body)
	assert.Equal(t, rec.AllTags, got.AllTags)
	assert.Equal(t, rec.Featured, got.Featured)
	assert.Equal(t, rec.GuideQuestion, got.GuideQuestion)
	assert.Equal(t, "r1", got.RulesetVersion)
	exists, err = store.DayExists(ctx, acc, day(10))
	require.NoError(t, err)
	assert.True(t, exists)

	saved, err := store.Get(ctx, acc, got.ID)
	require.NoError(t, err)
	assert.Equal(t, got, saved)
}

func TestStore_CreateWithoutGuideQuestion(t *testing.T) {
	store, acc, _ := setup(t)
	got := mustCreate(t, store, acc, 10, "본문", &fortune.DayRecord{RulesetVersion: "r1"})
	assert.Empty(t, got.GuideQuestion)
	assert.Empty(t, got.AllTags)
	assert.Empty(t, got.Featured)
}

func TestStore_SecondEntryReusesDayRecord(t *testing.T) {
	store, acc, _ := setup(t)
	first := mustCreate(t, store, acc, 10, "첫째", record("a"))
	second := mustCreate(t, store, acc, 10, "둘째", nil)

	assert.NotEqual(t, first.ID, second.ID)
	assert.Equal(t, []string{"a"}, second.AllTags)
	assert.Equal(t, first.GuideQuestion, second.GuideQuestion)
}

func TestStore_SecondRecordIsIgnored(t *testing.T) {
	store, acc, _ := setup(t)
	mustCreate(t, store, acc, 10, "첫째", record("a"))
	second := mustCreate(t, store, acc, 10, "둘째", record("b"))
	assert.Equal(t, []string{"a"}, second.AllTags, "먼저 넣은 기록이 남음")
}

func TestStore_CreateWithoutRecordWhenDayMissing(t *testing.T) {
	store, acc, pool := setup(t)
	_, err := store.CreateEntry(context.Background(), acc, day(10), "본문", nil)
	assert.ErrorIs(t, err, diary.ErrDayRecordMissing)
	assert.Equal(t, 0, countLive(t, pool, acc, 10))
}

func TestStore_ConcurrentCreatesStopAtTen(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)

	const workers = 12
	var wg sync.WaitGroup
	errs := make([]error, workers)
	for i := range errs {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, errs[i] = store.CreateEntry(ctx, acc, day(10), "본문", record("a"))
		}()
	}
	wg.Wait()

	succeeded, full := 0, 0
	for _, err := range errs {
		switch {
		case err == nil:
			succeeded++
		case assert.ErrorIs(t, err, diary.ErrDayFull):
			full++
		}
	}
	assert.Equal(t, diary.MaxEntriesPerDay, succeeded)
	assert.Equal(t, workers-diary.MaxEntriesPerDay, full)
	assert.Equal(t, diary.MaxEntriesPerDay, countLive(t, pool, acc, 10))
	var days int
	require.NoError(t, pool.QueryRow(ctx, "SELECT count(*) FROM diary_days WHERE account_id = $1", acc).Scan(&days))
	assert.Equal(t, 1, days)
}

// fillDay는 date에 n편을 만들고 id를 돌려줍니다.
func fillDay(t *testing.T, store *diary.Store, acc uuid.UUID, d, n int) []uuid.UUID {
	t.Helper()
	ids := make([]uuid.UUID, n)
	for i := range ids {
		var rec *fortune.DayRecord
		if i == 0 {
			rec = record("a")
		}
		ids[i] = mustCreate(t, store, acc, d, "본문", rec).ID
	}
	return ids
}

func TestStore_DeletedEntriesDoNotCount(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	ids := fillDay(t, store, acc, 10, diary.MaxEntriesPerDay)
	_, err := store.CreateEntry(ctx, acc, day(10), "열한째", nil)
	require.ErrorIs(t, err, diary.ErrDayFull)

	require.NoError(t, store.Delete(ctx, acc, ids[0]))
	_, err = store.CreateEntry(ctx, acc, day(10), "열한째", nil)
	assert.NoError(t, err)
}

func TestStore_RestoreRespectsLimit(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	ids := fillDay(t, store, acc, 10, diary.MaxEntriesPerDay)
	require.NoError(t, store.Delete(ctx, acc, ids[0]))
	extra := mustCreate(t, store, acc, 10, "대신", nil)

	_, err := store.Restore(ctx, acc, ids[0])
	assert.ErrorIs(t, err, diary.ErrDayFull, "살아 있는 10편")

	require.NoError(t, store.Delete(ctx, acc, extra.ID))
	restored, err := store.Restore(ctx, acc, ids[0])
	require.NoError(t, err)
	assert.Equal(t, ids[0], restored.ID)
	_, err = store.Get(ctx, acc, ids[0])
	assert.NoError(t, err)
}

func TestStore_RestoreLiveEntryIsNoop(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	ids := fillDay(t, store, acc, 10, diary.MaxEntriesPerDay)
	before, err := store.Get(ctx, acc, ids[3])
	require.NoError(t, err)

	got, err := store.Restore(ctx, acc, ids[3])
	require.NoError(t, err, "10편이어도 이미 살아 있으면 상한을 보지 않음")
	assert.Equal(t, before, got)
}

func TestStore_RestorePurgedIsNotFound(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	e := mustCreate(t, store, acc, 10, "비워질 것", record("a"))
	require.NoError(t, store.Delete(ctx, acc, e.ID))
	// P8의 내용 비우기가 content_purged_at을 찍은 상태를 SQL로 만듭니다.
	_, err := pool.Exec(ctx, "UPDATE diaries SET content_purged_at = now() WHERE account_id = $1", acc)
	require.NoError(t, err)

	_, err = store.Restore(ctx, acc, e.ID)
	assert.ErrorIs(t, err, diary.ErrNotFound)
}

func TestStore_DeleteThenGetIsNotFound(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	e := mustCreate(t, store, acc, 10, "본문", record("a"))

	require.NoError(t, store.Delete(ctx, acc, e.ID))
	_, err := store.Get(ctx, acc, e.ID)
	assert.ErrorIs(t, err, diary.ErrNotFound)
	assert.ErrorIs(t, store.Delete(ctx, acc, e.ID), diary.ErrNotFound)
	_, err = store.UpdateBody(ctx, acc, e.ID, "지운 뒤")
	assert.ErrorIs(t, err, diary.ErrNotFound)
}

func TestStore_OtherAccountIsNotFound(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	other := newAccount(t, pool)
	mine := mustCreate(t, store, acc, 10, "내 일기", record("x"))

	_, err := store.Get(ctx, other, mine.ID)
	assert.ErrorIs(t, err, diary.ErrNotFound)
	_, err = store.UpdateBody(ctx, other, mine.ID, "가로챔")
	assert.ErrorIs(t, err, diary.ErrNotFound)
	assert.ErrorIs(t, store.Delete(ctx, other, mine.ID), diary.ErrNotFound)

	require.NoError(t, store.Delete(ctx, acc, mine.ID))
	_, err = store.Restore(ctx, other, mine.ID)
	assert.ErrorIs(t, err, diary.ErrNotFound)

	list, err := store.List(ctx, other, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	assert.Empty(t, list)

	// 같은 날짜를 다른 계정이 따로 쓸 수 있습니다.
	exists, err := store.DayExists(ctx, other, day(10))
	require.NoError(t, err)
	assert.False(t, exists)
	mustCreate(t, store, other, 10, "남의 일기", record("y"))
}

func TestStore_UpdateBodyKeepsDayRecord(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	first := mustCreate(t, store, acc, 10, "처음", record("dohwa", "a"))

	got, err := store.UpdateBody(ctx, acc, first.ID, "고침")
	require.NoError(t, err)
	assert.Equal(t, "고침", got.Body)
	assert.Equal(t, first.AllTags, got.AllTags)
	assert.Equal(t, first.Featured, got.Featured)
	assert.Equal(t, first.GuideQuestion, got.GuideQuestion)
	assert.Equal(t, "r1", got.RulesetVersion)
	assert.True(t, first.CreatedAt.Equal(got.CreatedAt))
	assert.True(t, got.UpdatedAt.After(first.UpdatedAt))

	saved, err := store.Get(ctx, acc, first.ID)
	require.NoError(t, err)
	assert.Equal(t, got, saved)
}

func TestStore_UpdateBodyMissingIsNotFound(t *testing.T) {
	store, acc, _ := setup(t)
	_, err := store.UpdateBody(context.Background(), acc, uuid.New(), "없음")
	assert.ErrorIs(t, err, diary.ErrNotFound)
}

func dates(entries []diary.Entry) []int {
	out := make([]int, len(entries))
	for i, e := range entries {
		out[i] = e.Date.Day
	}
	return out
}

func ids(entries []diary.Entry) []uuid.UUID {
	out := make([]uuid.UUID, len(entries))
	for i, e := range entries {
		out[i] = e.ID
	}
	return out
}

func cursorOf(e diary.Entry) *diary.Cursor {
	return &diary.Cursor{Date: e.Date, CreatedAt: e.CreatedAt, ID: e.ID}
}

// seedTwoDays는 10-12에 3편, 10-13에 2편을 만들고 작성 순 id를 돌려줍니다.
func seedTwoDays(t *testing.T, store *diary.Store, acc uuid.UUID) (d12, d13 []uuid.UUID) {
	t.Helper()
	d12 = fillDay(t, store, acc, 12, 3)
	d13 = fillDay(t, store, acc, 13, 2)
	return d12, d13
}

func TestStore_ListOrder(t *testing.T) {
	store, acc, _ := setup(t)
	d12, d13 := seedTwoDays(t, store, acc)

	got, err := store.List(context.Background(), acc, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, append(append([]uuid.UUID{}, d13...), d12...), ids(got), "최근 날짜부터, 같은 날은 작성 순")
}

func TestStore_ListCursorSplitsDay(t *testing.T) {
	store, acc, _ := setup(t)
	d12, d13 := seedTwoDays(t, store, acc)
	want := append(append([]uuid.UUID{}, d13...), d12...)

	var seen []uuid.UUID
	var after *diary.Cursor
	for range 5 {
		page, err := store.List(context.Background(), acc, diary.ListQuery{After: after, Limit: 2})
		require.NoError(t, err)
		if len(page) == 0 {
			break
		}
		seen = append(seen, ids(page)...)
		after = cursorOf(page[len(page)-1])
	}
	assert.Equal(t, want, seen, "5편이 중복·빠짐 없이 날짜 중간에서도 이어짐")
}

func TestStore_ListCursorSameCreatedAt(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	fillDay(t, store, acc, 12, 2)
	_, err := pool.Exec(ctx, "UPDATE diaries SET created_at = '2026-10-12T00:00:00Z' WHERE account_id = $1", acc)
	require.NoError(t, err)

	all, err := store.List(ctx, acc, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	require.Len(t, all, 2)
	assert.Less(t, all[0].ID.String(), all[1].ID.String(), "created_at이 같으면 id 순")

	first, err := store.List(ctx, acc, diary.ListQuery{Limit: 1})
	require.NoError(t, err)
	second, err := store.List(ctx, acc, diary.ListQuery{After: cursorOf(first[0]), Limit: 1})
	require.NoError(t, err)
	assert.Equal(t, ids(all), append(ids(first), ids(second)...))
}

func TestStore_ListTagFilter(t *testing.T) {
	store, acc, _ := setup(t)
	mustCreate(t, store, acc, 1, "a", record("x"))
	mustCreate(t, store, acc, 2, "b", record("y"))
	mustCreate(t, store, acc, 2, "c", nil)
	mustCreate(t, store, acc, 3, "d", record("x", "y"))

	tag := "y"
	got, err := store.List(context.Background(), acc, diary.ListQuery{Tag: &tag, Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, []int{3, 2, 2}, dates(got), "y 날짜의 일기만, 같은 날 둘 다")
}

func TestStore_ListRangeAndDeleted(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	for d := 1; d <= 5; d++ {
		mustCreate(t, store, acc, d, "본문", record("x"))
	}
	gone := mustCreate(t, store, acc, 3, "지울 것", nil)
	require.NoError(t, store.Delete(ctx, acc, gone.ID))

	from, to := day(2), day(4)
	got, err := store.List(ctx, acc, diary.ListQuery{From: &from, To: &to, Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, []int{4, 3, 2}, dates(got), "범위는 양 끝 포함, 지운 일기는 빠짐")
}

func TestStore_ListRejectsInvalidLimit(t *testing.T) {
	store, acc, _ := setup(t)
	for _, limit := range []int{0, -1, math.MaxInt32 + 1} {
		_, err := store.List(context.Background(), acc, diary.ListQuery{Limit: limit})
		assert.Error(t, err, "limit %d", limit)
	}
}

func TestStore_StoresJSONShape(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	mustCreate(t, store, acc, 10, "본문", record("dohwa"))

	var guide, featured string
	require.NoError(t, pool.QueryRow(ctx,
		"SELECT guide_question::text, featured_tags::text FROM diary_days WHERE account_id = $1", acc).Scan(&guide, &featured))
	assert.JSONEq(t, `[{"text":"오늘은 "},{"text":"비견","term":"term.ten_god.bigyeon"},{"text":"을 느꼈나요?"}]`, guide)
	var withoutTerm int
	require.NoError(t, pool.QueryRow(ctx,
		"SELECT count(*) FROM diary_days, jsonb_array_elements(guide_question) seg WHERE account_id = $1 AND NOT seg ? 'term'", acc).Scan(&withoutTerm))
	assert.Equal(t, 2, withoutTerm, "term 없는 조각 둘에는 term 키 자체가 없음")
	assert.JSONEq(t, `[{"key":"dohwa","polarity":"neutral"}]`, featured)
}

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

func entry(d int, body string, tags ...string) diary.Entry {
	return diary.Entry{
		Date:           day(d),
		Body:           body,
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

func TestStore_UpsertCreatesThenUpdatesBodyOnly(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)

	first, created, err := store.Upsert(ctx, acc, entry(10, "처음", "dohwa", "a"))
	require.NoError(t, err)
	assert.True(t, created)
	assert.Equal(t, "처음", first.Body)
	assert.Equal(t, entry(10, "", "dohwa", "a").GuideQuestion, first.GuideQuestion)
	assert.Equal(t, entry(10, "").Featured, first.Featured)

	changed := entry(10, "고침", "other")
	changed.RulesetVersion = "r2"
	changed.GuideQuestion = []render.Segment{{Text: "다른 질문"}}
	second, created, err := store.Upsert(ctx, acc, changed)
	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, "고침", second.Body)
	assert.Equal(t, first.AllTags, second.AllTags)
	assert.Equal(t, first.Featured, second.Featured)
	assert.Equal(t, first.GuideQuestion, second.GuideQuestion)
	assert.Equal(t, "r1", second.RulesetVersion)
	assert.True(t, first.CreatedAt.Equal(second.CreatedAt))
	assert.False(t, second.UpdatedAt.Before(first.UpdatedAt))

	got, err := store.Get(ctx, acc, day(10))
	require.NoError(t, err)
	assert.Equal(t, second, got)
}

func TestStore_UpsertWithoutGuideQuestion(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	e := entry(10, "본문")
	e.GuideQuestion = nil
	e.AllTags = nil
	e.Featured = nil
	got, _, err := store.Upsert(ctx, acc, e)
	require.NoError(t, err)
	assert.Empty(t, got.GuideQuestion)
	assert.Empty(t, got.AllTags)
	assert.Empty(t, got.Featured)
}

func TestStore_ConcurrentUpsertKeepsOneRow(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)

	var wg sync.WaitGroup
	results := make([]bool, 2)
	errs := make([]error, 2)
	for i := range results {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, results[i], errs[i] = store.Upsert(ctx, acc, entry(10, "본문", "a"))
		}()
	}
	wg.Wait()
	require.NoError(t, errs[0])
	require.NoError(t, errs[1])
	assert.NotEqual(t, results[0], results[1], "하나만 새로 만든 것")

	var n int
	require.NoError(t, pool.QueryRow(ctx, "SELECT count(*) FROM diaries WHERE account_id = $1", acc).Scan(&n))
	assert.Equal(t, 1, n)
}

func TestStore_DeleteThenGetIsNotFound(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	_, _, err := store.Upsert(ctx, acc, entry(10, "본문"))
	require.NoError(t, err)

	require.NoError(t, store.Delete(ctx, acc, day(10)))
	_, err = store.Get(ctx, acc, day(10))
	assert.ErrorIs(t, err, diary.ErrNotFound)
	assert.ErrorIs(t, store.Delete(ctx, acc, day(10)), diary.ErrNotFound)
}

func TestStore_RestoreLatestDeleted(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	for _, body := range []string{"첫째", "둘째"} {
		_, created, err := store.Upsert(ctx, acc, entry(10, body))
		require.NoError(t, err)
		require.True(t, created)
		require.NoError(t, store.Delete(ctx, acc, day(10)))
	}

	restored, err := store.Restore(ctx, acc, day(10))
	require.NoError(t, err)
	assert.Equal(t, "둘째", restored.Body)
	got, err := store.Get(ctx, acc, day(10))
	require.NoError(t, err)
	assert.Equal(t, "둘째", got.Body)
}

func TestStore_RestoreWhenAliveIsDateTaken(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	_, _, err := store.Upsert(ctx, acc, entry(10, "지울 것"))
	require.NoError(t, err)
	require.NoError(t, store.Delete(ctx, acc, day(10)))
	_, _, err = store.Upsert(ctx, acc, entry(10, "새 것"))
	require.NoError(t, err)

	_, err = store.Restore(ctx, acc, day(10))
	assert.ErrorIs(t, err, diary.ErrDateTaken)
}

func TestStore_RestoreWithoutDeletedIsNotFound(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	_, err := store.Restore(ctx, acc, day(10))
	assert.ErrorIs(t, err, diary.ErrNotFound)
}

func dates(entries []diary.Entry) []int {
	out := make([]int, len(entries))
	for i, e := range entries {
		out[i] = e.Date.Day
	}
	return out
}

func TestStore_ListFiltersRangeTagAndDeleted(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	for _, e := range []diary.Entry{
		entry(1, "a", "x"), entry(2, "b", "y"), entry(3, "c", "x", "y"), entry(4, "d", "x"), entry(5, "e", "y"),
	} {
		_, _, err := store.Upsert(ctx, acc, e)
		require.NoError(t, err)
	}
	require.NoError(t, store.Delete(ctx, acc, day(4)))

	all, err := store.List(ctx, acc, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, []int{5, 3, 2, 1}, dates(all))

	from, to := day(2), day(3)
	ranged, err := store.List(ctx, acc, diary.ListQuery{From: &from, To: &to, Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, []int{3, 2}, dates(ranged))

	tag := "x"
	tagged, err := store.List(ctx, acc, diary.ListQuery{Tag: &tag, Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, []int{3, 1}, dates(tagged), "지운 4일은 빠짐")
}

func TestStore_ListBeforeIsKeyset(t *testing.T) {
	ctx := context.Background()
	store, acc, _ := setup(t)
	for _, d := range []int{1, 3, 5, 7, 9} {
		_, _, err := store.Upsert(ctx, acc, entry(d, "본문"))
		require.NoError(t, err)
	}

	page1, err := store.List(ctx, acc, diary.ListQuery{Limit: 2})
	require.NoError(t, err)
	assert.Equal(t, []int{9, 7}, dates(page1))

	// 첫 쪽을 본 사이에 새 일기가 들어와도(맨 앞 10일, 이미 지난 5일 앞쪽 6일) 다음 쪽은 중복·빠짐이 없습니다.
	for _, d := range []int{10, 6, 2} {
		_, _, err := store.Upsert(ctx, acc, entry(d, "새 글"))
		require.NoError(t, err)
	}
	before := page1[len(page1)-1].Date
	page2, err := store.List(ctx, acc, diary.ListQuery{Before: &before, Limit: 2})
	require.NoError(t, err)
	assert.Equal(t, []int{6, 5}, dates(page2))

	before = page2[len(page2)-1].Date
	page3, err := store.List(ctx, acc, diary.ListQuery{Before: &before, Limit: 5})
	require.NoError(t, err)
	assert.Equal(t, []int{3, 2, 1}, dates(page3))
}

func TestStore_OtherAccountInvisible(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	other := newAccount(t, pool)
	_, _, err := store.Upsert(ctx, acc, entry(10, "내 일기", "x"))
	require.NoError(t, err)

	_, err = store.Get(ctx, other, day(10))
	assert.ErrorIs(t, err, diary.ErrNotFound)
	assert.ErrorIs(t, store.Delete(ctx, other, day(10)), diary.ErrNotFound)
	_, err = store.Restore(ctx, other, day(10))
	assert.ErrorIs(t, err, diary.ErrNotFound)
	list, err := store.List(ctx, other, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	assert.Empty(t, list)

	// 같은 날짜에 다른 계정이 따로 쓸 수 있습니다.
	_, created, err := store.Upsert(ctx, other, entry(10, "남의 일기"))
	require.NoError(t, err)
	assert.True(t, created)
}

func TestStore_StoresJSONShape(t *testing.T) {
	ctx := context.Background()
	store, acc, pool := setup(t)
	_, _, err := store.Upsert(ctx, acc, entry(10, "본문", "dohwa"))
	require.NoError(t, err)

	var guide, featured string
	require.NoError(t, pool.QueryRow(ctx,
		"SELECT guide_question::text, featured_tags::text FROM diaries WHERE account_id = $1", acc).Scan(&guide, &featured))
	assert.JSONEq(t, `[{"text":"오늘은 "},{"text":"비견","term":"term.ten_god.bigyeon"},{"text":"을 느꼈나요?"}]`, guide)
	var withoutTerm int
	require.NoError(t, pool.QueryRow(ctx,
		"SELECT count(*) FROM diaries, jsonb_array_elements(guide_question) seg WHERE account_id = $1 AND NOT seg ? 'term'", acc).Scan(&withoutTerm))
	assert.Equal(t, 2, withoutTerm, "term 없는 조각 둘에는 term 키 자체가 없음")
	assert.JSONEq(t, `[{"key":"dohwa","polarity":"neutral"}]`, featured)
}

func TestStore_ListRejectsInvalidLimit(t *testing.T) {
	store, acc, _ := setup(t)
	for _, limit := range []int{0, -1, math.MaxInt32 + 1} {
		_, err := store.List(context.Background(), acc, diary.ListQuery{Limit: limit})
		assert.Error(t, err, "limit %d", limit)
	}
}

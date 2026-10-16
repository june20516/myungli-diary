package content_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
)

// reactionRow는 reactions 행 하나입니다.
type reactionRow struct {
	Reaction  string
	CreatedAt time.Time
	DeletedAt *time.Time
}

func (f *selectFixture) reactions(t *testing.T, selectionID int64) []reactionRow {
	t.Helper()
	rows, err := f.pool.Query(context.Background(),
		"SELECT reaction, created_at, deleted_at FROM reactions WHERE selection_id = $1 ORDER BY created_at, deleted_at NULLS LAST", selectionID)
	require.NoError(t, err)
	defer rows.Close()
	var out []reactionRow
	for rows.Next() {
		var r reactionRow
		require.NoError(t, rows.Scan(&r.Reaction, &r.CreatedAt, &r.DeletedAt))
		out = append(out, r)
	}
	require.NoError(t, rows.Err())
	return out
}

func TestPutReaction_IsIdempotent(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixture(t)
	sel := f.pick(t, day0, f.hash, headSlot, "k")

	require.NoError(t, f.store.PutReaction(ctx, sel.ID, "like"))
	f.clock.Advance(time.Minute)
	require.NoError(t, f.store.PutReaction(ctx, sel.ID, "like"))

	got := f.reactions(t, sel.ID)
	require.Len(t, got, 1, "같은 반응은 행을 더 만들지 않음")
	assert.Equal(t, "like", got[0].Reaction)
	assert.Nil(t, got[0].DeletedAt)
	assert.True(t, got[0].CreatedAt.Equal(f.clock.Now().Add(-time.Minute)), "처음 남긴 clock 시각 그대로")
}

func TestPutReaction_DifferentValueKeepsHistory(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixture(t)
	sel := f.pick(t, day0, f.hash, headSlot, "k")

	require.NoError(t, f.store.PutReaction(ctx, sel.ID, "like"))
	f.clock.Advance(time.Minute)
	require.NoError(t, f.store.PutReaction(ctx, sel.ID, "other"))

	got := f.reactions(t, sel.ID)
	require.Len(t, got, 2)
	assert.Equal(t, "like", got[0].Reaction)
	require.NotNil(t, got[0].DeletedAt, "옛 반응은 soft delete로 이력에 남음")
	assert.True(t, got[0].DeletedAt.Equal(f.clock.Now()))
	assert.Equal(t, "other", got[1].Reaction)
	assert.Nil(t, got[1].DeletedAt)
}

func TestDeleteReaction_SoftDeletes(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixture(t)
	sel := f.pick(t, day0, f.hash, headSlot, "k")
	require.NoError(t, f.store.PutReaction(ctx, sel.ID, "like"))
	f.clock.Advance(time.Minute)

	require.NoError(t, f.store.DeleteReaction(ctx, sel.ID))
	require.NoError(t, f.store.DeleteReaction(ctx, sel.ID), "반응이 없어도 성공(멱등)")

	got := f.reactions(t, sel.ID)
	require.Len(t, got, 1, "행은 지우지 않음")
	require.NotNil(t, got[0].DeletedAt)
	assert.True(t, got[0].DeletedAt.Equal(f.clock.Now()), "clock 기준 시각")

	// 취소 뒤 다시 남기면 soft delete된 행을 되살리지 않고 새 행을 넣습니다.
	require.NoError(t, f.store.PutReaction(ctx, sel.ID, "like"))
	got = f.reactions(t, sel.ID)
	require.Len(t, got, 2)
	assert.NotNil(t, got[0].DeletedAt)
	assert.Nil(t, got[1].DeletedAt)
}

func TestActiveReactions(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixture(t)
	head := f.pick(t, day0, f.hash, headSlot, "k")
	tag := f.pick(t, day0, f.hash, tagSlot, "k")
	guide := f.pick(t, day0, f.hash, guideSlot, "k")
	require.NoError(t, f.store.PutReaction(ctx, head.ID, "like"))
	require.NoError(t, f.store.PutReaction(ctx, tag.ID, "like"))
	require.NoError(t, f.store.DeleteReaction(ctx, tag.ID))

	got, err := f.store.ActiveReactions(ctx, []int64{head.ID, tag.ID, guide.ID})
	require.NoError(t, err)
	assert.Equal(t, map[int64]string{head.ID: "like"}, got, "취소한 반응과 반응 없는 기록은 빠짐")

	empty, err := f.store.ActiveReactions(ctx, nil)
	require.NoError(t, err)
	assert.Empty(t, empty)
}

// 같은 선택 기록에 다른 값을 동시에 남기면 둘 다 성공하고, 나중에 처리한 값 하나만 활성으로 남으며 앞 값은 이력입니다.
// 다른 연결이 reactions 쓰기를 막아 두 요청이 모두 조회까지 마친 뒤 기다리게 합니다. 선택 기록 행 lock이 없으면 둘 다
// "활성 없음"을 보고 넣으므로 한쪽은 부분 unique 때문에 조용히 빠지고 행이 하나만 남아 이 테스트가 실패합니다.
func TestPutReaction_ConcurrentDifferentValuesKeepLastOnly(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixtureOn(t, poolWithMaxConns(t, 8))
	sel := f.pick(t, day0, f.hash, headSlot, "k")

	holder, err := f.pool.Begin(ctx)
	require.NoError(t, err)
	_, err = holder.Exec(ctx, "LOCK TABLE reactions IN EXCLUSIVE MODE")
	require.NoError(t, err)

	values := []string{"like", "other"}
	errs := make([]error, len(values))
	var wg sync.WaitGroup
	for i, v := range values {
		wg.Go(func() { errs[i] = f.store.PutReaction(ctx, sel.ID, v) })
	}
	waiting := func() int {
		var n int
		if err := f.pool.QueryRow(ctx,
			"SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock' AND datname = current_database()").Scan(&n); err != nil {
			return -1
		}
		return n
	}
	blocked := assert.Eventually(t, func() bool { return waiting() == len(values) }, 10*time.Second, 10*time.Millisecond,
		"두 요청이 모두 lock을 기다려야 함")
	require.NoError(t, holder.Rollback(ctx))
	wg.Wait()
	require.True(t, blocked)

	for i := range values {
		require.NoError(t, errs[i], values[i])
	}
	got := f.reactions(t, sel.ID)
	require.Len(t, got, 2, "두 값 모두 행으로 남음")
	var active, deleted []string
	for _, r := range got {
		if r.DeletedAt == nil {
			active = append(active, r.Reaction)
		} else {
			deleted = append(deleted, r.Reaction)
		}
	}
	require.Len(t, active, 1, "활성은 하나")
	require.Len(t, deleted, 1)
	assert.ElementsMatch(t, values, append(active, deleted...), "앞 값은 soft delete, 나중 값이 활성")
}

func TestPutReaction_MissingSelectionIsNotFound(t *testing.T) {
	f := newSelectFixture(t)
	err := f.store.PutReaction(context.Background(), 999999, "like")
	assert.ErrorIs(t, err, content.ErrSelectionNotFound)
}

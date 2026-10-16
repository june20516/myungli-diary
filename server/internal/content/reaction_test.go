package content_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

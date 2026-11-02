package profile

import (
	"context"
	"slices"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
)

// createActiveProfile은 last_active_at이 lastActive인 계정을 만들고 withProfile이면 기본 프로필을 저장합니다.
func createActiveProfile(t *testing.T, f *serviceFixture, lastActive time.Time, withProfile bool) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	id := uuid.New()
	require.NoError(t, authdb.New(f.pool).CreateAccount(ctx, authdb.CreateAccountParams{ID: id, LastActiveAt: lastActive}))
	if withProfile {
		_, err := f.svc.Put(ctx, id, validProfile())
		require.NoError(t, err)
	}
	return id
}

func activeIDs(items []ActiveProfile) []uuid.UUID {
	ids := make([]uuid.UUID, 0, len(items))
	for _, item := range items {
		ids = append(ids, item.AccountID)
	}
	return ids
}

func TestListActiveProfiles_FiltersByStatusAndLastActive(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	activeSince := time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC)

	recent := createActiveProfile(t, f, activeSince.Add(24*time.Hour), true)
	exactly := createActiveProfile(t, f, activeSince, true)
	createActiveProfile(t, f, activeSince.Add(-time.Second), true)
	deleted := createActiveProfile(t, f, activeSince.Add(time.Hour), true)
	_, err := f.pool.Exec(ctx, `UPDATE accounts SET status = 'deleted', deleted_at = now() WHERE id = $1`, deleted)
	require.NoError(t, err)
	createActiveProfile(t, f, activeSince.Add(time.Hour), false)

	got, err := ListActiveProfiles(ctx, f.pool, activeSince, uuid.Nil, 100)
	require.NoError(t, err)

	assert.ElementsMatch(t, []uuid.UUID{recent, exactly}, activeIDs(got))
}

func TestListActiveProfiles_PagesByAccountID(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	activeSince := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	var want []uuid.UUID
	for range 5 {
		want = append(want, createActiveProfile(t, f, activeSince.Add(time.Hour), true))
	}
	slices.SortFunc(want, func(a, b uuid.UUID) int { return slices.Compare(a[:], b[:]) })

	var all []uuid.UUID
	after := uuid.Nil
	for _, wantLen := range []int{2, 2, 1, 0} {
		page, err := ListActiveProfiles(ctx, f.pool, activeSince, after, 2)
		require.NoError(t, err)
		require.Len(t, page, wantLen)
		all = append(all, activeIDs(page)...)
		if len(page) > 0 {
			after = page[len(page)-1].AccountID
		}
	}
	assert.Equal(t, want, all)
}

func TestListActiveProfiles_ConvertsProfile(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	activeSince := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	id := createActiveProfile(t, f, activeSince.Add(time.Hour), true)

	got, err := ListActiveProfiles(ctx, f.pool, activeSince, uuid.Nil, 10)
	require.NoError(t, err)
	require.Len(t, got, 1)

	want, err := f.svc.Get(ctx, id)
	require.NoError(t, err)
	assert.Equal(t, want, got[0].Profile)
}

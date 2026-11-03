package notify_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/notify"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

var storeNow = time.Date(2026, 11, 4, 7, 5, 0, 0, time.UTC)

func newAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	id := uuid.New()
	require.NoError(t, authdb.New(pool).CreateAccount(context.Background(), authdb.CreateAccountParams{ID: id, LastActiveAt: storeNow}))
	return id
}

func addDevice(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, platform string, active bool) uuid.UUID {
	t.Helper()
	id := uuid.New()
	_, err := pool.Exec(context.Background(), `INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at)
		VALUES ($1, $2, $3, sha256(convert_to($3, 'UTF8')), $4, $5, now())`, id, accountID, "fcm-"+id.String(), platform, active)
	require.NoError(t, err)
	return id
}

func TestStore_ClaimOncePerDay(t *testing.T) {
	pool := dbtest.New(t)
	store := notify.NewStore(pool)
	ctx := context.Background()
	account := newAccount(t, pool)
	day := profile.LocalDate{Year: 2026, Month: 11, Day: 4}

	first, err := store.Claim(ctx, account, day, storeNow)
	require.NoError(t, err)
	again, err := store.Claim(ctx, account, day, storeNow)
	require.NoError(t, err)
	nextDay, err := store.Claim(ctx, account, profile.LocalDate{Year: 2026, Month: 11, Day: 5}, storeNow)
	require.NoError(t, err)

	assert.True(t, first)
	assert.False(t, again)
	assert.True(t, nextDay)
}

func TestStore_FinishSetsResult(t *testing.T) {
	pool := dbtest.New(t)
	store := notify.NewStore(pool)
	ctx := context.Background()
	account := newAccount(t, pool)
	day := profile.LocalDate{Year: 2026, Month: 11, Day: 4}
	_, err := store.Claim(ctx, account, day, storeNow)
	require.NoError(t, err)

	require.NoError(t, store.Finish(ctx, account, day, notify.ResultSent, storeNow.Add(time.Second)))

	var result string
	var sentAt *time.Time
	require.NoError(t, pool.QueryRow(ctx, `SELECT result, sent_at FROM notification_log WHERE account_id = $1 AND local_date = '2026-11-04'`, account).
		Scan(&result, &sentAt))
	assert.Equal(t, "sent", result)
	require.NotNil(t, sentAt)
	assert.True(t, sentAt.Equal(storeNow.Add(time.Second)))
}

func TestStore_ActiveDevicesAndDeactivate(t *testing.T) {
	pool := dbtest.New(t)
	store := notify.NewStore(pool)
	ctx := context.Background()
	account := newAccount(t, pool)
	ios := addDevice(t, pool, account, "ios", true)
	android := addDevice(t, pool, account, "android", true)
	addDevice(t, pool, account, "android", false)

	devices, err := store.ActiveDevices(ctx, account)
	require.NoError(t, err)
	require.Len(t, devices, 2)
	ids := []uuid.UUID{devices[0].ID, devices[1].ID}
	assert.ElementsMatch(t, []uuid.UUID{ios, android}, ids)
	assert.Equal(t, "fcm-"+devices[0].ID.String(), devices[0].Token)

	require.NoError(t, store.Deactivate(ctx, ios))
	devices, err = store.ActiveDevices(ctx, account)
	require.NoError(t, err)
	require.Len(t, devices, 1)
	assert.Equal(t, android, devices[0].ID)
}

func TestStore_ReleaseLetsNextClaim(t *testing.T) {
	pool := dbtest.New(t)
	store := notify.NewStore(pool)
	ctx := context.Background()
	account := newAccount(t, pool)
	day := profile.LocalDate{Year: 2026, Month: 11, Day: 4}
	_, err := store.Claim(ctx, account, day, storeNow)
	require.NoError(t, err)

	require.NoError(t, store.Release(ctx, account, day))

	again, err := store.Claim(ctx, account, day, storeNow.Add(5*time.Minute))
	require.NoError(t, err)
	assert.True(t, again)
}

// Job이 죽어 pending으로 남은 행은 10분 뒤 다시 claim할 수 있습니다. sent·failed 행은 다시 claim하지 않습니다.
func TestStore_ReclaimsStalePending(t *testing.T) {
	pool := dbtest.New(t)
	store := notify.NewStore(pool)
	ctx := context.Background()
	day := profile.LocalDate{Year: 2026, Month: 11, Day: 4}

	stuck := newAccount(t, pool)
	_, err := store.Claim(ctx, stuck, day, storeNow)
	require.NoError(t, err)
	early, err := store.Claim(ctx, stuck, day, storeNow.Add(9*time.Minute))
	require.NoError(t, err)
	late, err := store.Claim(ctx, stuck, day, storeNow.Add(11*time.Minute))
	require.NoError(t, err)
	assert.False(t, early)
	assert.True(t, late)

	done := newAccount(t, pool)
	_, err = store.Claim(ctx, done, day, storeNow)
	require.NoError(t, err)
	require.NoError(t, store.Finish(ctx, done, day, notify.ResultSent, storeNow))
	reclaimed, err := store.Claim(ctx, done, day, storeNow.Add(time.Hour))
	require.NoError(t, err)
	assert.False(t, reclaimed)
}

func TestStore_ClaimDeletedAccount(t *testing.T) {
	pool := dbtest.New(t)
	store := notify.NewStore(pool)
	ctx := context.Background()
	account := newAccount(t, pool)
	_, err := pool.Exec(ctx, `UPDATE accounts SET status = 'deleted', deleted_at = now() WHERE id = $1`, account)
	require.NoError(t, err)

	_, err = store.Claim(ctx, account, profile.LocalDate{Year: 2026, Month: 11, Day: 4}, storeNow)

	require.ErrorIs(t, err, notify.ErrAccountDeleted)
}

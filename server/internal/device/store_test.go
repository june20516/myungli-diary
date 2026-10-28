package device_test

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/device"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

var now = time.Date(2026, 10, 28, 12, 0, 0, 0, time.UTC)

func newAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
	return id
}

func newStore(t *testing.T) (*device.Store, *pgxpool.Pool, *clocktest.Fake) {
	t.Helper()
	pool := dbtest.New(t)
	clk := clocktest.New(now)
	return device.NewStore(pool, clk), pool, clk
}

// deviceRow는 검증에 쓰는 devices 행 한 줄입니다.
type deviceRow struct {
	accountID  uuid.UUID
	platform   string
	active     bool
	lastSeenAt time.Time
}

func readDevice(t *testing.T, pool *pgxpool.Pool, id uuid.UUID) deviceRow {
	t.Helper()
	var row deviceRow
	require.NoError(t, pool.QueryRow(context.Background(),
		"SELECT account_id, platform, active, last_seen_at FROM devices WHERE id = $1", id).
		Scan(&row.accountID, &row.platform, &row.active, &row.lastSeenAt))
	return row
}

func countActive(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(context.Background(),
		"SELECT count(*) FROM devices WHERE account_id = $1 AND active", accountID).Scan(&n))
	return n
}

func TestStore_RegisterNewTokenIsCreated(t *testing.T) {
	store, pool, _ := newStore(t)
	account := newAccount(t, pool)

	d, created, err := store.Register(context.Background(), account, "token-1", device.PlatformAndroid)

	require.NoError(t, err)
	assert.True(t, created)
	assert.Equal(t, device.PlatformAndroid, d.Platform)
	row := readDevice(t, pool, d.ID)
	assert.Equal(t, account, row.accountID)
	assert.True(t, row.active)
	assert.True(t, row.lastSeenAt.Equal(now))
}

func TestStore_RegisterSameTokenKeepsID(t *testing.T) {
	store, pool, clk := newStore(t)
	account := newAccount(t, pool)
	first, _, err := store.Register(context.Background(), account, "token-1", device.PlatformAndroid)
	require.NoError(t, err)

	clk.Advance(time.Hour)
	second, created, err := store.Register(context.Background(), account, "token-1", device.PlatformAndroid)

	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, first.ID, second.ID)
	assert.True(t, readDevice(t, pool, second.ID).lastSeenAt.Equal(now.Add(time.Hour)))
}

func TestStore_RegisterMovesTokenToRequester(t *testing.T) {
	store, pool, _ := newStore(t)
	a, b := newAccount(t, pool), newAccount(t, pool)
	first, _, err := store.Register(context.Background(), a, "token-1", device.PlatformIOS)
	require.NoError(t, err)

	moved, created, err := store.Register(context.Background(), b, "token-1", device.PlatformIOS)

	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, first.ID, moved.ID)
	assert.Equal(t, b, readDevice(t, pool, moved.ID).accountID)
	assert.Equal(t, 0, countActive(t, pool, a))
	assert.ErrorIs(t, store.Deactivate(context.Background(), a, moved.ID), device.ErrNotFound)
}

func TestStore_RegisterReactivatesAndUpdatesPlatform(t *testing.T) {
	store, pool, _ := newStore(t)
	account := newAccount(t, pool)
	first, _, err := store.Register(context.Background(), account, "token-1", device.PlatformAndroid)
	require.NoError(t, err)
	require.NoError(t, store.Deactivate(context.Background(), account, first.ID))

	again, created, err := store.Register(context.Background(), account, "token-1", device.PlatformIOS)

	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, first.ID, again.ID)
	assert.Equal(t, device.PlatformIOS, again.Platform)
	row := readDevice(t, pool, again.ID)
	assert.True(t, row.active)
	assert.Equal(t, "ios", row.platform)
}

func TestStore_RegisterCapsActiveDevices(t *testing.T) {
	store, pool, clk := newStore(t)
	account := newAccount(t, pool)

	var oldest device.Device
	for i := range device.MaxActivePerAccount + 1 {
		d, _, err := store.Register(context.Background(), account, fmt.Sprintf("token-%d", i), device.PlatformAndroid)
		require.NoError(t, err)
		if i == 0 {
			oldest = d
		}
		clk.Advance(time.Second)
	}

	assert.Equal(t, device.MaxActivePerAccount, countActive(t, pool, account))
	assert.False(t, readDevice(t, pool, oldest.ID).active)
}

func TestStore_RegisterConcurrentStaysWithinCap(t *testing.T) {
	store, pool, _ := newStore(t)
	account := newAccount(t, pool)

	var wg sync.WaitGroup
	errs := make(chan error, device.MaxActivePerAccount+1)
	for i := range device.MaxActivePerAccount + 1 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, _, err := store.Register(context.Background(), account, fmt.Sprintf("token-%d", i), device.PlatformAndroid)
			errs <- err
		}()
	}
	wg.Wait()
	close(errs)

	for err := range errs {
		require.NoError(t, err)
	}
	assert.Equal(t, device.MaxActivePerAccount, countActive(t, pool, account))
}

func TestStore_DeactivateIsIdempotentForOwnDevice(t *testing.T) {
	store, pool, _ := newStore(t)
	account := newAccount(t, pool)
	d, _, err := store.Register(context.Background(), account, "token-1", device.PlatformAndroid)
	require.NoError(t, err)

	require.NoError(t, store.Deactivate(context.Background(), account, d.ID))
	require.NoError(t, store.Deactivate(context.Background(), account, d.ID))

	assert.False(t, readDevice(t, pool, d.ID).active)
}

func TestStore_DeactivateUnknownIsNotFound(t *testing.T) {
	store, pool, _ := newStore(t)

	err := store.Deactivate(context.Background(), newAccount(t, pool), uuid.New())

	assert.ErrorIs(t, err, device.ErrNotFound)
}

package device_test

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
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

// 계정 삭제와 겹친 등록이 지운 계정에 기기 행을 남기지 않도록 DB trigger가 막습니다(migration 00015와 같은 규칙).
func TestStore_RegisterOnDeletedAccountIsRejected(t *testing.T) {
	store, pool, _ := newStore(t)
	deleted := newAccount(t, pool)
	_, err := pool.Exec(context.Background(), "UPDATE accounts SET status = 'deleted', deleted_at = now() WHERE id = $1", deleted)
	require.NoError(t, err)

	_, _, err = store.Register(context.Background(), deleted, "token-1", device.PlatformAndroid)

	assert.True(t, account.IsAccountDeletedError(err), "err = %v", err)
}

// 다른 계정(B)이 A의 가장 오래된 토큰을 옮기는 중에 A의 상한 적용이 겹쳐도, 옮겨 간 기기는 B 쪽에서 활성으로 남습니다.
// A의 상한 적용은 B의 커밋을 기다렸다가 바뀐 행을 다시 보는데, 그때 주인이 B면 건드리지 않아야 합니다.
func TestStore_RegisterOverflowSkipsTokenMovedConcurrently(t *testing.T) {
	store, pool, clk := newStore(t)
	ctx := context.Background()
	a, b := newAccount(t, pool), newAccount(t, pool)
	var oldest device.Device
	for i := range device.MaxActivePerAccount {
		d, _, err := store.Register(ctx, a, fmt.Sprintf("token-%d", i), device.PlatformAndroid)
		require.NoError(t, err)
		if i == 0 {
			oldest = d
		}
		clk.Advance(time.Second)
	}

	// B가 가장 오래된 토큰을 옮긴 채 커밋하지 않고 행 잠금을 쥡니다.
	moving, err := pool.Begin(ctx)
	require.NoError(t, err)
	defer func() { _ = moving.Rollback(ctx) }()
	_, err = moving.Exec(ctx, "UPDATE devices SET account_id = $1, active = true, last_seen_at = $2 WHERE id = $3", b, clk.Now(), oldest.ID)
	require.NoError(t, err)

	done := make(chan error, 1)
	go func() {
		_, _, err := store.Register(ctx, a, "token-new", device.PlatformAndroid)
		done <- err
	}()
	require.Eventually(t, func() bool {
		var waiting int
		require.NoError(t, pool.QueryRow(ctx, "SELECT count(*) FROM pg_locks WHERE NOT granted").Scan(&waiting))
		return waiting > 0
	}, 5*time.Second, 10*time.Millisecond, "A의 상한 적용이 B의 행 잠금을 기다려야 합니다")
	require.NoError(t, moving.Commit(ctx))
	require.NoError(t, <-done)

	row := readDevice(t, pool, oldest.ID)
	assert.Equal(t, b, row.accountID)
	assert.True(t, row.active, "B로 옮긴 기기는 활성입니다")
	assert.Equal(t, device.MaxActivePerAccount, countActive(t, pool, a))
}

// 계약은 토큰을 4096자까지 받으므로 btree 항목 상한을 넘는 긴 토큰도 등록됩니다.
func TestStore_RegisterAcceptsMaxLengthToken(t *testing.T) {
	store, pool, _ := newStore(t)
	account := newAccount(t, pool)
	raw := make([]byte, 2048)
	_, err := rand.Read(raw)
	require.NoError(t, err)
	token := hex.EncodeToString(raw)

	first, created, err := store.Register(context.Background(), account, token, device.PlatformIOS)
	require.NoError(t, err)
	assert.True(t, created)
	again, created, err := store.Register(context.Background(), account, token, device.PlatformIOS)
	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, first.ID, again.ID)
}

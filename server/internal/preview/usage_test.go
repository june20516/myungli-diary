package preview_test

import (
	"context"
	"crypto/sha256"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/preview"
)

func TestUsage_ClaimOnlyOnce(t *testing.T) {
	ctx := context.Background()
	usage := preview.NewUsage(dbtest.New(t))

	first, err := usage.Claim(ctx, "install-1")
	require.NoError(t, err)
	assert.True(t, first)

	second, err := usage.Claim(ctx, "install-1")
	require.NoError(t, err)
	assert.False(t, second, "같은 설치의 두 번째")

	other, err := usage.Claim(ctx, "install-2")
	require.NoError(t, err)
	assert.True(t, other, "다른 설치는 따로")
}

func TestUsage_ReleaseAllowsClaimAgain(t *testing.T) {
	ctx := context.Background()
	usage := preview.NewUsage(dbtest.New(t))
	_, err := usage.Claim(ctx, "install-1")
	require.NoError(t, err)

	require.NoError(t, usage.Release(ctx, "install-1"))
	require.NoError(t, usage.Release(ctx, "never-claimed"), "없는 기록의 해제도 오류가 아님")

	again, err := usage.Claim(ctx, "install-1")
	require.NoError(t, err)
	assert.True(t, again)
}

func TestUsage_ConcurrentClaimWinsOnce(t *testing.T) {
	ctx := context.Background()
	usage := preview.NewUsage(dbtest.New(t))

	const callers = 8
	var won atomic.Int32
	var wg sync.WaitGroup
	for range callers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			claimed, err := usage.Claim(ctx, "install-1")
			assert.NoError(t, err)
			if claimed {
				won.Add(1)
			}
		}()
	}
	wg.Wait()

	assert.EqualValues(t, 1, won.Load(), "동시 선점은 하나만 성공")
}

func TestUsage_StoresOnlySHA256NotRawID(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	_, err := preview.NewUsage(pool).Claim(ctx, "install-raw-id")
	require.NoError(t, err)

	var stored []byte
	require.NoError(t, pool.QueryRow(ctx, "SELECT device_hash FROM preview_usage").Scan(&stored))
	want := sha256.Sum256([]byte("install-raw-id"))
	assert.Equal(t, want[:], stored)

	var rawRows int
	require.NoError(t, pool.QueryRow(ctx,
		"SELECT count(*) FROM preview_usage WHERE convert_from(device_hash, 'LATIN1') LIKE '%install-raw-id%'").Scan(&rawRows))
	assert.Zero(t, rawRows, "원문 id가 표에 없음")
}

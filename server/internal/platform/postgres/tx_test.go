package postgres_test

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// countAccounts는 accounts 행 수를 돌려줍니다.
func countAccounts(t *testing.T, ctx context.Context, tx interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}) int {
	t.Helper()
	var n int
	require.NoError(t, tx.QueryRow(ctx, `SELECT count(*) FROM accounts`).Scan(&n))
	return n
}

func TestInTx_CommitsOnSuccess(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)

	err := postgres.InTx(ctx, pool, func(tx pgx.Tx) error {
		return insertActiveAccount(ctx, tx)
	})

	require.NoError(t, err)
	assert.Equal(t, 1, countAccounts(t, ctx, pool))
}

func TestInTx_RollsBackOnError(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	errBoom := errors.New("boom")

	err := postgres.InTx(ctx, pool, func(tx pgx.Tx) error {
		require.NoError(t, insertActiveAccount(ctx, tx))
		return errBoom
	})

	require.ErrorIs(t, err, errBoom)
	assert.Equal(t, 0, countAccounts(t, ctx, pool))
}

func TestInTx_RetriesSerializationAndDeadlock(t *testing.T) {
	tests := []struct {
		name      string
		failures  int // fn이 처음 몇 번 실패하는지
		code      string
		wantCalls int
		wantErr   bool
	}{
		{name: "serialization 두 번 뒤 성공", failures: 2, code: "40001", wantCalls: 3},
		{name: "deadlock 세 번 뒤 성공", failures: 3, code: "40P01", wantCalls: 4},
		{name: "재시도 3번을 다 쓰면 마지막 오류", failures: 10, code: "40001", wantCalls: 4, wantErr: true},
		{name: "재시도 대상이 아닌 SQLSTATE는 한 번만", failures: 10, code: "23505", wantCalls: 1, wantErr: true},
	}
	pool := dbtest.New(t)
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx := context.Background()
			calls := 0
			err := postgres.InTx(ctx, pool, func(pgx.Tx) error {
				calls++
				if calls <= tt.failures {
					return &pgconn.PgError{Code: tt.code}
				}
				return nil
			})

			assert.Equal(t, tt.wantCalls, calls)
			if !tt.wantErr {
				require.NoError(t, err)
				return
			}
			var pgErr *pgconn.PgError
			require.ErrorAs(t, err, &pgErr)
			assert.Equal(t, tt.code, pgErr.Code)
		})
	}
}

func TestInTx_StopsRetryingWhenContextIsDone(t *testing.T) {
	pool := dbtest.New(t)
	ctx, cancel := context.WithCancel(context.Background())

	calls := 0
	err := postgres.InTx(ctx, pool, func(pgx.Tx) error {
		calls++
		cancel()
		return &pgconn.PgError{Code: "40001"}
	})

	require.Error(t, err)
	assert.Equal(t, 1, calls)
}

// insertActiveAccount는 트랜잭션 안에서 active 계정 한 행을 넣습니다.
func insertActiveAccount(ctx context.Context, tx pgx.Tx) error {
	_, err := tx.Exec(ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', now())`, accountA)
	return err
}

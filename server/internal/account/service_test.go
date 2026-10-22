package account_test

import (
	"bytes"
	"context"
	"log/slog"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// 이 파일의 테스트는 전역 account.CurrentDocuments를 바꿔 끼우는 것이 있어 t.Parallel을 쓰지 않습니다.

var testNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

// revokerCall은 fakeRevoker가 받은 호출 하나입니다.
type revokerCall struct {
	ids []int64
	// ctxErr는 받은 ctx의 Err()입니다.
	ctxErr error
}

// fakeRevoker는 Revoker 대역입니다. 받은 호출을 기록합니다.
type fakeRevoker struct {
	mu       sync.Mutex
	recorded []revokerCall
	// beforeAttempt가 있으면 ctx를 기록하기 전에 불립니다(호출자 ctx 취소 시뮬레이션).
	beforeAttempt func()
	// onAttempt가 있으면 호출을 기록한 뒤 불립니다.
	onAttempt func(ids []int64)
}

func (f *fakeRevoker) Attempt(ctx context.Context, ids []int64) {
	if f.beforeAttempt != nil {
		f.beforeAttempt()
	}
	f.mu.Lock()
	f.recorded = append(f.recorded, revokerCall{ids: ids, ctxErr: ctx.Err()})
	f.mu.Unlock()
	if f.onAttempt != nil {
		f.onAttempt(ids)
	}
}

func (f *fakeRevoker) calls() []revokerCall {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]revokerCall(nil), f.recorded...)
}

type fixture struct {
	ctx     context.Context
	pool    *pgxpool.Pool
	clk     *clocktest.Fake
	revoker *fakeRevoker
	logs    *bytes.Buffer
	service *account.Service
	id      uuid.UUID
}

// newFixture는 active 계정 하나(last_active_at = testNow)를 가진 서비스를 만듭니다.
func newFixture(t *testing.T) *fixture {
	t.Helper()
	ctx := context.Background()
	pool := dbtest.New(t)
	clk := clocktest.New(testNow)
	revoker := &fakeRevoker{}

	id, err := uuid.NewV7()
	require.NoError(t, err)
	require.NoError(t, authdb.New(pool).CreateAccount(ctx, authdb.CreateAccountParams{ID: id, LastActiveAt: testNow}))

	logs := &bytes.Buffer{}
	return &fixture{
		ctx: ctx, pool: pool, clk: clk, revoker: revoker, logs: logs, id: id,
		service: account.NewService(pool, revoker, clk, slog.New(slog.NewJSONHandler(logs, nil))),
	}
}

func (f *fixture) lastActiveAt(t *testing.T) time.Time {
	t.Helper()
	var got time.Time
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT last_active_at FROM accounts WHERE id = $1`, f.id).Scan(&got))
	return got
}

func (f *fixture) status(t *testing.T) string {
	t.Helper()
	return f.statusOf(t, f.id)
}

func (f *fixture) statusOf(t *testing.T, id uuid.UUID) string {
	t.Helper()
	var got string
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT status FROM accounts WHERE id = $1`, id).Scan(&got))
	return got
}

func (f *fixture) consentCount(t *testing.T) int {
	t.Helper()
	var n int
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT count(*) FROM consents WHERE account_id = $1`, f.id).Scan(&n))
	return n
}

func allCurrent() []account.ConsentDocument {
	return []account.ConsentDocument{
		{Document: account.Terms, Version: account.CurrentDocuments[account.Terms]},
		{Document: account.Privacy, Version: account.CurrentDocuments[account.Privacy]},
	}
}

func TestAccess_NewAccountRequiresConsent(t *testing.T) {
	f := newFixture(t)

	got, err := f.service.Access(f.ctx, f.id)

	require.NoError(t, err)
	assert.Equal(t, account.StatusActive, got.Status)
	assert.True(t, got.ConsentRequired)
}

func TestAccess_TouchesLastActiveAtMostOncePerDay(t *testing.T) {
	f := newFixture(t)

	f.clk.Set(testNow.Add(23 * time.Hour))
	_, err := f.service.Access(f.ctx, f.id)
	require.NoError(t, err)
	assert.True(t, testNow.Equal(f.lastActiveAt(t)), "23시간 뒤에는 갱신하지 않습니다")

	later := testNow.Add(24*time.Hour + time.Second)
	f.clk.Set(later)
	_, err = f.service.Access(f.ctx, f.id)
	require.NoError(t, err)
	assert.True(t, later.Equal(f.lastActiveAt(t)), "24시간 1초 뒤에는 갱신합니다")
}

func TestMe_ListsOnlyMissingCurrentDocuments(t *testing.T) {
	f := newFixture(t)

	before, err := f.service.Me(f.ctx, f.id)
	require.NoError(t, err)
	assert.Equal(t, f.id, before.AccountID)
	assert.Equal(t, []account.ConsentDocument{{Document: account.Privacy, Version: "1"}, {Document: account.Terms, Version: "1"}}, before.RequiredConsents)

	require.NoError(t, f.service.AgreeConsents(f.ctx, f.id, []account.ConsentDocument{{Document: account.Terms, Version: "1"}}))

	got, err := f.service.Me(f.ctx, f.id)
	require.NoError(t, err)
	assert.Equal(t, []account.ConsentDocument{{Document: account.Privacy, Version: "1"}}, got.RequiredConsents)
	assert.True(t, got.ConsentRequired)
}

func TestAgreeConsents_AllCurrentClearsRequirement(t *testing.T) {
	f := newFixture(t)

	require.NoError(t, f.service.AgreeConsents(f.ctx, f.id, allCurrent()))
	// 같은 문서를 다시 동의해도 성공합니다.
	require.NoError(t, f.service.AgreeConsents(f.ctx, f.id, allCurrent()))

	got, err := f.service.Access(f.ctx, f.id)
	require.NoError(t, err)
	assert.False(t, got.ConsentRequired)
	assert.Equal(t, 2, f.consentCount(t))
}

func TestAgreeConsents_StaleVersionStoresNothing(t *testing.T) {
	f := newFixture(t)

	err := f.service.AgreeConsents(f.ctx, f.id, []account.ConsentDocument{
		{Document: account.Terms, Version: "1"},
		{Document: account.Privacy, Version: "0"},
	})

	var mismatch *account.ConsentVersionMismatchError
	require.ErrorAs(t, err, &mismatch)
	assert.Equal(t, 1, mismatch.Index)
	assert.Zero(t, f.consentCount(t), "terms도 저장하지 않습니다")
}

func TestAgreeConsents_UnknownAccountIsNotFound(t *testing.T) {
	f := newFixture(t)

	err := f.service.AgreeConsents(f.ctx, uuid.New(), allCurrent())

	assert.ErrorIs(t, err, account.ErrNotFound)
}

func TestAgreeConsents_BumpedVersionRequiresAgain(t *testing.T) {
	f := newFixture(t)
	require.NoError(t, f.service.AgreeConsents(f.ctx, f.id, allCurrent()))

	original := account.CurrentDocuments
	account.CurrentDocuments = map[account.Document]string{account.Terms: "2", account.Privacy: "1"}
	t.Cleanup(func() { account.CurrentDocuments = original })

	got, err := f.service.Me(f.ctx, f.id)
	require.NoError(t, err)
	assert.True(t, got.ConsentRequired)
	assert.Equal(t, []account.ConsentDocument{{Document: account.Terms, Version: "2"}}, got.RequiredConsents)

	require.NoError(t, f.service.AgreeConsents(f.ctx, f.id, []account.ConsentDocument{{Document: account.Terms, Version: "2"}}))
	after, err := f.service.Access(f.ctx, f.id)
	require.NoError(t, err)
	assert.False(t, after.ConsentRequired)
}

func TestAccess_UnknownAccountIsNotFound(t *testing.T) {
	f := newFixture(t)

	_, err := f.service.Access(f.ctx, uuid.New())
	assert.ErrorIs(t, err, account.ErrNotFound)

	_, err = f.service.Me(f.ctx, uuid.New())
	assert.ErrorIs(t, err, account.ErrNotFound)
}

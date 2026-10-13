package account_test

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"sync"
	"sync/atomic"
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

// fakeSessions는 SessionEnder 대역입니다. 호출 횟수를 세고 지정한 오류를 돌려줍니다.
type fakeSessions struct {
	revokeCalls     atomic.Int32
	disconnectCalls atomic.Int32
	disconnectErr   error
}

func (f *fakeSessions) RevokeAllSessions(context.Context, uuid.UUID) error {
	f.revokeCalls.Add(1)
	return nil
}

func (f *fakeSessions) DisconnectProviders(context.Context, uuid.UUID) error {
	f.disconnectCalls.Add(1)
	return f.disconnectErr
}

type fixture struct {
	ctx      context.Context
	pool     *pgxpool.Pool
	clk      *clocktest.Fake
	sessions *fakeSessions
	logs     *bytes.Buffer
	service  *account.Service
	id       uuid.UUID
}

// newFixture는 active 계정 하나(last_active_at = testNow)를 가진 서비스를 만듭니다.
func newFixture(t *testing.T) *fixture {
	t.Helper()
	ctx := context.Background()
	pool := dbtest.New(t)
	clk := clocktest.New(testNow)
	sessions := &fakeSessions{}
	logs := &bytes.Buffer{}

	id, err := uuid.NewV7()
	require.NoError(t, err)
	require.NoError(t, authdb.New(pool).CreateAccount(ctx, authdb.CreateAccountParams{ID: id, LastActiveAt: testNow}))

	return &fixture{
		ctx: ctx, pool: pool, clk: clk, sessions: sessions, logs: logs, id: id,
		service: account.NewService(pool, sessions, clk, slog.New(slog.NewTextHandler(logs, nil))),
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
	var got string
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT status FROM accounts WHERE id = $1`, f.id).Scan(&got))
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
	assert.Nil(t, got.DeletionScheduledAt)
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

func TestRequestDeletion_SchedulesAndEndsSessions(t *testing.T) {
	f := newFixture(t)

	got, err := f.service.RequestDeletion(f.ctx, f.id)

	require.NoError(t, err)
	assert.True(t, testNow.Add(30*24*time.Hour).Equal(got))
	assert.Equal(t, "pending_deletion", f.status(t))
	assert.EqualValues(t, 1, f.sessions.revokeCalls.Load())
	assert.EqualValues(t, 1, f.sessions.disconnectCalls.Load())

	access, err := f.service.Access(f.ctx, f.id)
	require.NoError(t, err)
	assert.Equal(t, account.StatusPendingDeletion, access.Status)
	require.NotNil(t, access.DeletionScheduledAt)
	assert.True(t, got.Equal(*access.DeletionScheduledAt))
}

func TestRequestDeletion_IsIdempotent(t *testing.T) {
	f := newFixture(t)
	first, err := f.service.RequestDeletion(f.ctx, f.id)
	require.NoError(t, err)

	f.clk.Advance(48 * time.Hour)
	second, err := f.service.RequestDeletion(f.ctx, f.id)

	require.NoError(t, err)
	assert.True(t, first.Equal(second), "기존 예정일을 그대로 돌려줍니다")
	assert.EqualValues(t, 1, f.sessions.revokeCalls.Load())
	assert.EqualValues(t, 1, f.sessions.disconnectCalls.Load())
}

func TestRequestDeletion_ConcurrentCallsEndSessionsOnce(t *testing.T) {
	f := newFixture(t)

	const callers = 5
	results := make([]time.Time, callers)
	errs := make([]error, callers)
	var wg sync.WaitGroup
	for i := range callers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results[i], errs[i] = f.service.RequestDeletion(f.ctx, f.id)
		}()
	}
	wg.Wait()

	for i := range callers {
		require.NoError(t, errs[i])
		assert.True(t, results[0].Equal(results[i]))
	}
	assert.EqualValues(t, 1, f.sessions.revokeCalls.Load())
	assert.EqualValues(t, 1, f.sessions.disconnectCalls.Load())
}

func TestRequestDeletion_SessionEndFailureStillSchedules(t *testing.T) {
	f := newFixture(t)
	f.sessions.disconnectErr = errors.New("kakao unlink 실패")

	got, err := f.service.RequestDeletion(f.ctx, f.id)

	require.NoError(t, err)
	assert.True(t, testNow.Add(30*24*time.Hour).Equal(got))
	assert.Equal(t, "pending_deletion", f.status(t))
	assert.Contains(t, f.logs.String(), "level=WARN")
	assert.Contains(t, f.logs.String(), f.id.String())
	assert.Contains(t, f.logs.String(), "*errors.errorString")
	assert.NotContains(t, f.logs.String(), "kakao unlink 실패", "오류 문구는 남기지 않습니다")
}

func TestRequestDeletion_UnknownAccountIsNotFound(t *testing.T) {
	f := newFixture(t)

	_, err := f.service.RequestDeletion(f.ctx, uuid.New())

	assert.ErrorIs(t, err, account.ErrNotFound)
	assert.Zero(t, f.sessions.revokeCalls.Load())
}

func TestAccess_UnknownAccountIsNotFound(t *testing.T) {
	f := newFixture(t)

	_, err := f.service.Access(f.ctx, uuid.New())
	assert.ErrorIs(t, err, account.ErrNotFound)

	_, err = f.service.Me(f.ctx, uuid.New())
	assert.ErrorIs(t, err, account.ErrNotFound)
}

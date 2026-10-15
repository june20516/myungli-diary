package profile

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile/honorific"
)

// fakeCharts는 ChartChecker 대역입니다. 호출 횟수와 마지막 asOf를 기록합니다.
type fakeCharts struct {
	mu    sync.Mutex
	err   error
	calls int
	asOf  LocalDate
}

func (f *fakeCharts) Chart(_ context.Context, _ Birth, asOf LocalDate) (*enginev1.ChartResponse, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	f.asOf = asOf
	if f.err != nil {
		return nil, f.err
	}
	return &enginev1.ChartResponse{}, nil
}

func (f *fakeCharts) callCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

type serviceFixture struct {
	svc       *Service
	pool      *pgxpool.Pool
	charts    *fakeCharts
	clock     *clocktest.Fake
	accountID uuid.UUID
}

func newServiceFixture(t *testing.T) *serviceFixture {
	t.Helper()
	pool := dbtest.New(t)
	accountID := uuid.New()
	now := time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC)
	err := authdb.New(pool).CreateAccount(context.Background(), authdb.CreateAccountParams{ID: accountID, LastActiveAt: now})
	require.NoError(t, err)
	charts := &fakeCharts{}
	clk := clocktest.New(now)
	return &serviceFixture{svc: NewService(pool, charts, clk), pool: pool, charts: charts, clock: clk, accountID: accountID}
}

func validProfile() Profile {
	return Profile{
		Honorific:       "민지",
		Language:        "ko",
		CurrentTimezone: "Asia/Seoul",
		Birth:           validBirth(),
		Notification:    Notification{Status: NotifyDisabled},
	}
}

func requireHonorificRejected(t *testing.T, err error, want honorific.Code) {
	t.Helper()
	requireViolation(t, err, HonorificRejected, "/honorific", NoStatusRule)
	var ve *ValidationError
	require.True(t, errors.As(err, &ve))
	assert.Equal(t, want, ve.Honorific)
}

func profileCount(t *testing.T, f *serviceFixture) int {
	t.Helper()
	var n int
	require.NoError(t, f.pool.QueryRow(context.Background(), `SELECT count(*) FROM profiles`).Scan(&n))
	return n
}

func TestPut_CreatesAndReturnsWarnings(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	in := validProfile()
	in.Honorific = "민지님"
	in.Birth.PlaceStatus = PlaceCity
	in.Birth.CityID = seoulID
	in.Birth.TimeStatus = TimeKnown
	in.Birth.Time = &LocalTime{Hour: 9, Minute: 30}
	in.Notification = Notification{Status: NotifyEnabled, Time: &LocalTime{Hour: 8, Minute: 5}}

	saved, err := f.svc.Put(ctx, f.accountID, in)
	require.NoError(t, err)

	assert.Equal(t, []honorific.Code{honorific.SuffixStripped}, saved.Warnings)
	assert.Equal(t, "민지", saved.Profile.Honorific)
	assert.Equal(t, 1, f.charts.callCount())
	exists, err := f.svc.Exists(ctx, f.accountID)
	require.NoError(t, err)
	assert.True(t, exists)

	got, err := f.svc.Get(ctx, f.accountID)
	require.NoError(t, err)
	assert.Equal(t, saved.Profile, got)
	assert.Equal(t, &LocalTime{Hour: 9, Minute: 30}, got.Birth.Time)
	assert.Equal(t, &LocalTime{Hour: 8, Minute: 5}, got.Notification.Time)
	require.NotNil(t, got.Birth.Longitude)
	assert.InDelta(t, 126.98, *got.Birth.Longitude, 0.1)
}

func TestPut_ConcurrentFirstSaveKeepsOneRow(t *testing.T) {
	f := newServiceFixture(t)
	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := range errs {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, errs[i] = f.svc.Put(context.Background(), f.accountID, validProfile())
		}()
	}
	wg.Wait()

	require.NoError(t, errs[0])
	require.NoError(t, errs[1])
	assert.Equal(t, 1, profileCount(t, f))
}

func TestPut_RejectsHonorific(t *testing.T) {
	f := newServiceFixture(t)
	in := validProfile()
	in.Honorific = "{name}"

	_, err := f.svc.Put(context.Background(), f.accountID, in)

	requireHonorificRejected(t, err, honorific.InvalidChar)
	assert.Equal(t, 0, profileCount(t, f))
	assert.Equal(t, 0, f.charts.callCount())
}

func TestPut_EngineInvalidIsBirthInvalid(t *testing.T) {
	f := newServiceFixture(t)
	f.charts.err = engine.ErrInvalidArgument

	_, err := f.svc.Put(context.Background(), f.accountID, validProfile())

	requireViolation(t, err, BirthInvalid, "/birth", NoStatusRule)
	assert.Equal(t, 0, profileCount(t, f))
}

func TestPut_EngineOutOfRangeIsBirthOutOfRange(t *testing.T) {
	f := newServiceFixture(t)
	f.charts.err = engine.ErrOutOfRange

	_, err := f.svc.Put(context.Background(), f.accountID, validProfile())

	requireViolation(t, err, BirthOutOfRange, "/birth/date", NoStatusRule)
	assert.Equal(t, 0, profileCount(t, f))
}

func TestPut_EngineUnavailablePropagates(t *testing.T) {
	f := newServiceFixture(t)
	f.charts.err = engine.ErrUnavailable

	_, err := f.svc.Put(context.Background(), f.accountID, validProfile())

	require.ErrorIs(t, err, engine.ErrUnavailable)
	var ve *ValidationError
	assert.False(t, errors.As(err, &ve))
	assert.Equal(t, 0, profileCount(t, f))
}

func TestPut_SameBirthSkipsEngine(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	_, err := f.svc.Put(ctx, f.accountID, validProfile())
	require.NoError(t, err)

	changed := validProfile()
	changed.Honorific = "수아"
	_, err = f.svc.Put(ctx, f.accountID, changed)
	require.NoError(t, err)

	assert.Equal(t, 1, f.charts.callCount())
}

func TestPut_AsOfUsesCurrentTimezoneToday(t *testing.T) {
	f := newServiceFixture(t)
	f.clock.Set(time.Date(2026, 10, 15, 15, 30, 0, 0, time.UTC))

	_, err := f.svc.Put(context.Background(), f.accountID, validProfile())
	require.NoError(t, err)

	assert.Equal(t, LocalDate{Year: 2026, Month: 10, Day: 16}, f.charts.asOf)
}

func TestPut_ValidationFailuresSkipEngineAndStore(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()

	in := validProfile()
	in.CurrentTimezone = "Mars/Base"
	_, err := f.svc.Put(ctx, f.accountID, in)
	requireViolation(t, err, TimezoneInvalid, "/currentTimezone", NoStatusRule)

	in = validProfile()
	in.Birth.Date = LocalDate{Year: 2023, Month: 2, Day: 29}
	_, err = f.svc.Put(ctx, f.accountID, in)
	requireViolation(t, err, DateInvalid, "/birth/date", NoStatusRule)

	in = validProfile()
	in.Notification = Notification{Status: NotifyEnabled}
	_, err = f.svc.Put(ctx, f.accountID, in)
	requireViolation(t, err, Inconsistent, "/notification/time", RequiredByStatus)

	assert.Equal(t, 0, f.charts.callCount())
	assert.Equal(t, 0, profileCount(t, f))
}

func TestPatch_TimezoneOnlySkipsEngine(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	_, err := f.svc.Put(ctx, f.accountID, validProfile())
	require.NoError(t, err)

	saved, err := f.svc.Patch(ctx, f.accountID, Patch{CurrentTimezone: ptr("America/New_York")})
	require.NoError(t, err)

	assert.Equal(t, 1, f.charts.callCount())
	assert.Equal(t, "America/New_York", saved.Profile.CurrentTimezone)
	assert.Equal(t, "민지", saved.Profile.Honorific)
	assert.Nil(t, saved.Warnings)
	got, err := f.svc.Get(ctx, f.accountID)
	require.NoError(t, err)
	assert.Equal(t, "America/New_York", got.CurrentTimezone)
}

func TestPatch_SameBirthSkipsEngine(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	_, err := f.svc.Put(ctx, f.accountID, validProfile())
	require.NoError(t, err)

	same := validBirth()
	_, err = f.svc.Patch(ctx, f.accountID, Patch{Birth: &same})
	require.NoError(t, err)
	assert.Equal(t, 1, f.charts.callCount())

	other := validBirth()
	other.Gender = "male"
	_, err = f.svc.Patch(ctx, f.accountID, Patch{Birth: &other})
	require.NoError(t, err)
	assert.Equal(t, 2, f.charts.callCount())
}

func TestPatch_BirthAndNotificationAreReplacedWhole(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	in := validProfile()
	in.Notification = Notification{Status: NotifyEnabled, Time: &LocalTime{Hour: 8}}
	_, err := f.svc.Put(ctx, f.accountID, in)
	require.NoError(t, err)

	saved, err := f.svc.Patch(ctx, f.accountID, Patch{Notification: &Notification{Status: NotifyDisabled}})
	require.NoError(t, err)

	assert.Equal(t, Notification{Status: NotifyDisabled}, saved.Profile.Notification)
}

func TestPatch_HonorificWarnings(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	_, err := f.svc.Put(ctx, f.accountID, validProfile())
	require.NoError(t, err)

	saved, err := f.svc.Patch(ctx, f.accountID, Patch{Honorific: ptr("수아님")})
	require.NoError(t, err)

	assert.Equal(t, "수아", saved.Profile.Honorific)
	assert.Equal(t, []honorific.Code{honorific.SuffixStripped}, saved.Warnings)
}

func TestPatch_LanguageChangeRechecksHonorific(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	in := validProfile()
	in.Language = "ja"
	in.Honorific = "ゆき"
	_, err := f.svc.Put(ctx, f.accountID, in)
	require.NoError(t, err)

	saved, err := f.svc.Patch(ctx, f.accountID, Patch{Language: ptr("ko")})
	require.NoError(t, err)
	assert.Equal(t, "ko", saved.Profile.Language)

	long := validProfile()
	long.Language = "en"
	long.Honorific = "Abcdefghijk" // 11자: en은 통과, ko는 10자까지
	_, err = f.svc.Put(ctx, f.accountID, long)
	require.NoError(t, err)

	_, err = f.svc.Patch(ctx, f.accountID, Patch{Language: ptr("ko")})
	requireHonorificRejected(t, err, honorific.TooLong)
	got, err := f.svc.Get(ctx, f.accountID)
	require.NoError(t, err)
	assert.Equal(t, "en", got.Language, "거부되면 저장되지 않습니다")
}

func TestPatch_MissingProfileIsNotFound(t *testing.T) {
	f := newServiceFixture(t)

	_, err := f.svc.Patch(context.Background(), f.accountID, Patch{Language: ptr("en")})
	require.ErrorIs(t, err, ErrNotFound)

	_, err = f.svc.Get(context.Background(), f.accountID)
	require.ErrorIs(t, err, ErrNotFound)

	exists, err := f.svc.Exists(context.Background(), f.accountID)
	require.NoError(t, err)
	assert.False(t, exists)
}

func TestAnonymizedProfileIsTreatedAsMissing(t *testing.T) {
	f := newServiceFixture(t)
	ctx := context.Background()
	_, err := f.svc.Put(ctx, f.accountID, validProfile())
	require.NoError(t, err)
	_, err = f.pool.Exec(ctx, `UPDATE profiles SET anonymized_at = $2 WHERE account_id = $1`, f.accountID, f.clock.Now())
	require.NoError(t, err)
	calls := f.charts.callCount()

	_, err = f.svc.Get(ctx, f.accountID)
	require.ErrorIs(t, err, ErrNotFound)
	_, err = f.svc.Patch(ctx, f.accountID, Patch{Language: ptr("en")})
	require.ErrorIs(t, err, ErrNotFound)
	_, err = f.svc.Put(ctx, f.accountID, validProfile())
	require.ErrorIs(t, err, ErrNotFound)
	exists, err := f.svc.Exists(ctx, f.accountID)
	require.NoError(t, err)
	assert.False(t, exists)

	assert.Equal(t, calls, f.charts.callCount(), "익명화된 프로필에는 엔진을 부르지 않습니다")
	var anonymized bool
	require.NoError(t, f.pool.QueryRow(ctx, `SELECT anonymized_at IS NOT NULL FROM profiles`).Scan(&anonymized))
	assert.True(t, anonymized)
}

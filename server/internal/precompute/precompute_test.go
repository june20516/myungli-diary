package precompute_test

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/precompute"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// dailyCall과 monthCall은 가짜 Fortune이 받은 호출입니다.
type dailyCall struct {
	Date     profile.LocalDate
	Timezone string
}

type monthCall struct {
	Year, Month int
	Timezone    string
}

// fakeFortune은 호출을 기록하고 동시 실행 수의 최대값을 잽니다.
type fakeFortune struct {
	mu          sync.Mutex
	dailies     []dailyCall
	months      []monthCall
	failDaily   func(timezone string, date profile.LocalDate) bool
	hold        time.Duration
	running     int
	maxRunning  int
	dailyCounts map[string]int // 출생 시간대(계정 구분용)별 Daily 호출 수
}

func (f *fakeFortune) enter() {
	f.mu.Lock()
	f.running++
	f.maxRunning = max(f.maxRunning, f.running)
	f.mu.Unlock()
}

func (f *fakeFortune) leave() {
	f.mu.Lock()
	f.running--
	f.mu.Unlock()
}

func (f *fakeFortune) Daily(_ context.Context, b profile.Birth, date profile.LocalDate, currentTimezone string) (*enginev1.DailyResponse, error) {
	f.enter()
	defer f.leave()
	if f.hold > 0 {
		time.Sleep(f.hold)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.dailies = append(f.dailies, dailyCall{Date: date, Timezone: currentTimezone})
	if f.dailyCounts == nil {
		f.dailyCounts = map[string]int{}
	}
	f.dailyCounts[b.Timezone]++
	if f.failDaily != nil && f.failDaily(currentTimezone, date) {
		return nil, errors.New("엔진 실패")
	}
	return &enginev1.DailyResponse{}, nil
}

func (f *fakeFortune) Month(_ context.Context, _ profile.Birth, year, month int, currentTimezone string) (*enginev1.MonthResponse, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.months = append(f.months, monthCall{Year: year, Month: month, Timezone: currentTimezone})
	return &enginev1.MonthResponse{}, nil
}

// lister는 메모리의 프로필을 계정 id 순으로 정렬해 after와 limit로 자릅니다. 받은 activeSince를 기록합니다.
type lister struct {
	items       []profile.ActiveProfile
	err         error
	activeSince time.Time
}

func (l *lister) list(_ context.Context, activeSince time.Time, after uuid.UUID, limit int32) ([]profile.ActiveProfile, error) {
	l.activeSince = activeSince
	if l.err != nil {
		return nil, l.err
	}
	sorted := slices.Clone(l.items)
	slices.SortFunc(sorted, func(a, b profile.ActiveProfile) int { return slices.Compare(a.AccountID[:], b.AccountID[:]) })
	var page []profile.ActiveProfile
	for _, item := range sorted {
		if slices.Compare(item.AccountID[:], after[:]) > 0 && len(page) < int(limit) {
			page = append(page, item)
		}
	}
	return page, nil
}

// user는 현재 시간대가 timezone인 프로필입니다. 출생 시간대에 label을 넣어 호출을 계정별로 셀 수 있게 합니다.
func user(timezone, label string) profile.ActiveProfile {
	return profile.ActiveProfile{
		AccountID: uuid.New(),
		Profile: profile.Profile{
			CurrentTimezone: timezone,
			Birth:           profile.Birth{Timezone: label},
		},
	}
}

type fixture struct {
	fortune *fakeFortune
	lister  *lister
}

func run(t *testing.T, now time.Time, users ...profile.ActiveProfile) (*fixture, precompute.Result, error) {
	t.Helper()
	f := &fixture{fortune: &fakeFortune{}, lister: &lister{items: users}}
	result, err := precompute.Run(context.Background(), precompute.Deps{
		Profiles: f.lister.list,
		Fortune:  f.fortune,
		Clock:    clocktest.New(now),
		Logger:   slog.New(slog.DiscardHandler),
	})
	return f, result, err
}

func runWith(t *testing.T, f *fixture, now time.Time) (precompute.Result, error) {
	t.Helper()
	return precompute.Run(context.Background(), precompute.Deps{
		Profiles: f.lister.list,
		Fortune:  f.fortune,
		Clock:    clocktest.New(now),
		Logger:   slog.New(slog.DiscardHandler),
	})
}

func date(y, m, d int) profile.LocalDate { return profile.LocalDate{Year: y, Month: m, Day: d} }

func TestRun_SelectsUsersInLocalWindow(t *testing.T) {
	now := time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)
	f, result, err := run(t, now,
		user("Asia/Seoul", "a"), user("Asia/Tokyo", "b"), user("Europe/London", "c"), user("Asia/Kathmandu", "d"))
	require.NoError(t, err)

	assert.ElementsMatch(t, []dailyCall{
		{Date: date(2026, 11, 4), Timezone: "Asia/Seoul"},
		{Date: date(2026, 11, 4), Timezone: "Asia/Tokyo"},
	}, f.fortune.dailies)
	assert.Empty(t, f.fortune.months)
	assert.Equal(t, precompute.Result{Candidates: 4, Targets: 2, Succeeded: 2}, result)
}

func TestRun_WindowBoundaries(t *testing.T) {
	seoul := time.FixedZone("KST", 9*60*60)
	cases := map[string]struct {
		local  time.Time
		target bool
	}{
		"21:59:59": {time.Date(2026, 11, 3, 21, 59, 59, 0, seoul), false},
		"22:00:00": {time.Date(2026, 11, 3, 22, 0, 0, 0, seoul), true},
		"22:29:59": {time.Date(2026, 11, 3, 22, 29, 59, 0, seoul), true},
		"22:30:00": {time.Date(2026, 11, 3, 22, 30, 0, 0, seoul), false},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			f, result, err := run(t, c.local.UTC(), user("Asia/Seoul", "a"))
			require.NoError(t, err)
			if c.target {
				assert.Len(t, f.fortune.dailies, 1)
				assert.Equal(t, 1, result.Targets)
			} else {
				assert.Empty(t, f.fortune.dailies)
				assert.Equal(t, precompute.Result{Candidates: 1}, result)
			}
		})
	}
}

func TestRun_MonthOnLastDay(t *testing.T) {
	f, _, err := run(t, time.Date(2026, 12, 31, 13, 10, 0, 0, time.UTC), user("Asia/Seoul", "a"))
	require.NoError(t, err)
	assert.Equal(t, []dailyCall{{Date: date(2027, 1, 1), Timezone: "Asia/Seoul"}}, f.fortune.dailies)
	assert.Equal(t, []monthCall{{Year: 2027, Month: 1, Timezone: "Asia/Seoul"}}, f.fortune.months)

	other, _, err := run(t, time.Date(2026, 11, 3, 13, 10, 0, 0, time.UTC), user("Asia/Seoul", "a"))
	require.NoError(t, err)
	assert.Empty(t, other.fortune.months)
}

func TestRun_DSTNextDate(t *testing.T) {
	// America/New_York 2027-03-13 22:10 EST. 다음 날 02:00에 EDT로 바뀝니다.
	f, _, err := run(t, time.Date(2027, 3, 14, 3, 10, 0, 0, time.UTC), user("America/New_York", "a"))
	require.NoError(t, err)
	assert.Equal(t, []dailyCall{{Date: date(2027, 3, 14), Timezone: "America/New_York"}}, f.fortune.dailies)
}

func TestRun_DSTSameDayEvening(t *testing.T) {
	// America/New_York 2027-03-14 22:10 EDT(전환 당일 저녁, UTC-4).
	f, _, err := run(t, time.Date(2027, 3, 15, 2, 10, 0, 0, time.UTC), user("America/New_York", "a"))
	require.NoError(t, err)
	assert.Equal(t, []dailyCall{{Date: date(2027, 3, 15), Timezone: "America/New_York"}}, f.fortune.dailies)
}

func TestRun_CanceledContextLogsCountsAndFails(t *testing.T) {
	var logs bytes.Buffer
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err := precompute.Run(ctx, precompute.Deps{
		Profiles: (&lister{items: []profile.ActiveProfile{user("Asia/Seoul", "a")}}).list,
		Fortune:  &fakeFortune{},
		Clock:    clocktest.New(time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)),
		Logger:   slog.New(slog.NewTextHandler(&logs, nil)),
	})
	require.ErrorIs(t, err, context.Canceled)
	assert.Contains(t, logs.String(), "candidates=")
}

func TestRun_InvalidTimezoneCountedSeparately(t *testing.T) {
	now := time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)
	f, result, err := run(t, now, user("Nowhere/Invalid", "a"), user("Asia/Seoul", "b"))
	require.NoError(t, err)
	assert.Equal(t, []dailyCall{{Date: date(2026, 11, 4), Timezone: "Asia/Seoul"}}, f.fortune.dailies)
	assert.Equal(t, precompute.Result{Candidates: 2, Targets: 1, Succeeded: 1, InvalidTimezone: 1}, result)
}

// 시간대를 못 읽는 프로필만 있고 대상이 없는 실행은 Job 실패가 아닙니다(실행마다 경보가 나지 않게).
func TestRun_InvalidTimezoneAloneIsNotError(t *testing.T) {
	_, result, err := run(t, time.Date(2026, 11, 3, 3, 0, 0, 0, time.UTC), user("Nowhere/Invalid", "a"))
	require.NoError(t, err)
	assert.Equal(t, precompute.Result{Candidates: 1, InvalidTimezone: 1}, result)
}

func TestRun_PartialFailureSucceeds(t *testing.T) {
	now := time.Date(2026, 12, 31, 13, 15, 0, 0, time.UTC)
	f := &fixture{fortune: &fakeFortune{}, lister: &lister{items: []profile.ActiveProfile{
		user("Asia/Seoul", "a"), user("Asia/Tokyo", "b"), user("Asia/Pyongyang", "c"),
	}}}
	f.fortune.failDaily = func(timezone string, _ profile.LocalDate) bool { return timezone == "Asia/Tokyo" }

	result, err := runWith(t, f, now)
	require.NoError(t, err)
	assert.Equal(t, precompute.Result{Candidates: 3, Targets: 3, Succeeded: 2, Failed: 1}, result)
	// Daily가 실패한 도쿄는 Month를 부르지 않습니다.
	assert.Len(t, f.fortune.months, 2)
	for _, call := range f.fortune.months {
		assert.NotEqual(t, "Asia/Tokyo", call.Timezone)
	}
}

func TestRun_AllFailedIsError(t *testing.T) {
	now := time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)
	f := &fixture{fortune: &fakeFortune{}, lister: &lister{items: []profile.ActiveProfile{user("Asia/Seoul", "a"), user("Asia/Tokyo", "b")}}}
	f.fortune.failDaily = func(string, profile.LocalDate) bool { return true }

	result, err := runWith(t, f, now)
	require.ErrorIs(t, err, precompute.ErrAllFailed)
	assert.Equal(t, precompute.Result{Candidates: 2, Targets: 2, Failed: 2}, result)

	_, result, err = run(t, now)
	require.NoError(t, err)
	assert.Equal(t, precompute.Result{}, result)
}

func TestRun_PagesThroughAll(t *testing.T) {
	now := time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)
	users := make([]profile.ActiveProfile, 0, 1203)
	for i := range 1203 {
		users = append(users, user("Asia/Seoul", fmt.Sprint(i)))
	}
	f, result, err := run(t, now, users...)
	require.NoError(t, err)
	assert.Equal(t, 1203, result.Succeeded)
	require.Len(t, f.fortune.dailyCounts, 1203)
	for label, count := range f.fortune.dailyCounts {
		assert.Equal(t, 1, count, label)
	}
}

func TestRun_LimitsConcurrency(t *testing.T) {
	now := time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)
	users := make([]profile.ActiveProfile, 0, 40)
	for i := range 40 {
		users = append(users, user("Asia/Seoul", fmt.Sprint(i)))
	}
	f := &fixture{fortune: &fakeFortune{hold: 20 * time.Millisecond}, lister: &lister{items: users}}

	_, err := runWith(t, f, now)
	require.NoError(t, err)
	assert.LessOrEqual(t, f.fortune.maxRunning, 8)
	assert.Greater(t, f.fortune.maxRunning, 1)
}

func TestRun_ListErrorIsError(t *testing.T) {
	listErr := errors.New("DB 실패")
	f := &fixture{fortune: &fakeFortune{}, lister: &lister{err: listErr}}
	_, err := runWith(t, f, time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC))
	require.ErrorIs(t, err, listErr)
}

func TestRun_UsesActiveSince(t *testing.T) {
	now := time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC)
	f, _, err := run(t, now)
	require.NoError(t, err)
	assert.Equal(t, now.Add(-336*time.Hour), f.lister.activeSince)
}

// prepareCounter는 Prepare 호출 수와, 호출 시점에 이미 Fortune이 불렸는지를 기록합니다.
type prepareCounter struct {
	calls          int
	fortune        *fakeFortune
	calledAfterUse bool
	err            error
}

func (p *prepareCounter) prepare(context.Context) error {
	p.calls++
	p.fortune.mu.Lock()
	p.calledAfterUse = len(p.fortune.dailies) > 0
	p.fortune.mu.Unlock()
	return p.err
}

func runPrepared(t *testing.T, now time.Time, prepareErr error, users ...profile.ActiveProfile) (*fakeFortune, *prepareCounter, *bytes.Buffer, precompute.Result, error) {
	t.Helper()
	fortune := &fakeFortune{}
	counter := &prepareCounter{fortune: fortune, err: prepareErr}
	var logs bytes.Buffer
	result, err := precompute.Run(context.Background(), precompute.Deps{
		Profiles: (&lister{items: users}).list,
		Prepare:  counter.prepare,
		Fortune:  fortune,
		Clock:    clocktest.New(now),
		Logger:   slog.New(slog.NewTextHandler(&logs, nil)),
	})
	return fortune, counter, &logs, result, err
}

// 대상이 없으면 엔진 준비(버전 조회)를 하지 않습니다. 하루 48번 중 대부분의 실행이 여기에 해당합니다.
func TestRun_NoTargetsSkipsPrepare(t *testing.T) {
	_, counter, _, result, err := runPrepared(t, time.Date(2026, 11, 3, 3, 0, 0, 0, time.UTC), nil, user("Asia/Seoul", "a"))
	require.NoError(t, err)
	assert.Zero(t, counter.calls)
	assert.Equal(t, precompute.Result{Candidates: 1}, result)
}

func TestRun_PrepareOnceBeforeCompute(t *testing.T) {
	fortune, counter, _, _, err := runPrepared(t, time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC), nil,
		user("Asia/Seoul", "a"), user("Asia/Tokyo", "b"))
	require.NoError(t, err)
	assert.Equal(t, 1, counter.calls)
	assert.False(t, counter.calledAfterUse, "Prepare는 첫 계산 전에 불립니다")
	assert.Len(t, fortune.dailies, 2)
}

func TestRun_PrepareErrorIsErrorWithoutCompute(t *testing.T) {
	prepareErr := errors.New("엔진 버전 없음")
	fortune, _, logs, result, err := runPrepared(t, time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC), prepareErr, user("Asia/Seoul", "a"))
	require.ErrorIs(t, err, prepareErr)
	assert.Empty(t, fortune.dailies)
	assert.Equal(t, precompute.Result{Candidates: 1, Targets: 1}, result, "고른 대상은 계산하지 못해도 셉니다")
	assert.Contains(t, logs.String(), "precompute 완료")
}

func TestRun_LogsPhaseDurations(t *testing.T) {
	_, _, logs, _, err := runPrepared(t, time.Date(2026, 11, 3, 13, 15, 0, 0, time.UTC), nil, user("Asia/Seoul", "a"))
	require.NoError(t, err)
	for _, key := range []string{"list_ms=", "prepare_ms=", "compute_ms="} {
		assert.Contains(t, logs.String(), key)
	}
}

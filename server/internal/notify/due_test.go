package notify_test

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/notify"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

func mustLocation(t *testing.T, name string) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation(name)
	require.NoError(t, err)
	return loc
}

func TestDueAt(t *testing.T) {
	seoul := mustLocation(t, "Asia/Seoul")
	at := func(y, m, d, hh, mm, ss int) time.Time { return time.Date(y, time.Month(m), d, hh, mm, ss, 0, seoul) }
	cases := map[string]struct {
		now      time.Time
		notifyAt profile.LocalTime
		due      bool
		date     profile.LocalDate
		expire   time.Time
	}{
		"정각":           {at(2026, 11, 4, 7, 0, 0), profile.LocalTime{Hour: 7}, true, profile.LocalDate{Year: 2026, Month: 11, Day: 4}, at(2026, 11, 5, 0, 0, 0)},
		"1초 전":         {at(2026, 11, 4, 6, 59, 59), profile.LocalTime{Hour: 7}, false, profile.LocalDate{}, time.Time{}},
		"60분 뒤 경계 포함":  {at(2026, 11, 4, 8, 0, 0), profile.LocalTime{Hour: 7}, true, profile.LocalDate{Year: 2026, Month: 11, Day: 4}, at(2026, 11, 5, 0, 0, 0)},
		"60분 1초 뒤":     {at(2026, 11, 4, 8, 0, 1), profile.LocalTime{Hour: 7}, false, profile.LocalDate{}, time.Time{}},
		"자정을 넘는 창":     {at(2026, 11, 5, 0, 10, 0), profile.LocalTime{Hour: 23, Minute: 55}, true, profile.LocalDate{Year: 2026, Month: 11, Day: 4}, at(2026, 11, 5, 0, 0, 0)},
		"자정 뒤 아침 알림 전": {at(2026, 11, 5, 0, 10, 0), profile.LocalTime{Hour: 7}, false, profile.LocalDate{}, time.Time{}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			got, due, err := notify.DueAt(c.now.UTC(), "Asia/Seoul", c.notifyAt, 0, 0)
			require.NoError(t, err)
			assert.Equal(t, c.due, due)
			if c.due {
				assert.Equal(t, c.date, got.LocalDate)
				assert.True(t, got.Expire.Equal(c.expire), "expire = %v", got.Expire)
			}
		})
	}
}

// 2027-03-14 America/New_York은 02:00~03:00이 없습니다. Go는 02:30을 01:30 EST(06:30 UTC)로 정규화합니다.
func TestDueAt_NonexistentLocalTime(t *testing.T) {
	notifyAt := profile.LocalTime{Hour: 2, Minute: 30}
	got, due, err := notify.DueAt(time.Date(2027, 3, 14, 7, 10, 0, 0, time.UTC), "America/New_York", notifyAt, 0, 0)
	require.NoError(t, err)
	assert.True(t, due)
	assert.Equal(t, profile.LocalDate{Year: 2027, Month: 3, Day: 14}, got.LocalDate)

	_, due, err = notify.DueAt(time.Date(2027, 3, 14, 7, 31, 0, 0, time.UTC), "America/New_York", notifyAt, 0, 0)
	require.NoError(t, err)
	assert.False(t, due)
}

func TestDueAt_InvalidTimezone(t *testing.T) {
	_, _, err := notify.DueAt(time.Date(2026, 11, 4, 0, 0, 0, 0, time.UTC), "Nowhere/Invalid", profile.LocalTime{Hour: 7}, 0, 0)
	require.Error(t, err)
}

// America/Santiago 2026-09-06은 00:00이 없습니다(00:00 → 01:00). 현지 날짜와 만료가 하루 어긋나지 않아야 합니다.
func TestDueAt_MissingMidnight(t *testing.T) {
	santiago := mustLocation(t, "America/Santiago")
	cases := map[string]struct {
		now    time.Time
		date   profile.LocalDate
		expire time.Time
	}{
		"자정이 없는 날 아침": {time.Date(2026, 9, 6, 7, 10, 0, 0, santiago), profile.LocalDate{Year: 2026, Month: 9, Day: 6}, time.Date(2026, 9, 7, 0, 0, 0, 0, santiago)},
		"그 전날 아침":     {time.Date(2026, 9, 5, 7, 10, 0, 0, santiago), profile.LocalDate{Year: 2026, Month: 9, Day: 5}, time.Date(2026, 9, 6, 1, 0, 0, 0, santiago)},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			got, due, err := notify.DueAt(c.now, "America/Santiago", profile.LocalTime{Hour: 7}, 0, 0)
			require.NoError(t, err)
			require.True(t, due)
			assert.Equal(t, c.date, got.LocalDate)
			assert.True(t, got.Expire.Equal(c.expire), "expire = %v, want %v", got.Expire, c.expire)
		})
	}
}

// 가을 DST 끝(America/New_York 2026-11-01 01:00~02:00이 두 번)에도 그날 한 번 대상이 됩니다.
func TestDueAt_RepeatedLocalTime(t *testing.T) {
	got, due, err := notify.DueAt(time.Date(2026, 11, 1, 5, 40, 0, 0, time.UTC), "America/New_York", profile.LocalTime{Hour: 1, Minute: 30}, 0, 0)
	require.NoError(t, err)
	assert.True(t, due)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 11, Day: 1}, got.LocalDate)
}

// 보낼 시각은 고른 시각 + 오프셋이고, 그 시각이 lookahead 안에 오면 이번 실행이 맡습니다(D109).
func TestDueAt_OffsetAndLookahead(t *testing.T) {
	seoul := mustLocation(t, "Asia/Seoul")
	at := func(d, hh, mm, ss int) time.Time { return time.Date(2026, 11, d, hh, mm, ss, 0, seoul) }
	seven := profile.LocalTime{Hour: 7}
	cases := map[string]struct {
		now      time.Time
		notifyAt profile.LocalTime
		offset   time.Duration
		due      bool
		day      int
		sendAt   time.Time
	}{
		"오프셋 전에도 lookahead 안이면 맡음": {at(4, 7, 0, 0), seven, 4 * time.Minute, true, 4, at(4, 7, 4, 0)},
		"lookahead 끝은 다음 실행 몫":     {at(4, 7, 0, 0), seven, 5 * time.Minute, false, 0, time.Time{}},
		"lookahead 직전":             {at(4, 7, 0, 1), seven, 5 * time.Minute, true, 4, at(4, 7, 5, 0)},
		"고른 시각 전 실행도 오프셋 0이면 정각에":  {at(4, 6, 56, 0), seven, 0, true, 4, at(4, 7, 0, 0)},
		"보낼 시각부터 60분까지":            {at(4, 8, 9, 0), seven, 9 * time.Minute, true, 4, at(4, 7, 9, 0)},
		"보낼 시각 60분 뒤는 지남":          {at(4, 8, 9, 1), seven, 9 * time.Minute, false, 0, time.Time{}},
		"오프셋이 자정을 넘으면 고른 날짜":       {at(5, 0, 3, 0), profile.LocalTime{Hour: 23, Minute: 58}, 7 * time.Minute, true, 4, at(5, 0, 5, 0)},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			got, due, err := notify.DueAt(c.now.UTC(), "Asia/Seoul", c.notifyAt, c.offset, 5*time.Minute)
			require.NoError(t, err)
			require.Equal(t, c.due, due)
			if c.due {
				assert.Equal(t, profile.LocalDate{Year: 2026, Month: 11, Day: c.day}, got.LocalDate)
				assert.True(t, got.SendAt.Equal(c.sendAt), "sendAt = %v", got.SendAt)
				assert.False(t, got.SendAt.Before(atLocalSeoul(c.day, c.notifyAt, seoul)), "고른 시각보다 일찍 보내지 않습니다")
			}
		})
	}
}

func atLocalSeoul(day int, t profile.LocalTime, seoul *time.Location) time.Time {
	return time.Date(2026, 11, day, t.Hour, t.Minute, 0, 0, seoul)
}

// 오프셋은 [0, 10분)의 초 단위이고, 같은 계정은 늘 같으며, 계정들은 10분 안에 고르게 나뉩니다(D109 ①③).
func TestSpreadOffset(t *testing.T) {
	const accounts = 6000
	perMinute := make([]int, 10)
	for range accounts {
		id := uuid.Must(uuid.NewV7())
		offset := notify.SpreadOffset(id)
		require.Equal(t, offset, notify.SpreadOffset(id))
		require.GreaterOrEqual(t, offset, time.Duration(0))
		require.Less(t, offset, 10*time.Minute)
		require.Zero(t, offset%time.Second)
		perMinute[offset/time.Minute]++
	}
	for minute, n := range perMinute {
		assert.InDelta(t, accounts/10, n, accounts/10*0.2, "%d분대 %d명", minute, n)
	}
}

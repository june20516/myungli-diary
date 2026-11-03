package notify_test

import (
	"testing"
	"time"

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
			got, due, err := notify.DueAt(c.now.UTC(), "Asia/Seoul", c.notifyAt)
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
	got, due, err := notify.DueAt(time.Date(2027, 3, 14, 7, 10, 0, 0, time.UTC), "America/New_York", notifyAt)
	require.NoError(t, err)
	assert.True(t, due)
	assert.Equal(t, profile.LocalDate{Year: 2027, Month: 3, Day: 14}, got.LocalDate)

	_, due, err = notify.DueAt(time.Date(2027, 3, 14, 7, 31, 0, 0, time.UTC), "America/New_York", notifyAt)
	require.NoError(t, err)
	assert.False(t, due)
}

func TestDueAt_InvalidTimezone(t *testing.T) {
	_, _, err := notify.DueAt(time.Date(2026, 11, 4, 0, 0, 0, 0, time.UTC), "Nowhere/Invalid", profile.LocalTime{Hour: 7})
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
			got, due, err := notify.DueAt(c.now, "America/Santiago", profile.LocalTime{Hour: 7})
			require.NoError(t, err)
			require.True(t, due)
			assert.Equal(t, c.date, got.LocalDate)
			assert.True(t, got.Expire.Equal(c.expire), "expire = %v, want %v", got.Expire, c.expire)
		})
	}
}

// 가을 DST 끝(America/New_York 2026-11-01 01:00~02:00이 두 번)에도 그날 한 번 대상이 됩니다.
func TestDueAt_RepeatedLocalTime(t *testing.T) {
	got, due, err := notify.DueAt(time.Date(2026, 11, 1, 5, 40, 0, 0, time.UTC), "America/New_York", profile.LocalTime{Hour: 1, Minute: 30})
	require.NoError(t, err)
	assert.True(t, due)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 11, Day: 1}, got.LocalDate)
}

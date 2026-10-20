package billing

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func loadLocation(t *testing.T, name string) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation(name)
	require.NoError(t, err)
	return loc
}

func TestNextMidnight(t *testing.T) {
	seoul := loadLocation(t, "Asia/Seoul")
	newYork := loadLocation(t, "America/New_York")
	tests := []struct {
		name string
		now  time.Time
		loc  *time.Location
		want time.Time
	}{
		{"서울 23:59:30 -> 다음 날 00:00 KST", time.Date(2026, 10, 20, 23, 59, 30, 0, seoul), seoul, time.Date(2026, 10, 20, 15, 0, 0, 0, time.UTC)},
		{"서울 00:00:00 정각 -> 다음 날 00:00", time.Date(2026, 10, 21, 0, 0, 0, 0, seoul), seoul, time.Date(2026, 10, 21, 15, 0, 0, 0, time.UTC)},
		{"뉴욕 서머타임 시작일 12:00 -> 03-15 00:00 EDT", time.Date(2027, 3, 14, 12, 0, 0, 0, newYork), newYork, time.Date(2027, 3, 15, 4, 0, 0, 0, time.UTC)},
		{"UTC", time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC), time.UTC, time.Date(2026, 10, 21, 0, 0, 0, 0, time.UTC)},
		{"UTC 시각을 서울 날짜로 본다", time.Date(2026, 10, 20, 16, 0, 0, 0, time.UTC), seoul, time.Date(2026, 10, 21, 15, 0, 0, 0, time.UTC)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := nextMidnight(tt.now, tt.loc)
			assert.True(t, tt.want.Equal(got), "want %s got %s", tt.want, got)
			assert.True(t, got.After(tt.now))
		})
	}
}

package billing

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

const (
	testIOSProduct     = "test.ad_free.month"
	testAndroidProduct = "test.ad_free.month.android"
)

var testProducts = AdFreeCatalog([]string{testIOSProduct, testAndroidProduct})

func utc(year int, month time.Month, day, hour int) time.Time {
	return time.Date(year, month, day, hour, 0, 0, 0, time.UTC)
}

func TestAddMonths_OneMonth(t *testing.T) {
	tests := []struct {
		name string
		in   time.Time
		want time.Time
	}{
		{"같은 날 같은 시각", time.Date(2026, 1, 15, 10, 0, 0, 0, time.UTC), time.Date(2026, 2, 15, 10, 0, 0, 0, time.UTC)},
		{"1월 31일은 2월 마지막 날", time.Date(2026, 1, 31, 10, 30, 5, 0, time.UTC), time.Date(2026, 2, 28, 10, 30, 5, 0, time.UTC)},
		{"윤년 1월 31일은 2월 29일", time.Date(2028, 1, 31, 0, 0, 0, 0, time.UTC), time.Date(2028, 2, 29, 0, 0, 0, 0, time.UTC)},
		{"3월 31일은 4월 30일", time.Date(2026, 3, 31, 23, 59, 59, 0, time.UTC), time.Date(2026, 4, 30, 23, 59, 59, 0, time.UTC)},
		{"12월 31일은 다음 해 1월 31일", time.Date(2026, 12, 31, 8, 0, 0, 0, time.UTC), time.Date(2027, 1, 31, 8, 0, 0, 0, time.UTC)},
		{"UTC가 아닌 입력은 UTC 달력으로", time.Date(2026, 2, 1, 1, 0, 0, 0, time.FixedZone("KST", 9*3600)), time.Date(2026, 2, 28, 16, 0, 0, 0, time.UTC)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := addMonths(tt.in, 1)
			assert.True(t, got.Equal(tt.want), "got %v, want %v", got, tt.want)
			assert.Equal(t, time.UTC, got.Location())
		})
	}
}

func TestAddMonths(t *testing.T) {
	tests := []struct {
		name   string
		in     time.Time
		months int
		want   time.Time
	}{
		{"1개월은 addMonth와 같음", time.Date(2026, 1, 31, 10, 0, 0, 0, time.UTC), 1, time.Date(2026, 2, 28, 10, 0, 0, 0, time.UTC)},
		{"3개월 같은 날", time.Date(2026, 10, 5, 0, 0, 0, 0, time.UTC), 3, time.Date(2027, 1, 5, 0, 0, 0, 0, time.UTC)},
		{"3개월 뒤에 없는 날은 그 달 마지막 날", time.Date(2026, 11, 30, 0, 0, 0, 0, time.UTC), 3, time.Date(2027, 2, 28, 0, 0, 0, 0, time.UTC)},
		{"12개월은 다음 해 같은 날", time.Date(2028, 2, 29, 0, 0, 0, 0, time.UTC), 12, time.Date(2029, 2, 28, 0, 0, 0, 0, time.UTC)},
		{"UTC가 아닌 입력은 UTC 달력으로", time.Date(2026, 2, 1, 1, 0, 0, 0, time.FixedZone("KST", 9*3600)), 2, time.Date(2026, 3, 31, 16, 0, 0, 0, time.UTC)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := addMonths(tt.in, tt.months)
			assert.True(t, got.Equal(tt.want), "got %v, want %v", got, tt.want)
			assert.Equal(t, time.UTC, got.Location())
		})
	}
}

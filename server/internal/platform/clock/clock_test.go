package clock_test

import (
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

func TestSystem_ReturnsUTC(t *testing.T) {
	var c clock.Clock = clock.System{}
	if got := c.Now().Location(); got != time.UTC {
		t.Errorf("System.Now().Location() = %v, want UTC", got)
	}
}

func TestSystem_IsNearCurrentTime(t *testing.T) {
	before := time.Now()
	got := clock.System{}.Now()
	after := time.Now()

	if got.Before(before) || got.After(after) {
		t.Errorf("System.Now() = %v, want between %v and %v", got, before, after)
	}
}

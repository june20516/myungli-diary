package clocktest_test

import (
	"sync"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

func TestFake_SetAndAdvance(t *testing.T) {
	start := time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC)
	fake := clocktest.New(start)

	fake.Advance(90 * time.Minute)

	want := time.Date(2026, 10, 11, 1, 30, 0, 0, time.UTC)
	if got := fake.Now(); !got.Equal(want) {
		t.Errorf("Now() = %v, want %v", got, want)
	}

	reset := time.Date(2030, 1, 2, 3, 4, 5, 0, time.UTC)
	fake.Set(reset)
	if got := fake.Now(); !got.Equal(reset) {
		t.Errorf("Now() after Set = %v, want %v", got, reset)
	}
}

func TestFake_ConcurrentAccess(t *testing.T) {
	fake := clocktest.New(time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC))

	const workers = 100
	var wg sync.WaitGroup
	wg.Add(workers * 2)
	for range workers {
		go func() {
			defer wg.Done()
			fake.Advance(time.Second)
		}()
		go func() {
			defer wg.Done()
			_ = fake.Now()
		}()
	}
	wg.Wait()

	want := time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC).Add(workers * time.Second)
	if got := fake.Now(); !got.Equal(want) {
		t.Errorf("Now() after concurrent Advance = %v, want %v", got, want)
	}
}

func TestFake_NormalizesToUTC(t *testing.T) {
	kst := time.FixedZone("KST", 9*60*60)
	input := time.Date(2026, 10, 11, 9, 0, 0, 0, kst) // UTC 2026-10-11T00:00Z와 같은 순간

	fake := clocktest.New(input)
	if got := fake.Now(); got.Location() != time.UTC || !got.Equal(input) {
		t.Errorf("New: Now() = %v (Location %v), want same instant in UTC", got, got.Location())
	}

	setInput := time.Date(2030, 1, 2, 12, 0, 0, 0, kst)
	fake.Set(setInput)
	if got := fake.Now(); got.Location() != time.UTC || !got.Equal(setInput) {
		t.Errorf("Set: Now() = %v (Location %v), want same instant in UTC", got, got.Location())
	}
}

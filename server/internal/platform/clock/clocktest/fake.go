// Package clocktest는 테스트에서 시각을 직접 조작하는 Fake Clock을 제공합니다.
package clocktest

import (
	"sync"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// 컴파일 시점에 Fake가 clock.Clock을 만족하는지 확인합니다.
var _ clock.Clock = (*Fake)(nil)

// Fake는 테스트가 정한 시각을 돌려주는 Clock입니다. 여러 goroutine에서 안전합니다.
type Fake struct {
	mu  sync.Mutex
	now time.Time
}

// New는 주어진 시각을 UTC로 바꿔 시작하는 Fake를 만듭니다.
func New(t time.Time) *Fake {
	return &Fake{now: t.UTC()}
}

// Now는 Fake가 가진 현재 시각을 돌려줍니다.
func (f *Fake) Now() time.Time {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.now
}

// Set은 Fake의 현재 시각을 t(UTC로 변환한 값)로 바꿉니다.
func (f *Fake) Set(t time.Time) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.now = t.UTC()
}

// Advance는 Fake의 현재 시각을 d만큼 앞으로 옮깁니다.
func (f *Fake) Advance(d time.Duration) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.now = f.now.Add(d)
}

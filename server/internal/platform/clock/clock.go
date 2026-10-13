// Package clock은 현재 시각을 주입 가능한 형태로 제공합니다.
// 제품 코드는 time.Now()를 직접 부르지 않고 이 패키지의 Clock으로 시각을 읽습니다.
package clock

import "time"

// Clock은 현재 시각을 돌려주는 추상화입니다.
type Clock interface {
	Now() time.Time
}

// System은 실제 시스템 시각을 쓰는 Clock입니다. 항상 UTC로 돌려줍니다.
type System struct{}

// Now는 시스템의 현재 시각을 UTC로 돌려줍니다.
func (System) Now() time.Time {
	return time.Now().UTC()
}

package engine

import "time"

// SetInitialBackoffForTest는 값을 모르는 동안의 첫 재시도 간격을 줄입니다.
func (v *Versions) SetInitialBackoffForTest(d time.Duration) { v.initialBackoff = d }

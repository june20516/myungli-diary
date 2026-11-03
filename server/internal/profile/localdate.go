package profile

import "time"

// AddDays는 days일 뒤(음수면 앞)의 달력 날짜입니다. 시간대와 무관한 날짜 계산이라
// DST로 자정이 없는 날에도 하루씩 정확히 움직입니다.
func (d LocalDate) AddDays(days int) LocalDate {
	t := time.Date(d.Year, time.Month(d.Month), d.Day+days, 12, 0, 0, 0, time.UTC)
	return LocalDate{Year: t.Year(), Month: int(t.Month()), Day: t.Day()}
}

package notify

import (
	"time"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

// dueWindow는 현지 알림 시각부터 보내도 되는 시간입니다. Job이 멈췄다 돌아와도 이만큼의 누락분만 보냅니다(spec §8.2).
const dueWindow = 60 * time.Minute

// Due는 지금 보낼 알림 하나의 현지 날짜와 만료 시각(그 날짜 다음 날 현지 00:00)입니다.
type Due struct {
	LocalDate profile.LocalDate
	Expire    time.Time
}

// DueAt은 timezone의 현지 알림 시각 notifyAt이 [now − 60분, now] 안에 있는지와, 있다면 그 알림의 현지 날짜를 돌려줍니다.
// 오늘 현지 날짜의 알림 시각이 now보다 뒤면 어제 날짜의 알림 시각으로 봅니다(자정을 넘는 창).
// DST로 없는 현지 시각은 Go time.Date가 정규화한 시각을 씁니다. 시간대를 읽지 못하면 오류입니다.
func DueAt(now time.Time, timezone string, notifyAt profile.LocalTime) (Due, bool, error) {
	location, err := time.LoadLocation(timezone)
	if err != nil {
		return Due{}, false, err
	}
	local := now.In(location)
	year, month, day := local.Date()
	date := profile.LocalDate{Year: year, Month: int(month), Day: day}
	scheduled := atLocal(date, notifyAt, location)
	if scheduled.After(now) {
		date = date.AddDays(-1)
		scheduled = atLocal(date, notifyAt, location)
	}
	if now.Sub(scheduled) > dueWindow {
		return Due{}, false, nil
	}
	return Due{LocalDate: date, Expire: startOfDay(date.AddDays(1), location)}, true, nil
}

// atLocal은 date의 현지 시각 t입니다. 없는 시각은 Go time.Date가 정규화한 시각입니다.
func atLocal(date profile.LocalDate, t profile.LocalTime, location *time.Location) time.Time {
	return time.Date(date.Year, time.Month(date.Month), date.Day, t.Hour, t.Minute, 0, 0, location)
}

// startOfDay는 date의 현지 날짜가 시작되는 첫 순간입니다. DST로 00:00이 없는 날은 Go가 전날 시각으로
// 정규화하므로, 현지 날짜가 date가 될 때까지 한 시간씩 옮깁니다(America/Santiago 2026-09-06은 01:00).
func startOfDay(date profile.LocalDate, location *time.Location) time.Time {
	t := time.Date(date.Year, time.Month(date.Month), date.Day, 0, 0, 0, 0, location)
	for range 3 {
		year, month, day := t.Date()
		if (profile.LocalDate{Year: year, Month: int(month), Day: day}) == date {
			return t
		}
		t = t.Add(time.Hour)
	}
	return t
}

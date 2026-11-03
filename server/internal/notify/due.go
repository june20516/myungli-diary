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
	scheduled := time.Date(year, month, day, notifyAt.Hour, notifyAt.Minute, 0, 0, location)
	if scheduled.After(now) {
		day--
		scheduled = time.Date(year, month, day, notifyAt.Hour, notifyAt.Minute, 0, 0, location)
	}
	if now.Sub(scheduled) > dueWindow {
		return Due{}, false, nil
	}
	date := time.Date(year, month, day, 0, 0, 0, 0, location)
	return Due{
		LocalDate: profile.LocalDate{Year: date.Year(), Month: int(date.Month()), Day: date.Day()},
		Expire:    time.Date(date.Year(), date.Month(), date.Day()+1, 0, 0, 0, 0, location),
	}, true, nil
}

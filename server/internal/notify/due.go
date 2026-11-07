package notify

import (
	"hash/fnv"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

const (
	// dueWindow는 보낼 시각부터 보내도 되는 시간입니다. Job이 멈췄다 돌아와도 이만큼의 누락분만 보냅니다(spec §8.2).
	dueWindow = 60 * time.Minute
	// spreadWindow는 같은 알림 시각을 고른 사용자를 나눠 보내는 폭입니다. 고른 시각부터 이 안에 보냅니다(D109 ①).
	spreadWindow = 10 * time.Minute
)

// Due는 알림 하나의 현지 날짜, 보낼 시각(고른 시각 + 계정 오프셋), 만료 시각(그 날짜 다음 날 현지 00:00)입니다.
type Due struct {
	LocalDate profile.LocalDate
	SendAt    time.Time
	Expire    time.Time
}

// SpreadOffset은 계정의 알림을 고른 시각보다 늦추는 고정 오프셋입니다. [0, 10분)이고 초 단위입니다(D109 ①③).
// 계정 id의 hash라 같은 사용자는 날마다 같은 몫으로 받고, 사용자들은 10분 안에 고르게 나뉩니다.
func SpreadOffset(accountID uuid.UUID) time.Duration {
	h := fnv.New32a()
	_, _ = h.Write(accountID[:]) // hash.Hash의 Write는 오류를 돌려주지 않습니다.
	seconds := h.Sum32() % uint32(spreadWindow/time.Second)
	return time.Duration(seconds) * time.Second
}

// DueAt은 보낼 시각(timezone의 현지 알림 시각 notifyAt + offset)이 [now − 60분, now + lookahead) 안이거나 now와 같은지와,
// 그렇다면 그 알림의 현지 날짜와 보낼 시각을 돌려줍니다. lookahead는 다음 실행 전에 올 보낼 시각을 이번 실행이 맡는 폭입니다.
// 오늘 날짜의 보낼 시각이 그 구간보다 뒤면 어제 날짜의 알림으로 봅니다(자정을 넘는 창). 현지 날짜는 고른 시각의 날짜입니다.
// DST로 없는 현지 시각은 Go time.Date가 정규화한 시각을 씁니다. 시간대를 읽지 못하면 오류입니다.
func DueAt(now time.Time, timezone string, notifyAt profile.LocalTime, offset, lookahead time.Duration) (Due, bool, error) {
	location, err := time.LoadLocation(timezone)
	if err != nil {
		return Due{}, false, err
	}
	local := now.In(location)
	year, month, day := local.Date()
	date := profile.LocalDate{Year: year, Month: int(month), Day: day}
	sendAt := atLocal(date, notifyAt, location).Add(offset)
	if sendAt.After(now) && !sendAt.Before(now.Add(lookahead)) {
		date = date.AddDays(-1)
		sendAt = atLocal(date, notifyAt, location).Add(offset)
	}
	if now.Sub(sendAt) > dueWindow {
		return Due{}, false, nil
	}
	return Due{LocalDate: date, SendAt: sendAt, Expire: startOfDay(date.AddDays(1), location)}, true, nil
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

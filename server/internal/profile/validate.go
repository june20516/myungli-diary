package profile

import (
	"time"

	"github.com/june20516/myungli-diary/server/internal/city"
)

// D41 지원 범위(양력)입니다.
var (
	supportedFrom = LocalDate{Year: 1900, Month: 1, Day: 31}
	supportedTo   = LocalDate{Year: 2099, Month: 12, Day: 31}
)

// ValidateBirth는 엔진을 부르기 전에 server가 하는 검사입니다. 먼저 걸린 위반 하나만 돌려줍니다.
// 입력은 바꾸지 않고, city면 Longitude를 도시 경도로 채운 사본을 돌려줍니다.
// 음력의 날짜 존재와 범위는 엔진이 판정합니다.
func ValidateBirth(b Birth, pointer string) (Birth, error) {
	if err := validateStatusPairs(b, pointer); err != nil {
		return Birth{}, err
	}
	if b.Calendar == CalendarSolar {
		if !solarDateExists(b.Date) {
			return Birth{}, newViolation(DateInvalid, pointer+"/date", NoStatusRule)
		}
		if b.Date.before(supportedFrom) || supportedTo.before(b.Date) {
			return Birth{}, newViolation(BirthOutOfRange, pointer+"/date", NoStatusRule)
		}
	}
	if err := ValidateTimezone(b.Timezone, pointer+"/timezone"); err != nil {
		return Birth{}, err
	}

	out := b
	out.Longitude = nil
	if b.Time != nil {
		clock := *b.Time // 입력과 포인터를 공유하지 않도록 값을 복사합니다.
		out.Time = &clock
	}
	if b.PlaceStatus == PlaceCity {
		c, ok := city.Lookup(b.CityID)
		if !ok {
			return Birth{}, newViolation(CityNotFound, pointer+"/place/cityId", NoStatusRule)
		}
		longitude := c.Longitude
		out.Longitude = &longitude
	}
	return out, nil
}

// ValidateTimezone은 IANA 시간대 이름인지 확인합니다. 빈 문자열과 "Local"은 거부합니다.
func ValidateTimezone(name, pointer string) error {
	if name == "" || name == "Local" {
		return newViolation(TimezoneInvalid, pointer, NoStatusRule)
	}
	if _, err := time.LoadLocation(name); err != nil {
		return newViolation(TimezoneInvalid, pointer, NoStatusRule)
	}
	return nil
}

// ValidateNotification은 알림 상태와 시각의 짝을 확인합니다.
func ValidateNotification(n Notification, pointer string) error {
	return checkPair(n.Status == NotifyEnabled, n.Time != nil, pointer+"/time")
}

func validateStatusPairs(b Birth, pointer string) error {
	if err := checkPair(b.TimeStatus == TimeKnown, b.Time != nil, pointer+"/time/value"); err != nil {
		return err
	}
	if err := checkPair(b.PlaceStatus == PlaceCity, b.CityID != "", pointer+"/place/cityId"); err != nil {
		return err
	}
	if b.Calendar == CalendarSolar && b.IsLeapMonth {
		return newViolation(Inconsistent, pointer+"/isLeapMonth", ForbiddenByStatus)
	}
	return nil
}

// checkPair는 상태가 값을 요구하는지와 값이 있는지가 어긋나면 위반을 돌려줍니다.
func checkPair(required, present bool, field string) error {
	switch {
	case required && !present:
		return newViolation(Inconsistent, field, RequiredByStatus)
	case !required && present:
		return newViolation(Inconsistent, field, ForbiddenByStatus)
	}
	return nil
}

func (d LocalDate) before(other LocalDate) bool {
	if d.Year != other.Year {
		return d.Year < other.Year
	}
	if d.Month != other.Month {
		return d.Month < other.Month
	}
	return d.Day < other.Day
}

// solarDateExists는 양력 달력에 있는 날짜인지 확인합니다.
func solarDateExists(d LocalDate) bool {
	t := time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC)
	return t.Year() == d.Year && int(t.Month()) == d.Month && t.Day() == d.Day
}

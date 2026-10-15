// Package profile은 프로필 도메인 타입과 엔진을 부르기 전의 의미 검사, 출생 해시를 담습니다.
package profile

import (
	"fmt"

	"github.com/june20516/myungli-diary/server/internal/profile/honorific"
)

// Calendar는 출생 날짜의 달력입니다.
type Calendar string

// TimeStatus는 출생 시각을 아는지 나타냅니다.
type TimeStatus string

// PlaceStatus는 출생지를 물었는지, 골랐는지 나타냅니다.
type PlaceStatus string

// NotifyStatus는 알림 설정 상태입니다.
type NotifyStatus string

const (
	CalendarSolar Calendar = "solar"
	CalendarLunar Calendar = "lunar"

	TimeKnown   TimeStatus = "known"
	TimeUnknown TimeStatus = "unknown"

	PlaceNotAsked PlaceStatus = "not_asked"
	PlaceSkipped  PlaceStatus = "skipped"
	PlaceCity     PlaceStatus = "city"

	NotifyNotAsked NotifyStatus = "not_asked"
	NotifyEnabled  NotifyStatus = "enabled"
	NotifyDisabled NotifyStatus = "disabled"
)

// LocalDate는 시간대 없는 달력 날짜입니다.
type LocalDate struct{ Year, Month, Day int }

// LocalTime은 시간대 없는 시각입니다.
type LocalTime struct{ Hour, Minute int }

// Birth는 사주 계산에 쓰는 출생 정보입니다.
type Birth struct {
	Calendar    Calendar
	IsLeapMonth bool
	Date        LocalDate
	TimeStatus  TimeStatus
	Time        *LocalTime // TimeStatus가 known일 때만
	Gender      string     // "male" | "female"
	Timezone    string
	PlaceStatus PlaceStatus
	CityID      string   // PlaceStatus가 city일 때만
	Longitude   *float64 // city일 때 도시 경도로 채움(입력에는 없음)
}

// Notification은 알림 설정입니다.
type Notification struct {
	Status NotifyStatus
	Time   *LocalTime // enabled일 때만
}

// Profile은 계정의 프로필 전체입니다.
type Profile struct {
	Honorific       string
	Language        string
	CurrentTimezone string
	Birth           Birth
	Notification    Notification
}

// Violation은 422 의미 검사 위반의 종류입니다. httpapi가 problem code로 바꿉니다.
type Violation int

const (
	DateInvalid Violation = iota + 1
	BirthOutOfRange
	Inconsistent
	TimezoneInvalid
	CityNotFound
	BirthInvalid
	HonorificRejected // 사유는 ValidationError.Honorific
)

// StatusRule은 Inconsistent의 세부입니다.
type StatusRule int

const (
	NoStatusRule StatusRule = iota
	RequiredByStatus
	ForbiddenByStatus
)

// FieldViolation은 위반한 필드 하나입니다.
type FieldViolation struct {
	Field string     // 요청 본문 기준 JSON Pointer
	Rule  StatusRule // Inconsistent일 때만, 그 밖은 NoStatusRule
}

// ValidationError는 의미 검사 위반입니다.
type ValidationError struct {
	Violation Violation      // 첫 위반의 종류
	Honorific honorific.Code // Violation이 HonorificRejected일 때만 의미 있음
	Fields    []FieldViolation
}

var violationNames = map[Violation]string{
	DateInvalid:       "DateInvalid",
	BirthOutOfRange:   "BirthOutOfRange",
	Inconsistent:      "Inconsistent",
	TimezoneInvalid:   "TimezoneInvalid",
	CityNotFound:      "CityNotFound",
	BirthInvalid:      "BirthInvalid",
	HonorificRejected: "HonorificRejected",
}

// Error는 위반 종류와 field만 담습니다. 사용자 값은 넣지 않습니다.
func (e *ValidationError) Error() string {
	name, ok := violationNames[e.Violation]
	if !ok {
		name = fmt.Sprintf("Violation(%d)", int(e.Violation))
	}
	msg := "출생 정보 의미 검사 위반: " + name
	for _, f := range e.Fields {
		msg += " " + f.Field
	}
	return msg
}

func newViolation(v Violation, field string, rule StatusRule) *ValidationError {
	return &ValidationError{Violation: v, Fields: []FieldViolation{{Field: field, Rule: rule}}}
}

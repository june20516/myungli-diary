// Package schedule은 일정(날짜와 선택적 시각을 가진 사용자 기록)을 저장하고 읽는 서비스를 둡니다.
package schedule

import (
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

// MaxRangeDays는 List가 한 번에 보는 날짜 수의 상한입니다(from·to 포함).
const MaxRangeDays = 62

var (
	// ErrNotFound는 일정이 없거나 남의 것이거나(복원이 아닌 경우) 지웠을 때 돌려줍니다.
	ErrNotFound = errors.New("일정을 찾을 수 없습니다")
	// ErrRangeTooLong은 조회 범위가 MaxRangeDays를 넘을 때 돌려줍니다.
	ErrRangeTooLong = errors.New("일정 조회 범위가 너무 깁니다")
	// ErrRangeReversed는 조회 범위의 from이 to보다 늦을 때 돌려줍니다.
	ErrRangeReversed = errors.New("일정 조회 범위의 시작이 끝보다 늦습니다")
)

// 짝 위반의 field입니다(요청 본문 기준 JSON Pointer).
const fieldTime = "/time"

// Schedule은 일정 하나입니다. Time은 AllDay가 false일 때만 있고, Memo는 없으면 nil입니다.
type Schedule struct {
	ID        uuid.UUID
	Date      profile.LocalDate
	AllDay    bool
	Time      *profile.LocalTime
	Title     string
	Memo      *string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Input은 새 일정입니다. Memo의 빈 문자열은 메모 없음으로 저장합니다.
type Input struct {
	Date   profile.LocalDate
	AllDay bool
	Time   *profile.LocalTime
	Title  string
	Memo   *string
}

// Patch는 일정의 일부 수정입니다. nil 필드는 바꾸지 않습니다.
// AllDay를 true로 바꾸면 기존 Time이 지워지고, Memo의 빈 문자열은 메모를 지웁니다.
type Patch struct {
	Date   *profile.LocalDate
	AllDay *bool
	Time   *profile.LocalTime
	Title  *string
	Memo   *string
}

// checkPair는 AllDay와 Time의 짝을 검사합니다. 종일이면 Time이 없어야 하고, 아니면 있어야 합니다.
func checkPair(allDay bool, t *profile.LocalTime) error {
	switch {
	case allDay && t != nil:
		return pairViolation(profile.ForbiddenByStatus)
	case !allDay && t == nil:
		return pairViolation(profile.RequiredByStatus)
	}
	return nil
}

func pairViolation(rule profile.StatusRule) *profile.ValidationError {
	return &profile.ValidationError{
		Violation: profile.Inconsistent,
		Fields:    []profile.FieldViolation{{Field: fieldTime, Rule: rule}},
	}
}

// emptyToNil은 빈 메모를 메모 없음(nil)으로 바꿉니다(P5-9).
func emptyToNil(memo *string) *string {
	if memo != nil && *memo == "" {
		return nil
	}
	return memo
}

// apply는 s에 p를 적용한 결과를 돌려주고, 결과의 짝을 검사합니다.
// 종일로 바뀌는 수정은 기존 Time을 지운 뒤 p.Time을 봅니다. 그래서 종일로 바꾸면서 Time을 같이 보내면 위반입니다.
func (p Patch) apply(s Schedule) (Schedule, error) {
	if p.Date != nil {
		s.Date = *p.Date
	}
	if p.AllDay != nil {
		s.AllDay = *p.AllDay
		if s.AllDay {
			s.Time = nil
		}
	}
	if p.Time != nil {
		s.Time = p.Time
	}
	if p.Title != nil {
		s.Title = *p.Title
	}
	if p.Memo != nil {
		s.Memo = emptyToNil(p.Memo)
	}
	if err := checkPair(s.AllDay, s.Time); err != nil {
		return Schedule{}, err
	}
	return s, nil
}

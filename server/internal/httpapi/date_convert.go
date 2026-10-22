package httpapi

import (
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

// localDateOf는 계약 날짜를 도메인 달력 날짜로 바꿉니다.
func localDateOf(d openapi_types.Date) profile.LocalDate {
	return profile.LocalDate{Year: d.Year(), Month: int(d.Month()), Day: d.Day()}
}

// contractDate는 달력 날짜를 계약 날짜로 바꿉니다.
func contractDate(d profile.LocalDate) openapi_types.Date {
	return openapi_types.Date{Time: time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC)}
}

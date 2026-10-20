package httpapi

import (
	"context"
	"errors"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// 음력 변환 422가 가리키는 위치(요청 본문 기준 JSON Pointer)입니다.
const (
	fieldLunarDate   = "/date"
	fieldIsLeapMonth = "/isLeapMonth"
)

// errLunarSolarMissing은 엔진이 양력 날짜 없이 성공을 돌려준 경우입니다. 계약을 지킬 수 없어 500입니다.
var errLunarSolarMissing = errors.New("엔진 음력 변환 응답에 양력 날짜가 없습니다")

// ConvertLunarDate는 음력 날짜를 양력으로 바꾸고, 그해 그 음력 달에 윤달이 있는지 알려 줍니다. 입력은 저장하지 않습니다.
// 없는 음력 날짜는 422 date.invalid, 지원 범위 밖은 422 date.out_of_range입니다.
// App Check와 요청 한도는 register.go가 operation 단위로 감쌉니다.
func (a *API) ConvertLunarDate(ctx context.Context, req gen.ConvertLunarDateRequestObject) (gen.ConvertLunarDateResponseObject, error) {
	body := *req.Body
	resp, err := a.Lunar.ConvertLunarDate(ctx, lunarRequest(body.Date, body.IsLeapMonth))
	if err != nil {
		return nil, a.lunarError(ctx, body, err)
	}
	solar := resp.GetSolar()
	if solar == nil {
		return nil, errLunarSolarMissing
	}
	return gen.ConvertLunarDate200JSONResponse{
		SolarDate:    openapi_types.Date{Time: time.Date(int(solar.GetYear()), time.Month(solar.GetMonth()), int(solar.GetDay()), 0, 0, 0, 0, time.UTC)},
		MonthHasLeap: resp.GetMonthHasLeap(),
	}, nil
}

// lunarRequest는 계약의 음력 날짜를 엔진 요청으로 바꿉니다.
func lunarRequest(date gen.LunarOrSolarDate, isLeapMonth bool) *enginev1.LunarDateRequest {
	return &enginev1.LunarDateRequest{
		Date:        &enginev1.LocalDate{Year: dateInt32(date.Year), Month: dateInt32(date.Month), Day: dateInt32(date.Day)},
		IsLeapMonth: isLeapMonth,
	}
}

// dateInt32는 음력 연·월·일을 proto 정수로 바꿉니다. 범위는 요청 스키마(LunarOrSolarDate의 minimum·maximum)가 보장합니다.
func dateInt32(v int) int32 {
	return int32(v) //nolint:gosec // 범위는 요청 검증이 보장합니다
}

// lunarError는 엔진의 입력 판정을 422로 바꿉니다. 그 밖의 엔진 오류는 그대로 돌려 공통 경로(503·504·502)로 보냅니다.
func (a *API) lunarError(ctx context.Context, body gen.LunarDateRequest, err error) error {
	return dateError(err, func() string { return a.invalidLunarField(ctx, body) })
}

// dateError는 엔진의 날짜 판정을 422로 바꿉니다(음력 변환과 시진 확인이 같이 씁니다). 지원 범위 밖은 /date이고,
// 없는 날짜는 invalidField가 가리키는 필드입니다(필드를 가리는 데 엔진을 다시 부를 수 있어 필요할 때만 부릅니다).
// 그 밖의 엔진 오류는 그대로 돌려 공통 경로(503·504·502)로 보냅니다.
func dateError(err error, invalidField func() string) error {
	switch {
	case errors.Is(err, engine.ErrOutOfRange):
		return fieldError(problem.DateOutOfRange, fieldLunarDate)
	case errors.Is(err, engine.ErrInvalidArgument):
		return fieldError(problem.DateInvalid, invalidField())
	default:
		return err
	}
}

// invalidLunarField는 없는 음력 날짜가 어느 필드 탓인지 가립니다. 엔진은 둘을 구분하지 않으므로,
// 윤달을 물었을 때만 평달로 한 번 더 묻습니다. 평달은 있는데 그해 그 달에 윤달이 없으면 /isLeapMonth,
// 그 밖(윤달은 있는데 그 날이 없음, 평달도 없음, 다시 묻기 실패)은 /date입니다.
// 다시 묻기의 오류는 버립니다. 응답은 이미 422로 정해졌고, 필드만 덜 구체적일 뿐입니다.
func (a *API) invalidLunarField(ctx context.Context, body gen.LunarDateRequest) string {
	if !body.IsLeapMonth {
		return fieldLunarDate
	}
	plain, err := a.Lunar.ConvertLunarDate(ctx, lunarRequest(body.Date, false))
	if err != nil || plain.GetMonthHasLeap() {
		return fieldLunarDate
	}
	return fieldIsLeapMonth
}

// fieldError는 필드 하나를 가리키는 422 *Error를 만듭니다. errors[].code는 problem code와 같습니다.
func fieldError(c problem.Code, field string) *Error {
	e := newError(c, "Validation failed")
	e.Errors = []problem.FieldError{{Field: field, Code: c.Value}}
	return e
}

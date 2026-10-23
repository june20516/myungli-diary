package httpapi

import (
	"context"
	"fmt"
	"time"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// birthHourTimezone은 시진 확인이 쓰는 출생 시간대입니다. 시진은 대표 경도(경도 없음)로 계산하므로 한국 기준으로 고정합니다(D58 ②).
const birthHourTimezone = "Asia/Seoul"

// seoulLocation은 시진 응답을 벽시계로 바꾸는 시간대입니다. tzdata는 바이너리에 내장되어(S31) 실패하면 조립 실수이므로 시작 때 panic합니다.
var seoulLocation = mustLoadLocation(birthHourTimezone)

func mustLoadLocation(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		panic(fmt.Sprintf("시간대 %s를 불러오지 못했습니다: %v", name, err))
	}
	return loc
}

// birthHourGender는 시진 확인 요청에 싣는 성별입니다. 시진은 출생 시각·시간대·경도로만 정해져 성별과 무관하므로
// 미지정을 보냅니다. 엔진은 시진 확인에서만 GENDER_UNSPECIFIED를 받습니다(core #304, S69).
const birthHourGender = enginev1.Gender_GENDER_UNSPECIFIED

// BirthHourChecker는 시진 확인 핸들러가 쓰는 엔진 RPC입니다. engine.Engine이 만족합니다.
type BirthHourChecker interface {
	GetBirthHour(ctx context.Context, req *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error)
}

// GetBirthHour는 출생 시각이 속한 시진과 그 시작·끝(Asia/Seoul 벽시계 HH:MM)을 알려 줍니다. 입력은 저장하지 않습니다.
// 성별은 계산과 무관해 미지정으로 보냅니다(birthHourGender). 양력인데 isLeapMonth가 true면 422 request.inconsistent,
// 없는 날짜는 422 date.invalid, 지원 범위 밖은 422 date.out_of_range입니다.
// 시진 확인은 윤달 여부를 가리려고 엔진을 다시 부르지 않아 date.invalid의 field가 늘 /date입니다(음력 변환과 다름).
// 엔진이 조립되지 않았으면 503 service.unavailable입니다.
// App Check와 요청 한도는 register.go가 operation 단위로 감쌉니다.
func (a *API) GetBirthHour(ctx context.Context, req gen.GetBirthHourRequestObject) (gen.GetBirthHourResponseObject, error) {
	if a.BirthHour == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	body := *req.Body
	if body.Calendar == gen.CalendarType(profile.CalendarSolar) && body.IsLeapMonth {
		return nil, validationError(&profile.ValidationError{
			Violation: profile.Inconsistent,
			Fields:    []profile.FieldViolation{{Field: fieldIsLeapMonth, Rule: profile.ForbiddenByStatus}},
		})
	}
	engineReq, err := birthHourRequest(body)
	if err != nil {
		return nil, err
	}
	resp, err := a.BirthHour.GetBirthHour(ctx, engineReq)
	if err != nil {
		return nil, dateError(err, func() string { return fieldLunarDate })
	}
	return toBirthHour(resp)
}

// birthHourRequest는 계약 요청을 엔진 요청으로 바꿉니다. 시각 형식은 계약 검증(pattern)이 보장합니다.
func birthHourRequest(body gen.BirthHourRequest) (*enginev1.BirthHourRequest, error) {
	clock, err := parseClock(&body.Time)
	if err != nil {
		return nil, err
	}
	calendar := enginev1.CalendarType_CALENDAR_TYPE_SOLAR
	if body.Calendar == gen.CalendarType(profile.CalendarLunar) {
		calendar = enginev1.CalendarType_CALENDAR_TYPE_LUNAR
	}
	return &enginev1.BirthHourRequest{Birth: &enginev1.BirthInfo{
		Calendar:    calendar,
		IsLeapMonth: body.IsLeapMonth,
		Date:        &enginev1.LocalDate{Year: dateInt32(body.Date.Year), Month: dateInt32(body.Date.Month), Day: dateInt32(body.Date.Day)},
		Time:        &enginev1.LocalTime{Hour: dateInt32(clock.Hour), Minute: dateInt32(clock.Minute)},
		Gender:      birthHourGender,
		Timezone:    birthHourTimezone,
	}}, nil
}

// toBirthHour는 엔진 응답의 절대 시각을 Asia/Seoul 벽시계 HH:MM으로 바꿉니다(자시는 23:30~01:30처럼 날을 넘습니다).
func toBirthHour(resp *enginev1.BirthHourResponse) (gen.GetBirthHourResponseObject, error) {
	c := &converter{loc: seoulLocation}
	branch := enumValue[gen.Branch](c, resp.GetBranch())
	start := c.instant(resp.GetStart())
	end := c.instant(resp.GetEnd())
	if c.err != nil {
		return nil, c.err
	}
	return gen.GetBirthHour200JSONResponse{
		Branch: branch,
		Start:  start.Format(clockLayout),
		End:    end.Format(clockLayout),
	}, nil
}

package httpapi

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// 운세 422 date.out_of_range가 가리키는 parameter 이름입니다(계약 FieldError.field).
const (
	fieldDailyDate    = "date"
	fieldCalendarYear = "year"
)

// GetDaily는 그날의 데일리를 돌려줍니다. 반응할 수 있는 슬롯에는 이 사용자가 남긴 반응을 싣습니다.
// 프로필이 없으면 409 profile.required, D41 지원 범위 밖이면 422 date.out_of_range,
// 활성 콘텐츠 시드가 없거나 Contents가 조립되지 않았으면 503 service.unavailable입니다.
func (a *API) GetDaily(ctx context.Context, req gen.GetDailyRequestObject) (gen.GetDailyResponseObject, error) {
	id, p, err := a.fortuneProfile(ctx)
	if err != nil {
		return nil, err
	}
	if a.Contents == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	date := profile.LocalDate{Year: req.Date.Year(), Month: int(req.Date.Month()), Day: req.Date.Day()}
	view, err := a.Readings.Daily(ctx, id, p, date)
	if err != nil {
		return nil, outOfRangeError(err, fieldDailyDate)
	}
	reactions, err := a.dailyReactions(ctx, view)
	if err != nil {
		return nil, err
	}
	loc, err := currentLocation(p)
	if err != nil {
		return nil, err
	}
	body, err := toDaily(view, reactions, req.Date, loc)
	if err != nil {
		return nil, err
	}
	return gen.GetDaily200JSONResponse(body), nil
}

// GetCalendar는 한 달 달력을 돌려줍니다. 오류는 GetDaily와 같고, 422의 field는 year입니다.
func (a *API) GetCalendar(ctx context.Context, req gen.GetCalendarRequestObject) (gen.GetCalendarResponseObject, error) {
	id, p, err := a.fortuneProfile(ctx)
	if err != nil {
		return nil, err
	}
	view, err := a.Readings.Calendar(ctx, id, p, req.Year, req.Month)
	if err != nil {
		return nil, outOfRangeError(err, fieldCalendarYear)
	}
	loc, err := currentLocation(p)
	if err != nil {
		return nil, err
	}
	body, err := toCalendar(view, req.Year, req.Month, loc)
	if err != nil {
		return nil, err
	}
	return gen.GetCalendar200JSONResponse(body), nil
}

// GetChart는 나의 사주를 돌려줍니다. 프로필이 없으면 409 profile.required입니다.
// 기준일(세운)은 server가 정하므로 엔진 OUT_OF_RANGE는 사용자 입력 오류가 아니라 공통 경로(500)입니다.
func (a *API) GetChart(ctx context.Context, _ gen.GetChartRequestObject) (gen.GetChartResponseObject, error) {
	id, p, err := a.fortuneProfile(ctx)
	if err != nil {
		return nil, err
	}
	view, err := a.Readings.Chart(ctx, id, p)
	if err != nil {
		return nil, err
	}
	body, err := toChart(view)
	if err != nil {
		return nil, err
	}
	return gen.GetChart200JSONResponse(body), nil
}

// fortuneProfile은 운세 operation 공통 앞부분입니다. 인증된 계정과 그 프로필을 돌려줍니다.
// Readings가 조립되지 않은 것은 조립 실수이므로 헬스 체크(DB 없음)와 같게 503으로 드러냅니다.
func (a *API) fortuneProfile(ctx context.Context) (uuid.UUID, profile.Profile, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return uuid.Nil, profile.Profile{}, errNoAccount
	}
	if a.Readings == nil {
		return uuid.Nil, profile.Profile{}, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	p, err := a.Profiles.Get(ctx, id)
	if err != nil {
		return uuid.Nil, profile.Profile{}, err
	}
	return id, p, nil
}

// outOfRangeError는 엔진의 지원 범위 판정을 parameter field 하나를 가리키는 422로 바꿉니다.
// 그 밖의 오류는 그대로 돌려 공통 경로(409·503·504·502·500)로 보냅니다.
func outOfRangeError(err error, field string) error {
	if errors.Is(err, engine.ErrOutOfRange) {
		return fieldError(problem.DateOutOfRange, field)
	}
	return err
}

// currentLocation은 프로필 현재 시간대를 읽습니다. 저장 때 검사를 통과한 이름이라 실패는 서버 오류입니다.
func currentLocation(p profile.Profile) (*time.Location, error) {
	loc, err := time.LoadLocation(p.CurrentTimezone)
	if err != nil {
		// 오류 문구에 시간대 이름이 들어 있어 감싸지 않습니다.
		return nil, errors.New("프로필 현재 시간대 로드 실패")
	}
	return loc, nil
}

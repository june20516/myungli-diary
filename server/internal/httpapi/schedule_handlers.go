package httpapi

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/schedule"
)

// 일정 시각의 계약 표기(HH:MM)입니다.
const scheduleTimeLayout = "15:04"

// 본문 시각을 읽지 못할 때 가리키는 field입니다(계약 FieldError.field, 본문 기준 JSON Pointer).
const fieldScheduleTime = "/time"

// ListSchedules는 from~to(포함) 일정을 돌려줍니다. 62일을 넘으면 422 range.too_long(field to),
// from이 to보다 늦으면 400 request.invalid(field from)입니다.
func (a *API) ListSchedules(ctx context.Context, req gen.ListSchedulesRequestObject) (gen.ListSchedulesResponseObject, error) {
	id, err := a.scheduleAccountID(ctx)
	if err != nil {
		return nil, err
	}
	list, err := a.Schedules.List(ctx, id, localDateOf(req.Params.From), localDateOf(req.Params.To))
	if err != nil {
		return nil, err
	}
	items := make([]gen.Schedule, len(list))
	for i, s := range list {
		items[i] = toSchedule(s)
	}
	return gen.ListSchedules200JSONResponse(gen.ScheduleList{Items: items}), nil
}

// CreateSchedule은 일정을 만들고 201과 Location을 돌려줍니다. Idempotency-Key는 멱등 미들웨어가 다룹니다.
func (a *API) CreateSchedule(ctx context.Context, req gen.CreateScheduleRequestObject) (gen.CreateScheduleResponseObject, error) {
	id, err := a.scheduleAccountID(ctx)
	if err != nil {
		return nil, err
	}
	t, err := parseScheduleTime(req.Body.Time)
	if err != nil {
		return nil, err
	}
	created, err := a.Schedules.Create(ctx, id, schedule.Input{
		Date:   localDateOf(req.Body.Date),
		AllDay: req.Body.AllDay,
		Time:   t,
		Title:  req.Body.Title,
		Memo:   req.Body.Memo,
	})
	if err != nil {
		return nil, err
	}
	location := "/v1/schedules/" + created.ID.String()
	return gen.CreateSchedule201JSONResponse{
		Body:    toSchedule(created),
		Headers: gen.CreateSchedule201ResponseHeaders{Location: &location},
	}, nil
}

// UpdateSchedule은 보낸 필드만 바꿉니다. 짝 위반은 422 request.inconsistent, 없는 일정은 404 schedule.not_found입니다.
func (a *API) UpdateSchedule(ctx context.Context, req gen.UpdateScheduleRequestObject) (gen.UpdateScheduleResponseObject, error) {
	id, err := a.scheduleAccountID(ctx)
	if err != nil {
		return nil, err
	}
	t, err := parseScheduleTime(req.Body.Time)
	if err != nil {
		return nil, err
	}
	patch := schedule.Patch{
		AllDay: req.Body.AllDay,
		Time:   t,
		Title:  req.Body.Title,
		Memo:   req.Body.Memo,
	}
	if req.Body.Date != nil {
		date := localDateOf(*req.Body.Date)
		patch.Date = &date
	}
	updated, err := a.Schedules.Update(ctx, id, req.Id, patch)
	if err != nil {
		return nil, err
	}
	return gen.UpdateSchedule200JSONResponse(toSchedule(updated)), nil
}

// DeleteSchedule은 일정을 지웁니다(soft delete). 없으면 404 schedule.not_found입니다.
func (a *API) DeleteSchedule(ctx context.Context, req gen.DeleteScheduleRequestObject) (gen.DeleteScheduleResponseObject, error) {
	id, err := a.scheduleAccountID(ctx)
	if err != nil {
		return nil, err
	}
	if err := a.Schedules.Delete(ctx, id, req.Id); err != nil {
		return nil, err
	}
	return gen.DeleteSchedule204Response{}, nil
}

// RestoreSchedule은 지운 일정을 되살립니다. 이미 살아 있는 일정이면 그대로 200이고, 없으면 404 schedule.not_found입니다.
func (a *API) RestoreSchedule(ctx context.Context, req gen.RestoreScheduleRequestObject) (gen.RestoreScheduleResponseObject, error) {
	id, err := a.scheduleAccountID(ctx)
	if err != nil {
		return nil, err
	}
	restored, err := a.Schedules.Restore(ctx, id, req.Id)
	if err != nil {
		return nil, err
	}
	return gen.RestoreSchedule200JSONResponse(toSchedule(restored)), nil
}

// scheduleAccountID는 일정 operation 공통 앞부분으로, 인증된 계정 id를 돌려줍니다. 일정은 프로필을 요구하지 않습니다.
// Schedules가 조립되지 않은 것은 조립 실수이므로 일기와 같게 503으로 드러냅니다.
func (a *API) scheduleAccountID(ctx context.Context) (uuid.UUID, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return uuid.Nil, errNoAccount
	}
	if a.Schedules == nil {
		return uuid.Nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	return id, nil
}

// parseScheduleTime은 HH:MM 문자열을 시각으로 바꿉니다. nil이면 nil입니다.
// 요청 검증이 형식을 이미 막으므로 여기서 실패하는 것은 방어 경로이고, 400 request.invalid(field /time)로 답합니다.
func parseScheduleTime(s *string) (*profile.LocalTime, error) {
	if s == nil {
		return nil, nil
	}
	t, err := time.Parse(scheduleTimeLayout, *s)
	if err != nil {
		return nil, fieldError(problem.RequestInvalid, fieldScheduleTime)
	}
	return &profile.LocalTime{Hour: t.Hour(), Minute: t.Minute()}, nil
}

// toSchedule은 일정 하나를 계약 Schedule로 옮깁니다. 종일이면 time을, 메모가 없으면 memo를 생략합니다.
func toSchedule(s schedule.Schedule) gen.Schedule {
	out := gen.Schedule{
		AllDay:    s.AllDay,
		CreatedAt: s.CreatedAt,
		Date:      contractDate(s.Date),
		Id:        s.ID,
		Memo:      s.Memo,
		Title:     s.Title,
		UpdatedAt: s.UpdatedAt,
	}
	if s.Time != nil {
		formatted := fmt.Sprintf("%02d:%02d", s.Time.Hour, s.Time.Minute)
		out.Time = &formatted
	}
	return out
}

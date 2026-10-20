package httpapi_test

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/schedule"
)

// fakeSchedules는 ScheduleService 대역입니다. 받은 인자를 기록하고, 준비한 결과나 오류를 돌려줍니다.
type fakeSchedules struct {
	item schedule.Schedule
	list []schedule.Schedule
	err  error

	gotAccount uuid.UUID
	gotID      uuid.UUID
	gotFrom    profile.LocalDate
	gotTo      profile.LocalDate
	gotInput   schedule.Input
	gotPatch   schedule.Patch
}

func (f *fakeSchedules) List(_ context.Context, accountID uuid.UUID, from, to profile.LocalDate) ([]schedule.Schedule, error) {
	f.gotAccount, f.gotFrom, f.gotTo = accountID, from, to
	return f.list, f.err
}

func (f *fakeSchedules) Create(_ context.Context, accountID uuid.UUID, in schedule.Input) (schedule.Schedule, error) {
	f.gotAccount, f.gotInput = accountID, in
	return f.item, f.err
}

func (f *fakeSchedules) Update(_ context.Context, accountID, id uuid.UUID, p schedule.Patch) (schedule.Schedule, error) {
	f.gotAccount, f.gotID, f.gotPatch = accountID, id, p
	return f.item, f.err
}

func (f *fakeSchedules) Delete(_ context.Context, accountID, id uuid.UUID) error {
	f.gotAccount, f.gotID = accountID, id
	return f.err
}

func (f *fakeSchedules) Restore(_ context.Context, accountID, id uuid.UUID) (schedule.Schedule, error) {
	f.gotAccount, f.gotID = accountID, id
	return f.item, f.err
}

var sampleScheduleID = uuid.MustParse("0198a000-0000-7000-8000-000000000001")

func sampleSchedule() schedule.Schedule {
	memo := "3층 회의실"
	return schedule.Schedule{
		ID:        sampleScheduleID,
		Date:      profile.LocalDate{Year: 2026, Month: 10, Day: 21},
		AllDay:    false,
		Time:      &profile.LocalTime{Hour: 9, Minute: 5},
		Title:     "회의",
		Memo:      &memo,
		CreatedAt: time.Date(2026, 10, 20, 1, 0, 0, 0, time.UTC),
		UpdatedAt: time.Date(2026, 10, 20, 2, 0, 0, 0, time.UTC),
	}
}

// 일정 API는 프로필이 필요 없으므로 Profiles를 두지 않습니다.
func scheduleAPI(schedules *fakeSchedules) *httpapi.API {
	return &httpapi.API{Schedules: schedules}
}

const scheduleTarget = "/v1/schedules/0198a000-0000-7000-8000-000000000001"

func TestListSchedules(t *testing.T) {
	schedules := &fakeSchedules{list: []schedule.Schedule{sampleSchedule()}}
	req, rec := sendDiary(t, scheduleAPI(schedules), http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-31", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, fixedAccountID, schedules.gotAccount)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 1}, schedules.gotFrom)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 31}, schedules.gotTo)
	items, ok := decodeMap(t, rec)["items"].([]any)
	require.True(t, ok)
	require.Len(t, items, 1)
	item, ok := items[0].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, sampleScheduleID.String(), item["id"])
	assert.Equal(t, "2026-10-21", item["date"])
	assert.Equal(t, "09:05", item["time"])
	assert.Equal(t, false, item["allDay"])
	assert.Equal(t, "3층 회의실", item["memo"])
}

func TestListSchedules_EmptyAndOmitted(t *testing.T) {
	_, rec := sendDiary(t, scheduleAPI(&fakeSchedules{}), http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-31", "")
	require.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, []any{}, decodeMap(t, rec)["items"])

	// 종일 일정은 time을, 메모 없는 일정은 memo를 응답에서 생략합니다.
	s := sampleSchedule()
	s.AllDay, s.Time, s.Memo = true, nil, nil
	req, rec := sendDiary(t, scheduleAPI(&fakeSchedules{list: []schedule.Schedule{s}}), http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-31", "")
	require.Equal(t, http.StatusOK, rec.Code)
	expectFortuneContract(t, req, rec)
	item, ok := decodeMap(t, rec)["items"].([]any)[0].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, item, "time")
	assert.NotContains(t, item, "memo")
}

func TestListSchedules_RangeErrors(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		code   string
		field  string
	}{
		{"범위 초과", schedule.ErrRangeTooLong, http.StatusUnprocessableEntity, "range.too_long", "to"},
		{"from이 to보다 늦음", schedule.ErrRangeReversed, http.StatusBadRequest, "request.invalid", "from"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, rec := sendDiary(t, scheduleAPI(&fakeSchedules{err: tt.err}), http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-12-31", "")

			require.Equal(t, tt.status, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, tt.code, p.Code)
			assert.Equal(t, []string{tt.field}, fieldsOf(p))
			expectFortuneContract(t, req, rec)
		})
	}
}

func TestCreateSchedule(t *testing.T) {
	schedules := &fakeSchedules{item: sampleSchedule()}
	req, rec := sendDiary(t, scheduleAPI(schedules), http.MethodPost, "/v1/schedules",
		`{"date":"2026-10-21","allDay":false,"time":"09:05","title":"회의","memo":"3층 회의실"}`)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, "/v1/schedules/"+sampleScheduleID.String(), rec.Header().Get("Location"))
	assert.Equal(t, fixedAccountID, schedules.gotAccount)
	memo := "3층 회의실"
	assert.Equal(t, schedule.Input{
		Date: profile.LocalDate{Year: 2026, Month: 10, Day: 21}, AllDay: false,
		Time: &profile.LocalTime{Hour: 9, Minute: 5}, Title: "회의", Memo: &memo,
	}, schedules.gotInput)
	assert.Equal(t, sampleScheduleID.String(), decodeMap(t, rec)["id"])
}

func TestCreateSchedule_AllDayHasNoTime(t *testing.T) {
	schedules := &fakeSchedules{item: sampleSchedule()}
	_, rec := sendDiary(t, scheduleAPI(schedules), http.MethodPost, "/v1/schedules", `{"date":"2026-10-21","allDay":true,"title":"종일"}`)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	assert.Nil(t, schedules.gotInput.Time)
	assert.Nil(t, schedules.gotInput.Memo)
}

func TestCreateSchedule_Inconsistent(t *testing.T) {
	tests := []struct {
		name string
		rule profile.StatusRule
		code string
	}{
		{"시각 필요", profile.RequiredByStatus, "required_by_status"},
		{"시각 금지", profile.ForbiddenByStatus, "forbidden_by_status"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			violation := &profile.ValidationError{Violation: profile.Inconsistent, Fields: []profile.FieldViolation{{Field: "/time", Rule: tt.rule}}}
			req, rec := sendDiary(t, scheduleAPI(&fakeSchedules{err: violation}), http.MethodPost, "/v1/schedules",
				`{"date":"2026-10-21","allDay":false,"title":"x"}`)

			require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, "request.inconsistent", p.Code)
			require.Len(t, p.Errors, 1)
			assert.Equal(t, "/time", p.Errors[0].Field)
			assert.Equal(t, tt.code, p.Errors[0].Code)
			expectFortuneContract(t, req, rec)
		})
	}
}

func TestUpdateSchedule(t *testing.T) {
	schedules := &fakeSchedules{item: sampleSchedule()}
	req := newBodyRequest(t, http.MethodPatch, scheduleTarget, contentTypeMergePatch, `{"allDay":true,"title":"새 제목","memo":"","date":"2026-10-22"}`)
	handler, _ := newHandlerAPI(t, scheduleAPI(schedules))
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, fixedAccountID, schedules.gotAccount)
	assert.Equal(t, sampleScheduleID, schedules.gotID)
	title, memo, allDay := "새 제목", "", true
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 22}
	assert.Equal(t, schedule.Patch{Date: &date, AllDay: &allDay, Title: &title, Memo: &memo}, schedules.gotPatch)
}

func TestUpdateSchedule_TimeOnly(t *testing.T) {
	schedules := &fakeSchedules{item: sampleSchedule()}
	handler, _ := newHandlerAPI(t, scheduleAPI(schedules))
	rec := serve(handler, newBodyRequest(t, http.MethodPatch, scheduleTarget, contentTypeMergePatch, `{"time":"23:59"}`))

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, schedule.Patch{Time: &profile.LocalTime{Hour: 23, Minute: 59}}, schedules.gotPatch)
}

func TestScheduleOperations_NotFound(t *testing.T) {
	calls := []struct{ method, target, body string }{
		{http.MethodPatch, scheduleTarget, `{"title":"x"}`},
		{http.MethodDelete, scheduleTarget, ""},
		{http.MethodPost, scheduleTarget + "/restore", ""},
	}
	for _, c := range calls {
		t.Run(c.method, func(t *testing.T) {
			handler, _ := newHandlerAPI(t, scheduleAPI(&fakeSchedules{err: schedule.ErrNotFound}))
			var req *http.Request
			if c.body == "" {
				req = newBodyRequest(t, c.method, c.target, contentTypeJSON, "")
			} else {
				req = newBodyRequest(t, c.method, c.target, contentTypeMergePatch, c.body)
			}
			rec := serve(handler, req)

			require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
			assert.Equal(t, "schedule.not_found", decodeProblem(t, rec).Code)
			expectFortuneContract(t, req, rec)
		})
	}
}

func TestDeleteSchedule(t *testing.T) {
	schedules := &fakeSchedules{}
	req, rec := sendDiary(t, scheduleAPI(schedules), http.MethodDelete, scheduleTarget, "")

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, sampleScheduleID, schedules.gotID)
	assert.Equal(t, fixedAccountID, schedules.gotAccount)
}

func TestRestoreSchedule(t *testing.T) {
	schedules := &fakeSchedules{item: sampleSchedule()}
	req, rec := sendDiary(t, scheduleAPI(schedules), http.MethodPost, scheduleTarget+"/restore", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, sampleScheduleID, schedules.gotID)
	assert.Equal(t, sampleScheduleID.String(), decodeMap(t, rec)["id"])
}

func TestSchedules_Unavailable(t *testing.T) {
	api := &httpapi.API{}
	targets := []struct{ method, target, body string }{
		{http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-02", ""},
		{http.MethodPost, "/v1/schedules", `{"date":"2026-10-21","allDay":true,"title":"x"}`},
		{http.MethodDelete, scheduleTarget, ""},
		{http.MethodPost, scheduleTarget + "/restore", ""},
	}
	for _, tt := range targets {
		_, rec := sendDiary(t, api, tt.method, tt.target, tt.body)
		require.Equal(t, http.StatusServiceUnavailable, rec.Code, tt.target)
		assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	}
}

func TestUpdateSchedule_Inconsistent(t *testing.T) {
	violation := &profile.ValidationError{Violation: profile.Inconsistent, Fields: []profile.FieldViolation{{Field: "/time", Rule: profile.RequiredByStatus}}}
	handler, _ := newHandlerAPI(t, scheduleAPI(&fakeSchedules{err: violation}))
	req := newBodyRequest(t, http.MethodPatch, scheduleTarget, contentTypeMergePatch, `{"allDay":false}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "request.inconsistent", p.Code)
	require.Len(t, p.Errors, 1)
	assert.Equal(t, "/time", p.Errors[0].Field)
	assert.Equal(t, "required_by_status", p.Errors[0].Code)
	expectFortuneContract(t, req, rec)
}

func TestUpdateSchedule_Unavailable(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})
	rec := serve(handler, newBodyRequest(t, http.MethodPatch, scheduleTarget, contentTypeMergePatch, `{"title":"x"}`))

	require.Equal(t, http.StatusServiceUnavailable, rec.Code)
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
}

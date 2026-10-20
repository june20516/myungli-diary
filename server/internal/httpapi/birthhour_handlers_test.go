package httpapi_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// postBirthHourBody는 시진 확인 요청을 보내고 응답을 돌려줍니다.
func postBirthHourBody(t *testing.T, fake *enginetest.Fake, body gen.BirthHourRequest) (*http.Request, *httptest.ResponseRecorder, *openapi3.T) {
	t.Helper()
	raw, err := json.Marshal(body)
	require.NoError(t, err)
	handler, spec := newHandlerAPI(t, &httpapi.API{BirthHour: fake})
	req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/birth-hour", strings.NewReader(string(raw)))
	req.Header.Set("Content-Type", "application/json")
	return req, serve(handler, req), spec
}

func birthHourPayload(calendar gen.CalendarType, isLeap bool) gen.BirthHourRequest {
	return gen.BirthHourRequest{
		InstallationId: "i",
		Calendar:       calendar,
		Date:           gen.LunarOrSolarDate{Year: 1990, Month: 5, Day: 15},
		IsLeapMonth:    isLeap,
		Time:           "00:10",
	}
}

func seoulInstant(t *testing.T, day, clock string) *timestamppb.Timestamp {
	t.Helper()
	loc, err := time.LoadLocation("Asia/Seoul")
	require.NoError(t, err)
	at, err := time.ParseInLocation("2006-01-02 15:04", day+" "+clock, loc)
	require.NoError(t, err)
	return timestamppb.New(at)
}

func TestGetBirthHour_SendsSeoulFixedGenderWithoutLongitude(t *testing.T) {
	tests := []struct {
		name         string
		calendar     gen.CalendarType
		isLeap       bool
		wantCalendar enginev1.CalendarType
	}{
		{"양력", gen.CalendarType("solar"), false, enginev1.CalendarType_CALENDAR_TYPE_SOLAR},
		{"음력 윤달", gen.CalendarType("lunar"), true, enginev1.CalendarType_CALENDAR_TYPE_LUNAR},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got *enginev1.BirthHourRequest
			fake := &enginetest.Fake{BirthHour: func(req *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
				got = req
				return &enginev1.BirthHourResponse{Branch: enginev1.Branch_BRANCH_JA, Start: seoulInstant(t, "1990-05-14", "23:30"), End: seoulInstant(t, "1990-05-15", "01:30")}, nil
			}}

			_, rec, _ := postBirthHourBody(t, fake, birthHourPayload(tt.calendar, tt.isLeap))

			require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
			birth := got.GetBirth()
			assert.Equal(t, tt.wantCalendar, birth.GetCalendar())
			assert.Equal(t, tt.isLeap, birth.GetIsLeapMonth())
			assert.EqualValues(t, 1990, birth.GetDate().GetYear())
			assert.EqualValues(t, 5, birth.GetDate().GetMonth())
			assert.EqualValues(t, 15, birth.GetDate().GetDay())
			assert.EqualValues(t, 0, birth.GetTime().GetHour())
			assert.EqualValues(t, 10, birth.GetTime().GetMinute())
			assert.Equal(t, "Asia/Seoul", birth.GetTimezone())
			assert.Equal(t, enginev1.Gender_GENDER_MALE, birth.GetGender())
			assert.Nil(t, birth.Longitude)
		})
	}
}

func TestGetBirthHour_ReturnsSeoulWallClockAcrossMidnight(t *testing.T) {
	// 엔진은 절대 시각을 돌려주므로 UTC 값이어도 Asia/Seoul 벽시계로 나가야 합니다(자시 23:30~01:30).
	fake := &enginetest.Fake{BirthHour: func(*enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
		return &enginev1.BirthHourResponse{
			Branch: enginev1.Branch_BRANCH_JA,
			Start:  timestamppb.New(time.Date(1990, 5, 14, 14, 30, 0, 0, time.UTC)),
			End:    timestamppb.New(time.Date(1990, 5, 14, 16, 30, 0, 0, time.UTC)),
		}, nil
	}}

	req, rec, spec := postBirthHourBody(t, fake, birthHourPayload("solar", false))

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var resp gen.BirthHour
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, gen.Branch("ja"), resp.Branch)
	assert.Equal(t, "23:30", resp.Start)
	assert.Equal(t, "01:30", resp.End)
}

func TestGetBirthHour_SolarLeapMonthIs422Inconsistent(t *testing.T) {
	fake := &enginetest.Fake{}

	_, rec, _ := postBirthHourBody(t, fake, birthHourPayload("solar", true))

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "request.inconsistent", p.Code)
	assert.Equal(t, []problem.FieldError{{Field: "/isLeapMonth", Code: "forbidden_by_status"}}, p.Errors)
	assert.EqualValues(t, 0, fake.BirthHourCalls.Load())
}

func TestGetBirthHour_EngineDateErrorsAre422(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		wantCode string
	}{
		{"없는 날짜", engine.ErrInvalidArgument, "date.invalid"},
		{"지원 범위 밖", engine.ErrOutOfRange, "date.out_of_range"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &enginetest.Fake{BirthHour: func(*enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
				return nil, tt.err
			}}

			_, rec, _ := postBirthHourBody(t, fake, birthHourPayload("lunar", false))

			require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, tt.wantCode, p.Code)
			assert.Equal(t, []problem.FieldError{{Field: "/date", Code: tt.wantCode}}, p.Errors)
		})
	}
}

func TestGetBirthHour_MissingEngineInstantIs500(t *testing.T) {
	fake := &enginetest.Fake{BirthHour: func(*enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
		return &enginev1.BirthHourResponse{Branch: enginev1.Branch_BRANCH_JA}, nil
	}}

	_, rec, _ := postBirthHourBody(t, fake, birthHourPayload("solar", false))

	assert.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
}

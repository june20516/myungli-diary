package httpapi_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// postLunarDate는 음력 변환 요청을 보내고 응답을 돌려줍니다.
func postLunarDate(t *testing.T, fake *enginetest.Fake, body string) (*http.Request, *httptest.ResponseRecorder, *openapi3.T) {
	t.Helper()
	handler, spec := newHandlerAPI(t, &httpapi.API{Lunar: fake})
	req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/lunar-date", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	return req, serve(handler, req), spec
}

// lunarBody는 음력 변환 요청 본문입니다.
func lunarBody(year, month, day int, isLeap bool) string {
	b, _ := json.Marshal(gen.LunarDateRequest{
		InstallationId: "i",
		Date:           gen.LunarOrSolarDate{Year: year, Month: month, Day: day},
		IsLeapMonth:    isLeap,
	})
	return string(b)
}

func TestConvertLunarDate_Returns200(t *testing.T) {
	var got *enginev1.LunarDateRequest
	fake := &enginetest.Fake{LunarDate: func(req *enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
		got = req
		return &enginev1.LunarDateResponse{Solar: &enginev1.LocalDate{Year: 2026, Month: 2, Day: 17}}, nil
	}}
	req, rec, spec := postLunarDate(t, fake, lunarBody(2026, 1, 1, false))

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var resp gen.LunarConversion
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, "2026-02-17", resp.SolarDate.String())
	assert.False(t, resp.MonthHasLeap)
	require.NotNil(t, got)
	assert.EqualValues(t, 2026, got.GetDate().GetYear())
	assert.EqualValues(t, 1, got.GetDate().GetMonth())
	assert.EqualValues(t, 1, got.GetDate().GetDay())
	assert.False(t, got.GetIsLeapMonth())
}

func TestConvertLunarDate_InvalidIs422DateInvalid(t *testing.T) {
	// 평달에 없는 날(예: 29일까지인 달의 30일)은 /date입니다. 평달 요청은 다시 묻지 않습니다.
	fake := &enginetest.Fake{LunarDate: func(*enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
		return nil, engine.ErrInvalidArgument
	}}

	_, rec, _ := postLunarDate(t, fake, lunarBody(2026, 1, 30, false))

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "date.invalid", p.Code)
	assert.Equal(t, []problem.FieldError{{Field: "/date", Code: "date.invalid"}}, p.Errors)
	assert.EqualValues(t, 1, fake.LunarDateCalls.Load())
}

func TestConvertLunarDate_MissingLeapMonthPointsToIsLeapMonth(t *testing.T) {
	// 그해 그 달에 윤달이 없는데 윤달을 물으면 /isLeapMonth입니다. 평달로 다시 물어 가려냅니다.
	fake := &enginetest.Fake{LunarDate: func(req *enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
		if req.GetIsLeapMonth() {
			return nil, engine.ErrInvalidArgument
		}
		return &enginev1.LunarDateResponse{Solar: &enginev1.LocalDate{Year: 2026, Month: 2, Day: 17}, MonthHasLeap: false}, nil
	}}

	_, rec, _ := postLunarDate(t, fake, lunarBody(2026, 1, 1, true))

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "date.invalid", p.Code)
	assert.Equal(t, []problem.FieldError{{Field: "/isLeapMonth", Code: "date.invalid"}}, p.Errors)
	assert.EqualValues(t, 2, fake.LunarDateCalls.Load())
}

func TestConvertLunarDate_MissingDayInLeapMonthPointsToDate(t *testing.T) {
	// 윤달은 있지만 그 윤달에 없는 날(윤달 30일)이면 /date입니다.
	fake := &enginetest.Fake{LunarDate: func(req *enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
		if req.GetIsLeapMonth() {
			return nil, engine.ErrInvalidArgument
		}
		return &enginev1.LunarDateResponse{Solar: &enginev1.LocalDate{Year: 2025, Month: 7, Day: 24}, MonthHasLeap: true}, nil
	}}

	_, rec, _ := postLunarDate(t, fake, lunarBody(2025, 6, 30, true))

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	assert.Equal(t, []problem.FieldError{{Field: "/date", Code: "date.invalid"}}, decodeProblem(t, rec).Errors)
}

func TestConvertLunarDate_OutOfRangeIs422(t *testing.T) {
	fake := &enginetest.Fake{LunarDate: func(*enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
		return nil, engine.ErrOutOfRange
	}}

	_, rec, _ := postLunarDate(t, fake, lunarBody(2099, 12, 29, false))

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "date.out_of_range", p.Code)
	assert.Equal(t, []problem.FieldError{{Field: "/date", Code: "date.out_of_range"}}, p.Errors)
}

func TestConvertLunarDate_EngineUnavailableIs503(t *testing.T) {
	fake := &enginetest.Fake{LunarDate: func(*enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error) {
		return nil, engine.ErrUnavailable
	}}

	_, rec, _ := postLunarDate(t, fake, lunarBody(2026, 1, 1, false))

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "engine.unavailable", decodeProblem(t, rec).Code)
	assert.Equal(t, "5", rec.Header().Get("Retry-After"))
}

func TestConvertLunarDate_MissingSolarIs500(t *testing.T) {
	// 엔진이 양력 날짜 없이 성공을 돌려주면 계약을 지킬 수 없으므로 500입니다.
	fake := &enginetest.Fake{}

	_, rec, _ := postLunarDate(t, fake, lunarBody(2026, 1, 1, false))

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
}

func TestConvertLunarDate_WithoutEngineIs503(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})
	req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/lunar-date", strings.NewReader(lunarBody(2026, 1, 1, false)))
	req.Header.Set("Content-Type", "application/json")

	rec := serve(handler, req)

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
}

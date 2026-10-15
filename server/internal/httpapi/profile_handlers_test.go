package httpapi_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/profile/honorific"
)

// storedProfile은 도시 출생지와 알림 시각을 가진 저장된 프로필입니다. 경도는 저장 시 채워지는 값입니다.
func storedProfile() profile.Profile {
	longitude := 139.69
	return profile.Profile{
		Honorific:       "민지",
		Language:        "ko",
		CurrentTimezone: "Asia/Seoul",
		Birth: profile.Birth{
			Calendar:    profile.CalendarSolar,
			Date:        profile.LocalDate{Year: 1990, Month: 5, Day: 17},
			TimeStatus:  profile.TimeKnown,
			Time:        &profile.LocalTime{Hour: 7, Minute: 30},
			Gender:      "female",
			Timezone:    "Asia/Tokyo",
			PlaceStatus: profile.PlaceCity,
			CityID:      "tokyo",
			Longitude:   &longitude,
		},
		Notification: profile.Notification{Status: profile.NotifyEnabled, Time: &profile.LocalTime{Hour: 7, Minute: 5}},
	}
}

func TestGetProfile_Returns200(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me/profile", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.Profile
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, "민지", got.Honorific)
	assert.Equal(t, gen.LanguageKo, got.Language)
	assert.Equal(t, gen.BirthPlaceStatusCity, got.Birth.Place.Status)
	require.NotNil(t, got.Birth.Place.CityId)
	assert.Equal(t, "tokyo", *got.Birth.Place.CityId)
	require.NotNil(t, got.Birth.Time.Value)
	assert.Equal(t, "07:30", *got.Birth.Time.Value)
	require.NotNil(t, got.Notification.Time)
	assert.Equal(t, "07:05", *got.Notification.Time)
	assert.NotContains(t, rec.Body.String(), "longitude")
}

func TestGetProfile_MissingIs409(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}})

	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me/profile", nil)
	rec := serve(handler, req)

	require.Equal(t, http.StatusConflict, rec.Code, rec.Body.String())
	assert.Equal(t, "profile.required", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, req, rec)
}

func TestCreateProfile_WarningsInBody(t *testing.T) {
	saved := profile.Saved{Profile: storedProfile(), Warnings: []honorific.Code{honorific.SuffixStripped}}
	fp := &fakeProfiles{saved: saved}
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: fp})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.ProfileResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, []gen.FieldError{{Field: "/honorific", Code: "name.suffix_stripped"}}, got.Warnings)
	// 요청 본문이 도메인 프로필로 옮겨졌는지 확인합니다.
	assert.Equal(t, "민지", fp.gotPut.Honorific)
	assert.Equal(t, profile.LocalDate{Year: 1990, Month: 5, Day: 17}, fp.gotPut.Birth.Date)
	assert.Equal(t, &profile.LocalTime{Hour: 7, Minute: 30}, fp.gotPut.Birth.Time)
	assert.Equal(t, profile.PlaceNotAsked, fp.gotPut.Birth.PlaceStatus)
	assert.Equal(t, &profile.LocalTime{Hour: 7, Minute: 5}, fp.gotPut.Notification.Time)
}

func TestCreateProfile_NoWarningsIsEmptyArray(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{saved: profile.Saved{Profile: storedProfile()}}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Contains(t, rec.Body.String(), `"warnings":[]`)
	expectContractResponse(t, spec, req, rec)
}

func TestCreateProfile_ValidationMapsTo422(t *testing.T) {
	cases := []struct {
		name       string
		err        *profile.ValidationError
		wantCode   string
		wantFields []gen.FieldError
	}{
		{
			name: "시각 상태와 값이 어긋남",
			err: &profile.ValidationError{Violation: profile.Inconsistent, Fields: []profile.FieldViolation{
				{Field: "/birth/time/value", Rule: profile.RequiredByStatus},
			}},
			wantCode:   "request.inconsistent",
			wantFields: []gen.FieldError{{Field: "/birth/time/value", Code: "required_by_status"}},
		},
		{
			name: "허용하지 않는 값",
			err: &profile.ValidationError{Violation: profile.Inconsistent, Fields: []profile.FieldViolation{
				{Field: "/birth/isLeapMonth", Rule: profile.ForbiddenByStatus},
			}},
			wantCode:   "request.inconsistent",
			wantFields: []gen.FieldError{{Field: "/birth/isLeapMonth", Code: "forbidden_by_status"}},
		},
		{
			name:       "없는 날짜",
			err:        &profile.ValidationError{Violation: profile.DateInvalid, Fields: []profile.FieldViolation{{Field: "/birth/date"}}},
			wantCode:   "date.invalid",
			wantFields: []gen.FieldError{{Field: "/birth/date", Code: "date.invalid"}},
		},
		{
			name:       "지원 범위 밖",
			err:        &profile.ValidationError{Violation: profile.BirthOutOfRange, Fields: []profile.FieldViolation{{Field: "/birth/date"}}},
			wantCode:   "birth.out_of_range",
			wantFields: []gen.FieldError{{Field: "/birth/date", Code: "birth.out_of_range"}},
		},
		{
			name:       "시간대",
			err:        &profile.ValidationError{Violation: profile.TimezoneInvalid, Fields: []profile.FieldViolation{{Field: "/currentTimezone"}}},
			wantCode:   "timezone.invalid",
			wantFields: []gen.FieldError{{Field: "/currentTimezone", Code: "timezone.invalid"}},
		},
		{
			name:       "도시",
			err:        &profile.ValidationError{Violation: profile.CityNotFound, Fields: []profile.FieldViolation{{Field: "/birth/place/cityId"}}},
			wantCode:   "city.not_found",
			wantFields: []gen.FieldError{{Field: "/birth/place/cityId", Code: "city.not_found"}},
		},
		{
			name: "호칭 이모지",
			err: &profile.ValidationError{Violation: profile.HonorificRejected, Honorific: honorific.Emoji,
				Fields: []profile.FieldViolation{{Field: "/honorific"}}},
			wantCode:   "name.emoji",
			wantFields: []gen.FieldError{{Field: "/honorific", Code: "name.emoji"}},
		},
		{
			name: "호칭 빈 값",
			err: &profile.ValidationError{Violation: profile.HonorificRejected, Honorific: honorific.Empty,
				Fields: []profile.FieldViolation{{Field: "/honorific"}}},
			wantCode:   "name.empty",
			wantFields: []gen.FieldError{{Field: "/honorific", Code: "name.empty"}},
		},
		{
			name:       "엔진이 거부한 출생 정보",
			err:        &profile.ValidationError{Violation: profile.BirthInvalid, Fields: []profile.FieldViolation{{Field: "/birth/date"}}},
			wantCode:   "birth.invalid",
			wantFields: []gen.FieldError{{Field: "/birth/date", Code: "birth.invalid"}},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{err: tc.err}})

			req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
			rec := serve(handler, req)

			require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
			expectContractResponse(t, spec, req, rec)
			p := decodeProblem(t, rec)
			assert.Equal(t, tc.wantCode, p.Code)
			require.Len(t, p.Errors, len(tc.wantFields))
			for i, want := range tc.wantFields {
				assert.Equal(t, want.Field, p.Errors[i].Field)
				assert.Equal(t, want.Code, p.Errors[i].Code)
			}
		})
	}
}

func TestCreateProfile_EngineUnavailableIs503WithRetryAfter(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{err: engine.ErrUnavailable}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "5", rec.Header().Get("Retry-After"))
	assert.Equal(t, "engine.unavailable", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, req, rec)
}

func TestCreateProfile_EngineTimeoutIs504(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{err: engine.ErrTimeout}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusGatewayTimeout, rec.Code, rec.Body.String())
	assert.Empty(t, rec.Header().Get("Retry-After"))
	assert.Equal(t, "engine.timeout", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, req, rec)
}

func TestUpdateProfile_MergePatchOnlyTimezone(t *testing.T) {
	fp := &fakeProfiles{saved: profile.Saved{Profile: storedProfile()}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: fp})

	req := newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, `{"currentTimezone":"Asia/Tokyo"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	require.NotNil(t, fp.gotPatch.CurrentTimezone)
	assert.Equal(t, "Asia/Tokyo", *fp.gotPatch.CurrentTimezone)
	assert.Nil(t, fp.gotPatch.Honorific)
	assert.Nil(t, fp.gotPatch.Language)
	assert.Nil(t, fp.gotPatch.Birth)
	assert.Nil(t, fp.gotPatch.Notification)
}

func TestUpdateProfile_MissingIs409(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}})

	req := newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, `{"honorific":"민지"}`)
	rec := serve(handler, req)

	require.Equal(t, http.StatusConflict, rec.Code, rec.Body.String())
	assert.Equal(t, "profile.required", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, req, rec)
}

func TestCreateProfile_MissingProfileIs401LikeUnknownAccount(t *testing.T) {
	// 계약 PUT에는 409가 없습니다. 익명화 경합으로 계정이 사라진 경우는 계정 없음과 같은 401입니다.
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code, rec.Body.String())
	assert.Equal(t, "auth.token_invalid", decodeProblem(t, rec).Code)
	assert.Equal(t, `Bearer error="invalid_token"`, rec.Header().Get("WWW-Authenticate"))
	expectContractResponse(t, spec, req, rec)
}

func TestCreateProfile_SuffixWarningInBody(t *testing.T) {
	saved := profile.Saved{Profile: storedProfile(), Warnings: []honorific.Code{honorific.SuffixWarning}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: &fakeProfiles{saved: saved}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.ProfileResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, []gen.FieldError{{Field: "/honorific", Code: "name.suffix_warning"}}, got.Warnings)
}

func TestCreateProfile_UnknownWarningCodeIsDroppedWithErrorLog(t *testing.T) {
	saved := profile.Saved{Profile: storedProfile(), Warnings: []honorific.Code{honorific.Empty}}
	handler, spec, logs := newHandlerAPIWithLogs(t, &httpapi.API{Profiles: &fakeProfiles{saved: saved}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Contains(t, rec.Body.String(), `"warnings":[]`)
	assert.Contains(t, logs.String(), `"severity":"ERROR"`)
}

func TestCreateProfile_UnknownViolationIs500WithErrorLog(t *testing.T) {
	handler, spec, logs := newHandlerAPIWithLogs(t, &httpapi.API{Profiles: &fakeProfiles{err: &profile.ValidationError{Violation: 99}}})

	req := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, req)

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
	assert.Contains(t, logs.String(), `"severity":"ERROR"`)
	expectContractResponse(t, spec, req, rec)
}

func TestUpdateProfile_NullOrEmptyHonorificIs400(t *testing.T) {
	for _, body := range []string{`{"honorific":null}`, `{"honorific":""}`} {
		t.Run(body, func(t *testing.T) {
			fp := &fakeProfiles{}
			handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: fp})

			req := newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, body)
			rec := serve(handler, req)

			require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
			assert.Equal(t, "request.invalid", decodeProblem(t, rec).Code)
			expectContractResponse(t, spec, req, rec)
		})
	}
}

func TestUpdateProfile_MergePatchLanguageBirthNotification(t *testing.T) {
	fp := &fakeProfiles{saved: profile.Saved{Profile: storedProfile()}}
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: fp})
	body := `{"language":"ja","birth":` + validBirth + `,"notification":{"status":"enabled","time":"21:10"}}`

	req := newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, body)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	require.NotNil(t, fp.gotPatch.Language)
	assert.Equal(t, "ja", *fp.gotPatch.Language)
	require.NotNil(t, fp.gotPatch.Birth)
	assert.Equal(t, profile.LocalDate{Year: 1990, Month: 5, Day: 17}, fp.gotPatch.Birth.Date)
	assert.Equal(t, profile.CalendarSolar, fp.gotPatch.Birth.Calendar)
	require.NotNil(t, fp.gotPatch.Notification)
	assert.Equal(t, profile.NotifyEnabled, fp.gotPatch.Notification.Status)
	assert.Equal(t, &profile.LocalTime{Hour: 21, Minute: 10}, fp.gotPatch.Notification.Time)
	assert.Nil(t, fp.gotPatch.Honorific)
	assert.Nil(t, fp.gotPatch.CurrentTimezone)
}

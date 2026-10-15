package httpapi

import (
	"context"
	"fmt"
	"time"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/profile/honorific"
)

// 호칭 경고의 code입니다. problem code가 아니라 ProfileResponse.warnings가 정한 값이라 registry 밖에 둡니다.
const (
	warningSuffixStripped = "name.suffix_stripped"
	warningSuffixWarning  = "name.suffix_warning"
	// warningHonorificField는 경고가 가리키는 위치(요청 본문 기준 JSON Pointer)입니다.
	warningHonorificField = "/honorific"
)

// clockLayout은 계약의 HH:MM 시각 형식입니다.
const clockLayout = "15:04"

// GetProfile은 저장된 프로필을 돌려줍니다. 없으면 409 profile.required입니다.
func (a *API) GetProfile(ctx context.Context, _ gen.GetProfileRequestObject) (gen.GetProfileResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	p, err := a.Profiles.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	return gen.GetProfile200JSONResponse(fromProfile(p)), nil
}

// CreateProfile은 프로필을 만들거나 통째로 바꿉니다.
func (a *API) CreateProfile(ctx context.Context, req gen.CreateProfileRequestObject) (gen.CreateProfileResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	saved, err := a.Profiles.Put(ctx, id, toProfile(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.CreateProfile200JSONResponse(fromSaved(saved)), nil
}

// UpdateProfile은 본문에 있는 필드만 바꿉니다. 프로필이 없으면 409 profile.required입니다.
func (a *API) UpdateProfile(ctx context.Context, req gen.UpdateProfileRequestObject) (gen.UpdateProfileResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	saved, err := a.Profiles.Patch(ctx, id, toPatch(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.UpdateProfile200JSONResponse(fromSaved(saved)), nil
}

// toProfile은 요청 본문을 도메인 프로필로 바꿉니다.
func toProfile(in gen.ProfileInput) profile.Profile {
	return profile.Profile{
		Honorific:       in.Honorific,
		Language:        string(in.Language),
		CurrentTimezone: in.CurrentTimezone,
		Birth:           toBirth(in.Birth),
		Notification:    toNotification(in.Notification),
	}
}

// toPatch는 PATCH 본문을 도메인 Patch로 바꿉니다. 본문에 없는 필드는 생성 타입의 nil 포인터로 남아 바꾸지 않음이 됩니다.
func toPatch(in gen.ProfilePatch) profile.Patch {
	patch := profile.Patch{
		Honorific:       in.Honorific,
		CurrentTimezone: in.CurrentTimezone,
	}
	if in.Language != nil {
		language := string(*in.Language)
		patch.Language = &language
	}
	if in.Birth != nil {
		birth := toBirth(*in.Birth)
		patch.Birth = &birth
	}
	if in.Notification != nil {
		notification := toNotification(*in.Notification)
		patch.Notification = &notification
	}
	return patch
}

func toBirth(in gen.Birth) profile.Birth {
	birth := profile.Birth{
		Calendar:    profile.Calendar(in.Calendar),
		IsLeapMonth: in.IsLeapMonth,
		Date:        profile.LocalDate{Year: in.Date.Year, Month: in.Date.Month, Day: in.Date.Day},
		TimeStatus:  profile.TimeStatus(in.Time.Status),
		Time:        parseClock(in.Time.Value),
		Gender:      string(in.Gender),
		Timezone:    in.Timezone,
		PlaceStatus: profile.PlaceStatus(in.Place.Status),
	}
	if in.Place.CityId != nil {
		birth.CityID = *in.Place.CityId
	}
	return birth
}

func toNotification(in gen.NotificationSetting) profile.Notification {
	return profile.Notification{Status: profile.NotifyStatus(in.Status), Time: parseClock(in.Time)}
}

// parseClock은 HH:MM 문자열을 시각으로 바꿉니다. 없거나 형식이 틀리면 nil입니다.
// 형식은 계약 검증(pattern)이 이미 보장하므로, 틀린 값은 "값 없음"으로 두어 상태-값 짝 검사가 422로 거릅니다.
func parseClock(value *string) *profile.LocalTime {
	if value == nil {
		return nil
	}
	parsed, err := time.Parse(clockLayout, *value)
	if err != nil {
		return nil
	}
	return &profile.LocalTime{Hour: parsed.Hour(), Minute: parsed.Minute()}
}

// fromProfile은 도메인 프로필을 응답 본문으로 바꿉니다. 경도는 계약에 없어 내보내지 않습니다.
func fromProfile(p profile.Profile) gen.Profile {
	birth := gen.Birth{
		Calendar:    gen.CalendarType(p.Birth.Calendar),
		Date:        gen.LunarOrSolarDate{Year: p.Birth.Date.Year, Month: p.Birth.Date.Month, Day: p.Birth.Date.Day},
		Gender:      gen.BirthGender(p.Birth.Gender),
		IsLeapMonth: p.Birth.IsLeapMonth,
		Place:       gen.BirthPlace{Status: gen.BirthPlaceStatus(p.Birth.PlaceStatus)},
		Time:        gen.BirthTime{Status: gen.BirthTimeStatus(p.Birth.TimeStatus), Value: formatClock(p.Birth.Time)},
		Timezone:    p.Birth.Timezone,
	}
	if p.Birth.PlaceStatus == profile.PlaceCity {
		cityID := p.Birth.CityID
		birth.Place.CityId = &cityID
	}
	return gen.Profile{
		Birth:           birth,
		CurrentTimezone: p.CurrentTimezone,
		Honorific:       p.Honorific,
		Language:        gen.Language(p.Language),
		Notification: gen.NotificationSetting{
			Status: gen.NotificationSettingStatus(p.Notification.Status),
			Time:   formatClock(p.Notification.Time),
		},
	}
}

func formatClock(t *profile.LocalTime) *string {
	if t == nil {
		return nil
	}
	formatted := fmt.Sprintf("%02d:%02d", t.Hour, t.Minute)
	return &formatted
}

// fromSaved는 저장 결과를 응답 본문으로 바꿉니다. warnings는 비어 있어도 항상 배열입니다.
func fromSaved(saved profile.Saved) gen.ProfileResponse {
	warnings := make([]gen.FieldError, 0, len(saved.Warnings))
	for _, w := range saved.Warnings {
		if code, ok := warningCode(w); ok {
			warnings = append(warnings, gen.FieldError{Field: warningHonorificField, Code: code})
		}
	}
	return gen.ProfileResponse{Profile: fromProfile(saved.Profile), Warnings: warnings}
}

func warningCode(c honorific.Code) (string, bool) {
	switch c {
	case honorific.SuffixStripped:
		return warningSuffixStripped, true
	case honorific.SuffixWarning:
		return warningSuffixWarning, true
	case honorific.None, honorific.Empty, honorific.TooLong, honorific.Emoji, honorific.Control, honorific.InvalidChar:
		return "", false
	}
	return "", false
}

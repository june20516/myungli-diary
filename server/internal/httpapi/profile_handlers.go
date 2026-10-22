package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/city"
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
	return gen.GetProfile200JSONResponse(a.fromProfile(ctx, p)), nil
}

// CreateProfile은 프로필을 만들거나 통째로 바꿉니다.
func (a *API) CreateProfile(ctx context.Context, req gen.CreateProfileRequestObject) (gen.CreateProfileResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	input, err := toProfile(*req.Body)
	if err != nil {
		return nil, err
	}
	saved, err := a.Profiles.Put(ctx, id, input)
	if err != nil {
		// 계약 PUT에는 409가 없습니다. 인증 뒤 계정이 지워진 경합은 계정 없음과 같은 401로 답합니다.
		if errors.Is(err, profile.ErrNotFound) {
			return nil, fmt.Errorf("프로필 저장 중 계정이 사라졌습니다: %w", account.ErrNotFound)
		}
		return nil, err
	}
	return gen.CreateProfile200JSONResponse(a.fromSaved(ctx, saved)), nil
}

// UpdateProfile은 본문에 있는 필드만 바꿉니다. 프로필이 없으면 409 profile.required입니다.
func (a *API) UpdateProfile(ctx context.Context, req gen.UpdateProfileRequestObject) (gen.UpdateProfileResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	patch, err := toPatch(*req.Body)
	if err != nil {
		return nil, err
	}
	saved, err := a.Profiles.Patch(ctx, id, patch)
	if err != nil {
		return nil, err
	}
	return gen.UpdateProfile200JSONResponse(a.fromSaved(ctx, saved)), nil
}

// toProfile은 요청 본문을 도메인 프로필로 바꿉니다. 시각 형식이 틀리면 오류입니다.
func toProfile(in gen.ProfileInput) (profile.Profile, error) {
	birth, err := toBirth(in.Birth)
	if err != nil {
		return profile.Profile{}, err
	}
	notification, err := toNotification(in.Notification)
	if err != nil {
		return profile.Profile{}, err
	}
	return profile.Profile{
		Honorific:       in.Honorific,
		Language:        string(in.Language),
		CurrentTimezone: in.CurrentTimezone,
		Birth:           birth,
		Notification:    notification,
	}, nil
}

// toPatch는 PATCH 본문을 도메인 Patch로 바꿉니다. 본문에 없는 필드는 생성 타입의 nil 포인터로 남아 바꾸지 않음이 됩니다.
func toPatch(in gen.ProfilePatch) (profile.Patch, error) {
	patch := profile.Patch{
		Honorific:       in.Honorific,
		CurrentTimezone: in.CurrentTimezone,
	}
	if in.Language != nil {
		language := string(*in.Language)
		patch.Language = &language
	}
	if in.Birth != nil {
		birth, err := toBirth(*in.Birth)
		if err != nil {
			return profile.Patch{}, err
		}
		patch.Birth = &birth
	}
	if in.Notification != nil {
		notification, err := toNotification(*in.Notification)
		if err != nil {
			return profile.Patch{}, err
		}
		patch.Notification = &notification
	}
	return patch, nil
}

func toBirth(in gen.Birth) (profile.Birth, error) {
	birthTime, err := parseClock(in.Time.Value)
	if err != nil {
		return profile.Birth{}, err
	}
	birth := profile.Birth{
		Calendar:    profile.Calendar(in.Calendar),
		IsLeapMonth: in.IsLeapMonth,
		Date:        profile.LocalDate{Year: in.Date.Year, Month: in.Date.Month, Day: in.Date.Day},
		TimeStatus:  profile.TimeStatus(in.Time.Status),
		Time:        birthTime,
		Gender:      string(in.Gender),
		Timezone:    in.Timezone,
		PlaceStatus: profile.PlaceStatus(in.Place.Status),
	}
	if in.Place.CityId != nil {
		birth.CityID = *in.Place.CityId
	}
	return birth, nil
}

func toNotification(in gen.NotificationSetting) (profile.Notification, error) {
	notifyTime, err := parseClock(in.Time)
	if err != nil {
		return profile.Notification{}, err
	}
	return profile.Notification{Status: profile.NotifyStatus(in.Status), Time: notifyTime}, nil
}

// parseClock은 HH:MM 문자열을 시각으로 바꿉니다. 없으면 nil입니다.
// 형식은 계약 검증(pattern)이 이미 보장하므로 형식 오류는 프로그램 오류이고, 핸들러가 500으로 드러냅니다.
// 오류 문구에는 입력 값을 넣지 않습니다.
func parseClock(value *string) (*profile.LocalTime, error) {
	if value == nil {
		return nil, nil
	}
	parsed, err := time.Parse(clockLayout, *value)
	if err != nil {
		return nil, errors.New("계약 검증을 통과한 시각이 HH:MM 형식이 아닙니다")
	}
	return &profile.LocalTime{Hour: parsed.Hour(), Minute: parsed.Minute()}, nil
}

// fromProfile은 도메인 프로필을 응답 본문으로 바꿉니다. 경도는 birth.place가 아니라 birthCity에만 내보냅니다.
func (a *API) fromProfile(ctx context.Context, p profile.Profile) gen.Profile {
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
		BirthCity:       a.birthCity(ctx, p),
		CurrentTimezone: p.CurrentTimezone,
		Honorific:       p.Honorific,
		Language:        gen.Language(p.Language),
		Notification: gen.NotificationSetting{
			Status: gen.NotificationSettingStatus(p.Notification.Status),
			Time:   formatClock(p.Notification.Time),
		},
	}
}

// birthCity는 출생 도시를 프로필 언어 이름으로 돌려줍니다(#199). 도시 출생이 아니면 nil입니다.
// 경도는 엔진 계산에 쓰는 저장된 경도이고, 없으면 도시 자료의 경도입니다(server 결정 S46).
// 도시 자료가 바뀌어 저장된 id를 찾을 수 없으면 Warn을 남기고 nil입니다. app은 그때 경도 안내를 그리지 않습니다.
func (a *API) birthCity(ctx context.Context, p profile.Profile) *gen.City {
	if p.Birth.PlaceStatus != profile.PlaceCity {
		return nil
	}
	c, ok := city.Lookup(p.Birth.CityID)
	if !ok {
		a.Logger.WarnContext(ctx, "저장된 출생 도시를 도시 자료에서 찾지 못해 birthCity를 뺍니다",
			slog.String("city_id", p.Birth.CityID), slog.String("city_data_version", city.DataVersion()))
		return nil
	}
	longitude := c.Longitude
	if p.Birth.Longitude != nil {
		longitude = *p.Birth.Longitude
	}
	out := toCity(c, p.Language, longitude)
	return &out
}

// toCity는 도시 자료를 계약 City로 옮깁니다. 이름은 lang(ko·en·ja, 그 밖은 en)이고, 경도는 호출자가 정합니다.
// birthCity는 저장된 경도를, listCities는 도시 자료의 경도를 넘깁니다.
func toCity(c city.City, lang string, longitude float64) gen.City {
	out := gen.City{
		Id:          c.ID,
		Name:        c.Name(lang),
		Country:     c.Country,
		CountryName: c.CountryName(lang),
		Timezone:    c.Timezone,
		Longitude:   float32(longitude),
	}
	if region, ok := c.RegionName(lang); ok {
		out.RegionName = &region
	}
	return out
}

func formatClock(t *profile.LocalTime) *string {
	if t == nil {
		return nil
	}
	formatted := fmt.Sprintf("%02d:%02d", t.Hour, t.Minute)
	return &formatted
}

// fromSaved는 저장 결과를 응답 본문으로 바꿉니다. warnings는 비어 있어도 항상 배열입니다.
// 알 수 없는 경고 code는 응답에서 빼고 Error 로그를 남깁니다(호칭 값은 남기지 않습니다).
func (a *API) fromSaved(ctx context.Context, saved profile.Saved) gen.ProfileResponse {
	warnings := make([]gen.FieldError, 0, len(saved.Warnings))
	for _, w := range saved.Warnings {
		code, ok := warningCode(w)
		if !ok {
			a.Logger.ErrorContext(ctx, "알 수 없는 호칭 경고 code", slog.Int("warning", int(w)))
			continue
		}
		warnings = append(warnings, gen.FieldError{Field: warningHonorificField, Code: code})
	}
	return gen.ProfileResponse{Profile: a.fromProfile(ctx, saved.Profile), Warnings: warnings}
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

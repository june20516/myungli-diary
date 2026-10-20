package profile

import (
	"errors"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/engine"
)

const (
	seoulID = "1835848"
	tokyoID = "1850147"
)

func validBirth() Birth {
	return Birth{
		Calendar:    CalendarSolar,
		Date:        LocalDate{Year: 1990, Month: 5, Day: 17},
		TimeStatus:  TimeUnknown,
		Gender:      "female",
		Timezone:    "Asia/Seoul",
		PlaceStatus: PlaceSkipped,
	}
}

func requireViolation(t *testing.T, err error, want Violation, field string, rule StatusRule) {
	t.Helper()
	var ve *ValidationError
	require.True(t, errors.As(err, &ve), "ValidationError여야 합니다: %v", err)
	assert.Equal(t, want, ve.Violation)
	require.Len(t, ve.Fields, 1)
	assert.Equal(t, FieldViolation{Field: field, Rule: rule}, ve.Fields[0])
}

func TestValidateBirth_StatusPairs(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(b *Birth)
		field  string
		rule   StatusRule
	}{
		{"known인데 시각 없음", func(b *Birth) { b.TimeStatus = TimeKnown }, "/birth/time/value", RequiredByStatus},
		{"unknown인데 시각 있음", func(b *Birth) { b.Time = &LocalTime{Hour: 9} }, "/birth/time/value", ForbiddenByStatus},
		{"city인데 id 없음", func(b *Birth) { b.PlaceStatus = PlaceCity }, "/birth/place/cityId", RequiredByStatus},
		{"skipped인데 id 있음", func(b *Birth) { b.CityID = seoulID }, "/birth/place/cityId", ForbiddenByStatus},
		{"not_asked인데 id 있음", func(b *Birth) { b.PlaceStatus = PlaceNotAsked; b.CityID = seoulID }, "/birth/place/cityId", ForbiddenByStatus},
		{"양력인데 윤달", func(b *Birth) { b.IsLeapMonth = true }, "/birth/isLeapMonth", ForbiddenByStatus},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b := validBirth()
			tt.mutate(&b)
			_, err := ValidateBirth(b, "/birth")
			requireViolation(t, err, Inconsistent, tt.field, tt.rule)
		})
	}
}

func TestValidateBirth_Valid(t *testing.T) {
	b := validBirth()
	b.TimeStatus = TimeKnown
	b.Time = &LocalTime{Hour: 9, Minute: 30}
	_, err := ValidateBirth(b, "/birth")
	require.NoError(t, err)
}

func TestValidateBirth_SolarDateExists(t *testing.T) {
	tests := []struct {
		name string
		date LocalDate
		ok   bool
	}{
		{"평년 2월 29일", LocalDate{2023, 2, 29}, false},
		{"윤년 2월 29일", LocalDate{2024, 2, 29}, true},
		{"4월 31일", LocalDate{2026, 4, 31}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b := validBirth()
			b.Date = tt.date
			_, err := ValidateBirth(b, "/birth")
			if tt.ok {
				require.NoError(t, err)
				return
			}
			requireViolation(t, err, DateInvalid, "/birth/date", NoStatusRule)
		})
	}
}

func TestValidateBirth_D41Range(t *testing.T) {
	tests := []struct {
		name string
		date LocalDate
		ok   bool
	}{
		{"하한 하루 전", LocalDate{1900, 1, 30}, false},
		{"하한", LocalDate{1900, 1, 31}, true},
		{"상한", LocalDate{2099, 12, 31}, true},
		{"상한 다음 해", LocalDate{2100, 1, 1}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b := validBirth()
			b.Date = tt.date
			_, err := ValidateBirth(b, "/birth")
			if tt.ok {
				require.NoError(t, err)
				return
			}
			requireViolation(t, err, BirthOutOfRange, "/birth/date", NoStatusRule)
		})
	}
}

func TestValidateBirth_LunarSkipsCalendarChecks(t *testing.T) {
	b := validBirth()
	b.Calendar = CalendarLunar
	b.Date = LocalDate{1990, 2, 30}
	_, err := ValidateBirth(b, "/birth")
	require.NoError(t, err)

	b.IsLeapMonth = true
	_, err = ValidateBirth(b, "/birth")
	require.NoError(t, err)
}

func TestValidateBirth_Timezone(t *testing.T) {
	for _, name := range []string{"Asia/Seoul", "UTC", "Etc/UTC"} {
		b := validBirth()
		b.Timezone = name
		_, err := ValidateBirth(b, "/birth")
		require.NoError(t, err, name)
	}
	for _, name := range []string{"Mars/Base", "", "Local"} {
		b := validBirth()
		b.Timezone = name
		_, err := ValidateBirth(b, "/birth")
		requireViolation(t, err, TimezoneInvalid, "/birth/timezone", NoStatusRule)
	}
}

func TestValidateTimezone(t *testing.T) {
	require.NoError(t, ValidateTimezone("America/New_York", "/currentTimezone"))
	requireViolation(t, ValidateTimezone("Nope/Nope", "/currentTimezone"), TimezoneInvalid, "/currentTimezone", NoStatusRule)
}

func TestValidateBirth_CityFillsLongitude(t *testing.T) {
	b := validBirth()
	b.PlaceStatus = PlaceCity
	b.CityID = tokyoID
	b.Longitude = ptr(1.0) // 입력의 값은 도시 값으로 덮어씁니다.

	got, err := ValidateBirth(b, "/birth")
	require.NoError(t, err)
	require.NotNil(t, got.Longitude)
	assert.InDelta(t, 139.69, *got.Longitude, 0.1)
	assert.InDelta(t, 1.0, *b.Longitude, 0, "입력은 바뀌지 않습니다")

	b.CityID = "0"
	_, err = ValidateBirth(b, "/birth")
	requireViolation(t, err, CityNotFound, "/birth/place/cityId", NoStatusRule)
}

func TestValidateBirth_NonCityHasNoLongitude(t *testing.T) {
	b := validBirth()
	b.Longitude = ptr(126.9)
	got, err := ValidateBirth(b, "/birth")
	require.NoError(t, err)
	assert.Nil(t, got.Longitude)
}

func TestValidateBirth_DoesNotAliasInputTime(t *testing.T) {
	b := validBirth()
	b.TimeStatus = TimeKnown
	b.Time = &LocalTime{Hour: 9, Minute: 30}

	got, err := ValidateBirth(b, "/birth")
	require.NoError(t, err)
	require.NotNil(t, got.Time)
	got.Time.Hour = 23
	assert.Equal(t, 9, b.Time.Hour, "사본의 Time을 바꿔도 입력은 그대로여야 합니다")
}

func TestValidateBirth_CheckOrder(t *testing.T) {
	t.Run("상태 짝이 날짜보다 먼저", func(t *testing.T) {
		b := validBirth()
		b.TimeStatus = TimeKnown // 시각 없음
		b.Date = LocalDate{2023, 2, 29}
		_, err := ValidateBirth(b, "/birth")
		requireViolation(t, err, Inconsistent, "/birth/time/value", RequiredByStatus)
	})
	t.Run("날짜가 시간대보다 먼저", func(t *testing.T) {
		b := validBirth()
		b.Date = LocalDate{2023, 2, 29}
		b.Timezone = "Mars/Base"
		_, err := ValidateBirth(b, "/birth")
		requireViolation(t, err, DateInvalid, "/birth/date", NoStatusRule)
	})
	t.Run("범위가 도시보다 먼저", func(t *testing.T) {
		b := validBirth()
		b.Date = LocalDate{1900, 1, 30}
		b.PlaceStatus = PlaceCity
		b.CityID = "0"
		_, err := ValidateBirth(b, "/birth")
		requireViolation(t, err, BirthOutOfRange, "/birth/date", NoStatusRule)
	})
}

func TestValidateBirth_PointerPrefix(t *testing.T) {
	b := validBirth()
	b.Date = LocalDate{2023, 2, 29}
	_, err := ValidateBirth(b, "/profile/birth")
	requireViolation(t, err, DateInvalid, "/profile/birth/date", NoStatusRule)
}

func TestValidateNotification(t *testing.T) {
	tests := []struct {
		name string
		n    Notification
		ok   bool
		rule StatusRule
	}{
		{"enabled 시각 없음", Notification{Status: NotifyEnabled}, false, RequiredByStatus},
		{"disabled 시각 있음", Notification{Status: NotifyDisabled, Time: &LocalTime{Hour: 8}}, false, ForbiddenByStatus},
		{"not_asked 시각 있음", Notification{Status: NotifyNotAsked, Time: &LocalTime{Hour: 8}}, false, ForbiddenByStatus},
		{"enabled 시각 있음", Notification{Status: NotifyEnabled, Time: &LocalTime{Hour: 8}}, true, NoStatusRule},
		{"disabled", Notification{Status: NotifyDisabled}, true, NoStatusRule},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateNotification(tt.n, "/notification")
			if tt.ok {
				require.NoError(t, err)
				return
			}
			requireViolation(t, err, Inconsistent, "/notification/time", tt.rule)
		})
	}
}

func TestValidationError_ErrorHasNoValues(t *testing.T) {
	b := validBirth()
	b.Date = LocalDate{2023, 2, 29}
	_, err := ValidateBirth(b, "/birth")
	assert.Equal(t, "출생 정보 의미 검사 위반: DateInvalid /birth/date", err.Error())
}

func ptr[T any](v T) *T { return &v }

func TestLocalDate_After(t *testing.T) {
	base := LocalDate{2026, 10, 20}
	assert.True(t, LocalDate{2026, 10, 21}.After(base))
	assert.True(t, LocalDate{2026, 11, 1}.After(base))
	assert.True(t, LocalDate{2027, 1, 1}.After(base))
	assert.False(t, base.After(base))
	assert.False(t, LocalDate{2026, 10, 19}.After(base))
	assert.False(t, LocalDate{2025, 12, 31}.After(base))
}

func TestEngineBirthViolation(t *testing.T) {
	requireViolation(t, EngineBirthViolation(engine.ErrInvalidArgument, "/birth"), BirthInvalid, "/birth", NoStatusRule)
	requireViolation(t, EngineBirthViolation(fmt.Errorf("감쌈: %w", engine.ErrOutOfRange), "/birth"), BirthOutOfRange, "/birth/date", NoStatusRule)
	assert.NoError(t, EngineBirthViolation(nil, "/birth"))
	other := errors.New("그 밖")
	assert.Same(t, other, EngineBirthViolation(other, "/birth"), "해당 없는 오류는 그대로")
}

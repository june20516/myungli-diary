package fortune

import (
	"errors"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// toBirthInfo는 프로필의 출생 정보를 엔진 요청의 BirthInfo로 바꿉니다.
// 시각은 TimeStatus가 known이고 Time이 있을 때만, 경도는 Longitude가 있을 때만 넣습니다.
// 알 수 없는 달력·성별은 프로그램 오류이므로 UNSPECIFIED로 흘리지 않고 오류로 돌려줍니다(값은 문구에 넣지 않습니다).
func toBirthInfo(b profile.Birth) (*enginev1.BirthInfo, error) {
	var calendar enginev1.CalendarType
	switch b.Calendar {
	case profile.CalendarSolar:
		calendar = enginev1.CalendarType_CALENDAR_TYPE_SOLAR
	case profile.CalendarLunar:
		calendar = enginev1.CalendarType_CALENDAR_TYPE_LUNAR
	default:
		return nil, errors.New("엔진 요청으로 바꿀 수 없는 달력 값입니다")
	}

	var gender enginev1.Gender
	switch b.Gender {
	case "male":
		gender = enginev1.Gender_GENDER_MALE
	case "female":
		gender = enginev1.Gender_GENDER_FEMALE
	default:
		return nil, errors.New("엔진 요청으로 바꿀 수 없는 성별 값입니다")
	}

	info := &enginev1.BirthInfo{
		Calendar:    calendar,
		IsLeapMonth: b.IsLeapMonth,
		Date:        toLocalDate(b.Date),
		Gender:      gender,
		Timezone:    b.Timezone,
		Longitude:   b.Longitude,
	}
	if b.TimeStatus == profile.TimeKnown && b.Time != nil {
		info.Time = &enginev1.LocalTime{Hour: toInt32(b.Time.Hour), Minute: toInt32(b.Time.Minute)}
	}
	return info, nil
}

func toLocalDate(d profile.LocalDate) *enginev1.LocalDate {
	return &enginev1.LocalDate{Year: toInt32(d.Year), Month: toInt32(d.Month), Day: toInt32(d.Day)}
}

// toInt32는 연·월·일·시·분 값을 proto 정수로 바꿉니다. 출생 값은 ValidateBirth가, 조회 연·월은 요청 스키마가 범위를 보장합니다.
func toInt32(v int) int32 {
	return int32(v) //nolint:gosec // 범위는 위 검증이 보장합니다
}

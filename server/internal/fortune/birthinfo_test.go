package fortune

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

func TestToBirthInfo(t *testing.T) {
	longitude := 126.98
	base := profile.Birth{
		Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1990, Month: 5, Day: 17},
		TimeStatus: profile.TimeUnknown, Gender: "male", Timezone: "Asia/Seoul", PlaceStatus: profile.PlaceNotAsked,
	}

	t.Run("시각을 모르면 time이 없다", func(t *testing.T) {
		info, err := toBirthInfo(base)
		require.NoError(t, err)
		assert.Nil(t, info.Time)
		assert.Equal(t, enginev1.Gender_GENDER_MALE, info.Gender)
		assert.Equal(t, enginev1.CalendarType_CALENDAR_TYPE_SOLAR, info.Calendar)
		assert.EqualValues(t, 17, info.Date.Day)
	})

	t.Run("출생지를 묻지 않았으면 longitude가 없다", func(t *testing.T) {
		info, err := toBirthInfo(base)
		require.NoError(t, err)
		assert.Nil(t, info.Longitude)
	})

	t.Run("아는 시각과 도시 경도를 담는다", func(t *testing.T) {
		b := base
		b.TimeStatus = profile.TimeKnown
		b.Time = &profile.LocalTime{Hour: 7, Minute: 30}
		b.PlaceStatus = profile.PlaceCity
		b.Longitude = &longitude
		info, err := toBirthInfo(b)
		require.NoError(t, err)
		require.NotNil(t, info.Time)
		assert.EqualValues(t, 7, info.Time.Hour)
		assert.EqualValues(t, 30, info.Time.Minute)
		require.NotNil(t, info.Longitude)
		assert.InDelta(t, longitude, *info.Longitude, 1e-9)
	})

	t.Run("음력 윤달", func(t *testing.T) {
		b := base
		b.Calendar = profile.CalendarLunar
		b.IsLeapMonth = true
		b.Gender = "female"
		info, err := toBirthInfo(b)
		require.NoError(t, err)
		assert.Equal(t, enginev1.CalendarType_CALENDAR_TYPE_LUNAR, info.Calendar)
		assert.True(t, info.IsLeapMonth)
		assert.Equal(t, enginev1.Gender_GENDER_FEMALE, info.Gender)
	})

	t.Run("알 수 없는 값은 오류이고 값을 문구에 넣지 않는다", func(t *testing.T) {
		b := base
		b.Gender = "zzz"
		_, err := toBirthInfo(b)
		require.Error(t, err)
		assert.NotContains(t, err.Error(), "zzz")

		b = base
		b.Calendar = "qqq"
		_, err = toBirthInfo(b)
		require.Error(t, err)
		assert.NotContains(t, err.Error(), "qqq")
	})
}

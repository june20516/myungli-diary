package profile

import (
	"time"

	"github.com/jackc/pgx/v5/pgtype"
)

// 이 파일은 달력 날짜·시각과 DB date·time 값의 변환을 둡니다. 값 타입의 소유자가 한 곳에서 맞춥니다.

// PgDate는 달력 날짜를 DB date 값으로 바꿉니다.
func PgDate(d LocalDate) pgtype.Date {
	return pgtype.Date{Time: time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC), Valid: true}
}

// PgDateOrNull은 nil이면 NULL인 PgDate입니다.
func PgDateOrNull(d *LocalDate) pgtype.Date {
	if d == nil {
		return pgtype.Date{}
	}
	return PgDate(*d)
}

// LocalDateFromPg는 DB date 값을 달력 날짜로 바꿉니다.
func LocalDateFromPg(d pgtype.Date) LocalDate {
	return LocalDate{Year: d.Time.Year(), Month: int(d.Time.Month()), Day: d.Time.Day()}
}

// PgTime은 시:분을 DB time 값으로 바꿉니다. nil이면 NULL입니다.
func PgTime(t *LocalTime) pgtype.Time {
	if t == nil {
		return pgtype.Time{}
	}
	micros := int64(t.Hour*60+t.Minute) * int64(time.Minute/time.Microsecond)
	return pgtype.Time{Microseconds: micros, Valid: true}
}

// LocalTimeFromPg는 DB time 값을 시:분으로 바꿉니다. NULL이면 nil입니다.
func LocalTimeFromPg(t pgtype.Time) *LocalTime {
	if !t.Valid {
		return nil
	}
	minutes := int(t.Microseconds / int64(time.Minute/time.Microsecond))
	return &LocalTime{Hour: minutes / 60, Minute: minutes % 60}
}

package profile_test

import (
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

func TestPgConversions_RoundTrip(t *testing.T) {
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 20}
	assert.Equal(t, date, profile.LocalDateFromPg(profile.PgDate(date)))
	assert.Equal(t, pgtype.Date{}, profile.PgDateOrNull(nil))
	assert.Equal(t, profile.PgDate(date), profile.PgDateOrNull(&date))

	clock := &profile.LocalTime{Hour: 23, Minute: 59}
	assert.Equal(t, clock, profile.LocalTimeFromPg(profile.PgTime(clock)))
	assert.Equal(t, pgtype.Time{}, profile.PgTime(nil))
	assert.Nil(t, profile.LocalTimeFromPg(pgtype.Time{}))
	assert.Equal(t, int64(9*60+5)*60_000_000, profile.PgTime(&profile.LocalTime{Hour: 9, Minute: 5}).Microseconds)
}

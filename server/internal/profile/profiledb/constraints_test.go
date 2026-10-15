package profiledb_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile/profiledb"
)

const checkViolation = "23514"

// validParams는 제약을 모두 만족하는 프로필 값입니다. 각 테스트가 한 열만 어긋나게 바꿉니다.
func validParams(accountID uuid.UUID) profiledb.UpsertProfileParams {
	return profiledb.UpsertProfileParams{
		AccountID:        accountID,
		Honorific:        pgtype.Text{String: "민수", Valid: true},
		Language:         "ko",
		CurrentTimezone:  "Asia/Seoul",
		Calendar:         pgtype.Text{String: "solar", Valid: true},
		IsLeapMonth:      pgtype.Bool{Bool: false, Valid: true},
		BirthYear:        pgtype.Int2{Int16: 1990, Valid: true},
		BirthMonth:       pgtype.Int2{Int16: 5, Valid: true},
		BirthDay:         pgtype.Int2{Int16: 17, Valid: true},
		BirthTimeStatus:  pgtype.Text{String: "unknown", Valid: true},
		Gender:           pgtype.Text{String: "male", Valid: true},
		BirthTimezone:    pgtype.Text{String: "Asia/Seoul", Valid: true},
		BirthPlaceStatus: pgtype.Text{String: "skipped", Valid: true},
		NotifyStatus:     "disabled",
		BirthHash:        make([]byte, 32),
	}
}

func timeOfDay(hour, minute int) pgtype.Time {
	return pgtype.Time{Microseconds: int64(hour*60+minute) * int64(time.Minute/time.Microsecond), Valid: true}
}

// newQueries는 계정 한 개가 있는 빈 DB의 쿼리 객체와 그 계정 id를 돌려줍니다.
func newQueries(t *testing.T) (*profiledb.Queries, uuid.UUID) {
	t.Helper()
	q, _, accountID := newDB(t)
	return q, accountID
}

// newDB는 newQueries에 더해 직접 SQL을 실행할 풀도 돌려줍니다.
func newDB(t *testing.T) (*profiledb.Queries, *pgxpool.Pool, uuid.UUID) {
	t.Helper()
	pool := dbtest.New(t)
	accountID := uuid.New()
	err := authdb.New(pool).CreateAccount(context.Background(), authdb.CreateAccountParams{
		ID:           accountID,
		LastActiveAt: time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC),
	})
	require.NoError(t, err)
	return profiledb.New(pool), pool, accountID
}

// requireCheckViolation은 err가 wantConstraint라는 이름의 CHECK 위반인지 단언합니다.
func requireCheckViolation(t *testing.T, err error, wantConstraint string) {
	t.Helper()
	var pgErr *pgconn.PgError
	require.True(t, errors.As(err, &pgErr), "PgError여야 합니다: %v", err)
	require.Equal(t, checkViolation, pgErr.Code)
	require.Equal(t, wantConstraint, pgErr.ConstraintName)
}

func TestProfiles_RejectsTimeStatusMismatch(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthTimeStatus = pgtype.Text{String: "known", Valid: true} // birth_time 없음

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_birth_time_status_value")
}

func TestProfiles_RejectsCityWithoutLongitude(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthPlaceStatus = pgtype.Text{String: "city", Valid: true}
	params.BirthCityID = pgtype.Text{String: "seoul", Valid: true} // longitude 없음

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_birth_place_status_value")
}

func TestProfiles_RejectsCityIDWithoutCityStatus(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID) // birth_place_status = skipped
	params.BirthCityID = pgtype.Text{String: "seoul", Valid: true}
	params.Longitude = pgtype.Float8{Float64: 126.98, Valid: true}

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_birth_place_status_value")
}

func TestProfiles_RejectsSolarLeap(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.IsLeapMonth = pgtype.Bool{Bool: true, Valid: true}

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_solar_not_leap")
}

func TestProfiles_RejectsNotifyMinuteNotMultipleOf5(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.NotifyStatus = "enabled"
	params.NotifyTime = timeOfDay(7, 3)

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_notify_time_step")
}

func TestProfiles_AcceptsNotifyMinuteMultipleOf5(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.NotifyStatus = "enabled"
	params.NotifyTime = timeOfDay(7, 5)

	profile, err := q.UpsertProfile(context.Background(), params)

	require.NoError(t, err)
	require.Equal(t, timeOfDay(7, 5), profile.NotifyTime)
}

func TestProfiles_RejectsIncompleteUntilAnonymized(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(*profiledb.UpsertProfileParams)
	}{
		{"honorific", func(p *profiledb.UpsertProfileParams) { p.Honorific = pgtype.Text{} }},
		{"birth_hash", func(p *profiledb.UpsertProfileParams) { p.BirthHash = nil }},
		{"gender", func(p *profiledb.UpsertProfileParams) { p.Gender = pgtype.Text{} }},
		{"calendar", func(p *profiledb.UpsertProfileParams) { p.Calendar = pgtype.Text{} }},
		{"birth_timezone", func(p *profiledb.UpsertProfileParams) { p.BirthTimezone = pgtype.Text{} }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			q, accountID := newQueries(t)
			params := validParams(accountID)
			tt.mutate(&params)

			_, err := q.UpsertProfile(context.Background(), params)

			requireCheckViolation(t, err, "profiles_complete_until_anonymized")
		})
	}
}

// insertAnonymized는 익명화된 행(출생 열이 비어 있음)을 만들고, extraColumn = extraValue를 더해 넣습니다.
// UpsertProfile은 anonymized_at을 다루지 않으므로 직접 INSERT합니다.
func insertAnonymized(pool *pgxpool.Pool, accountID uuid.UUID, extraColumn, extraValue string) error {
	_, err := pool.Exec(context.Background(), `
		INSERT INTO profiles (account_id, language, current_timezone, notify_status, anonymized_at, `+extraColumn+`)
		VALUES ($1, 'ko', 'Asia/Seoul', 'disabled', '2026-10-15T01:00:00Z', `+extraValue+`)`, accountID)
	return err
}

func TestProfiles_AnonymizedMayDropBirthColumns(t *testing.T) {
	_, pool, accountID := newDB(t)

	err := insertAnonymized(pool, accountID, "birth_time_status", "NULL")

	require.NoError(t, err)
}

func TestProfiles_AnonymizedRowStillRejectsTimeWithoutStatus(t *testing.T) {
	_, pool, accountID := newDB(t)

	err := insertAnonymized(pool, accountID, "birth_time", "'07:30'")

	requireCheckViolation(t, err, "profiles_birth_time_status_value")
}

func TestProfiles_AnonymizedRowStillRejectsCityIDWithoutStatus(t *testing.T) {
	_, pool, accountID := newDB(t)

	err := insertAnonymized(pool, accountID, "birth_city_id", "'seoul'")

	requireCheckViolation(t, err, "profiles_birth_place_status_value")
}

func TestProfiles_KnownTimeWithValueIsAccepted(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthTimeStatus = pgtype.Text{String: "known", Valid: true}
	params.BirthTime = timeOfDay(7, 30)

	_, err := q.UpsertProfile(context.Background(), params)

	require.NoError(t, err)
}

func TestProfiles_RejectsUnknownTimeWithValue(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthTime = timeOfDay(7, 30) // 상태는 unknown

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_birth_time_status_value")
}

func TestProfiles_UpsertDoesNotTouchAnonymizedRow(t *testing.T) {
	ctx := context.Background()
	q, pool, accountID := newDB(t)
	require.NoError(t, insertAnonymized(pool, accountID, "birth_time_status", "NULL"))

	_, err := q.UpsertProfile(ctx, validParams(accountID))

	require.ErrorIs(t, err, pgx.ErrNoRows)
	row, err := q.GetProfile(ctx, accountID)
	require.NoError(t, err)
	require.NotNil(t, row.AnonymizedAt)
	require.True(t, row.AnonymizedAt.Equal(time.Date(2026, 10, 15, 1, 0, 0, 0, time.UTC)))
	require.False(t, row.Honorific.Valid)
	require.Nil(t, row.BirthHash)
}

func TestProfiles_RejectsBirthHashOfWrongLength(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthHash = make([]byte, 31)

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err, "profiles_birth_hash_length")
}

func TestProfiles_UpsertKeepsOneRow(t *testing.T) {
	ctx := context.Background()
	q, accountID := newQueries(t)
	first := validParams(accountID)
	second := validParams(accountID)
	second.Honorific = pgtype.Text{String: "지원", Valid: true}

	_, err := q.UpsertProfile(ctx, first)
	require.NoError(t, err)
	returned, err := q.UpsertProfile(ctx, second)
	require.NoError(t, err)

	got, err := q.GetProfile(ctx, accountID)
	require.NoError(t, err)
	require.Equal(t, "지원", got.Honorific.String)
	require.Equal(t, got, returned)
	exists, err := q.ProfileExists(ctx, accountID)
	require.NoError(t, err)
	require.True(t, exists)
}

func TestProfiles_ProfileExistsFalseWithoutRow(t *testing.T) {
	q, accountID := newQueries(t)

	exists, err := q.ProfileExists(context.Background(), accountID)

	require.NoError(t, err)
	require.False(t, exists)
}

func TestProfiles_ProfileExistsFalseForAnonymizedRow(t *testing.T) {
	q, pool, accountID := newDB(t)
	require.NoError(t, insertAnonymized(pool, accountID, "birth_time_status", "NULL"))

	exists, err := q.ProfileExists(context.Background(), accountID)

	require.NoError(t, err)
	require.False(t, exists)
}

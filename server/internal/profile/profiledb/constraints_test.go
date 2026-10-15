package profiledb_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
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
	pool := dbtest.New(t)
	accountID := uuid.New()
	err := authdb.New(pool).CreateAccount(context.Background(), authdb.CreateAccountParams{
		ID:           accountID,
		LastActiveAt: time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC),
	})
	require.NoError(t, err)
	return profiledb.New(pool), accountID
}

func requireCheckViolation(t *testing.T, err error) {
	t.Helper()
	var pgErr *pgconn.PgError
	require.True(t, errors.As(err, &pgErr), "PgError여야 합니다: %v", err)
	require.Equal(t, checkViolation, pgErr.Code)
}

func TestProfiles_RejectsTimeStatusMismatch(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthTimeStatus = pgtype.Text{String: "known", Valid: true} // birth_time 없음

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
}

func TestProfiles_RejectsCityWithoutLongitude(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthPlaceStatus = pgtype.Text{String: "city", Valid: true}
	params.BirthCityID = pgtype.Text{String: "seoul", Valid: true} // longitude 없음

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
}

func TestProfiles_RejectsCityIDWithoutCityStatus(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID) // birth_place_status = skipped
	params.BirthCityID = pgtype.Text{String: "seoul", Valid: true}
	params.Longitude = pgtype.Float8{Float64: 126.98, Valid: true}

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
}

func TestProfiles_RejectsSolarLeap(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.IsLeapMonth = pgtype.Bool{Bool: true, Valid: true}

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
}

func TestProfiles_RejectsNotifyMinuteNotMultipleOf5(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.NotifyStatus = "enabled"
	params.NotifyTime = timeOfDay(7, 3)

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
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
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.Honorific = pgtype.Text{}

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
}

func TestProfiles_AnonymizedMayDropBirthColumns(t *testing.T) {
	q, accountID := newQueries(t)
	anonymizedAt := time.Date(2026, 10, 15, 1, 0, 0, 0, time.UTC)
	params := profiledb.UpsertProfileParams{
		AccountID:       accountID,
		Language:        "ko",
		CurrentTimezone: "Asia/Seoul",
		NotifyStatus:    "disabled",
		AnonymizedAt:    &anonymizedAt,
	}

	_, err := q.UpsertProfile(context.Background(), params)

	require.NoError(t, err)
}

func TestProfiles_RejectsBirthHashOfWrongLength(t *testing.T) {
	q, accountID := newQueries(t)
	params := validParams(accountID)
	params.BirthHash = make([]byte, 31)

	_, err := q.UpsertProfile(context.Background(), params)

	requireCheckViolation(t, err)
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

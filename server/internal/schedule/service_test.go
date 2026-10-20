package schedule_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/schedule"
)

func newAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
	return id
}

func setup(t *testing.T) (*schedule.Service, uuid.UUID, *pgxpool.Pool) {
	t.Helper()
	pool := dbtest.New(t)
	return schedule.NewService(schedule.NewStore(pool)), newAccount(t, pool), pool
}

func date(m, d int) profile.LocalDate { return profile.LocalDate{Year: 2026, Month: m, Day: d} }

func at(h, m int) *profile.LocalTime { return &profile.LocalTime{Hour: h, Minute: m} }

func ptr[T any](v T) *T { return &v }

func allDay(d profile.LocalDate, title string) schedule.Input {
	return schedule.Input{Date: d, AllDay: true, Title: title}
}

func timed(d profile.LocalDate, h, m int, title string) schedule.Input {
	return schedule.Input{Date: d, AllDay: false, Time: at(h, m), Title: title}
}

// requireInconsistent는 err가 /time 하나를 가리키는 짝 위반이고 규칙이 rule인지 확인합니다.
func requireInconsistent(t *testing.T, err error, rule profile.StatusRule) {
	t.Helper()
	var v *profile.ValidationError
	require.ErrorAs(t, err, &v)
	assert.Equal(t, profile.Inconsistent, v.Violation)
	assert.Equal(t, []profile.FieldViolation{{Field: "/time", Rule: rule}}, v.Fields)
}

func TestService_CreateAndList(t *testing.T) {
	ctx := context.Background()
	svc, acc, _ := setup(t)

	created, err := svc.Create(ctx, acc, schedule.Input{Date: date(10, 20), AllDay: false, Time: at(9, 30), Title: "회의", Memo: ptr("3층")})
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, created.ID)
	assert.Equal(t, uuid.Version(7), created.ID.Version())
	assert.Equal(t, date(10, 20), created.Date)
	assert.False(t, created.AllDay)
	assert.Equal(t, at(9, 30), created.Time)
	assert.Equal(t, "회의", created.Title)
	assert.Equal(t, ptr("3층"), created.Memo)
	assert.False(t, created.CreatedAt.IsZero())

	got, err := svc.List(ctx, acc, date(10, 20), date(10, 20))
	require.NoError(t, err)
	assert.Equal(t, []schedule.Schedule{created}, got)
}

func TestService_ListOrdersByDateAllDayTimeCreated(t *testing.T) {
	ctx := context.Background()
	svc, acc, _ := setup(t)

	// 일부러 정렬과 다른 순서로 만듭니다.
	late, err := svc.Create(ctx, acc, timed(date(10, 21), 15, 0, "오후"))
	require.NoError(t, err)
	early, err := svc.Create(ctx, acc, timed(date(10, 21), 9, 0, "오전"))
	require.NoError(t, err)
	day2, err := svc.Create(ctx, acc, allDay(date(10, 22), "다음 날"))
	require.NoError(t, err)
	allDayB, err := svc.Create(ctx, acc, allDay(date(10, 21), "종일 B"))
	require.NoError(t, err)
	allDayA, err := svc.Create(ctx, acc, allDay(date(10, 21), "종일 A"))
	require.NoError(t, err)
	first, err := svc.Create(ctx, acc, allDay(date(10, 20), "먼저"))
	require.NoError(t, err)

	got, err := svc.List(ctx, acc, date(10, 20), date(10, 22))
	require.NoError(t, err)
	// 같은 날 종일끼리는 만든 순입니다.
	assert.Equal(t, []uuid.UUID{first.ID, allDayB.ID, allDayA.ID, early.ID, late.ID, day2.ID}, ids(got))
}

func ids(list []schedule.Schedule) []uuid.UUID {
	out := make([]uuid.UUID, len(list))
	for i, s := range list {
		out[i] = s.ID
	}
	return out
}

func TestService_ListRangeLimits(t *testing.T) {
	ctx := context.Background()
	svc, acc, _ := setup(t)

	// 2026-10-01 ~ 2026-12-01은 포함 62일, 12-02는 63일입니다.
	got, err := svc.List(ctx, acc, date(10, 1), date(12, 1))
	require.NoError(t, err)
	assert.Empty(t, got)
	assert.NotNil(t, got)

	_, err = svc.List(ctx, acc, date(10, 1), date(12, 2))
	assert.ErrorIs(t, err, schedule.ErrRangeTooLong)

	_, err = svc.List(ctx, acc, date(10, 2), date(10, 1))
	assert.ErrorIs(t, err, schedule.ErrRangeReversed)

	// 하루짜리 범위(from == to)는 정상입니다.
	_, err = svc.List(ctx, acc, date(10, 1), date(10, 1))
	assert.NoError(t, err)
}

func TestService_ListSkipsOthersAndDeleted(t *testing.T) {
	ctx := context.Background()
	svc, acc, pool := setup(t)
	other := newAccount(t, pool)

	mine, err := svc.Create(ctx, acc, allDay(date(10, 20), "내 것"))
	require.NoError(t, err)
	gone, err := svc.Create(ctx, acc, allDay(date(10, 20), "지움"))
	require.NoError(t, err)
	_, err = svc.Create(ctx, other, allDay(date(10, 20), "남의 것"))
	require.NoError(t, err)
	require.NoError(t, svc.Delete(ctx, acc, gone.ID))

	got, err := svc.List(ctx, acc, date(10, 20), date(10, 20))
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{mine.ID}, ids(got))
}

func TestService_CreateInconsistentPair(t *testing.T) {
	ctx := context.Background()
	svc, acc, _ := setup(t)

	_, err := svc.Create(ctx, acc, schedule.Input{Date: date(10, 20), AllDay: false, Title: "시각 없음"})
	requireInconsistent(t, err, profile.RequiredByStatus)

	_, err = svc.Create(ctx, acc, schedule.Input{Date: date(10, 20), AllDay: true, Time: at(9, 0), Title: "종일인데 시각"})
	requireInconsistent(t, err, profile.ForbiddenByStatus)
}

func TestService_CreateEmptyMemoIsNil(t *testing.T) {
	ctx := context.Background()
	svc, acc, _ := setup(t)

	in := allDay(date(10, 20), "메모 없음")
	in.Memo = ptr("")
	created, err := svc.Create(ctx, acc, in)
	require.NoError(t, err)
	assert.Nil(t, created.Memo)
}

func TestService_UpdatePatchRules(t *testing.T) {
	ctx := context.Background()

	t.Run("allDay를 true로 바꾸면 time이 지워집니다", func(t *testing.T) {
		svc, acc, _ := setup(t)
		s, err := svc.Create(ctx, acc, timed(date(10, 20), 9, 0, "회의"))
		require.NoError(t, err)
		got, err := svc.Update(ctx, acc, s.ID, schedule.Patch{AllDay: ptr(true)})
		require.NoError(t, err)
		assert.True(t, got.AllDay)
		assert.Nil(t, got.Time)
		assert.Equal(t, "회의", got.Title)
	})

	t.Run("allDay를 false로 바꾸는데 time이 없으면 required_by_status", func(t *testing.T) {
		svc, acc, _ := setup(t)
		s, err := svc.Create(ctx, acc, allDay(date(10, 20), "종일"))
		require.NoError(t, err)
		_, err = svc.Update(ctx, acc, s.ID, schedule.Patch{AllDay: ptr(false)})
		requireInconsistent(t, err, profile.RequiredByStatus)
	})

	t.Run("allDay를 false로 바꾸면서 time을 보내면 적용됩니다", func(t *testing.T) {
		svc, acc, _ := setup(t)
		s, err := svc.Create(ctx, acc, allDay(date(10, 20), "종일"))
		require.NoError(t, err)
		got, err := svc.Update(ctx, acc, s.ID, schedule.Patch{AllDay: ptr(false), Time: at(18, 5)})
		require.NoError(t, err)
		assert.False(t, got.AllDay)
		assert.Equal(t, at(18, 5), got.Time)
	})

	t.Run("결과가 종일인데 time을 보내면 forbidden_by_status", func(t *testing.T) {
		svc, acc, _ := setup(t)
		s, err := svc.Create(ctx, acc, allDay(date(10, 20), "종일"))
		require.NoError(t, err)
		_, err = svc.Update(ctx, acc, s.ID, schedule.Patch{Time: at(9, 0)})
		requireInconsistent(t, err, profile.ForbiddenByStatus)

		_, err = svc.Update(ctx, acc, s.ID, schedule.Patch{AllDay: ptr(true), Time: at(9, 0)})
		requireInconsistent(t, err, profile.ForbiddenByStatus)
	})

	t.Run("보내지 않은 필드는 그대로이고 time만 바꿀 수 있습니다", func(t *testing.T) {
		svc, acc, _ := setup(t)
		in := timed(date(10, 20), 9, 0, "회의")
		in.Memo = ptr("메모")
		s, err := svc.Create(ctx, acc, in)
		require.NoError(t, err)
		got, err := svc.Update(ctx, acc, s.ID, schedule.Patch{Time: at(10, 15), Date: ptr(date(10, 25)), Title: ptr("새 제목")})
		require.NoError(t, err)
		assert.Equal(t, date(10, 25), got.Date)
		assert.Equal(t, at(10, 15), got.Time)
		assert.Equal(t, "새 제목", got.Title)
		assert.Equal(t, ptr("메모"), got.Memo)
		assert.Equal(t, s.CreatedAt, got.CreatedAt)
	})

	t.Run("memo 빈 문자열은 지우기이고 값은 바꾸기입니다", func(t *testing.T) {
		svc, acc, _ := setup(t)
		in := allDay(date(10, 20), "종일")
		in.Memo = ptr("메모")
		s, err := svc.Create(ctx, acc, in)
		require.NoError(t, err)

		got, err := svc.Update(ctx, acc, s.ID, schedule.Patch{Memo: ptr("새 메모")})
		require.NoError(t, err)
		assert.Equal(t, ptr("새 메모"), got.Memo)

		got, err = svc.Update(ctx, acc, s.ID, schedule.Patch{Memo: ptr("")})
		require.NoError(t, err)
		assert.Nil(t, got.Memo)
	})
}

func TestService_NotFound(t *testing.T) {
	ctx := context.Background()
	svc, acc, pool := setup(t)
	other := newAccount(t, pool)

	s, err := svc.Create(ctx, acc, allDay(date(10, 20), "내 것"))
	require.NoError(t, err)
	gone, err := svc.Create(ctx, acc, allDay(date(10, 20), "지움"))
	require.NoError(t, err)
	require.NoError(t, svc.Delete(ctx, acc, gone.ID))

	for name, id := range map[string]uuid.UUID{"없는 id": uuid.New(), "지운 일정": gone.ID} {
		t.Run(name, func(t *testing.T) {
			_, err := svc.Update(ctx, acc, id, schedule.Patch{Title: ptr("x")})
			assert.ErrorIs(t, err, schedule.ErrNotFound)
			assert.ErrorIs(t, svc.Delete(ctx, acc, id), schedule.ErrNotFound)
		})
	}

	t.Run("남의 일정", func(t *testing.T) {
		_, err := svc.Update(ctx, other, s.ID, schedule.Patch{Title: ptr("x")})
		assert.ErrorIs(t, err, schedule.ErrNotFound)
		assert.ErrorIs(t, svc.Delete(ctx, other, s.ID), schedule.ErrNotFound)
		_, err = svc.Restore(ctx, other, s.ID)
		assert.ErrorIs(t, err, schedule.ErrNotFound)
	})

	t.Run("없는 일정은 복원도 404", func(t *testing.T) {
		_, err := svc.Restore(ctx, acc, uuid.New())
		assert.ErrorIs(t, err, schedule.ErrNotFound)
	})
}

func TestService_RestoreIsIdempotent(t *testing.T) {
	ctx := context.Background()
	svc, acc, _ := setup(t)

	s, err := svc.Create(ctx, acc, timed(date(10, 20), 9, 0, "회의"))
	require.NoError(t, err)
	require.NoError(t, svc.Delete(ctx, acc, s.ID))
	got, err := svc.List(ctx, acc, date(10, 20), date(10, 20))
	require.NoError(t, err)
	assert.Empty(t, got)

	restored, err := svc.Restore(ctx, acc, s.ID)
	require.NoError(t, err)
	assert.Equal(t, s.ID, restored.ID)
	assert.Equal(t, s.Title, restored.Title)
	assert.Equal(t, s.Time, restored.Time)

	// 이미 살아 있는 일정을 다시 되살려도 같은 결과입니다.
	again, err := svc.Restore(ctx, acc, s.ID)
	require.NoError(t, err)
	assert.Equal(t, restored, again)

	got, err = svc.List(ctx, acc, date(10, 20), date(10, 20))
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{s.ID}, ids(got))
}

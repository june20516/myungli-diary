package schedule

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/schedule/scheduledb"
)

// Store는 PostgreSQL 일정 저장소입니다. 규칙 검사는 Service가 하고, 여기는 저장과 조회만 합니다.
type Store struct {
	pool *pgxpool.Pool
}

// NewStore는 연결 풀 위에 저장소를 만듭니다.
func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// List는 from~to(포함) 살아 있는 일정을 날짜 → 종일 먼저 → 시각 → 만든 순으로 돌려줍니다. 없으면 빈 slice입니다.
func (s *Store) List(ctx context.Context, accountID uuid.UUID, from, to profile.LocalDate) ([]Schedule, error) {
	rows, err := scheduledb.New(s.pool).ListSchedules(ctx, scheduledb.ListSchedulesParams{
		AccountID: accountID, FromDate: profile.PgDate(from), ToDate: profile.PgDate(to),
	})
	if err != nil {
		return nil, fmt.Errorf("일정 목록 조회: %w", err)
	}
	out := make([]Schedule, len(rows))
	for i, row := range rows {
		out[i] = toSchedule(scheduledb.GetScheduleForUpdateRow(row))
	}
	return out, nil
}

// Create는 in을 새 일정으로 저장합니다.
func (s *Store) Create(ctx context.Context, accountID uuid.UUID, in Input) (Schedule, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return Schedule{}, fmt.Errorf("일정 ID 생성: %w", err)
	}
	row, err := scheduledb.New(s.pool).InsertSchedule(ctx, scheduledb.InsertScheduleParams{
		ID: id, AccountID: accountID, Date: profile.PgDate(in.Date), AllDay: in.AllDay,
		Time: profile.PgTime(in.Time), Title: in.Title, Memo: toPgText(in.Memo),
	})
	if err != nil {
		return Schedule{}, fmt.Errorf("일정 저장: %w", err)
	}
	return toSchedule(scheduledb.GetScheduleForUpdateRow(row)), nil
}

// Update는 살아 있는 일정을 잠가 읽고 change를 적용한 결과로 고칩니다.
// change가 오류를 돌려주면 아무것도 바꾸지 않고 그 오류를 그대로 돌려줍니다. 없는 일정은 ErrNotFound입니다.
func (s *Store) Update(ctx context.Context, accountID, id uuid.UUID, change func(Schedule) (Schedule, error)) (Schedule, error) {
	var updated Schedule
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := scheduledb.New(tx)
		current, err := q.GetScheduleForUpdate(ctx, scheduledb.GetScheduleForUpdateParams{ID: id, AccountID: accountID})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return fmt.Errorf("일정 조회: %w", err)
		}
		next, err := change(toSchedule(scheduledb.GetScheduleForUpdateRow(current)))
		if err != nil {
			return err
		}
		row, err := q.UpdateSchedule(ctx, scheduledb.UpdateScheduleParams{
			ID: id, AccountID: accountID, Date: profile.PgDate(next.Date), AllDay: next.AllDay,
			Time: profile.PgTime(next.Time), Title: next.Title, Memo: toPgText(next.Memo),
		})
		if err != nil {
			return fmt.Errorf("일정 수정: %w", err)
		}
		updated = toSchedule(scheduledb.GetScheduleForUpdateRow(row))
		return nil
	})
	if err != nil {
		return Schedule{}, err
	}
	return updated, nil
}

// Delete는 일정을 지운 것으로 표시합니다(soft delete). 살아 있는 일정이 없으면 ErrNotFound입니다.
func (s *Store) Delete(ctx context.Context, accountID, id uuid.UUID) error {
	n, err := scheduledb.New(s.pool).SoftDeleteSchedule(ctx, scheduledb.SoftDeleteScheduleParams{ID: id, AccountID: accountID})
	if err != nil {
		return fmt.Errorf("일정 삭제: %w", err)
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// Restore는 지운 일정을 되살립니다. 이미 살아 있는 일정이면 건드리지 않고 그대로 돌려주며, 없으면 ErrNotFound입니다.
// 행을 잠가 읽은 뒤 판정하므로 그 사이 다른 요청이 지워도 지운 행을 살아 있는 것으로 답하지 않습니다.
func (s *Store) Restore(ctx context.Context, accountID, id uuid.UUID) (Schedule, error) {
	var restored Schedule
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := scheduledb.New(tx)
		current, err := q.GetScheduleForRestore(ctx, scheduledb.GetScheduleForRestoreParams{ID: id, AccountID: accountID})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return fmt.Errorf("일정 조회: %w", err)
		}
		if !current.IsDeleted {
			restored = toSchedule(scheduledb.GetScheduleForUpdateRow{
				ID: current.ID, Date: current.Date, AllDay: current.AllDay, Time: current.Time, Title: current.Title,
				Memo: current.Memo, CreatedAt: current.CreatedAt, UpdatedAt: current.UpdatedAt,
			})
			return nil
		}
		row, err := q.RestoreSchedule(ctx, scheduledb.RestoreScheduleParams{ID: id, AccountID: accountID})
		if err != nil {
			return fmt.Errorf("일정 복원: %w", err)
		}
		restored = toSchedule(scheduledb.GetScheduleForUpdateRow(row))
		return nil
	})
	if err != nil {
		return Schedule{}, err
	}
	return restored, nil
}

// toSchedule은 조회한 행을 Schedule로 바꿉니다. 열이 늘면 sqlc 행 타입이 달라져 컴파일이 깨지므로 여기서 옮깁니다.
func toSchedule(row scheduledb.GetScheduleForUpdateRow) Schedule {
	out := Schedule{
		ID:        row.ID,
		Date:      profile.LocalDateFromPg(row.Date),
		AllDay:    row.AllDay,
		Title:     row.Title,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
		Time:      profile.LocalTimeFromPg(row.Time),
	}
	if row.Memo.Valid {
		memo := row.Memo.String
		out.Memo = &memo
	}
	return out
}

func toPgText(s *string) pgtype.Text {
	if s == nil {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *s, Valid: true}
}

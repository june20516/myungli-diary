-- 일정 쿼리입니다. 조회는 살아 있는 행(deleted_at IS NULL)만 보고, 복원 경로만 지운 행을 봅니다.

-- name: InsertSchedule :one
INSERT INTO schedules (id, account_id, date, all_day, time, title, memo)
VALUES (@id, @account_id, @date, @all_day, @time, @title, @memo)
RETURNING id, date, all_day, time, title, memo, created_at, updated_at;

-- name: ListSchedules :many
-- 날짜 → 종일 먼저 → 시각 → 만든 순입니다. from·to는 포함입니다.
SELECT id, date, all_day, time, title, memo, created_at, updated_at
FROM schedules
WHERE account_id = @account_id AND deleted_at IS NULL
  AND date >= @from_date AND date <= @to_date
ORDER BY date, all_day DESC, time, created_at, id;

-- name: GetScheduleForUpdate :one
-- 수정할 일정을 잠가 읽습니다. 없거나 지웠거나 남의 것이면 행을 돌려받지 못합니다(pgx.ErrNoRows).
SELECT id, date, all_day, time, title, memo, created_at, updated_at
FROM schedules
WHERE id = @id AND account_id = @account_id AND deleted_at IS NULL
FOR UPDATE;

-- name: UpdateSchedule :one
UPDATE schedules
SET date = @date, all_day = @all_day, time = @time, title = @title, memo = @memo
WHERE id = @id AND account_id = @account_id AND deleted_at IS NULL
RETURNING id, date, all_day, time, title, memo, created_at, updated_at;

-- name: SoftDeleteSchedule :execrows
UPDATE schedules SET deleted_at = now()
WHERE id = @id AND account_id = @account_id AND deleted_at IS NULL;

-- name: RestoreSchedule :one
-- 지운 일정만 되살립니다. 지운 일정이 아니면 행을 돌려받지 못합니다(pgx.ErrNoRows).
UPDATE schedules SET deleted_at = NULL
WHERE id = @id AND account_id = @account_id AND deleted_at IS NOT NULL
RETURNING id, date, all_day, time, title, memo, created_at, updated_at;

-- name: GetScheduleForRestore :one
-- 지운 것까지 포함해 잠가 읽습니다. is_deleted로 되살릴지, 이미 살아 있어 그대로 답할지 가립니다.
SELECT id, date, all_day, time, title, memo, created_at, updated_at, (deleted_at IS NOT NULL)::boolean AS is_deleted
FROM schedules
WHERE id = @id AND account_id = @account_id
FOR UPDATE;

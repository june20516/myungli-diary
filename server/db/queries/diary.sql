-- 일기 쿼리입니다. 조회는 모두 살아 있는 행(deleted_at IS NULL)만 봅니다.

-- name: UpsertDiary :one
-- 그날 일기가 없으면 만들고, 있으면 본문만 바꿉니다(태그·질문·규칙 버전·created_at은 처음 값을 유지합니다).
-- 동시 요청도 partial unique 인덱스가 하나의 행으로 모읍니다. created는 새 행일 때만 true입니다.
INSERT INTO diaries (id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version)
VALUES (@id, @account_id, @date, @body, @all_tags, @featured_tags, @guide_question, @ruleset_version)
ON CONFLICT (account_id, date) WHERE deleted_at IS NULL
DO UPDATE SET body = EXCLUDED.body, updated_at = now()
RETURNING id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version, created_at, updated_at,
          (xmax = 0) AS created;

-- name: GetDiary :one
SELECT id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version, created_at, updated_at
FROM diaries
WHERE account_id = @account_id AND date = @date AND deleted_at IS NULL;

-- name: SoftDeleteDiary :execrows
UPDATE diaries SET deleted_at = now()
WHERE account_id = @account_id AND date = @date AND deleted_at IS NULL;

-- name: LiveDiaryExists :one
SELECT EXISTS (
    SELECT 1 FROM diaries WHERE account_id = @account_id AND date = @date AND deleted_at IS NULL
);

-- name: RestoreLatestDeletedDiary :one
-- 그 날짜에 지운 일기 중 가장 늦게 지운 것을 되살립니다. 없으면 행을 돌려받지 못합니다(pgx.ErrNoRows).
UPDATE diaries SET deleted_at = NULL
WHERE id = (
    SELECT d.id FROM diaries d
    WHERE d.account_id = @account_id AND d.date = @date AND d.deleted_at IS NOT NULL
    ORDER BY d.deleted_at DESC, d.created_at DESC, d.id DESC
    LIMIT 1
)
RETURNING id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version, created_at, updated_at;

-- name: ListDiaries :many
-- 날짜 역순입니다. 범위(from·to, 포함)·태그·keyset(before: 그 날짜보다 앞)은 NULL이면 걸지 않습니다.
SELECT id, account_id, date, body, all_tags, featured_tags, guide_question, ruleset_version, created_at, updated_at
FROM diaries
WHERE account_id = @account_id AND deleted_at IS NULL
  AND (sqlc.narg('from_date')::date IS NULL OR date >= sqlc.narg('from_date')::date)
  AND (sqlc.narg('to_date')::date IS NULL OR date <= sqlc.narg('to_date')::date)
  AND (sqlc.narg('tag')::text IS NULL OR all_tags @> ARRAY[sqlc.narg('tag')::text])
  AND (sqlc.narg('before_date')::date IS NULL OR date < sqlc.narg('before_date')::date)
ORDER BY date DESC
LIMIT @row_limit;

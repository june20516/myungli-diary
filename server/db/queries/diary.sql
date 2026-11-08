-- 일기 쿼리입니다. 일기 한 편(diaries)과 날짜 기록(diary_days)을 JOIN해 읽습니다(D83).
-- 조회는 모두 살아 있는 행(deleted_at IS NULL)만 보고, 모든 쿼리가 account_id 조건을 겁니다.

-- name: DiaryDayExists :one
SELECT EXISTS (
    SELECT 1 FROM diary_days WHERE account_id = @account_id AND date = @date
);

-- name: InsertDiaryDay :exec
-- 그날 첫 편이면 날짜 기록을 만들고, 이미 있으면 먼저 넣은 기록을 그대로 둡니다.
INSERT INTO diary_days (account_id, date, all_tags, featured_tags, guide_question, ruleset_version, day_kind)
VALUES (@account_id, @date, @all_tags, @featured_tags, @guide_question, @ruleset_version, @day_kind)
ON CONFLICT (account_id, date) DO NOTHING;

-- name: LockDiaryDay :one
-- 날짜 기록 행을 잠가 그 날짜를 잠급니다(같은 날짜의 만들기·되살리기가 줄을 섭니다). 없으면 행을 돌려받지 못합니다(pgx.ErrNoRows).
SELECT 1
FROM diary_days
WHERE account_id = @account_id AND date = @date
FOR UPDATE;

-- name: CountLiveDiaries :one
SELECT count(*) FROM diaries
WHERE account_id = @account_id AND date = @date AND deleted_at IS NULL;

-- name: InsertDiary :one
-- guide_question은 그 편에서 고른 오늘의 질문이고, 고르지 않았으면 NULL이라 날짜 기록의 질문을 돌려줍니다(S140).
WITH inserted AS (
    INSERT INTO diaries (id, account_id, date, body, guide_question)
    VALUES (@id, @account_id, @date, @body, @guide_question)
    RETURNING id, account_id, date, body, guide_question, created_at, updated_at
)
SELECT i.id, i.account_id, i.date, i.body, dd.all_tags, dd.featured_tags, COALESCE(i.guide_question, dd.guide_question)::jsonb AS guide_question, dd.ruleset_version, dd.day_kind, i.created_at, i.updated_at
FROM inserted i
JOIN diary_days dd ON dd.account_id = i.account_id AND dd.date = i.date;

-- name: GetDiary :one
SELECT d.id, d.account_id, d.date, d.body, dd.all_tags, dd.featured_tags, COALESCE(d.guide_question, dd.guide_question)::jsonb AS guide_question, dd.ruleset_version, dd.day_kind, d.created_at, d.updated_at
FROM diaries d
JOIN diary_days dd ON dd.account_id = d.account_id AND dd.date = d.date
WHERE d.id = @id AND d.account_id = @account_id AND d.deleted_at IS NULL;

-- name: UpdateDiaryBody :one
-- 살아 있는 일기의 본문만 바꿉니다(날짜 기록은 유지). 없으면 행을 돌려받지 못합니다(pgx.ErrNoRows).
WITH changed AS (
    UPDATE diaries SET body = @body, updated_at = now()
    WHERE diaries.id = @id AND diaries.account_id = @account_id AND diaries.deleted_at IS NULL
    RETURNING id, account_id, date, body, guide_question, created_at, updated_at
)
SELECT u.id, u.account_id, u.date, u.body, dd.all_tags, dd.featured_tags, COALESCE(u.guide_question, dd.guide_question)::jsonb AS guide_question, dd.ruleset_version, dd.day_kind, u.created_at, u.updated_at
FROM changed u
JOIN diary_days dd ON (dd.account_id, dd.date) = (u.account_id, u.date);

-- name: SoftDeleteDiary :execrows
UPDATE diaries SET deleted_at = now()
WHERE id = @id AND account_id = @account_id AND deleted_at IS NULL;

-- name: GetDiaryState :one
-- 지운 행까지 보고 그 행을 잠급니다. 되살리기가 대상의 날짜와 상태를 확인하는 데 씁니다(같은 일기의 동시 되살리기·지우기가 줄을 섭니다).
-- 잠금 순서는 diaries 행 다음 diary_days 행입니다(만들기는 diary_days 행 다음 새 행이라 순환이 없습니다). 없으면 행을 돌려받지 못합니다(pgx.ErrNoRows).
SELECT id, date, deleted_at, content_purged_at
FROM diaries
WHERE id = @id AND account_id = @account_id
FOR UPDATE;

-- name: UndeleteDiary :exec
UPDATE diaries SET deleted_at = NULL
WHERE id = @id AND account_id = @account_id AND deleted_at IS NOT NULL AND content_purged_at IS NULL;

-- name: ListDiaries :many
-- 날짜 역순, 같은 날짜 안에서는 작성 순입니다. 범위(from·to, 포함)·태그·keyset(after_*: 그 항목 다음)은 NULL이면 걸지 않습니다.
-- after_date·after_created_at·after_id는 셋 다 넣거나 셋 다 NULL로 둡니다.
SELECT d.id, d.account_id, d.date, d.body, dd.all_tags, dd.featured_tags, COALESCE(d.guide_question, dd.guide_question)::jsonb AS guide_question, dd.ruleset_version, dd.day_kind, d.created_at, d.updated_at
FROM diaries d
JOIN diary_days dd ON dd.account_id = d.account_id AND dd.date = d.date
WHERE d.account_id = @account_id AND d.deleted_at IS NULL
  AND (sqlc.narg('from_date')::date IS NULL OR d.date >= sqlc.narg('from_date')::date)
  AND (sqlc.narg('to_date')::date IS NULL OR d.date <= sqlc.narg('to_date')::date)
  AND (sqlc.narg('tag')::text IS NULL OR dd.all_tags @> ARRAY[sqlc.narg('tag')::text])
  AND (sqlc.narg('after_date')::date IS NULL
       OR d.date < sqlc.narg('after_date')::date
       OR (d.date = sqlc.narg('after_date')::date
           AND (d.created_at, d.id) > (sqlc.narg('after_created_at')::timestamptz, sqlc.narg('after_id')::uuid)))
ORDER BY d.date DESC, d.created_at ASC, d.id ASC
LIMIT @row_limit;

-- name: DiaryStatsCounts :one
-- 회고 집계의 편수와 날의 성격별 날짜 수입니다(#862). 날짜는 살아 있는 일기가 한 편 이상 있는 날만 세고, day_kind가 NULL인 날은 어디에도 세지 않습니다.
WITH live_days AS (
    SELECT dd.day_kind
    FROM diary_days dd
    WHERE dd.account_id = @account_id::uuid
      AND dd.date IN (SELECT d.date FROM diaries d WHERE d.account_id = @account_id::uuid AND d.deleted_at IS NULL)
)
SELECT
    (SELECT count(*) FROM diaries WHERE account_id = @account_id::uuid AND deleted_at IS NULL) AS entry_count,
    count(*) FILTER (WHERE day_kind = 'yongsin_day') AS yongsin_days,
    count(*) FILTER (WHERE day_kind = 'gwiin_day') AS gwiin_days,
    count(*) FILTER (WHERE day_kind = 'ordinary_day') AS ordinary_days,
    count(*) FILTER (WHERE day_kind = 'gisin_day') AS gisin_days
FROM live_days;

-- name: TopFeaturedTags :many
-- 살아 있는 일기가 있는 날짜의 대표 태그를 날짜 수가 많은 순(같으면 키 오름차순)으로 tag_limit개까지 셉니다(#862).
-- polarity는 그 태그가 붙은 가장 최근 날짜의 값입니다.
SELECT
    t.key::text AS key,
    ((array_agg(t.polarity ORDER BY dd.date DESC))[1])::text AS polarity,
    count(DISTINCT dd.date) AS days
FROM diary_days dd
CROSS JOIN LATERAL jsonb_to_recordset(dd.featured_tags) AS t(key text, polarity text)
WHERE dd.account_id = @account_id::uuid
  AND dd.date IN (SELECT d.date FROM diaries d WHERE d.account_id = @account_id::uuid AND d.deleted_at IS NULL)
GROUP BY t.key
ORDER BY days DESC, t.key ASC
LIMIT @tag_limit;

-- 콘텐츠 시드 적재와 읽기, 문장 선택 기록·순환 상태 쿼리입니다.

-- name: InsertSeed :execrows
INSERT INTO content_seeds (version) VALUES (@version)
ON CONFLICT (version) DO NOTHING;

-- name: DeactivateSeeds :exec
UPDATE content_seeds SET active = false WHERE active AND version <> @version;

-- name: ActivateSeed :exec
UPDATE content_seeds SET active = true WHERE version = @version;

-- name: GetActiveSeed :one
SELECT version FROM content_seeds WHERE active;

-- name: ListTemplates :many
SELECT slot, key, variant, body FROM content_templates
WHERE seed_version = @seed_version AND lang = @lang;

-- name: GetSelection :one
SELECT id, message_key, variant, seed_version FROM daily_selections
WHERE account_id = @account_id AND date = @date AND slot = @slot AND birth_hash = @birth_hash;

-- name: InsertSelection :one
-- 동시 요청이 같은 행을 넣으면 하나만 남고, 진 쪽은 행을 돌려받지 못합니다(pgx.ErrNoRows).
INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
VALUES (@account_id, @date, @slot, @birth_hash, @message_key, @variant, @seed_version)
ON CONFLICT ON CONSTRAINT daily_selections_unique DO NOTHING
RETURNING id;

-- name: UpdateSelection :one
-- 메시지 키가 바뀐 기록을 새로 고른 값으로 바꿉니다. 그 사이 다른 요청이 먼저 바꿨으면 행을 돌려받지 못합니다.
UPDATE daily_selections
SET message_key = @message_key, variant = @variant, seed_version = @seed_version
WHERE id = @id AND message_key = @old_message_key
RETURNING id;

-- name: GetRotation :one
SELECT next_variant FROM rotation_state WHERE account_id = @account_id AND message_key = @message_key;

-- name: SetRotation :exec
INSERT INTO rotation_state (account_id, message_key, next_variant)
VALUES (@account_id, @message_key, @next_variant)
ON CONFLICT (account_id, message_key) DO UPDATE SET next_variant = EXCLUDED.next_variant;

-- name: CountCare :one
-- 돌봄(care) 기록을 (날짜, 슬롯)마다 하나로 셉니다. 지금 고르는 (오늘, 슬롯)은 빼고 셉니다.
-- 그 자리에 이미 care가 있어도 다시 care를 고르면 개수가 늘지 않기 때문입니다.
-- today_count는 오늘, week_count는 오늘을 포함한 최근 7일(week_start ~ today)입니다.
SELECT
    count(DISTINCT slot) FILTER (WHERE date = @today::date) AS today_count,
    count(DISTINCT ROW(date, slot)) AS week_count
FROM daily_selections
WHERE account_id = @account_id
  AND variant = 'care'
  AND date BETWEEN @week_start::date AND @today::date
  AND NOT (date = @today::date AND slot = @slot);

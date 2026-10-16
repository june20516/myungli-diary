-- 콘텐츠 시드 적재와 읽기, 문장 선택 기록·순환 상태 쿼리입니다.

-- name: InsertSeed :execrows
INSERT INTO content_seeds (version, slots) VALUES (@version, @slots)
ON CONFLICT (version) DO NOTHING;

-- name: GetSeedSlots :one
SELECT slots FROM content_seeds WHERE version = @version;

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
-- 돌봄(care) 기록을 (날짜, 슬롯)마다 하나로 셉니다. 지금 고르는 (오늘, 슬롯)은 빼고 셉니다(이유는 selector.careCapped 주석).
-- today_count는 오늘, week_count는 오늘을 포함한 최근 7일(week_start ~ today)입니다.
SELECT
    count(DISTINCT slot) FILTER (WHERE date = @today::date) AS today_count,
    count(DISTINCT ROW(date, slot)) AS week_count
FROM daily_selections
WHERE account_id = @account_id
  AND variant = 'care'
  AND date BETWEEN @week_start::date AND @today::date
  AND NOT (date = @today::date AND slot = @slot);

-- name: ListOtherHashVariants :many
-- 같은 (계정, 날짜, 슬롯)에서 지문이 다른 기록들이 쓴 variant입니다. 같은 날 다시 고를 때 이 유형을 피합니다.
SELECT DISTINCT variant FROM daily_selections
WHERE account_id = @account_id AND date = @date AND slot = @slot AND birth_hash <> @birth_hash;

-- name: SoftDeleteReactions :exec
-- 선택 기록의 문장이 바뀌면 옛 문장에 남긴 활성 반응을 soft delete합니다.
UPDATE reactions SET deleted_at = @deleted_at
WHERE selection_id = @selection_id AND deleted_at IS NULL;

-- name: ListHanja :many
SELECT term, hanja FROM content_hanja WHERE seed_version = @seed_version;

-- name: LockSelection :execrows
-- 한 선택 기록의 반응 변경을 차례로 하게 하는 행 lock입니다. 트랜잭션이 끝나면 풀립니다.
SELECT 1 FROM daily_selections WHERE id = @id FOR UPDATE;

-- name: GetActiveReaction :one
SELECT reaction FROM reactions WHERE selection_id = @selection_id AND deleted_at IS NULL;

-- name: InsertReaction :exec
-- 동시 요청이 함께 넣으면 부분 unique 인덱스(활성은 하나) 덕분에 하나만 남습니다.
INSERT INTO reactions (selection_id, reaction, created_at)
VALUES (@selection_id, @reaction, @created_at)
ON CONFLICT (selection_id) WHERE deleted_at IS NULL DO NOTHING;

-- name: ListActiveReactions :many
SELECT selection_id, reaction FROM reactions
WHERE selection_id = ANY(@selection_ids::bigint[]) AND deleted_at IS NULL;

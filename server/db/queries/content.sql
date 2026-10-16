-- 콘텐츠 시드 적재와 읽기 쿼리입니다.
-- 선택 기록·순환 상태 쿼리는 선택기를 구현할 때 더합니다.

-- name: InsertSeed :execrows
INSERT INTO content_seeds (version) VALUES (@version)
ON CONFLICT (version) DO NOTHING;

-- name: InsertTemplate :exec
INSERT INTO content_templates (seed_version, slot, key, variant, lang, body)
VALUES (@seed_version, @slot, @key, @variant, @lang, @body)
ON CONFLICT DO NOTHING;

-- name: DeactivateSeeds :exec
UPDATE content_seeds SET active = false WHERE active AND version <> @version;

-- name: ActivateSeed :exec
UPDATE content_seeds SET active = true WHERE version = @version;

-- name: GetActiveSeed :one
SELECT version FROM content_seeds WHERE active;

-- name: ListTemplates :many
SELECT slot, key, variant, body FROM content_templates
WHERE seed_version = @seed_version AND lang = @lang;

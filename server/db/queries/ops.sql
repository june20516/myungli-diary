-- 운영 명령(#1321)의 감사 기록 쿼리입니다.

-- name: InsertOpsAudit :exec
-- 운영 행위 한 건을 남깁니다. purpose는 content_view일 때만 값이 있습니다.
INSERT INTO ops_audit (id, at, actor, channel, action, account_id, purpose, reason, target, before, after)
VALUES (@id, @at, @actor, @channel, @action, sqlc.narg('account_id'), sqlc.narg('purpose'), @reason, @target, sqlc.narg('before'), sqlc.narg('after'));

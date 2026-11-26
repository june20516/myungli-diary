-- 운영 명령(#1321)의 감사 기록 쿼리입니다.

-- name: InsertOpsAudit :exec
-- 운영 행위 한 건을 남깁니다. purpose는 content_view일 때만 값이 있습니다.
INSERT INTO ops_audit (id, at, actor, channel, action, account_id, purpose, reason, target, before, after)
VALUES (@id, @at, @actor, @channel, @action, sqlc.narg('account_id'), sqlc.narg('purpose'), @reason, @target, sqlc.narg('before'), sqlc.narg('after'));

-- name: GetOpsAccount :one
-- 지원 조회용 계정 한 건입니다.
SELECT id, status, created_at, deleted_at, last_active_at
FROM accounts
WHERE id = @id;

-- name: ListOpsIdentities :many
-- 로그인 수단입니다. 제공자 subject와 Apple 토큰은 읽지 않습니다.
SELECT provider, created_at
FROM auth_identities
WHERE account_id = @account_id
ORDER BY created_at, id;

-- name: ListOpsDevices :many
-- 기기입니다. 알림 token은 읽지 않습니다.
SELECT platform, active, created_at, last_seen_at
FROM devices
WHERE account_id = @account_id
ORDER BY created_at, id;

-- name: ListOpsPurchases :many
-- 구매 장부입니다. original_account_id가 account_id와 다르면 합치기로 옮겨 온 구매입니다.
SELECT product_id, store, store_purchase_id, purchased_at, refunded_at, production, original_account_id
FROM purchases
WHERE account_id = @account_id
ORDER BY purchased_at DESC, id;

-- name: ListOpsAccountsByStoreTransaction :many
-- 스토어 거래 id를 가진 구매의 계정입니다. 둘 이상이면 호출한 쪽이 모호함으로 다룹니다.
SELECT DISTINCT account_id
FROM purchases
WHERE store_purchase_id = @store_purchase_id
ORDER BY account_id;

-- name: ListOpsAudit :many
-- 감사 기록입니다. 최근 기록이 먼저입니다.
SELECT id, at, actor, channel, action, account_id, purpose, reason, target, before, after
FROM ops_audit
WHERE (sqlc.narg('account_id')::uuid IS NULL OR account_id = sqlc.narg('account_id')::uuid)
  AND (sqlc.narg('since')::timestamptz IS NULL OR at >= sqlc.narg('since')::timestamptz)
ORDER BY at DESC, id DESC
LIMIT @row_limit;

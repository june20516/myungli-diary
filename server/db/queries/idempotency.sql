-- Idempotency-Key 쿼리입니다. 이 표는 시스템 데이터라 행을 물리적으로 지웁니다.

-- name: ClaimIdempotencyKey :one
-- 키를 선점합니다. 행이 없거나 만료된 행(created_at <= expired_before)일 때만 새로 쓰고 account_id를 돌려줍니다.
-- 살아 있는 행이 있으면 아무것도 바꾸지 않고 행을 돌려받지 못합니다(pgx.ErrNoRows).
INSERT INTO idempotency_keys (account_id, key, request_hash, created_at)
VALUES (@account_id, @key, @request_hash, @created_at)
ON CONFLICT (account_id, key) DO UPDATE
SET request_hash = EXCLUDED.request_hash, status = NULL, headers = NULL, body = NULL,
    created_at = EXCLUDED.created_at, completed_at = NULL
WHERE idempotency_keys.created_at <= @expired_before
RETURNING account_id;

-- name: GetIdempotencyKey :one
SELECT request_hash, status, headers, body, completed_at
FROM idempotency_keys
WHERE account_id = @account_id AND key = @key;

-- name: CompleteIdempotencyKey :execrows
UPDATE idempotency_keys
SET status = @status, headers = @headers, body = @body, completed_at = @completed_at
WHERE account_id = @account_id AND key = @key AND request_hash = @request_hash AND completed_at IS NULL;

-- name: ReleaseIdempotencyKey :exec
-- 완료되지 않은 행만 지웁니다(요청 지문이 같은 선점자의 것).
DELETE FROM idempotency_keys
WHERE account_id = @account_id AND key = @key AND request_hash = @request_hash AND completed_at IS NULL;

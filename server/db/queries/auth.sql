-- name: CreateAccount :exec
INSERT INTO accounts (id, status, last_active_at)
VALUES (@id, 'active', @last_active_at);

-- GetIdentity는 제공자 연결과 계정 status를 함께 읽고 계정 행을 잠급니다.
-- 같은 계정에 대한 동시 로그인·복구가 한 줄로 처리됩니다.
-- name: GetIdentity :one
SELECT i.id, i.account_id, i.provider, i.subject,
       i.apple_refresh_token, i.apple_token_key_id, i.apple_client_id,
       i.provider_disconnected_at, a.status AS account_status
FROM auth_identities i
JOIN accounts a ON a.id = i.account_id
WHERE i.provider = @provider AND i.subject = @subject
FOR UPDATE OF a;

-- name: CreateIdentity :exec
INSERT INTO auth_identities (id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
VALUES (@id, @account_id, @provider, @subject, @apple_refresh_token, @apple_token_key_id, @apple_client_id);

-- name: UpdateAppleToken :exec
UPDATE auth_identities
SET apple_refresh_token = @apple_refresh_token,
    apple_token_key_id = @apple_token_key_id,
    apple_client_id = @apple_client_id
WHERE id = @id;

-- RestoreAccount는 삭제 대기 계정을 되살립니다. 갱신된 행 수를 돌려줍니다.
-- name: RestoreAccount :execrows
UPDATE accounts
SET status = 'active', deletion_requested_at = NULL
WHERE id = @id AND status = 'pending_deletion';

-- name: ClearProviderDisconnected :exec
UPDATE auth_identities
SET provider_disconnected_at = NULL
WHERE account_id = @account_id AND provider_disconnected_at IS NOT NULL;

-- name: InsertRefreshToken :exec
INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at)
VALUES (@id, @account_id, @token_hash, @family_id, @expires_at);

-- GetRefreshTokenForUpdate는 refresh 행을 잠그고 계정 status를 함께 돌려줍니다.
-- 동시에 같은 토큰으로 refresh하면 한쪽이 잠금을 기다린 뒤 used_at을 보게 됩니다.
-- name: GetRefreshTokenForUpdate :one
SELECT t.id, t.account_id, t.token_hash, t.family_id, t.expires_at, t.used_at, t.revoked_at,
       a.status AS account_status
FROM refresh_tokens t
JOIN accounts a ON a.id = t.account_id
WHERE t.token_hash = @token_hash
FOR UPDATE OF t;

-- name: MarkRefreshTokenUsed :execrows
UPDATE refresh_tokens
SET used_at = @used_at::timestamptz
WHERE id = @id AND used_at IS NULL;

-- name: RevokeFamily :exec
UPDATE refresh_tokens
SET revoked_at = @revoked_at::timestamptz
WHERE family_id = @family_id AND revoked_at IS NULL;

-- name: RevokeAccountTokens :exec
UPDATE refresh_tokens
SET revoked_at = @revoked_at::timestamptz
WHERE account_id = @account_id AND revoked_at IS NULL;

-- name: ListIdentities :many
SELECT id, account_id, provider, subject,
       apple_refresh_token, apple_token_key_id, apple_client_id, provider_disconnected_at
FROM auth_identities
WHERE account_id = @account_id
ORDER BY created_at, id;

-- MarkProviderDisconnected는 Apple 토큰 세 열을 비우고 연결 해제 시각을 기록합니다.
-- name: MarkProviderDisconnected :exec
UPDATE auth_identities
SET apple_refresh_token = NULL,
    apple_token_key_id = NULL,
    apple_client_id = NULL,
    provider_disconnected_at = @disconnected_at::timestamptz
WHERE id = @id;

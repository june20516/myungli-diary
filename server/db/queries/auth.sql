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

-- IdentityExists는 (provider, subject) 연결 행이 있는지 잠그지 않고 확인합니다.
-- Apple 로그인 트랜잭션이 실패한 뒤 교환한 토큰을 revoke해도 되는지 판단할 때 씁니다.
-- name: IdentityExists :one
SELECT EXISTS (
    SELECT 1 FROM auth_identities WHERE provider = @provider AND subject = @subject
);

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
SELECT t.id, t.account_id, t.token_hash, t.family_id, t.expires_at, t.used_at, t.replaced_by_id, t.revoked_at,
       a.status AS account_status
FROM refresh_tokens t
JOIN accounts a ON a.id = t.account_id
WHERE t.token_hash = @token_hash
FOR UPDATE OF t;

-- MarkRefreshTokenUsed는 토큰을 쓴 시각과 그 대신 발급한 다음 토큰을 기록합니다.
-- 다음 토큰은 replaced_by_id 외래 키 때문에 먼저 저장돼 있어야 합니다.
-- name: MarkRefreshTokenUsed :execrows
UPDATE refresh_tokens
SET used_at = @used_at::timestamptz, replaced_by_id = @replaced_by_id::uuid
WHERE id = @id AND used_at IS NULL;

-- GetRefreshTokenByIDForUpdate는 id로 refresh 행을 잠그고 사용·폐기 상태를 돌려줍니다.
-- 유예 처리에서 이미 쓴 토큰의 다음 토큰을 확인할 때 씁니다.
-- name: GetRefreshTokenByIDForUpdate :one
SELECT id, used_at, revoked_at
FROM refresh_tokens
WHERE id = @id
FOR UPDATE;

-- RevokeRefreshToken은 아직 폐기되지 않은 토큰 하나를 폐기합니다. 바뀐 행 수를 돌려줍니다.
-- name: RevokeRefreshToken :execrows
UPDATE refresh_tokens
SET revoked_at = @revoked_at::timestamptz
WHERE id = @id AND revoked_at IS NULL;

-- SetRefreshTokenReplacedBy는 이미 쓴 토큰의 다음 토큰을 바꿉니다. used_at은 그대로 둡니다(유예 창이 늘어나지 않게).
-- name: SetRefreshTokenReplacedBy :execrows
UPDATE refresh_tokens
SET replaced_by_id = @replaced_by_id::uuid
WHERE id = @id AND used_at IS NOT NULL;

-- RevokeFamily는 family에서 아직 폐기되지 않은 토큰을 모두 폐기합니다. 바뀐 행 수를 돌려줍니다.
-- name: RevokeFamily :execrows
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

-- LockAccountStatus는 계정 행을 잠그고 status를 돌려줍니다.
-- 제공자 연결 해제를 기록하기 전에 부르면, 그 사이 복구 로그인이 끼어들어 새로 저장한 연결을 덮지 않습니다.
-- name: LockAccountStatus :one
SELECT status FROM accounts WHERE id = @id FOR UPDATE;

-- InsertAppleWebLogin은 Apple 웹 콜백이 교환한 결과를 교환 코드 해시와 함께 저장합니다.
-- name: InsertAppleWebLogin :exec
INSERT INTO apple_web_logins (
    id, exchange_hash, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id, expires_at
) VALUES (
    @id, @exchange_hash, @subject, @nonce_hash, @apple_refresh_token, @apple_token_key_id, @apple_client_id,
    @expires_at::timestamptz
);

-- GetAppleWebLoginForUpdate는 교환 코드 해시로 행을 읽고 잠급니다. 같은 코드의 동시 교환이 한 줄로 처리됩니다.
-- name: GetAppleWebLoginForUpdate :one
SELECT id, exchange_hash, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id,
       expires_at, consumed_at
FROM apple_web_logins
WHERE exchange_hash = @exchange_hash
FOR UPDATE;

-- ConsumeAppleWebLogin은 아직 소진되지 않은 행만 소진 처리합니다. 바뀐 행 수가 0이면 이미 소진된 것입니다.
-- name: ConsumeAppleWebLogin :execrows
UPDATE apple_web_logins
SET consumed_at = @consumed_at::timestamptz
WHERE id = @id AND consumed_at IS NULL;

-- ListAccountIdentities는 계정의 제공자 연결을 붙인 순으로 돌려줍니다(listIdentities, S100). subject는 내보내지 않습니다.
-- name: ListAccountIdentities :many
SELECT provider, created_at
FROM auth_identities
WHERE account_id = @account_id
ORDER BY created_at, id;

-- GetIdentityForLink는 붙이려는 (provider, subject) 연결과 그 계정의 status를 읽고 계정 행을 잠급니다.
-- 붙이기 트랜잭션이 현재 계정 행을 먼저 잠근 뒤 부르므로, 다른 계정 행은 그 다음에 잠깁니다.
-- name: GetIdentityForLink :one
SELECT i.id, i.account_id, a.status AS account_status
FROM auth_identities i
JOIN accounts a ON a.id = i.account_id
WHERE i.provider = @provider AND i.subject = @subject
FOR UPDATE OF a;

-- AccountHasProvider는 계정에 그 제공자 연결이 이미 있는지 알려 줍니다(한 계정에 제공자마다 연결 하나).
-- name: AccountHasProvider :one
SELECT EXISTS (
    SELECT 1 FROM auth_identities WHERE account_id = @account_id AND provider = @provider
);

-- name: CountIdentities :one
SELECT count(*) FROM auth_identities WHERE account_id = @account_id;

-- DeleteIdentity는 계정의 그 제공자 연결을 물리적으로 지우고, 지운 행을 돌려줍니다.
-- 커밋 뒤 허가 취소(카카오 unlink, Apple revoke)에 subject와 Apple 토큰 열을 씁니다.
-- name: DeleteIdentity :one
DELETE FROM auth_identities
WHERE account_id = @account_id AND provider = @provider
RETURNING id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id;

-- InsertMergeTicket은 합치기 토큰의 해시를 저장합니다(S101). 원문은 저장하지 않습니다.
-- name: InsertMergeTicket :exec
INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
VALUES (@id, @token_hash, @account_id, @other_account_id, @identity_id, @expires_at::timestamptz);

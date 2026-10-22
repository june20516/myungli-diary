-- name: CreateAccount :exec
INSERT INTO accounts (id, status, last_active_at)
VALUES (@id, 'active', @last_active_at);

-- GetIdentity는 제공자 연결과 계정 status를 함께 읽고 계정 행을 잠급니다.
-- 같은 계정에 대한 동시 로그인·계정 삭제가 한 줄로 처리됩니다. 잠금을 기다린 뒤 다시 확인하는 것은 계정 행뿐이라,
-- 기다리는 사이 지워진 연결 행을 돌려줄 수 있습니다(호출자가 IdentityExists로 다시 확인).
-- name: GetIdentity :one
SELECT i.id, i.account_id, i.provider, i.subject,
       i.apple_refresh_token, i.apple_token_key_id, i.apple_client_id,
       a.status AS account_status
FROM auth_identities i
JOIN accounts a ON a.id = i.account_id
WHERE i.provider = @provider AND i.subject = @subject
FOR UPDATE OF a;

-- IdentityExists는 (provider, subject) 연결 행이 있는지 잠그지 않고 확인합니다.
-- Apple 로그인 트랜잭션이 실패한 뒤 교환한 토큰을 revoke해도 되는지 판단할 때와, 계정 행 잠금을 기다린 뒤
-- 연결 행이 정말 남아 있는지 다시 확인할 때 씁니다.
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

-- LockAccountStatus는 계정 행을 잠그고 status를 돌려줍니다.
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
-- GetIdentity와 같이 기다리는 사이 지워진 연결 행을 돌려줄 수 있습니다.
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

-- InsertMergeTicket은 합치기 토큰의 해시를 저장합니다. 원문은 저장하지 않습니다.
-- 연결 409는 더 이상 토큰을 만들지 않고(S110), 합치기 요약(previewMerge, S110)이 이 쿼리로 발급합니다.
-- name: InsertMergeTicket :exec
INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
VALUES (@id, @token_hash, @account_id, @other_account_id, @identity_id, @expires_at::timestamptz);

-- QueueRevocation은 카카오·Apple 허가 취소 대기 행을 하나 넣고 id를 돌려줍니다(S106).
-- created_at은 30일 포기 판정의 기준이라 DB 기본값 대신 앱 시각을 넣습니다.
-- name: QueueRevocation :one
INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at, created_at)
VALUES (@provider, @subject, @identity_id, @apple_refresh_token, @apple_token_key_id, @apple_client_id, @now::timestamptz, @now::timestamptz)
RETURNING id;

-- LockDueRevocation은 시각이 된 대기 행 하나를 잠그고 돌려줍니다. 다른 곳이 잠근 행은 건너뜁니다.
-- name: LockDueRevocation :one
SELECT id, provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id,
       attempts, next_attempt_at, created_at
FROM provider_revocations
WHERE next_attempt_at <= @now::timestamptz
ORDER BY next_attempt_at, id
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- LockRevocation은 아직 시도하지 않은(attempts = 0) 대기 행 하나를 id로 잠그고 돌려줍니다. 다른 곳이 잠근 행은 건너뜁니다.
-- 이미 실패 처리된 행은 재시도 job의 몫이라, Attempt가 곧바로 다시 부르지 않게 합니다.
-- name: LockRevocation :one
SELECT id, provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id,
       attempts, next_attempt_at, created_at
FROM provider_revocations
WHERE id = @id AND attempts = 0
FOR UPDATE SKIP LOCKED;

-- name: DeleteRevocation :exec
DELETE FROM provider_revocations WHERE id = @id;

-- ScheduleRevocationRetry는 실패한 대기 행의 시도 횟수와 다음 시각을 정합니다.
-- name: ScheduleRevocationRetry :exec
UPDATE provider_revocations
SET attempts = @attempts, next_attempt_at = @next_attempt_at::timestamptz
WHERE id = @id;

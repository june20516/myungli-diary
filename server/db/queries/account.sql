-- name: GetAccountAccess :one
SELECT status, deletion_requested_at, last_active_at
FROM accounts
WHERE id = @id;

-- TouchLastActive는 저장된 값보다 더 새 시각일 때만 갱신합니다. 하루 한 번으로 제한하는 일은 호출자가 지킵니다.
-- name: TouchLastActive :execrows
UPDATE accounts
SET last_active_at = @last_active_at
WHERE id = @id AND last_active_at < @last_active_at;

-- name: ListConsents :many
SELECT document, version, agreed_at
FROM consents
WHERE account_id = @account_id
ORDER BY agreed_at, document, version;

-- name: InsertConsent :exec
INSERT INTO consents (id, account_id, document, version, agreed_at)
VALUES (@id, @account_id, @document, @version, @agreed_at)
ON CONFLICT (account_id, document, version) DO NOTHING;

-- 아래는 계정 삭제(DeleteAccountTx, S105)의 쿼리입니다. 지우는 순서는 FK 자식부터입니다(FK가 모두 ON DELETE RESTRICT).

-- LockAccountForDelete는 계정 행을 잠그고 상태를 돌려줍니다. 같은 계정에 쓰는 요청은 이 잠금 뒤에서 기다립니다.
-- name: LockAccountForDelete :one
SELECT status
FROM accounts
WHERE id = @id
FOR UPDATE;

-- QueueProviderRevocations는 카카오와, 저장한 token이 있는 Apple 인증 계정마다 허가 취소 대기 행을 넣습니다(S106).
-- Apple refresh token은 원래 행의 암호화 값 그대로 옮기고, 복호화의 aad인 원래 인증 계정 id를 함께 남깁니다.
-- name: QueueProviderRevocations :many
INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at)
SELECT provider,
       CASE WHEN provider = 'kakao' THEN subject END,
       id,
       apple_refresh_token,
       apple_token_key_id,
       apple_client_id,
       @next_attempt_at::timestamptz
FROM auth_identities
WHERE account_id = @account_id
  AND (provider = 'kakao' OR (provider = 'apple' AND apple_refresh_token IS NOT NULL))
RETURNING id;

-- TallyReactions는 살아 있는 반응을 계정과 끊긴 문장별 집계에 더합니다(D57).
-- name: TallyReactions :exec
INSERT INTO reaction_tallies (message_key, variant, reaction, count)
SELECT s.message_key, s.variant, r.reaction, count(*)
FROM reactions r
JOIN daily_selections s ON s.id = r.selection_id
WHERE s.account_id = @account_id AND r.deleted_at IS NULL
GROUP BY s.message_key, s.variant, r.reaction
ON CONFLICT (message_key, variant, reaction) DO UPDATE
SET count = reaction_tallies.count + EXCLUDED.count;

-- name: DeleteReactionsByAccount :exec
DELETE FROM reactions
WHERE selection_id IN (SELECT id FROM daily_selections WHERE account_id = @account_id);

-- name: DeleteDailySelectionsByAccount :exec
DELETE FROM daily_selections WHERE account_id = @account_id;

-- name: DeleteRotationStateByAccount :exec
DELETE FROM rotation_state WHERE account_id = @account_id;

-- name: DeleteDiariesByAccount :exec
DELETE FROM diaries WHERE account_id = @account_id;

-- name: DeleteDiaryDaysByAccount :exec
DELETE FROM diary_days WHERE account_id = @account_id;

-- name: DeleteSchedulesByAccount :exec
DELETE FROM schedules WHERE account_id = @account_id;

-- name: DeleteIdempotencyKeysByAccount :exec
DELETE FROM idempotency_keys WHERE account_id = @account_id;

-- DeleteMergeTicketsByAccount는 이 계정이 A(account_id)이거나 B(other_account_id)인 합치기 토큰을 지웁니다.
-- name: DeleteMergeTicketsByAccount :exec
DELETE FROM account_merge_tickets WHERE account_id = @account_id OR other_account_id = @account_id;

-- name: DeleteRefreshTokensByAccount :exec
DELETE FROM refresh_tokens WHERE account_id = @account_id;

-- name: DeleteConsentsByAccount :exec
DELETE FROM consents WHERE account_id = @account_id;

-- name: DeleteIdentitiesByAccount :exec
DELETE FROM auth_identities WHERE account_id = @account_id;

-- 계산 캐시는 이 계정 프로필의 출생 해시로 지웁니다. 프로필이 없으면 지울 것이 없습니다.
-- 같은 출생 정보의 다른 계정도 쓰던 행일 수 있지만 다시 계산할 수 있습니다(D88 ③).

-- name: DeleteChartCacheByProfile :exec
DELETE FROM chart_cache
WHERE birth_hash = (SELECT birth_hash FROM profiles WHERE account_id = @account_id);

-- name: DeleteDailyCacheByProfile :exec
DELETE FROM daily_cache
WHERE birth_hash = (SELECT birth_hash FROM profiles WHERE account_id = @account_id);

-- name: DeleteMonthCacheByProfile :exec
DELETE FROM month_cache
WHERE birth_hash = (SELECT birth_hash FROM profiles WHERE account_id = @account_id);

-- name: DeleteProfileByAccount :exec
DELETE FROM profiles WHERE account_id = @account_id;

-- MarkAccountDeleted는 계정을 껍데기(id·status·created_at·deleted_at)로 남깁니다.
-- 옛 CHECK(accounts_status_timestamps)가 deleted에 deletion_requested_at·anonymized_at을 요구하므로 둘도 같은 시각으로 채웁니다.
-- 옛 열을 없애는 migration과 함께 이 두 쓰기도 없어집니다.
-- name: MarkAccountDeleted :exec
UPDATE accounts
SET status = 'deleted',
    deleted_at = @deleted_at::timestamptz,
    deletion_requested_at = @deleted_at::timestamptz,
    anonymized_at = @deleted_at::timestamptz
WHERE id = @id;

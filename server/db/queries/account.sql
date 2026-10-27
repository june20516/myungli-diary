-- name: GetAccountAccess :one
SELECT status, last_active_at
FROM accounts
WHERE id = @id;

-- TouchLastActive는 저장된 값보다 더 새 시각일 때만 갱신합니다. 하루 한 번으로 제한하는 일은 호출자가 지킵니다.
-- 지운 계정의 껍데기는 갱신하지 않습니다.
-- name: TouchLastActive :execrows
UPDATE accounts
SET last_active_at = @last_active_at
WHERE id = @id AND last_active_at < @last_active_at AND status <> 'deleted';

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
-- created_at은 30일 포기 판정(S106)의 기준이라 DB 기본값 대신 앱 시각을 넣습니다.
INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at, created_at)
SELECT provider,
       CASE WHEN provider = 'kakao' THEN subject END,
       id,
       apple_refresh_token,
       apple_token_key_id,
       apple_client_id,
       @now::timestamptz,
       @now::timestamptz
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
-- 집계 행 잠금 순서를 고정해 두 계정 삭제가 같은 문장 집계를 반대 순서로 잠그는 deadlock을 막습니다.
ORDER BY s.message_key, s.variant, r.reaction
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

-- DeleteMergeReceiptsByAccount는 이 계정이 A로 합친 영수증을 지웁니다(S115).
-- name: DeleteMergeReceiptsByAccount :exec
DELETE FROM account_merge_receipts WHERE account_id = @account_id;

-- name: DeleteRefreshTokensByAccount :exec
DELETE FROM refresh_tokens WHERE account_id = @account_id;

-- name: DeleteConsentsByAccount :exec
DELETE FROM consents WHERE account_id = @account_id;

-- DeleteAppleWebLoginsByAccount는 이 계정 Apple 인증 계정의 웹 로그인 기록(subject·nonce 해시·암호화 refresh token)을
-- 지웁니다. subject로 찾으므로 인증 계정보다 먼저 지웁니다.
-- name: DeleteAppleWebLoginsByAccount :exec
DELETE FROM apple_web_logins
WHERE subject IN (SELECT i.subject FROM auth_identities i WHERE i.account_id = @account_id AND i.provider = 'apple');

-- name: DeleteIdentitiesByAccount :exec
DELETE FROM auth_identities WHERE account_id = @account_id;

-- 계산 캐시는 이 계정의 출생 해시로 지웁니다. 지금 프로필의 해시와, 프로필을 고치기 전 출생 정보로 남은
-- 문장 선택 기록의 해시를 함께 봅니다. 그래서 프로필·선택 기록보다 먼저 지웁니다.
-- 같은 출생 정보의 다른 계정도 쓰던 행일 수 있지만 다시 계산할 수 있습니다(D88 ③).

-- name: DeleteChartCacheByAccount :exec
DELETE FROM chart_cache
WHERE birth_hash IN (
    SELECT p.birth_hash FROM profiles p WHERE p.account_id = @account_id
    UNION
    SELECT s.birth_hash FROM daily_selections s WHERE s.account_id = @account_id AND s.birth_hash IS NOT NULL
);

-- name: DeleteDailyCacheByAccount :exec
DELETE FROM daily_cache
WHERE birth_hash IN (
    SELECT p.birth_hash FROM profiles p WHERE p.account_id = @account_id
    UNION
    SELECT s.birth_hash FROM daily_selections s WHERE s.account_id = @account_id AND s.birth_hash IS NOT NULL
);

-- name: DeleteMonthCacheByAccount :exec
DELETE FROM month_cache
WHERE birth_hash IN (
    SELECT p.birth_hash FROM profiles p WHERE p.account_id = @account_id
    UNION
    SELECT s.birth_hash FROM daily_selections s WHERE s.account_id = @account_id AND s.birth_hash IS NOT NULL
);

-- name: DeleteProfileByAccount :exec
DELETE FROM profiles WHERE account_id = @account_id;

-- MarkAccountDeleted는 계정을 껍데기(id·status·created_at·deleted_at)로 남깁니다.
-- last_active_at은 NOT NULL이라 지운 시각으로 덮어 마지막 활동 시각을 남기지 않습니다.
-- name: MarkAccountDeleted :exec
UPDATE accounts
SET status = 'deleted',
    deleted_at = @deleted_at::timestamptz,
    last_active_at = @deleted_at::timestamptz
WHERE id = @id;

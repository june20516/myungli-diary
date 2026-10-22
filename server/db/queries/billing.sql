-- 권한 기록 쿼리입니다. 판정은 이 쿼리가 돌려준 유효한 행으로 계산합니다(spec §3.3).

-- name: ListLiveGrants :many
-- 계정의 취소되지 않았고 아직 만료되지 않은 권한 행입니다. 시작 전인 행도 포함하므로 호출한 쪽이 starts_at을 봅니다.
-- 순서는 (expires_at, id) 오름차순으로 고정합니다.
SELECT entitlement, source, starts_at, expires_at
FROM entitlement_grants
WHERE account_id = @account_id
  AND revoked_at IS NULL
  AND expires_at > @now
ORDER BY expires_at, id;

-- name: ListAdFreePassGrants :many
-- 계정의 광고 제거권 출처(ad_free_pass) 행 전체입니다. 취소된 행도 포함합니다(동기화가 조정할 대상, P7-5).
SELECT id, entitlement, source_ref, revoked_at
FROM entitlement_grants
WHERE account_id = @account_id
  AND source = 'ad_free_pass'
ORDER BY id;

-- name: UpsertGrant :exec
-- (entitlement, source, source_ref)로 행을 찾아 기간을 맞추고 취소를 풉니다(P7-4·P7-5).
-- 같은 구매가 다른 계정 행으로 이미 있으면(RevenueCat transfer 등) 지금 구매 목록에 그 구매가 있는 계정으로 옮깁니다(구매 목록이 권위).
-- 바뀐 값이 없으면 행을 다시 쓰지 않습니다.
INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
VALUES (@account_id, @entitlement, @source, @source_ref, @starts_at, @expires_at)
ON CONFLICT (account_id, entitlement, source, source_ref) DO UPDATE
SET account_id = EXCLUDED.account_id,
    starts_at  = EXCLUDED.starts_at,
    expires_at = EXCLUDED.expires_at,
    revoked_at = NULL
WHERE entitlement_grants.account_id <> EXCLUDED.account_id
   OR entitlement_grants.starts_at <> EXCLUDED.starts_at
   OR entitlement_grants.expires_at <> EXCLUDED.expires_at
   OR entitlement_grants.revoked_at IS NOT NULL;

-- name: RevokeGrant :exec
-- 행을 취소합니다. 이미 취소된 행의 revoked_at은 그대로 둡니다(P7-5).
-- account_id 조건은 그 사이 다른 계정의 동기화가 이 행을 옮겨 간 경우(transfer) 그 계정 행을 취소하지 않게 합니다.
UPDATE entitlement_grants
SET revoked_at = @now::timestamptz
WHERE id = @id
  AND account_id = @account_id
  AND revoked_at IS NULL;

-- name: ExistingAccountIDs :many
-- 후보 id 중 accounts에 있는 id입니다(webhook 계정 찾기, P7-7). 순서는 보장하지 않으므로 호출한 쪽이 후보 순서로 맞춥니다.
SELECT id
FROM accounts
WHERE id = ANY(@ids::uuid[]);

-- name: InsertBillingEvent :exec
-- webhook 이벤트를 기록합니다. 같은 event_id가 이미 있으면 아무것도 하지 않습니다(P7-8).
INSERT INTO billing_events (event_id, account_id, payload, received_at)
VALUES (@event_id, @account_id, @payload, @received_at)
ON CONFLICT (event_id) DO NOTHING;

-- name: BillingEventProcessedAt :one
-- 이벤트의 처리 완료 시각입니다. NULL이면 아직 처리하지 않았거나 앞선 처리가 실패했습니다.
SELECT processed_at
FROM billing_events
WHERE event_id = @event_id;

-- name: MarkBillingEventProcessed :exec
-- 이벤트 처리를 마쳤다고 찍습니다. 이미 찍혀 있으면 처음 시각을 그대로 둡니다.
UPDATE billing_events
SET processed_at = @now::timestamptz
WHERE event_id = @event_id
  AND processed_at IS NULL;

-- name: InsertRewardEvent :execrows
-- 보상형 광고 콜백을 기록합니다. 같은 transaction_id가 이미 있으면 아무것도 하지 않고 0행입니다(P7-14).
INSERT INTO reward_events (transaction_id, account_id, ad_unit, reward_item, raw_query, received_at)
VALUES (@transaction_id, @account_id, @ad_unit, @reward_item, @raw_query, @received_at)
ON CONFLICT (transaction_id) DO NOTHING;

-- name: AccountCurrentTimezone :one
-- 계정 프로필의 현재 시간대(IANA 이름)입니다. 프로필이 없으면 행이 없습니다.
SELECT current_timezone
FROM profiles
WHERE account_id = @account_id;

-- name: InsertRewardedAdGrant :exec
-- 보상형 광고의 insight 권한 행입니다. source_ref는 transaction_id입니다. 이미 있으면 아무것도 하지 않습니다(P7-14).
INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
VALUES (@account_id, 'insight', 'rewarded_ad', @source_ref, @starts_at, @expires_at)
ON CONFLICT (account_id, entitlement, source, source_ref) DO NOTHING;

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

-- name: RevokeGrant :exec
-- 행을 취소합니다. 이미 취소된 행의 revoked_at은 그대로 둡니다(rechainFrom의 환불 구간, S108).
-- account_id 조건은 호출한 계정의 행만 취소하게 하는 안전장치입니다.
UPDATE entitlement_grants
SET revoked_at = @now::timestamptz
WHERE id = @id
  AND account_id = @account_id
  AND revoked_at IS NULL;

-- name: InsertPurchase :execrows
-- 구매를 장부에 적습니다. 주인과 처음 산 계정은 적는 계정입니다(S107).
-- 같은 id가 이미 있으면 아무것도 하지 않고 0행입니다(주인은 바꾸지 않음). 빈 스토어 거래 id는 NULL로 적습니다.
INSERT INTO purchases (id, account_id, original_account_id, product_id, store, store_purchase_id, purchased_at, refunded_at, production)
VALUES (@id, @account_id, @account_id, @product_id, @store, NULLIF(@store_purchase_id::text, ''), @purchased_at, sqlc.narg(refunded_at), @production)
ON CONFLICT (id) DO NOTHING;

-- name: PurchaseOwner :one
-- 구매의 지금 주인 계정입니다. 장부에 없으면 행이 없습니다.
SELECT account_id
FROM purchases
WHERE id = @id;

-- name: OwnersByStorePurchaseIDs :many
-- 그 스토어에서 스토어 거래 id 중 하나를 가진 구매의 주인 계정입니다(webhook 대체 경로, spec §5.4). 중복 없이 id 순입니다.
SELECT DISTINCT account_id
FROM purchases
WHERE store = @store
  AND store_purchase_id = ANY(@store_purchase_ids::text[])
ORDER BY account_id;

-- name: PurchaseBySameStoreTransaction :one
-- 같은 스토어 거래(store, store_purchase_id)를 다른 구매 id로 먼저 적은 행입니다(spec §5.2 방어). 먼저 적은 행 하나입니다.
SELECT id, account_id
FROM purchases
WHERE store = @store
  AND store_purchase_id = @store_purchase_id::text
  AND id <> @id
ORDER BY created_at, id
LIMIT 1;

-- name: PurchaseRefunded :one
-- 장부의 구매가 환불로 적혀 있는지입니다. 잠그지 않은 주인 계정의 구매를 쓰지 않고 볼 때 씁니다(spec §5.4).
SELECT (refunded_at IS NOT NULL)::boolean AS refunded
FROM purchases
WHERE id = @id;

-- name: MarkPurchaseRefunded :execrows
-- 구매를 환불로 적습니다. 이미 환불된 구매는 처음 시각을 그대로 두고 0행입니다.
UPDATE purchases
SET refunded_at = @refunded_at::timestamptz
WHERE id = @id
  AND refunded_at IS NULL;

-- name: NextPassStart :one
-- 새 구매 구간의 시작 = max(구매 시각, 이 계정의 같은 권한 광고 제거권 구간 끝)입니다(S108).
-- ListPassSegments와 같이 장부에 구매가 있는 취소되지 않은 구간만 셉니다. GREATEST는 NULL(구간 없음)을 무시합니다.
SELECT GREATEST(@purchased_at::timestamptz, max(g.expires_at))::timestamptz AS starts_at
FROM entitlement_grants g
JOIN purchases p ON p.id = g.source_ref
WHERE g.account_id = @account_id
  AND g.entitlement = @entitlement
  AND g.source = 'ad_free_pass'
  AND g.revoked_at IS NULL;

-- name: InsertPassGrant :exec
-- 광고 제거권 구간 한 행입니다. source_ref는 구매 id입니다. 이미 있으면 아무것도 하지 않습니다.
INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
VALUES (@account_id, @entitlement, 'ad_free_pass', @source_ref, @starts_at, @expires_at)
ON CONFLICT (account_id, entitlement, source, source_ref) DO NOTHING;

-- name: ListPassSegments :many
-- 계정의 취소되지 않은 광고 제거권 구간과 그 구매의 환불 여부입니다(rechainFrom, S108).
-- 순서는 권한, 구매 시각, 구매 id입니다. 장부 이전 구간은 00016이 지웠으므로 모든 구간에 장부 행이 있습니다.
SELECT g.id, g.entitlement, g.starts_at, g.expires_at, (p.refunded_at IS NOT NULL)::boolean AS refunded
FROM entitlement_grants g
JOIN purchases p ON p.id = g.source_ref
WHERE g.account_id = @account_id
  AND g.source = 'ad_free_pass'
  AND g.revoked_at IS NULL
ORDER BY g.entitlement, p.purchased_at, p.id;

-- name: ListAccountPurchases :many
-- 계정이 주인인 구매와 이 계정의 광고 제거권 사용 구간입니다(구매 목록, spec §5.5). 최근 구매 먼저입니다.
-- 한 구매의 권한 행은 같은 구간이라 이 계정의 행 하나만 봅니다(권한 이름 순 첫 행). 권한을 고정하지 않으므로 insight만 주는
-- 기간 상품도 구간이 나옵니다(spec §5.6). 구간 행은 이 계정의 것만 잇고(합친 구매의 B 구간 제외),
-- 구간이 없는 구매(목록 밖 상품, 시작 전 환불로 구간이 없던 구매)는 구간 열이 NULL입니다.
SELECT p.id, p.product_id, p.purchased_at, p.refunded_at,
       g.starts_at AS segment_starts_at, g.expires_at AS segment_expires_at, g.revoked_at AS segment_revoked_at
FROM purchases p
LEFT JOIN entitlement_grants g
       ON g.source_ref = p.id
      AND g.account_id = @account_id
      AND g.source = 'ad_free_pass'
      -- unique (account_id, entitlement, source, source_ref)라 권한 하나를 고르면 한 행입니다.
      -- LATERAL 하위 쿼리 대신 이 형태를 쓰는 것은 sqlc가 LEFT JOIN 표의 열을 NULL 가능으로 추론하게 하려는 것입니다.
      AND g.entitlement = (
          SELECT min(eg.entitlement)
          FROM entitlement_grants eg
          WHERE eg.source_ref = p.id
            AND eg.account_id = @account_id
            AND eg.source = 'ad_free_pass'
      )
WHERE p.account_id = @account_id
ORDER BY p.purchased_at DESC, p.id;

-- name: SetGrantPeriod :exec
-- 구간의 시작·끝을 옮깁니다(rechainFrom의 대기 구간). 취소된 구간은 옮기지 않습니다.
UPDATE entitlement_grants
SET starts_at  = @starts_at,
    expires_at = @expires_at
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

-- name: ListMovablePassSegments :many
-- 계정 합치기(MovePurchasesTx, spec §5.3·§6.3)로 옮길 계정의 아직 끝나지 않은 광고 제거권 구간입니다. 끊긴 구간(환불)과 보상형 광고 구간은 옮기지 않으므로 뺍니다.
-- 순서는 권한, 그 계정 사슬의 시작 순입니다(받는 계정 끝에 차례로 붙임).
SELECT g.id, g.entitlement, g.source_ref, g.starts_at, g.expires_at
FROM entitlement_grants g
WHERE g.account_id = @account_id
  AND g.source = 'ad_free_pass'
  AND g.revoked_at IS NULL
  AND g.expires_at > @now::timestamptz
ORDER BY g.entitlement, g.starts_at, g.id;

-- name: EndGrantAt :exec
-- 사용 중 구간을 지금에서 끝냅니다(합치기로 옮긴 B 구간). 취소된 구간은 바꾸지 않습니다.
UPDATE entitlement_grants
SET expires_at = @now::timestamptz
WHERE id = @id
  AND account_id = @account_id
  AND revoked_at IS NULL;

-- name: MovePurchasesOwner :exec
-- 계정이 주인인 구매를 모두 받는 계정으로 옮기고 합친 시각을 적습니다. 처음 산 계정(original_account_id)은 그대로입니다.
UPDATE purchases
SET account_id = @to_account_id,
    merged_at = @now::timestamptz
WHERE account_id = @from_account_id;

-- name: LockActiveAccountForTestGrant :one
-- staging 테스트 광고 제거 기간(S125)을 다룰 계정의 상태입니다. 행이 없으면 없는 계정입니다.
-- FOR SHARE로 잡아 계정 삭제(FOR UPDATE)와 직렬화하므로, 지우는 중인 계정에 기간이 남지 않습니다.
SELECT (status = 'active')::boolean AS active FROM accounts WHERE id = @account_id FOR SHARE;

-- name: InsertTestGrant :exec
-- staging 테스트 광고 제거 기간 한 행입니다(S125). source_ref는 부여마다 새로 만든 id입니다.
INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
VALUES (@account_id, @entitlement, 'test_grant', @source_ref, @starts_at, @expires_at);

-- name: RevokeTestGrants :execrows
-- 계정의 끝나지 않은 테스트 광고 제거 기간을 지금 끊습니다(S125).
UPDATE entitlement_grants
SET revoked_at = @now::timestamptz
WHERE account_id = @account_id
  AND source = 'test_grant'
  AND revoked_at IS NULL
  AND expires_at > @now::timestamptz;

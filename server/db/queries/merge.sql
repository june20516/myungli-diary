-- 계정 합치기(S110·S111)의 쿼리입니다. A는 지금 로그인한 유저 계정, B는 합쳐져 지워지는 유저 계정입니다.

-- LockActiveIdentityAccount는 합치기 증명으로 찾은 인증 계정과 그 유저 계정이 아직 있고 active인지 확인하고,
-- 합치기 토큰을 넣는 동안 두 행이 지워지지 않게 공유 잠금을 잡습니다. 그 사이 떼거나 지웠으면 행이 없습니다.
-- name: LockActiveIdentityAccount :one
SELECT i.account_id
FROM auth_identities i
JOIN accounts a ON a.id = i.account_id
WHERE i.id = @identity_id AND a.status = 'active'
FOR SHARE OF i, a;

-- InsertMergeTicket은 합치기 토큰의 해시를 저장합니다. 원문은 저장하지 않습니다.
-- name: InsertMergeTicket :exec
INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
VALUES (@id, @token_hash, @account_id, @other_account_id, @identity_id, @expires_at::timestamptz);

-- CountMovableRecords는 B에서 A로 옮길 기록 수를 셉니다(spec §6.2).
-- 일기·일정은 지운 것을 포함합니다. 날짜 기록은 A와 날짜가 겹치지 않는 것만 date_records로 세고, 겹친 날은 overlap_days로 셉니다.
-- 반응은 B의 문장 선택 기록에 붙은 살아 있는 반응입니다.
-- name: CountMovableRecords :one
SELECT
    (SELECT count(*) FROM diaries d WHERE d.account_id = @other_account_id)::bigint AS diaries,
    (SELECT count(*) FROM schedules s WHERE s.account_id = @other_account_id)::bigint AS schedules,
    (SELECT count(*) FROM diary_days b
        WHERE b.account_id = @other_account_id
          AND NOT EXISTS (SELECT 1 FROM diary_days a WHERE a.account_id = @account_id AND a.date = b.date))::bigint AS date_records,
    (SELECT count(*) FROM diary_days b
        WHERE b.account_id = @other_account_id
          AND EXISTS (SELECT 1 FROM diary_days a WHERE a.account_id = @account_id AND a.date = b.date))::bigint AS overlap_days,
    (SELECT count(*) FROM reactions r
        JOIN daily_selections ds ON ds.id = r.selection_id
        WHERE ds.account_id = @other_account_id AND r.deleted_at IS NULL)::bigint AS reactions;

-- ListRemainingPassGrants는 계정의 기간 상품 사용 구간 중 아직 끝나지 않은 것을 돌려줍니다(남은 날 계산).
-- 끊긴 구간(revoked_at)과 보상형 광고 구간은 옮기지 않으므로 뺍니다.
-- name: ListRemainingPassGrants :many
SELECT entitlement, starts_at, expires_at
FROM entitlement_grants
WHERE account_id = @account_id
  AND source = 'ad_free_pass'
  AND revoked_at IS NULL
  AND expires_at > @now::timestamptz
ORDER BY entitlement, starts_at;

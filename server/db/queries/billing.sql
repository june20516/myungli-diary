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

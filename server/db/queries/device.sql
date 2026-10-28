-- 알림 기기 쿼리입니다(S92, S119).

-- name: UpsertDevice :one
-- 토큰이 이미 있으면 같은 행을 요청한 계정의 활성 기기로 되살립니다. inserted는 새 행일 때만 true입니다.
INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at)
VALUES (@id, @account_id, @fcm_token, @token_hash, @platform, true, @seen_at)
ON CONFLICT (token_hash) DO UPDATE
SET account_id = EXCLUDED.account_id, platform = EXCLUDED.platform, active = true, last_seen_at = EXCLUDED.last_seen_at
RETURNING id, platform, (xmax = 0)::boolean AS inserted;

-- name: DeactivateOverflowDevices :execrows
-- 계정의 활성 기기를 최근 순으로 세워 max_active대 뒤를 비활성으로 바꿉니다.
-- 바깥 조건에도 주인과 활성을 다시 적습니다. 고른 행을 다른 계정이 동시에 옮겨 가면, 그 커밋을 기다린 뒤
-- 바뀐 행으로 조건을 다시 보는데 subquery 결과(id)만으로는 옮겨 간 기기까지 꺼 버리기 때문입니다.
UPDATE devices SET active = false
WHERE devices.account_id = @account_id AND devices.active AND devices.id IN (
    SELECT d.id FROM devices AS d
    WHERE d.account_id = @account_id AND d.active
    ORDER BY d.last_seen_at DESC, d.id DESC
    OFFSET @max_active
);

-- name: DeactivateDevice :execrows
-- 자기 기기면 이미 비활성이어도 1행입니다. 없거나 남의 기기면 0행입니다.
UPDATE devices SET active = false
WHERE id = @id AND account_id = @account_id;

-- 알림 기기 쿼리입니다(S92, S119).

-- name: UpsertDevice :one
-- 토큰이 이미 있으면 같은 행을 요청한 계정의 활성 기기로 되살립니다. inserted는 새 행일 때만 true입니다.
INSERT INTO devices (id, account_id, fcm_token, platform, active, last_seen_at)
VALUES (@id, @account_id, @fcm_token, @platform, true, @seen_at)
ON CONFLICT (fcm_token) DO UPDATE
SET account_id = EXCLUDED.account_id, platform = EXCLUDED.platform, active = true, last_seen_at = EXCLUDED.last_seen_at
RETURNING id, platform, (xmax = 0)::boolean AS inserted;

-- name: DeactivateOverflowDevices :execrows
-- 계정의 활성 기기를 최근 순으로 세워 max_active대 뒤를 비활성으로 바꿉니다.
UPDATE devices SET active = false
WHERE devices.id IN (
    SELECT d.id FROM devices AS d
    WHERE d.account_id = @account_id AND d.active
    ORDER BY d.last_seen_at DESC, d.id DESC
    OFFSET @max_active
);

-- name: DeactivateDevice :execrows
-- 자기 기기면 이미 비활성이어도 1행입니다. 없거나 남의 기기면 0행입니다.
UPDATE devices SET active = false
WHERE id = @id AND account_id = @account_id;

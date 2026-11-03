-- name: ClaimNotification :execrows
-- 그 (계정, 현지 날짜)에 처음이면 pending 행을 넣습니다. stale_before 전에 claim된 채 pending으로 남은 행
-- (Job이 죽음)은 다시 가져옵니다. 그 밖에 행이 있으면 0행입니다(S129).
INSERT INTO notification_log (account_id, local_date, result, claimed_at)
VALUES (@account_id, @local_date, 'pending', @claimed_at)
ON CONFLICT (account_id, local_date) DO UPDATE SET claimed_at = EXCLUDED.claimed_at
WHERE notification_log.result = 'pending' AND notification_log.claimed_at < @stale_before::timestamptz;

-- name: ReleaseNotification :exec
-- 보내지 못한 pending 행을 지워 창 안의 다음 실행이 다시 보내게 합니다(S129).
DELETE FROM notification_log
WHERE account_id = @account_id AND local_date = @local_date AND result = 'pending';

-- name: FinishNotification :exec
UPDATE notification_log
SET result = @result, sent_at = CASE WHEN @result::text = 'sent' THEN @finished_at::timestamptz END
WHERE account_id = @account_id AND local_date = @local_date;

-- name: ListActiveDevices :many
SELECT id, fcm_token, platform FROM devices
WHERE account_id = @account_id AND active
ORDER BY last_seen_at DESC;

-- name: DeactivateDeviceByID :exec
-- FCM이 토큰이 무효라고 답한 기기를 비활성으로 바꿉니다(S92).
UPDATE devices SET active = false WHERE id = @id;

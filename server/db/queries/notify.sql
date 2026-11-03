-- name: ClaimNotification :execrows
-- 그 (계정, 현지 날짜)에 처음이면 pending 행을 넣습니다. 이미 있으면 0행입니다.
INSERT INTO notification_log (account_id, local_date, result, claimed_at)
VALUES (@account_id, @local_date, 'pending', @claimed_at)
ON CONFLICT (account_id, local_date) DO NOTHING;

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

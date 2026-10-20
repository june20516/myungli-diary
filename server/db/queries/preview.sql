-- 비로그인 미리보기 1회 기록 쿼리입니다. 이 표는 시스템 데이터라 행을 물리적으로 지웁니다.

-- name: ClaimPreviewUsage :execrows
-- 설치를 선점합니다. 이미 있으면 아무것도 바꾸지 않아 영향 행이 0입니다.
INSERT INTO preview_usage (device_hash)
VALUES (@device_hash)
ON CONFLICT (device_hash) DO NOTHING;

-- name: ReleasePreviewUsage :exec
DELETE FROM preview_usage WHERE device_hash = @device_hash;

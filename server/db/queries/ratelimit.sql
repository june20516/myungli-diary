-- 요청 한도 쿼리입니다. 이 표는 시스템 데이터라 행을 물리적으로 지웁니다.

-- name: IncrementRateLimit :one
-- 키의 창 요청 수를 하나 올리고 올린 뒤의 값을 돌려줍니다. 한 문장이라 동시 요청도 각자 다른 값을 받습니다.
INSERT INTO rate_limits (key, window_start, count)
VALUES (@key, @window_start, 1)
ON CONFLICT (key, window_start) DO UPDATE SET count = rate_limits.count + 1
RETURNING count;

-- 엔진 응답 캐시입니다. 없으면 pgx.ErrNoRows를 돌려줍니다.
-- Put은 같은 키가 이미 있으면 아무것도 하지 않으므로(먼저 쓴 값 유지) 겹친 요청이 서로 실패시키지 않습니다.

-- name: GetChart :one
SELECT response FROM chart_cache
WHERE birth_hash = @birth_hash AND ruleset_version = @ruleset_version AND as_of_year = @as_of_year;

-- name: PutChart :exec
INSERT INTO chart_cache (birth_hash, ruleset_version, as_of_year, response)
VALUES (@birth_hash, @ruleset_version, @as_of_year, @response)
ON CONFLICT DO NOTHING;

-- name: GetDaily :one
SELECT response FROM daily_cache
WHERE birth_hash = @birth_hash AND ruleset_version = @ruleset_version
  AND date = @date AND current_timezone = @current_timezone;

-- name: PutDaily :exec
INSERT INTO daily_cache (birth_hash, ruleset_version, date, current_timezone, response)
VALUES (@birth_hash, @ruleset_version, @date, @current_timezone, @response)
ON CONFLICT DO NOTHING;

-- name: GetMonth :one
SELECT response FROM month_cache
WHERE birth_hash = @birth_hash AND ruleset_version = @ruleset_version
  AND year = @year AND month = @month AND current_timezone = @current_timezone;

-- name: PutMonth :exec
INSERT INTO month_cache (birth_hash, ruleset_version, year, month, current_timezone, response)
VALUES (@birth_hash, @ruleset_version, @year, @month, @current_timezone, @response)
ON CONFLICT DO NOTHING;

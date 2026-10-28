-- job retention의 정리 쿼리입니다(spec §8.3, S113, S119, S120). 기준 시각은 모두 호출하는 쪽이 계산해 넘깁니다.

-- name: DeleteChartCacheBefore :execrows
DELETE FROM chart_cache WHERE created_at < @cutoff;

-- name: DeleteDailyCacheBefore :execrows
DELETE FROM daily_cache WHERE created_at < @cutoff;

-- name: DeleteMonthCacheBefore :execrows
DELETE FROM month_cache WHERE created_at < @cutoff;

-- name: DeleteChartCacheOtherVersions :execrows
DELETE FROM chart_cache WHERE ruleset_version <> @current;

-- name: DeleteDailyCacheOtherVersions :execrows
DELETE FROM daily_cache WHERE ruleset_version <> @current;

-- name: DeleteMonthCacheOtherVersions :execrows
DELETE FROM month_cache WHERE ruleset_version <> @current;

-- name: DeleteIdempotencyKeysBefore :execrows
DELETE FROM idempotency_keys WHERE created_at < @cutoff;

-- name: DeleteEndedRateLimits :execrows
-- 창 길이가 지난 창, 곧 window_start가 now − 창 길이 이하인 행을 지웁니다.
DELETE FROM rate_limits WHERE window_start <= @last_ended_start;

-- 만료된 refresh token을 지웁니다. 회전 사슬(replaced_by_id, RESTRICT)에서 아직 살아 있는 토큰이 가리키는 행은 남깁니다.
-- 회전한 토큰은 뒤 토큰이 늦게 만료되므로 보통 사슬째 함께 지워지고, 이 조건은 TTL을 줄인 배포 뒤의 뒤집힌 사슬을 위한 것입니다.
-- name: DeleteExpiredRefreshTokens :execrows
DELETE FROM refresh_tokens AS t
WHERE t.expires_at < @now
  AND NOT EXISTS (
      SELECT 1 FROM refresh_tokens AS r
      WHERE r.replaced_by_id = t.id AND r.expires_at >= @now
  );

-- name: DeleteMergeTicketsExpiredBefore :execrows
DELETE FROM account_merge_tickets WHERE expires_at < @cutoff;

-- name: DeleteInactiveDevicesSeenBefore :execrows
DELETE FROM devices WHERE NOT active AND last_seen_at < @cutoff;

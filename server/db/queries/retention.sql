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

-- name: DeletePreviewUsageBefore :execrows
DELETE FROM preview_usage WHERE used_at < @cutoff;

-- name: DeleteRewardEventsBefore :execrows
DELETE FROM reward_events WHERE received_at < @cutoff;

-- 보상형 광고 구간은 보상 기록이라 1년 기준이고, 끝난 시각으로 셉니다.
-- name: DeleteRewardGrantsEndedBefore :execrows
DELETE FROM entitlement_grants WHERE source = 'rewarded_ad' AND expires_at < @cutoff;

-- name: DeleteBillingEventsBefore :execrows
DELETE FROM billing_events WHERE received_at < @cutoff;

-- 결제 구간은 끝난 시각이 기준보다 앞일 때 지웁니다. 끝난 구간은 rechain이 건너뛰므로 최근 구간에 영향이 없습니다.
-- name: DeletePaidGrantsEndedBefore :execrows
DELETE FROM entitlement_grants WHERE source IN ('ad_free_pass', 'subscription') AND expires_at < @cutoff;

-- 구매는 결제일이 기준보다 앞이고 그 구매의 구간이 남아 있지 않을 때 지웁니다(구간을 먼저 지운 뒤 부릅니다).
-- 앞 구간 끝에 이어 붙어 늦게 끝난 구매는 구간과 함께 남습니다.
-- name: DeletePurchasesBefore :execrows
DELETE FROM purchases AS p
WHERE p.purchased_at < @cutoff
  AND NOT EXISTS (
      SELECT 1 FROM entitlement_grants AS g
      WHERE g.source IN ('ad_free_pass', 'subscription') AND g.source_ref = p.id
  );

-- 복구 기간이 지난 지운 일기의 본문을 비웁니다(S6). 가이드 질문과 태그는 날짜 기록(diary_days)에 남깁니다(S95).
-- name: PurgeDeletedDiaries :execrows
UPDATE diaries SET body = '', content_purged_at = @now::timestamptz
WHERE deleted_at < @cutoff::timestamptz AND content_purged_at IS NULL;

-- name: PurgeDeletedSchedules :execrows
UPDATE schedules SET title = '', memo = NULL, content_purged_at = @now::timestamptz
WHERE deleted_at < @cutoff::timestamptz AND content_purged_at IS NULL;

-- 만료 + 1일 지난 Apple 웹 로그인 중 app이 오지 않아 쓰이지 않았고 그 subject의 연결 행도 없는 행의
-- Apple refresh token을 허가 취소 대기 행으로 넘깁니다(S19, apple web callback spec §2.5).
-- 토큰은 웹 로그인 행 id를 aad로 암호화했고 재시도는 identity_id를 aad로 여므로 identity_id에 그 id를 넣습니다.
-- name: QueueUnclaimedAppleWebLoginRevocations :execrows
INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at)
SELECT 'apple', w.subject, w.id, w.apple_refresh_token, w.apple_token_key_id, w.apple_client_id, @now::timestamptz
FROM apple_web_logins AS w
WHERE w.expires_at < @cutoff::timestamptz
  AND w.consumed_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth_identities AS i WHERE i.provider = 'apple' AND i.subject = w.subject
  );

-- name: DeleteAppleWebLoginsExpiredBefore :execrows
DELETE FROM apple_web_logins WHERE expires_at < @cutoff;

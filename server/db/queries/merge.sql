-- 계정 합치기(S110·S111)의 쿼리입니다. A는 지금 로그인한 유저 계정, B는 합쳐져 지워지는 유저 계정입니다.

-- LockActiveIdentityAccount는 합치기 증명으로 찾은 인증 계정과 그 유저 계정이 아직 있고 active인지 확인하고,
-- 합치기 토큰을 넣는 동안 두 행이 지워지지 않게 공유 잠금을 잡습니다. 그 사이 떼거나 지웠으면 행이 없습니다.
-- name: LockActiveIdentityAccount :one
SELECT i.account_id
FROM auth_identities i
JOIN accounts a ON a.id = i.account_id
WHERE i.id = @identity_id AND a.status = 'active'
FOR SHARE OF i, a;

-- InsertMergeTicket은 합치기 토큰의 해시를 저장합니다. 원문은 저장하지 않습니다.
-- name: InsertMergeTicket :exec
INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
VALUES (@id, @token_hash, @account_id, @other_account_id, @identity_id, @expires_at::timestamptz);

-- CountMovableRecords는 B에서 A로 옮길 기록 수를 셉니다(spec §6.2).
-- 일기·일정은 지운 것을 포함합니다. 날짜 기록은 A와 날짜가 겹치지 않는 것만 date_records로 세고, 겹친 날은 overlap_days로 셉니다.
-- 반응은 B의 문장 선택 기록에 붙은 살아 있는 반응입니다.
-- name: CountMovableRecords :one
SELECT
    (SELECT count(*) FROM diaries d WHERE d.account_id = @other_account_id)::bigint AS diaries,
    (SELECT count(*) FROM schedules s WHERE s.account_id = @other_account_id)::bigint AS schedules,
    (SELECT count(*) FROM diary_days b
        WHERE b.account_id = @other_account_id
          AND NOT EXISTS (SELECT 1 FROM diary_days a WHERE a.account_id = @account_id AND a.date = b.date))::bigint AS date_records,
    (SELECT count(*) FROM diary_days b
        WHERE b.account_id = @other_account_id
          AND EXISTS (SELECT 1 FROM diary_days a WHERE a.account_id = @account_id AND a.date = b.date))::bigint AS overlap_days,
    (SELECT count(*) FROM reactions r
        JOIN daily_selections ds ON ds.id = r.selection_id
        WHERE ds.account_id = @other_account_id AND r.deleted_at IS NULL)::bigint AS reactions;

-- ListRemainingPassGrants는 계정의 기간 상품 사용 구간 중 아직 끝나지 않은 것을 돌려줍니다(남은 날 계산).
-- 끊긴 구간(revoked_at)과 보상형 광고 구간은 옮기지 않으므로 뺍니다.
-- name: ListRemainingPassGrants :many
SELECT entitlement, starts_at, expires_at
FROM entitlement_grants
WHERE account_id = @account_id
  AND source = 'ad_free_pass'
  AND revoked_at IS NULL
  AND expires_at > @now::timestamptz
ORDER BY entitlement, starts_at;

-- 아래는 합치기 실행(Execute, S111)의 쿼리입니다. 모두 한 트랜잭션에서 A·B 계정 행을 FOR UPDATE로 잡은 뒤 부릅니다.

-- MergeTicketAccounts는 토큰 해시로 합치기 토큰의 A·B를 찾습니다. 잠그기 전에 잠글 계정을 정하려고 읽으며, 확인은 LockMergeTicket이 합니다.
-- name: MergeTicketAccounts :one
SELECT account_id, other_account_id
FROM account_merge_tickets
WHERE token_hash = @token_hash;

-- LockMergeAccounts는 A·B 계정 행을 id 순서로 잠그고 상태를 돌려줍니다. 정렬 뒤에 잠그므로 두 합치기가 같은 순서로 잡습니다.
-- name: LockMergeAccounts :many
SELECT id, status
FROM accounts
WHERE id = ANY(@ids::uuid[])
ORDER BY id
FOR UPDATE;

-- LockMergeTicket은 A·B에 묶인 합치기 토큰 행을 잠급니다. 그 사이 B 삭제·인증 계정 떼기로 지워졌으면 행이 없습니다.
-- name: LockMergeTicket :one
SELECT id, identity_id, expires_at, consumed_at
FROM account_merge_tickets
WHERE token_hash = @token_hash
  AND account_id = @account_id
  AND other_account_id = @other_account_id
FOR UPDATE;

-- IdentityLinkedTo는 인증 계정이 아직 그 유저 계정에 연결돼 있는지 알려 줍니다.
-- name: IdentityLinkedTo :one
SELECT EXISTS (SELECT 1 FROM auth_identities WHERE id = @identity_id AND account_id = @account_id)::boolean AS linked;

-- name: ConsumeMergeTicket :exec
UPDATE account_merge_tickets
SET consumed_at = @now::timestamptz
WHERE id = @id;

-- KeepOtherDiaryDays는 두 계정 모두 날짜 기록이 있는 날에 B의 날짜 기록 값으로 A 행을 바꿉니다(profile = other).
-- 일기가 (account_id, date)로 날짜 기록을 가리키므로(diaries_day_fk) A 행을 남긴 채 값만 바꿉니다.
-- name: KeepOtherDiaryDays :exec
UPDATE diary_days a
SET all_tags = b.all_tags,
    featured_tags = b.featured_tags,
    guide_question = b.guide_question,
    ruleset_version = b.ruleset_version,
    created_at = b.created_at
FROM diary_days b
WHERE a.account_id = @account_id
  AND b.account_id = @other_account_id
  AND a.date = b.date;

-- CopyOtherOnlyDiaryDays는 B에만 있는 날짜 기록을 A에 만듭니다. B 행은 B 삭제가 지웁니다.
-- name: CopyOtherOnlyDiaryDays :exec
INSERT INTO diary_days (account_id, date, all_tags, featured_tags, guide_question, ruleset_version, created_at)
SELECT @account_id, b.date, b.all_tags, b.featured_tags, b.guide_question, b.ruleset_version, b.created_at
FROM diary_days b
WHERE b.account_id = @other_account_id
  AND NOT EXISTS (SELECT 1 FROM diary_days a WHERE a.account_id = @account_id AND a.date = b.date);

-- MoveDiaries는 B의 일기를 지운 것까지 모두 A로 옮깁니다. 하루 10편 상한은 검사하지 않습니다(D83 ④).
-- updated_at은 trigger가 옮긴 시각으로 바꿉니다.
-- name: MoveDiaries :exec
UPDATE diaries SET account_id = @account_id WHERE account_id = @other_account_id;

-- name: MoveSchedules :exec
UPDATE schedules SET account_id = @account_id WHERE account_id = @other_account_id;

-- 겹친 문장 선택 기록은 같은 (date, slot, birth_hash)가 두 계정에 모두 있는 것입니다. birth_hash가 NULL인 행은 unique에서
-- 서로 다른 값이라 겹치지 않습니다. loser는 지울 쪽, winner는 남길 쪽(고른 프로필 쪽) 계정입니다.

-- TallyOverlappingReactions는 지울 쪽 겹친 선택에 붙은 살아 있는 반응을 문장별 집계에 더합니다(D57).
-- name: TallyOverlappingReactions :exec
INSERT INTO reaction_tallies (message_key, variant, reaction, count)
SELECT s.message_key, s.variant, r.reaction, count(*)
FROM reactions r
JOIN daily_selections s ON s.id = r.selection_id
WHERE s.account_id = @loser_account_id
  AND r.deleted_at IS NULL
  AND EXISTS (
      SELECT 1 FROM daily_selections w
      WHERE w.account_id = @winner_account_id AND w.date = s.date AND w.slot = s.slot AND w.birth_hash = s.birth_hash
  )
GROUP BY s.message_key, s.variant, r.reaction
-- 계정 삭제의 TallyReactions와 같은 순서로 집계 행을 잠가 deadlock을 막습니다.
ORDER BY s.message_key, s.variant, r.reaction
ON CONFLICT (message_key, variant, reaction) DO UPDATE
SET count = reaction_tallies.count + EXCLUDED.count;

-- DeleteOverlappingReactions는 지울 쪽 겹친 선택의 반응(취소 이력 포함)을 지웁니다.
-- name: DeleteOverlappingReactions :exec
DELETE FROM reactions
WHERE selection_id IN (
    SELECT s.id FROM daily_selections s
    WHERE s.account_id = @loser_account_id
      AND EXISTS (
          SELECT 1 FROM daily_selections w
          WHERE w.account_id = @winner_account_id AND w.date = s.date AND w.slot = s.slot AND w.birth_hash = s.birth_hash
      )
);

-- name: DeleteOverlappingSelections :exec
DELETE FROM daily_selections s
WHERE s.account_id = @loser_account_id
  AND EXISTS (
      SELECT 1 FROM daily_selections w
      WHERE w.account_id = @winner_account_id AND w.date = s.date AND w.slot = s.slot AND w.birth_hash = s.birth_hash
  );

-- MoveSelections는 남은 B 문장 선택 기록을 A로 옮깁니다. 반응은 selection_id로 따라갑니다.
-- name: MoveSelections :exec
UPDATE daily_selections SET account_id = @account_id WHERE account_id = @other_account_id;

-- ReplaceProfileWithOther는 B의 프로필(사주 정보·호칭·설정)로 A의 프로필을 바꾸고, A에 없으면 만듭니다(profile = other).
-- B에 프로필이 없으면 0행입니다.
-- name: ReplaceProfileWithOther :execrows
INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
                      birth_year, birth_month, birth_day, birth_time_status, birth_time, gender, birth_timezone,
                      birth_place_status, birth_city_id, longitude, notify_status, notify_time, birth_hash, updated_at)
SELECT @account_id, b.honorific, b.language, b.current_timezone, b.calendar, b.is_leap_month,
       b.birth_year, b.birth_month, b.birth_day, b.birth_time_status, b.birth_time, b.gender, b.birth_timezone,
       b.birth_place_status, b.birth_city_id, b.longitude, b.notify_status, b.notify_time, b.birth_hash, @now::timestamptz
FROM profiles b
WHERE b.account_id = @other_account_id
ON CONFLICT (account_id) DO UPDATE
SET honorific = EXCLUDED.honorific,
    language = EXCLUDED.language,
    current_timezone = EXCLUDED.current_timezone,
    calendar = EXCLUDED.calendar,
    is_leap_month = EXCLUDED.is_leap_month,
    birth_year = EXCLUDED.birth_year,
    birth_month = EXCLUDED.birth_month,
    birth_day = EXCLUDED.birth_day,
    birth_time_status = EXCLUDED.birth_time_status,
    birth_time = EXCLUDED.birth_time,
    gender = EXCLUDED.gender,
    birth_timezone = EXCLUDED.birth_timezone,
    birth_place_status = EXCLUDED.birth_place_status,
    birth_city_id = EXCLUDED.birth_city_id,
    longitude = EXCLUDED.longitude,
    notify_status = EXCLUDED.notify_status,
    notify_time = EXCLUDED.notify_time,
    birth_hash = EXCLUDED.birth_hash,
    updated_at = EXCLUDED.updated_at;

-- name: DeleteProfile :exec
DELETE FROM profiles WHERE account_id = @account_id;

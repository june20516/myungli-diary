-- name: GetProfile :one
SELECT * FROM profiles
WHERE account_id = @account_id;

-- name: ProfileExists :one
SELECT EXISTS (SELECT 1 FROM profiles WHERE account_id = @account_id);

-- UpsertProfile은 프로필을 만들거나 통째로 바꿉니다.
-- 동시에 첫 등록이 두 번 들어와도 둘 다 성공하며, 나중에 실행된 값이 남습니다.
-- anonymized_at은 다루지 않으므로 일반 저장이 익명화를 되돌리거나 만들지 못합니다.
-- name: UpsertProfile :one
INSERT INTO profiles (
    account_id, honorific, language, current_timezone,
    calendar, is_leap_month, birth_year, birth_month, birth_day,
    birth_time_status, birth_time, gender, birth_timezone,
    birth_place_status, birth_city_id, longitude,
    notify_status, notify_time, birth_hash
) VALUES (
    @account_id, @honorific, @language, @current_timezone,
    @calendar, @is_leap_month, @birth_year, @birth_month, @birth_day,
    @birth_time_status, @birth_time, @gender, @birth_timezone,
    @birth_place_status, @birth_city_id, @longitude,
    @notify_status, @notify_time, @birth_hash
)
ON CONFLICT (account_id) DO UPDATE SET
    honorific          = EXCLUDED.honorific,
    language           = EXCLUDED.language,
    current_timezone   = EXCLUDED.current_timezone,
    calendar           = EXCLUDED.calendar,
    is_leap_month      = EXCLUDED.is_leap_month,
    birth_year         = EXCLUDED.birth_year,
    birth_month        = EXCLUDED.birth_month,
    birth_day          = EXCLUDED.birth_day,
    birth_time_status  = EXCLUDED.birth_time_status,
    birth_time         = EXCLUDED.birth_time,
    gender             = EXCLUDED.gender,
    birth_timezone     = EXCLUDED.birth_timezone,
    birth_place_status = EXCLUDED.birth_place_status,
    birth_city_id      = EXCLUDED.birth_city_id,
    longitude          = EXCLUDED.longitude,
    notify_status      = EXCLUDED.notify_status,
    notify_time        = EXCLUDED.notify_time,
    birth_hash         = EXCLUDED.birth_hash
RETURNING *;

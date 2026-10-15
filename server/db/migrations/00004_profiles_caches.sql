-- +goose Up
-- 사용자 프로필과 엔진 응답 캐시 테이블입니다.
-- 출생 정보는 계정 삭제 익명화 때 지워지므로(anonymized_at) 출생 열과 honorific, birth_hash는 NULL을 허용하고,
-- 익명화 전(anonymized_at IS NULL)에는 모두 있어야 한다는 것을 CHECK로 지킵니다.
-- 음력 30일이 date에 들어가지 않으므로 출생 날짜는 정수 셋(year, month, day)으로 둡니다.

CREATE TABLE profiles (
    account_id         uuid PRIMARY KEY REFERENCES accounts (id) ON DELETE RESTRICT,
    honorific          text,
    language           text        NOT NULL CHECK (language IN ('ko', 'en', 'ja')),
    current_timezone   text        NOT NULL,
    calendar           text CHECK (calendar IN ('solar', 'lunar')),
    is_leap_month      boolean,
    birth_year         smallint CONSTRAINT profiles_birth_year_range CHECK (birth_year BETWEEN 1900 AND 2099),
    birth_month        smallint CONSTRAINT profiles_birth_month_range CHECK (birth_month BETWEEN 1 AND 12),
    birth_day          smallint CONSTRAINT profiles_birth_day_range CHECK (birth_day BETWEEN 1 AND 31),
    birth_time_status  text CHECK (birth_time_status IN ('known', 'unknown')),
    birth_time         time,
    gender             text CHECK (gender IN ('male', 'female')),
    birth_timezone     text,
    birth_place_status text CHECK (birth_place_status IN ('not_asked', 'skipped', 'city')),
    birth_city_id      text,
    longitude          double precision,
    notify_status      text        NOT NULL CHECK (notify_status IN ('not_asked', 'enabled', 'disabled')),
    notify_time        time,
    -- 출생 정보의 SHA-256입니다. 엔진 결과 캐시의 키로 씁니다.
    birth_hash         bytea CONSTRAINT profiles_birth_hash_length CHECK (octet_length(birth_hash) = 32),
    anonymized_at      timestamptz,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    -- 출생 시각 상태와 값의 짝입니다.
    CONSTRAINT profiles_birth_time_status_value CHECK (
        (birth_time_status IS NOT DISTINCT FROM 'known') = (birth_time IS NOT NULL)
    ),
    -- 출생지가 도시일 때만 도시 id와 경도가 있고, 둘은 함께 있습니다.
    CONSTRAINT profiles_birth_place_status_value CHECK (
        (birth_place_status IS NOT DISTINCT FROM 'city') = (birth_city_id IS NOT NULL)
        AND (birth_place_status IS NOT DISTINCT FROM 'city') = (longitude IS NOT NULL)
    ),
    -- 양력에는 윤달이 없습니다.
    CONSTRAINT profiles_solar_not_leap CHECK (
        calendar IS DISTINCT FROM 'solar' OR is_leap_month IS NOT TRUE
    ),
    -- 알림 시각은 알림이 켜졌을 때만 있고, 5분 단위입니다.
    CONSTRAINT profiles_notify_status_time CHECK (
        (notify_status = 'enabled') = (notify_time IS NOT NULL)
    ),
    CONSTRAINT profiles_notify_time_step CHECK (
        notify_time IS NULL
        OR (extract(minute FROM notify_time)::int % 5 = 0 AND extract(second FROM notify_time) = 0)
    ),
    -- 익명화 전에는 출생 정보 전체와 호칭, 출생 해시가 모두 있습니다.
    CONSTRAINT profiles_complete_until_anonymized CHECK (
        anonymized_at IS NOT NULL
        OR (honorific IS NOT NULL AND calendar IS NOT NULL AND is_leap_month IS NOT NULL
            AND birth_year IS NOT NULL AND birth_month IS NOT NULL AND birth_day IS NOT NULL
            AND birth_time_status IS NOT NULL AND gender IS NOT NULL AND birth_timezone IS NOT NULL
            AND birth_place_status IS NOT NULL AND birth_hash IS NOT NULL)
    )
);

CREATE TRIGGER profiles_set_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 엔진 응답 캐시입니다. 시스템 데이터라 created_at을 DB 기본값으로 둡니다.
-- 계정과 이어지지 않고 출생 해시로만 찾으므로 계정 FK가 없습니다.
CREATE TABLE chart_cache (
    birth_hash      bytea       NOT NULL CONSTRAINT chart_cache_birth_hash_length CHECK (octet_length(birth_hash) = 32),
    ruleset_version text        NOT NULL,
    as_of_year      int         NOT NULL,
    response        bytea       NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (birth_hash, ruleset_version, as_of_year)
);

CREATE TABLE daily_cache (
    birth_hash       bytea       NOT NULL CONSTRAINT daily_cache_birth_hash_length CHECK (octet_length(birth_hash) = 32),
    ruleset_version  text        NOT NULL,
    date             date        NOT NULL,
    current_timezone text        NOT NULL,
    response         bytea       NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (birth_hash, ruleset_version, date, current_timezone)
);

CREATE TABLE month_cache (
    birth_hash       bytea       NOT NULL CONSTRAINT month_cache_birth_hash_length CHECK (octet_length(birth_hash) = 32),
    ruleset_version  text        NOT NULL,
    year             int         NOT NULL,
    month            int         NOT NULL,
    current_timezone text        NOT NULL,
    response         bytea       NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (birth_hash, ruleset_version, year, month, current_timezone)
);

-- +goose Down
DROP TABLE month_cache;
DROP TABLE daily_cache;
DROP TABLE chart_cache;
DROP TABLE profiles;

-- +goose Up
-- 일정 테이블입니다. 지울 때는 deleted_at만 채웁니다(행을 물리적으로 지우지 않으므로 FK는 ON DELETE RESTRICT입니다).
-- 하루에 여러 건이 있을 수 있어 날짜에 unique를 걸지 않습니다.
-- time은 all_day가 false일 때만 있고(분 단위 벽시계 시각), memo는 빈 문자열 대신 NULL로 둡니다.
-- title·memo를 지우는 일(content_purged_at)은 계정 익명화 작업(P8)이 하며, 여기서는 열만 둡니다.
CREATE TABLE schedules (
    id                uuid        PRIMARY KEY,
    account_id        uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    date              date        NOT NULL,
    all_day           boolean     NOT NULL,
    time              time,
    title             text        NOT NULL,
    memo              text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    deleted_at        timestamptz,
    content_purged_at timestamptz,
    CONSTRAINT schedules_time_by_all_day CHECK ((all_day AND time IS NULL) OR (NOT all_day AND time IS NOT NULL))
);

-- 기간 목록용입니다.
CREATE INDEX schedules_account_date ON schedules (account_id, date) WHERE deleted_at IS NULL;

CREATE TRIGGER schedules_set_updated_at BEFORE UPDATE ON schedules
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE schedules;

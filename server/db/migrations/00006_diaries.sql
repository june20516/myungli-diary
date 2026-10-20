-- +goose Up
-- 일기 테이블입니다. 하루 1편이고, 지울 때는 deleted_at만 채웁니다(행을 물리적으로 지우지 않으므로 FK는 ON DELETE RESTRICT입니다).
-- 지운 일기는 같은 날짜에 여러 편 남을 수 있어서 unique는 살아 있는 행에만 겁니다.
-- all_tags·featured_tags·ruleset_version·guide_question은 처음 쓸 때 본 그날 엔진 결과와 질문의 기록이라, 본문을 고쳐도 바뀌지 않습니다.
-- featured_tags는 [{"key","polarity"}], guide_question은 [{"text","term"}](term은 없으면 생략)이고, 질문이 없으면 NULL입니다.
-- content_purged_at은 계정 익명화 때 본문을 지운 시각이며, 채우는 일은 익명화 작업(P8)이 합니다.
CREATE TABLE diaries (
    id                uuid        PRIMARY KEY,
    account_id        uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    date              date        NOT NULL,
    body              text        NOT NULL,
    all_tags          text[]      NOT NULL,
    featured_tags     jsonb       NOT NULL,
    guide_question    jsonb,
    ruleset_version   text        NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    deleted_at        timestamptz,
    content_purged_at timestamptz
);

CREATE UNIQUE INDEX diaries_one_per_day ON diaries (account_id, date) WHERE deleted_at IS NULL;

-- 태그로 거르는 목록용입니다.
CREATE INDEX diaries_all_tags ON diaries USING gin (all_tags);

-- 날짜 역순 목록용 인덱스는 따로 두지 않습니다. 위 diaries_one_per_day가 같은 열·조건이라 역방향 스캔으로 정렬을 덮습니다.

CREATE TRIGGER diaries_set_updated_at BEFORE UPDATE ON diaries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE diaries;

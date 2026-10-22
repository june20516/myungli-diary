-- +goose Up
-- 일기를 한 날짜에 여러 편 쓸 수 있게 날짜 기록(diary_days)과 일기 한 편(diaries)으로 나눕니다(D83).
-- diary_days는 그날 첫 편을 쓸 때 만들고 이후 바꾸지 않으므로 updated_at이 없습니다. 일기를 다 지워도 행은 남고, 행을 지우는 일은 계정 익명화와 합치기만 합니다(FK는 ON DELETE RESTRICT).
-- all_tags·featured_tags·ruleset_version·guide_question은 처음 쓸 때 본 그날 엔진 결과와 질문의 기록입니다.
-- featured_tags는 [{"key","polarity"}], guide_question은 [{"text","term"}](term은 없으면 생략)이고, 질문이 없으면 NULL입니다.
-- 이관: (계정, 날짜)마다 살아 있는 행의 기록을 쓰고, 살아 있는 행이 없으면 가장 먼저 만든 행(created_at, id 순)의 기록을 씁니다.
CREATE TABLE diary_days (
    account_id      uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    date            date        NOT NULL,
    all_tags        text[]      NOT NULL,
    featured_tags   jsonb       NOT NULL,
    guide_question  jsonb,
    ruleset_version text        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, date)
);

INSERT INTO diary_days (account_id, date, all_tags, featured_tags, guide_question, ruleset_version, created_at)
SELECT DISTINCT ON (account_id, date) account_id, date, all_tags, featured_tags, guide_question, ruleset_version, created_at
FROM diaries
ORDER BY account_id, date, (deleted_at IS NOT NULL), created_at, id;

-- 태그로 거르는 목록용입니다.
CREATE INDEX diary_days_all_tags ON diary_days USING gin (all_tags);

ALTER TABLE diaries
    ADD CONSTRAINT diaries_day_fk FOREIGN KEY (account_id, date) REFERENCES diary_days (account_id, date) ON DELETE RESTRICT;

DROP INDEX diaries_one_per_day;
DROP INDEX diaries_all_tags;

-- 날짜 역순 목록용입니다. 같은 날짜 안에서는 쓴 순서로 둡니다.
CREATE INDEX diaries_list ON diaries (account_id, date DESC, created_at, id) WHERE deleted_at IS NULL;

ALTER TABLE diaries
    DROP COLUMN all_tags,
    DROP COLUMN featured_tags,
    DROP COLUMN guide_question,
    DROP COLUMN ruleset_version;

-- +goose Down
-- 한 날짜에 살아 있는 일기가 하나일 때만 되돌릴 수 있습니다. 둘 이상이면 diaries_one_per_day를 만들지 못해 실패합니다.
-- 지운 일기도 같은 날짜 기록의 값을 받습니다(옛 모양은 행마다 값을 가졌지만 날짜별 값 하나로 복원합니다).
ALTER TABLE diaries
    ADD COLUMN all_tags        text[],
    ADD COLUMN featured_tags   jsonb,
    ADD COLUMN guide_question  jsonb,
    ADD COLUMN ruleset_version text;

UPDATE diaries d
SET all_tags = dd.all_tags,
    featured_tags = dd.featured_tags,
    guide_question = dd.guide_question,
    ruleset_version = dd.ruleset_version
FROM diary_days dd
WHERE dd.account_id = d.account_id AND dd.date = d.date;

ALTER TABLE diaries
    ALTER COLUMN all_tags SET NOT NULL,
    ALTER COLUMN featured_tags SET NOT NULL,
    ALTER COLUMN ruleset_version SET NOT NULL;

CREATE UNIQUE INDEX diaries_one_per_day ON diaries (account_id, date) WHERE deleted_at IS NULL;
CREATE INDEX diaries_all_tags ON diaries USING gin (all_tags);

DROP INDEX diaries_list;
ALTER TABLE diaries DROP CONSTRAINT diaries_day_fk;
DROP TABLE diary_days;

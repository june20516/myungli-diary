-- +goose Up
-- 콘텐츠(문장 틀) 시드와, 사용자에게 보여 준 문장의 선택 기록 테이블입니다.
-- 시드 버전은 내용 지문이라 새 버전이 들어와도 옛 버전 행을 지우지 않습니다(옛 선택 기록이 옛 버전을 가리키기 때문입니다).
-- 계정 행은 물리적으로 지우지 않으므로 계정을 가리키는 FK는 기존 테이블처럼 ON DELETE RESTRICT입니다.
-- 선택 기록 -> 반응 FK만 CASCADE라서, 계정 정리 때 선택 기록을 지우면 반응도 함께 지워집니다.

CREATE TABLE content_seeds (
    version    text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now(),
    active     boolean     NOT NULL DEFAULT false
);

-- 활성 시드는 항상 하나 이하입니다.
CREATE UNIQUE INDEX content_seeds_one_active ON content_seeds (active) WHERE active;

CREATE TABLE content_templates (
    seed_version text NOT NULL REFERENCES content_seeds (version) ON DELETE RESTRICT,
    slot         text NOT NULL,
    key          text NOT NULL,
    variant      text NOT NULL,
    lang         text NOT NULL CHECK (lang IN ('ko', 'en', 'ja')),
    body         text NOT NULL,
    PRIMARY KEY (seed_version, slot, key, variant, lang)
);

-- 하루·슬롯마다 어떤 문장을 골랐는지의 기록입니다. 사주 지문(birth_hash)이 달라지면 새로 고르므로 키에 들어갑니다.
CREATE TABLE daily_selections (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id   uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    date         date        NOT NULL,
    slot         text        NOT NULL,
    birth_hash   bytea       NOT NULL CONSTRAINT daily_selections_birth_hash_len CHECK (octet_length(birth_hash) = 32),
    message_key  text        NOT NULL,
    variant      text        NOT NULL,
    seed_version text        NOT NULL REFERENCES content_seeds (version) ON DELETE RESTRICT,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT daily_selections_unique UNIQUE (account_id, date, slot, birth_hash)
);

-- 같은 메시지 키가 다시 나올 때 어느 변주 차례인지의 상태입니다.
CREATE TABLE rotation_state (
    account_id   uuid NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    message_key  text NOT NULL,
    next_variant text NOT NULL,
    PRIMARY KEY (account_id, message_key)
);

-- 선택 기록 하나에 반응은 하나입니다. 반응을 취소하면 deleted_at을 채웁니다.
CREATE TABLE reactions (
    selection_id bigint      NOT NULL UNIQUE REFERENCES daily_selections (id) ON DELETE CASCADE,
    reaction     text        NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz
);

-- +goose Down
DROP TABLE reactions;
DROP TABLE rotation_state;
DROP TABLE daily_selections;
DROP TABLE content_templates;
DROP TABLE content_seeds;

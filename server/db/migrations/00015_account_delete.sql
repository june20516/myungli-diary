-- +goose Up
-- 계정 삭제 즉시 처리(S105)와 허가 취소 재시도(S106)의 저장입니다.
-- 옛 열(deletion_requested_at·anonymized_at, auth_identities.provider_disconnected_at)과
-- 옛 CHECK·'pending_deletion' 값은 그 열을 쓰는 코드가 없어질 때 따로 지우므로 이 migration은 새 것만 더합니다.

-- 지운 시각입니다. 이미 'deleted'인 행은 옛 시각에서 채웁니다.
ALTER TABLE accounts ADD COLUMN deleted_at timestamptz;
UPDATE accounts SET deleted_at = coalesce(anonymized_at, deletion_requested_at) WHERE status = 'deleted';

-- 카카오·Apple 허가 취소를 다시 시도하려고 남기는 대기 행입니다.
-- 원래 인증 계정과 유저 계정 행을 지운 뒤에도 남아야 하므로 FK가 없습니다.
CREATE TABLE provider_revocations (
    id                  bigserial PRIMARY KEY,
    provider            text        NOT NULL CHECK (provider IN ('kakao', 'apple')),
    -- 카카오 사용자 id(unlink에 씀). Apple은 NULL입니다.
    subject             text,
    -- 원래 인증 계정 id입니다. Apple refresh token을 이 id를 aad로 묶어 암호화했으므로 복호화에 씁니다.
    identity_id         uuid        NOT NULL,
    -- 원래 행의 암호화 값 그대로입니다. 카카오는 NULL입니다.
    apple_refresh_token bytea,
    apple_token_key_id  text,
    apple_client_id     text,
    attempts            integer     NOT NULL DEFAULT 0,
    next_attempt_at     timestamptz NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    -- apple_* 세 열은 모두 있거나 모두 없어야 합니다.
    CONSTRAINT provider_revocations_apple_columns_together CHECK (
        (apple_refresh_token IS NULL) = (apple_token_key_id IS NULL)
        AND (apple_refresh_token IS NULL) = (apple_client_id IS NULL)
    ),
    -- 카카오는 subject가 있고 Apple 열이 없으며, Apple은 Apple 열이 있습니다.
    CONSTRAINT provider_revocations_provider_columns CHECK (
        (provider = 'kakao' AND subject IS NOT NULL AND apple_refresh_token IS NULL)
        OR (provider = 'apple' AND apple_refresh_token IS NOT NULL)
    )
);

-- 재시도 job이 시각이 된 행을 찾습니다.
CREATE INDEX provider_revocations_next_attempt_at_idx ON provider_revocations (next_attempt_at);

-- 계정과 끊긴 문장별 반응 집계입니다(D57). 계정을 지울 때 반응을 여기에 더합니다.
CREATE TABLE reaction_tallies (
    message_key text   NOT NULL,
    variant     text   NOT NULL,
    reaction    text   NOT NULL,
    count       bigint NOT NULL CHECK (count > 0),
    PRIMARY KEY (message_key, variant, reaction)
);

-- +goose Down
-- 집계와 대기 행은 지워지고 되돌아오지 않습니다.
DROP TABLE reaction_tallies;
DROP TABLE provider_revocations;
ALTER TABLE accounts DROP COLUMN deleted_at;

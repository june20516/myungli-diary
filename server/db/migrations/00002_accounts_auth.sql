-- +goose Up
-- 계정, 제공자 연결, refresh token, 약관 동의 테이블입니다.
-- 행을 물리적으로 지우지 않으므로 FK는 모두 ON DELETE RESTRICT입니다.
-- 업무 시각(last_active_at 등)은 앱이 Clock에서 받아 넣고, created_at만 DB 기본값을 씁니다.

CREATE TABLE accounts (
    id                    uuid PRIMARY KEY,
    status                text        NOT NULL CHECK (status IN ('active', 'pending_deletion', 'deleted')),
    deletion_requested_at timestamptz,
    anonymized_at         timestamptz,
    last_active_at        timestamptz NOT NULL,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    -- status와 삭제 관련 시각의 짝을 DB가 지킵니다.
    CONSTRAINT accounts_status_timestamps CHECK (
        (status = 'active' AND deletion_requested_at IS NULL AND anonymized_at IS NULL)
        OR (status = 'pending_deletion' AND deletion_requested_at IS NOT NULL AND anonymized_at IS NULL)
        OR (status = 'deleted' AND deletion_requested_at IS NOT NULL AND anonymized_at IS NOT NULL)
    )
);

CREATE TRIGGER accounts_set_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE auth_identities (
    id                       uuid PRIMARY KEY,
    account_id               uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    provider                 text        NOT NULL CHECK (provider IN ('kakao', 'apple')),
    subject                  text        NOT NULL,
    -- secretbox(AES-GCM)로 암호화한 값입니다. 키 id는 apple_token_key_id에 둡니다.
    apple_refresh_token      bytea,
    apple_token_key_id       text,
    apple_client_id          text,
    provider_disconnected_at timestamptz,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT auth_identities_provider_subject_key UNIQUE (provider, subject),
    -- apple_* 세 열은 모두 있거나 모두 없어야 합니다.
    CONSTRAINT auth_identities_apple_columns_together CHECK (
        (apple_refresh_token IS NULL) = (apple_token_key_id IS NULL)
        AND (apple_refresh_token IS NULL) = (apple_client_id IS NULL)
    ),
    -- 카카오 연결에는 Apple 토큰 정보가 없습니다.
    CONSTRAINT auth_identities_kakao_without_apple CHECK (
        provider <> 'kakao' OR apple_refresh_token IS NULL
    )
);

CREATE INDEX auth_identities_account_id_idx ON auth_identities (account_id);

CREATE TRIGGER auth_identities_set_updated_at BEFORE UPDATE ON auth_identities
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE refresh_tokens (
    id         uuid PRIMARY KEY,
    account_id uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    -- 토큰 원문이 아니라 SHA-256만 저장합니다.
    token_hash bytea       NOT NULL UNIQUE,
    -- 같은 로그인에서 회전된 토큰들의 묶음입니다. 재사용이 감지되면 묶음 전체를 폐기합니다.
    family_id  uuid        NOT NULL,
    expires_at timestamptz NOT NULL,
    used_at    timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_family_id_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_account_active_idx ON refresh_tokens (account_id) WHERE revoked_at IS NULL;

CREATE TABLE consents (
    id         uuid PRIMARY KEY,
    account_id uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    document   text        NOT NULL CHECK (document IN ('terms', 'privacy')),
    version    text        NOT NULL,
    agreed_at  timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT consents_account_document_version_key UNIQUE (account_id, document, version)
);

-- +goose Down
DROP TABLE consents;
DROP TABLE refresh_tokens;
DROP TABLE auth_identities;
DROP TABLE accounts;

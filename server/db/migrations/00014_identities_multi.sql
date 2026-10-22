-- +goose Up
-- LINE·Google 로그인(S99)과 한 계정의 연결 여러 개(S100), 계정 합치기 토큰(S101)의 저장입니다.
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_provider_check;
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_provider_check
    CHECK (provider IN ('kakao', 'apple', 'test', 'line', 'google'));

-- LINE·Google 연결에는 Apple 토큰 정보가 없습니다(카카오와 같은 규칙).
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_line_google_without_apple CHECK (
    provider NOT IN ('line', 'google') OR apple_refresh_token IS NULL
);

-- 한 계정에 같은 제공자 연결은 하나입니다. 지금 데이터는 계정마다 연결이 하나라 걸리는 행이 없습니다.
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_account_provider_key UNIQUE (account_id, provider);

-- 합치기 토큰입니다. 원문이 아니라 SHA-256만 저장하고, 10분 일회용입니다.
-- 붙이려던 연결(identity_id)이 떼거나 합쳐 지워지면 토큰도 함께 무효가 되므로 CASCADE입니다.
-- 계정은 물리적으로 지우지 않으므로 account_id·other_account_id는 RESTRICT입니다.
CREATE TABLE account_merge_tickets (
    id               uuid PRIMARY KEY,
    token_hash       bytea       NOT NULL UNIQUE,
    account_id       uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    other_account_id uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    identity_id      uuid        NOT NULL REFERENCES auth_identities (id) ON DELETE CASCADE,
    expires_at       timestamptz NOT NULL,
    consumed_at      timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now()
);

-- 지난 행 정리(retention)가 만료 시각으로 찾습니다.
CREATE INDEX account_merge_tickets_expires_at_idx ON account_merge_tickets (expires_at);

-- +goose Down
-- 'line'·'google' 행이 남아 있으면 되돌리기가 CHECK 위반으로 실패합니다. 그 연결을 먼저 정리해야 합니다.
DROP TABLE account_merge_tickets;
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_account_provider_key;
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_line_google_without_apple;
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_provider_check;
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_provider_check
    CHECK (provider IN ('kakao', 'apple', 'test'));

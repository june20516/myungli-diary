-- +goose Up
-- Apple 웹 로그인 콜백이 만든 임시 결과입니다. 앱이 교환 코드로 한 번 가져가면 소진됩니다.
-- 행을 물리적으로 지우지 않으므로 소진 여부는 consumed_at으로 표시합니다.
-- 업무 시각(expires_at, consumed_at)은 앱이 Clock에서 받아 넣고, created_at만 DB 기본값을 씁니다.

CREATE TABLE apple_web_logins (
    id                  uuid PRIMARY KEY,
    -- 교환 코드 원문이 아니라 SHA-256만 저장합니다.
    exchange_hash       bytea       NOT NULL UNIQUE,
    subject             text        NOT NULL,
    -- Apple id_token의 nonce claim입니다. 앱이 보낸 nonce의 SHA-256 소문자 hex와 비교합니다.
    nonce_hash          text        NOT NULL CHECK (nonce_hash ~ '^[0-9a-f]{64}$'),
    -- secretbox(AES-GCM)로 암호화한 값입니다. 키 id는 apple_token_key_id에 둡니다.
    apple_refresh_token bytea       NOT NULL,
    apple_token_key_id  text        NOT NULL,
    apple_client_id     text        NOT NULL,
    expires_at          timestamptz NOT NULL,
    consumed_at         timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT apple_web_logins_consumed_not_after_expiry CHECK (consumed_at IS NULL OR consumed_at <= expires_at)
);

-- +goose Down
DROP TABLE apple_web_logins;

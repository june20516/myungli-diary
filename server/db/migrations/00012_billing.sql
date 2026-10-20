-- +goose Up
-- 결제와 권한 표 셋입니다(P7). 권한 판정은 entitlement_grants만 읽습니다(spec §3.3).
-- 세 표 모두 계정 삭제 때 행을 지우지 않고 보관합니다(spec §9 남김). 계정 FK는 ON DELETE RESTRICT입니다.

-- 권한 부여 기록입니다. 환불·취소는 행을 지우지 않고 revoked_at을 찍습니다.
-- 같은 (entitlement, source, source_ref)는 한 행이라 동기화가 그 행을 찾아 고칩니다.
CREATE TABLE entitlement_grants (
    id          bigserial   PRIMARY KEY,
    account_id  uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    entitlement text        NOT NULL CHECK (entitlement IN ('ad_free', 'insight')),
    source      text        NOT NULL CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription')),
    source_ref  text        NOT NULL,
    starts_at   timestamptz NOT NULL,
    expires_at  timestamptz NOT NULL,
    revoked_at  timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT entitlement_grants_period CHECK (expires_at > starts_at),
    CONSTRAINT entitlement_grants_source_unique UNIQUE (entitlement, source, source_ref)
);

CREATE INDEX entitlement_grants_account_idx ON entitlement_grants (account_id, entitlement, expires_at);

-- 보상형 광고 서버 검증(SSV) 콜백 기록입니다. transaction_id가 멱등 키입니다.
-- 모르는 계정의 콜백도 기록만 하므로 account_id는 NULL을 허용합니다. raw_query는 원본 쿼리 전체입니다.
CREATE TABLE reward_events (
    transaction_id text        PRIMARY KEY,
    account_id     uuid        REFERENCES accounts (id) ON DELETE RESTRICT,
    ad_unit        text,
    reward_item    text,
    raw_query      text        NOT NULL,
    received_at    timestamptz NOT NULL
);

-- RevenueCat webhook 수신 기록입니다. event_id가 멱등 키이고, processed_at이 NULL이면 처리가 끝나지 않은 것입니다.
-- 회계·분쟁 근거라 5년 보관합니다(spec §9). 지난 기록 정리는 retention 작업 몫입니다.
CREATE TABLE billing_events (
    id           bigserial   PRIMARY KEY,
    event_id     text        NOT NULL UNIQUE,
    account_id   uuid        REFERENCES accounts (id) ON DELETE RESTRICT,
    payload      jsonb       NOT NULL,
    received_at  timestamptz NOT NULL,
    processed_at timestamptz
);

-- +goose Down
DROP TABLE billing_events;
DROP TABLE reward_events;
DROP TABLE entitlement_grants;

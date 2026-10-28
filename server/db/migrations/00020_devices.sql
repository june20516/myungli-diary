-- +goose Up
-- 알림 기기입니다(S92, S119). FCM 토큰은 기기 하나를 뜻하므로 전역 unique이고, 다른 계정이 같은 토큰을 등록하면
-- 행의 주인이 그 계정으로 옮겨 갑니다. 해제하거나 상한(계정당 활성 10대)을 넘은 기기는 비활성으로 남깁니다.
-- 계정은 물리적으로 지우지 않으므로 FK는 RESTRICT이고, 계정 삭제가 기기 행을 먼저 지웁니다.
CREATE TABLE devices (
    id           uuid        PRIMARY KEY,
    account_id   uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    fcm_token    text        NOT NULL UNIQUE,
    platform     text        NOT NULL CHECK (platform IN ('ios', 'android')),
    active       boolean     NOT NULL,
    last_seen_at timestamptz NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- 상한 적용과 알림 발송이 계정의 활성 기기를 최근 순으로 찾습니다.
CREATE INDEX devices_account_active_idx ON devices (account_id, last_seen_at) WHERE active;

-- +goose Down
DROP TABLE devices;

-- +goose Up
-- 알림 기기입니다(S92, S119). FCM 토큰은 기기 하나를 뜻하므로 전역 unique이고, 다른 계정이 같은 토큰을 등록하면
-- 행의 주인이 그 계정으로 옮겨 갑니다. 해제하거나 상한(계정당 활성 10대)을 넘은 기기는 비활성으로 남깁니다.
-- 계약은 토큰을 4096자까지 받는데 btree 항목은 약 2.7KB가 상한이라, unique는 토큰의 SHA-256(token_hash)에 겁니다.
-- 계정은 물리적으로 지우지 않으므로 FK는 RESTRICT이고, 계정 삭제가 기기 행을 먼저 지웁니다.
CREATE TABLE devices (
    id           uuid        PRIMARY KEY,
    account_id   uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    fcm_token    text        NOT NULL,
    token_hash   bytea       NOT NULL UNIQUE,
    platform     text        NOT NULL CHECK (platform IN ('ios', 'android')),
    active       boolean     NOT NULL,
    last_seen_at timestamptz NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- 상한 적용과 알림 발송이 계정의 활성 기기를 최근 순으로 찾습니다.
CREATE INDEX devices_account_active_idx ON devices (account_id, last_seen_at) WHERE active;

-- 계정 삭제와 겹친 등록이 지운 계정에 기기 행을 남기지 않게 막습니다(migration 00015의 개인 데이터 표와 같은 규칙).
-- 토큰이 다른 계정으로 옮겨 가는 upsert도 account_id를 바꾸므로 같이 검사합니다.
-- 같은 계정의 재등록(기기 행을 잠근 뒤 trigger가 계정 행을 기다림)과 그 계정의 삭제(계정 행을 잠근 뒤 기기 행을 지움)는
-- 서로를 기다려 deadlock(40P01)이 날 수 있습니다. postgres.InTx가 진 쪽을 다시 실행하므로 풀립니다
-- (다시 실행한 등록은 MD001로 끝남). migration 00015에 적은 다른 쓰기와 같은 경우입니다.
CREATE TRIGGER devices_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON devices
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();

-- +goose Down
DROP TRIGGER devices_reject_deleted_account ON devices;
DROP TABLE devices;

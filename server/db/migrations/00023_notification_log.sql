-- +goose Up
-- 아침 알림 발송 기록입니다(spec §3, §8.2, S129). (계정, 현지 날짜)마다 한 행이라 하루 한 번을 지킵니다.
-- job notify는 보내기 전에 행을 pending으로 넣고(claim) 끝나면 sent·failed로 바꿉니다. 겹친 실행도 두 번 보내지 않습니다.
CREATE TABLE notification_log (
    account_id uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    local_date date        NOT NULL,
    result     text        NOT NULL CHECK (result IN ('pending', 'sent', 'failed')),
    claimed_at timestamptz NOT NULL,
    sent_at    timestamptz,
    PRIMARY KEY (account_id, local_date)
);

-- job retention이 30일 지난 행을 지웁니다.
CREATE INDEX notification_log_claimed_at_idx ON notification_log (claimed_at);

-- 계정 삭제와 겹친 발송이 지운 계정에 행을 남기지 않게 막습니다(migration 00015의 개인 데이터 표와 같은 규칙).
CREATE TRIGGER notification_log_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON notification_log
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();

-- +goose Down
DROP TRIGGER notification_log_reject_deleted_account ON notification_log;
DROP TABLE notification_log;

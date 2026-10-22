-- +goose Up
-- 계정 삭제 즉시 처리(S105)와 허가 취소 재시도(S106)의 저장입니다.
-- 삭제 대기 상태('pending_deletion')·30일 유예·익명화가 없어지므로, 남은 삭제 대기 계정을 지우고 옛 열과 CHECK를
-- deleted_at 하나로 바꾸며, 프로필의 익명화 열도 없앱니다.

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

-- 지운 계정에 개인 데이터 행이 새로 붙지 않게 막습니다(S105).
-- 삭제 트랜잭션은 계정 행을 FOR UPDATE로 잠근 채 개인 데이터를 지우므로, 미들웨어를 이미 통과한 쓰기가
-- 그 사이에 행을 넣으면 FK는 껍데기 계정 행으로 통과해 버립니다. 그래서 쓰기마다 계정 행을 FOR KEY SHARE
-- (FK 검사와 같은 잠금)로 읽어, 삭제가 끝날 때까지 기다렸다가 commit된 상태를 봅니다.
-- 'deleted'면 SQLSTATE MD001(account.SQLStateAccountDeleted)로 실패하고 server는 401 auth.token_invalid로 답합니다.
-- 계정 삭제 자신은 지우기만 하고 마지막에 accounts를 바꾸므로 이 trigger에 걸리지 않습니다.
-- +goose StatementBegin
CREATE FUNCTION reject_deleted_account_write() RETURNS trigger AS $$
DECLARE
    account_status text;
BEGIN
    SELECT status INTO account_status FROM accounts WHERE id = NEW.account_id FOR KEY SHARE;
    IF account_status = 'deleted' THEN
        RAISE EXCEPTION 'account is deleted' USING ERRCODE = 'MD001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

-- reactions는 account_id가 없어 선택 기록으로 계정을 찾습니다. 선택 기록이 이미 없으면 FK 검사에 맡깁니다.
-- +goose StatementBegin
CREATE FUNCTION reject_deleted_account_reaction() RETURNS trigger AS $$
DECLARE
    owner_id       uuid;
    account_status text;
BEGIN
    SELECT account_id INTO owner_id FROM daily_selections WHERE id = NEW.selection_id;
    SELECT status INTO account_status FROM accounts WHERE id = owner_id FOR KEY SHARE;
    IF account_status = 'deleted' THEN
        RAISE EXCEPTION 'account is deleted' USING ERRCODE = 'MD001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

-- INSERT와, 나중 합치기가 쓰는 account_id를 바꾸는 UPDATE에 겁니다. 다른 열만 바꾸는 UPDATE는 지운 계정의 행이
-- 남아 있지 않으므로 검사하지 않습니다.
CREATE TRIGGER profiles_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON profiles
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER diaries_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON diaries
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER diary_days_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON diary_days
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER schedules_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON schedules
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER daily_selections_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON daily_selections
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER rotation_state_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON rotation_state
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER consents_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON consents
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER auth_identities_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON auth_identities
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER refresh_tokens_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON refresh_tokens
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER idempotency_keys_reject_deleted_account BEFORE INSERT OR UPDATE OF account_id ON idempotency_keys
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_write();
CREATE TRIGGER reactions_reject_deleted_account BEFORE INSERT OR UPDATE OF selection_id ON reactions
    FOR EACH ROW EXECUTE FUNCTION reject_deleted_account_reaction();

-- 남은 삭제 대기 계정을 계정 삭제(account.DeleteAccountTx)와 같은 목록·순서로 지웁니다(spec §3.2).
-- 출시 전이라 staging에만 있는 행입니다. 그래서 반응을 문장별 집계(reaction_tallies)에 더하지 않습니다
-- (실제 사용자의 반응이 아니라 집계에 섞이면 안 됩니다). 카카오·Apple 허가 취소는 계정 삭제처럼 대기 행으로 남겨
-- 재시도 job(retention)이 처리하게 합니다. 위 trigger는 INSERT와 account_id를 바꾸는 UPDATE에만 걸리므로
-- 여기의 DELETE와 accounts UPDATE를 막지 않습니다.
INSERT INTO provider_revocations (provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at, created_at)
SELECT i.provider,
       CASE WHEN i.provider = 'kakao' THEN i.subject END,
       i.id,
       i.apple_refresh_token,
       i.apple_token_key_id,
       i.apple_client_id,
       now(),
       now()
FROM auth_identities i
JOIN accounts a ON a.id = i.account_id
WHERE a.status = 'pending_deletion'
  AND (i.provider = 'kakao' OR (i.provider = 'apple' AND i.apple_refresh_token IS NOT NULL));

DELETE FROM reactions
WHERE selection_id IN (
    SELECT s.id FROM daily_selections s JOIN accounts a ON a.id = s.account_id WHERE a.status = 'pending_deletion'
);
DELETE FROM daily_selections WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM rotation_state WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM diaries WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM diary_days WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM schedules WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM idempotency_keys WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM account_merge_tickets
WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion')
   OR other_account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM refresh_tokens WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM consents WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
DELETE FROM auth_identities WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
-- 계산 캐시는 프로필의 출생 해시로 찾으므로 프로필보다 먼저 지웁니다.
DELETE FROM chart_cache WHERE birth_hash IN (
    SELECT p.birth_hash FROM profiles p JOIN accounts a ON a.id = p.account_id WHERE a.status = 'pending_deletion'
);
DELETE FROM daily_cache WHERE birth_hash IN (
    SELECT p.birth_hash FROM profiles p JOIN accounts a ON a.id = p.account_id WHERE a.status = 'pending_deletion'
);
DELETE FROM month_cache WHERE birth_hash IN (
    SELECT p.birth_hash FROM profiles p JOIN accounts a ON a.id = p.account_id WHERE a.status = 'pending_deletion'
);
DELETE FROM profiles WHERE account_id IN (SELECT id FROM accounts WHERE status = 'pending_deletion');
-- 지운 시각은 삭제를 요청한 시각으로 둡니다. 옛 CHECK가 deleted에 anonymized_at을 요구하므로 같은 값으로 채웁니다.
UPDATE accounts
SET status = 'deleted', deleted_at = deletion_requested_at, anonymized_at = deletion_requested_at
WHERE status = 'pending_deletion';

-- 상태는 active·deleted 둘뿐이고, 지운 시각은 deleted일 때만 있습니다.
ALTER TABLE accounts DROP CONSTRAINT accounts_status_timestamps;
ALTER TABLE accounts DROP CONSTRAINT accounts_status_check;
ALTER TABLE accounts DROP COLUMN deletion_requested_at;
ALTER TABLE accounts DROP COLUMN anonymized_at;
ALTER TABLE accounts ADD CONSTRAINT accounts_status_check CHECK (status IN ('active', 'deleted'));
ALTER TABLE accounts ADD CONSTRAINT accounts_status_deleted_at CHECK (
    (status = 'active' AND deleted_at IS NULL) OR (status = 'deleted' AND deleted_at IS NOT NULL)
);

-- 떼기는 연결 행을 지우고 계정 삭제도 연결 행을 지우므로(S100·S105) 끊긴 시각 표시는 쓰지 않습니다.
ALTER TABLE auth_identities DROP COLUMN provider_disconnected_at;

-- 익명화가 없어졌으므로(S105, 계정 삭제가 프로필 행을 지움) profiles.anonymized_at과 익명화 전제 CHECK를 없앱니다.
-- 익명화된 프로필은 익명화 job이 없어 생긴 적이 없지만, 남아 있다면 지운 계정의 것이라 지웁니다.
-- 출생 정보 전체·호칭·출생 해시가 모두 있어야 한다는 조건은 그대로 profiles_complete로 지킵니다.
DELETE FROM profiles WHERE anonymized_at IS NOT NULL;
ALTER TABLE profiles DROP CONSTRAINT profiles_complete_until_anonymized;
ALTER TABLE profiles DROP COLUMN anonymized_at;
ALTER TABLE profiles ADD CONSTRAINT profiles_complete CHECK (
    honorific IS NOT NULL AND calendar IS NOT NULL AND is_leap_month IS NOT NULL
    AND birth_year IS NOT NULL AND birth_month IS NOT NULL AND birth_day IS NOT NULL
    AND birth_time_status IS NOT NULL AND gender IS NOT NULL AND birth_timezone IS NOT NULL
    AND birth_place_status IS NOT NULL AND birth_hash IS NOT NULL
);

-- +goose Down
-- 열과 CHECK는 되돌리지만 지운 데이터(삭제 대기 계정의 개인 데이터)는 되돌리지 않습니다. 그 계정은 deleted로 남습니다.
ALTER TABLE profiles DROP CONSTRAINT profiles_complete;
ALTER TABLE profiles ADD COLUMN anonymized_at timestamptz;
ALTER TABLE profiles ADD CONSTRAINT profiles_complete_until_anonymized CHECK (
    anonymized_at IS NOT NULL
    OR (honorific IS NOT NULL AND calendar IS NOT NULL AND is_leap_month IS NOT NULL
        AND birth_year IS NOT NULL AND birth_month IS NOT NULL AND birth_day IS NOT NULL
        AND birth_time_status IS NOT NULL AND gender IS NOT NULL AND birth_timezone IS NOT NULL
        AND birth_place_status IS NOT NULL AND birth_hash IS NOT NULL)
);
ALTER TABLE auth_identities ADD COLUMN provider_disconnected_at timestamptz;
ALTER TABLE accounts DROP CONSTRAINT accounts_status_deleted_at;
ALTER TABLE accounts DROP CONSTRAINT accounts_status_check;
ALTER TABLE accounts ADD COLUMN deletion_requested_at timestamptz;
ALTER TABLE accounts ADD COLUMN anonymized_at timestamptz;
-- 되돌린 옛 CHECK를 만족하도록 지운 계정의 옛 두 시각을 지운 시각으로 채웁니다.
UPDATE accounts SET deletion_requested_at = deleted_at, anonymized_at = deleted_at WHERE status = 'deleted';
ALTER TABLE accounts ADD CONSTRAINT accounts_status_check CHECK (status IN ('active', 'pending_deletion', 'deleted'));
ALTER TABLE accounts ADD CONSTRAINT accounts_status_timestamps CHECK (
    (status = 'active' AND deletion_requested_at IS NULL AND anonymized_at IS NULL)
    OR (status = 'pending_deletion' AND deletion_requested_at IS NOT NULL AND anonymized_at IS NULL)
    OR (status = 'deleted' AND deletion_requested_at IS NOT NULL AND anonymized_at IS NOT NULL)
);
DROP TRIGGER reactions_reject_deleted_account ON reactions;
DROP TRIGGER idempotency_keys_reject_deleted_account ON idempotency_keys;
DROP TRIGGER refresh_tokens_reject_deleted_account ON refresh_tokens;
DROP TRIGGER auth_identities_reject_deleted_account ON auth_identities;
DROP TRIGGER consents_reject_deleted_account ON consents;
DROP TRIGGER rotation_state_reject_deleted_account ON rotation_state;
DROP TRIGGER daily_selections_reject_deleted_account ON daily_selections;
DROP TRIGGER schedules_reject_deleted_account ON schedules;
DROP TRIGGER diary_days_reject_deleted_account ON diary_days;
DROP TRIGGER diaries_reject_deleted_account ON diaries;
DROP TRIGGER profiles_reject_deleted_account ON profiles;
DROP FUNCTION reject_deleted_account_reaction();
DROP FUNCTION reject_deleted_account_write();
-- 집계와 대기 행은 지워지고 되돌아오지 않습니다.
DROP TABLE reaction_tallies;
DROP TABLE provider_revocations;
ALTER TABLE accounts DROP COLUMN deleted_at;

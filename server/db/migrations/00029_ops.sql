-- 운영 명령(#1321)의 바탕입니다. 운영자 부여의 출처 operator, 운영 행위를 남기는 감사 표 ops_audit,
-- 운영 API 서비스(server-ops)가 쓰는 권한 묶음 myungli_ops를 더합니다. 구성원 지정은 migrate 명령이 합니다(staging, prod).
-- 위로 다시 적용해도 되도록 IF NOT EXISTS, CREATE OR REPLACE를 씁니다(down이 감사 표를 남깁니다).

-- +goose Up
-- 열에 붙은 CHECK는 PostgreSQL이 entitlement_grants_source_check로 이름 붙였습니다(00012, 00022).
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_check;
ALTER TABLE entitlement_grants ADD CONSTRAINT entitlement_grants_source_check
    CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription', 'test_grant', 'operator'));

-- account_id에는 FK를 두지 않습니다. 없는 계정을 조회한 시도도 남기기 위해서입니다.
CREATE TABLE IF NOT EXISTS ops_audit (
    id         uuid        PRIMARY KEY,
    at         timestamptz NOT NULL,
    actor      text        NOT NULL CHECK (actor <> ''),
    -- 실행자의 IAP sub입니다. 메일이 바뀌어도 같은 사람을 찾게 actor(메일)와 따로 남깁니다.
    actor_sub  text        NOT NULL CHECK (actor_sub <> ''),
    channel    text        NOT NULL CHECK (channel IN ('ops_api')),
    action     text        NOT NULL CHECK (action IN ('account_show', 'grant', 'revoke', 'content_view', 'audit_list')),
    account_id uuid,
    purpose    text        CHECK (purpose IN ('inquiry', 'incident', 'policy', 'legal')),
    reason     text        NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
    target     jsonb       NOT NULL,
    before     jsonb,
    after      jsonb,
    CONSTRAINT ops_audit_purpose_for_view CHECK ((action = 'content_view') = (purpose IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS ops_audit_account_idx ON ops_audit (account_id, at DESC);
CREATE INDEX IF NOT EXISTS ops_audit_at_idx ON ops_audit (at);

-- 감사 행은 고칠 수 없고, 보관 2년이 지난 행만 지울 수 있고, 표를 비울 수(TRUNCATE) 없습니다.
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION ops_audit_guard() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'TRUNCATE' THEN
        RAISE EXCEPTION 'ops_audit은 비울 수 없습니다';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'ops_audit 행은 고칠 수 없습니다';
    END IF;
    IF OLD.at >= now() - interval '2 years' THEN
        RAISE EXCEPTION 'ops_audit 행은 2년이 지난 뒤에만 지울 수 있습니다';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

DROP TRIGGER IF EXISTS ops_audit_guard ON ops_audit;
CREATE TRIGGER ops_audit_guard BEFORE UPDATE OR DELETE ON ops_audit
    FOR EACH ROW EXECUTE FUNCTION ops_audit_guard();
-- 행 trigger는 TRUNCATE를 막지 못하므로 문장 trigger를 따로 둡니다.
DROP TRIGGER IF EXISTS ops_audit_guard_truncate ON ops_audit;
CREATE TRIGGER ops_audit_guard_truncate BEFORE TRUNCATE ON ops_audit
    FOR EACH STATEMENT EXECUTE FUNCTION ops_audit_guard();

-- 감사 행의 시각은 DB가 정합니다. at은 언제나 now()(트랜잭션 시작 시각)라 서비스 시계나 인자로 남는 값을 바꿀 수 없습니다.
-- actor는 덮지 않습니다. 사람 DB 계정이 없어 session_user는 서비스 계정이라 사람을 가리키지 않고,
-- 실행자 값은 server-ops가 검증한 IAP JWT에서 넣습니다. channel이 ops_api가 아니면 거절합니다.
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION ops_audit_stamp() RETURNS trigger AS $$
BEGIN
    IF NEW.channel <> 'ops_api' THEN
        RAISE EXCEPTION 'ops_audit의 channel은 ops_api만 쓸 수 있습니다';
    END IF;
    NEW.at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

DROP TRIGGER IF EXISTS ops_audit_stamp ON ops_audit;
CREATE TRIGGER ops_audit_stamp BEFORE INSERT ON ops_audit
    FOR EACH ROW EXECUTE FUNCTION ops_audit_stamp();

-- 00024의 기본 권한이 새 표에 UPDATE를 주므로 거둡니다(trigger가 한 번 더 막습니다).
REVOKE UPDATE ON ops_audit FROM myungli_app;
-- 앱 런타임은 감사 행을 쓰지 않습니다. 감사 행은 server-ops(myungli_ops)만 씁니다.
-- retention용 DELETE는 남깁니다.
REVOKE INSERT ON ops_audit FROM myungli_app;

-- +goose StatementBegin
DO $$
BEGIN
    CREATE ROLE myungli_ops NOLOGIN;
EXCEPTION
    -- 역할은 cluster 전체에 하나입니다. 다른 DB(테스트 DB 포함)가 이미 만들었으면 그대로 씁니다.
    WHEN duplicate_object THEN NULL;
END
$$;
-- +goose StatementEnd

GRANT USAGE ON SCHEMA public TO myungli_ops;
GRANT SELECT ON accounts, entitlement_grants, purchases, diaries, diary_days, schedules, ops_audit TO myungli_ops;
-- 제공자 subject, Apple 토큰, 알림 token, 출생 정보 해시처럼 운영 명령이 읽지 않는 민감 칸은 칸 단위로 뺍니다.
-- 칸 목록은 db/queries/ops.sql이 SELECT, WHERE, ORDER BY에 쓰는 칸입니다. 쿼리가 칸을 더 쓰면 여기도 더합니다.
GRANT SELECT (id, account_id, provider, created_at) ON auth_identities TO myungli_ops;
GRANT SELECT (id, account_id, platform, active, created_at, last_seen_at) ON devices TO myungli_ops;
GRANT SELECT (account_id, honorific, language, current_timezone, calendar, is_leap_month,
              birth_year, birth_month, birth_day, birth_time_status, birth_time,
              gender, birth_timezone, birth_place_status, birth_city_id, longitude) ON profiles TO myungli_ops;
GRANT INSERT ON entitlement_grants, ops_audit TO myungli_ops;
GRANT UPDATE (revoked_at) ON entitlement_grants TO myungli_ops;
GRANT USAGE ON SEQUENCE entitlement_grants_id_seq TO myungli_ops;
-- 운영자 부여가 계정 행을 FOR SHARE로 잠급니다. PostgreSQL은 행 잠금에 그 표의 UPDATE 권한(한 칸 이상)을 요구하므로,
-- 값이 바뀔 일 없는 updated_at 한 칸만 허용합니다.
GRANT UPDATE (updated_at) ON accounts TO myungli_ops;

-- +goose Down
-- 역할은 다른 DB가 쓰고 있을 수 있어 지우지 않고 권한만 거둡니다(00024와 같음).
REVOKE UPDATE (updated_at) ON accounts FROM myungli_ops;
REVOKE USAGE ON SEQUENCE entitlement_grants_id_seq FROM myungli_ops;
REVOKE UPDATE (revoked_at) ON entitlement_grants FROM myungli_ops;
REVOKE INSERT ON entitlement_grants FROM myungli_ops;
REVOKE SELECT (account_id, honorific, language, current_timezone, calendar, is_leap_month,
               birth_year, birth_month, birth_day, birth_time_status, birth_time,
               gender, birth_timezone, birth_place_status, birth_city_id, longitude) ON profiles FROM myungli_ops;
REVOKE SELECT (id, account_id, platform, active, created_at, last_seen_at) ON devices FROM myungli_ops;
REVOKE SELECT (id, account_id, provider, created_at) ON auth_identities FROM myungli_ops;
REVOKE SELECT ON accounts, entitlement_grants, purchases, diaries, diary_days, schedules FROM myungli_ops;
REVOKE USAGE ON SCHEMA public FROM myungli_ops;

-- 감사 기록은 보관 의무가 있어 ops_audit 표, 함수, trigger, 인덱스를 지우지 않습니다. myungli_ops 권한만 거둡니다.
-- (INSERT와 SELECT 권한은 위 REVOKE와 아래에서 거둡니다. 다시 up하면 표를 새로 만들지 않고 그대로 씁니다.)
REVOKE INSERT, SELECT ON ops_audit FROM myungli_ops;

DELETE FROM entitlement_grants WHERE source = 'operator';
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_check;
ALTER TABLE entitlement_grants ADD CONSTRAINT entitlement_grants_source_check
    CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription', 'test_grant'));

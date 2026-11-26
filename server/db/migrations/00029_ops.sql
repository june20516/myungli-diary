-- 운영 명령(#1321)의 바탕입니다. 운영자 부여의 출처 operator, 운영 행위를 남기는 감사 표 ops_audit,
-- 사람 운영자가 쓰는 권한 묶음 myungli_ops를 더합니다. 구성원 지정은 migrate 명령이 합니다(staging, prod).

-- +goose Up
-- 열에 붙은 CHECK는 PostgreSQL이 entitlement_grants_source_check로 이름 붙였습니다(00012, 00022).
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_check;
ALTER TABLE entitlement_grants ADD CONSTRAINT entitlement_grants_source_check
    CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription', 'test_grant', 'operator'));

-- account_id에는 FK를 두지 않습니다. 없는 계정을 조회한 시도도 남기기 위해서입니다.
CREATE TABLE ops_audit (
    id         uuid        PRIMARY KEY,
    at         timestamptz NOT NULL,
    actor      text        NOT NULL CHECK (actor <> ''),
    channel    text        NOT NULL CHECK (channel IN ('cli', 'admin_api')),
    action     text        NOT NULL CHECK (action IN ('account_show', 'grant', 'revoke', 'content_view', 'audit_list')),
    account_id uuid,
    purpose    text        CHECK (purpose IN ('inquiry', 'incident', 'policy', 'legal')),
    reason     text        NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
    target     jsonb       NOT NULL,
    before     jsonb,
    after      jsonb,
    CONSTRAINT ops_audit_purpose_for_view CHECK ((action = 'content_view') = (purpose IS NOT NULL))
);

CREATE INDEX ops_audit_account_idx ON ops_audit (account_id, at DESC);
CREATE INDEX ops_audit_at_idx ON ops_audit (at);

-- 감사 행은 고칠 수 없고, 보관 2년이 지난 행만 지울 수 있고, 표를 비울 수(TRUNCATE) 없습니다.
-- +goose StatementBegin
CREATE FUNCTION ops_audit_guard() RETURNS trigger AS $$
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

CREATE TRIGGER ops_audit_guard BEFORE UPDATE OR DELETE ON ops_audit
    FOR EACH ROW EXECUTE FUNCTION ops_audit_guard();
-- 행 trigger는 TRUNCATE를 막지 못하므로 문장 trigger를 따로 둡니다.
CREATE TRIGGER ops_audit_guard_truncate BEFORE TRUNCATE ON ops_audit
    FOR EACH STATEMENT EXECUTE FUNCTION ops_audit_guard();

-- 00024의 기본 권한이 새 표에 UPDATE를 주므로 거둡니다(trigger가 한 번 더 막습니다).
REVOKE UPDATE ON ops_audit FROM myungli_app;

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
GRANT SELECT ON accounts, auth_identities, devices, entitlement_grants, purchases, diaries, diary_days, schedules, profiles, ops_audit TO myungli_ops;
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
REVOKE SELECT ON accounts, auth_identities, devices, entitlement_grants, purchases, diaries, diary_days, schedules, profiles FROM myungli_ops;
REVOKE USAGE ON SCHEMA public FROM myungli_ops;

DROP TRIGGER ops_audit_guard_truncate ON ops_audit;
DROP TRIGGER ops_audit_guard ON ops_audit;
DROP FUNCTION ops_audit_guard();
DROP TABLE ops_audit;

DELETE FROM entitlement_grants WHERE source = 'operator';
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_check;
ALTER TABLE entitlement_grants ADD CONSTRAINT entitlement_grants_source_check
    CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription', 'test_grant'));

-- 런타임(serve, retention, precompute, notify)이 쓰는 읽기와 쓰기 권한 묶음입니다(S137).
-- migration을 적용하는 계정(server-migrator, cloudsqlsuperuser)이 표의 주인이고, 런타임 계정은 이 역할의
-- 구성원으로만 표에 닿습니다. 그래서 런타임은 데이터를 읽고 쓰지만 표를 만들거나 바꾸거나 지우지 못하고,
-- trigger를 끄거나 역할을 만들지 못합니다. 구성원 지정은 migrate 명령이 DB_RUNTIME_USER로 합니다(환경마다 이름이 다름).

-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    CREATE ROLE myungli_app NOLOGIN;
EXCEPTION
    -- 역할은 cluster 전체에 하나입니다. 다른 DB(테스트 DB 포함)가 이미 만들었으면 그대로 씁니다.
    WHEN duplicate_object THEN NULL;
END
$$;
-- +goose StatementEnd

GRANT USAGE ON SCHEMA public TO myungli_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myungli_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO myungli_app;

-- 이 migration을 적용하는 계정이 앞으로 만드는 표와 sequence에도 같은 권한을 줍니다.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO myungli_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO myungli_app;

-- +goose Down
-- 역할은 다른 DB가 쓰고 있을 수 있어 지우지 않고 권한만 거둡니다.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE USAGE, SELECT, UPDATE ON SEQUENCES FROM myungli_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM myungli_app;
REVOKE USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public FROM myungli_app;
REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM myungli_app;
REVOKE USAGE ON SCHEMA public FROM myungli_app;

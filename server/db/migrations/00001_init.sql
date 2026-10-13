-- +goose Up
-- +goose StatementBegin
-- 이후 테이블이 BEFORE UPDATE 트리거로 쓰는 함수입니다. 행을 고칠 때 updated_at을 현재 시각으로 맞춥니다.
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

-- +goose Down
DROP FUNCTION set_updated_at();

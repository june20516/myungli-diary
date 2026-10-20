-- +goose Up
-- 비로그인 미리보기 1회 기록 표입니다. 설치 id의 SHA-256(32바이트)만 남기고 원문은 남기지 않습니다(D50·D58).
-- 시스템 데이터라 행을 물리적으로 지웁니다(엔진 실패 시 선점 해제, 지난 기록 정리는 retention 작업 몫입니다).
CREATE TABLE preview_usage (
    device_hash bytea       PRIMARY KEY,
    used_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT preview_usage_device_hash_length CHECK (octet_length(device_hash) = 32)
);

-- +goose Down
DROP TABLE preview_usage;

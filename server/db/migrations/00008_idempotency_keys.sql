-- +goose Up
-- Idempotency-Key 표입니다. (account_id, key)가 PK라서 같은 키로 동시에 온 요청 중 하나만 행을 만듭니다.
-- 행은 첫 요청 때 응답 없이(completed_at NULL) 만들고, 처리가 2xx로 끝나면 응답(status·headers·body)을 채웁니다.
-- 시스템 데이터라 만료나 실패한 행은 물리적으로 지웁니다(soft delete 규칙의 예외).
-- 만료(24시간)는 created_at 기준이며, 만료된 행은 같은 키의 다음 요청이 덮어씁니다.
CREATE TABLE idempotency_keys (
    account_id   uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    key          text        NOT NULL,
    request_hash bytea       NOT NULL,
    status       integer,
    headers      jsonb,
    body         bytea,
    created_at   timestamptz NOT NULL,
    completed_at timestamptz,
    PRIMARY KEY (account_id, key),
    CONSTRAINT idempotency_keys_hash_sha256 CHECK (octet_length(request_hash) = 32),
    CONSTRAINT idempotency_keys_completed CHECK (
        completed_at IS NULL OR (status IS NOT NULL AND headers IS NOT NULL AND body IS NOT NULL)
    )
);

-- +goose Down
DROP TABLE idempotency_keys;

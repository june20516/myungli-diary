-- +goose Up
-- 합치기 영수증입니다(S115). 합치기 토큰 행은 B를 지울 때 함께 지워지므로, 같은 토큰의 재전송이 이미 합친 요청인지
-- 가르려고 A(account_id)와 토큰 해시를 합치기와 같은 트랜잭션에 남깁니다. 24시간 동안만 쓰고 job retention이 지웁니다.
-- A를 지우거나 A가 다른 계정에 합쳐지면 계정 삭제가 지웁니다. 계정은 물리적으로 지우지 않으므로 FK는 RESTRICT입니다.
CREATE TABLE account_merge_receipts (
    token_hash bytea       PRIMARY KEY,
    account_id uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    merged_at  timestamptz NOT NULL
);

-- 지난 행 정리(retention)가 합친 시각으로 찾습니다.
CREATE INDEX account_merge_receipts_merged_at_idx ON account_merge_receipts (merged_at);

-- +goose Down
DROP TABLE account_merge_receipts;

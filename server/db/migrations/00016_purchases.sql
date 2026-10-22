-- +goose Up
-- 구매 장부입니다(spec §5.1, D88 ②). 상품 종류와 상관없이 앱에서 산 구매 한 건이 한 행입니다.
-- 계정 삭제 때 행을 지우지 않고 지운 계정 앞으로 남기는 표라서, 개인 데이터 표의 deleted 계정 거절 trigger를 걸지 않습니다.
-- 상태는 열린 값으로 두고 상품 종류를 굳히는 열·제약을 두지 않습니다(spec §5.6).
CREATE TABLE purchases (
    id                  text        PRIMARY KEY,
    account_id          uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    original_account_id uuid        NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    merged_at           timestamptz,
    product_id          text        NOT NULL,
    store               text        NOT NULL,
    purchased_at        timestamptz NOT NULL,
    refunded_at         timestamptz,
    production          boolean     NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX purchases_account_idx ON purchases (account_id, purchased_at DESC);

-- 합친 구매가 B 구간과 A 구간을 함께 가질 수 있도록 같은 구매 행을 계정마다 따로 둡니다(spec §5.1).
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_unique;
ALTER TABLE entitlement_grants
    ADD CONSTRAINT entitlement_grants_source_unique UNIQUE (account_id, entitlement, source, source_ref);

-- +goose Down
-- 한 구매가 여러 유저 계정에 구간 행을 가진 데이터가 있으면 옛 unique 복원이 실패합니다(출시 전이라 허용).
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_unique;
ALTER TABLE entitlement_grants
    ADD CONSTRAINT entitlement_grants_source_unique UNIQUE (entitlement, source, source_ref);
DROP TABLE purchases;

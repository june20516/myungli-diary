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
    -- 스토어 거래 id(RevenueCat v2 store_purchase_identifier)입니다. webhook에는 RevenueCat 구매 id 대신
    -- 이 값이 transaction_id로 오므로, 후보 계정을 못 찾은 webhook이 장부 주인을 찾는 데 씁니다(spec §5.4).
    store_purchase_id   text,
    purchased_at        timestamptz NOT NULL,
    refunded_at         timestamptz,
    production          boolean     NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX purchases_account_idx ON purchases (account_id, purchased_at DESC);
-- 같은 스토어 거래를 찾는 인덱스입니다(장부 기록의 중복 방어, webhook 대체 경로, spec §5.2·§5.4).
-- unique로 두지 않습니다. 같은 스토어 거래가 여러 RevenueCat 구매 id로 보일 수 있는지 아직 확인하지 못했고,
-- 그런 행이 이미 있어도 동기화가 실패하지 않고 경고를 남긴 채 기존 행을 따르게 하려는 것입니다.
CREATE INDEX purchases_store_purchase_idx ON purchases (store, store_purchase_id) WHERE store_purchase_id IS NOT NULL;

-- 장부 이전 동기화가 만든 광고 제거권 구간은 장부 행이 없어 다시 잇기(rechainFrom)가 다룰 수 없으므로 지웁니다.
-- 출시 전이라 staging 데이터만 해당하고, 다음 동기화가 구매 장부와 함께 구간을 다시 만듭니다. 다른 출처 행은 남깁니다.
DELETE FROM entitlement_grants WHERE source = 'ad_free_pass';

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

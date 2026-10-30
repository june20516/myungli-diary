-- +goose Up
-- staging 테스트 광고 제거 기간(S125)의 출처 test_grant를 더합니다. prod 바이너리에는 이 출처를 쓰는 코드가 없습니다.
-- 열에 붙은 CHECK는 PostgreSQL이 entitlement_grants_source_check로 이름 붙였습니다(00012).
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_check;
ALTER TABLE entitlement_grants ADD CONSTRAINT entitlement_grants_source_check
    CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription', 'test_grant'));

-- +goose Down
DELETE FROM entitlement_grants WHERE source = 'test_grant';
ALTER TABLE entitlement_grants DROP CONSTRAINT entitlement_grants_source_check;
ALTER TABLE entitlement_grants ADD CONSTRAINT entitlement_grants_source_check
    CHECK (source IN ('ad_free_pass', 'rewarded_ad', 'subscription'));

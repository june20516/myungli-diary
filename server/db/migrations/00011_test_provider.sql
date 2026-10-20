-- +goose Up
-- staging E2E 테스트 로그인(S24, spec §13.2)이 만드는 provider 'test' 연결을 허용합니다.
-- staging과 prod가 같은 migration입니다. prod 바이너리에는 발급 경로가 없어 'test' 행이 생기지 않습니다.
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_provider_check;
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_provider_check
    CHECK (provider IN ('kakao', 'apple', 'test'));

-- 테스트 연결에는 Apple 토큰 정보가 없습니다(카카오와 같은 규칙).
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_test_without_apple CHECK (
    provider <> 'test' OR apple_refresh_token IS NULL
);

-- +goose Down
-- 'test' 행이 남아 있으면 되돌리기가 CHECK 위반으로 실패합니다. 테스트 계정을 먼저 정리해야 합니다.
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_test_without_apple;
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_provider_check;
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_provider_check
    CHECK (provider IN ('kakao', 'apple'));

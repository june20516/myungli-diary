-- +goose Up
-- job retention이 만료된 refresh token을 지울 때 replaced_by_id의 FK(RESTRICT) 검사가 지우는 행마다
-- 이 열을 찾으므로 인덱스를 둡니다(S120). 첫 사용 전 토큰은 NULL이라 partial 인덱스입니다.
CREATE INDEX refresh_tokens_replaced_by_id_idx ON refresh_tokens (replaced_by_id) WHERE replaced_by_id IS NOT NULL;

-- +goose Down
DROP INDEX refresh_tokens_replaced_by_id_idx;

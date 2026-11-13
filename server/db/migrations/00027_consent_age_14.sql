-- +goose Up
-- 만 14세 이상 확인을 세 번째 필수 동의 문서로 받습니다(D127 ④, #1112, S158). 법적 문서 페이지는 없고 기록과 보관은 다른 동의와 같습니다.
ALTER TABLE consents DROP CONSTRAINT consents_document_check;
ALTER TABLE consents ADD CONSTRAINT consents_document_check CHECK (document IN ('terms', 'privacy', 'age_14'));

-- +goose Down
DELETE FROM consents WHERE document = 'age_14';
ALTER TABLE consents DROP CONSTRAINT consents_document_check;
ALTER TABLE consents ADD CONSTRAINT consents_document_check CHECK (document IN ('terms', 'privacy'));

-- name: GetAccountAccess :one
SELECT status, deletion_requested_at, last_active_at
FROM accounts
WHERE id = @id;

-- TouchLastActive는 저장된 값보다 새 시각일 때만 갱신합니다(쓰기 빈도를 줄입니다).
-- name: TouchLastActive :execrows
UPDATE accounts
SET last_active_at = @last_active_at
WHERE id = @id AND last_active_at < @last_active_at;

-- name: ListConsents :many
SELECT document, version, agreed_at
FROM consents
WHERE account_id = @account_id
ORDER BY agreed_at, document, version;

-- name: InsertConsent :exec
INSERT INTO consents (id, account_id, document, version, agreed_at)
VALUES (@id, @account_id, @document, @version, @agreed_at)
ON CONFLICT (account_id, document, version) DO NOTHING;

-- RequestDeletion은 활성 계정을 삭제 대기로 바꾸고 갱신된 행 수를 돌려줍니다.
-- name: RequestDeletion :execrows
UPDATE accounts
SET status = 'pending_deletion', deletion_requested_at = @deletion_requested_at
WHERE id = @id AND status = 'active';

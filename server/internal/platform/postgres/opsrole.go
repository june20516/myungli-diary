package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// OpsRole은 사람 운영자가 쓰는 권한 묶음입니다(migration 00029, #1321).
const OpsRole = "myungli_ops"

// GrantOpsRole은 사람 IAM 사용자를 OpsRole의 구성원으로 두고, 새로 넣은 사용자 이름을 돌려줍니다.
// 사람 IAM 사용자는 로그인할 수 있고 이름에 @가 있으며 .iam으로 끝나지 않는 역할입니다(서비스 계정 사용자는 .iam으로 끝남).
// 이미 구성원인 사용자는 건드리지 않고 목록에도 넣지 않습니다. migration을 적용한 계정으로 부릅니다.
func GrantOpsRole(ctx context.Context, pool *pgxpool.Pool) ([]string, error) {
	rows, err := pool.Query(ctx, `
		SELECT rolname FROM pg_roles
		WHERE rolcanlogin AND rolname LIKE '%@%' AND rolname NOT LIKE '%.iam'
		  AND NOT pg_has_role(rolname, $1, 'MEMBER')
		ORDER BY rolname`, OpsRole)
	if err != nil {
		return nil, fmt.Errorf("운영자 대상 조회: %w", err)
	}
	names, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return nil, fmt.Errorf("운영자 대상 읽기: %w", err)
	}

	for i, name := range names {
		statement := "GRANT " + pgx.Identifier{OpsRole}.Sanitize() + " TO " + pgx.Identifier{name}.Sanitize()
		if _, err := pool.Exec(ctx, statement); err != nil {
			return nil, grantOpsRoleError(i, err)
		}
	}
	return names, nil
}

// grantOpsRoleError는 GRANT 실패를 로그에 남겨도 되는 오류로 바꿉니다. PostgreSQL 오류 문구에는 사람 메일(역할 이름)이
// 들어갈 수 있어 원문을 감싸지 않고 SQLSTATE 코드만 담습니다. 대상은 이름 대신 순번(1부터)으로 가리킵니다.
func grantOpsRoleError(index int, err error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return fmt.Errorf("%s 구성원 지정(%d번째 대상): SQLSTATE %s", OpsRole, index+1, pgErr.Code)
	}
	return fmt.Errorf("%s 구성원 지정(%d번째 대상): %w", OpsRole, index+1, err)
}

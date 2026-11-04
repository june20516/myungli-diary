package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AppRole은 런타임 계정이 표에 닿는 읽기와 쓰기 권한 묶음입니다(migration 00024, S137).
const AppRole = "myungli_app"

// GrantAppRole은 DB 사용자 member를 AppRole의 구성원으로 둡니다. 이미 구성원이면 바뀌는 것이 없습니다.
// migration을 적용한 계정(AppRole을 만든 계정)으로 부릅니다. member는 이미 있어야 합니다(Cloud SQL IAM 사용자는 Terraform이 만듦).
func GrantAppRole(ctx context.Context, pool *pgxpool.Pool, member string) error {
	if member == "" {
		return errors.New("권한을 줄 DB 사용자 이름이 비어 있습니다")
	}
	statement := "GRANT " + pgx.Identifier{AppRole}.Sanitize() + " TO " + pgx.Identifier{member}.Sanitize()
	if _, err := pool.Exec(ctx, statement); err != nil {
		return fmt.Errorf("%s 구성원 지정: %w", AppRole, err)
	}
	return nil
}

// cloudSQLSuperuser는 Cloud SQL이 주는 가장 높은 사용자 역할입니다. local과 테스트 DB에는 없습니다.
const cloudSQLSuperuser = "cloudsqlsuperuser"

// ErrRuntimeHasSuperuser는 런타임 DB 사용자가 cloudsqlsuperuser에 속해 DDL 권한을 갖는다는 뜻입니다(S137).
var ErrRuntimeHasSuperuser = errors.New("런타임 DB 사용자가 cloudsqlsuperuser 구성원입니다")

// CheckRuntimeNotSuperuser는 member가 cloudsqlsuperuser에 속하지 않는지 확인합니다. 속하면 ErrRuntimeHasSuperuser입니다.
// cloudsqlsuperuser가 없는 DB(local, 테스트)에서는 확인할 것이 없어 nil입니다.
func CheckRuntimeNotSuperuser(ctx context.Context, pool *pgxpool.Pool, member string) error {
	// pg_has_role은 없는 역할에 오류를 내고 AND는 평가 순서를 보장하지 않으므로, 역할이 있을 때만 CASE로 묻습니다.
	var isMember bool
	err := pool.QueryRow(ctx, `
		SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = $2)
		            THEN pg_has_role($1, $2, 'MEMBER')
		            ELSE false END`, member, cloudSQLSuperuser).Scan(&isMember)
	if err != nil {
		return fmt.Errorf("%s 소속 확인: %w", cloudSQLSuperuser, err)
	}
	if isMember {
		return ErrRuntimeHasSuperuser
	}
	return nil
}

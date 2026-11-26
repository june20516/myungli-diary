package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// OpsRole은 운영 API 서비스(server-ops)가 쓰는 권한 묶음입니다(migration 00029, #1321).
const OpsRole = "myungli_ops"

// 역할 분리 검사가 돌려주는 오류입니다. 오류 문구에는 역할 이름을 넣지 않습니다(로그에 남겨도 되게).
var (
	// ErrRuntimeInOpsRole은 런타임 DB 사용자가 OpsRole 구성원이라는 뜻입니다.
	ErrRuntimeInOpsRole = errors.New("런타임 DB 사용자가 운영자 역할 구성원입니다")
	// ErrOpsInAppRole은 운영 API DB 사용자가 AppRole 구성원이라는 뜻입니다.
	ErrOpsInAppRole = errors.New("운영 API DB 사용자가 앱 역할 구성원입니다")
	// ErrUnexpectedOpsMember는 OpsRole에 지정한 운영 API DB 사용자 밖의 직접 구성원이 있다는 뜻입니다.
	ErrUnexpectedOpsMember = errors.New("운영자 역할에 지정하지 않은 구성원이 있습니다")
)

// GrantOpsUser는 DB 사용자 member를 OpsRole의 구성원으로 둡니다. 이미 구성원이면 바뀌는 것이 없습니다.
// migration을 적용한 계정(OpsRole을 만든 계정)으로 부릅니다. member는 이미 있어야 합니다(Cloud SQL IAM 서비스 계정 사용자는 Terraform이 만듦).
func GrantOpsUser(ctx context.Context, pool *pgxpool.Pool, member string) error {
	if member == "" {
		return errors.New("권한을 줄 DB 사용자 이름이 비어 있습니다")
	}
	statement := "GRANT " + pgx.Identifier{OpsRole}.Sanitize() + " TO " + pgx.Identifier{member}.Sanitize()
	if _, err := pool.Exec(ctx, statement); err != nil {
		return fmt.Errorf("%s 구성원 지정: %w", OpsRole, withoutRoleName(err))
	}
	return nil
}

// withoutRoleName은 PostgreSQL 오류를 SQLSTATE 코드만 남긴 오류로 바꿉니다. 오류 문구에는 역할 이름이 들어가 로그에 남기면 안 됩니다.
func withoutRoleName(err error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return fmt.Errorf("SQLSTATE %s", pgErr.Code)
	}
	return err
}

// CheckRoleSeparation은 런타임과 운영 API의 DB 사용자가 서로의 권한을 갖지 않는지 확인합니다.
//   - runtimeUser가 OpsRole 구성원이면 ErrRuntimeInOpsRole
//   - opsUser가 AppRole 구성원이면 ErrOpsInAppRole
//   - OpsRole의 직접 구성원 중 opsUser 밖이 있으면 ErrUnexpectedOpsMember(사람 계정이 몰래 들어오는 것을 막음)
//
// 또 opsUser가 cloudsqlsuperuser 구성원이면 ErrRuntimeHasSuperuser입니다(런타임과 같은 기준).
// 오류에 역할 이름을 담지 않으므로 호출자는 그대로 로그에 남겨도 됩니다.
func CheckRoleSeparation(ctx context.Context, pool *pgxpool.Pool, runtimeUser, opsUser string) error {
	runtimeInOps, err := hasRole(ctx, pool, runtimeUser, OpsRole)
	if err != nil {
		return err
	}
	if runtimeInOps {
		return ErrRuntimeInOpsRole
	}
	opsInApp, err := hasRole(ctx, pool, opsUser, AppRole)
	if err != nil {
		return err
	}
	if opsInApp {
		return ErrOpsInAppRole
	}
	if err := CheckRuntimeNotSuperuser(ctx, pool, opsUser); err != nil {
		return err
	}

	var others int
	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM pg_auth_members m
		JOIN pg_roles member ON member.oid = m.member
		WHERE m.roleid = $1::regrole AND member.rolname <> $2`, pgx.Identifier{OpsRole}.Sanitize(), opsUser).Scan(&others)
	if err != nil {
		return fmt.Errorf("%s 구성원 확인: %w", OpsRole, err)
	}
	if others > 0 {
		return fmt.Errorf("%w: %d명", ErrUnexpectedOpsMember, others)
	}
	return nil
}

// hasRole은 member가 role의 구성원(상속 포함)인지 묻습니다.
func hasRole(ctx context.Context, pool *pgxpool.Pool, member, role string) (bool, error) {
	var isMember bool
	if err := pool.QueryRow(ctx, `SELECT pg_has_role($1, $2, 'MEMBER')`, member, role).Scan(&isMember); err != nil {
		return false, fmt.Errorf("%s 소속 확인: %w", role, withoutRoleName(err))
	}
	return isMember, nil
}

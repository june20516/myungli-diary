package postgres

import (
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

// PostgreSQL 오류 문구(역할 이름 포함)는 새 오류에 들어가지 않고, SQLSTATE와 순번만 남습니다.
func TestGrantOpsRoleError_DropsPostgresMessage(t *testing.T) {
	pgErr := &pgconn.PgError{Code: "42704", Message: `role "op@example.com" does not exist`}

	got := grantOpsRoleError(1, pgErr)

	if strings.Contains(got.Error(), "op@example.com") || errors.Is(got, pgErr) {
		t.Errorf("오류에 원문이 남았습니다: %v", got)
	}
	for _, want := range []string{"2번째 대상", "42704", OpsRole} {
		if !strings.Contains(got.Error(), want) {
			t.Errorf("오류 %q에 %q가 없습니다", got, want)
		}
	}
}

// PostgreSQL 오류가 아니면(연결 끊김 등) 원인을 감쌉니다.
func TestGrantOpsRoleError_WrapsOtherErrors(t *testing.T) {
	cause := errors.New("연결 끊김")
	if got := grantOpsRoleError(0, cause); !errors.Is(got, cause) {
		t.Errorf("원인을 감싸지 않았습니다: %v", got)
	}
}

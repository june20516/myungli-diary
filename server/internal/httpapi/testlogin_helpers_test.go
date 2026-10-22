package httpapi_test

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// testLoginPath와 testLoginSecretHeader는 staging 테스트 로그인(S24)의 경로와 비밀 헤더입니다.
const (
	testLoginPath         = "/test/v1/auth/login"
	testLoginSecretHeader = "X-Test-Login-Secret" //nolint:gosec // 헤더 이름이며 비밀 값이 아닙니다
)

// realAuth는 실제 DB 위의 인증·계정 서비스입니다. 제공자 검증은 쓰지 않으므로 카카오·Apple 의존성은 비워 둡니다.
type realAuth struct {
	pool     *pgxpool.Pool
	auth     *auth.Service
	accounts *account.Service
	access   *token.AccessIssuer
}

// noopRevoker는 허가 취소를 시도하지 않는 account.Revoker 대역입니다.
type noopRevoker struct{}

func (noopRevoker) Attempt(context.Context, []int64) {}

func newRealAuth(t *testing.T) realAuth {
	t.Helper()
	pool := dbtest.New(t)
	clk := clocktest.New(handlerNow)
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	access, err := token.NewAccessIssuer(token.SigningKey{ID: "k1", Private: priv}, nil, clk)
	require.NoError(t, err)
	box, err := secretbox.New(secretbox.Key{ID: "b1", Bytes: bytes.Repeat([]byte{7}, 32)}, nil)
	require.NoError(t, err)
	authService := auth.NewService(pool, auth.ServiceDeps{Access: access, Box: box, Clock: clk})
	return realAuth{pool: pool, auth: authService, accounts: account.NewService(pool, noopRevoker{}, clk), access: access}
}

// countTestIdentities는 provider test 연결 수입니다.
func (r realAuth) countTestIdentities(t *testing.T) int {
	t.Helper()
	var count int
	require.NoError(t, r.pool.QueryRow(t.Context(), `SELECT count(*) FROM auth_identities WHERE provider = 'test'`).Scan(&count))
	return count
}

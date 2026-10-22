package cli

import (
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// retention이 시각이 된 허가 취소 대기 행을 제공자 대역에 보내고 지운다.
func TestJobRetention_RunsRevocationRetry(t *testing.T) {
	fake := providertest.New(t)
	clk := clocktest.New(time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC))
	fake.SetClock(clk)
	pool := dbtest.New(t)
	authCfg := flowAuthConfig(t)
	cfg := config.RevocationConfig{
		TokenKeyID: authCfg.TokenKeyID, TokenKey: authCfg.TokenKey, KakaoAdminKey: authCfg.KakaoAdminKey,
		AppleTeamID: authCfg.AppleTeamID, AppleKeyID: authCfg.AppleKeyID, ApplePrivateKeyPEM: authCfg.ApplePrivateKeyPEM,
	}
	_, err := pool.Exec(t.Context(),
		`INSERT INTO provider_revocations (provider, subject, identity_id, next_attempt_at, created_at)
		 VALUES ('kakao', 'kakao-1', $1, $2, $2)`, uuid.Must(uuid.NewV7()), clk.Now())
	require.NoError(t, err)

	err = retention(t.Context(), cfg, retentionDeps{
		Pool:   pool,
		Clock:  clk,
		Logger: slog.New(slog.DiscardHandler),
		HTTP:   fake.Client(),
		Providers: providerURLs{
			KakaoJWKS:   fake.JWKSURL(),
			KakaoUnlink: fake.KakaoUnlinkURL(),
			AppleJWKS:   fake.JWKSURL(),
			AppleToken:  fake.AppleTokenURL(),
			AppleRevoke: fake.AppleRevokeURL(),
		},
	})

	require.NoError(t, err)
	unlinks := fake.KakaoUnlinkRequests()
	require.Len(t, unlinks, 1)
	assert.Equal(t, "kakao-1", unlinks[0].Form.Get("target_id"))
	var rows int
	require.NoError(t, pool.QueryRow(t.Context(), `SELECT count(*) FROM provider_revocations`).Scan(&rows))
	assert.Zero(t, rows)
}

// job retention은 더 이상 not implemented가 아니라 설정을 읽는 단계부터 실행한다.
func TestRun_RetentionWithoutDatabaseURL_Exits1WithConfigError(t *testing.T) {
	code, stderr := runCLI(t, "job", "retention")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "DATABASE_URL")
	assert.NotContains(t, stderr, "not implemented")
}

// serve 설정(JWT 서명 키, 제공자 앱 ID 등) 없이 허가 취소 설정과 DB만으로 설정 읽기, DB 연결, 재시도가 끝나고 종료 코드 0입니다.
func TestRun_RetentionSucceedsWithOnlyRevocationSettings(t *testing.T) {
	authCfg := flowAuthConfig(t)
	env := map[string]string{
		"DATABASE_URL":            dbtest.NewURL(t),
		"TOKEN_ENCRYPTION_KEY_ID": authCfg.TokenKeyID,
		"TOKEN_ENCRYPTION_KEY":    authCfg.TokenKey,
		"KAKAO_ADMIN_KEY":         authCfg.KakaoAdminKey,
		"APPLE_TEAM_ID":           authCfg.AppleTeamID,
		"APPLE_KEY_ID":            authCfg.AppleKeyID,
		"APPLE_PRIVATE_KEY":       authCfg.ApplePrivateKeyPEM,
	}

	code, _, stderr := runCLIWithEnv(t, env, "job", "retention")

	assert.Equal(t, 0, code, "stderr: %s", stderr)
	assert.Contains(t, stderr, "허가 취소 재시도 완료")
}

// 허가 취소 설정이 빠지면 DB에 연결하기 전에 변수 이름과 함께 실패한다.
func TestRun_RetentionMissingRevocationSettings_Exits1(t *testing.T) {
	code, _, stderr := runCLIWithEnv(t, map[string]string{"DATABASE_URL": "postgres://127.0.0.1:1/x"}, "job", "retention")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "KAKAO_ADMIN_KEY")
}

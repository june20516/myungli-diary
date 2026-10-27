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
		// retention은 허가 취소 주소만 씁니다.
		Providers: providerURLs{
			KakaoUnlink: fake.KakaoUnlinkURL(),
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

// retention이 24시간 지난 합치기 영수증만 지운다(S115).
func TestJobRetention_DeletesExpiredMergeReceipts(t *testing.T) {
	fake := providertest.New(t)
	clk := clocktest.New(time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC))
	fake.SetClock(clk)
	pool := dbtest.New(t)
	authCfg := flowAuthConfig(t)
	cfg := config.RevocationConfig{
		TokenKeyID: authCfg.TokenKeyID, TokenKey: authCfg.TokenKey, KakaoAdminKey: authCfg.KakaoAdminKey,
		AppleTeamID: authCfg.AppleTeamID, AppleKeyID: authCfg.AppleKeyID, ApplePrivateKeyPEM: authCfg.ApplePrivateKeyPEM,
	}
	var accountID uuid.UUID
	require.NoError(t, pool.QueryRow(t.Context(),
		`INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id`).Scan(&accountID))
	for i, mergedAt := range []time.Time{clk.Now().Add(-24 * time.Hour), clk.Now().Add(-24*time.Hour + time.Second)} {
		_, err := pool.Exec(t.Context(), `INSERT INTO account_merge_receipts (token_hash, account_id, merged_at) VALUES ($1, $2, $3)`,
			[]byte{byte(i)}, accountID, mergedAt)
		require.NoError(t, err)
	}

	err := retention(t.Context(), cfg, retentionDeps{
		Pool:      pool,
		Clock:     clk,
		Logger:    slog.New(slog.DiscardHandler),
		HTTP:      fake.Client(),
		Providers: providerURLs{KakaoUnlink: fake.KakaoUnlinkURL(), AppleRevoke: fake.AppleRevokeURL()},
	})

	require.NoError(t, err)
	var kept []byte
	require.NoError(t, pool.QueryRow(t.Context(), `SELECT token_hash FROM account_merge_receipts`).Scan(&kept), "하나만 남습니다")
	assert.Equal(t, []byte{1}, kept, "24시간이 안 된 영수증은 남깁니다")
}

// 허가 취소 설정이 잘못돼 그 단계가 실패해도 합치기 영수증 정리는 먼저 끝냅니다(보관 기간 약속, S115).
func TestJobRetention_DeletesMergeReceiptsEvenWhenRevocationConfigFails(t *testing.T) {
	clk := clocktest.New(time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC))
	pool := dbtest.New(t)
	var accountID uuid.UUID
	require.NoError(t, pool.QueryRow(t.Context(),
		`INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id`).Scan(&accountID))
	_, err := pool.Exec(t.Context(), `INSERT INTO account_merge_receipts (token_hash, account_id, merged_at) VALUES ($1, $2, $3)`,
		[]byte{0}, accountID, clk.Now().Add(-25*time.Hour))
	require.NoError(t, err)

	err = retention(t.Context(), config.RevocationConfig{TokenKeyID: "k1", TokenKey: "not-base64"}, retentionDeps{
		Pool:   pool,
		Clock:  clk,
		Logger: slog.New(slog.DiscardHandler),
	})

	require.Error(t, err)
	var rows int
	require.NoError(t, pool.QueryRow(t.Context(), `SELECT count(*) FROM account_merge_receipts`).Scan(&rows))
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

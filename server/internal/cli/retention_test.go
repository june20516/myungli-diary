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
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

// retention이 시각이 된 허가 취소 대기 행을 제공자 대역에 보내고 지운다.
func TestJobRetention_RunsRevocationRetry(t *testing.T) {
	fake := providertest.New(t)
	clk := clocktest.New(time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC))
	fake.SetClock(clk)
	pool := dbtest.New(t)
	settings, err := parseAuthSettings(flowAuthConfig(t))
	require.NoError(t, err)
	_, err = pool.Exec(t.Context(),
		`INSERT INTO provider_revocations (provider, subject, identity_id, next_attempt_at, created_at)
		 VALUES ('kakao', 'kakao-1', $1, $2, $2)`, uuid.Must(uuid.NewV7()), clk.Now())
	require.NoError(t, err)

	err = retention(t.Context(), settings, retentionDeps{
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

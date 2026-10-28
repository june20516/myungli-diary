package cli

import (
	"bytes"
	"context"
	"log/slog"
	"net"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"

	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
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
		Engine: &enginetest.Fake{},
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
		Engine:    &enginetest.Fake{},
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
		Engine: &enginetest.Fake{},
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

	env["ENGINE_ADDR"] = startInfoEngine(t, "rs-1")

	code, _, stderr := runCLIWithEnv(t, env, "job", "retention")

	assert.Equal(t, 0, code, "stderr: %s", stderr)
	assert.Contains(t, stderr, "허가 취소 재시도 완료")
	assert.Contains(t, stderr, "이전 ruleset_version 캐시")
}

// 엔진 설정이 빠지면 이전 버전 캐시 정리만 실패하고, 법정 보관 기간 정리와 허가 취소 재시도는 끝낸 뒤 job이 실패로 끝난다.
func TestRun_RetentionMissingEngineAddr_RunsOtherStepsAndExits1(t *testing.T) {
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

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "ENGINE_ADDR")
	assert.Contains(t, stderr, "결제 기록 완료")
	assert.Contains(t, stderr, "허가 취소 재시도 완료")
}

// infoEngine은 GetInfo만 답하는 엔진 gRPC 대역입니다.
type infoEngine struct {
	enginev1.UnimplementedMyungliEngineServer
	rulesetVersion string
}

func (e *infoEngine) GetInfo(context.Context, *enginev1.InfoRequest) (*enginev1.InfoResponse, error) {
	return &enginev1.InfoResponse{EngineVersion: "test", RulesetVersion: e.rulesetVersion}, nil
}

// startInfoEngine은 localhost TCP에 GetInfo 대역을 띄우고 ENGINE_ADDR 값을 돌려줍니다.
func startInfoEngine(t *testing.T, rulesetVersion string) string {
	t.Helper()
	listener, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	require.NoError(t, err)
	server := grpc.NewServer()
	enginev1.RegisterMyungliEngineServer(server, &infoEngine{rulesetVersion: rulesetVersion})
	go func() { _ = server.Serve(listener) }()
	t.Cleanup(server.Stop)
	return listener.Addr().String()
}

// 허가 취소 설정이 빠지면 DB에 연결하기 전에 변수 이름과 함께 실패한다.
func TestRun_RetentionMissingRevocationSettings_Exits1(t *testing.T) {
	code, _, stderr := runCLIWithEnv(t, map[string]string{"DATABASE_URL": "postgres://127.0.0.1:1/x"}, "job", "retention")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "KAKAO_ADMIN_KEY")
}

// newRetentionFixture는 허가 취소 대역, 시계, DB, 허가 취소 설정을 준비합니다.
func newRetentionFixture(t *testing.T) (*providertest.Server, *clocktest.Fake, *pgxpool.Pool, config.RevocationConfig) {
	t.Helper()
	fake := providertest.New(t)
	clk := clocktest.New(time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC))
	fake.SetClock(clk)
	authCfg := flowAuthConfig(t)
	cfg := config.RevocationConfig{
		TokenKeyID: authCfg.TokenKeyID, TokenKey: authCfg.TokenKey, KakaoAdminKey: authCfg.KakaoAdminKey,
		AppleTeamID: authCfg.AppleTeamID, AppleKeyID: authCfg.AppleKeyID, ApplePrivateKeyPEM: authCfg.ApplePrivateKeyPEM,
	}
	return fake, clk, dbtest.New(t), cfg
}

func retentionTestDeps(fake *providertest.Server, clk *clocktest.Fake, pool *pgxpool.Pool, eng engine.Engine) retentionDeps {
	return retentionDeps{
		Pool:      pool,
		Clock:     clk,
		Logger:    slog.New(slog.DiscardHandler),
		HTTP:      fake.Client(),
		Engine:    eng,
		Providers: providerURLs{KakaoUnlink: fake.KakaoUnlinkURL(), AppleRevoke: fake.AppleRevokeURL()},
	}
}

func insertDailyCache(t *testing.T, pool *pgxpool.Pool, n byte, rulesetVersion string, createdAt time.Time) {
	t.Helper()
	_, err := pool.Exec(t.Context(), `INSERT INTO daily_cache (birth_hash, ruleset_version, date, current_timezone, response, created_at)
		VALUES ($1, $2, '2026-10-23', 'Asia/Seoul', '\x00', $3)`, bytes.Repeat([]byte{n}, 32), rulesetVersion, createdAt)
	require.NoError(t, err)
}

func countRows(t *testing.T, pool *pgxpool.Pool, sql string) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(t.Context(), sql).Scan(&n), sql)
	return n
}

// 엔진이 내려가 이전 버전 캐시 정리가 실패해도 다른 단계는 끝내고, job은 실패로 끝나 경보를 받는다.
func TestJobRetention_ContinuesAfterEngineFailure(t *testing.T) {
	fake, clk, pool, cfg := newRetentionFixture(t)
	insertDailyCache(t, pool, 1, "rs-1", clk.Now().Add(-31*24*time.Hour))
	_, err := pool.Exec(t.Context(), `INSERT INTO rate_limits (key, window_start, count) VALUES ('ip', $1, 1)`, clk.Now().Add(-time.Hour))
	require.NoError(t, err)
	_, err = pool.Exec(t.Context(), `INSERT INTO provider_revocations (provider, subject, identity_id, next_attempt_at, created_at)
		VALUES ('kakao', 'kakao-1', $1, $2, $2)`, uuid.Must(uuid.NewV7()), clk.Now())
	require.NoError(t, err)
	down := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) { return nil, engine.ErrUnavailable }}

	err = retention(t.Context(), cfg, retentionTestDeps(fake, clk, pool, down))

	require.ErrorIs(t, err, engine.ErrUnavailable)
	assert.Zero(t, countRows(t, pool, "SELECT count(*) FROM daily_cache"))
	assert.Zero(t, countRows(t, pool, "SELECT count(*) FROM rate_limits"))
	assert.Zero(t, countRows(t, pool, "SELECT count(*) FROM provider_revocations"), "허가 취소 재시도도 돕니다")
}

// 엔진의 지금 ruleset_version이 아닌 캐시를 지운다(spec §8.3).
func TestJobRetention_DeletesStaleRulesetCaches(t *testing.T) {
	fake, clk, pool, cfg := newRetentionFixture(t)
	insertDailyCache(t, pool, 1, "r1", clk.Now())
	insertDailyCache(t, pool, 2, "r2", clk.Now())
	eng := &enginetest.Fake{Info: func() (*enginev1.InfoResponse, error) {
		return &enginev1.InfoResponse{EngineVersion: "e", RulesetVersion: "r2"}, nil
	}}

	require.NoError(t, retention(t.Context(), cfg, retentionTestDeps(fake, clk, pool, eng)))

	assert.Zero(t, countRows(t, pool, "SELECT count(*) FROM daily_cache WHERE ruleset_version = 'r1'"))
	assert.Equal(t, 1, countRows(t, pool, "SELECT count(*) FROM daily_cache WHERE ruleset_version = 'r2'"))
}

// 연결되지 않은 Apple 웹 로그인의 토큰은 같은 실행의 허가 취소 재시도에서 Apple에 revoke된다(S19).
func TestJobRetention_RevokesUnclaimedAppleWebLoginToken(t *testing.T) {
	fake, clk, pool, cfg := newRetentionFixture(t)
	box, err := parseTokenBox(cfg.TokenKeyID, cfg.TokenKey, "", "")
	require.NoError(t, err)
	id := uuid.Must(uuid.NewV7())
	sealed, keyID, err := box.Seal([]byte("apple-refresh"), id[:])
	require.NoError(t, err)
	_, err = pool.Exec(t.Context(), `INSERT INTO apple_web_logins (id, exchange_hash, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id, expires_at)
		VALUES ($1, $2, 'apple-1', repeat('a', 64), $3, $4, 'web.client', $5)`, id, id[:], sealed, keyID, clk.Now().Add(-25*time.Hour))
	require.NoError(t, err)

	require.NoError(t, retention(t.Context(), cfg, retentionTestDeps(fake, clk, pool, &enginetest.Fake{})))

	revokes := fake.AppleRevokeRequests()
	require.Len(t, revokes, 1)
	assert.Equal(t, "apple-refresh", revokes[0].Form.Get("token"))
	assert.Equal(t, "web.client", revokes[0].Form.Get("client_id"))
	assert.Zero(t, countRows(t, pool, "SELECT count(*) FROM apple_web_logins"))
	assert.Zero(t, countRows(t, pool, "SELECT count(*) FROM provider_revocations"))
}

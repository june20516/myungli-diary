package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
)

// rawResult는 테스트 goroutine 밖에서 보낸 요청의 결과입니다(require를 쓰지 않으려고 오류를 함께 담습니다).
type rawResult struct {
	status int
	body   map[string]any
	err    error
}

// postJSON은 require 없이 JSON 본문 요청을 보냅니다. 테스트 goroutine이 아닌 곳에서 씁니다.
func (e *flowEnv) postJSON(ctx context.Context, path, accessToken string, body any) rawResult {
	raw, err := json.Marshal(body)
	if err != nil {
		return rawResult{err: err}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, e.url+path, bytes.NewReader(raw))
	if err != nil {
		return rawResult{err: err}
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err := e.client.Do(req)
	if err != nil {
		return rawResult{err: err}
	}
	defer func() { _ = resp.Body.Close() }()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return rawResult{err: err}
	}
	out := rawResult{status: resp.StatusCode, body: map[string]any{}}
	if len(data) > 0 {
		out.err = json.Unmarshal(data, &out.body)
	}
	return out
}

// 삭제 트랜잭션이 계정 행을 잡은 동안 미들웨어를 통과한 일기 저장은 잠금에서 기다리고, 삭제가 commit되면
// 401 auth.token_invalid로 끝나며 껍데기 계정에 행을 남기지 않습니다(S105, Review Focus 1).
func TestService_Delete_ConcurrentWriteGets401(t *testing.T) {
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.Charts = okCharts{}
		deps.Days = fakeDays{}
	})
	login := env.loginKakao("delete-flow-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)
	profileSaved := env.do(http.MethodPut, "/v1/me/profile", access, json.RawMessage(flowProfileBody))
	require.Equal(t, http.StatusOK, profileSaved.status, "프로필 본문: %v", profileSaved.body)
	me := env.do(http.MethodGet, "/v1/me", access, nil)
	require.Equal(t, http.StatusOK, me.status, "me 본문: %v", me.body)
	accountID, err := uuid.Parse(me.body["accountId"].(string))
	require.NoError(t, err)

	// 계정 삭제처럼 계정 행을 잠그고 개인 데이터를 지운 채 commit하지 않습니다.
	tx, err := env.pool.Begin(t.Context())
	require.NoError(t, err)
	t.Cleanup(func() { _ = tx.Rollback(context.Background()) })
	_, err = account.DeleteAccountTx(t.Context(), tx, accountID, env.clk.Now())
	require.NoError(t, err)

	done := make(chan rawResult, 1)
	go func() {
		done <- env.postJSON(t.Context(), "/v1/diaries", access, map[string]any{"date": "2026-10-12", "body": "삭제 중에 쓴 일기"})
	}()

	// 일기 저장이 계정 행 잠금을 기다릴 때까지 기다린 뒤 삭제를 commit합니다.
	require.Eventually(t, func() bool {
		var waiting int
		require.NoError(t, env.pool.QueryRow(t.Context(), `SELECT count(*) FROM pg_stat_activity
			WHERE datname = current_database() AND wait_event_type = 'Lock'`).Scan(&waiting))
		return waiting == 1
	}, 10*time.Second, 20*time.Millisecond)
	require.NoError(t, tx.Commit(t.Context()))

	got := <-done
	require.NoError(t, got.err)
	require.Equal(t, http.StatusUnauthorized, got.status, "본문: %v", got.body)
	assert.Equal(t, "auth.token_invalid", got.body["code"])

	for _, table := range []string{"diaries", "diary_days"} {
		var n int
		require.NoError(t, env.pool.QueryRow(t.Context(), `SELECT count(*) FROM `+table+` WHERE account_id = $1`, accountID).Scan(&n))
		assert.Zero(t, n, "%s에 새 행이 없습니다", table)
	}
}

//go:build staging

package auth_test

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
)

func TestValidTestLabel(t *testing.T) {
	for _, label := range []string{"a", "E2E01", strings.Repeat("z", 32)} {
		assert.True(t, auth.ValidTestLabel(label), label)
	}
	for _, label := range []string{"", strings.Repeat("z", 33), "e2e-01", "e2e 01", "가나", "e2e01\n"} {
		assert.False(t, auth.ValidTestLabel(label), label)
	}
}

// 같은 label은 같은 계정이고, 계정 찾기·만들기·토큰 발급은 정상 로그인과 같습니다(S24).
func TestLoginTest_FindsOrCreatesTestIdentity(t *testing.T) {
	f := newFixture(t)

	first, err := f.service.LoginTest(f.ctx, "e2e01")
	require.NoError(t, err)
	assert.True(t, first.IsNewAccount)
	assert.NotEmpty(t, first.Tokens.AccessToken)
	assert.NotEmpty(t, first.Tokens.RefreshToken)

	again, err := f.service.LoginTest(f.ctx, "e2e01")
	require.NoError(t, err)
	assert.False(t, again.IsNewAccount)
	assert.Equal(t, first.AccountID, again.AccountID)
	assert.NotEqual(t, first.Tokens.RefreshToken, again.Tokens.RefreshToken, "로그인마다 새 refresh family입니다")

	other, err := f.service.LoginTest(f.ctx, "e2e02")
	require.NoError(t, err)
	assert.NotEqual(t, first.AccountID, other.AccountID)

	var provider, subject string
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT provider, subject FROM auth_identities WHERE account_id = $1`, first.AccountID).Scan(&provider, &subject))
	assert.Equal(t, "test", provider)
	assert.Equal(t, "e2e01", subject)
}

// 카카오 subject와 같은 문자열이어도 provider가 달라 다른 계정입니다.
func TestLoginTest_DoesNotReuseOtherProviderSubject(t *testing.T) {
	f := newFixture(t)
	kakao := f.loginKakao(t, "shared1")

	res, err := f.service.LoginTest(f.ctx, "shared1")
	require.NoError(t, err)
	assert.NotEqual(t, kakao.AccountID, res.AccountID)
}

// 삭제 대기 계정은 정상 로그인처럼 되살리고 이전 세션을 폐기합니다.
func TestLoginTest_RestoresPendingDeletion(t *testing.T) {
	f := newFixture(t)
	first, err := f.service.LoginTest(f.ctx, "e2e01")
	require.NoError(t, err)
	f.requestDeletion(t, first.AccountID)

	res, err := f.service.LoginTest(f.ctx, "e2e01")
	require.NoError(t, err)
	assert.True(t, res.RestoredFromDeletion)
	assert.Equal(t, first.AccountID, res.AccountID)

	_, err = f.service.Refresh(f.ctx, first.Tokens.RefreshToken)
	require.Error(t, err, "복구 전 세션은 폐기됩니다")
}

// 핸들러를 거치지 않은 호출도 형식이 틀린 label은 DB에 닿기 전에 거절합니다.
func TestLoginTest_RejectsInvalidLabel(t *testing.T) {
	f := newFixture(t)
	_, err := f.service.LoginTest(f.ctx, "bad-label")
	require.ErrorIs(t, err, auth.ErrTestLabelInvalid)

	var count int
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT count(*) FROM auth_identities`).Scan(&count))
	assert.Zero(t, count)
}

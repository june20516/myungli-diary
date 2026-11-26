//go:build unix

package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCheckOpsFileOwner(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ops-oauth.json")
	require.NoError(t, os.WriteFile(path, []byte("{}"), 0o600))
	info, err := os.Stat(path)
	require.NoError(t, err)

	assert.NoError(t, checkOpsFileOwner(info, os.Getuid()))
	err = checkOpsFileOwner(info, os.Getuid()+1)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "실행 사용자의 파일이 아닙니다")
	assert.NotContains(t, err.Error(), "{}", "오류에 파일 내용을 넣지 않습니다")
}

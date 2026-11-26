//go:build unix

package cli

import (
	"os"
	"path/filepath"
	"syscall"
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

// ensureOpsDir가 없는 폴더를 0700으로 만드는지 봅니다. 만든 권한은 umask에 따라 줄어들므로 시험 동안 umask를 022로
// 고정하고 끝나면 되돌립니다. umask는 프로세스 전체 값이라 이 시험은 t.Parallel을 쓰지 않습니다(이 패키지에 병렬 시험 없음).
func TestOpsLogin_CreatesMissingDirPrivate(t *testing.T) {
	previous := syscall.Umask(0o022)
	t.Cleanup(func() { syscall.Umask(previous) })

	dir := filepath.Join(t.TempDir(), "server", "staging")
	require.NoError(t, ensureOpsDir(dir))
	info, err := os.Stat(dir)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o700), info.Mode().Perm())
}

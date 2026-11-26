//go:build unix

package cli

import (
	"errors"
	"io/fs"
	"syscall"
)

// checkOpsFileOwner는 자격 파일의 소유자가 실행 사용자(uid)인지 확인합니다.
// 다른 사용자가 만든 파일의 refresh token으로 호출하지 않으려는 것입니다.
func checkOpsFileOwner(info fs.FileInfo, uid int) error {
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return errors.New("파일 소유자를 확인할 수 없습니다")
	}
	if int64(stat.Uid) != int64(uid) {
		return errors.New("실행 사용자의 파일이 아닙니다. 본인 계정으로 server ops login을 다시 실행하세요")
	}
	return nil
}

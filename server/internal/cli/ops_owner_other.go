//go:build !unix

package cli

import "io/fs"

// checkOpsFileOwner는 unix 계열이 아닌 OS에서는 소유자를 검사하지 않습니다.
// 운영 CLI는 macOS와 Linux에서 돌고, 다른 OS는 파일 권한 모델이 달라 uid로 비교할 수 없습니다.
func checkOpsFileOwner(fs.FileInfo, int) error {
	return nil
}

package engine_test

import (
	"os"
	"regexp"
	"testing"

	"github.com/stretchr/testify/require"
)

// 엔진 Cloud Run 서비스의 동시 요청 수는 엔진 gRPC 서버의 worker 수와 같아야 합니다(#817 ②).
// 크면 남는 요청이 엔진 안에서 줄을 서고 증설이 늦어지며, 작으면 worker가 놉니다.
func TestEngineConcurrency_MatchesCoreWorkers(t *testing.T) {
	workers := firstMatch(t, "../../../core/src/myungli_engine/grpc_api/server.py", `(?m)^MAX_WORKERS: Final = (\d+)$`)
	concurrency := firstMatch(t, "../../deploy/terraform/env/run.tf", `(?m)^\s*max_instance_request_concurrency = (\d+)$`)

	require.Equal(t, workers, concurrency, "엔진 서비스의 max_instance_request_concurrency를 core MAX_WORKERS와 맞춰 주세요")
}

// firstMatch는 파일에서 pattern의 첫 묶음을 돌려줍니다. 하나만 있어야 합니다.
func firstMatch(t *testing.T, path, pattern string) string {
	t.Helper()
	body, err := os.ReadFile(path) //nolint:gosec // 테스트가 고정한 저장소 안 경로
	require.NoError(t, err)
	matches := regexp.MustCompile(pattern).FindAllSubmatch(body, -1)
	require.Len(t, matches, 1, "%s에서 %s가 정확히 하나여야 합니다", path, pattern)
	return string(matches[0][1])
}

package engine_test

import (
	"testing"

	"github.com/stretchr/testify/require"
)

// 엔진 배포 관문은 server 서비스가 Terraform이 처음 만든 자리표시 이미지면 받는 쪽이 없다고 보고 통과합니다(#848, D110).
// 두 곳의 이미지 값이 어긋나면 관문이 자리표시를 실제 server로 읽어 멈춥니다.
func TestDeployGate_PlaceholderMatchesTerraform(t *testing.T) {
	terraform := firstMatch(t, "../../deploy/terraform/env/main.tf", `(?m)^\s*placeholder_image = "([^"]+)"$`)
	workflow := firstMatch(t, "../../../.github/workflows/deploy-engine-env.yml", `(?m)^\s*placeholder_image="([^"]+)"$`)

	require.Equal(t, terraform, workflow, "deploy-engine-env.yml의 placeholder_image를 env/main.tf와 맞춰 주세요")
}

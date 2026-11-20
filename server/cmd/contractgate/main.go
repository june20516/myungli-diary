// Command contractgate는 REST 계약 변경이 이미 나간 앱 빌드를 깨는지 기준 commit과 비교해 판정합니다(D138, S165).
//
// server 디렉터리에서 실행합니다. 기준 계약과 tfvars는 git에서 꺼내고, 새 계약과 tfvars는 작업 트리의 파일입니다.
//
//	go run ./cmd/contractgate -base origin/staging
//
// 깨는 변경이 있고 staging과 prod의 최소 앱 버전을 모두 올리지 않았으면 종료 코드 1입니다.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/june20516/myungli-diary/server/internal/contractgate"
)

// oasdiffModule은 깨는 변경 후보를 찾는 도구입니다. 버전을 고정하고 Go checksum DB가 받은 코드를 확인합니다.
// server 모듈과 kin-openapi 버전이 달라 go.mod의 tool로 넣지 않고 go run module@version으로 따로 빌드합니다.
const oasdiffModule = "github.com/oasdiff/oasdiff@v1.38.0"

const (
	specPath  = "api/openapi.yaml"
	tfvarsDir = "deploy/terraform/env"
)

// minVersionEnvs는 최소 앱 버전을 함께 올려야 하는 환경입니다. 테스터 빌드는 staging, 출시 빌드는 prod를 봅니다.
var minVersionEnvs = []string{"staging", "prod"}

func main() {
	base := flag.String("base", "origin/staging", "비교 기준 git revision")
	flag.Parse()
	code, err := run(context.Background(), *base, os.Stdout)
	if err != nil {
		fmt.Fprintln(os.Stderr, "contractgate:", err)
		os.Exit(2)
	}
	os.Exit(code)
}

func run(ctx context.Context, base string, out io.Writer) (int, error) {
	baseSpec, err := gitShow(ctx, base, specPath)
	if err != nil {
		return 0, err
	}
	headSpec, err := os.ReadFile(specPath)
	if err != nil {
		return 0, err
	}
	changes, err := oasdiff(ctx, baseSpec)
	if err != nil {
		return 0, err
	}
	result, err := contractgate.Evaluate(changes, baseSpec, headSpec)
	if err != nil {
		return 0, err
	}

	for _, finding := range result.OpenEnumAdditions {
		_, _ = fmt.Fprintf(out, "통과(열린 enum %s): %s %s\n", finding.Enum, finding.Change.OperationID, finding.Change.Text)
	}
	if len(result.Breaking) == 0 {
		_, _ = fmt.Fprintf(out, "계약 관문 통과: %s 대비 이미 나간 앱을 깨는 변경이 없습니다(D138).\n", base)
		return 0, nil
	}

	_, _ = fmt.Fprintf(out, "이미 나간 앱 빌드를 깨는 계약 변경 %d건(%s 대비, D138):\n", len(result.Breaking), base)
	for _, finding := range result.Breaking {
		change := finding.Change
		enum := ""
		if finding.Enum != "" {
			enum = fmt.Sprintf(" [닫힌 enum %s]", finding.Enum)
		}
		_, _ = fmt.Fprintf(out, "  - %s %s %s (%s)%s: %s\n", change.OperationID, change.Operation, change.Path, change.ID, enum, change.Text)
	}

	raised, err := minVersionsRaised(ctx, base)
	if err != nil {
		return 0, err
	}
	if raised {
		_, _ = fmt.Fprintln(out, "계약 관문 통과: staging과 prod의 최소 앱 버전(iOS, Android)을 모두 올렸습니다(D138 ② 최소 버전 길). 예전 빌드는 업데이트 안내를 받습니다.")
		return 0, nil
	}
	_, _ = fmt.Fprint(out, `계약 관문 실패. 꼭 깨야 하면 셋 중 하나로 가고 PR 본문에 고른 길을 적습니다(D138 ②):
  1. 그 enum을 먼저 열린 enum으로 바꾸는 계약 변경을 내고, 그 계약을 아는 앱이 배포된 뒤 값을 더합니다.
  2. 같은 PR에서 staging.tfvars와 prod.tfvars의 APP_MIN_VERSION_IOS, APP_MIN_VERSION_ANDROID를 모두 올립니다(최후 수단).
  3. /v2 경로를 새로 엽니다.
`)
	return 1, nil
}

// oasdiff는 기준 계약과 작업 트리 계약을 oasdiff breaking으로 비교한 변경 목록입니다.
func oasdiff(ctx context.Context, baseSpec []byte) ([]contractgate.Change, error) {
	dir, err := os.MkdirTemp("", "contractgate")
	if err != nil {
		return nil, err
	}
	defer func() { _ = os.RemoveAll(dir) }()
	basePath := filepath.Join(dir, "base.yaml")
	if err := os.WriteFile(basePath, baseSpec, 0o600); err != nil {
		return nil, err
	}
	cmd := exec.CommandContext(ctx, "go", "run", oasdiffModule, "breaking", basePath, specPath, "--format", "json") //nolint:gosec // 고정 모듈과 이 명령이 만든 임시 파일 경로입니다.
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("oasdiff breaking: %w", err)
	}
	var changes []contractgate.Change
	if err := json.Unmarshal(output, &changes); err != nil {
		return nil, fmt.Errorf("oasdiff 출력: %w", err)
	}
	return changes, nil
}

// minVersionsRaised는 minVersionEnvs의 tfvars 모두에서 최소 앱 버전을 올렸는지 봅니다.
func minVersionsRaised(ctx context.Context, base string) (bool, error) {
	for _, env := range minVersionEnvs {
		path := filepath.Join(tfvarsDir, env+".tfvars")
		baseTfvars, err := gitShow(ctx, base, path)
		if err != nil {
			return false, err
		}
		headTfvars, err := os.ReadFile(path) //nolint:gosec // 고정한 환경 이름으로 만든 저장소 안 경로입니다.
		if err != nil {
			return false, err
		}
		baseVersions, err := contractgate.MinVersions(baseTfvars)
		if err != nil {
			return false, fmt.Errorf("기준 %s: %w", path, err)
		}
		headVersions, err := contractgate.MinVersions(headTfvars)
		if err != nil {
			return false, fmt.Errorf("%s: %w", path, err)
		}
		if !contractgate.MinVersionsRaised(baseVersions, headVersions) {
			return false, nil
		}
	}
	return true, nil
}

// gitShow는 기준 revision의 파일 내용입니다. path는 server 디렉터리 기준입니다.
func gitShow(ctx context.Context, revision, path string) ([]byte, error) {
	output, err := exec.CommandContext(ctx, "git", "show", revision+":./"+path).Output() //nolint:gosec // 실행한 사람이 준 비교 기준과 고정 경로입니다.
	if err != nil {
		return nil, fmt.Errorf("git show %s:%s: %w", revision, path, err)
	}
	return output, nil
}

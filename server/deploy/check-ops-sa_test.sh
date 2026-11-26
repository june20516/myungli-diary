#!/usr/bin/env bash
# check-ops-sa.sh를 고정 JSON(testdata/check-ops-sa/)으로 시험합니다. gcloud를 부르지 않습니다.
# server.yml이 돌리고, 로컬에서는 `bash server/deploy/check-ops-sa_test.sh`로 돌립니다(jq 필요).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/check-ops-sa.sh"
data="$here/testdata/check-ops-sa"
failures=0

# run_case <이름> <기대 종료 코드> <서비스 계정 정책> <프로젝트 정책> [출력에 있어야 할 글자...]
# 사람 메일(@example.com)과 메일 앞부분이 출력에 남지 않는지도 늘 확인합니다.
run_case() {
  local name="$1" want="$2" sa="$3" project="$4"
  shift 4
  local out code=0
  out="$(GITHUB_STEP_SUMMARY='' OPS_SA_POLICY_FILE="$data/$sa" PROJECT_POLICY_FILE="$data/$project" \
    bash "$script" test-project 2>&1)" || code=$?
  local ok=true
  if [ "$code" -ne "$want" ]; then
    echo "실패 [$name]: 종료 코드 $code, 기대 $want"
    ok=false
  fi
  if grep -qE 'example\.com|someone|owner@|operator@|ops-team|gone@' <<< "$out"; then
    echo "실패 [$name]: 사람 메일이 출력에 남았습니다"
    ok=false
  fi
  local expected
  for expected in "$@"; do
    if ! grep -qF -- "$expected" <<< "$out"; then
      echo "실패 [$name]: 출력에 '$expected'가 없습니다"
      ok=false
    fi
  done
  if [ "$ok" = true ]; then
    echo "통과 [$name]"
  else
    echo "--- 출력 ---"
    echo "$out"
    failures=$((failures + 1))
  fi
}

run_case "정상" 0 sa-ok.json project-ok.json "검사 통과"
run_case "서비스 계정 정책이 비어 있음" 0 sa-empty.json project-ok.json "검사 통과"
run_case "deployer의 프로젝트 단위 serviceAccountUser 예외" 0 sa-ok.json project-deployer-only.json "검사 통과"
run_case "서비스 계정 정책에 다른 주체" 1 sa-other-principal.json project-ok.json \
  "roles/iam.serviceAccountUser user:(가림)" \
  "roles/iam.serviceAccountTokenCreator serviceAccount:server-runtime@test-project.iam.gserviceaccount.com"
run_case "서비스 계정 정책에 deployer의 TokenCreator" 1 sa-deployer-token-creator.json project-ok.json \
  "roles/iam.serviceAccountTokenCreator serviceAccount:deployer@test-project.iam.gserviceaccount.com"
run_case "프로젝트 단위 TokenCreator" 1 sa-ok.json project-token-creator.json \
  "roles/iam.serviceAccountTokenCreator serviceAccount:server-runtime@test-project.iam.gserviceaccount.com"
run_case "프로젝트 단위 serviceAccountUser가 deployer 밖 주체" 1 sa-ok.json project-sa-user-other.json \
  "roles/iam.serviceAccountUser user:(가림)" "roles/iam.serviceAccountUser group:(가림)"
run_case "프로젝트 단위 workloadIdentityUser는 deployer도 예외 아님" 1 sa-ok.json project-deployer-wif.json \
  "roles/iam.workloadIdentityUser serviceAccount:deployer@test-project.iam.gserviceaccount.com" \
  "roles/iam.workloadIdentityUser deleted:user:(가림)"

# 인자가 없으면 사용법 오류(2)입니다.
code=0
bash "$script" > /dev/null 2>&1 || code=$?
if [ "$code" -eq 2 ]; then
  echo "통과 [인자 없음]"
else
  echo "실패 [인자 없음]: 종료 코드 $code, 기대 2"
  failures=$((failures + 1))
fi

# 입력이 JSON이 아니면 통과시키지 않습니다.
code=0
bad="$(mktemp)"
trap 'rm -f "$bad"' EXIT
echo "not json" > "$bad"
OPS_SA_POLICY_FILE="$bad" PROJECT_POLICY_FILE="$data/project-ok.json" bash "$script" test-project > /dev/null 2>&1 || code=$?
if [ "$code" -ne 0 ]; then
  echo "통과 [JSON 아님]"
else
  echo "실패 [JSON 아님]: 통과했습니다"
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "check-ops-sa 시험 실패 ${failures}건"
  exit 1
fi
echo "check-ops-sa 시험 모두 통과"

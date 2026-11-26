#!/usr/bin/env bash
# server-ops 서비스 계정을 빌려 쓸 수 있는 주체가 배포 계정(deployer)뿐인지 검사합니다(#1321, 지휘 검토 1).
# deploy-server-env.yml이 server-ops 갱신 전에 부르고, 실패하면 배포를 멈춥니다.
#
#   check-ops-sa.sh <프로젝트>
#
# ① server-ops 계정의 IAM 정책: deployer의 roles/iam.serviceAccountUser 말고 다른 바인딩이 있으면 실패합니다.
#    (Terraform이 google_service_account_iam_policy로 이 정책 전체를 정하므로, 다른 바인딩은 Terraform 밖에서 생긴 것입니다.)
# ② 프로젝트 IAM 정책: 아래 네 역할을 가진 주체가 있으면 실패합니다. 프로젝트 단위 부여는 프로젝트의 모든 서비스 계정을
#    빌려 쓰게(키 관리 역할은 키를 만들어 그 계정으로 로그인하게) 하므로 server-ops도 포함됩니다.
#      roles/iam.serviceAccountUser, roles/iam.serviceAccountTokenCreator, roles/iam.workloadIdentityUser,
#      roles/iam.serviceAccountKeyAdmin(예외 없음)
#    예외: deployer의 프로젝트 단위 roles/iam.serviceAccountUser 하나. bootstrap deployer_roles가 주는 것이고,
#    모든 Cloud Run 서비스와 Job을 각자의 계정으로 배포하는 actAs에 필요합니다. 서비스 계정 단위로 좁히는 것은
#    bootstrap 변경(사용자 apply)이라 #1321에 제안으로 남깁니다.
# ③ server-ops 계정의 사용자 관리 키: 하나라도 있으면 실패합니다. 키가 있으면 IAM 정책과 상관없이 그 계정으로 로그인할 수 있습니다.
#    출력에는 키 개수만 적고 키 id는 적지 않습니다.
#
# 출력에는 역할과 주체 종류만 적습니다. 서비스 계정은 계정 id까지 보이고, 사람과 그룹 등 그 밖의 주체는 가립니다(D74).
#
# 시험용 입력: OPS_SA_POLICY_FILE, PROJECT_POLICY_FILE, OPS_SA_KEYS_FILE이 있으면 gcloud 대신 그 JSON 파일을 읽습니다
# (check-ops-sa_test.sh). 입력이 JSON 정책이나 키 목록으로 해석되지 않으면 "입력 해석 실패"를 적고 종료 코드 1입니다.
# GITHUB_STEP_SUMMARY가 있으면 실패 내용을 요약에도 적습니다.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "사용법: check-ops-sa.sh <프로젝트>" >&2
  exit 2
fi
project="$1"
if ! command -v jq > /dev/null; then
  echo "jq가 필요합니다" >&2
  exit 1
fi
deployer="serviceAccount:deployer@${project}.iam.gserviceaccount.com"
ops_sa="server-ops@${project}.iam.gserviceaccount.com"

# 서비스 계정 정책을 읽습니다. 시험용 파일이 있으면 그것을, 없으면 gcloud를 씁니다.
ops_sa_policy() {
  if [ -n "${OPS_SA_POLICY_FILE:-}" ]; then
    cat "$OPS_SA_POLICY_FILE"
  else
    gcloud iam service-accounts get-iam-policy "$ops_sa" --project "$project" --format=json
  fi
}

# 프로젝트 정책을 읽습니다. 시험용 파일이 있으면 그것을, 없으면 gcloud를 씁니다.
project_policy() {
  if [ -n "${PROJECT_POLICY_FILE:-}" ]; then
    cat "$PROJECT_POLICY_FILE"
  else
    gcloud projects get-iam-policy "$project" --format=json
  fi
}

# 사용자 관리 키 목록을 읽습니다. 시험용 파일이 있으면 그것을, 없으면 gcloud를 씁니다.
ops_sa_keys() {
  if [ -n "${OPS_SA_KEYS_FILE:-}" ]; then
    cat "$OPS_SA_KEYS_FILE"
  else
    gcloud iam service-accounts keys list --iam-account="$ops_sa" --project "$project" --managed-by=user --format=json
  fi
}

# require_shape <이름> <jq 조건> <JSON>: 입력이 기대한 모양의 JSON이 아니면 고정 문구로 실패합니다.
require_shape() {
  if ! jq -e "$2" <<< "$3" > /dev/null 2>&1; then
    echo "입력 해석 실패: $1" >&2
    exit 1
  fi
}

# mask는 주체를 "종류:값"에서 서비스 계정만 그대로 두고 나머지는 "종류:(가림)"으로 바꿉니다.
# deleted: 접두가 붙은 주체(지운 사용자 등)도 같은 규칙입니다. allUsers처럼 종류만 있는 주체는 그대로입니다.
# shellcheck disable=SC2016 # jq 식이라 $는 셸이 펼치지 않습니다.
jq_mask='def mask:
  if test("^(deleted:)?serviceAccount:") then .
  elif test(":") then sub("^(?<kind>(deleted:)?[^:]+):.*$"; "\(.kind):(가림)")
  else . end;'

# 정책을 셸 변수에 먼저 받아 gcloud 실패가 set -e로 바로 드러나게 합니다.
sa_json="$(ops_sa_policy)"
project_json="$(project_policy)"
keys_json="$(ops_sa_keys)"

require_shape "server-ops 계정 IAM 정책" 'type == "object"' "$sa_json"
require_shape "프로젝트 IAM 정책" 'type == "object"' "$project_json"
require_shape "server-ops 사용자 관리 키 목록" 'type == "array"' "$keys_json"

# shellcheck disable=SC2016
sa_violations="$(jq -r --arg deployer "$deployer" "$jq_mask"'
  [.bindings[]? | .role as $role | .members[]?
    | select(($role == "roles/iam.serviceAccountUser" and . == $deployer) | not)
    | "\($role) \(mask)"] | .[]' <<< "$sa_json")"

# shellcheck disable=SC2016
project_violations="$(jq -r --arg deployer "$deployer" "$jq_mask"'
  ["roles/iam.serviceAccountUser", "roles/iam.serviceAccountTokenCreator", "roles/iam.workloadIdentityUser",
   "roles/iam.serviceAccountKeyAdmin"] as $watched
  | [.bindings[]? | select(.role as $r | $watched | index($r)) | .role as $role | .members[]?
    | select(($role == "roles/iam.serviceAccountUser" and . == $deployer) | not)
    | "\($role) \(mask)"] | .[]' <<< "$project_json")"

user_key_count="$(jq 'length' <<< "$keys_json")"

if [ -z "$sa_violations" ] && [ -z "$project_violations" ] && [ "$user_key_count" -eq 0 ]; then
  echo "server-ops 계정 검사 통과 (${project}): 빌려 쓸 수 있는 주체는 deployer뿐이고 사용자 관리 키가 없습니다."
  exit 0
fi

report() {
  echo "### server-ops 계정 검사 실패 (${project})"
  if [ -n "$sa_violations" ]; then
    echo "server-ops 계정 IAM 정책에 deployer의 roles/iam.serviceAccountUser 말고 다른 바인딩이 있습니다:"
    while IFS= read -r line; do echo "* $line"; done <<< "$sa_violations"
  fi
  if [ -n "$project_violations" ]; then
    echo "프로젝트 IAM 정책에 모든 서비스 계정을 빌려 쓰게 하는 부여가 있습니다:"
    while IFS= read -r line; do echo "* $line"; done <<< "$project_violations"
  fi
  if [ "$user_key_count" -ne 0 ]; then
    echo "server-ops 계정에 사용자 관리 키가 ${user_key_count}개 있습니다. 키를 지워야 합니다."
  fi
  echo "해당 부여를 거둔 뒤 배포를 다시 실행하세요."
}

report >&2
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  report >> "$GITHUB_STEP_SUMMARY"
fi
exit 1

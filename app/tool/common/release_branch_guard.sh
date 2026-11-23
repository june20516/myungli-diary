# shellcheck shell=bash
# 스토어 업로드 스크립트가 source하는 helper입니다(#1285, D141, spec 2026-11-19-branch-split-design §6).
# 출시 빌드(prod 설정)는 main의 승격 커밋에서만 만들고 올립니다. 업로드 스크립트는 올릴 빌드가
# prod 설정이면 현재 브랜치가 main인지 보고, 아니면 멈춥니다.
#
# 설정은 빌드 산출물의 Dart AOT 바이너리(Android libapp.so, iOS App.framework/App)에 들어간
# API_BASE_URL로 가립니다. 업로드 때 따로 받는 인자는 실제 빌드와 어긋날 수 있어 쓰지 않습니다.
# 기준 값은 config/env/<staging|prod>.json(A97)에서 읽습니다. 필요: jq, git.

# 이 파일을 source한 스크립트의 app/ 디렉터리 기준 경로입니다.
release_guard_app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Dart 바이너리가 어느 환경 파일로 빌드됐는지 출력합니다: prod, staging, none(환경 파일 없음).
store_build_env() {
  local dart_binary="$1" env url
  for env in prod staging; do
    url="$(jq -r '.API_BASE_URL // empty' "$release_guard_app_dir/config/env/$env.json")" || return 1
    if [[ -z "$url" ]]; then
      echo "config/env/$env.json에 API_BASE_URL이 없습니다." >&2
      return 1
    fi
    if grep -qaF "$url" "$dart_binary"; then
      echo "$env"
      return 0
    fi
  done
  echo none
}

# prod 빌드면 현재 브랜치가 main인지 확인하고, 아니면 실패합니다. 판별한 환경을 출력합니다.
require_main_for_prod_build() {
  local dart_binary="$1" env branch
  env="$(store_build_env "$dart_binary")" || return 1
  if [[ "$env" == prod ]]; then
    branch="$(git -C "$release_guard_app_dir" rev-parse --abbrev-ref HEAD)" || return 1
    if [[ "$branch" != main ]]; then
      echo "prod 설정 빌드는 main의 승격 커밋에서만 만들어 올립니다(D141). 현재 브랜치: $branch" >&2
      return 1
    fi
  fi
  echo "$env"
}

#!/usr/bin/env bash
# 배포 뒤 server와 엔진의 조합 확인(D147, S169). deploy-server-env.yml과 deploy-engine-env.yml이 부릅니다.
#
#   compose-check.sh versions <프로젝트>
#     그 환경의 server, 엔진 이미지 commit을 요약에 적고, 지금 checkout(HEAD)의 core/, server/ 내용과 다르면 뒤처진 것으로 봅니다.
#     GITHUB_OUTPUT에 engine_behind, server_behind(true|false)를 씁니다. 이미지 태그가 commit이 아니거나
#     그 commit을 저장소에서 찾지 못하면 판단할 수 없어 뒤처진 것으로 봅니다(안전한 쪽). git 이력 전체가 필요합니다(fetch-depth 0).
#
#   compose-check.sh smoke <프로젝트>
#     Job server-smoke(job smoke)를 실행하고 끝날 때까지 기다립니다. Job이 아직 없으면(첫 env apply 전) 건너뜁니다.
#     실패하면 종료 코드 1이고, 되돌리기 명령을 요약에 적습니다. 자동으로 되돌리지는 않습니다(S169 ③).
#
# REGION(기본 asia-northeast3), GITHUB_STEP_SUMMARY, GITHUB_OUTPUT은 workflow가 줍니다. 없으면 표준 출력에 씁니다.
set -euo pipefail

region="${REGION:-asia-northeast3}"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
output="${GITHUB_OUTPUT:-/dev/stdout}"

# image_commit은 Cloud Run 서비스 이미지 태그를 출력합니다. 서비스가 없으면 빈 문자열입니다.
image_commit() {
  local service="$1" project="$2" image
  if ! image="$(gcloud run services describe "$service" --region "$region" --project "$project" \
    --format='value(spec.template.spec.containers[0].image)' 2>/dev/null)"; then
    echo ""
    return
  fi
  echo "${image##*:}"
}

# behind는 commit의 dir 내용이 HEAD의 dir 내용과 다르면(또는 판단할 수 없으면) true를 출력합니다.
behind() {
  local commit="$1" dir="$2" deployed head
  if ! [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo true
    return
  fi
  if ! deployed="$(git rev-parse --verify --quiet "${commit}:${dir}")"; then
    echo true
    return
  fi
  head="$(git rev-parse "HEAD:${dir}")"
  if [ "$deployed" = "$head" ]; then echo false; else echo true; fi
}

versions() {
  local project="$1" server engine server_behind engine_behind
  server="$(image_commit server "$project")"
  engine="$(image_commit engine "$project")"
  server_behind="$(behind "$server" server)"
  engine_behind="$(behind "$engine" core)"
  {
    echo "### 판 맞춤 확인 (${project})"
    echo "| 구성 | 배포된 이미지 | HEAD(${GITHUB_SHA:-$(git rev-parse HEAD)})와 비교 |"
    echo "| --- | --- | --- |"
    echo "| server | \`${server:-없음}\` | $([ "$server_behind" = true ] && echo '뒤처짐(server/ 다름)' || echo '같음') |"
    echo "| 엔진 | \`${engine:-없음}\` | $([ "$engine_behind" = true ] && echo '뒤처짐(core/ 다름)' || echo '같음') |"
  } >> "$summary"
  if [ "$engine_behind" = true ]; then
    echo "::warning title=엔진이 뒤처짐::${project}의 엔진(${engine:-없음})이 HEAD의 core/와 다릅니다(D147 ②)."
  fi
  if [ "$server_behind" = true ]; then
    echo "::warning title=server가 뒤처짐::${project}의 server(${server:-없음})가 HEAD의 server/와 다릅니다(D147 ②)."
  fi
  {
    echo "engine_behind=${engine_behind}"
    echo "server_behind=${server_behind}"
  } >> "$output"
}

smoke() {
  local project="$1"
  if ! gcloud run jobs describe server-smoke --region "$region" --project "$project" --format='value(name)' >/dev/null 2>&1; then
    echo "### 조합 확인 건너뜀 (${project}): Job server-smoke가 아직 없습니다. 다음 deploy-server가 만듭니다." >> "$summary"
    return 0
  fi
  if gcloud run jobs execute server-smoke --wait --region "$region" --project "$project"; then
    echo "### 조합 확인 통과 (${project})" >> "$summary"
    return 0
  fi
  {
    echo "### 조합 확인 실패 (${project})"
    echo "server가 엔진을 불러 화면 문장을 끝까지 만들지 못했습니다. 실패 칸은 Job server-smoke 로그의 \"조합 확인: 문장을 만들지 못함\"에 있습니다."
    echo "자동으로 되돌리지 않았습니다(S169 ③). 되돌리려면 이전 리비전을 찾아 트래픽을 옮깁니다(\`server/docs/runbook/deploy.md\`):"
    echo '```sh'
    echo "gcloud run revisions list --service server --region ${region} --project ${project} --limit 3"
    echo "gcloud run services update-traffic server --to-revisions <이전 리비전>=100 --region ${region} --project ${project}"
    echo '```'
  } >> "$summary"
  return 1
}

case "${1:-}" in
  versions) versions "${2:?프로젝트가 필요합니다}" ;;
  smoke) smoke "${2:?프로젝트가 필요합니다}" ;;
  *)
    echo "usage: compose-check.sh versions|smoke <프로젝트>" >&2
    exit 2
    ;;
esac

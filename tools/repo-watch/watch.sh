#!/usr/bin/env bash
# 요청함(Issue)·PR·main ci-gate 결과(끝난 실행만, 최근 5개) 변화를 1분마다 비교해, 바뀐 것만 한 줄씩 출력합니다.
# 출력 한 줄이 지휘 세션의 알림 하나가 됩니다. 상태는 STATE_DIR에 두어 다시 띄워도 이어집니다.
set -u
REPO=june20516/myungli-diary
STATE_DIR=${1:?state dir}
mkdir -p "$STATE_DIR"

snapshot() {
  # 각 줄: 종류 번호 상태 제목. 실패하면 빈 출력으로 두고 이번 비교를 건너뜁니다.
  local out
  out=$({
    gh pr list -R "$REPO" --state all --limit 30 \
      --json number,state,title --jq '.[] | "PR #\(.number) \(.state) \(.title)"' &&
    gh issue list -R "$REPO" --state all --limit 40 \
      --json number,state,title --jq '.[] | "Issue #\(.number) \(.state) \(.title)"' &&
    main_ci
  } 2>/dev/null) || return 1
  printf '%s\n' "$out" | sort
}

main_ci() {
  # 실행 전체 결론이 아니라 ci-gate job 판정을 씁니다. drift 단위의 실패는 실행을 failure로 만들지만 판정에서는 빠지기 때문입니다(docs/workflow.md §6.1).
  # 끝난 실행의 판정은 바뀌지 않으므로 실행 번호·시도 횟수별로 STATE_DIR에 캐시해 매분 job을 다시 조회하지 않습니다.
  local runs id attempt sha cache verdict
  runs=$(gh run list -R "$REPO" --branch main --workflow ci-gate.yml --limit 5 \
    --json databaseId,attempt,headSha,status \
    --jq '.[] | select(.status == "completed") | "\(.databaseId) \(.attempt) \(.headSha[0:7])"') || return 1
  while read -r id attempt sha; do
    [ -n "$id" ] || continue
    cache="$STATE_DIR/gate-$id-$attempt"
    if [ ! -s "$cache" ]; then
      gh api "repos/$REPO/actions/runs/$id/attempts/$attempt/jobs" \
        --jq '.jobs[] | select(.name == "ci-gate") | .conclusion' > "$cache.tmp" || return 1
      # ci-gate job이 없으면(changes 단계에서 실행이 멈춤 등) 판정 없음으로 둡니다.
      [ -s "$cache.tmp" ] || echo "no-verdict" > "$cache.tmp"
      mv "$cache.tmp" "$cache"
    fi
    verdict=$(cat "$cache")
    echo "main-ci $sha $verdict"
  done <<< "$runs"
}

[ -f "$STATE_DIR/prev" ] || snapshot > "$STATE_DIR/prev"
# 조회가 연달아 실패하면(화면 잠금으로 gh가 토큰을 못 읽음, 네트워크 끊김 등) 알림이 없어도 변화가 없는 것이 아닙니다.
# FAIL_LIMIT번 연달아 실패하면 한 번 알리고, 다시 성공하면 복구를 알립니다.
FAIL_LIMIT=5
fails=0
while true; do
  sleep 60
  if ! cur=$(snapshot) || [ -z "$cur" ]; then
    fails=$((fails + 1))
    [ "$fails" -eq "$FAIL_LIMIT" ] && echo "감시 오류: gh 조회가 ${FAIL_LIMIT}번 연달아 실패했습니다. 복구 전까지 변화를 알 수 없습니다."
    continue
  fi
  [ "$fails" -ge "$FAIL_LIMIT" ] && echo "감시 복구: gh 조회가 다시 됩니다(실패 ${fails}회). 그사이 변화는 아래 줄에 함께 나옵니다."
  fails=0
  # 한 번도 본 적 없는 줄(새 항목 또는 상태가 바뀐 항목)만 알립니다.
  # prev는 지금까지 본 줄을 모두 쌓아 둡니다. 조회 범위(최근 N개)에서 빠졌다가 다시 들어온 줄을 또 알리지 않으려는 것입니다.
  comm -13 "$STATE_DIR/prev" <(printf '%s\n' "$cur") | sed 's/^/변화: /'
  sort -u "$STATE_DIR/prev" <(printf '%s\n' "$cur") > "$STATE_DIR/prev.next" && mv "$STATE_DIR/prev.next" "$STATE_DIR/prev"
done

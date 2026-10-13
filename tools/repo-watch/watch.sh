#!/usr/bin/env bash
# 요청함(Issue)·PR·main ci-gate 변화를 1분마다 비교해, 바뀐 것만 한 줄씩 출력합니다.
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
    gh run list -R "$REPO" --branch main --workflow ci-gate.yml --limit 1 \
      --json headSha,status,conclusion --jq '.[] | "main-ci \(.headSha[0:7]) \(.status) \(.conclusion)"'
  } 2>/dev/null) || return 1
  printf '%s\n' "$out" | sort
}

[ -f "$STATE_DIR/prev" ] || snapshot > "$STATE_DIR/prev"
while true; do
  sleep 60
  cur=$(snapshot) || continue
  [ -n "$cur" ] || continue
  # 새로 생긴 줄(새 항목 또는 상태가 바뀐 항목)만 알립니다.
  comm -13 "$STATE_DIR/prev" <(printf '%s\n' "$cur") | sed 's/^/변화: /'
  printf '%s\n' "$cur" > "$STATE_DIR/prev"
done

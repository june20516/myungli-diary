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
    gh run list -R "$REPO" --branch main --workflow ci-gate.yml --limit 5 \
      --json headSha,status,conclusion \
      --jq '.[] | select(.status == "completed") | "main-ci \(.headSha[0:7]) \(.conclusion)"'
  } 2>/dev/null) || return 1
  printf '%s\n' "$out" | sort
}

[ -f "$STATE_DIR/prev" ] || snapshot > "$STATE_DIR/prev"
while true; do
  sleep 60
  cur=$(snapshot) || continue
  [ -n "$cur" ] || continue
  # 한 번도 본 적 없는 줄(새 항목 또는 상태가 바뀐 항목)만 알립니다.
  # prev는 지금까지 본 줄을 모두 쌓아 둡니다. 조회 범위(최근 N개)에서 빠졌다가 다시 들어온 줄을 또 알리지 않으려는 것입니다.
  comm -13 "$STATE_DIR/prev" <(printf '%s\n' "$cur") | sed 's/^/변화: /'
  sort -u "$STATE_DIR/prev" <(printf '%s\n' "$cur") > "$STATE_DIR/prev.next" && mv "$STATE_DIR/prev.next" "$STATE_DIR/prev"
done

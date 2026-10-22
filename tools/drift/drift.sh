#!/usr/bin/env bash
# drift Issue 열기·모으기·닫기 (ci-gate의 drift-report·drift-close, docs/workflow.md §6.1)
#
# 사용:
#   drift.sh report  PR 실행에서. env: PR, PR_TITLE, CONTRACTS, RUN_URL, 단위별 SERVER·APP·WRITING·DESIGN = "<mode>:<result>"
#   drift.sh close   main push에서. env: SHA, RUN_URL, 단위별 SERVER·APP·WRITING·DESIGN = "<result>"
# gh는 GH_REPO·GH_TOKEN을 읽습니다. 테스트(test_drift.py)는 PATH 앞에 가짜 gh를 둡니다.
#
# 단위마다 열린 drift Issue는 하나로 모읍니다. 받는 쪽이 따라잡기 전에 다른 PR이 그 단위의 계약을 또 바꾸면,
# 새 Issue를 열지 않고 가장 오래된 Issue 본문에 "더해진 원인" 줄을 더합니다. 받는 쪽은 한 PR에서 함께 맞추고,
# close는 제목과 더해진 원인의 PR이 모두 그 main 커밋에 들어 있을 때만 닫습니다.
set -euo pipefail

ADDED="* 더해진 원인: PR #"
UNITS=(server app writing design)

# 그 단위 앞으로 열린 drift Issue 배열(번호 오름차순)
# `gh issue list`의 라벨 조건은 검색 색인을 거쳐 가끔 빈 결과를 돌려줍니다(그래서 #479가 열려 있는데 #490이 새로 열림).
# REST issues 목록은 저장소 데이터를 바로 읽으므로 이것을 씁니다. 이 목록에는 PR도 섞여 오므로 뺍니다.
open_drifts() {
  gh api "repos/$GH_REPO/issues?state=open&labels=drift,to:$1&per_page=100" |
    jq '[.[] | select(.pull_request | not) | {number, title, body}] | sort_by(.number)'
}

# Issue 하나(JSON)의 원인 PR 번호: 제목의 `PR #N`과 본문의 더해진 원인 줄
causes() {
  jq -r --arg added "$ADDED" '
    (.title | match("PR #([0-9]+)").captures[0].string),
    ((.body // "") | split("\n")[] | select(startswith($added)) | ltrimstr($added) | match("^[0-9]+").string)
  ' <<<"$1" | sort -un
}

unit_state() {
  case "$1" in
    server) echo "${SERVER:-}" ;;
    app) echo "${APP:-}" ;;
    writing) echo "${WRITING:-}" ;;
    design) echo "${DESIGN:-}" ;;
  esac
}

report() {
  # 계약 파일의 소유 단위(from 라벨)입니다.
  local from_labels=""
  echo "$CONTRACTS" | grep -q 'server/api/openapi' && from_labels="$from_labels,from:server"
  echo "$CONTRACTS" | grep -q 'docs/ia/' && from_labels="$from_labels,from:root"
  echo "$CONTRACTS" | grep -q 'docs/identity/design/' && from_labels="$from_labels,from:design"
  echo "$CONTRACTS" | grep -q 'docs/identity/writing/' && from_labels="$from_labels,from:writing"
  echo "$CONTRACTS" | grep -qE 'core/|proto/' && from_labels="$from_labels,from:core"
  gh label create drift --color FBCA04 --description "계약 변경을 받는 쪽이 아직 따라오지 않음 (workflow §6.1)" 2>/dev/null || true

  local unit state title issues existing
  for unit in "${UNITS[@]}"; do
    state=$(unit_state "$unit")
    title="[drift] $unit: PR #$PR 계약 변경 따라잡기"
    issues=$(open_drifts "$unit")

    if [ "$state" = "drift:success" ]; then
      # 주는 쪽이 PR 안에서 맞춘 것이므로 이 PR이 연 Issue를 닫습니다. 다른 원인이 더해진 Issue는 그 원인이 남아 있어 닫지 않습니다.
      jq -r --arg t "$title" --arg added "$ADDED" \
        '.[] | select(.title == $t and ((.body // "") | contains($added) | not)) | .number' <<<"$issues" |
        while read -r number; do
          gh issue close "$number" --comment "PR #$PR의 다음 실행에서 $unit drift 검사가 통과해 자동으로 닫습니다($RUN_URL)."
        done
      continue
    fi
    [ "$state" = "drift:failure" ] || continue

    # 이 PR이 이미 연 Issue나 이미 더한 원인이면 넘어갑니다(같은 PR의 다시 실행).
    if jq -e --arg t "$title" --arg line "$ADDED$PR(" \
      'any(.[]; .title == $t or ((.body // "") | contains($line)))' <<<"$issues" >/dev/null; then
      echo "이미 알려져 있습니다: $unit PR #$PR"
      continue
    fi

    existing=$(jq -r 'first(.[].number) // empty' <<<"$issues")
    if [ -n "$existing" ]; then
      jq -r --arg n "$existing" '.[] | select(.number == ($n | tonumber)) | .body // ""' <<<"$issues" > body.md
      grep -qF "$ADDED" body.md || echo "" >> body.md
      printf '%s%s(%s). 바뀐 계약 파일: %s 실패한 검사: %s\n' "$ADDED" "$PR" "$PR_TITLE" "$CONTRACTS" "$RUN_URL" >> body.md
      local label_args=()
      [ -z "$from_labels" ] || label_args=(--add-label "${from_labels#,}")
      gh issue edit "$existing" --body-file body.md "${label_args[@]}"
      gh issue comment "$existing" --body "PR #$PR($PR_TITLE)의 계약 변경에서도 \`$unit\` drift 검사가 실패했습니다($RUN_URL). $unit 앞 drift는 이 Issue 하나로 모읍니다. 맞출 때 이 변경도 함께 따라잡아 주세요(docs/workflow.md §6.1)."
      continue
    fi

    printf '%s\n' \
      "## 무엇이 필요한가" \
      "PR #$PR($PR_TITLE)이 바꾼 계약에 \`$unit\`이 아직 맞지 않습니다. 이 단위의 다음 PR에서 맞춰 주세요. 맞추기 전에는 이 단위의 PR이 ci-gate를 통과하지 못합니다(docs/workflow.md §6.1)." \
      "" \
      "* 바뀐 계약 파일: $CONTRACTS" \
      "* 실패한 검사: $RUN_URL" \
      "" \
      "## 관련" \
      "PR #$PR. 이 Issue는 ci-gate가 자동으로 열었습니다. 맞춘 PR 본문에는 \`Closes\`가 아니라 \`참고 #<이 Issue>\`를 적어 주세요. 이 Issue는 원인 PR이 모두 main에 들어 있고 그 단위 검사가 main에서 통과하면 자동으로 닫힙니다. 따라잡기 전에 다른 PR이 이 단위의 계약을 또 바꾸면 아래에 원인이 더해집니다." > body.md
    gh issue create --title "$title" --label "drift,kind:request,to:$unit$from_labels" --body-file body.md
  done
}

close() {
  local unit result issue number sources source state compare merged pending
  for unit in "${UNITS[@]}"; do
    result=$(unit_state "$unit")
    [ "$result" = "success" ] || continue
    # main에서 그 단위 검사가 통과하면 그 커밋의 계약을 모두 따라잡은 것입니다. 다만 원인 PR이 모두 이 커밋에 들어 있을 때만 닫습니다.
    # 원인 PR이 열린 채 다른 PR이 먼저 병합되면, 이 통과는 그 원인 계약 변경을 아직 검사하지 않은 것입니다.
    open_drifts "$unit" | jq -c '.[]' | while read -r issue; do
      number=$(jq -r .number <<<"$issue")
      sources=$(causes "$issue")
      [ -n "$sources" ] || continue
      merged=""; pending=""
      for source in $sources; do
        state=$(gh pr view "$source" --json state,mergeCommit | jq -r '"\(.state) \(.mergeCommit.oid // "")"')
        case "$state" in
          MERGED\ *)
            compare=$(gh api "repos/$GH_REPO/compare/${state#MERGED }...$SHA" | jq -r .status)
            if [ "$compare" = "ahead" ] || [ "$compare" = "identical" ]; then
              merged="$merged #$source"
            else
              pending="$pending #$source"
            fi ;;
          CLOSED\ *) ;; # 병합 없이 닫힌 원인은 따라잡을 계약 변경이 없습니다.
          *) pending="$pending #$source" ;;
        esac
      done
      if [ -n "$pending" ]; then
        echo "#$number: 원인 PR$pending이 아직 이 커밋에 없어 남깁니다."
      elif [ -n "$merged" ]; then
        gh issue close "$number" --comment "main \`${SHA:0:7}\`(원인 PR$merged 포함)에서 $unit 검사가 통과해 자동으로 닫습니다($RUN_URL, docs/workflow.md §6.1)."
      else
        gh issue close "$number" --reason "not planned" --comment "원인 PR이 모두 병합되지 않고 닫혀 따라잡을 계약 변경이 없습니다. 자동으로 닫습니다."
      fi
    done
  done
}

case "${1:-}" in
  report) report ;;
  close) close ;;
  *) echo "사용: drift.sh report|close" >&2; exit 2 ;;
esac

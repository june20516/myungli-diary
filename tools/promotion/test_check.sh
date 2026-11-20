#!/usr/bin/env bash
# promotion check.sh 테스트: main 대상 PR은 staging에서만 통과하는지 봅니다.
set -u
here=$(cd "$(dirname "$0")" && pwd)
fail=0

REPO=june20516/myungli-diary

expect() {
  local want=$1 base=$2 head=$3 head_repo=$4 pattern=${5:-}
  local out code
  out=$("$here/check.sh" "$base" "$head" "$head_repo" "$REPO" 2>&1)
  code=$?
  if [ "$code" != "$want" ]; then
    echo "FAIL: check.sh $base $head $head_repo → $code, 기대 $want"
    fail=1
  elif [ -n "$pattern" ] && ! printf '%s' "$out" | grep -q "$pattern"; then
    echo "FAIL: check.sh $base $head 출력에 '$pattern' 없음: $out"
    fail=1
  else
    echo "ok: check.sh $base $head → $code"
  fi
}

expect 0 main staging "$REPO"
expect 1 main core/foo "$REPO" "main에는 staging에서만"
expect 0 staging core/foo "$REPO"
expect 1 main "" "$REPO" "main에는 staging에서만"
# fork의 staging 브랜치는 이름만 같을 뿐 이 저장소의 staging이 아닙니다.
expect 1 main staging someone/myungli-diary "이 저장소의 staging"
expect 0 staging staging someone/myungli-diary

exit $fail

#!/usr/bin/env bash
# promotion check.sh 테스트: main 대상 PR은 staging에서만 통과하는지 봅니다.
set -u
here=$(cd "$(dirname "$0")" && pwd)
fail=0

expect() {
  local want=$1 base=$2 head=$3 pattern=${4:-}
  local out code
  out=$("$here/check.sh" "$base" "$head" 2>&1)
  code=$?
  if [ "$code" != "$want" ]; then
    echo "FAIL: check.sh $base $head → $code, 기대 $want"
    fail=1
  elif [ -n "$pattern" ] && ! printf '%s' "$out" | grep -q "$pattern"; then
    echo "FAIL: check.sh $base $head 출력에 '$pattern' 없음: $out"
    fail=1
  else
    echo "ok: check.sh $base $head → $code"
  fi
}

expect 0 main staging
expect 1 main core/foo "main에는 staging에서만"
expect 0 staging core/foo
expect 1 main "" "main에는 staging에서만"

exit $fail

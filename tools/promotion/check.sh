#!/usr/bin/env bash
# main 대상 PR은 staging 브랜치에서 온 승격 PR만 받습니다(D136 ①, docs/specs/2026-11-19-branch-split-design.md §3).
# 사용: check.sh <base_ref> <head_ref>. ci-gate의 promotion-source job이 PR마다 부릅니다.
set -u
base=${1-}
head=${2-}

if [ "$base" = "main" ] && [ "$head" != "staging" ]; then
  echo "main에는 staging에서만 들어옵니다(승격 PR). 이 PR의 출발 브랜치: '${head}'. 대상을 staging으로 바꿔 주세요."
  exit 1
fi
echo "통과: ${head} → ${base}"

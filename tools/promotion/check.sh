#!/usr/bin/env bash
# main 대상 PR은 이 저장소의 staging 브랜치에서 온 승격 PR만 받습니다(D136 ①, D141, docs/specs/2026-11-19-branch-split-design.md §3).
# 사용: check.sh <base_ref> <head_ref> <head_repo> <repo>. promotion-source workflow가 PR을 열거나 고치거나 대상을 바꿀 때마다 부릅니다.
# 이 검사는 실수(대상을 main으로 잘못 둠, fork의 같은 이름 브랜치)를 막는 장치입니다. PR 안에서 이 파일이나 workflow를 고치면
# 통과할 수 있어, 털린 쓰기 권한까지 막는 장벽은 prod environment 승인과 GCP 배포 권한의 main 조건입니다(spec §3).
set -u
base=${1-}
head=${2-}
head_repo=${3-}
repo=${4-}

if [ "$base" = "main" ]; then
  if [ "$head" != "staging" ]; then
    echo "main에는 staging에서만 들어옵니다(승격 PR). 이 PR의 출발 브랜치: '${head}'. 대상을 staging으로 바꿔 주세요."
    exit 1
  fi
  if [ "$head_repo" != "$repo" ]; then
    echo "main에는 이 저장소의 staging에서만 들어옵니다. 이 PR은 '${head_repo}'의 staging에서 왔습니다."
    exit 1
  fi
fi
echo "통과: ${head_repo}:${head} → ${base}"

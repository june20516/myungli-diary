#!/bin/sh
# 저장소 라벨·마일스톤을 규약(docs/workflow.md §5.2)대로 맞춥니다. 여러 번 실행해도 결과가 같습니다.
# 실행: bash tools/github-setup/setup_repo.sh  (gh 인증 필요)
set -e

UNITS="root core server app writing design"
for unit in $UNITS; do
  gh label create "from:$unit" --color BFBFBF --description "보내는 쪽: $unit" --force
  gh label create "to:$unit" --color 1D76DB --description "받는 쪽: $unit" --force
done
for kind in request report notice task; do
  gh label create "kind:$kind" --color 0E8A16 --description "종류: $kind" --force
done
gh label create blocking --color B60205 --description "다른 작업을 막고 있음" --force
gh label create accepted --color 5319E7 --description "지휘 세션이 수락함" --force
gh label create rejected --color 000000 --description "지휘 세션이 거절함" --force

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
EXISTING=$(gh api "repos/$REPO/milestones?state=all&per_page=100" -q '.[].title')
for milestone in B0 IA W0 V0 V1 V2 S1 S2 S3 A1 A2 W1 I1 I2 I3 I4; do
  if ! printf '%s\n' "$EXISTING" | grep -qx "$milestone"; then
    gh api "repos/$REPO/milestones" -f title="$milestone" -f description="docs/roadmap.md의 $milestone" >/dev/null
  fi
done
B0_NUMBER=$(gh api "repos/$REPO/milestones?state=all&per_page=100" -q '.[] | select(.title=="B0") | .number')
gh api -X PATCH "repos/$REPO/milestones/$B0_NUMBER" -f state=closed >/dev/null
echo "라벨·마일스톤 설정 완료"

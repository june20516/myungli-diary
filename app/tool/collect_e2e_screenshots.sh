#!/usr/bin/env bash
# Patrol이 Android에서 가져온 네이티브 스크린샷을 `<화면>__<상태|default>.png` 이름으로 모읍니다.
# 사용: tool/collect_e2e_screenshots.sh <patrol 스크린샷 디렉터리> [출력 디렉터리]
# Patrol 파일 이름은 `<타임스탬프>_<태그>.png`이고 태그가 `<화면>__<상태|default>`입니다.
set -euo pipefail

source_dir="${1:?사용: collect_e2e_screenshots.sh <patrol 스크린샷 디렉터리> [출력 디렉터리]}"
output_dir="${2:-build/e2e-screenshots}"

mkdir -p "$output_dir"
found=0
while IFS= read -r -d '' file; do
  name="$(basename "$file")"
  tag="${name#*_}"
  cp "$file" "$output_dir/$tag"
  found=$((found + 1))
done < <(find "$source_dir" -name '*__*.png' -print0)

echo "스크린샷 ${found}장을 ${output_dir}에 모았습니다."
[ "$found" -gt 0 ]

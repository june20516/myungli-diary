#!/usr/bin/env bash
# Patrol이 Android에서 가져온 네이티브 스크린샷을 `<화면>__<상태|default>.png` 이름으로 모읍니다.
# 사용: tool/collect_e2e_screenshots.sh <patrol 스크린샷 디렉터리> [출력 디렉터리]
# Patrol 파일 이름은 `<타임스탬프>_<태그>.png`이고 태그가 `<화면>__<상태|default>`입니다.
# 같은 이름이 둘 이상이면 덮어쓰지 않고 오류로 끝냅니다. 같은 출력 디렉터리를 다시 쓸 수 있게
# 실행 전에 그 디렉터리의 이전 결과(`*__*.png`)만 지웁니다.
set -euo pipefail

source_dir="${1:?사용: collect_e2e_screenshots.sh <patrol 스크린샷 디렉터리> [출력 디렉터리]}"
output_dir="${2:-build/e2e-screenshots}"

mkdir -p "$output_dir"
find "$output_dir" -maxdepth 1 -name '*__*.png' -delete
found=0
while IFS= read -r -d '' file; do
  name="$(basename "$file")"
  tag="$(printf '%s' "$name" | sed -E 's/^[0-9]+_//')"
  if [ -e "$output_dir/$tag" ]; then
    echo "같은 이름의 스크린샷이 둘 이상입니다: $tag" >&2
    exit 1
  fi
  cp "$file" "$output_dir/$tag"
  found=$((found + 1))
done < <(find "$source_dir" -name '*__*.png' -print0)

echo "스크린샷 ${found}장을 ${output_dir}에 모았습니다."
[ "$found" -gt 0 ]

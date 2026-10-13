#!/usr/bin/env bash
# golden 기준 Flutter 버전(tool/golden_flutter_version의 첫 유효 줄)을 출력합니다.
# 값이 비어 있으면 오류 메시지와 함께 실패합니다. goldens_linux.sh와 CI가 이 스크립트를 씁니다.
set -euo pipefail

file="$(cd "$(dirname "$0")" && pwd)/golden_flutter_version"
# 주석(#)과 빈 줄을 뺀 첫 줄이 버전입니다. 매치가 없어도 파이프라인이 죽지 않게 || true.
version="$( { grep -v '^[[:space:]]*#' "$file" || true; } | { grep -v '^[[:space:]]*$' || true; } | head -n 1 | tr -d '[:space:]')"
if [ -z "$version" ]; then
  echo "tool/golden_flutter_version에 Flutter 버전이 없습니다." >&2
  exit 1
fi
echo "$version"

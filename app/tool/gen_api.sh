#!/usr/bin/env bash
# OpenAPI 계약(../server/api/openapi.yaml)에서 Dart 클라이언트와 route 표를 생성합니다.
# 실행: tool/gen_api.sh (app/ 에서). openapi-generator는 Docker 이미지로 돌립니다.
set -euo pipefail

cd "$(dirname "$0")/.."

readonly GENERATOR_IMAGE="openapitools/openapi-generator-cli:v7.26.0"
readonly OUTPUT_DIR="lib/core/api/gen"
readonly WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 계약 파일은 저장소 루트의 server/api에 있으므로 저장소 루트를 통째로 읽기 전용으로 붙인다.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(cd .. && pwd):/repo:ro" \
  -v "$WORK_DIR:/out" \
  "$GENERATOR_IMAGE" generate \
  -i /repo/server/api/openapi.yaml \
  -g dart-dio \
  -o /out \
  --additional-properties=serializationLibrary=json_serializable,pubName=myungli_diary,sourceFolder=core/api/gen \
  --type-mappings=date=String \
  >/dev/null

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$WORK_DIR/lib/core/api/gen/." "$OUTPUT_DIR/"

# json_serializable·copy_with 코드(.g.dart)는 build_runner가 만든다.
dart run build_runner build \
  --build-filter "$OUTPUT_DIR/**"
dart format "$OUTPUT_DIR" >/dev/null

dart run tool/gen_api_routes.dart

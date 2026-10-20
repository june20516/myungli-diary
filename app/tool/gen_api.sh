#!/usr/bin/env bash
# OpenAPI 계약(../server/api/openapi.yaml)에서 Dart 클라이언트와 route 표를 생성합니다.
# 실행: tool/gen_api.sh (app/ 에서). openapi-generator는 Docker 이미지로 돌립니다.
set -euo pipefail

cd "$(dirname "$0")/.."

readonly GENERATOR_IMAGE="openapitools/openapi-generator-cli:v7.26.0@sha256:a304ddf1e2e5f24f68fa3153568d6174cea4959d09aa8e3db6d526fd0782326d"
readonly OUTPUT_DIR="lib/core/api/gen"
readonly TEMPLATE_PATCH="$(pwd)/tool/openapi-templates/open_enum.patch"
readonly WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/spec" "$WORK_DIR/templates" "$WORK_DIR/out"

# 열린 enum(계약 info.description "호환과 버전" 절)에 표시를 단 생성용 계약 사본을 만든다(결정 A66).
dart run tool/mark_open_enums.dart "$WORK_DIR/spec/openapi.json"

# 생성기 기본 템플릿을 꺼내 열린 enum patch를 적용한다. 맞지 않으면 여기서 실패한다.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$WORK_DIR:/work" \
  "$GENERATOR_IMAGE" author template \
  -g dart-dio \
  --library dio \
  -o /work/templates \
  >/dev/null
(cd "$WORK_DIR/templates" && git apply "$TEMPLATE_PATCH")

# 쓰지 않는 생성물(auth 인터셉터와 이를 묶는 api.dart)은 생성기 ignore 파일로 뺀다.
cp tool/openapi-generator-ignore "$WORK_DIR/out/.openapi-generator-ignore"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$WORK_DIR:/work" \
  "$GENERATOR_IMAGE" generate \
  -i /work/spec/openapi.json \
  -t /work/templates \
  -g dart-dio \
  -o /work/out \
  --additional-properties=serializationLibrary=json_serializable,pubName=myungli_diary,sourceFolder=core/api/gen \
  --type-mappings=date=String \
  >/dev/null

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$WORK_DIR/out/lib/core/api/gen/." "$OUTPUT_DIR/"

# json_serializable·copy_with·drift 코드(.g.dart)는 build_runner가 만든다.
# 필터를 주면 필터 밖 생성물을 지우므로 전체를 한 번 돌린다.
dart run build_runner build --delete-conflicting-outputs
dart format "$OUTPUT_DIR" >/dev/null

dart run tool/gen_api_routes.dart

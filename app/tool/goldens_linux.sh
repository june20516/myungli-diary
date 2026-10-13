#!/usr/bin/env bash
# golden 기준 이미지를 Linux(Docker)에서 만들어 app/test/goldens에 되돌려 놓습니다.
#
# Flutter 버전은 tool/golden_flutter_version 한 곳에서 정합니다(로컬 Flutter와 무관).
# ghcr.io/cirruslabs/flutter 이미지는 그 버전 태그가 없으면 stable을 쓰되, 컨테이너 안
# SDK를 같은 버전으로 checkout해 맞춥니다.
# 저장소는 읽기 전용으로 마운트하고 컨테이너 안 복사본에서 돌리므로 호스트의
# .dart_tool·pubspec.lock이 바뀌지 않습니다. 결과 이미지만 호스트 사용자 소유로
# 되돌립니다(삭제된 golden도 반영).
#
# 사용: app/tool/goldens_linux.sh
# 환경 변수: DOCKER_PLATFORM(기본 linux/amd64, CI runner와 같음)
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$app_dir/.." && pwd)"
platform="${DOCKER_PLATFORM:-linux/amd64}"

# 주석(#)과 빈 줄을 뺀 첫 줄이 버전입니다.
version="$(grep -v '^[[:space:]]*#' "$app_dir/tool/golden_flutter_version" | grep -v '^[[:space:]]*$' | head -n 1 | tr -d '[:space:]')"
if [ -z "$version" ]; then
  echo "tool/golden_flutter_version에 버전이 없습니다." >&2
  exit 1
fi

image="ghcr.io/cirruslabs/flutter:$version"
if ! docker manifest inspect "$image" >/dev/null 2>&1; then
  echo "이미지 태그 $version 이 없어 stable을 쓰고 SDK를 $version 으로 맞춥니다." >&2
  image="ghcr.io/cirruslabs/flutter:stable"
fi
echo "이미지: $image ($platform), Flutter $version"

mkdir -p "$app_dir/test/goldens"

docker run --rm --platform "$platform" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e WANT_FLUTTER="$version" \
  -v "$repo_root:/src:ro" \
  -v "$app_dir/test/goldens:/out" \
  "$image" bash -euo pipefail -c '
    if ! (flutter --version 2>/dev/null || true) | grep -q "^Flutter $WANT_FLUTTER "; then
      sdk="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
      git config --global --add safe.directory "$sdk"
      git -C "$sdk" fetch --depth 1 origin "refs/tags/$WANT_FLUTTER:refs/tags/$WANT_FLUTTER"
      git -C "$sdk" checkout -q -f "$WANT_FLUTTER"
    fi
    flutter --version
    mkdir -p /work
    cd /src
    # tar 멤버 이름은 app/... 형태입니다(./ 접두사 없음).
    tar --exclude=app/.dart_tool --exclude=app/build \
      --exclude=app/widgetbook/.dart_tool --exclude=app/widgetbook/build \
      --exclude=app/android --exclude=app/ios -cf - app docs server/api | tar -xf - -C /work
    cd /work/app
    flutter pub get
    flutter test --update-goldens --tags golden
    mkdir -p test/goldens
    # 삭제된 golden도 반영하도록 비우고 복사합니다.
    find /out -mindepth 1 -delete
    cp -a test/goldens/. /out/
    chown -R "$HOST_UID:$HOST_GID" /out
  '

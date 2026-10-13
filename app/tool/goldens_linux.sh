#!/usr/bin/env bash
# golden 기준 이미지를 Linux(Docker)에서 만들어 app/test/goldens에 되돌려 놓습니다.
#
# golden은 Linux에서만 비교합니다(CI와 같은 환경). 로컬 Flutter와 같은 버전 태그의
# ghcr.io/cirruslabs/flutter 이미지를 쓰고, 그 태그가 없으면 stable을 쓰되, 컨테이너 안에서 SDK를 로컬과 같은 버전으로 맞춥니다.
# 저장소는 읽기 전용으로 마운트하고 컨테이너 안 복사본에서 돌리므로 호스트의
# .dart_tool·pubspec.lock이 바뀌지 않습니다. 결과 이미지만 호스트 사용자 소유로 복사합니다.
#
# 사용: app/tool/goldens_linux.sh
# 환경 변수: FLUTTER_IMAGE_TAG(이미지 태그 강제), DOCKER_PLATFORM(기본 linux/amd64, CI runner와 같음)
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$app_dir/.." && pwd)"
platform="${DOCKER_PLATFORM:-linux/amd64}"

# flutter가 PATH에 없으면 버전을 알 수 없으므로 stable로 갑니다.
local_version="$(flutter --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)"
tag="${FLUTTER_IMAGE_TAG:-${local_version:-stable}}"
image="ghcr.io/cirruslabs/flutter:$tag"
if ! docker manifest inspect "$image" >/dev/null 2>&1; then
  echo "이미지 태그 $tag 가 없어 stable을 씁니다(로컬 Flutter ${local_version:-알 수 없음})." >&2
  tag="stable"
  image="ghcr.io/cirruslabs/flutter:$tag"
fi
echo "이미지: $image ($platform)"

mkdir -p "$app_dir/test/goldens"

docker run --rm --platform "$platform" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e WANT_FLUTTER="${local_version:-}" \
  -v "$repo_root:/src:ro" \
  -v "$app_dir/test/goldens:/out" \
  "$image" bash -euo pipefail -c '
    # 이미지 태그가 로컬 Flutter보다 낡았으면(stable 태그는 늦게 갱신됨) SDK를 같은 버전으로 맞춥니다.
    if [ -n "$WANT_FLUTTER" ] && ! (flutter --version 2>/dev/null || true) | grep -q "^Flutter $WANT_FLUTTER "; then
      sdk="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
      git config --global --add safe.directory "$sdk"
      git -C "$sdk" fetch --depth 1 origin "refs/tags/$WANT_FLUTTER:refs/tags/$WANT_FLUTTER"
      git -C "$sdk" checkout -q -f "$WANT_FLUTTER"
    fi
    flutter --version
    mkdir -p /work
    cd /src
    tar --exclude=./app/.dart_tool --exclude=./app/build --exclude=./app/widgetbook/.dart_tool \
      --exclude=./app/android --exclude=./app/ios -cf - app docs server/api | tar -xf - -C /work
    cd /work/app
    flutter pub get
    flutter test --update-goldens --tags golden
    mkdir -p test/goldens
    cp -a test/goldens/. /out/
    chown -R "$HOST_UID:$HOST_GID" /out
  '

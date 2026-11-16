#!/usr/bin/env bash
# 스토어 이미지(App Store, Play 스크린샷과 Play 그래픽 이미지)를 golden과 같은 Linux 렌더(Docker)로 만듭니다
# (#1203, D133).
#
#   app/tool/store_images_linux.sh
#
# test/store/store_images_test.dart를 MYUNGLI_STORE=1로 돌립니다. design 명세(store.json)의 장면을 언어마다 그 언어
# 데모 응답(fixtures/store-<언어>, 다시 만들기는 tool/store_fixtures.sh)으로 찍어 두 틀에 합성하고, 스크린샷 위
# 글은 writing 원고(listing.json)입니다. 글이 글 자리를 넘으면 실패합니다(store.json caption.overflow).
#
# 결과는 저장소 밖 산출물 폴더(기본 app/.local/store-images, STORE_OUT으로 바꿈)에 둡니다. 언제든 다시 만들 수
# 있어 저장소에 넣지 않습니다. 콘솔 업로드는 지휘가 합니다.
# * <언어>/appStore/<순서>-<장면>.png 1320×2868
# * <언어>/play/<순서>-<장면>.png 1080×1920
# * play-feature-graphic.png 1024×500(세 언어 같은 한 장)
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$app_dir/.." && pwd)"
platform="${DOCKER_PLATFORM:-linux/amd64}"
out_dir="${STORE_OUT:-$app_dir/.local/store-images}"

# Docker Desktop의 자격 증명 도우미(docker-credential-desktop)를 부르지 않도록 빈 설정으로
# 돌립니다. 공개 이미지라 로그인이 필요 없고, macOS에서 이 도우미가 터미널 앱에 '다른 앱의
# 데이터 접근' 확인을 매번 띄웁니다. 빈 설정에는 context가 없으므로 소켓 주소를 먼저 읽어 둡니다.
if [ -z "${DOCKER_HOST:-}" ]; then
  DOCKER_HOST="$(docker context inspect --format '{{.Endpoints.docker.Host}}')"
  export DOCKER_HOST
fi
DOCKER_CONFIG="$(mktemp -d)"
export DOCKER_CONFIG
trap 'rm -rf "$DOCKER_CONFIG"' EXIT
printf '{}\n' >"$DOCKER_CONFIG/config.json"

version="$("$app_dir/tool/golden_flutter_version.sh")"

image="ghcr.io/cirruslabs/flutter:$version"
if ! docker manifest inspect "$image" >/dev/null 2>&1; then
  echo "이미지 태그 $version 이 없어 stable을 쓰고 SDK를 $version 으로 맞춥니다." >&2
  image="ghcr.io/cirruslabs/flutter:stable"
fi
echo "이미지: $image ($platform), Flutter $version"

rm -rf "$out_dir"
mkdir -p "$out_dir"

docker run --rm --platform "$platform" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e WANT_FLUTTER="$version" \
  -e MYUNGLI_STORE=1 \
  -v "$repo_root:/src:ro" \
  -v "$out_dir:/out" \
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
    tar --exclude=app/.dart_tool --exclude=app/build --exclude=app/.local \
      --exclude=app/widgetbook/.dart_tool --exclude=app/widgetbook/build \
      --exclude=app/android --exclude=app/ios -cf - app docs server/api | tar -xf - -C /work
    cd /work/app
    flutter pub get
    flutter test test/store/store_images_test.dart
    cp -a build/store/. /out/
    chown -R "$HOST_UID:$HOST_GID" /out
  '

echo "스토어 이미지를 만들었습니다: $out_dir ($(find "$out_dir" -name '*.png' | wc -l | tr -d ' ')장)"

#!/usr/bin/env bash
# 화면별·상태별 스크린샷을 golden과 같은 Linux 렌더(Docker)로 그려 app/docs/artifacts/에 등록합니다(#336).
#
#   tool/screens_linux.sh
#
# test/screenshots/screens_test.dart의 사례(화면·상태·fake 시나리오)를 MYUNGLI_SCREENSHOTS=1로
# 돌려 build/screens/<화면>__<상태>.png를 만들고, tool/register_screenshots.dart --origin render로
# index.json에 올립니다. 화면을 새로 만들거나 바꾼 계획 PR에서 사례를 더하고 다시 돌립니다.
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$app_dir/.." && pwd)"
platform="${DOCKER_PLATFORM:-linux/amd64}"

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

out_dir="$app_dir/build/screens"
rm -rf "$out_dir"
mkdir -p "$out_dir"

docker run --rm --platform "$platform" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e WANT_FLUTTER="$version" \
  -e MYUNGLI_SCREENSHOTS=1 \
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
    tar --exclude=app/.dart_tool --exclude=app/build \
      --exclude=app/widgetbook/.dart_tool --exclude=app/widgetbook/build \
      --exclude=app/android --exclude=app/ios -cf - app docs server/api | tar -xf - -C /work
    cd /work/app
    flutter pub get
    flutter test test/screenshots
    cp -a build/screens/. /out/
    chown -R "$HOST_UID:$HOST_GID" /out
  '

# 그린 화면을 app/docs/artifacts/에 등록합니다(같은 그림은 건너뛰고 바뀐 그림은 바꿈).
cd "$app_dir"
dart run tool/register_screenshots.dart "$out_dir" --origin render

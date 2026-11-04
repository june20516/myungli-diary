#!/usr/bin/env bash
# 스토어 빌드의 Crashlytics 심볼을 올립니다(#739, 결정 A105). app/에서 실행합니다.
#
#   tool/upload_crashlytics_symbols.sh <staging|prod> <android|ios>
#
# * android: release 빌드가 넣은 mapping file id(build.gradle.kts의 CrashlyticsMappingIdTask)와
#   R8 mapping(build/app/outputs/mapping/release/mapping.txt)을 Firebase CLI로 함께 올립니다.
#   id는 빌드마다 새로 만들어지므로 스토어에 올린 그 빌드 직후, 다시 빌드하기 전에 돌립니다.
# * ios: `flutter build ipa`가 만든 archive의 dSYM을 Crashlytics upload-symbols로 올립니다.
#
# 앱 ID는 lib/core/firebase/firebase_options_<env>.dart(A93)에서 읽습니다. Firebase CLI 로그인
# (`firebase login`)이 필요하고, 빌드할 때 준 환경과 같은 환경을 줍니다.
set -euo pipefail

usage() {
  echo "사용법: tool/upload_crashlytics_symbols.sh <staging|prod> <android|ios>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
env="$1"
platform="$2"
case "$env" in staging | prod) ;; *) usage ;; esac
case "$platform" in android | ios) ;; *) usage ;; esac

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$app_dir"

options="lib/core/firebase/firebase_options_${env}.dart"
# 옵션 파일에서 그 플랫폼 앱의 appId(예 1:123:android:abc)를 찾습니다.
app_id="$(grep -oE "appId: '[0-9]+:[0-9]+:${platform}:[0-9a-f]+'" "$options" |
  sed -E "s/appId: '([^']+)'/\1/" | head -1)"
if [ -z "$app_id" ]; then
  echo "$options 에서 $platform 앱 ID를 찾지 못했습니다." >&2
  exit 1
fi

fail() {
  echo "$1" >&2
  exit 1
}

case "$platform" in
android)
  mapping="build/app/outputs/mapping/release/mapping.txt"
  resource="$(find build/app/generated -name crashlytics_mapping_file_id.xml \
    -path '*Release*' 2>/dev/null | head -1)"
  [ -f "$mapping" ] || fail "$mapping 이 없습니다. release 빌드 직후에 돌립니다."
  [ -n "$resource" ] || fail "mapping file id 파일이 없습니다. release 빌드 직후에 돌립니다."
  # 파일 시각은 비교하지 않습니다. Java·Kotlin 코드가 그대로면 R8이 건너뛰어 mapping.txt는
  # 예전 시각이지만 내용은 이 빌드와 같고, id는 빌드마다 새로 쓰입니다.
  id="$(grep -oE '>[0-9a-f]{32}<' "$resource" | tr -d '<>')"
  echo "Android $env ($app_id), mapping file id $id"
  firebase crashlytics:mappingfile:upload --app="$app_id" \
    --resource-file="$resource" "$mapping"
  ;;
ios)
  dsyms="build/ios/archive/Runner.xcarchive/dSYMs"
  [ -d "$dsyms" ] || fail "$dsyms 이 없습니다. flutter build ipa 직후에 돌립니다."
  # Crashlytics SDK(SPM)에 들어 있는 업로드 도구입니다.
  tool="$(find build/ios/SourcePackages "$HOME/Library/Developer/Xcode/DerivedData" \
    -path '*firebase-ios-sdk/Crashlytics/upload-symbols' -type f 2>/dev/null | head -1)"
  [ -n "$tool" ] || fail "upload-symbols를 찾지 못했습니다. flutter build ipa를 먼저 돌립니다."
  echo "iOS $env ($app_id), $dsyms"
  "$tool" -ai "$app_id" -p ios "$dsyms"
  ;;
esac

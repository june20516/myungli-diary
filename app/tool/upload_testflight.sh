#!/usr/bin/env bash
# iOS archive를 App Store Connect(TestFlight)에 올립니다(A103, #1285). app/에서 실행합니다.
#
#   tool/upload_testflight.sh [archive]   # archive 기본값 build/ios/archive/Runner.xcarchive
#
# `flutter build ipa`가 만든 archive를 ios/ExportOptions.plist의 destination만 upload로 바꿔 다시
# export하면 xcodebuild가 바로 올립니다. 올리기 전 IPA 확인(entitlements, CFBundleVersion,
# UIDeviceFamily)은 README "iOS TestFlight"대로 먼저 합니다.
# 인증은 App Store Connect API Admin 팀 키(로컬 값 K18)라 Xcode 계정 로그인에 기대지 않습니다.
# 키 파일은 경로로만 넘기고 내용을 읽거나 출력하지 않습니다(D98).
# prod 설정으로 만든 archive는 현재 브랜치가 main일 때만 올립니다(D141, tool/common/release_branch_guard.sh).
# 필요: Xcode(xcodebuild, plutil), jq, git.
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "사용: tool/upload_testflight.sh [archive]" >&2
  exit 2
fi

# 인자로 받은 archive는 부른 곳 기준 경로라 app/로 옮기기 전에 절대 경로로 바꿉니다.
if [[ $# -eq 1 ]]; then
  archive="$(cd "$1" && pwd)" || { echo "archive가 없습니다: $1" >&2; exit 2; }
fi
app_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$app_dir"
# shellcheck source=common/release_branch_guard.sh
source tool/common/release_branch_guard.sh

archive="${archive:-build/ios/archive/Runner.xcarchive}"
app_bundle="$archive/Products/Applications/Runner.app"
key_path="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/shared/appstore-connect-admin.p8"

[[ -d "$app_bundle" ]] || { echo "archive에 Runner.app이 없습니다: $archive" >&2; exit 2; }
[[ -f "$key_path" ]] || { echo "App Store Connect 키(K18)가 없습니다: $key_path" >&2; exit 3; }
for tool in xcodebuild plutil jq git; do
  command -v "$tool" >/dev/null || { echo "${tool}이 없습니다." >&2; exit 3; }
done

# archive의 Dart 바이너리로 빌드 설정을 가리고, prod면 main 브랜치인지 봅니다.
build_env="$(require_main_for_prod_build "$app_bundle/Frameworks/App.framework/App")"
build_number="$(plutil -extract CFBundleVersion raw "$app_bundle/Info.plist")"
echo "빌드 설정: $build_env, CFBundleVersion: $build_number"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cp ios/ExportOptions.plist "$work_dir/ExportOptionsUpload.plist"
plutil -replace destination -string upload "$work_dir/ExportOptionsUpload.plist"

xcodebuild -exportArchive -archivePath "$archive" \
  -exportOptionsPlist "$work_dir/ExportOptionsUpload.plist" -exportPath "$work_dir/upload" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$key_path" \
  -authenticationKeyID LKGA94F3KB -authenticationKeyIssuerID 0c874e33-b32a-426a-b5a5-a8da26e5e8bf
echo "App Store Connect에 빌드 ${build_number}를 올렸습니다(${build_env}). TestFlight 처리는 몇 분 걸립니다."

#!/usr/bin/env bash
# Android 스토어 빌드(AAB)를 Play Console 트랙에 올립니다(#944).
#
#   tool/upload_play.sh <aab> [track]      # track 기본값 internal
#
# Android Publisher API v3 순서: edits.insert → (빌드 번호 중복 검사) → edits.bundles.upload
# → edits.tracks.update → edits.commit. 중간에 실패하면 edit를 지워 아무것도 남기지 않습니다.
# 인증은 서비스 계정 play-publisher(키 파일 없음)를 사용자 gcloud 계정이 impersonation으로
# 씁니다. 토큰은 변수로만 다루고 출력하거나 파일에 쓰지 않습니다(D98).
# 필요: gcloud(로그인한 사용자에게 play-publisher의 Service Account Token Creator 권한),
#       bundletool(AAB의 versionCode 읽기), jq, curl.
# 출시 노트는 넣지 않습니다(문구가 정해지면 releaseNotes를 더함).
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "사용: tool/upload_play.sh <aab> [track]" >&2
  exit 2
fi
aab="$1"
track="${2:-internal}"
package="app.myungli.diary"
service_account="play-publisher@myungli-diary.iam.gserviceaccount.com"
api="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package"
upload_api="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package"

[[ -f "$aab" ]] || { echo "AAB가 없습니다: $aab" >&2; exit 2; }
for tool in gcloud bundletool jq curl; do
  command -v "$tool" >/dev/null || { echo "${tool}이 없습니다." >&2; exit 3; }
done

version_code="$(bundletool dump manifest --bundle "$aab" \
  --xpath /manifest/@android:versionCode)"
[[ "$version_code" =~ ^[0-9]+$ ]] || {
  echo "AAB에서 versionCode를 읽지 못했습니다: $version_code" >&2
  exit 1
}

token="$(gcloud auth print-access-token \
  --impersonate-service-account="$service_account" \
  --scopes=https://www.googleapis.com/auth/androidpublisher 2>/dev/null)" || {
  echo "play-publisher 토큰을 받지 못했습니다(gcloud 로그인과 impersonation 권한 확인)." >&2
  exit 1
}

edit_id=""
# API를 부르고 응답 본문을 돌려줍니다. HTTP 2xx가 아니면 본문을 보이고 실패합니다.
call() {
  local method="$1" url="$2"
  shift 2
  local body status
  body="$(mktemp)"
  status="$(curl -sS -o "$body" -w '%{http_code}' -X "$method" \
    -H "Authorization: Bearer $token" "$@" "$url")"
  if [[ "$status" != 2* ]]; then
    echo "$method ${url#https://androidpublisher.googleapis.com} 실패(HTTP $status):" >&2
    jq -r '.error.message // .' "$body" >&2 || cat "$body" >&2
    rm -f "$body"
    return 1
  fi
  cat "$body"
  rm -f "$body"
}
cleanup() {
  if [[ -n "$edit_id" ]]; then
    curl -sS -o /dev/null -X DELETE -H "Authorization: Bearer $token" \
      "$api/edits/$edit_id" || true
  fi
}
trap cleanup EXIT

edit_id="$(call POST "$api/edits" | jq -r .id)"

# 이미 올라간 빌드 번호(어느 트랙이든, 트랙에 없는 업로드 포함)와 겹치면 멈춥니다.
uploaded="$(call GET "$api/edits/$edit_id/bundles" | jq -r '.bundles[]?.versionCode')"
in_tracks="$(call GET "$api/edits/$edit_id/tracks" |
  jq -r '.tracks[]?.releases[]?.versionCodes[]?')"
if grep -qx "$version_code" <<<"$uploaded"$'\n'"$in_tracks"; then
  echo "빌드 번호 ${version_code}는 이미 Play에 있습니다. pubspec.yaml의 +N을 올려 다시 빌드하세요(A104)." >&2
  exit 1
fi

echo "AAB 올리는 중(versionCode $version_code)..."
call POST "$upload_api/edits/$edit_id/bundles?uploadType=media" \
  -H "Content-Type: application/octet-stream" --data-binary "@$aab" >/dev/null

release="$(jq -n --arg code "$version_code" \
  '{releases: [{versionCodes: [$code], status: "completed"}]}')"
call PUT "$api/edits/$edit_id/tracks/$track" \
  -H "Content-Type: application/json" -d "$release" >/dev/null

call POST "$api/edits/$edit_id:commit" >/dev/null
edit_id=""
echo "Play ${track} 트랙에 versionCode ${version_code}를 올렸습니다."

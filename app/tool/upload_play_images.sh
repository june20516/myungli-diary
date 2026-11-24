#!/usr/bin/env bash
# 스토어 이미지(tool/store_images_linux.sh 결과)를 Play 등록정보에 올립니다(#1307).
#
#   tool/upload_play_images.sh [이미지 폴더] [--dry-run]   # 폴더 기본값 .local/store-images
#
# 언어(ko→ko-KR, en→en-US, ja→ja-JP)마다 휴대폰 스크린샷(<언어>/play/*.png, 파일 이름 순서)과
# 피처 그래픽(play-feature-graphic.png, 세 언어 공통)을 Play에 걸린 이미지의 sha256 목록과
# 순서까지 비교합니다. 같으면 건너뛰고, 다르면 그 종류를 모두 지운 뒤 순서대로 다시 올립니다.
# --dry-run은 비교만 하고 edit를 지웁니다.
#
# Android Publisher API v3 순서: edits.insert → edits.images.list → (다른 종류만)
# edits.images.deleteall → edits.images.upload → edits.commit. 중간에 실패하면 edit를 지워
# 아무것도 남기지 않습니다. 인증은 tool/upload_play.sh와 같이 play-publisher를 impersonation으로
# 쓰고, 토큰은 출력하지 않습니다(D98). 필요: gcloud, jq, curl, shasum.
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
images_dir="$app_dir/.local/store-images"
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    -*) echo "사용: tool/upload_play_images.sh [이미지 폴더] [--dry-run]" >&2; exit 2 ;;
    *) images_dir="$arg" ;;
  esac
done
[[ -d "$images_dir" ]] || { echo "이미지 폴더가 없습니다: $images_dir" >&2; exit 2; }
for tool in gcloud jq curl shasum; do
  command -v "$tool" >/dev/null || { echo "${tool}이 없습니다." >&2; exit 3; }
done

package="app.myungli.diary"
service_account="play-publisher@myungli-diary.iam.gserviceaccount.com"
api="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package"
upload_api="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package"
feature_graphic="$images_dir/play-feature-graphic.png"
languages=(ko:ko-KR en:en-US ja:ja-JP)

# 올리기 전에 로컬 파일이 다 있는지 봅니다(Play 휴대폰 스크린샷은 2~8장).
[[ -f "$feature_graphic" ]] || { echo "피처 그래픽이 없습니다: $feature_graphic" >&2; exit 2; }
for pair in "${languages[@]}"; do
  shots=("$images_dir/${pair%%:*}/play/"*.png)
  [[ -f "${shots[0]}" ]] || { echo "스크린샷이 없습니다: $images_dir/${pair%%:*}/play" >&2; exit 2; }
  ((${#shots[@]} >= 2 && ${#shots[@]} <= 8)) || {
    echo "Play 휴대폰 스크린샷은 2~8장입니다(${pair%%:*}: ${#shots[@]}장)." >&2
    exit 2
  }
done

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

local_hashes() {
  local file
  for file in "$@"; do
    shasum -a 256 "$file" | cut -d' ' -f1
  done
}

# 한 언어의 한 이미지 종류를 로컬 파일 목록과 맞춥니다. 바꿨으면 0, 같으면 1을 돌려줍니다.
sync_images() {
  local language="$1" image_type="$2"
  shift 2
  local url="$api/edits/$edit_id/listings/$language/$image_type"
  local remote expected
  remote="$(call GET "$url" | jq -r '.images[]?.sha256')"
  expected="$(local_hashes "$@")"
  if [[ "$remote" == "$expected" ]]; then
    echo "$language $image_type: 같음($#장), 건너뜀"
    return 1
  fi
  echo "$language $image_type: 다름(Play $(grep -c . <<<"$remote" || true)장 → 로컬 $#장)"
  $dry_run && return 0
  call DELETE "$url" >/dev/null
  local file
  for file in "$@"; do
    call POST "$upload_api/edits/$edit_id/listings/$language/$image_type?uploadType=media" \
      -H "Content-Type: image/png" --data-binary "@$file" >/dev/null
    echo "  올림 ${file#"$images_dir/"}"
  done
  return 0
}

edit_id="$(call POST "$api/edits" | jq -r .id)"

changed=0
for pair in "${languages[@]}"; do
  folder="${pair%%:*}"
  language="${pair##*:}"
  sync_images "$language" phoneScreenshots "$images_dir/$folder/play/"*.png && changed=$((changed + 1))
  sync_images "$language" featureGraphic "$feature_graphic" && changed=$((changed + 1))
done

if $dry_run; then
  echo "dry-run: 바꿀 종류 ${changed}개, 아무것도 올리지 않았습니다."
  exit 0
fi
if ((changed == 0)); then
  echo "Play 이미지가 이미 로컬 판과 같습니다."
  exit 0
fi
call POST "$api/edits/$edit_id:commit" >/dev/null
edit_id=""
echo "Play 등록정보 이미지 ${changed}종류를 바꿨습니다."

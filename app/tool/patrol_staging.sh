#!/usr/bin/env bash
# Patrol E2E를 staging server에 대고 돌립니다(#781, 결정 A108).
#
#   tool/patrol_staging.sh [대상(기본 patrol_test)] [patrol test에 넘길 인자...]
#   예) tool/patrol_staging.sh patrol_test/launch_test.dart
#
# 하는 일:
# 1. gcloud 로그인을 확인하고, Secret Manager의 TEST_LOGIN_SECRET을 relay(tool/e2e_staging/relay.dart)의
#    stdin으로 바로 넘겨 띄웁니다. 비밀은 relay 메모리에만 있고 출력, 파일, 인자, 환경 변수에 남지 않습니다.
# 2. relay(127.0.0.1:47283)가 준비되면 에뮬레이터에 `adb reverse tcp:47283`을 걸어 앱이 relay에 닿게 합니다.
# 3. tool/patrol_local.sh를 http 모드와 staging dart-define으로 부릅니다.
# 4. 끝나면(통과, 실패, 중단 모두) relay에 /cleanup을 보내 이 실행이 만든 테스트 계정을 지우고,
#    relay를 끝내고 reverse를 지웁니다. relay도 SIGINT, SIGTERM을 받으면 스스로 한 번 더 정리합니다.
#
# adb 서버는 다른 프로젝트와 함께 쓰므로 `adb kill-server`, `adb reverse --remove-all`을 하지 않습니다.
#
# 환경 변수:
#   MYUNGLI_STAGING_PROJECT  staging GCP 프로젝트 id(기본 myungli-diary-staging).
#   MYUNGLI_LOCAL_DIR        로컬 값 폴더(기본 ~/.config/myungli, D98). app/staging/dart-defines.json을 씁니다.
#   PATROL_DEVICE            쓸 기기. 없으면 연결된 에뮬레이터 하나를 씁니다(patrol_local.sh에도 넘김).
#   그 밖의 PATROL_* 값은 tool/patrol_local.sh가 읽습니다.
#
# 종료 코드: patrol_local.sh와 같습니다. 3은 환경 문제(gcloud 로그인, relay 준비 안 됨, 기기 없음 포함)입니다.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 3

project="${MYUNGLI_STAGING_PROJECT:-myungli-diary-staging}"
local_dir="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}"
staging_defines="$local_dir/app/staging/dart-defines.json"
env_file="config/env/staging.json"
relay_port=47283
relay_url="http://127.0.0.1:$relay_port"
relay_ready_timeout=10

sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$sdk/platform-tools/adb"

log_dir="build/patrol-local"
mkdir -p "$log_dir"
relay_log="$log_dir/relay-$(date +%Y%m%d-%H%M%S).log"

say() { echo "[patrol_staging] $*"; }

# patrol_local.sh의 PATROL_EXTRA_DEFINES는 공백으로 나누므로 공백 든 경로는 쓸 수 없습니다.
if [[ "$env_file" == *[[:space:]]* || "$staging_defines" == *[[:space:]]* ]]; then
  say "dart-define 파일 경로에 공백이 있습니다. 공백 없는 경로만 쓸 수 있습니다(MYUNGLI_LOCAL_DIR 확인)"
  exit 3
fi

if ! command -v gcloud >/dev/null 2>&1; then
  say "gcloud가 없습니다"
  exit 3
fi
if ! gcloud auth print-access-token >/dev/null 2>&1; then
  say "gcloud에 로그인되어 있지 않습니다(gcloud auth login)"
  exit 3
fi
if [[ ! -f "$staging_defines" ]]; then
  say "staging dart-define 파일이 없습니다: $staging_defines (docs/local-values.md)"
  exit 3
fi

api_base="$(sed -n 's/.*"API_BASE_URL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$env_file")"
if [[ -z "$api_base" ]]; then
  say "$env_file에서 API_BASE_URL을 읽지 못했습니다"
  exit 3
fi

# 쓸 에뮬레이터 하나를 정합니다. patrol_local.sh도 같은 기기를 쓰게 PATROL_DEVICE로 넘깁니다.
serial="${PATROL_DEVICE:-}"
if [[ -z "$serial" ]]; then
  serials="$("$adb" devices | awk '$1 ~ /^emulator-/ && $2 == "device" {print $1}')"
  if [[ "$(grep -c . <<<"$serials")" != "1" ]]; then
    say "연결된 에뮬레이터가 하나가 아닙니다. 하나만 띄우거나 PATROL_DEVICE로 고르세요: $(tr '\n' ' ' <<<"$serials")"
    exit 3
  fi
  serial="$serials"
fi
export PATROL_DEVICE="$serial"

if curl -s -o /dev/null --max-time 2 "$relay_url/ready"; then
  say "$relay_url에 이미 relay가 떠 있습니다. 다른 실행을 끝낸 뒤 다시 돌리세요"
  exit 3
fi

relay_pid=""
reverse_set=""
finished=""

# relay에 정리를 맡기고 relay와 reverse를 치웁니다. EXIT에서 한 번만 돕니다.
finish() {
  [[ -n "$finished" ]] && return
  finished=1
  if [[ -n "$relay_pid" ]] && kill -0 "$relay_pid" 2>/dev/null; then
    local result
    if result="$(curl -s --max-time 120 -X POST "$relay_url/cleanup")"; then
      say "테스트 계정 정리: $result"
    else
      say "relay가 /cleanup에 답하지 않았습니다. relay 스스로의 정리를 기다립니다"
    fi
    kill -TERM "$relay_pid" 2>/dev/null
    wait "$relay_pid" 2>/dev/null
  elif [[ -n "$relay_pid" ]]; then
    say "relay가 먼저 끝났습니다. 남은 테스트 계정이 있으면 로그를 보세요(로그 $relay_log)"
  fi
  if [[ -n "$relay_pid" ]]; then
    grep '정리 결과' "$relay_log" | sed 's/^/  /'
  fi
  if [[ -n "$reverse_set" ]]; then
    "$adb" -s "$serial" reverse --remove "tcp:$relay_port" >/dev/null 2>&1
  fi
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

say "relay를 띄웁니다(프로젝트 $project, API $api_base, 로그 $relay_log)"
gcloud secrets versions access latest --secret=TEST_LOGIN_SECRET --project="$project" 2>>"$relay_log" |
  dart run tool/e2e_staging/relay.dart --api-base "$api_base" >>"$relay_log" 2>&1 &
relay_pid=$!

# 0.25초마다 확인합니다. relay가 죽으면 기다리지 않고 바로 끝냅니다.
ticks=0
until curl -sf -o /dev/null --max-time 1 "$relay_url/ready"; do
  if ! kill -0 "$relay_pid" 2>/dev/null || ((ticks >= relay_ready_timeout * 4)); then
    say "relay 준비 안 됨(로그 $relay_log)"
    tail -5 "$relay_log" | sed 's/^/  /'
    # 아직 아무 요청도 받지 않아 지울 계정이 없습니다. relay만 끝내고 정리 단계를 건너뜁니다.
    kill -TERM "$relay_pid" 2>/dev/null
    wait "$relay_pid" 2>/dev/null
    relay_pid=""
    exit 3
  fi
  sleep 0.25
  ticks=$((ticks + 1))
done
say "relay 준비됨 $relay_url"

if ! "$adb" -s "$serial" reverse "tcp:$relay_port" "tcp:$relay_port" >/dev/null; then
  say "adb reverse tcp:$relay_port에 실패했습니다"
  exit 3
fi
reverse_set=1

PATROL_API_MODE=http PATROL_EXTRA_DEFINES="$env_file $staging_defines" \
  tool/patrol_local.sh "${1:-patrol_test}" --dart-define=E2E_MODE=staging "${@:2}"

#!/usr/bin/env bash
# 로컬 Patrol E2E를 에뮬레이터 한 대에서 끝까지(통과·실패·중단 중 하나로) 돌립니다.
#
#   tool/patrol_local.sh [대상(기본 patrol_test)] [patrol test에 넘길 인자...]
#   예) tool/patrol_local.sh patrol_test/diary_test.dart
#
# 대처하는 문제(2026-10-20에 겪음):
# * 기기가 여러 대(에뮬레이터·실기기·macOS·Chrome)면 patrol이 기기를 고르라고 묻고 멈춤
#   → 늘 `-d <에뮬레이터>`로 지정하고 stdin을 닫습니다. 에뮬레이터가 둘 이상이면 고르지 않고 멈춥니다.
# * 실행 중 에뮬레이터가 빠지면 patrol이 기기를 끝없이 기다림
#   → 감시 루프가 기기 상태를 보고, 정해진 시간 넘게 빠져 있으면 patrol을 끝냅니다. 전체 시간 한도도 둡니다.
# * 설치 단계의 `device offline`으로 테스트 0개가 돌고 실패
#   → 기기 문제로 분류해 기기가 돌아오기를 기다린 뒤 정해진 횟수만큼 다시 돌립니다(테스트 실패는 다시 돌리지 않음).
# * 멈춘 이전 실행이 남아 같은 로그에 계속 씀
#   → 잠금으로 동시에 둘을 돌리지 않고, 실행마다 새 로그 파일을 씁니다.
#
# adb 서버는 다른 프로젝트(예: React Native)와 함께 쓰므로 `adb kill-server`·`adb reverse --remove-all`을
# 하지 않습니다. 포트는 Metro(8081)와 겹치지 않게 47281/47282입니다.
#
# 환경 변수:
#   PATROL_DEVICE         쓸 기기(예 emulator-5554). 없으면 연결된 에뮬레이터 하나를 씁니다.
#   PATROL_AVD            연결된 에뮬레이터가 없을 때 띄울 AVD 이름(emulator -list-avds).
#   PATROL_BOOT_TIMEOUT   부팅·재연결 대기 초(기본 180).
#   PATROL_RUN_TIMEOUT    한 번 실행의 최대 초(기본 1800).
#   PATROL_OFFLINE_GRACE  실행 중 기기가 빠져 있어도 기다리는 초(기본 60).
#   PATROL_RETRIES        기기 문제일 때 다시 돌리는 횟수(기본 1).
#
# 종료 코드: 0 통과, 1 테스트 실패, 2 기기 문제(다시 돌려도 안 됨), 3 환경 문제(잠금·기기 없음·도구 없음),
#           4 시간 초과.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 3

target="${1:-patrol_test}"
shift || true
extra_args=("$@")

sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$sdk/platform-tools/adb"
emulator="$sdk/emulator/emulator"
patrol="$(command -v patrol || echo "$HOME/.pub-cache/bin/patrol")"

boot_timeout="${PATROL_BOOT_TIMEOUT:-180}"
run_timeout="${PATROL_RUN_TIMEOUT:-1800}"
offline_grace="${PATROL_OFFLINE_GRACE:-60}"
retries="${PATROL_RETRIES:-1}"
poll=10

log_dir="build/patrol-local"
lock_dir="$log_dir/run.lock"
mkdir -p "$log_dir"

say() { echo "[patrol_local] $*"; }

# 명령을 [초] 안에 끝내지 못하면 끊습니다(오프라인 기기에 붙은 adb shell이 멈추는 것을 막음).
run_limited() {
  local seconds="$1"
  shift
  "$@" &
  local pid=$!
  (sleep "$seconds" && kill "$pid" 2>/dev/null) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid"
  local status=$?
  kill "$watcher" 2>/dev/null
  return "$status"
}

# [pid]와 그 자식 프로세스(flutter·gradle·adb)를 모두 끝냅니다.
kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    kill_tree "$child"
  done
  kill "$pid" 2>/dev/null
}

device_state() { run_limited 10 "$adb" -s "$1" get-state 2>/dev/null | tr -d '\r'; }

booted() {
  [[ "$(run_limited 10 "$adb" -s "$1" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]
}

# [serial]이 연결되고 부팅을 마칠 때까지 기다립니다.
wait_for_device() {
  local serial="$1" waited=0
  while ((waited < boot_timeout)); do
    if [[ "$(device_state "$serial")" == "device" ]] && booted "$serial"; then
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  return 1
}

# 쓸 에뮬레이터를 정해 stdout으로 냅니다. 없으면 PATROL_AVD를 띄웁니다.
pick_device() {
  if [[ -n "${PATROL_DEVICE:-}" ]]; then
    echo "$PATROL_DEVICE"
    return 0
  fi
  local serials
  serials="$(run_limited 10 "$adb" devices | awk '$1 ~ /^emulator-/ && ($2 == "device" || $2 == "offline") {print $1}')"
  local count
  count="$(grep -c . <<<"$serials")"
  if ((count == 1)); then
    echo "$serials"
    return 0
  fi
  if ((count > 1)); then
    say "에뮬레이터가 여러 대입니다. PATROL_DEVICE로 고르세요: $(tr '\n' ' ' <<<"$serials")" >&2
    return 1
  fi
  if [[ -z "${PATROL_AVD:-}" ]]; then
    say "연결된 에뮬레이터가 없습니다. 띄우거나 PATROL_AVD를 주세요. AVD: $("$emulator" -list-avds | tr '\n' ' ')" >&2
    return 1
  fi
  say "에뮬레이터 ${PATROL_AVD}를 띄웁니다" >&2
  nohup "$emulator" -avd "$PATROL_AVD" -no-audio >"$log_dir/emulator.log" 2>&1 &
  local waited=0
  while ((waited < boot_timeout)); do
    serials="$(run_limited 10 "$adb" devices | awk '$1 ~ /^emulator-/ {print $1}')"
    if [[ -n "$serials" ]]; then
      head -1 <<<"$serials"
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  say "${PATROL_AVD}가 ${boot_timeout}초 안에 나타나지 않았습니다" >&2
  return 1
}

# 잠금: 다른 실행이 살아 있으면 멈춥니다. 죽은 실행의 잠금은 치웁니다.
if ! mkdir "$lock_dir" 2>/dev/null; then
  holder="$(cat "$lock_dir/pid" 2>/dev/null || true)"
  if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
    say "다른 Patrol 실행(pid $holder)이 돌고 있습니다"
    exit 3
  fi
  rm -rf "$lock_dir"
  mkdir "$lock_dir"
fi
echo $$ >"$lock_dir/pid"
run_pid=""
cleanup() {
  [[ -n "$run_pid" ]] && kill_tree "$run_pid"
  rm -rf "$lock_dir"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [[ ! -x "$patrol" ]]; then
  say "patrol CLI가 없습니다(dart pub global activate patrol_cli)"
  exit 3
fi

serial="$(pick_device)" || exit 3
say "기기 $serial"

# 한 번 실행합니다. 결과: 0 통과, 1 테스트 실패, 2 기기 문제, 4 시간 초과.
run_once() {
  local log="$1"
  "$patrol" test -d "$serial" -t "$target" \
    --dart-define-from-file=config/auth.json --dart-define=API_MODE=fake --test-server-port 47281 --app-server-port 47282 \
    "${extra_args[@]+"${extra_args[@]}"}" </dev/null >"$log" 2>&1 &
  run_pid=$!
  local elapsed=0 offline=0 verdict=""
  while kill -0 "$run_pid" 2>/dev/null; do
    sleep "$poll"
    elapsed=$((elapsed + poll))
    if [[ "$(device_state "$serial")" == "device" ]]; then
      offline=0
    else
      offline=$((offline + poll))
      say "기기가 응답하지 않습니다(${offline}초)"
    fi
    if ((offline >= offline_grace)); then
      verdict=2
      say "기기가 ${offline_grace}초 넘게 빠져 실행을 끝냅니다"
    elif ((elapsed >= run_timeout)); then
      verdict=4
      say "${run_timeout}초가 지나 실행을 끝냅니다"
    elif grep -q "Please select an option" "$log"; then
      verdict=2
      say "patrol이 기기를 고르라고 묻습니다. 실행을 끝냅니다"
    fi
    if [[ -n "$verdict" ]]; then
      kill_tree "$run_pid"
      wait "$run_pid" 2>/dev/null
      run_pid=""
      return "$verdict"
    fi
  done
  wait "$run_pid"
  local status=$?
  run_pid=""
  if ((status == 0)); then
    return 0
  fi
  local total
  total="$(grep -oE 'Total: [0-9]+' "$log" | tail -1 | grep -oE '[0-9]+' || true)"
  # 테스트가 하나도 돌지 않았거나 설치·연결에서 끊겼으면 기기 문제입니다.
  if [[ -z "$total" || "$total" == "0" ]] || grep -qE "device offline|Failed to install|device '.*' not found|no devices" "$log"; then
    return 2
  fi
  return 1
}

attempt=0
while true; do
  attempt=$((attempt + 1))
  if ! wait_for_device "$serial"; then
    say "${serial}이 ${boot_timeout}초 안에 준비되지 않았습니다"
    exit 2
  fi
  log="$log_dir/$(date +%Y%m%d-%H%M%S)-$attempt.log"
  say "실행 $attempt: $target (로그 $log)"
  run_once "$log"
  result=$?
  grep -E "Total:|Successful:|Failed:|Skipped:" "$log" | sed 's/^/  /'
  case "$result" in
    0) say "통과"; exit 0 ;;
    1) say "테스트 실패(로그 $log)"; exit 1 ;;
    4) say "시간 초과(로그 $log)"; exit 4 ;;
  esac
  if ((attempt > retries)); then
    say "기기 문제로 끝났습니다(로그 $log)"
    exit 2
  fi
  say "기기 문제로 보입니다. 기기가 돌아오면 다시 돌립니다"
done

#!/usr/bin/env bash
# CI(app.yml e2e-android)에서 에뮬레이터가 뜬 뒤 Patrol E2E를 fake 모드로 돌립니다. app/에서 실행합니다.
#
#   tool/e2e_ci.sh
#
# 로컬 실행은 tool/patrol_local.sh를 씁니다. 이 스크립트는 GitHub runner 전용입니다(sudo dmesg, ::error 표기).
#
# 2026-11-11부터 e2e가 job 상한 60분에서 cancelled로 끝났습니다. 2026-11-23 실행에서 테스트 중 에뮬레이터
# 프로세스가 아무 출력 없이 사라졌고, patrol과 `adb logcat`이 기기를 끝없이 기다렸습니다. 그래서:
# * patrol을 30분 timeout으로 감싸 넘으면(124) 실패로 끝내고, 에뮬레이터 프로세스가 사라지면 바로 끝냅니다.
# * adb 호출도 timeout으로 감싸 기기가 없을 때 멈추지 않게 합니다.
# * 에뮬레이터가 사라진 이유를 가리도록 30초마다 메모리와 에뮬레이터 생존을 build/e2e-mem.log에 적고,
#   실패하면 호스트 kernel 로그(OOM, segfault)와 에뮬레이터 crash 기록(/tmp/android-runner)을 남깁니다.
# 산출물: build/patrol.log, build/logcat-full.txt, build/logcat-stream.txt, build/e2e-mem.log, build/e2e-diag/.
# Patrol 포트는 기본값(8081, 8082) 대신 47281, 47282로 고정합니다(app/CLAUDE.md와 같은 값).
set -uo pipefail

cd "$(dirname "$0")/.." || exit 3
mkdir -p build/e2e-diag

# 30초마다: 시각, 사용 중/전체 메모리(MB), 남은 메모리, 에뮬레이터(qemu) 프로세스 수, 바쁜 스레드.
(
  while :; do
    mem="$(free -m | awk '/^Mem:/ {print $3 "/" $2 " avail " $7}')"
    echo "$(date -u +%H:%M:%S) mem ${mem} qemu=$(pgrep -c qemu-system || true)"
    # 에뮬레이터 스레드별 CPU 상위 5개. 얼었을 때 렌더 스레드가 바쁜지(느린 처리) 쉬는지(교착)를 봅니다.
    qemu_pid="$(pgrep -o qemu-system || true)"
    if [[ -n "$qemu_pid" ]]; then
      top -b -n 1 -H -p "$qemu_pid" | sed -n '8,12p' | awk '{print "  " $9 "% " $12}'
    fi
    sleep 30
  done
) > build/e2e-mem.log 2>&1 &
sampler=$!
# 테스트 내내 기기 logcat을 파일로 받습니다. 에뮬레이터가 사라져도 그 직전까지 남고, 앱이 쓰는
# 렌더링 백엔드 줄(Impeller Vulkan 또는 OpenGLES)도 여기에 남습니다.
adb logcat -v threadtime > build/logcat-stream.txt 2>&1 &
logcat_pid=$!
trap 'kill "$sampler" "$logcat_pid" 2>/dev/null' EXIT

# 기기가 없어도 멈추지 않는 adb.
adb_quick() {
  timeout 60 adb "$@"
}

timeout -k 60 1800 patrol test -t patrol_test \
  --dart-define-from-file=config/auth.json --dart-define=API_MODE=fake \
  --test-server-port 47281 --app-server-port 47282 \
  --screenshots-output-dir build/e2e-native-screenshots > build/patrol.log 2>&1 &
patrol_pid=$!

# 에뮬레이터가 사라지면 patrol은 기기를 끝없이 기다리므로, 두 번 연속(20초) 없으면 바로 끝냅니다.
emulator_gone=false
missing=0
while kill -0 "$patrol_pid" 2>/dev/null; do
  if pgrep qemu-system >/dev/null; then
    missing=0
  else
    missing=$((missing + 1))
    if [[ "$missing" -ge 2 ]]; then
      emulator_gone=true
      echo "$(date -u +%H:%M:%S) 에뮬레이터 프로세스가 사라져 patrol을 끝냅니다." | tee -a build/e2e-mem.log
      pkill -TERM -P "$patrol_pid" 2>/dev/null
      kill -TERM "$patrol_pid" 2>/dev/null
      break
    fi
  fi
  sleep 10
done
wait "$patrol_pid"
rc=$?
if [[ "$emulator_gone" == true && "$rc" == 0 ]]; then
  rc=1
fi

echo "--- 앱 렌더링 백엔드 ---"
grep -m 3 "rendering backend" build/logcat-stream.txt || echo "기록 없음"

if [[ "$rc" != 0 ]]; then
  cat build/patrol.log
  if [[ "$emulator_gone" == true ]]; then
    echo "::error title=e2e 에뮬레이터 사라짐::테스트 중 에뮬레이터 프로세스가 사라졌습니다. 위 로그의 마지막 테스트와 job 로그의 kernel 로그(-show-kernel)를 봅니다"
  elif [[ "$rc" == 124 ]]; then
    echo "::error title=e2e 멈춤::patrol이 30분 안에 끝나지 않아 멈췄습니다. 위 로그의 마지막 테스트와 e2e-gradle-reports의 진단 기록을 봅니다"
  fi
  echo "--- instrumentation 결과, Patrol 요약에서 빠지는 프로세스 크래시 포함 ---"
  tail -n 8 build/app/outputs/androidTest-results/connected/debug/*/testlog/test-results.log || true

  echo "--- 에뮬레이터 상태 ---"
  pgrep -a qemu-system || echo "에뮬레이터 프로세스가 없습니다."
  adb_quick devices || true
  echo "--- 커널 OOM 기록 ---"
  sudo dmesg -T | grep -iE "out of memory|oom-kill|killed process" | tail -n 20 || echo "OOM 기록 없음"
  # 에뮬레이터가 signal로 죽으면(segfault, trap 등) 호스트 kernel 로그에 qemu 줄이 남습니다.
  echo "--- 호스트 kernel 로그 끝부분 ---"
  sudo dmesg -T | tail -n 40
  echo "--- 메모리 기록 끝부분 ---"
  tail -n 10 build/e2e-mem.log
  cp -R /tmp/android-runner/. build/e2e-diag/ 2>/dev/null || true

  adb_quick logcat -d > build/logcat-full.txt || echo "기기가 없어 logcat을 받지 못했습니다."
  exit 1
fi

n=$(adb_quick logcat -d | grep -c "Destroy timeout of remove-task" || true)
echo "remove-task destroy timeout=$n"
if [[ "$n" != 0 ]]; then
  echo "::warning title=e2e A100::테스트 뒤 Activity가 닫히지 않은 채 끝난 task가 $n개 있습니다. app/README.md 기기 E2E 실패 읽기"
fi

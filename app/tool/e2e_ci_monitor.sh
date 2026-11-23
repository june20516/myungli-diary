#!/usr/bin/env bash
# CI e2e 동안 호스트와 기기 지표를 시간순으로 적고, 기기가 얼면 에뮬레이터 스레드 호출 스택을 받습니다.
# tool/e2e_ci.sh가 백그라운드로 띄우고 끝날 때 멈춥니다. app/에서 실행합니다. GitHub runner 전용(sudo).
#
#   tool/e2e_ci_monitor.sh <출력 디렉터리>
#
# 2026-11-23 조사: 실제 앱 화면에서 에뮬레이터 호스트가 교착(모든 스레드 CPU 0%)되고 약 1분 뒤 에뮬레이터가
# 스스로 끝났습니다. 테스트가 이어지며 무언가 쌓이는지, 얼 때 어느 호출에서 멈췄는지 보려고 둡니다.
#
# 산출물(<출력 디렉터리>/):
# * e2e-metrics.tsv: 15초마다 한 줄. 열은 머리줄에 있습니다.
# * e2e-threads.log: 30초마다 에뮬레이터 스레드별 CPU 상위 5개.
# * e2e-freeze.log: 기기 응답 확인(5초마다)에서 응답 없음이 시작되고 풀린 시각.
# * e2e-diag/qemu-stacks.txt, qemu-kstacks.txt: 처음 얼었을 때 에뮬레이터 사용자 공간 스택(gdb)과
#   kernel 스택.
set -uo pipefail

out="${1:?출력 디렉터리가 필요합니다}"
mkdir -p "$out/e2e-diag"
app_id=app.myungli.diary

# 얼었을 때 바로 쓰도록 gdb를 미리 설치합니다(없으면 스택만 건너뜀).
(command -v gdb >/dev/null || sudo apt-get install -y -qq gdb >/dev/null 2>&1) &

qemu_pid() { pgrep -o qemu-system || true; }

# 기기 안 명령. 응답이 없어도 5초 안에 돌아옵니다.
adb_shell() { timeout 5 adb shell "$@" 2>/dev/null | tr -d '\r'; }

# 15초마다 지표 한 줄.
metrics_loop() {
  printf 'time\thost_avail_mb\tqemu_rss_mb\tqemu_threads\tqemu_fds\tadb_ms\tguest_avail_mb\tapp_pid\tapp_pss_kb\tapp_graphics_kb\tapp_threads\tsf_layers\n' \
    > "$out/e2e-metrics.tsv"
  while :; do
    local now host_avail qpid qrss="" qthreads="" qfds="" start adb_ms guest_avail pid pss="" gfx="" threads="" layers
    now="$(date -u +%H:%M:%S)"
    host_avail="$(free -m | awk '/^Mem:/ {print $7}')"
    qpid="$(qemu_pid)"
    if [[ -n "$qpid" ]]; then
      qrss="$(awk '/^VmRSS:/ {print int($2 / 1024)}' "/proc/$qpid/status" 2>/dev/null)"
      qthreads="$(awk '/^Threads:/ {print $2}' "/proc/$qpid/status" 2>/dev/null)"
      qfds="$(sudo ls "/proc/$qpid/fd" 2>/dev/null | wc -l)"
    fi
    start="$(date +%s%N)"
    if timeout 5 adb shell true >/dev/null 2>&1; then
      adb_ms="$((($(date +%s%N) - start) / 1000000))"
    else
      adb_ms="timeout"
    fi
    guest_avail="$(adb_shell cat /proc/meminfo | awk '/^MemAvailable:/ {print int($2 / 1024)}')"
    pid="$(adb_shell pidof "$app_id")"
    if [[ -n "$pid" ]]; then
      local meminfo
      meminfo="$(adb_shell dumpsys meminfo "$pid")"
      pss="$(awk '/TOTAL PSS:/ {print $3; exit}' <<<"$meminfo")"
      gfx="$(awk '/^ *Graphics:/ {print $2; exit}' <<<"$meminfo")"
      threads="$(adb_shell cat "/proc/$pid/status" | awk '/^Threads:/ {print $2}')"
    fi
    layers="$(adb_shell dumpsys SurfaceFlinger --list | wc -l)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$now" "$host_avail" "$qrss" "$qthreads" "$qfds" \
      "$adb_ms" "$guest_avail" "$pid" "$pss" "$gfx" "$threads" "$layers" >> "$out/e2e-metrics.tsv"
    sleep 15
  done
}

# 30초마다 에뮬레이터 스레드별 CPU 상위 5개. 얼었을 때 렌더 스레드가 바쁜지(느린 처리) 쉬는지(교착)를 봅니다.
threads_loop() {
  while :; do
    local qpid
    qpid="$(qemu_pid)"
    echo "$(date -u +%H:%M:%S) qemu=${qpid:-없음}"
    if [[ -n "$qpid" ]]; then
      top -b -n 1 -H -p "$qpid" | sed -n '8,12p' | awk '{print "  " $9 "% " $12}'
    fi
    sleep 30
  done > "$out/e2e-threads.log" 2>&1
}

# 5초마다 기기 응답을 봅니다. 에뮬레이터는 살아 있는데 세 번 연속(15초) 응답이 없으면 얼었다고 보고,
# 처음 한 번만 스택을 받습니다(에뮬레이터는 얼고 약 1분 뒤 스스로 끝남).
freeze_loop() {
  local misses=0 frozen=false dumped=false qpid
  while :; do
    qpid="$(qemu_pid)"
    if [[ -n "$qpid" ]] && ! timeout 4 adb shell true >/dev/null 2>&1; then
      misses=$((misses + 1))
    else
      if [[ "$frozen" == true ]]; then
        echo "$(date -u +%H:%M:%S) 기기 응답이 돌아왔습니다." >> "$out/e2e-freeze.log"
      fi
      misses=0
      frozen=false
    fi
    if [[ "$misses" -ge 3 && "$frozen" == false ]]; then
      frozen=true
      echo "$(date -u +%H:%M:%S) 기기가 15초 넘게 응답하지 않습니다(qemu pid $qpid)." >> "$out/e2e-freeze.log"
      if [[ "$dumped" == false ]]; then
        dumped=true
        # 출력 파일은 runner 사용자 디렉터리라 sudo 밖에서 씁니다.
        # shellcheck disable=SC2024
        sudo sh -c "for t in /proc/$qpid/task/*; do echo \"== \$t \$(cat \$t/comm) wchan=\$(cat \$t/wchan)\"; cat \$t/stack; done" \
          > "$out/e2e-diag/qemu-kstacks.txt" 2>&1
        if command -v gdb >/dev/null; then
          # shellcheck disable=SC2024
          timeout 40 sudo gdb -p "$qpid" -batch -ex "set pagination off" -ex "thread apply all bt 25" \
            > "$out/e2e-diag/qemu-stacks.txt" 2>&1
        else
          echo "gdb가 없어 사용자 공간 스택을 받지 못했습니다." > "$out/e2e-diag/qemu-stacks.txt"
        fi
        echo "$(date -u +%H:%M:%S) 에뮬레이터 스택을 받았습니다." >> "$out/e2e-freeze.log"
      fi
    fi
    sleep 5
  done
}

metrics_loop &
threads_loop &
freeze_loop &
trap 'kill $(jobs -p) 2>/dev/null' EXIT TERM
wait

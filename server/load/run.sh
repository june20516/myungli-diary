#!/bin/sh
# 부하 생성기 Job(load-k6)의 진입점입니다(L1-2b). Job 인자는 k6 run 뒤에 그대로 붙습니다.
#
#   RUN=<회차> sh run.sh scenarios/ramp.js
#
# 결과는 GCS volume(/results) 아래 <회차> 폴더에 씁니다. 원자료는 크므로 gzip(raw.csv.gz)이고, k6-summary.json은
# ramp.js의 handleSummary가 RESULT_DIR에 씁니다. 스크립트 설정은 Job 실행의 환경 변수로 넘깁니다(k6 run은 시스템 환경 변수를 읽음).
set -eu

: "${RUN:?RUN(회차 이름, 예 2026-11-05-limit-1)이 필요합니다}"
case "$RUN" in
  *[!A-Za-z0-9._-]* | .* )
    echo "RUN은 영숫자, 점, 밑줄, 하이픈만 쓰고 점으로 시작하지 않습니다: $RUN" >&2
    exit 2
    ;;
esac

RESULT_DIR="/results/$RUN"
export RESULT_DIR
mkdir -p "$RESULT_DIR"
exec k6 run --out "csv=$RESULT_DIR/raw.csv.gz" "$@"

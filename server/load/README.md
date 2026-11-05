# 부하 테스트 (L1)

계획은 [`server/docs/plans/2026-11-04-l1-load-test.md`](../docs/plans/2026-11-04-l1-load-test.md), 환경은 D104(부하 전용 프로젝트 `myungli-diary-load`)입니다. 환경을 띄우고 지우는 절차는 [`deploy/terraform/README.md`](../deploy/terraform/README.md) "부하 환경"에 있습니다.

| 파일 | 내용 |
| --- | --- |
| `lib/flows.js` | 하루 사용 흐름(앱 열기, today 화면, 반응, 일기 쓰기, 캘린더). app 코드의 호출 순서를 근거로 둡니다 |
| `lib/api.js` | REST 계약 형식 요청. 요청마다 tag `operation`(operationId) |
| `lib/profiles.js` | 테스트 계정 프로필. 출생 정보를 계정 번호로 고루 나눔 |
| `accounts.js` | 테스트 계정 준비(로그인, 동의, 프로필) |
| `scenarios/ramp.js` | 단계별 한계점 측정. 단계마다 도착률 고정 scenario `stage_<세션/초>` |
| `report/` | 결과 파일 집계 도구(Go) |
| `Dockerfile`, `run.sh` | 생성기 Job `load-k6` 이미지와 진입점(L1-2b) |

## 실행

측정은 같은 region의 생성기 Job으로 합니다(아래 "생성기 Job"). 로컬에서 보내면 Hosting까지 왕복이 응답마다 p50 약 145ms 더해지고(smoke), 기본 STAGES의 마지막 단계(VU 1,600개, 초당 약 3,000건)는 로컬 Mac이 먼저 막힙니다. 로컬 실행은 smoke와 스크립트 확인용입니다.

### 로컬

k6는 컨테이너(`grafana/k6:2.3.0`)로 돌립니다. 아래는 `server/`에서 실행합니다. 테스트 로그인 비밀은 Secret Manager에서 바로 환경 변수로 넘기고, 화면이나 파일에 남기지 않습니다.

```sh
export TEST_LOGIN_SECRET="$(gcloud secrets versions access latest --secret TEST_LOGIN_SECRET --project myungli-diary-load)"
k6() { docker run --rm -v "$PWD/load":/load -v "$PWD/.local/load/$RUN":/results -w /load -e TEST_LOGIN_SECRET grafana/k6:2.3.0 "$@"; }
```

스크립트 설정은 k6 flag `-e`로 넘깁니다(`k6 run -e 이름=값`). 비밀만 docker `-e`로 넘기는데, `k6 run`은 시스템 환경 변수를 읽지만 `k6 inspect`는 읽지 않습니다.

#### 계정 만들기
회차마다 Cloud SQL을 새로 만들므로 측정 전에 한 번 돌립니다. 계정 수는 측정의 VU 수(단계별 `도착률 × SESSION_SECONDS`의 모든 단계 합, 기본 STAGES로 3,185) 이상이어야 합니다. VU는 단계마다 따로이고 갱신 토큰을 VU끼리 넘길 수 없어, 가장 큰 단계만큼이 아니라 합만큼 필요합니다.

```sh
RUN=accounts; mkdir -p ".local/load/$RUN"
k6 run -e ACCOUNTS=3200 --quiet accounts.js
```

#### 측정
```sh
RUN=2026-11-05-limit-1; mkdir -p ".local/load/$RUN"
k6 run -e ACCOUNTS=3200 -e STAGES=2,5,10,20,40,80,160,320 --out csv=/results/raw.csv.gz scenarios/ramp.js
```

* **smoke:** `-e STAGES=1 -e STAGE_DURATION=1m`(계정 20개면 충분)
* **warm 회차:** `job precompute`를 먼저 돌려 오늘 데일리를 채운 뒤 `DAILY_OFFSET_DAYS=0`
* **cold 회차:** 아직 계산하지 않은 날짜로 옮깁니다. 예: `-e DAILY_OFFSET_DAYS=30`. 회차마다 다른 값을 씁니다.

| 환경 변수 | 기본값 | 뜻 |
| --- | --- | --- |
| `BASE_URL` | `https://myungli-diary-load.web.app` | 공개 주소(Hosting). 직접 주소로 보내지 않음 |
| `ACCOUNTS` | 3200 | 준비한 계정 수. VU 하나가 계정 하나를 맡음 |
| `STAGES` | `2,5,10,20,40,80,160,320` | 단계별 도착률(세션/초). 세션 하나는 요청 9~10개쯤(smoke 기준). 상한은 #782 목표(L 180, L-1월 270)보다 높게 둡니다 |
| `STAGE_DURATION`, `STAGE_GAP` | `3m`, `30s` | 단계 길이와 단계 사이 쉬는 시간 |
| `STAGE_WARMUP` | `30s` | 단계마다 처음 이만큼은 tag `phase=warmup`, 그 뒤는 `phase=steady`. 멈춤 판정은 steady에만 |
| `SESSION_SECONDS` | 5 | 세션 하나에 걸리는 시간 짐작. VU 수 = 도착률 × 이 값 |
| `REACTION_PERCENT`, `DIARY_PERCENT`, `CALENDAR_PERCENT` | 10, 25, 20 | 세션마다 반응, 일기 쓰기, 캘린더를 할 확률(%) |
| `DAILY_OFFSET_DAYS` | 0 | today 화면이 여는 날짜 옮기기(cold 회차) |
| `DIARY_SPREAD_DAYS` | 7 | 일기 날짜를 오늘부터 며칠 전까지 나눔(하루 10편 상한 피함) |
| `REQUEST_TIMEOUT` | `30s` | 요청 하나의 시간 초과 |

**멈춤 조건(단계마다, steady 구간):** 오류율(4xx, 5xx, 시간 초과) 1% 넘음, `getDaily` p95 2초 넘음. 단계가 바뀌면 Cloud Run이 인스턴스를 늘리는 동안 응답이 잠깐 느려지므로 단계 처음(`STAGE_WARMUP`)은 판정에서 뺍니다. 2026-11-05 cold 회차에서 `stage_40` 시작 7초의 표본만으로 멈췄습니다. k6 `delayAbortEval`은 회차 시작부터 세어 이 일을 못 합니다. warmup 응답도 사용자가 겪는 값이라 `stages.csv`에 따로 남습니다. 닿으면 k6가 그 단계에서 끝내고 종료 코드가 0이 아닙니다(정상적인 한계 도달). 멈춘 단계 바로 아래가 그 설정의 한계점입니다.

### 생성기 Job

부하 프로젝트의 Cloud Run Job `load-k6`(8 vCPU, 16GiB, 최대 90분)가 같은 이미지 안의 스크립트를 돌립니다. 준비는 `deploy/terraform/README.md` "생성기 Job 준비"입니다. 결과는 bucket `myungli-diary-load-load-results`의 `<회차>/`에 `raw.csv.gz`와 `k6-summary.json`으로 남습니다(30일 뒤 지움). 테스트 로그인 비밀은 Job에 Secret으로 붙어 있어 넘기지 않습니다.

Job 인자는 `k6 run` 뒤에 붙고(스크립트 경로), 설정은 실행의 환경 변수로 넘깁니다. 값에 쉼표가 있으므로(`STAGES`) gcloud의 구분자 바꾸기 `^@^`를 씁니다.

```sh
job() { gcloud run jobs execute load-k6 --region asia-northeast3 --project myungli-diary-load --wait "$@"; }
# 계정 만들기
job --args=accounts.js --update-env-vars='^@^RUN=2026-11-05-accounts@ACCOUNTS=3200'
# 측정
RUN=2026-11-05-limit-1
job --args=scenarios/ramp.js --update-env-vars="^@^RUN=$RUN@ACCOUNTS=3200@STAGES=2,5,10,20,40,80,160,320"
# 결과 내려받기(server/에서)
gcloud storage cp -r "gs://myungli-diary-load-load-results/$RUN" .local/load/
```

멈춤 조건에 닿으면 k6 종료 코드가 0이 아니라 Job 실행도 실패로 끝납니다. 정상적인 한계 도달이므로 결과 파일로 판단합니다. 실행 로그는 `gcloud run jobs executions list --job load-k6 --region asia-northeast3 --project myungli-diary-load`의 실행 이름으로 Cloud Logging에서 봅니다.

### 결과 파일 만들기
Monitoring 지표는 몇 분 늦게 들어오므로 측정이 끝나고 5분쯤 뒤에 돌립니다. ADC(`gcloud auth application-default login`)가 필요합니다.

```sh
mkdir -p "docs/load/$RUN" && cp ".local/load/$RUN/k6-summary.json" "docs/load/$RUN/"
go run ./load/report -raw ".local/load/$RUN/raw.csv.gz" -summary "docs/load/$RUN/k6-summary.json" -out "docs/load/$RUN"
```

원자료 `raw.csv.gz`(기본 STAGES를 끝까지 가면 압축 전 1~2GB)는 크므로 `.local/`(git ignore)에만 둡니다. `docs/load/<회차>/`에는 아래 파일과 사람이 읽는 `README.md`를 둡니다.

## 결과 파일 (D104 ②)

금액은 어느 파일에도 넣지 않습니다(D74). 시각은 모두 UTC, RFC 3339입니다.

### `k6-summary.json`
k6 `handleSummary` 그대로입니다. 갱신 토큰이 든 `setup_data`는 뺍니다. 멈춤 조건 결과는 `metrics["http_req_failed{scenario:stage_N,phase:steady}"].thresholds`에 있습니다.

### `stages.csv`
단계마다 phase(`all`, `warmup`, `steady`)별로 `operation=all` 한 줄과 operation별 한 줄입니다. setup 요청(테스트 로그인)은 빠집니다. phase tag가 없는 원자료(2026-11-05 cold 회차)는 `all` 행만 나옵니다.

| 열 | 단위 | 뜻 |
| --- | --- | --- |
| `stage_rate` | 세션/초 | 단계의 목표 도착률 |
| `stage_start_utc`, `stage_end_utc` | 시각 | 그 단계와 phase의 첫 요청과 마지막 요청(끝은 +1초) |
| `phase` | | `all`(단계 전체), `warmup`(단계 처음 `STAGE_WARMUP`), `steady`(그 뒤, 멈춤 판정 구간) |
| `operation` | | operationId 또는 `all` |
| `requests` | 건 | 요청 수 |
| `actual_rps` | 건/초 | `requests ÷ 창 길이`. 창은 operation과 상관없이 그 단계와 phase 전체 |
| `p50_ms`, `p95_ms`, `p99_ms` | ms | `http_req_duration` 백분위(선형 보간). 값이 없으면 빈 칸 |
| `status_2xx` | 건 | 2xx |
| `status_304` | 건 | 304(`getGlossary`의 If-None-Match) |
| `status_429` | 건 | 429(Cloud Run 인스턴스 상한이나 server 요청 한도) |
| `status_5xx` | 건 | 5xx |
| `status_other` | 건 | 그 밖(4xx, 연결 실패 status 0) |
| `timeouts` | 건 | 요청 시간 초과(k6 error_code 1050) |
| `blocked` | true/false | 그 단계에서 멈춤 조건에 닿았는지(phase와 상관없이 단계 값) |

### `monitoring.csv`
측정 창(첫 단계 1분 전 ~ 마지막 단계 2분 뒤)의 1분 간격 시계열입니다. 한 줄이 (시각, 지표, resource) 하나입니다.

| 열 | 뜻 |
| --- | --- |
| `time_utc` | 1분 구간의 끝 시각 |
| `metric` | 아래 지표 이름 |
| `resource` | `server`, `engine`(Cloud Run 서비스), `sql`(Cloud SQL) |
| `value`, `unit` | 값과 단위 |

| `metric` | `unit` | 원 지표, 정렬과 축약 |
| --- | --- | --- |
| `instance_count` | count | `run.googleapis.com/container/instance_count`, 1분 최대, 서비스 합 |
| `request_count` | requests_per_min | `run.googleapis.com/request_count`, 1분 합 |
| `request_latency_p95` | ms | `run.googleapis.com/request_latencies`, 1분 분포의 p95 |
| `cpu_utilization_mean` | ratio(0~1) | `run.googleapis.com/container/cpu/utilizations`, 1분 분포의 평균 |
| `billable_instance_time` | seconds_per_min | `run.googleapis.com/container/billable_instance_time`, 1분 합 |
| `sql_connections` | count | `cloudsql.googleapis.com/database/postgresql/num_backends`, 1분 최대, DB 합 |
| `sql_cpu_utilization` | ratio(0~1) | `cloudsql.googleapis.com/database/cpu/utilization`, 1분 평균 |

### `usage.csv`
측정 창의 자원 사용량 합계입니다.

| 열 | 뜻 |
| --- | --- |
| `resource` | `server`, `engine`, `sql` |
| `instance_seconds` | `billable_instance_time` 합(초) |
| `vcpu_seconds`, `memory_gib_seconds` | `instance_seconds × vCPU(1)`, `× 메모리(0.5GiB)`. 크기는 `deploy/terraform/env/run.tf` |
| `sql_hours` | `sql` 행만. 측정 창 길이(시간). 인스턴스는 창 내내 켜져 있음 |

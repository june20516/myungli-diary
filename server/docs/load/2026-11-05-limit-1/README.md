# L1 한계점 측정 1회차 (2026-11-05)

계획은 [`docs/plans/2026-11-04-l1-load-test.md`](../../plans/2026-11-04-l1-load-test.md) L1-4, 파일 형식은 [`load/README.md`](../../../load/README.md) "결과 파일"입니다. 시각은 모두 UTC입니다. 금액은 적지 않습니다(D74).

## 결론

* **한계점은 초당 80세션(요청 약 735건/초)입니다.** cold와 warm 모두 `stage_80`은 steady 구간에서 오류 없이 버티고, `stage_160`에서 멈춥니다. #782 목표(L 180, L-1월 270세션/초)에 미치지 못합니다.
* **처음 막히는 곳은 Cloud SQL CPU입니다.** 두 회차 모두 `stage_80` 끝에 SQL CPU가 100%에 닿습니다. warm에서는 엔진이 거의 놀고 있는데도 처리량이 약 730건/초에서 멈춥니다.
* **cold에서는 엔진도 막힙니다.** `stage_160`에서 엔진이 "쓸 수 있는 인스턴스 없음" 429를 679건 냈고, server가 엔진을 13초 기다리다 504를 321건 냈습니다. 엔진은 3개에서 늘지 않았습니다.
* **단계가 바뀔 때마다 증설 지연이 큽니다.** cold의 warmup 구간(단계 처음 30초) getDaily p95는 10~13초입니다. 아침 알림 직후처럼 요청이 갑자기 몰리면 사용자가 겪을 수 있는 값입니다.

## 회차

| 폴더 | 날짜 옮김 | STAGES | 끝난 이유 | 쓰는 범위 |
| --- | --- | --- | --- | --- |
| `cold-2/` | 45일 뒤(`DAILY_OFFSET_DAYS=45`) | 2~320 | `stage_40` 18초에 생성기 Job이 Cloud Run maintenance로 멈춘 뒤 종료(아래 "생성기 사고") | `stage_2`~`stage_20` |
| `cold-3/` | 60일 뒤 | 20~320 | `stage_160`에서 멈춤 조건 | 전부 |
| `warm/` | 0(오늘) | 20~320 | `stage_160`에서 멈춤 조건 | 전부 |

* **공통 설정:** 생성기 Job `load-k6`(같은 region, 8 vCPU), 계정 3,200개, 단계 3분, 사이 30초, warmup 30초, 세션 확률 반응 10%, 일기 25%, 캘린더 20%.
* **이미지:**
  * server `sha256:6807acdb6fb94783e074eb04621b2a308ae3342ee522a48a9197d316cf0dda0f`(commit ac78b161)
  * engine `sha256:c588548755adce9200654a7e666b1e4826be14ac07eae73acbfd094ae39f311a`
  * load-k6 commit ac78b161
* **용량 설정:** server와 엔진 모두 1 vCPU, 512Mi, 동시 요청 80(기본), 인스턴스 상한 없음(기본 100). Cloud SQL `db-custom-1-3840`(prod와 같음).
* **warm 준비:** precompute Job은 서울 22:00~22:30에만 다음 날을 계산합니다. 그래서 측정 전에 계정마다 `getDaily(오늘)`를 한 번씩 불러 같은 캐시(`fortune.Service.Daily`의 postgres 캐시)를 채웠습니다. 3,200건 모두 200이었습니다.
* **첫 cold 시도(저장소에 넣지 않음):** 2026-11-04 23:05에 돌린 회차는 `stage_40` 시작 7초에 멈췄습니다. k6 `delayAbortEval`이 단계가 아니라 회차 시작부터 세는 판정 결함 때문이었습니다. warmup과 steady를 나누는 수정(#799) 뒤 다시 쟀습니다.

## 단계별 결과 (steady 구간)

전체(`operation=all`)와 getDaily입니다. 오류는 4xx, 5xx, 시간 초과를 모두 셉니다.

| 회차 | 세션/초 | 요청/초 | 전체 p50 | 전체 p95 | 전체 p99 | getDaily p95 | 오류 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cold-2 | 2 | 18.5 | 136ms | 310ms | 386ms | 326ms | 0 |
| cold-2 | 5 | 46.8 | 136ms | 240ms | 357ms | 279ms | 5xx 1 |
| cold-2 | 10 | 91.7 | 136ms | 240ms | 402ms | 266ms | 0 |
| cold-2 | 20 | 184.4 | 145ms | 297ms | 404ms | 352ms | 1 |
| cold-3 | 20 | 182.8 | 140ms | 278ms | 423ms | 327ms | 0 |
| cold-3 | 40 | 365.7 | 140ms | 298ms | 436ms | 363ms | 1 |
| cold-3 | 80 | 736.4 | 192ms | 625ms | 942ms | 791ms | 1 |
| cold-3 | 160 | (steady 3건에서 멈춤) | | | | | |
| warm | 20 | 183.0 | 130ms | 243ms | 388ms | 261ms | 422 16 |
| warm | 40 | 367.2 | 136ms | 301ms | 447ms | 338ms | 422 11 |
| warm | 80 | 732.4 | 149ms | 431ms | 631ms | 644ms | 0 |
| warm | 160 | 98.7(steady 1초) | 854ms | 3,052ms | 3,437ms | 2,567ms | 0 |

* `cold-2`와 `cold-3`의 `stage_20`은 거의 같습니다(p95 297ms와 278ms). 측정이 재현됩니다.
* warm의 422는 모두 `createDiary`입니다. 같은 계정으로 세 회차를 돌려 하루 일기 10편 상한에 닿은 측정 스크립트 쪽 결과입니다.

### 멈춘 단계(`stage_160`)

| 회차 | 구간 | 요청/초 | 전체 p50 | 전체 p95 | getDaily p95 | 429 | 5xx |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cold-3 | warmup 34초 | 222 | 3,462ms | 12,401ms | 20,227ms | 103 | 127 |
| warm | warmup 30초 | 712 | 1,345ms | 3,268ms | 3,546ms | 0 | 0 |

목표 도착률이면 요청은 약 1,470건/초입니다. cold는 그 1/6, warm은 1/2에서 멈춥니다. warm의 처리량은 `stage_80`(732건/초)과 같은 값에서 더 오르지 않습니다.

### 단계 처음의 증설 지연 (warmup getDaily p95)

| 세션/초 | cold-2 | cold-3 | warm |
| --- | --- | --- | --- |
| 20 | 2,978ms | 9,926ms(첫 단계) | 234ms |
| 40 | | 13,140ms | 381ms |
| 80 | | 13,147ms | 785ms |

* cold-3 `stage_20`은 회차의 첫 단계라 server와 엔진이 1~2개에서 시작했습니다.
* server 요청 로그에서도 같은 시각에 daily와 calendar가 4~5초씩 걸리고, 그 직전에 "Starting new instance"가 찍혔습니다(cold-2 `stage_40` 01:03:44~48).

## 자원 (monitoring.csv)

| 시각 | 단계 | server 인스턴스 | 엔진 인스턴스 | SQL CPU 최대 | SQL 연결 |
| --- | --- | --- | --- | --- | --- |
| cold-3 01:22~01:24 | 40 | 3~4 | 3 | 0.37~0.58 | 14 |
| cold-3 01:25~01:27 | 80 | 3 | 3 | 0.46~1.0 | 14 |
| cold-3 01:28 | 160 | 3 | 3 | 0.97 | 14 |
| warm 01:43~01:45 | 80 | 3 | 3 | 0.52~1.0 | 14 |
| warm 01:46 | 160 | 3 | 2~3 | 0.89 | 14 |

* server CPU p99는 0.69 아래, 엔진 CPU p99는 cold 0.75, warm 0.06 아래입니다.
* `stage_40` 뒤로는 server와 엔진 모두 새 인스턴스를 띄우지 않았습니다. 엔진이 429를 내던 cold `stage_160` 동안에도 "Starting new instance" 로그가 없습니다. quota는 instance 100, CPU 할당 20 vCPU(region, 생성기 Job 8 vCPU 포함)입니다. 증설을 시도했다가 막힌 로그도 없어, autoscaler가 왜 늘리지 않았는지는 이 자료로 정할 수 없습니다.
* **SQL 연결 상한:** DB 사용자가 IAM 서비스 계정뿐이라 `SHOW max_connections`를 돌리지 않고 측정으로 봤습니다. 연결(`num_backends`)은 내내 14개(server 3개 × pgx pool 기본 상한 4, 그 밖 2)였고, "too many clients"와 "remaining connection slots" 로그는 세 회차 동안 0건입니다. 연결 상한(tier 기본 100)이 아니라 pool 상한과 SQL CPU가 먼저 막습니다.
* `usage.csv`는 회차마다 instance 초를 합한 값입니다.

## 그 밖에 본 것

* **지연 바닥:** 같은 region에서 보내도 가장 가벼운 `getAppConfig`가 p50 약 123ms입니다. smoke에서 server 처리 시간은 p95 40~54ms였습니다. 차이의 대부분은 Firebase Hosting rewrite 경로입니다.
* **Hosting 503:** 첫 cold 시도의 `stage_10`에서 `refreshToken` 하나가 32ms 만에 503을 받았습니다. 그 시각 Cloud Run 요청 로그에는 503이 없어, server에 닿기 전 Hosting 앞단의 응답으로 봅니다.
* **생성기 사고:** cold-2의 `stage_40`에서 Job task가 01:03:50~53에 요청을 하나도 보내지 못했습니다. 01:03:59부터는 server 로그에 없는 12~13초 응답이 찍혔고, 01:04:01에 종료 신호를 받았습니다. Cloud Run은 "Cloud Run task resuming after scheduled maintenance"와 "memory limit was reached"를 남겼는데, 1분 메모리 사용률은 6% 아래였습니다. 그래서 cold-2의 `stage_40` 행은 쓰지 않습니다. 다음 회차에서도 단계 안에 요청이 끊긴 초가 있는지 먼저 봅니다.

## 고칠 것 (Issue 후보)

1. **Cloud SQL CPU:** 초당 약 730건에서 1 vCPU가 다 찹니다. 어떤 query가 CPU를 쓰는지 Query Insights가 꺼져 있어 보지 못했습니다. 다음 회차에 켜고 query별로 본 뒤 tier와 query를 정합니다.
2. **엔진 동시 처리:** 엔진은 Python 동기 gRPC 서버(worker 8개, `core/src/myungli_engine/grpc_api/server.py`)인데 Cloud Run은 인스턴스마다 동시 요청 80개를 보냅니다. 엔진 서비스의 동시 요청 수를 엔진이 실제로 처리하는 수에 맞추는지 봅니다(server `run.tf`와 core).
3. **증설:** 429가 나는 동안에도 인스턴스가 3개에서 늘지 않은 이유를 찾습니다. 단계 처음 10초대 지연을 줄일 최소 인스턴스나 증설 설정도 함께 봅니다.
4. **server pgx pool 상한:** 인스턴스마다 4개라 SQL이 느려지면 server 안에서 기다립니다. SQL 쪽을 정한 뒤 맞춥니다.
5. **측정 스크립트:** 같은 계정으로 회차를 거듭하면 하루 일기 상한(422)에 닿습니다. 일기 날짜를 회차마다 옮기거나, 회차마다 계정을 새로 만듭니다.

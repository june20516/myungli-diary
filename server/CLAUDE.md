# server — 메인 API 서버 (Go)

이 디렉터리에서 시작한 세션은 **server 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 인증: 카카오·Apple 로그인, 제공자 토큰 검증 후 자체 JWT 발급, 계정과 제공자 연결을 나눠 저장 (D55)
* 배포: GCP Cloud Run(server·엔진 각각, 엔진은 내부 전용 gRPC), Cloud SQL PostgreSQL, Artifact Registry, Secret Manager, GitHub Actions + Workload Identity Federation (D56)
* 사용자 프로필: 출생 정보 저장. 생년월일시, 음력·윤달(KASI 한국 음력, D41), 시간 모름, 성별, 출생 시간대·(선택) 경도 (D18·D29). 호칭 필수 (D36). 생년월일 지원 범위 양력 1900-01-31 ~ 2099-12-31 (D41)
* 일기 CRUD: 저장 시 엔진의 태그 키 전체와 `ruleset_version`, 그때 보인 가이드 질문의 렌더된 원문을 함께 기록 (엔진 spec §7.7·§12, D59④). 한 날짜에 살아 있는 일기 10편까지(D83), 날짜 기록(태그·`ruleset_version`·가이드 질문)은 그날 첫 편 때 한 번, 지난 날 쓰기 가능, 미래 불가 (D49). 태그별 일기 조회 (D47①). 저장 응답에 대표 태그(키·길흉, 엔진 spec §7.7의 화면 표시용 0~2개, D76)를 담음 (Issue #31)
* 기기 간 동기화: MVP는 앱의 로컬 초안만입니다. 저장은 온라인에서만 하고, 동기화·충돌 처리는 Phase 2입니다 (D47②)
* 기본 일정 CRUD: 제목·날짜·종일 또는 시간·메모 (D47③). 반복·일정 알림·외부 캘린더 연동은 범위 밖
* 로그인 없는 미리보기 요청 하나(입력을 저장하지 않음), 새 계정 약관 동의 (D50). 같은 비로그인 규칙의 시진 확인 요청(출생 날짜·시각 → 시진과 벽시계 범위, 엔진 새 RPC) (D58)
* 도시 목록(시간대·경도, D29·D47⑤), 계정 삭제, 최소 앱 버전 응답 (IA spec §10)
* **수익 (D53·D54·D60):** 만료일이 있는 entitlement 모델(구독으로 넓혀 쓸 수 있게), 영수증 검증(RevenueCat webhook 기본안), 광고 제거 여부 응답. 근거·해석 열람 권한(D60): AdMob 보상 SSV 콜백을 직접 받아 서명(ECDSA) 검증·`transaction_id` 멱등 처리 후 그날 자정(사용자 현재 시간대)까지 부여, 광고 제거권 기간에도 부여, 출처 기록. 권한이 없으면 근거 시트의 판정 근거·원전·원국 개인 해석과 `saju-chart.yongsin.basis`를 응답에 담지 않음. 상품은 1개월 광고 제거권(자동 갱신 없음, 잠정 가격은 비공개 기록)이며 구독 결제는 MVP 이후입니다
* **콘텐츠 모듈:** 엔진의 메시지 키를 언어별 문장으로 변환합니다. 템플릿은 PostgreSQL에 저장하고 버전을 관리하며, 시드 파일로 초기화합니다. 언어는 한국어·영어·일본어입니다 (D27·D28). 문장의 저장·선택·렌더는 모두 server입니다(D59). 그날 첫 요청 때 (계정, 날짜, 슬롯) → (문장 틀 id, 버전)을 정해 저장하고, 반응·돌봄 상한·두 기기 일치를 이 기록으로 지킵니다. 문장 유형(`advice`·`state`·`care`) 순환은 총운 슬롯에만, 문장 반응(좋아요)은 계정에 붙여 저장해 사용자 성향(유형 가중치) 자료로 씀 (D40·D57), 호칭 접미사·조사 처리 (D36, 규칙은 계약 "호칭·조사 처리 규칙"). 시드 원고는 CI에서 `mlw check`로 검사 (계약 "라이팅 검사기")
* 엔진 gRPC 클라이언트 (D26), 시간대별 배치와 결과 캐시(PostgreSQL, Redis 도입 기준은 server 결정 S4). 캐시 키에 `ruleset_version`을 넣습니다 (D31)
* 아침 운세 알림 발송 (D18-⑨)
* 앱을 위한 REST/JSON API (D26)
* **MVP 범위 밖:** LLM 기능은 Phase 2 유료입니다 (D22·D23). 목적별 택일, 외부 캘린더 연동, 다른 날 전체 풀이(D47⑥), 구독 결제(D53)도 범위 밖입니다

## 고칠 수 있는 곳
`server/`, `.github/workflows/server.yml`, `.github/workflows/deploy-*.yml`(D65), `docs/contracts/README.md`의 server 행(계약 PR에서 버전과 상태 한 줄만)과 `docs/contracts/CHANGELOG.md`의 server 절(바뀐 내용을 맨 위에, D131), GitHub Issues(요청·보고 작성, `gh issue list --label to:server`). 그 밖은 읽기만 합니다. 예외로 `docs/local-values.md`(D98)의 server 행은 그 값을 정하거나 바꾸는 PR에서 고칩니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 로컬 값
로컬 값은 `docs/local-values.md`(D98)를 따릅니다. 원본은 `$MYUNGLI_LOCAL_DIR/server/<환경>/`, 저장소 안에는 버려도 되는 산출물만 둡니다. 새 Secret 이름은 그 대장에 적습니다. Terraform state는 저장소 밖 state bucket이 원본입니다(bootstrap 포함, K12).

## 계약
버전과 상태는 [`docs/contracts/README.md`](../docs/contracts/README.md) 표 하나가 기준입니다. 아래는 역할과 상대만 적습니다.

| 계약 | 역할 | 상대 |
| --- | --- | --- |
| `proto/myungli/engine/v1/engine.proto` | **사용** | core |
| `core/message_keys.json` | **사용** (콘텐츠 시드가 모든 키를 3개 언어로 갖췄는지 검사) | core |
| `core/message_params.json` | **사용** (슬롯 `params` 대조) | core |
| `core/evidence_rules.json`, `core/evidence_sources.json` | **사용** (근거 문장 렌더) | core |
| 근거 참조 형식 (`source_ref`) | **사용** (`evidence` 단계) | core |
| 엔진 버전 표기 (`engine_version`, `ruleset_version`) | **사용** (일기 태그 기록, 캐시 키) | core |
| REST API v1 `server/api/openapi.yaml` | **제공** | app |
| 슬롯 명세, 호칭·조사 처리 규칙, 라이팅 검사기 | **사용** (W0 이후) | writing |
| MVP 화면 목록 (IA) `docs/ia/screens.json` | **사용** (`source: content` 슬롯이 콘텐츠 모듈의 템플릿 범위) | 지휘 |

## 검사
CI는 `.github/workflows/server.yml`이고, `ci-gate`가 넘기는 `mode`로 범위를 고릅니다(D81, `docs/workflow.md` §6.2). own은 전체를 돌리고, drift·gate는 계약을 읽는 검사만 돌립니다. 반복 중에는 아래 빠른 경로를 로컬에서 돌립니다(`server/`에서 실행).

* **바뀐 패키지만:** `go test -race $(git diff --name-only origin/main... -- . | grep '\.go$' | sed 's#^server/##' | xargs -n1 dirname | sort -u | sed 's#^#./#')`. DB 테스트(testcontainers)는 Docker가 켜져 있어야 합니다.
* **계약을 바꿨을 때:** `go generate ./... && git status --porcelain`(출력이 비어야 함), `go test -race ./api/ ./seed/... ./legal/... ./internal/content/render/ ./internal/profile/honorific/`, `go test -race -run 'TestRegisterAPI_|TestProblemCodes_|TestLegalPage_|TestAppCheck_' ./internal/httpapi/`
* **엔진 클라이언트나 proto를 바꿨을 때만:** `go test -count=1 -tags enginecontract ./internal/engine/...`(core 이미지를 빌드해 띄우므로 느립니다)
* **commit 전:** `go vet ./... && golangci-lint run ./... && go test -race ./...`. staging 태그를 건드렸으면 `-tags staging`으로 vet·lint를 한 번 더 돌립니다.

## 현재 상태
병합된 일의 경과는 적지 않습니다(PR 본문, 결정 행, git에 있음). 여기에는 진행 중인 일(브랜치, 열린 PR, 막힌 것)만 두고 병합하면 지웁니다(`docs/workflow.md` §3 마무리).

* 기준 문서: spec [`docs/specs/2026-10-11-server-mvp-design.md`](docs/specs/2026-10-11-server-mvp-design.md), 결정 [`docs/decisions.md`](docs/decisions.md)(대체된 결정의 원문은 [`docs/decisions-history.md`](docs/decisions-history.md)). 구현 단계 P1~P9의 계획은 `docs/plans/`에 있습니다.
* **진행 중:** 없음.
* 엔진 서비스의 컨테이너 이미지는 core가 `core/`만으로 빌드되게 맞춥니다(D33, D56). 엔진 쪽 요구(포트, 헬스 체크 등)는 요청함으로 주고받습니다.

## 다음 할 일
1. P8 끝. staging에서 app 실제 FCM adapter(#603)와 함께 알림 하나가 오고 누르면 `today`로 가는지 확인합니다.
2. **REST v1은 freeze(S3, 1.0.0)입니다.** 계약은 하위 호환 추가만 하고(S93), 점검 목록의 "freeze 뒤 할 일"(계산 기준 값, 날짜 기록 읽기, 구매 종류, 예시)을 P8과 함께 minor·patch로 넣습니다.
3. 법적 문서 원문(ko, en, ja의 이용약관과 처리방침, #1120)이 내장됐습니다. 원문이 바뀌면 drift Issue로 옵니다. `go generate ./legal/`로 내장 문서를 다시 만듭니다.
4. writing W1 원고가 다 오면 시드 CI의 `--partial`을 빼고 변환 도구에 `-strict`를 켭니다(S38).
5. P9 남은 일: 사용자 준비(bootstrap, GitHub 변수와 environment, Secret 값, `deploy/terraform/README.md`)와 남은 tfvars 값을 받으면 tfvars PR로 채웁니다. staging 첫 배포에서 엔진 비공개 DNS 경로와 h2c·probe(#79), Cloud SQL IAM 연결, `job retention`의 엔진 호출(S120, Job도 같은 env로 `ENGINE_ADDR`를 받음), 두 결정 행의 확인 항목(S117 프록시 홉·`assetlinks.json`·Apple 복귀, S118 Play 테스트 구매)을 확인하고, 확인되면 #79를 닫습니다. `TRUSTED_PROXY_HOPS`는 2로 정했습니다(S135). 남은 P9: OpenTelemetry. 로그 제외 필터는 S136, 알림 발송 Job은 P8-4, migration 전용 계정 분리는 S137로 끝났습니다.
6. **엔진 배포 순서(S139):** 엔진 규칙 버전을 올리는 PR은 병합 뒤 deploy-server가 staging에 나간 다음 `deploy-engine`을 dispatch로 돌립니다. 관문이 server `/version`을 보고 통과시킵니다. prod는 I4 전이라 승인 대기를 취소합니다.
7. **`LEGAL_BUSINESS_INFO`(S157):** staging 값은 들어 있습니다. prod와 load는 그 환경을 배포하기 전에 값을 넣어야 server가 뜹니다(`deploy/terraform/README.md`).
8. L1(#782, #817): 1회차 [`docs/load/2026-11-05-limit-1/`](docs/load/2026-11-05-limit-1/README.md), 2회차 [`2026-11-09-limit-2/`](docs/load/2026-11-09-limit-2/README.md), 3회차 [`2026-11-09-limit-3/`](docs/load/2026-11-09-limit-3/README.md), 4회차 [`2026-11-09-limit-4/`](docs/load/2026-11-09-limit-4/README.md). S147로 요청당 query 5.9→3.9건, S148로 트랜잭션 약 45% 감소. 한계는 cold, warm 모두 초당 80세션(160에서 멈춤)이고, SQL CPU는 statement나 트랜잭션 수를 따르지 않아 왕복 줄이기는 멈춥니다. 다음 수단은 SQL tier이며 #903(12월 15일까지 tier와 예산 점검)에서 정한 뒤 5회차.
9. 받은 요청 #794(staging 전용 연결 테스트 경로, E2E account_test): 지휘 순서는 L1 1회차 뒤이고 Q1 점검 대상입니다.
10. app 질문이 오면 답합니다.

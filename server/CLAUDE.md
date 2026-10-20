# server — 메인 API 서버 (Go)

이 디렉터리에서 시작한 세션은 **server 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 인증: 카카오·Apple 로그인, 제공자 토큰 검증 후 자체 JWT 발급, 계정과 제공자 연결을 나눠 저장 (D55)
* 배포: GCP Cloud Run(server·엔진 각각, 엔진은 내부 전용 gRPC), Cloud SQL PostgreSQL, Artifact Registry, Secret Manager, GitHub Actions + Workload Identity Federation (D56)
* 사용자 프로필: 출생 정보 저장. 생년월일시, 음력·윤달(KASI 한국 음력, D41), 시간 모름, 성별, 출생 시간대·(선택) 경도 (D18·D29). 호칭 필수 (D36). 생년월일 지원 범위 양력 1900-01-31 ~ 2099-12-31 (D41)
* 일기 CRUD: 저장 시 엔진의 태그 키 전체와 `ruleset_version`, 그때 보인 가이드 질문의 렌더된 원문을 함께 기록 (엔진 spec §7.7·§12, D59④). **하루 1편**(날짜 유일), 지난 날 쓰기 가능, 미래 불가 (D49). 태그별 일기 조회 (D47①). 저장 응답에 대표 태그(키·길흉, 엔진 spec §7.7의 화면 표시용 0~2개, D76)를 담음 (Issue #31)
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
`server/`, `.github/workflows/server.yml`, `.github/workflows/deploy-*.yml`(D65), `docs/contracts/README.md`의 server 행(계약 PR에서), GitHub Issues(요청·보고 작성, `gh issue list --label to:server`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

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

## 현재 상태 (2026-10-20, server 세션 갱신)
* **설계(S1) 완료, 구현 P1(기반과 REST 계약 초안)·P2(인증·계정·약관)·P2a(Apple 웹 로그인 복귀)·P3(프로필·엔진·캐시)·P4(콘텐츠)·P5(일기·일정)·P6(비로그인·참조)·P7(결제와 권한) 완료**입니다: [`docs/specs/2026-10-11-server-mvp-design.md`](docs/specs/2026-10-11-server-mvp-design.md). server 결정은 [`docs/decisions.md`](docs/decisions.md)(S1~S93)에 모읍니다.
* P2로 카카오·Apple 로그인, JWT 발급·refresh rotation, 약관 동의, 계정 삭제 예약·복구, `/v1/me`가 `serve`에 조립됐습니다. P2a(#89)로 Android Apple 웹 로그인이 조립됐습니다(S22). 새 결정은 S15~S24(nonce, 삭제 대기 계정, 도메인별 sqlc, 동의 문서 버전, Apple 토큰 처리, refresh 유예, Apple 웹 교환 코드, 문장 선택 지문, staging 테스트 로그인)입니다.
* P3로 프로필 저장·조회·수정(`PUT/GET/PATCH /v1/me/profile`), 엔진 gRPC 클라이언트·대역, 결과 캐시(`ResultCache`)와 `ruleset_version` 확인, 도시 자료 내장이 조립됐습니다. 계약 변경은 PR #163으로 먼저 병합했습니다. 새 결정은 S25(프로필 Put 멱등)·S26(출생 해시 = 사주 지문)·S27(엔진 연결)·S28(도시 자료)·S29(엔진 검증 시점)·S30(캐시 흐름)·S31(tzdata 내장)입니다. `convertLunarDate`(`POST /v1/lunar-date`)는 core RPC(#164) 병합 뒤 #170으로 조립됐습니다(엔진 `INVALID_ARGUMENT` → 422 `date.invalid`, `OUT_OF_RANGE` → 422 `date.out_of_range`).
* P4로 콘텐츠 모듈이 조립됐습니다: 원고 → 시드 변환(`go generate ./seed/`)과 `seed` 명령, 렌더러(호칭·조사·용어 토큰), 문장 선택·순환·돌봄 상한, 용어 사전(`getGlossary`, ETag), 데일리·캘린더·나의 사주 응답과 잠금(D60, P7에서 실제 판정으로 연결), 문장 반응(`put/deleteReaction`), 시드 CI(`mlw check --partial`). 새 결정은 S33~S44(문장 틀 키, 선택 지문, 변환 때 용어 역조회, 태그 polarity 표, serve는 시드를 넣지 않음, `--partial`, 반응 이력, 계정 advisory lock, 상한 우선, 잠금 시 근거 렌더 생략, 한자 표, 시드 출처 열 없음)입니다.
* P4 후속(브랜치 `server/p4-followups`): drift #250·#255(시드 변환이 용어 id를 슬롯 명세와 대조, S48), 엔진 안내 `Notice.text` 렌더(#232, S49), `Profile.birthCity`(#199, S46), 계약 개정(달력 첫 달 1900-02 #248·S47, `getGlossary`·`putReaction`·`deleteReaction`의 409 `profile.required` 명시).
* P5로 일기·일정이 `serve`에 조립됐습니다: 일기 저장·조회·삭제·복원·목록(저장 때 태그·길흉·`ruleset_version`·가이드 질문 기록, 고칠 때는 본문만 변경), 일정 CRUD·복원·목록(62일 상한), `createSchedule`의 `Idempotency-Key`(24시간 재생). 새 결정은 S50~S64입니다.
* P6로 비로그인·참조가 `serve`에 조립됐습니다: App Check 검증(`createPreview`·`getBirthHour`·`convertLunarDate`, 설정이 비면 503), `getBirthHour`·`convertLunarDate`의 IP별 요청 한도, 시진 확인(엔진 `GetBirthHour`), 미리보기(설치당 1회, 입력 저장 없음), 도시 검색(ETag)과 앱 설정(`getAppConfig`), 요청 언어 선택, 원국 개인 해석(`Chart.personalReadings`), Apple 복귀 페이지 writing 원고, staging 테스트 로그인(`-tags staging`, #93). 계약 개정은 설명과 하위 호환 추가뿐이고 새 결정은 S65~S78입니다. 규칙 정합성 점검 #281도 이 PR에서 정리했습니다.
* P7로 결제와 권한이 `serve`에 조립됐습니다: 결제 표 3개(migration 00012), RevenueCat REST v2 동기화(광고 제거권 이어 붙이기·환불), webhook 멱등 처리와 구매 복원(`restorePurchases`), AdMob SSV 검증과 보상 권한(`rewarded_ad`), 근거 잠금의 실제 판정(D60), 계약 개정(결제 설명, S77 필드 제거). 새 결정은 S79~S89입니다.
* P7 후속(브랜치 `server/p7-followups`, #338 위에 쌓음): 나의 사주 문장 `Chart.ilganHead`·`ilganBody`·`yongsinSummary`(#329, S90), 법적 문서 정적 페이지 `GET /legal/terms`·`/legal/privacy`와 `AppConfig.legal`(#332·D80, S91). 원문 `docs/legal/<언어>/`는 `go generate ./legal/`로 내장하며 아직 원문이 없어 페이지는 404 준비 중입니다. 계약 draft.10(하위 호환 추가). ci-gate server drift 경로에 `docs/legal/<언어>/`가 들어갔습니다(#341).
* S3 준비(브랜치 `server/s3-freeze-prep`, `server/p7-followups` 위에 쌓음): 계약 draft.11. 알림 기기 계약 확정(S92), 호환·버전 정책과 열린 enum(S93), 점검에서 찾은 응답 목록·설명 차이 정리. 점검 목록과 남은 일은 [`docs/plans/2026-10-20-s3-freeze-prep.md`](docs/plans/2026-10-20-s3-freeze-prep.md)입니다.
* 수익화 사이클 M0가 끝나 MVP 범위가 다시 확정됐습니다(D53·D54).
* 엔진 계약의 상태는 계약 표에 있습니다. 계약 메모는 Issue #3(원문 보관: `docs/coordination/2026-10-10-core-to-server-engine-proto-v1.md`)에 있습니다.
* 받은 요청: #141·#152 처리(#152 나머지 ③④⑤는 #167), #170 처리, #55(호칭·조사 규칙과 시드 변환)·#129(용어 id, 값 종류 `text`) P4에서 처리, #79(클라이언트 쪽 완료, 배포 설정은 P9). 앞으로 받은 요청은 `gh issue list --label to:server`.
* 엔진 서비스의 컨테이너 이미지는 core가 `core/`만으로 빌드되게 맞춥니다(D33·D56). 엔진 쪽 요구(포트, 헬스 체크 등)는 요청함으로 주고받습니다.

## 다음 할 일
1. **S3(REST v1 freeze):** 점검 목록의 "freeze 전에 남은 일"(app 생성 옵션 요청 #347의 답, 예시, IA 대조)을 마치고 freeze PR(`info.version` `1.0.0`, 계약 표 상태)을 올립니다. freeze 뒤에는 추가만 합니다(S93).
2. P8(Job: precompute, notify, retention과 익명화)과 `registerDevice`·`deleteDevice` 구현(계약은 draft.11로 확정, S92).
3. 원문 `docs/legal/<언어>/`가 들어오면 drift Issue로 옵니다. `go generate ./legal/`로 내장 문서를 다시 만듭니다.
4. core #304가 반영되면 시진 확인 성별을 `GENDER_UNSPECIFIED`로 되돌립니다(S69).
5. writing W1 원고가 다 오면 시드 CI의 `--partial`을 빼고 변환 도구에 `-strict`를 켭니다(S38).
6. #79 배포 설정(h2c, startup probe, `ENGINE_ADDR`·`ENGINE_AUDIENCE`)과 P6 배포 설정(`FIREBASE_PROJECT_NUMBER`, `TRUSTED_PROXY_HOPS`, `APP_MIN_VERSION_*`, `TEST_LOGIN_SECRET`, staging `-tags staging` 빌드)은 P9에서 합니다.
7. app 질문(#100·#114·#165)이 오면 답합니다.

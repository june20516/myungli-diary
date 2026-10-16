# server — 메인 API 서버 (Go)

이 디렉터리에서 시작한 세션은 **server 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 인증: 카카오·Apple 로그인, 제공자 토큰 검증 후 자체 JWT 발급, 계정과 제공자 연결을 나눠 저장 (D55)
* 배포: GCP Cloud Run(server·엔진 각각, 엔진은 내부 전용 gRPC), Cloud SQL PostgreSQL, Artifact Registry, Secret Manager, GitHub Actions + Workload Identity Federation (D56)
* 사용자 프로필: 출생 정보 저장. 생년월일시, 음력·윤달(KASI 한국 음력, D41), 시간 모름, 성별, 출생 시간대·(선택) 경도 (D18·D29). 호칭 필수 (D36). 생년월일 지원 범위 양력 1900-01-31 ~ 2099-12-31 (D41)
* 일기 CRUD: 저장 시 엔진의 태그 키 전체와 `ruleset_version`, 그때 보인 가이드 질문의 렌더된 원문을 함께 기록 (엔진 spec §7.7·§12, D59④). **하루 1편**(날짜 유일), 지난 날 쓰기 가능, 미래 불가 (D49). 태그별 일기 조회 (D47①). 저장 응답에 대표 태그(키·길흉, 엔진 spec §7.7의 화면 표시용 1~2개)를 담음 (Issue #31)
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
`server/`, `.github/workflows/server.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:server`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| `proto/myungli/engine/v1/engine.proto` | **사용** | core |
| `core/message_keys.json` | **사용** (콘텐츠 시드가 모든 키를 3개 언어로 갖췄는지 검사) | core |
| REST API v1 `server/api/openapi.yaml` | **제공** | app |
| 슬롯 명세, 호칭·조사 처리 규칙, 라이팅 검사기 | **사용** (W0 이후) | writing |
| MVP 화면 목록 (IA) `docs/ia/screens.json` | **참고** (`source: content` 슬롯이 콘텐츠 모듈의 템플릿 범위) | 지휘 |

## 현재 상태 (2026-10-15, server 세션 갱신)
* **설계(S1) 완료, 구현 P1(기반과 REST 계약 초안)·P2(인증·계정·약관)·P2a(Apple 웹 로그인 복귀)·P3(프로필·엔진·캐시) 완료**입니다: [`docs/specs/2026-10-11-server-mvp-design.md`](docs/specs/2026-10-11-server-mvp-design.md). server 결정은 [`docs/decisions.md`](docs/decisions.md)(S1~S32)에 모읍니다.
* P2로 카카오·Apple 로그인, JWT 발급·refresh rotation, 약관 동의, 계정 삭제 예약·복구, `/v1/me`가 `serve`에 조립됐습니다. P2a(#89)로 Android Apple 웹 로그인이 조립됐습니다(S22). 새 결정은 S15~S24(nonce, 삭제 대기 계정, 도메인별 sqlc, 동의 문서 버전, Apple 토큰 처리, refresh 유예, Apple 웹 교환 코드, 문장 선택 지문, staging 테스트 로그인)입니다.
* P3로 프로필 저장·조회·수정(`PUT/GET/PATCH /v1/me/profile`), 엔진 gRPC 클라이언트·대역, 결과 캐시(`ResultCache`)와 `ruleset_version` 확인, 도시 자료 내장이 조립됐습니다. 계약 변경은 PR #163으로 먼저 병합했습니다. 새 결정은 S25(프로필 Put 멱등)·S26(출생 해시 = 사주 지문)·S27(엔진 연결)·S28(도시 자료)·S29(엔진 검증 시점)·S30(캐시 흐름)·S31(tzdata 내장)입니다. `convertLunarDate`(`POST /v1/lunar-date`)는 core RPC(#164) 병합 뒤 #170으로 조립됐습니다(엔진 `INVALID_ARGUMENT` → 422 `date.invalid`, `OUT_OF_RANGE` → 422 `date.out_of_range`).
* 수익화 사이클 M0가 끝나 MVP 범위가 다시 확정됐습니다(D53·D54).
* 엔진 계약 상태: **구현 완료** (main 병합 완료, PR #1 `ec4fc90`). 계약 메모는 Issue #3(원문 보관: `docs/coordination/2026-10-10-core-to-server-engine-proto-v1.md`)에 있습니다.
* 받은 요청: #141·#152 처리(#152 나머지 ③④⑤는 #167), #170 처리, #79(클라이언트 쪽 완료, 배포 설정은 P9). 앞으로 받은 요청은 `gh issue list --label to:server`.
* 엔진 서비스의 컨테이너 이미지는 core가 `core/`만으로 빌드되게 맞춥니다(D33·D56). 엔진 쪽 요구(포트, 헬스 체크 등)는 요청함으로 주고받습니다.

## 다음 할 일
1. 계약 draft.4(#167·#199)가 병합되면 `Profile.birthCity`를 채웁니다(`city.Lookup`, 프로필 언어 이름). `City.longitude`는 `listCities`(P6)에서 채웁니다.
2. #167의 문장 필드(`todayReason`, `Evidence.basis`·`source`, `Glossary.hanja`)는 P4 콘텐츠 모듈이 렌더합니다. 한자 원고는 writing에 요청했습니다.
3. **P4(콘텐츠) 계획**을 씁니다(#55 호칭·조사 규칙 사용법과 원고 → 시드 변환, #129). 넘길 메모는 `docs/plans/README.md` "다음 계획에 넘길 메모"의 P4에 있습니다.
4. #79 배포 설정(h2c, startup probe, `ENGINE_ADDR`·`ENGINE_AUDIENCE`)은 P9에서 합니다. #93(staging 테스트 로그인)도 설계(S24)가 끝났고 구현은 P6/P9입니다.
5. app 질문(#100·#114·#165)이 오면 답합니다.

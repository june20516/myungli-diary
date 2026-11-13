# 통합 로드맵

지휘 세션이 관리합니다. 제품 단계(Phase 1~3)는 비공개 기록 `background/05-roadmap.md`를 따르고, 이 문서는 **Phase 1(MVP) 안에서 서브 프로젝트들이 어떤 순서로 맞물리는지**를 다룹니다.

**제품 지도:** https://claude.ai/artifact/GFLHjAufPE6F4qPyssdfsC (노선도로 진행 상태를 봅니다. 지휘 세션이 정기 일과에서 갱신합니다.)

## 마일스톤

| ID | 마일스톤 | 담당 | 선행 조건 | 끝나면 열리는 것 | 상태 |
| --- | --- | --- | --- | --- | --- |
| R0 | 제품 결정·엔진 설계 | 지휘 | - | C1 | **완료** |
| C1 | 엔진 기반: 시각 변환·원국·판정 규칙 (계획 Task 1~13) | core | R0 | C2 | **완료** |
| C2 | **엔진 gRPC 계약 v1 freeze** (Task 14) | core | C1 | S2, I1 | **완료** |
| C3 | 엔진 완성: 서버·골든 테스트·CI (Task 15~20) | core | C2 | I1 | **완료** |
| S1 | server 설계 (spec·계획) | server | R0, M0 | S2 | **완료** |
| S2 | server 구현: 인증·프로필·일기·콘텐츠 모듈·엔진 클라이언트 | server | S1, C2 | S3, I1 | **완료** |
| S3 | **REST API v1 freeze** | server | S2 | A2, I2 | **완료** |
| A1 | app 설계 (spec·계획), 대역 데이터로 화면 구현 | app | R0, IA, M0, V2 | A2 | **완료** |
| A2 | app의 실제 API 연동: `local` server로 REST 연동, 실제 SDK adapter(카카오·Apple·LINE·Google 로그인 #311, App Link, FCM #347 ②, RevenueCat·AdMob, D91 ①) | app | S3 (A1과 나란히) | I2 | **완료** |
| B0 | 브랜드 기반 확정 (`docs/identity/README.md`) | 지휘 | 브랜드 기반 spec 승인 | W0, V0, IA | **완료** |
| IA | MVP 화면 목록: 화면, 목적, 화면마다 들어갈 문장 슬롯과 컴포넌트 (계약, D39) | 지휘 | B0 | W0 슬롯 목록, V2, A1 | **완료** |
| M0 | 수익화 결정 체계 수립과 첫 사이클, MVP 범위 재검증 | 지휘 | IA | S1·A1 착수 | **완료** |
| W0 | 라이팅 시스템 기반: 보이스·톤 가이드, 슬롯 명세, slop 패턴, 검수 절차, 검사기 | writing | B0 (슬롯 목록은 IA) | W1 | **완료** |
| V0 | 시각 정체성 | design | B0 | V1 | **완료** |
| V1 | **디자인 토큰 freeze** | design | V0 | V2, A1 | **완료** |
| V2 | 컴포넌트 명세 | design | V1, IA | A1 UI 구현 | **완료** |
| W1 | 콘텐츠: 메시지 키별 문장 3개 언어 초안 → 원어민 검수 (D28) | writing → server 시드 | W0, C2(`message_keys.json`) | I3 | **완료** |
| I1 | 통합 1: server ↔ core 실제 gRPC 호출 | 지휘 판단 | C3, S2 | I3, T1 | **완료** |
| I2 | 통합 2: app ↔ server. app E2E(A13)를 staging http 모드로 그대로 돌려 검증합니다(#87) | 지휘 판단 | A2, S3 | I3, T1 | **완료** |
| DS1 | **디자인 시스템 재정비(D107):** 공개 디자인 시스템 레퍼런스 조사 → 규칙(간격, 아이콘, 목록 줄, 버튼 조합, 화면 묶음과 섹션 제목, 눌림, 설명 열기, 시트, 확인 창, 로딩, 전환, 키보드) → 화면 결정 시안(D105) → IA, 컴포넌트 계약, 원고 → app 일괄 구현. 검수 대장 F-001~F-031 | 지휘 + design + writing + app | 검수 회차1 | H1, T1 | **완료** (검수 회차2와 빌드 7 항목 F-032~F-058 모두 끝남, 2026-11-14) |
| H1 | **기준 문서 정리:** 세션이 읽는 문서(`CLAUDE.md`, 결정 로그, 로드맵, 계약 목록)의 앞쪽은 경과 없는 지금 사실, 경과는 뒤쪽이나 별도 파일로 옮기고 2차 참조로 잇기. 처음 읽는 문서 크기 상한(D131) | 지휘 + 각 단위 | 검수 피드백 회차(`docs/review/`) | Q1 | **진행 중** ([spec](specs/2026-11-13-h1-doc-slimming-design.md), [계획](plans/2026-11-14-h1-doc-slimming.md)) |
| Q1 | **T1 전 보안 점검:** 인프라, 배포 경로, server, 엔진, app, 로컬 값 전반. 발견 상세는 비공개 저장소에만(D74). 관문: Critical과 High 0. 준비 메모 [`docs/specs/2026-10-30-security-review-design.md`](specs/2026-10-30-security-review-design.md) | 지휘 + 각 단위 + 독립 점검 | 검수 피드백 회차, H1, staging 기동(P9) | T1 | 시작 전 |
| O1 | **관측:** 앱 크래시(Crashlytics 보고 확인, 심볼 업로드), server와 인프라 알림(5xx, 지연, 인스턴스 상한, DB, Job 실패), 외부 uptime check, 예산 알림. 준비 메모 [`docs/specs/2026-10-30-capacity-observability-design.md`](specs/2026-10-30-capacity-observability-design.md) | 지휘 + server + app | staging 기동(P9) | T1 | **완료** |
| T1 | **비공개 테스트: 테스트용 클라우드에 server와 엔진을 올리고, 테스트 빌드를 배포해 테스터가 실제로 써 봅니다** ① 테스트 인프라: GCP staging 프로젝트, 도메인과 DNS, 비밀 값(외부 준비물 E4, E6~E12) ② server와 엔진 staging 배포(server P9, 엔진 실행 조건 #79). ①②는 I2가 staging에서 app E2E를 돌릴 때 먼저 세우고 T1에서 그대로 씁니다 ③ 테스트 빌드 배포: iOS TestFlight, Android Play 비공개 테스트 트랙(E2, E3) ④ 테스터 초대와 사용: Play 새 개인 계정 조건(테스터 12명 이상이 14일 연속) | 지휘 + server + app + 사용자 | I1, I2, Q1, O1 | I4(Play 비공개 테스트 의무를 이 단계에서 채움), E15(D92: 앱을 받아 본 뒤 사업자등록) | 시작 전 |
| L1 | **부하 테스트와 용량 산정:** 비슷한 범주 앱의 대형, 중형, 소형 활성 사용자 규모를 시나리오로(수치는 비공개 `business/`, D74), 요청당 연산과 비용, 한계에서의 server 응답과 app 대응. 부하 전용 환경 우선. 준비 메모 같은 파일 | 지휘 + server + app | O1 | I4 | **진행 중** (3회차까지 잼, 남은 것 server #817, tier는 2026-12-15 점검 #903) |
| I3 | 통합 3: 데일리·나의 사주·캘린더·일기 전 과정 E2E(app E2E 재사용, #87) | 지휘 판단 | I1, I2, W1 | I4 | - |
| I4 | 스토어 심사·출시 (iOS / Android) | 지휘 + app | I3, T1 | Phase 2 | - |

**통합 마일스톤(I1~I4)의 시작 조건:** 위 선행 조건에 더해 열린 `drift` Issue가 0이어야 합니다(`docs/workflow.md` §6.1).


## 현재 진행 순서 (2026-11-14 기준)
지휘 세션이 상태가 바뀔 때마다 고칩니다. 위 표의 선행 조건을 지금 상태에 대입한 결과입니다. 지난 순서는 [`roadmap-history.md`](roadmap-history.md)에 있습니다.

* **열린 `drift` Issue는 받는 단위의 다음 할 일 맨 앞에 둡니다**(D73, `docs/workflow.md` §6.1). 지금 열린 drift: server #1150(엔진 2026.11.9 따라잡기, PR #1159 병합, `main` 검사 통과 때 닫힘).
* **동시에 도는 단위 세션은 둘까지입니다**(D78). 단위 PR은 사용자가 auto-merge를 걸어 두면 검사 통과 때 병합됩니다(D100 ②). CI는 `gh run watch` 없이 60초 이상 간격으로 확인합니다.
* **목표는 T1(비공개 테스트)입니다. 가장 긴 경로:** H1(기준 문서 정리) → bootstrap 묶음 apply(D103) → Q1(보안 점검) → T1. DS1은 검수 회차2와 빌드 7 항목까지 끝났습니다.
* **실기기:** 빌드 8(app #1162 기록)로 빌드 7 검수 반영(F-053~F-058)을 확인합니다.
* **staging 상태:** server(REST 1.13.1), 엔진(ruleset 2026.11.9), Test Store 결제(D99), AdMob SSV(S126), health(S127), 미리 계산(S128), 아침 알림(S129), O1 알림(S133), 문의 메일(S134), 클라이언트 IP `TRUSTED_PROXY_HOPS=2`(S135), 런타임 DB 권한 분리(S137), 법적 문서 게시(사업자 정보는 server가 로컬 값으로 채움, D126)까지 배포됐습니다. prod 엔진도 2026.11.1입니다. prod server는 설정이 비어 배포를 건너뛰므로, 그동안 생기는 server prod 승인 대기는 지휘가 취소합니다. staging E2E는 `app/tool/patrol_staging.sh`로 돌리며, 실행마다 `support@`로 `[E2E]` 문의 메일이 한 통 옵니다.
* **2026-12-15: Cloud SQL tier와 예산 점검(#903, 사용자 일정).** 그날 활성 사용자와 알림 켠 사용자 추이, L1 측정 결과를 보고 1월 최고 부하(L-1월) 전에 prod tier를 올릴지와 지출 범위를 사용자가 정합니다. I4가 1월 뒤로 가면 "I4 2주 전"으로 옮깁니다. 금액은 비공개 L1 리포트에 있습니다(D74).
* **T1 전에 정할 것: server → app 관문(D110 ⑦).** 실기기 빌드(5)는 REST 1.5.0의 `LuckLevel.very_good`을 몰라 staging 달력 월 응답을 읽지 못했습니다(닫힌 enum). 테스터 기기에는 옛 빌드가 남으므로 T1 전에 앱 지원 REST 버전과 최소 지원 버전(업데이트 안내)을 server, app 설계로 정합니다.
* **Q1로 넘긴 것:** server 직접 주소(run.app)가 열려 있어 IP 한도를 우회할 수 있음(S135, 직접 주소를 끄면 Hosting 공개 주소도 끊김).
* **I4 전에 남은 일:** prod server 설정과 비밀 값, prod `RESEND_API_KEY`, SSV 주소 prod 전환, 스토어 출시 뒤 AdMob 앱 검토, LINE Published, 스토어 지원 연락처 `support@`, 법적 문서 시행일과 prod 사업자 정보 비밀 값(E16, 원문은 게시됨).

| 순서 | 담당 | 할 일 | 끝나면 풀리는 것 |
| --- | --- | --- | --- |
| 1 | 지휘 | H1 루트 몫 → 단위 요청 다섯 | H1 단위 몫 |
| 2 | 각 단위 | H1 단위 몫: 자기 `CLAUDE.md` 현재 상태 정리, 결정 로그 대체 원문을 history로 | H1 끝, bootstrap |
| 3 | 사용자 + 지휘 | bootstrap 묶음 apply(D103) | Q1 |
| 4 | 지휘 + 각 단위 | Q1 보안 점검 | T1 |
| 뒤 | 각자 | core #59, writing #531(MVP 밖), server #794(staging 테스트 연결), #817(L1 후속) | 빈 줄이 생길 때 |
| 관문 | 사용자 | 빌드 8 확인, 테스터 이메일 12개(#535) | T1 |
| 2026-12-15 | 사용자 + 지휘 | Cloud SQL tier와 예산 점검(#903) | I4(1월 최고 부하) |

## 외부 준비물
대장과 절차는 [`docs/external-prep.md`](external-prep.md) 하나입니다(D91 ②). 지휘가 때가 된 항목을 `to:user`·`kind:prep` Issue로 안내합니다. 항목별 지금 상태는 대장이 기준입니다.

## 지휘 세션 미결 (서브 프로젝트 설계 전에 정할 것)
| 항목 | 걸린 곳 | 근거 |
| --- | --- | --- |
| (없음) | | |

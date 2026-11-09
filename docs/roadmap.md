# 통합 로드맵

지휘 세션이 관리합니다. 제품 단계(Phase 1~3)는 비공개 기록 `background/05-roadmap.md`를 따르고, 이 문서는 **Phase 1(MVP) 안에서 서브 프로젝트들이 어떤 순서로 맞물리는지**를 다룹니다.

**제품 지도:** https://claude.ai/artifact/GFLHjAufPE6F4qPyssdfsC (노선도로 진행 상태를 봅니다. 지휘 세션이 정기 일과에서 갱신합니다.)

## 마일스톤

| ID | 마일스톤 | 담당 | 선행 조건 | 끝나면 열리는 것 | 상태 |
| --- | --- | --- | --- | --- | --- |
| R0 | 제품 결정·엔진 설계 | 지휘 | - | C1 | **완료** (D1~D34) |
| C1 | 엔진 기반: 시각 변환·원국·판정 규칙 (계획 Task 1~13) | core | R0 | C2 | **완료** (main 병합 완료, PR #1 `ec4fc90`) |
| C2 | **엔진 gRPC 계약 v1 freeze** (Task 14) | core | C1 | S2, I1 | **완료** (main 병합 완료, PR #1 `ec4fc90`) |
| C3 | 엔진 완성: 서버·골든 테스트·CI (Task 15~20) | core | C2 | I1 | **완료** (main 병합 완료, PR #1 `ec4fc90`, CI check·proto·slow 통과). 후속: 엔진 컨테이너 이미지·health PR #80(#34, 실행 조건 #79) |
| S1 | server 설계 (spec·계획) | server | R0, M0 | S2 | **완료** (PR #62 `8528022`, server 결정 S1~) |
| S2 | server 구현: 인증·프로필·일기·콘텐츠 모듈·엔진 클라이언트 | server | S1, C2 | S3, I1 | **완료** (P1~P7, REST 1.0.0 freeze PR #528 뒤 하위 호환 추가. P8 Job `precompute`(S128), `notify`(S129), `retention`(S106)과 알림 기기 API `registerDevice`, `deleteDevice`까지 구현하고 staging에 배포(P9). 2026-11-09 지휘 확인으로 상태를 고침. 경과는 PR #62~#584와 server 결정 로그) |
| S3 | **REST API v1 freeze** | server | S2 | A2, I2 | **완료** (PR #528 `1.0.0`, S114. IA 화면 40개와 계약 대조, 남은 빈틈은 freeze 뒤 minor. 제품 판단 #527은 D90) |
| A1 | app 설계 (spec·계획), 대역 데이터로 화면 구현 | app | R0, IA, M0, V2 | A2 | **완료** (IA 화면 40개를 대역 데이터로 모두 구현, 마지막 화면 `login-methods`·`account-merge`는 PR #588(2026-10-28). 후속 맞춤 #587·#353·#354·#331은 A2와 나란히. 아키텍처 spec·결정 A1~A15 PR #95, 기반 구현 PR #117: 앱 셸·통신·캐시·디자인 시스템·플랫폼 대역·E2E 뼈대, 결정 A16. 계획 2 온보딩·로그인 PR #149: 화면 13개, 결정 A17~A21, IA v2 반영. 계획 3 오늘·깊이 시트 PR #196: today·풀이·근거·공유 시트, 결정 A22~A27, 컴포넌트 2.3.0 반영. IA v3 화면 PR #215(birthplace 한국 표준 소개·calc-basis, 결정 A28~A31). 계획 4 달력·일정 PR #253(결정 A32~A43, 오늘 대표 태그 D76), 컴포넌트 2.6.0·draft.6 따라잡기 PR #269(A44), 계획 5 일기 1부(컴포넌트·데이터, A45~A53) PR #303, 계획 5 화면 4개·흐름·E2E와 생일 음력 V31 모양 PR #310(A54, 규칙 정합성 #282 마무리), 계획 6 나·설정 PR #345(A55~A66: `my-saju`·`saju-chart`·`settings`·`profile-edit`·`account-delete`·`legal`, drift draft.9~11·IA v4 따라잡기, 열린 enum #347 ①, 화면 스크린샷 도구 #336). 남은 것: 따라잡기 #504·#518·#484·#493과 화면 일 #387(로그인 수단·계정 합치기 화면)·#418·#453. 실제 SDK adapter(계획 7)는 A2로 옮김(D91 ①)) |
| A2 | app의 실제 API 연동: `local` server로 REST 연동, 실제 SDK adapter(카카오·Apple·LINE·Google 로그인 #311, App Link, FCM #347 ②, RevenueCat·AdMob, D91 ①) | app | S3 (A1과 나란히) | I2 | **완료** (실제 SDK adapter와 실기기 확인: Android 1.0.0+4, iOS 1.0.0 (3), 로그인 다섯, App Link, 계정 연결과 합치기, 2026-11-03. 컴포넌트 3.3.0과 빌드 번호 규칙 A104 PR #748, D101 모의 광고 PR #762, D102 문의 화면 PR #779) |
| B0 | 브랜드 기반 확정 (`docs/identity/README.md`) | 지휘 | 브랜드 기반 spec 승인 | W0, V0, IA | **완료** |
| IA | MVP 화면 목록: 화면, 목적, 화면마다 들어갈 문장 슬롯과 컴포넌트 (계약, D39) | 지휘 | B0 | W0 슬롯 목록, V2, A1 | **완료** (D47~D51, `docs/ia/screens.json` v1). v2: 선택 동의 제거(D67)와 계획 2 차이(D68), PR #133. v3: 출생지 화면의 한국 기준 소개·계산 기준 로그인 전 열람(D71), PR #157 |
| M0 | 수익화 결정 체계 수립과 첫 사이클, MVP 범위 재검증 | 지휘 | IA | S1·A1 착수 | **완료** (D53, 비공개 기록 `business/`) |
| W0 | 라이팅 시스템 기반: 보이스·톤 가이드, 슬롯 명세, slop 패턴, 검수 절차, 검사기 | writing | B0 (슬롯 목록은 IA) | W1 | **완료** (PR #36 `7698f52`, 결정 W1~W15, 계약: 슬롯 명세·호칭 조사·검사기) |
| V0 | 시각 정체성 | design | B0 | V1 | **완료** (PR #10 `77b7e4f`, 결정 V1~V7) |
| V1 | **디자인 토큰 freeze** | design | V0 | V2, A1 | **완료** (PR #18 `d049e08`, 계약 1.0.0, 결정 V8~V12) |
| V2 | 컴포넌트 명세 | design | V1, IA | A1 UI 구현 | **완료** (PR #43 `47a1867`, 컴포넌트 계약 1.0.0, 토큰 1.1.0, 결정 V13~V24). 후속 PR #66 `b1317e4`: 컴포넌트 2.0.0(근거 잠금, D60), 결정 V25~V27. PR #83: 2.1.0(문장 조각 `term` 표시, 근거 잠금 슬롯), 결정 V28. PR #110: 2.2.0(용신 근거 줄 이름 슬롯). PR #189: 2.3.0(app 구현 대응, `depth-link` 화면 이동, 글자 수 상한). PR #221: 2.4.0(`city-search` 처리 중·`skeleton`). PR #245: 2.5.0(`lucky-card` 변형 `tag`, D76). PR #261: 2.6.0(app 계획 4 확인, V36~V38). PR #293: 2.6.1(규칙 정합성, D77 슬롯 상한) |
| W1 | 콘텐츠: 메시지 키별 문장 3개 언어 초안 → 원어민 검수 (D28) | writing → server 시드 | W0, C2(`message_keys.json`) | I3 | **완료** (W1-3 용어·근거와 스토어 태그라인 PR #627(W47~W49)로 3개 언어 원고가 모두 참, 원고 검사 `--partial` 제거. 원어민 검수는 완료 조건이 아닌 보강 단계(D70). W1 spec `docs/identity/writing/specs/2026-10-16-w1-content-design.md`. W1-1 오늘 화면·엔진 안내 PR #249, W1-2 사주·개인 해석 PR #254, D77 IA ui 슬롯·남은 ui 원고 PR #279·#297(W33), 기본 깊이 원고 삭제 PR #326(D79), 생일 음력 문구 PR #328(W34). 다음 W1-3 용어·근거. 원어민 검수는 사용자 준비물) |
| I1 | 통합 1: server ↔ core 실제 gRPC 호출 | 지휘 판단 | C3, S2 | I3, T1 | **완료** (2026-11-03 staging 확인: 엔진이 오늘 요청 71건에 200, server의 daily, chart, calendar 응답 200. 엔진 실행 조건 #79) |
| I2 | 통합 2: app ↔ server. app E2E(A13)를 staging http 모드로 그대로 돌려 검증합니다(#87) | 지휘 판단 | A2, S3 | I3, T1 | **완료** (app PR #791, A108: Patrol E2E를 http 모드로 staging에서 통과, 로그인은 S24 테스트 로그인, 계정 연결과 합치기는 실기기 몫, server 어긋남 없음, 2026-11-04) |
| DS1 | **디자인 시스템 재정비(D107):** 공개 디자인 시스템 레퍼런스 조사 → 규칙(간격, 아이콘, 목록 줄, 버튼 조합, 화면 묶음과 섹션 제목, 눌림, 설명 열기, 시트, 확인 창, 로딩, 전환, 키보드) → 화면 결정 시안(D105) → IA, 컴포넌트 계약, 원고 → app 일괄 구현. 검수 대장 F-001~F-031 | 지휘 + design + writing + app | 검수 회차1 | H1, T1 | **검수 회차2 진행 중** (app 구현 끝 PR #872, 회차1 F-001~F-031 끝남. 회차2 원요청 받기 마감(2026-11-10), F-032~F-047 보냄(작업 #892~#937, F-033 끝남). 회차2 항목이 모두 끝나면 완료) |
| H1 | **기준 문서 정리:** 세션이 읽는 문서(`CLAUDE.md`, 결정 로그, 로드맵, 계약 목록)의 앞쪽은 경과 없는 지금 사실, 경과는 뒤쪽이나 별도 파일로 옮기고 2차 참조로 잇기. 준비 메모 [`docs/specs/2026-10-30-context-slimming-design.md`](specs/2026-10-30-context-slimming-design.md) | 지휘 + 각 단위 | 검수 피드백 회차(`docs/review/`) | Q1 | 시작 전 |
| Q1 | **T1 전 보안 점검:** 인프라, 배포 경로, server, 엔진, app, 로컬 값 전반. 발견 상세는 비공개 저장소에만(D74). 관문: Critical과 High 0. 준비 메모 [`docs/specs/2026-10-30-security-review-design.md`](specs/2026-10-30-security-review-design.md) | 지휘 + 각 단위 + 독립 점검 | 검수 피드백 회차, H1, staging 기동(P9) | T1 | 시작 전 |
| O1 | **관측:** 앱 크래시(Crashlytics 보고 확인, 심볼 업로드), server와 인프라 알림(5xx, 지연, 인스턴스 상한, DB, Job 실패), 외부 uptime check, 예산 알림. 준비 메모 [`docs/specs/2026-10-30-capacity-observability-design.md`](specs/2026-10-30-capacity-observability-design.md) | 지휘 + server + app | staging 기동(P9) | T1 | **완료** (server 알림 정책, uptime check, 예산 알림, 대응 절차 PR #764 S133. app Crashlytics 보고와 Android 심볼 업로드 PR #760) |
| T1 | **비공개 테스트: 테스트용 클라우드에 server와 엔진을 올리고, 테스트 빌드를 배포해 테스터가 실제로 써 봅니다** ① 테스트 인프라: GCP staging 프로젝트, 도메인과 DNS, 비밀 값(외부 준비물 E4, E6~E12) ② server와 엔진 staging 배포(server P9, 엔진 실행 조건 #79). ①②는 I2가 staging에서 app E2E를 돌릴 때 먼저 세우고 T1에서 그대로 씁니다 ③ 테스트 빌드 배포: iOS TestFlight, Android Play 비공개 테스트 트랙(E2, E3) ④ 테스터 초대와 사용: Play 새 개인 계정 조건(테스터 12명 이상이 14일 연속) | 지휘 + server + app + 사용자 | I1, I2, Q1, O1 | I4(Play 비공개 테스트 의무를 이 단계에서 채움), E15(D92: 앱을 받아 본 뒤 사업자등록) | 시작 전 |
| L1 | **부하 테스트와 용량 산정:** 비슷한 범주 앱의 대형, 중형, 소형 활성 사용자 규모를 시나리오로(수치는 비공개 `business/`, D74), 요청당 연산과 비용, 한계에서의 server 응답과 app 대응. 부하 전용 환경 우선. 준비 메모 같은 파일 | 지휘 + server + app | O1 | I4 | **진행 중** (1회차 2026-11-05: 한계점 초당 80세션, 첫 병목 Cloud SQL CPU, cold에서 엔진 증설 안 됨. 목표 S, M 버팀, L, L-1월 못 버팀. 알림 나눠 보내기 D109로 L 범위 안. 고칠 것과 2회차는 server 요청. 비공개 시각 리포트) |
| I3 | 통합 3: 데일리·나의 사주·캘린더·일기 전 과정 E2E(app E2E 재사용, #87) | 지휘 판단 | I1, I2, W1 | I4 | - |
| I4 | 스토어 심사·출시 (iOS / Android) | 지휘 + app | I3, T1 | Phase 2 | - |

**통합 마일스톤(I1~I4)의 시작 조건:** 위 선행 조건에 더해 열린 `drift` Issue가 0이어야 합니다(`docs/workflow.md` §6.1).

**병행 가능 구간:** S1 · A1은 M0 뒤에 서로 기다리지 않고 진행합니다. 동시에 진행하면 `git worktree`로 작업 디렉터리를 나눕니다(`docs/workflow.md` §6). B0 이후 W0와 V0도 서로 기다리지 않으며, core·server 흐름과도 따로 진행합니다. 정체성 쪽 순서는 B0 → (W0 ∥ V0) → IA → V1 → V2 → A1 UI 구현입니다. 수익화 사이클 M0는 IA 뒤, S1·A1 착수 전에 돌려 MVP 범위를 다시 확인합니다(D52).

## 현재 진행 순서 (2026-11-09 오후 기준)
지휘 세션이 상태가 바뀔 때마다 고칩니다. 위 표의 선행 조건을 지금 상태에 대입한 결과입니다.

* **열린 `drift` Issue는 받는 단위의 다음 할 일 맨 앞에 둡니다**(D73, `docs/workflow.md` §6.1). 지금 열린 drift는 없습니다.
* **동시에 도는 단위 세션은 둘까지입니다**(D78). 단위 PR은 사용자가 auto-merge를 걸어 두면 검사 통과 때 병합됩니다(D100 ②). CI는 `gh run watch` 없이 60초 이상 간격으로 확인합니다.
* **목표는 T1(비공개 테스트)입니다. 가장 긴 경로:** DS1 검수 회차2 → H1(기준 문서 정리) → bootstrap 묶음 apply(D103) → Q1(보안 점검) → T1. 검수 회차2는 원요청 받기를 마감했습니다(2026-11-10, 빌드(6), 비공개 기록 `review/inbox/2026-11-09-회차2.md`). 항목 F-032~F-047을 단위 작업으로 보냈고(D114~D117), 사용자 선택 관문이 둘 남았습니다: F-044 그날 시트 일정 블록 시안(design #932), F-047 행운 색 비교안(core #937 측정 뒤). design은 앱 아이콘 원본(#942, #908)과 drift부터 정리하고 회차2 작업으로 넘어갑니다. Play 비공개 테스트 의무(테스터 12명 14일 + 심사, #535)가 T1 뒤 출시를 막으므로 테스터 이메일 12개를 지금 모읍니다.
* **T1 전에 정할 것: server → app 관문(D110 ⑦).** 실기기 빌드(5)는 REST 1.5.0의 `LuckLevel.very_good`을 몰라 staging 달력 월 응답을 읽지 못했습니다(닫힌 enum). 테스터 기기에는 옛 빌드가 남으므로 T1 전에 앱 지원 REST 버전과 최소 지원 버전(업데이트 안내)을 server, app 설계로 정합니다.
* **2026-12-15: Cloud SQL tier와 예산 점검(#903, 사용자 일정).** 그날 활성 사용자와 알림 켠 사용자 추이, L1 측정 결과를 보고 1월 최고 부하(L-1월) 전에 prod tier를 올릴지와 지출 범위를 사용자가 정합니다. I4가 1월 뒤로 가면 "I4 2주 전"으로 옮깁니다. 금액은 비공개 L1 리포트에 있습니다(D74).
* **L1:** 3회차까지 쟀습니다. 처음 막히는 곳은 계속 Cloud SQL CPU이고 원인은 query 횟수와 트랜잭션입니다. S147(#898)로 요청당 query가 5.9건에서 3.9건이 되어 cold도 80세션/초를 버티지만 한계 단계는 160 그대로입니다. S148(#902, 트랜잭션 줄이기)이 마지막 코드 작업이고, 남는 몫은 #903의 tier 결정입니다.
* **실기기:** Android, iOS 모두 1.0.0 (6)입니다(main `93f2eb92`, DS1 화면, 컴포넌트 6.0.0, `very_good`). iOS는 TestFlight 업로드를 확인했고, Android는 사용자가 Play 내부 테스트에 올렸습니다. LINE은 Developing 채널이라 Tester 역할 계정만 로그인됩니다(E10, T1 직전 Published).
* **staging 상태:** server(REST 1.9.0, 원전 원문 정자 시드 #876, query 줄이기 S147), 엔진(ruleset 2026.11.1), Test Store 결제(D99), AdMob SSV(S126), health(S127), 미리 계산(S128), 아침 알림(S129), O1 알림(S133), 문의 메일(S134), 클라이언트 IP `TRUSTED_PROXY_HOPS=2`(S135), 런타임 DB 권한 분리(S137)까지 배포됐습니다. prod 엔진도 2026.11.1입니다. prod server는 설정이 비어 배포를 건너뛰므로, 그동안 생기는 server prod 승인 대기는 지휘가 취소합니다. staging E2E는 `app/tool/patrol_staging.sh`로 돌리며, 실행마다 `support@`로 `[E2E]` 문의 메일이 한 통 옵니다.
* **Q1로 넘긴 것:** server 직접 주소(run.app)가 열려 있어 IP 한도를 우회할 수 있음(S135, 직접 주소를 끄면 Hosting 공개 주소도 끊김).
* **I4 전에 남은 일:** prod server 설정과 비밀 값, prod `RESEND_API_KEY`, SSV 주소 prod 전환, 스토어 출시 뒤 AdMob 앱 검토, LINE Published, 스토어 지원 연락처 `support@`, 법적 문서 원문(E16).

| 박자 | 담당 | 할 일 | 막는 것 |
| --- | --- | --- | --- |
| 지금 | 사용자 + 지휘 | 검수 회차2 작업 추적, 관문 F-044(#932 시안), F-047(#937 측정 뒤 비교 페이지). 새 원요청은 회차3 또는 수시로 | H1, T1 |
| 지금 | 사용자 | 테스터 이메일 12개(#535), TestFlight 내부 테스터 | T1 |
| 지금 | design | 앱 아이콘 원본 #942(#908, drift #941 함께) → review sev:2 #918 → sev:3 #920, #929, #934(app이 기다림), #900, #917, #923, #932 | T1 |
| 지금 | writing | drift #940 → review F-032 행운 색 이름(#893), F-041 #925, F-042 #928 | T1 |
| 지금 | app | drift #916 → review sev:1 #922(광고 제거 오류) → sev:2 #919, #924, #926, #931, #936 → sev:3 #921, #930, #935. 앱 아이콘 #909(#942 뒤) | T1 |
| 지금 | server | drift #939 → review F-042 #927, F-045 #933 → staging 테스트 연결(#794). L1 4회차 끝(#907), tier는 12월 점검 | L1 |
| 다음 | 지휘 | D110 ⑦ server → app 관문 설계 요청, H1 준비 | T1 |
| 2026-12-15 | 사용자 + 지휘 | Cloud SQL tier와 예산 점검(#903) | I4(1월 최고 부하) |
| 필요할 때 | writing | 구매 상태 `owned` 키 #531(MVP 밖). core #625 답이 오면 반영 | I3 |
| 지금 | core | review F-047 행운 색 비교안 측정(#937, 결정은 사용자) | T1 |
| 필요할 때 | core | #625(writing 요청, 조후표 칸), #59 남은 2번(스냅샷 분할 검토, 다음 규칙 변경 때) | I3 |

## 외부 준비물
대장과 절차는 [`docs/external-prep.md`](external-prep.md) 하나입니다(D91 ②). 지휘가 때가 된 항목을 `to:user`·`kind:prep` Issue로 안내합니다.

* **지금(사용자):** E3 테스터 12명 모집 #535(T1을 가장 오래 막음), App Store Connect 사용권 계약 동의, #714 빌드가 나오면 Play 내부 테스트 업로드와 TestFlight 내부 테스터 등록, E14 문의 메일 주소. 스토어 상품은 E15 뒤.
* **완료:** E2 Apple Developer, E4 GCP, E5 Firebase(#605), E6 도메인, E7 Apple 로그인, E8 서명 지문, E9 카카오 콘솔, E10 LINE, E11 Google 로그인, E17 staging 몫(#636, prod 비밀 값은 I4 전).
* **T1 직전:** LINE 채널 Published(E10), Google 동의 화면 프로덕션 전환이나 테스터 등록(E11), staging debug token 교체.
* **I4 전(보류):** E13 보상형 단위 SSV 콜백 URL을 staging에서 prod 주소로 바꾸기(#539), E15 사업자등록 #534(앱을 받아 본 뒤, D92), E16 약관과 처리방침 원문(AdMob 동의 메시지가 가리키는 주소, 실제 사용자에게 광고가 나가기 전까지 열려야 함), E18 원어민 검수, E19 정책 검토.

## 지휘 세션 미결 (서브 프로젝트 설계 전에 정할 것)
| 항목 | 걸린 곳 | 근거 |
| --- | --- | --- |
| (없음) | | |

* 결정됨: 소셜 로그인 제공자는 D55(카카오·Apple) → D82(카카오·LINE·Google·Apple, 계정 연결·합치기, 2026-10-21), 서버·엔진 배포 플랫폼은 D56(GCP)입니다(2026-10-11).
* 이관 후 결정됨: "캘린더 길흉 점의 색 규칙"은 design V1에서 정했습니다. 점이 아니라 날짜 칸을 옅게 채웁니다(2026-10-11, design 결정 V10, PR #18).

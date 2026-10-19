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
| S2 | server 구현: 인증·프로필·일기·콘텐츠 모듈·엔진 클라이언트 | server | S1, C2 | S3, I1 | **진행 중** (P1 기반·REST 초안 PR #62, P2 인증·계정·약관 PR #99, P2a Apple 웹 로그인 복귀 PR #113, P3 프로필·엔진·캐시 PR #163·#171(REST draft.3), draft.4 PR #225(근거 문장·도시 경도)·draft.5 PR #233(일정 범위·달력 캐시), P4 콘텐츠 모듈 PR #238(시드·렌더러·운세 operation·용어 사전·반응). 다음 P5 일기·일정) |
| S3 | **REST API v1 freeze** | server | S2 | A2, I2 | 시작 전 |
| A1 | app 설계 (spec·계획), 대역 데이터로 화면 구현 | app | R0, IA, M0, V2 | A2 | **진행 중** (아키텍처 spec·결정 A1~A15 PR #95, 기반 구현 PR #117: 앱 셸·통신·캐시·디자인 시스템·플랫폼 대역·E2E 뼈대, 결정 A16. 계획 2 온보딩·로그인 PR #149: 화면 13개, 결정 A17~A21, IA v2 반영. 계획 3 오늘·깊이 시트 PR #196: today·풀이·근거·공유 시트, 결정 A22~A27, 컴포넌트 2.3.0 반영. IA v3 화면 PR #215(birthplace 한국 표준 소개·calc-basis, 결정 A28~A31). 계획 4 달력·일정 PR #253(결정 A32~A43, 오늘 대표 태그 D76). 다음 계획 5 일기) |
| A2 | app의 실제 API 연동 | app | A1, S3 | I2 | 시작 전 |
| B0 | 브랜드 기반 확정 (`docs/identity/README.md`) | 지휘 | 브랜드 기반 spec 승인 | W0, V0, IA | **완료** |
| IA | MVP 화면 목록: 화면, 목적, 화면마다 들어갈 문장 슬롯과 컴포넌트 (계약, D39) | 지휘 | B0 | W0 슬롯 목록, V2, A1 | **완료** (D47~D51, `docs/ia/screens.json` v1). v2: 선택 동의 제거(D67)와 계획 2 차이(D68), PR #133. v3: 출생지 화면의 한국 기준 소개·계산 기준 로그인 전 열람(D71), PR #157 |
| M0 | 수익화 결정 체계 수립과 첫 사이클, MVP 범위 재검증 | 지휘 | IA | S1·A1 착수 | **완료** (D53, 비공개 기록 `business/`) |
| W0 | 라이팅 시스템 기반: 보이스·톤 가이드, 슬롯 명세, slop 패턴, 검수 절차, 검사기 | writing | B0 (슬롯 목록은 IA) | W1 | **완료** (PR #36 `7698f52`, 결정 W1~W15, 계약: 슬롯 명세·호칭 조사·검사기) |
| V0 | 시각 정체성 | design | B0 | V1 | **완료** (PR #10 `77b7e4f`, 결정 V1~V7) |
| V1 | **디자인 토큰 freeze** | design | V0 | V2, A1 | **완료** (PR #18 `d049e08`, 계약 1.0.0, 결정 V8~V12) |
| V2 | 컴포넌트 명세 | design | V1, IA | A1 UI 구현 | **완료** (PR #43 `47a1867`, 컴포넌트 계약 1.0.0, 토큰 1.1.0, 결정 V13~V24). 후속 PR #66 `b1317e4`: 컴포넌트 2.0.0(근거 잠금, D60), 결정 V25~V27. PR #83: 2.1.0(문장 조각 `term` 표시, 근거 잠금 슬롯), 결정 V28. PR #110: 2.2.0(용신 근거 줄 이름 슬롯). PR #189: 2.3.0(app 구현 대응, `depth-link` 화면 이동, 글자 수 상한). PR #221: 2.4.0(`city-search` 처리 중·`skeleton`). PR #245: 2.5.0(`lucky-card` 변형 `tag`, D76) |
| W1 | 콘텐츠: 메시지 키별 문장 3개 언어 초안 → 원어민 검수 (D28) | writing → server 시드 | W0, C2(`message_keys.json`) | I3 | **진행 중** (W1 spec `docs/identity/writing/specs/2026-10-16-w1-content-design.md`. W1-1 오늘 화면·엔진 안내 PR #249, W1-2 사주·개인 해석 PR #254, 슬롯 명세 v1.5·검사기 v0.7.0. 다음 W1-3 용어·근거. 원어민 검수는 사용자 준비물) |
| I1 | 통합 1: server ↔ core 실제 gRPC 호출 | 지휘 판단 | C3, S2 | I3 | - |
| I2 | 통합 2: app ↔ server. app E2E(A13)를 staging http 모드로 그대로 돌려 검증합니다(#87) | 지휘 판단 | A2, S3 | I3 | - |
| I3 | 통합 3: 데일리·나의 사주·캘린더·일기 전 과정 E2E(app E2E 재사용, #87) | 지휘 판단 | I1, I2, W1 | I4 | - |
| I4 | 스토어 심사·출시 (iOS / Android) | 지휘 + app | I3 | Phase 2 | - |

**통합 마일스톤(I1~I4)의 시작 조건:** 위 선행 조건에 더해 열린 `drift` Issue가 0이어야 합니다(`docs/workflow.md` §6.1).

**병행 가능 구간:** S1 · A1은 M0 뒤에 서로 기다리지 않고 진행합니다. 동시에 진행하면 `git worktree`로 작업 디렉터리를 나눕니다(`docs/workflow.md` §6). B0 이후 W0와 V0도 서로 기다리지 않으며, core·server 흐름과도 따로 진행합니다. 정체성 쪽 순서는 B0 → (W0 ∥ V0) → IA → V1 → V2 → A1 UI 구현입니다. 수익화 사이클 M0는 IA 뒤, S1·A1 착수 전에 돌려 MVP 범위를 다시 확인합니다(D52).

## 현재 진행 순서 (2026-10-20 기준, #253·#254 병합 뒤)
지휘 세션이 상태가 바뀔 때마다 고칩니다. 위 표의 선행 조건을 지금 상태에 대입한 결과입니다.

* **열린 `drift` Issue는 받는 단위의 다음 할 일 맨 앞에 둡니다**(D73, `docs/workflow.md` §6.1). 지금은 server #250(PR #249)·#255(PR #254), design #252(PR #249)·#257(PR #254), app #256(PR #254)입니다. design 실패 원인은 writing 라운드 원고 문장 수를 고정값으로 대조하는 검사(`docs/identity/design/tools/test_lengths.py` `test_corpus_reads_round_choices`, 49 → 61)입니다. 각 단위가 main을 따라잡은 PR이 병합되고 main 검사가 통과하면 `ci-gate`가 함께 닫습니다.
* **writing이 보낸 문구가 도착했습니다:** 엔진 안내 `system.notice`(#232, PR #249)와 새 오류 문구 3건(#237, PR #254). server는 시드 변환과 `Notice.text` 렌더를, app은 대기 테스트(`_awaitingWriting`) 해제를 이어 갑니다.
* **동시에 도는 세션은 둘까지입니다.** 길게 가는 단위 하나(가장 긴 경로)와, 짧게 끝내고 닫는 단위 하나입니다. 나머지는 요청이 왔을 때만 엽니다. 단위 하나가 PR을 올려 병합되기까지를 한 박자로 보고, 박자마다 지휘가 정기 일과를 돕니다.
* **가장 긴 경로:** S2(진행 중, 다음 P5) → S3 → A2 → I2, 그리고 A1(진행 중, 남은 계획 5·6·7) → A2. W1(진행 중, 남은 W1-3) → I3.

| 박자 | 담당 | 할 일 | 막는 것 |
| --- | --- | --- | --- |
| 1 (지금) | server | drift #250·#255(W1-1·W1-2 원고 시드 대조) → #232 notice 시드 변환·`Notice.text` 렌더 → #199(`Profile.birthCity`) → #248(`getCalendar` 1900-01 응답 규칙, 엔진 한계는 core와 확인) → P5(일기·일정) 계획 | S3, app 경도 문단·달력 첫 달 |
| 1 (짧게) | design | drift #252·#257(`test_lengths.py` 라운드 문장 수) → #218(app 계획 4 임시 결정 확인: 양력 전용 date-picker, 진행 중 규칙, 윤달 표기, 삭제 확인 창, day-cell 높이, 여러 줄 text-field, day-sheet, 근거 여러 문단·한자 글꼴·원전 인용 상자) | app 임시 결정 확정(A32~A42) |
| 2 | app | drift #256(남아 있으면) → #237·#232 문구 가져오기 → design #218 답 반영 → 계획 5(일기) | A2, I2 |
| 2 | writing | W1-3 용어·근거(`term.meaning`·`glossary.value_name`·`evidence.basis`·`evidence.source`, `--partial` 제거, 스토어 태그라인). #258(core) 답은 기다리지 않고 지금 `quote`로 씁니다 | I3, server 시드 strict(S38) |
| 3 | server | S3(REST v1 freeze), staging 테스트 로그인·App Check debug token 구현(S24, P6·P9), #79(엔진 실행 조건, D65 배포 workflow) | A2, I2 |
| 필요할 때 | core | #258(원전 `quote` 번체 원문 여부, 막지 않음), #120(core.yml actions), #59 남은 2번(스냅샷 분할 검토, 다음 규칙 변경 때) | - |

## 외부 준비물
| 항목 | 필요한 시점 | 담당 |
| --- | --- | --- |
| 한국천문연구원 API 키 (data.go.kr: 24절기·음양력) | core Task 18 | 사용자 |
| `buf` 설치 | core Task 14 | core 세션 |
| Apple Developer / Google Play 개발자 계정 | I4 (빌드 배포는 A1부터 필요할 수 있음) | 사용자 |
| 영어·일본어 원어민 검수 | W1 | 사용자 (writing W1) |
| ~~배포 플랫폼 선정 (서버·엔진)~~ | S1 | **결정 완료** (D56: GCP Cloud Run + Cloud SQL) |
| GCP 프로젝트 준비: 결제 계정, Artifact Registry·Cloud Run·Cloud SQL·Secret Manager API 사용 설정, GitHub Actions용 Workload Identity Federation (D56) | S1 배포 단계 | 사용자 (설정 절차는 server가 안내) |
| Kakao Developers 앱 등록, Apple Sign in with Apple 설정(Services ID, 키) (D55) | S1·A1 로그인 연동 | 사용자 |
| 개인정보 처리방침과 스토어 개인정보 표시 작성: Firebase(App Check·FCM·Crashlytics) 국외 이전, 카카오·Apple 로그인, AdMob·RevenueCat (D64) | 출시 전 (I4) | 사용자 (초안은 지휘) |
| 서비스 도메인 구입: API 주소, Android App Link(`APP_LINK_BASE`)·`assetlinks.json` 호스팅, Apple Services ID 복귀 주소 (#89, S22) | A1 실제 로그인 연동 전, 늦어도 server 배포(P9) 전 | 사용자 |
| 출시 전 정책 검토: AdMob 보상형 광고 고지 문구(`evidence-sheet.lock.reward`, writing 라운드 R8-4 선택에 "끝까지"가 없음), 스토어 심사 기준 | 출시 전 (I4) | 사용자 (writing·design 지원) |
| 사업자등록, 통신판매업 신고, 스토어 세금·정산 계좌 (D53) | 출시 전 (I4) | 사용자 |
| AdMob 계정, RevenueCat 계정 (D53) | A1 연동 시점 | 사용자 |
| AdMob 보상형 광고 단위 생성, SSV 콜백 URL 설정(server가 주소 안내) (D60) | S2·A1 연동 시점 | 사용자 |
| ~~KASI 자료(테스트 fixture 약 520KB)의 저장소 재배포 허용 범위 확인~~ | 저장소 공개 전 | **확인 완료** (2026-10-10): 공공데이터포털 음양력 정보(15012679)·특일 정보(15012690) 모두 "이용허락범위 제한 없음", 무료. 출처 표기는 core에 요청 |

## 지휘 세션 미결 (서브 프로젝트 설계 전에 정할 것)
| 항목 | 걸린 곳 | 근거 |
| --- | --- | --- |
| (없음) | | |

* 결정됨: 소셜 로그인 제공자는 D55(카카오·Apple), 서버·엔진 배포 플랫폼은 D56(GCP)입니다(2026-10-11).
* 이관 후 결정됨: "캘린더 길흉 점의 색 규칙"은 design V1에서 정했습니다. 점이 아니라 날짜 칸을 옅게 채웁니다(2026-10-11, design 결정 V10, PR #18).

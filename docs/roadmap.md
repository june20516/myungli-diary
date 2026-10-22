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
| S2 | server 구현: 인증·프로필·일기·콘텐츠 모듈·엔진 클라이언트 | server | S1, C2 | S3, I1 | **진행 중** (P1 기반·REST 초안 PR #62, P2 인증·계정·약관 PR #99, P2a Apple 웹 로그인 복귀 PR #113, P3 프로필·엔진·캐시 PR #163·#171(REST draft.3), draft.4 PR #225(근거 문장·도시 경도)·draft.5 PR #233(일정 범위·달력 캐시), P4 콘텐츠 모듈 PR #238(시드·렌더러·운세 operation·용어 사전·반응), P4 후속 PR #262(notice 렌더·`birthCity`, draft.6), P5 일기·일정·`Idempotency-Key` PR #270(draft.7), P6 비로그인·참조와 D66·D60·D75 정리 PR #305(draft.8), P7 결제와 권한(RevenueCat·AdMob SSV·권한 판정)과 S77 필드 제거 PR #338(draft.9), 나의 사주 문장 필드·법적 문서 정적 페이지 PR #342(draft.10, D80), S3 freeze 준비 PR #346(draft.11, 열린 enum·알림 기기 S92·S93). 다음 S3 freeze(app #347 답 뒤), P8 Job) |
| S3 | **REST API v1 freeze** | server | S2 | A2, I2 | 시작 전 |
| A1 | app 설계 (spec·계획), 대역 데이터로 화면 구현 | app | R0, IA, M0, V2 | A2 | **진행 중** (아키텍처 spec·결정 A1~A15 PR #95, 기반 구현 PR #117: 앱 셸·통신·캐시·디자인 시스템·플랫폼 대역·E2E 뼈대, 결정 A16. 계획 2 온보딩·로그인 PR #149: 화면 13개, 결정 A17~A21, IA v2 반영. 계획 3 오늘·깊이 시트 PR #196: today·풀이·근거·공유 시트, 결정 A22~A27, 컴포넌트 2.3.0 반영. IA v3 화면 PR #215(birthplace 한국 표준 소개·calc-basis, 결정 A28~A31). 계획 4 달력·일정 PR #253(결정 A32~A43, 오늘 대표 태그 D76), 컴포넌트 2.6.0·draft.6 따라잡기 PR #269(A44), 계획 5 일기 1부(컴포넌트·데이터, A45~A53) PR #303, 계획 5 화면 4개·흐름·E2E와 생일 음력 V31 모양 PR #310(A54, 규칙 정합성 #282 마무리), 계획 6 나·설정 PR #345(A55~A66: `my-saju`·`saju-chart`·`settings`·`profile-edit`·`account-delete`·`legal`, drift draft.9~11·IA v4 따라잡기, 열린 enum #347 ①, 화면 스크린샷 도구 #336). 다음 계획 7 수익·알림·실제 로그인(#311, #347 ②)) |
| A2 | app의 실제 API 연동 | app | A1, S3 | I2 | 시작 전 |
| B0 | 브랜드 기반 확정 (`docs/identity/README.md`) | 지휘 | 브랜드 기반 spec 승인 | W0, V0, IA | **완료** |
| IA | MVP 화면 목록: 화면, 목적, 화면마다 들어갈 문장 슬롯과 컴포넌트 (계약, D39) | 지휘 | B0 | W0 슬롯 목록, V2, A1 | **완료** (D47~D51, `docs/ia/screens.json` v1). v2: 선택 동의 제거(D67)와 계획 2 차이(D68), PR #133. v3: 출생지 화면의 한국 기준 소개·계산 기준 로그인 전 열람(D71), PR #157 |
| M0 | 수익화 결정 체계 수립과 첫 사이클, MVP 범위 재검증 | 지휘 | IA | S1·A1 착수 | **완료** (D53, 비공개 기록 `business/`) |
| W0 | 라이팅 시스템 기반: 보이스·톤 가이드, 슬롯 명세, slop 패턴, 검수 절차, 검사기 | writing | B0 (슬롯 목록은 IA) | W1 | **완료** (PR #36 `7698f52`, 결정 W1~W15, 계약: 슬롯 명세·호칭 조사·검사기) |
| V0 | 시각 정체성 | design | B0 | V1 | **완료** (PR #10 `77b7e4f`, 결정 V1~V7) |
| V1 | **디자인 토큰 freeze** | design | V0 | V2, A1 | **완료** (PR #18 `d049e08`, 계약 1.0.0, 결정 V8~V12) |
| V2 | 컴포넌트 명세 | design | V1, IA | A1 UI 구현 | **완료** (PR #43 `47a1867`, 컴포넌트 계약 1.0.0, 토큰 1.1.0, 결정 V13~V24). 후속 PR #66 `b1317e4`: 컴포넌트 2.0.0(근거 잠금, D60), 결정 V25~V27. PR #83: 2.1.0(문장 조각 `term` 표시, 근거 잠금 슬롯), 결정 V28. PR #110: 2.2.0(용신 근거 줄 이름 슬롯). PR #189: 2.3.0(app 구현 대응, `depth-link` 화면 이동, 글자 수 상한). PR #221: 2.4.0(`city-search` 처리 중·`skeleton`). PR #245: 2.5.0(`lucky-card` 변형 `tag`, D76). PR #261: 2.6.0(app 계획 4 확인, V36~V38). PR #293: 2.6.1(규칙 정합성, D77 슬롯 상한) |
| W1 | 콘텐츠: 메시지 키별 문장 3개 언어 초안 → 원어민 검수 (D28) | writing → server 시드 | W0, C2(`message_keys.json`) | I3 | **진행 중** (W1 spec `docs/identity/writing/specs/2026-10-16-w1-content-design.md`. W1-1 오늘 화면·엔진 안내 PR #249, W1-2 사주·개인 해석 PR #254, D77 IA ui 슬롯·남은 ui 원고 PR #279·#297(W33), 기본 깊이 원고 삭제 PR #326(D79), 생일 음력 문구 PR #328(W34). 다음 W1-3 용어·근거. 원어민 검수는 사용자 준비물) |
| I1 | 통합 1: server ↔ core 실제 gRPC 호출 | 지휘 판단 | C3, S2 | I3 | - |
| I2 | 통합 2: app ↔ server. app E2E(A13)를 staging http 모드로 그대로 돌려 검증합니다(#87) | 지휘 판단 | A2, S3 | I3 | - |
| I3 | 통합 3: 데일리·나의 사주·캘린더·일기 전 과정 E2E(app E2E 재사용, #87) | 지휘 판단 | I1, I2, W1 | I4 | - |
| I4 | 스토어 심사·출시 (iOS / Android) | 지휘 + app | I3 | Phase 2 | - |

**통합 마일스톤(I1~I4)의 시작 조건:** 위 선행 조건에 더해 열린 `drift` Issue가 0이어야 합니다(`docs/workflow.md` §6.1).

**병행 가능 구간:** S1 · A1은 M0 뒤에 서로 기다리지 않고 진행합니다. 동시에 진행하면 `git worktree`로 작업 디렉터리를 나눕니다(`docs/workflow.md` §6). B0 이후 W0와 V0도 서로 기다리지 않으며, core·server 흐름과도 따로 진행합니다. 정체성 쪽 순서는 B0 → (W0 ∥ V0) → IA → V1 → V2 → A1 UI 구현입니다. 수익화 사이클 M0는 IA 뒤, S1·A1 착수 전에 돌려 MVP 범위를 다시 확인합니다(D52).

## 현재 진행 순서 (2026-10-22 기준, app 계획 6 완료 뒤)
지휘 세션이 상태가 바뀔 때마다 고칩니다. 위 표의 선행 조건을 지금 상태에 대입한 결과입니다.

* **열린 `drift` Issue는 받는 단위의 다음 할 일 맨 앞에 둡니다**(D73, `docs/workflow.md` §6.1). 지금은 app #412(IA 생성 코드 `ia.g.dart`와 REST draft.13 등, 원인 PR은 Issue 본문) 하나입니다. design #395, server #433·#448, writing #443은 PR #439·#438·#436으로 끝났습니다. 단위마다 열린 drift는 하나이고, 따라잡기 전에 계약이 또 바뀌면 그 Issue에 원인 PR이 더해집니다(PR #430). writing #413·#426은 PR #416·#419로 끝났습니다. server·app·design이 쓰는 `mlw check`는 통과해 다른 단위는 막지 않습니다. 받는 단위가 main에서 검사를 통과하면 `drift-close`가 닫습니다. drift는 손으로 닫지 않습니다(닫으면 다음 PR 실행에서 새로 열림).
* **검사 범위·시점 정리(D81) 완료:** 지휘 몫(PR #357·#366)과 다섯 단위 몫(app #364, core #365, server #368, writing #369, design #371)이 끝났고, `ci-gate`가 모든 단위에 `mode`를 넘깁니다(#366·#367·#370·#373). 캐시·건너뛰기는 D81 ⑥을 따릅니다.
* **규칙 정합성 점검(D78) 완료:** 지휘 몫(PR #280·#306)과 다섯 단위 몫(#285·#283·#284·#281·#282, app은 PR #303·#310)이 모두 끝났습니다.
* **동시에 도는 단위 세션은 둘까지입니다**(지휘는 세지 않고, 요청에 답하려고 연 세션은 셉니다, D78). 가장 긴 경로에 있는 단위부터 엽니다. 나머지는 요청이 왔을 때만 엽니다. 단위 하나가 PR을 올려 병합되기까지를 한 박자로 보고, 박자마다 지휘가 정기 일과를 돕니다.
* **가장 긴 경로:** A1(계획 6·7) → A2, 그리고 S2(#381·#351·다음 P7) → S3 → A2 → I2. W1(남은 W1-3)은 I3만 막고, I3는 I1·I2 뒤라 그다음입니다.

| 박자 | 담당 | 할 일 | 막는 것 |
| --- | --- | --- | --- |
| 지금 | app | drift #412(`ia.g.dart`, #408과 같은 PR도 됨) → 계획 7 수익·알림·실제 로그인(#311: 카카오·Apple adapter, D82 범위 확장 #387(LINE·Google adapter, 로그인 수단·계정 합치기 화면), D83 일기 하루 여러 편 #408(입구는 언제나 새 일기, 일기 줄)과 한 날짜 10편 상한 #424(입구 막기, 422), REST draft.13 일기 클라이언트 #437, REST draft.14 LINE·Google 로그인·연결·합치기 #463(떼기·계정 삭제 직전 LINE·Google SDK 허가 취소, D82 ⑤), writing ARB #418, ui 조사 `josaClass` #453(D84), App Link, FCM과 알림 기기 호출 시점 #347 ②, AdMob·RevenueCat 실제 adapter). #311의 release 서명 지문·스토어 URL만 Google Play 개발자 계정(외부 준비물) 뒤 | A1 완료, A2 |
| 지금 | server | D82 인증 확장 #386(계약 draft.14 PR #466 완료 → 제공자·연결 구현 PR → 합치기 구현 PR. 합치기는 같은 날 일기를 10편을 넘어도 모두 옮김, D83 ④. LINE·Google 허가 취소는 app, D82 ⑤), S69 되돌림(core #304 완료) → S3 REST v1 freeze PR(#347 ① 답 받음, S93) → P8 Job(precompute·notify·retention과 익명화). 대운 시작 연도(#351, PR #385 draft.12)와 D83 일기 하루 여러 편(#407, 계약 PR #438·구현 PR #456) 완료 | S2 완료, S3, A2 |
| 다음 | writing | (D82·D83 원고 #388·#409·#425·#441은 PR #419·#436, REST draft.14 오류 문구 #468은 PR #470으로 완료) → W1-3 용어·근거(`term.meaning`·`glossary.value_name`·`evidence.basis`·`evidence.source`, `--partial` 제거, 스토어 태그라인). 원전 `quote`는 글자 그대로(core #258 답). app 계획 6 임시 문구 22개·사주 용어 사전 범주(#331), force-update 사유별 문구(#355, 슬롯 안 `select`) | I3, server 시드 strict(S38) |
| 그다음 | server | staging 테스트 로그인·App Check debug token(S24, P9), #79(엔진 실행 조건, D65 배포 workflow) | I2 |
| 필요할 때 | core | #59 남은 2번(스냅샷 분할 검토, 다음 규칙 변경 때). #304는 PR #432로 완료 | - |
| 다음 | design | app 요청 #475(2.7.0·2.8.0 구현에서 명세와 다르게 둔 값 4가지: 카카오 배지 색, LINE 글자 폭, 일기 줄 간격, 그날 시트 시각 형식) → #353(십성 라벨 자리)·#354(notice-banner 오류 변형, dialog 기본 선택, toast와 하단 CTA 위치). app이 그 화면을 다시 만지기 전에. D82 로그인 수단·계정 합치기(#389)는 컴포넌트 계약 2.7.0(PR #439), D83 같은 날 여러 편 일기 줄과 상한 채운 날 입구(#410)는 2.8.0(PR #458)으로 완료 | - |

## 외부 준비물
| 항목 | 필요한 시점 | 담당 |
| --- | --- | --- |
| 한국천문연구원 API 키 (data.go.kr: 24절기·음양력) | core Task 18 | 사용자 |
| `buf` 설치 | core Task 14 | core 세션 |
| Apple Developer / Google Play 개발자 계정 | A1 계획 7(#311: release·Play App Signing 서명 지문과 스토어 URL을 server에 전달), I4 | 사용자 |
| 영어·일본어 원어민 검수 | W1 | 사용자 (writing W1) |
| ~~배포 플랫폼 선정 (서버·엔진)~~ | S1 | **결정 완료** (D56: GCP Cloud Run + Cloud SQL) |
| GCP 프로젝트 준비: 결제 계정, Artifact Registry·Cloud Run·Cloud SQL·Secret Manager API 사용 설정, GitHub Actions용 Workload Identity Federation (D56) | S1 배포 단계 | 사용자 (설정 절차는 server가 안내) |
| Kakao Developers 앱 등록, Apple Sign in with Apple 설정(Services ID, 키), LINE Developers 로그인 채널(이메일 권한 신청 없음), Google Cloud OAuth client(iOS·Android·server) (D55·D82) | S1·A1 로그인 연동 | 사용자 |
| 개인정보 처리방침과 스토어 개인정보 표시 작성: Firebase(App Check·FCM·Crashlytics) 국외 이전, 카카오·LINE·Google·Apple 로그인(server는 LINE·Google 사용자 token을 보관하지 않음, D82 ⑤), 계정 삭제는 즉시 익명화하고 법정 보관 기록만 남김·지운 일기·일정 보관 기간(D85 ⑤⑦), AdMob·RevenueCat (D64·D82) | 출시 전 (I4), 원문 위치 `docs/legal/`(D80) | 사용자 (초안은 지휘) |
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

* 결정됨: 소셜 로그인 제공자는 D55(카카오·Apple) → D82(카카오·LINE·Google·Apple, 계정 연결·합치기, 2026-10-21), 서버·엔진 배포 플랫폼은 D56(GCP)입니다(2026-10-11).
* 이관 후 결정됨: "캘린더 길흉 점의 색 규칙"은 design V1에서 정했습니다. 점이 아니라 날짜 칸을 옅게 채웁니다(2026-10-11, design 결정 V10, PR #18).

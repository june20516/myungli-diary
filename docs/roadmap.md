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
| S3 | **REST API v1 freeze** | server | S2 | A2, I2 | **완료** (PR #528 `1.0.0`, S114. IA 화면 40개와 계약 대조, 남은 빈틈은 freeze 뒤 minor. 제품 판단 #527은 D90) |
| A1 | app 설계 (spec·계획), 대역 데이터로 화면 구현 | app | R0, IA, M0, V2 | A2 | **완료** (IA 화면 40개를 대역 데이터로 모두 구현, 마지막 화면 `login-methods`·`account-merge`는 PR #588(2026-10-28). 후속 맞춤 #587·#353·#354·#331·#355는 A2와 나란히. 아키텍처 spec·결정 A1~A15 PR #95, 기반 구현 PR #117: 앱 셸·통신·캐시·디자인 시스템·플랫폼 대역·E2E 뼈대, 결정 A16. 계획 2 온보딩·로그인 PR #149: 화면 13개, 결정 A17~A21, IA v2 반영. 계획 3 오늘·깊이 시트 PR #196: today·풀이·근거·공유 시트, 결정 A22~A27, 컴포넌트 2.3.0 반영. IA v3 화면 PR #215(birthplace 한국 표준 소개·calc-basis, 결정 A28~A31). 계획 4 달력·일정 PR #253(결정 A32~A43, 오늘 대표 태그 D76), 컴포넌트 2.6.0·draft.6 따라잡기 PR #269(A44), 계획 5 일기 1부(컴포넌트·데이터, A45~A53) PR #303, 계획 5 화면 4개·흐름·E2E와 생일 음력 V31 모양 PR #310(A54, 규칙 정합성 #282 마무리), 계획 6 나·설정 PR #345(A55~A66: `my-saju`·`saju-chart`·`settings`·`profile-edit`·`account-delete`·`legal`, drift draft.9~11·IA v4 따라잡기, 열린 enum #347 ①, 화면 스크린샷 도구 #336). 남은 것: 따라잡기 #504·#518·#484·#493과 화면 일 #387(로그인 수단·계정 합치기 화면)·#418·#453. 실제 SDK adapter(계획 7)는 A2로 옮김(D91 ①)) |
| A2 | app의 실제 API 연동: `local` server로 REST 연동, 실제 SDK adapter(카카오·Apple·LINE·Google 로그인 #311, App Link, FCM #347 ②, RevenueCat·AdMob, D91 ①) | app | S3 (A1과 나란히) | I2 | 시작 전 (외부 값이 필요한 adapter는 외부 준비물 E7~E13 뒤) |
| B0 | 브랜드 기반 확정 (`docs/identity/README.md`) | 지휘 | 브랜드 기반 spec 승인 | W0, V0, IA | **완료** |
| IA | MVP 화면 목록: 화면, 목적, 화면마다 들어갈 문장 슬롯과 컴포넌트 (계약, D39) | 지휘 | B0 | W0 슬롯 목록, V2, A1 | **완료** (D47~D51, `docs/ia/screens.json` v1). v2: 선택 동의 제거(D67)와 계획 2 차이(D68), PR #133. v3: 출생지 화면의 한국 기준 소개·계산 기준 로그인 전 열람(D71), PR #157 |
| M0 | 수익화 결정 체계 수립과 첫 사이클, MVP 범위 재검증 | 지휘 | IA | S1·A1 착수 | **완료** (D53, 비공개 기록 `business/`) |
| W0 | 라이팅 시스템 기반: 보이스·톤 가이드, 슬롯 명세, slop 패턴, 검수 절차, 검사기 | writing | B0 (슬롯 목록은 IA) | W1 | **완료** (PR #36 `7698f52`, 결정 W1~W15, 계약: 슬롯 명세·호칭 조사·검사기) |
| V0 | 시각 정체성 | design | B0 | V1 | **완료** (PR #10 `77b7e4f`, 결정 V1~V7) |
| V1 | **디자인 토큰 freeze** | design | V0 | V2, A1 | **완료** (PR #18 `d049e08`, 계약 1.0.0, 결정 V8~V12) |
| V2 | 컴포넌트 명세 | design | V1, IA | A1 UI 구현 | **완료** (PR #43 `47a1867`, 컴포넌트 계약 1.0.0, 토큰 1.1.0, 결정 V13~V24). 후속 PR #66 `b1317e4`: 컴포넌트 2.0.0(근거 잠금, D60), 결정 V25~V27. PR #83: 2.1.0(문장 조각 `term` 표시, 근거 잠금 슬롯), 결정 V28. PR #110: 2.2.0(용신 근거 줄 이름 슬롯). PR #189: 2.3.0(app 구현 대응, `depth-link` 화면 이동, 글자 수 상한). PR #221: 2.4.0(`city-search` 처리 중·`skeleton`). PR #245: 2.5.0(`lucky-card` 변형 `tag`, D76). PR #261: 2.6.0(app 계획 4 확인, V36~V38). PR #293: 2.6.1(규칙 정합성, D77 슬롯 상한) |
| W1 | 콘텐츠: 메시지 키별 문장 3개 언어 초안 → 원어민 검수 (D28) | writing → server 시드 | W0, C2(`message_keys.json`) | I3 | **진행 중** (W1 spec `docs/identity/writing/specs/2026-10-16-w1-content-design.md`. W1-1 오늘 화면·엔진 안내 PR #249, W1-2 사주·개인 해석 PR #254, D77 IA ui 슬롯·남은 ui 원고 PR #279·#297(W33), 기본 깊이 원고 삭제 PR #326(D79), 생일 음력 문구 PR #328(W34). 다음 W1-3 용어·근거. 원어민 검수는 사용자 준비물) |
| I1 | 통합 1: server ↔ core 실제 gRPC 호출 | 지휘 판단 | C3, S2 | I3, T1 | - |
| I2 | 통합 2: app ↔ server. app E2E(A13)를 staging http 모드로 그대로 돌려 검증합니다(#87) | 지휘 판단 | A2, S3 | I3, T1 | - |
| T1 | **비공개 테스트: 테스트용 클라우드에 server와 엔진을 올리고, 테스트 빌드를 배포해 테스터가 실제로 써 봅니다** ① 테스트 인프라: GCP staging 프로젝트, 도메인과 DNS, 비밀 값(외부 준비물 E4, E6~E12) ② server와 엔진 staging 배포(server P9, 엔진 실행 조건 #79). ①②는 I2가 staging에서 app E2E를 돌릴 때 먼저 세우고 T1에서 그대로 씁니다 ③ 테스트 빌드 배포: iOS TestFlight, Android Play 비공개 테스트 트랙(E2, E3) ④ 테스터 초대와 사용: Play 새 개인 계정 조건(테스터 12명 이상이 14일 연속) | 지휘 + server + app + 사용자 | I1, I2 | I4(Play 비공개 테스트 의무를 이 단계에서 채움), E15(D92: 앱을 받아 본 뒤 사업자등록) | 시작 전 |
| I3 | 통합 3: 데일리·나의 사주·캘린더·일기 전 과정 E2E(app E2E 재사용, #87) | 지휘 판단 | I1, I2, W1 | I4 | - |
| I4 | 스토어 심사·출시 (iOS / Android) | 지휘 + app | I3, T1 | Phase 2 | - |

**통합 마일스톤(I1~I4)의 시작 조건:** 위 선행 조건에 더해 열린 `drift` Issue가 0이어야 합니다(`docs/workflow.md` §6.1).

**병행 가능 구간:** S1 · A1은 M0 뒤에 서로 기다리지 않고 진행합니다. 동시에 진행하면 `git worktree`로 작업 디렉터리를 나눕니다(`docs/workflow.md` §6). B0 이후 W0와 V0도 서로 기다리지 않으며, core·server 흐름과도 따로 진행합니다. 정체성 쪽 순서는 B0 → (W0 ∥ V0) → IA → V1 → V2 → A1 UI 구현입니다. 수익화 사이클 M0는 IA 뒤, S1·A1 착수 전에 돌려 MVP 범위를 다시 확인합니다(D52).

## 현재 진행 순서 (2026-10-28 기준, app PR #588 병합 뒤)
지휘 세션이 상태가 바뀔 때마다 고칩니다. 위 표의 선행 조건을 지금 상태에 대입한 결과입니다.

* **열린 `drift` Issue는 받는 단위의 다음 할 일 맨 앞에 둡니다**(D73, `docs/workflow.md` §6.1). 지금은 writing #574(design 3.1.0 상한 3개) 하나입니다. app #585는 PR #588로, app #504는 PR #579 뒤 main 검사 통과로, writing #551은 PR #566, design #558은 D95 되돌림, server #550은 PR #571로 끝났습니다. 단위마다 열린 drift는 하나이고, 따라잡기 전에 계약이 또 바뀌면 그 Issue에 원인 PR이 더해집니다(PR #430). 받는 단위가 main에서 검사를 통과하면 `drift-close`가 닫습니다. drift는 손으로 닫지 않습니다(닫으면 다음 PR 실행에서 새로 열림). 맞춘 PR 본문에는 `참고 #<drift>`를 적습니다.
* **검사 범위·시점 정리(D81) 완료:** 지휘 몫(PR #357·#366)과 다섯 단위 몫(app #364, core #365, server #368, writing #369, design #371)이 끝났고, `ci-gate`가 모든 단위에 `mode`를 넘깁니다(#366·#367·#370·#373). 캐시·건너뛰기는 D81 ⑥을 따릅니다.
* **규칙 정합성 점검(D78) 완료:** 지휘 몫(PR #280·#306)과 다섯 단위 몫(#285·#283·#284·#281·#282, app은 PR #303·#310)이 모두 끝났습니다.
* **동시에 도는 단위 세션은 둘까지입니다**(지휘는 세지 않고, 요청에 답하려고 연 세션은 셉니다, D78). 가장 긴 경로에 있는 단위부터 엽니다. 나머지는 요청이 왔을 때만 엽니다. 단위 하나가 PR을 올려 병합되기까지를 한 박자로 보고, 박자마다 지휘가 정기 일과를 돕니다.
* **가장 긴 경로:** A1(따라잡기·남은 화면) → A2(REST 연동, 실제 adapter), 외부 준비물 E2~E12 → server 배포 P9 → I1·I2, 그리고 S2(남은 P8) → A2 → I2. S3(REST v1 freeze)는 PR #528로 끝났습니다. W1(남은 W1-3)은 I3만 막고, I3는 I1·I2 뒤라 그다음입니다.

| 박자 | 담당 | 할 일 | 막는 것 |
| --- | --- | --- | --- |
| 지금 | app | **A2 시작(실제 연동, D91 ①):** `local` server로 REST 연동부터(외부 준비물 없이 가능). **A1 후속:** design·writing 답이 오는 대로 #587(합치기 카드 윤달 표시), #353·#354, 임시 문구 #331·#355. (A1 완료: 마지막 화면 `login-methods`·`account-merge`와 writing ARB #418, REST 1.2.0 drift #585는 PR #588로. 따라잡기 PR #554로 #518·#484·#493, 조사 `josaClass` #453(D84, A86)은 PR #565로, writing PR #566 따라잡기(`style.S9`, 구매 줄 구분자 삭제, A87)는 PR #569로, REST 1.1.0 따라잡기(`Diary.dayKind`, A88)는 PR #578로, design 3.1.0 구매 줄 두 줄 배치(V47, #564)는 PR #579로 완료.) **A2 다음:** 외부 준비물이 오는 대로 실제 SDK adapter(#311 카카오·Apple·LINE·Google, #463(LINE·Google SDK 허가 취소는 D95로 빠짐), App Link, FCM과 알림 기기 호출 #347 ②, RevenueCat·AdMob). app이 따라잡는 PR이 열려 있는 동안에는 app에 닿는 새 변경을 다음 박자로 모음(D91 ③) | A1, A2 |
| 지금 | server | P8 Job(precompute·notify·retention). (D96 `DiarySummary.dayKind` #576은 REST 1.2.0 PR #584로 완료. REST 1.1.0 PR #571로 drift #550, S100의 D95 정정, D90 ① 그날 성격 #530(S116), 합치기 재전송 #552(S115), Google nonce #555 완료. S3 REST v1 freeze는 PR #528로 완료(`1.0.0`, S114). D85·D88 묶음 #481·#492는 계약 draft.15 PR #517, 계정 즉시 삭제 #519, 구매 장부·구매 목록 #520, 계정 합치기 #521로 완료(S105~S113). S69 되돌림은 PR #525. D82 인증 확장 #386은 PR #466·#473·#521로 완료. 대운 시작 연도 #351(PR #385), D83 일기 하루 여러 편 #407(PR #438·#456) 완료) | S2 완료, S3, A2 |
| 지금 | writing | drift #574(design 3.1.0의 `ad-free.buy.cta`, `ad-free.offer.period`, `ad-free.history.cta` 상한) → design 답이 오면 #587 윤달 틀(`accountChoiceSaju`) → 구매 상태 `owned` 키 #531(MVP 밖) → W1-3 용어·근거(`term.meaning`·`glossary.value_name`·`evidence.basis`·`evidence.source`, `--partial` 제거, 스토어 태그라인). 원전 `quote`는 글자 그대로(core #258 답). app 계획 6 임시 문구 22개·사주 용어 사전 범주(#331), force-update 사유별 문구(#355, 슬롯 안 `select`). (drift #551, D93 원고와 검사기 규칙 `style.S9` #546, `ad-free` 구매 버튼·가격·기간 #548은 PR #566으로 완료(W44, 라운드 R20). 맺음 검사 없앰 W43 #543, 맺음 라운드 R18·R19 #544, D85 원고 #482는 #510·#524로 완료) | I3, server 시드 strict(S38), app A1 |
| 다음 | design | #587(계정 합치기 카드 사주 줄의 윤달 표시 자리, writing이 이어서 틀) → #353(십성 라벨 자리)·#354(notice-banner 오류 변형, dialog 기본 선택, toast와 하단 CTA 위치). app이 그 화면을 다시 만지기 전에. (컴포넌트 계약 2.7.0 #439, 2.8.0 #458, 3.0.0 #512, drift #480은 #514로, drift #558은 D95 되돌림으로, 구매 줄 배치와 새 슬롯 상한 #564는 PR #573(3.1.0, V47)으로 완료) | app A1 |
| 그다음 | server | staging 테스트 로그인·App Check debug token(S24, P9), #79(엔진 실행 조건, D65 배포 workflow) | I2 |
| 필요할 때 | core | #59 남은 2번(스냅샷 분할 검토, 다음 규칙 변경 때). #304는 PR #432로 완료 | - |

## 외부 준비물
대장과 절차는 [`docs/external-prep.md`](external-prep.md) 하나입니다(D91 ②). 지휘가 때가 된 항목을 `to:user`·`kind:prep` Issue로 안내합니다.

* **지금 진행 중(사용자):** E3 Google Play 개인 계정과 테스터 12명 모집 #535, E2 Apple Developer #536, E4 GCP #537, E6 도메인 #538, E13 AdMob 계정 #539. E1은 개인사업자(D92). E15 사업자등록·통신판매업 #534는 앱을 받아 본 뒤(보류). server 질문 #540(도메인 연결 방식, Android 상품 유형).
* **server 배포(P9)와 I1·I2는 E7~E12가 모두 있어야 합니다.** server가 staging·prod에서 그 값이 비면 시작하지 않습니다.

## 지휘 세션 미결 (서브 프로젝트 설계 전에 정할 것)
| 항목 | 걸린 곳 | 근거 |
| --- | --- | --- |
| (없음) | | |

* 결정됨: 소셜 로그인 제공자는 D55(카카오·Apple) → D82(카카오·LINE·Google·Apple, 계정 연결·합치기, 2026-10-21), 서버·엔진 배포 플랫폼은 D56(GCP)입니다(2026-10-11).
* 이관 후 결정됨: "캘린더 길흉 점의 색 규칙"은 design V1에서 정했습니다. 점이 아니라 날짜 칸을 옅게 채웁니다(2026-10-11, design 결정 V10, PR #18).

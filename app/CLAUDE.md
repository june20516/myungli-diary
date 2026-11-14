# app — 모바일 앱 (Flutter)

이 디렉터리에서 시작한 세션은 **app 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 플랫폼: iOS / Android (Flutter, 01 §1.1)
* **온보딩:**
  * 생년월일시 입력, 양력·음력(윤달 포함), 시간 모름, 성별 (D18-①②③)
  * 호칭(앱이 사용자를 부를 말) 필수 입력 (D36)
  * 태어난 시간 아래 시진 확인 줄: 기기 지역이 한국일 때만, server의 비로그인 시진 확인 요청 값으로 (D58)
  * 음력 생일은 KASI 한국 음력 기준입니다. 생년월일 입력 범위는 양력 1900-01-31 ~ 2099-12-31입니다 (D41)
  * 출생지는 기본적으로 받지 않고 한국 출생으로 가정해 표시합니다. 언어나 기기의 위치·로케일이 한국이 아닐 때는 도시 단위 출생지 입력을 안내합니다 (D29)
  * 소셜 로그인: 카카오·Apple, iOS·Android 모두. Android의 Apple 로그인은 웹 흐름 (D55)
* **데일리 화면:**
  * 총운 문장, 카드 4종(행운 컬러·방향·숫자·집중 시간), 대표 해시태그 (D18-④⑤, D19~D21·D25)
  * 용신의 날은 "좋은 날"로 강조합니다 (D20)
  * 총운 문장에 대한 반응(좋아요)을 수집합니다 (D40·D57)
  * 깊이 단계(D37) `surface` → `explain` → `evidence`는 카드 → 바텀시트 Half → Full로 펼칩니다 (06 §1)
* **나의 사주:**
  * `surface`: 일간 소개, 용신·행운 색
  * `evidence`: 사주팔자 표, 십성·지장간·12운성·신살, 오행 분포, 용신 근거, 대운·세운 표 (D16·D18-⑥⑦). 표 데이터는 무료이고, 판정 근거·원전·원국 개인 해석·용신 근거는 잠금입니다(`evidenceAccess`, D60)
* **탭 4개:** 오늘·달력·일기·나 (D48). 로그인은 첫 풀이 미리보기 뒤에 받습니다 (D50)
* **캘린더:** 월간 길흉(날짜 칸 채우기, design 결정 V10), 음력 날짜, 절기 (04 §4.4, D18-⑧). 기본 일정(제목·날짜·종일 또는 시간·메모, D47③). 다른 날 전체 풀이는 없고 그날 성격 한 줄만 (D47⑥)
* **일기:** 텍스트 작성, 작성 전 가이드 질문, 저장 후 해시태그 칩 (04 §4.3, D22, 06 §4). 하루 여러 편(한 날짜 최대 10편, D83), 지난 날 쓰기 가능 (D49). 태그를 누르면 같은 태그의 일기 목록 (D47①). 오프라인은 로컬 초안만 (D47②)
* **공유:** 오늘 카드 이미지 공유, 로그인 필요 (D47④). 일기는 공유하지 않습니다
* **수익 (D53·D54):** 탭 루트 4곳 하단 적응형 배너 광고(AdMob 기본안), 광고 동의(iOS ATT, 필요한 지역 UMP)는 이 기기에서 처음 광고를 보이기 전에, 1개월 광고 제거권 인앱결제(자동 갱신 없음, 잠정 가격은 비공개 기록, RevenueCat 기본안)와 구매 복원. 근거 시트의 잠금 안내와 보상형 광고(D60): 사용자가 고를 때만, 매번 보상 고지 후, 광고가 준비됐을 때만 버튼을 켬. SSV `userId`로 계정을 넘기고 server 권한을 받아 엶
* **알림 수신:** 아침 운세 (D18-⑨)
* **안내 문구:** 엔진 notice를 안내 문구로 보여줍니다. 예: 자시 출생 계산 기준(D6), 시간 모름, 절입 전후 출생. 계산 기준은 `calc-basis` 화면이 보여 줍니다(D71, 구현됨)
* **다국어:** 한국어·영어·일본어. UI 문자열은 ARB로 관리하고, 콘텐츠 문장은 서버가 렌더해 줍니다. app은 문장을 고르거나 조사를 붙이지 않고, 받은 그날 응답을 캐시해 오프라인에 보입니다 (D27·D28·D59). ARB 메시지 이름은 lowerCamelCase Dart 식별자이며, writing `slots/ui/`와 검사기 `mlw check-arb`가 이 규약을 전제합니다. A1에서 어긋나면 요청함으로 알립니다
* **화면 구성:** 지휘 세션의 MVP 화면 목록(IA, D39)을 따릅니다.
* **디자인:** 기준은 [`docs/identity/README.md`](../docs/identity/README.md)(브랜드 기반)와 [`docs/identity/design/visual-identity.md`](../docs/identity/design/visual-identity.md)(시각 정체성)입니다. **다크 모드는 MVP에 포함**됩니다(design 결정 V4). 앱 아이콘 원본은 `docs/identity/design/logo/`이고, 크기별 PNG 내보내기는 app이 합니다. 디자인 토큰과 컴포넌트 명세는 design 작업 단위가 제공합니다(V1·V2). UI 구현은 V2 이후에 시작하고, 설계는 병행할 수 있습니다.
* **MVP 범위 밖:** 인스타그램 스토리·카카오 템플릿 공유, 궁합, 일기 감성 코멘트(LLM), 구독 결제는 Phase 2 이후입니다 (05, D22·D23·D53)

## 고칠 수 있는 곳
`app/`, `.github/workflows/app.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:app`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

로컬 값은 `docs/local-values.md`(D98)를 따릅니다. 원본은 `$MYUNGLI_LOCAL_DIR/app/<환경>/`(기본 `~/.config/myungli`), `app/.local/`에는 버려도 되는 산출물만 둡니다. 비밀 파일은 경로로만 다루고 내용을 출력하지 않습니다.

## 검사
작업 단계와 속도에 맞춰 자원을 고릅니다. 반복 중에는 로컬에서, PR 직전 확인이나 CI 환경에서만 나는 문제는 GitHub Actions에서 돌립니다.
* **로컬 빠른 경로(반복 중, D81):** 바꾼 범위의 테스트만 돌립니다. `flutter test <바꾼 테스트 파일·디렉터리>`(예 `flutter test test/features/me test/flows/my_saju_flow_test.dart`), 계약 파일(openapi·IA·토큰·컴포넌트·원고)을 따라잡았으면 `flutter test --tags contract`, golden은 바꾼 컴포넌트의 파일만 `tool/goldens_linux.sh test/design/<파일>`. 기기 E2E는 바꾼 흐름 파일만 `tool/patrol_local.sh patrol_test/<흐름>_test.dart`로 돌리고, 전체 Patrol은 `main` push·밤 실행(`e2e-android`)에 맡깁니다. 아래 전체 검사는 PR 직전에 한 번 돌립니다.
* **CI 범위(D81):** `ci-gate`가 `mode`를 넘깁니다. `own`(app 코드나 `app.yml`이 바뀜)은 전체 `checks`·`goldens`·디버그 APK, `drift`·`gate`는 계약 검사만(생성 코드 차이, ARB 문구, fixture 스키마, E2E 커버리지, `contract` 태그 테스트)입니다. 계약 파일을 읽는 테스트는 `@Tags(['contract'])`를 붙이고, 빠뜨리거나 잘못 붙이면 `test/contract/contract_tags_test.dart`가 실패합니다. `app.yml`의 `push` 트리거는 `e2e-android`만 돕니다.
* **로컬(PR 직전 전체):** `flutter analyze`(app·widgetbook)와 `dart analyze`(app, riverpod_lint plugin 지적까지 나옴 — `flutter analyze`는 같은 코드에서 plugin 지적이 나왔다 안 나왔다 한 적이 있어(원인 미확인) 함께 돌립니다), `flutter test --exclude-tags golden`, `dart format --set-exit-if-changed .`, `dart run tool/ia_coverage.dart --check`, golden은 Docker `tool/goldens_linux.sh`(CI와 같은 Linux 렌더링).
* **로컬 E2E(Patrol):** 에뮬레이터 한 대를 띄우고 `tool/patrol_local.sh [대상]`(예 `tool/patrol_local.sh patrol_test/diary_test.dart`)으로 돌립니다. `patrol test`를 직접 부르지 않습니다. 스크립트가 늘 `-d <에뮬레이터>`로 지정하고(기기가 여러 대면 patrol이 고르라고 묻고 멈춤), 실행 중 기기가 60초 넘게 빠지면 끝내고, 설치 단계 `device offline`처럼 테스트가 하나도 돌지 못한 기기 문제는 기기가 돌아오면 한 번 다시 돌리며, 잠금으로 동시 실행을 막고 실행마다 새 로그(`build/patrol-local/`)를 씁니다. 종료 코드 0 통과, 1 테스트 실패, 2 기기 문제, 3 환경 문제, 4 시간 초과(2026-10-20 에뮬레이터 이탈로 patrol이 멈춘 일에서 나옴). 포트는 기본값(8081·8082) 대신 47281/47282입니다. 개발 기기에서 다른 도구(예 React Native Metro의 `adb reverse tcp:8081`)가 8081을 잡고 있으면 계측이 `BindException`으로 죽습니다. adb 서버는 다른 프로젝트와 함께 쓰므로 `adb kill-server`를 하지 않습니다. CI(`app.yml`)도 같은 포트입니다.
* **GitHub(필요할 때):** 브랜치를 push하고 `gh workflow run app.yml --ref <브랜치>`. `e2e-android`(x86_64·API 34)는 PR 검사(`ci-gate`)에서 건너뛰므로 PR 직전 한 번 확인합니다. 실패하면 artifact `e2e-gradle-reports`에 Gradle 보고서와 기기 전체 logcat이 남습니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| REST API `server/api/openapi.yaml` (freeze는 S3) | **사용** | server |
| `source_ref`·enum 값 (엔진 spec §9·§11, server가 그대로 전달) | **사용** (`evidence` 단계 표시) | core → server |
| 디자인 토큰 (`docs/identity/design/tokens/`, Dart 코드 생성은 app) | **사용** | design |
| 컴포넌트 명세 (`docs/identity/design/components/`) | **사용** | design |
| MVP 화면 목록 (IA) `docs/ia/screens.json` (화면·상태·경로·슬롯·컴포넌트) | **사용** | 지휘 |
| ui 원고 ARB `docs/identity/writing/generated/arb/app_{ko,en,ja}.arb` (`tool/import_writing_arb.dart`로 가져옴) | **사용** | writing |

## 현재 상태 (2026-11-14, app 세션 갱신)
진행 중인 일만 적고, 병합하면 지웁니다(`docs/workflow.md` §3 마무리 2번). 병합된 일의 경과는 PR 본문, 결정 로그(`docs/decisions.md`), git에 있습니다.
* **스토어 빌드 (8) 기록과 H1 문서 정리(#1166, D131)**, 브랜치 `app/store-build-8`, PR #1162. Android와 iOS 1.0.0 (8)(빌드 7 검수 묶음 A147)을 Play 내부 테스트와 TestFlight에 올렸습니다. release 빌드를 기기에서 실행해 보는 확인은 이번에 하지 않았습니다. 막힌 것은 없습니다.

## 다음 할 일
0. **실기기와 도구:**
   * 빌드 8 실기기에서 열림 테두리, 달력 탭 재선택(스크린리더 초점 포함), 근거 아이콘 자리를 확인합니다.
   * Flutter 3.50.0(stable 2026-11-12)으로 올리기: `tool/golden_flutter_version`, 로컬 Flutter, `pubspec.lock`, golden을 한 PR에서(A144). 그 전까지 CI는 3.47.7로 고정입니다.
   * drift #916(PR #993) 남은 사용자 확인: TalkBack이나 VoiceOver를 켜고 일기 쓰기 질문 떼기와 다시 붙이기에서 한 번만 읽히는지.
   * DS1에서 남긴 원고 쪽 확인거리(`stage-strip` 읽기 연결의 "와", en 윤달 태그 대소문자, 세운 연도와 나이 배치, 그날 시트 내역 "지지합 / 합")는 PR #872 본문 "남은 것"에 있습니다.
   * staging 광고(A106): staging release 실기기에서 모의 광고와 보상 열림 확인, iPhone 광고 실패 코드 확인.
   * Crashlytics(A105): iOS는 dSYM 업로드만 했고 보고 시험은 하지 않았습니다(사용자 결정, 아이폰 연결 때 `CRASHLYTICS_SELF_TEST` release로 확인).
1. **계획 7 A2 남은 것(#311·#387·#484):** [spec](docs/specs/2026-10-21-real-login-design.md)·[계획](docs/plans/2026-10-22-real-login.md) "진행 순서"의 A2 열대로 합니다.
   * **실기기 확인 목록(spec §12):** 카카오톡 로그인·계정 로그인·각 취소, LINE 앱·웹 로그인(LINE 앱 없음)·취소, Google 계정 선택·취소와 두 번째 로그인에서 계정 선택이 다시 뜨는지, iOS Apple 로그인·취소, Android Auth Tab이 server 303을 받는지·안내 페이지 intent 복귀·앱이 내려간 뒤 복귀, `assetlinks.json` 검증(`adb shell pm get-app-links app.myungli.diary`), 붙이기·떼기·합치기(LINE·Google 허가는 제공자 쪽 연결 앱 목록에 남는 것이 맞음, D95). Auth Tab이 303을 받지 못하면 안내 페이지 intent 경로를 기본으로 할지 다시 판단하고 server와 문구는 Issue로 올립니다.
   * **App Link(#311 ③):** 패키지 이름·서명 인증서 SHA-256 지문(release·Play App Signing)과 스토어 URL을 server에 알립니다(server `ANDROID_APP_PACKAGE`·`ANDROID_CERT_SHA256`·`ANDROID_STORE_URL`, #114에서 debug 지문만 알림).
   * **광고(A99, #686):** 실기기에서 배너와 보상형 테스트 광고 확인(로그인 뒤 탭 루트, 근거 열람), SSV 끝까지 확인(staging server와 AdMob 콘솔 SSV 콜백 URL 등록 뒤), iOS ATT 실기기 확인(UMP 동의 창이 IDFA 안내 다음에 ATT를 물음, A101), UMP 동의 메시지(E16 뒤 콘솔 게시).
   * **수익 쪽(spec §14, A98):** debug + staging으로 결제 흐름 끝까지 시험(server staging 결제와 Test Store 상품, #683, README "결제 시험"), iOS sandbox에서 `syncPurchasesForResult`가 Apple ID 로그인 창을 띄우는지(뜨면 지휘에 알림, #493), `Purchases.products()` 시간 한계(구매 내역 `loading` 길이도 같은 기준).
   * **`AccountLinker`:** `logIn` 실패를 진입 계산·앱 재개마다 다시 시도하므로, 실제 SDK 오류 의미에 맞춰 재시도 간격과 반복 오류 보고 억제를 정합니다.
   * **#603 아침 알림:** 교체 키(`tag`·`apns-collapse-id`)에 대한 server 답을 확인합니다.
   * en 십성 이름으로 대운 라벨 두 줄 규칙을 실제 글자로 확인합니다.
2. **연결 상태 provider:** 차트·달력은 캐시가 있는 채로 오프라인 진입하면 오늘 화면과 달리 stale·오프라인 표시가 없습니다(`loadCacheFirst`의 `stale`을 버림, A32·A56). 달력·일기 목록 오프라인 배너도 지금은 요청의 `OfflineError`로 판단합니다(`calendar_screen.dart`, 일기 목록은 `ScreenStateView`). provider를 만들 때 오늘과 같은 표시로 맞춥니다.
3. **지운 일기 아래 쌓인 `diary-view`**(태그 모아보기에서 다시 열어 지운 경우)는 돌아가면 "일기를 찾지 못했어요" 안내만 보입니다. 쌓인 화면을 정리할지는 실제 사용을 보고 정합니다.
4. **design #211 응답**은 `ProsePageBody`·skeleton·`InputStep.preface` 간격에 반영합니다. **원전 인용 fixture**는 writing 원고(W1-3)가 오면 채웁니다.
5. **출시 전(I4) 확인:** 실기기에서 iOS 백업 제외(설정 > iCloud > 저장 공간에 DB가 잡히지 않는지)와 기기 이전 뒤 로그아웃 상태로 시작하는지 확인합니다(기반은 빌드·단위 테스트까지만 확인).
   * 글꼴 31M를 release 빌드 다운로드 크기로 보고 subset 여부 재판단. Pretendard 업스트림 저작권 고지(Inter·Source Han Sans·M PLUS 1p `NOTICE.txt`)가 법적으로 충분한지 라이선스 검토. Apple 로고 라이선스 검토도 출시 전에 마칩니다.
6. 받은 요청은 `gh issue list --label to:app`으로 확인합니다. 기반 PR 때 design에 보내는 notice(아이콘 패키지 `phosphor_glyphs`, 탭 아이콘 선택, 컴포넌트 변형 등)의 답도 확인합니다.

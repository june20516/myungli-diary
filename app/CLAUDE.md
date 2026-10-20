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
* **일기:** 텍스트 작성, 작성 전 가이드 질문, 저장 후 해시태그 칩 (04 §4.3, D22, 06 §4). 하루 1편, 지난 날 쓰기 가능 (D49). 태그를 누르면 같은 태그의 일기 목록 (D47①). 오프라인은 로컬 초안만 (D47②)
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

## 검사
작업 단계와 속도에 맞춰 자원을 고릅니다. 반복 중에는 로컬에서, PR 직전 확인이나 CI 환경에서만 나는 문제는 GitHub Actions에서 돌립니다.
* **로컬(반복 중):** `flutter analyze`(app·widgetbook)와 `dart analyze`(app, riverpod_lint plugin 지적까지 나옴 — `flutter analyze`는 같은 코드에서 plugin 지적이 나왔다 안 나왔다 한 적이 있어(원인 미확인) 함께 돌립니다), `flutter test --exclude-tags golden`, `dart format --set-exit-if-changed .`, `dart run tool/ia_coverage.dart --check`, golden은 Docker `tool/goldens_linux.sh`(CI와 같은 Linux 렌더링).
* **로컬 E2E(Patrol):** 에뮬레이터(`~/Library/Android/sdk/emulator/emulator -list-avds`)를 띄우고 `patrol test -t patrol_test --dart-define=API_MODE=fake --test-server-port 47281 --app-server-port 47282`. 포트는 기본값(8081·8082) 대신 이 값을 씁니다. 개발 기기에서 다른 도구(예 React Native Metro의 `adb reverse tcp:8081`)가 8081을 잡고 있으면 계측이 `BindException`으로 죽습니다. CI(`app.yml`)도 같은 값입니다.
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

## 현재 상태 (2026-10-20, app 세션 갱신)
* **계획 5(일기) 진행 중**입니다. 브랜치 `app/diary`, 계획 [`docs/plans/2026-10-20-diary.md`](docs/plans/2026-10-20-diary.md), 결정 A45~A53. Task 1~7(결정·임시 문구 #275, fake 일기 저장소, `tag-chip`·`diary-row`·`diary-editor`·`draft-indicator`·`date-picker` `calendar`(`MonthDatePicker`), 일기 저장소·초안·목록·쓰기·지우기 provider)을 마쳤고, 화면(Task 8~11)과 흐름·E2E(Task 12)가 남았습니다.
  * 첫 PR #303이 drift #271(PR #270)·#277(PR #276)·#286(PR #280)·#295(PR #291)·#301(PR #298)을 맞춥니다: 생성 클라이언트 재생성, IA 슬롯 9개(D77) 상수와 화면이 있는 7곳의 Key·Semantics(toast·notice-banner·근거 시트 제목이 identifier를 받음). 일기 2곳(`diary-edit.save.cta`·`diary-view.deleted.toast`)은 Task 9·10에서 붙입니다. #288(PR #279, writing `diaryEditSave`·`diaryViewDeleted` 원고)은 #279 병합 뒤 `import_writing_arb.dart`로 가져와 임시 표시를 지웁니다. #299(design PR #293)·#300(writing PR #297)도 그 PR이 병합되면 다음 계획 5 PR에서 맞춥니다. 일기 슬롯 3개(`diary-edit.save.cta`·`diary-view.deleted.toast`·`diary-list.pick-date.confirm`)의 Key·Semantics는 화면 Task 8~10에서 붙입니다.
  * #282(규칙 정합성, D78)의 1·7·8번은 이 PR, 2~6번은 계획 5 PR들에 나눠 담고 PR마다 `참고 #282`로 적습니다.
* **컴포넌트·REST 따라잡기(drift #264·#266) 완료**이고 PR #269로 main에 병합됐습니다. 계획 [`docs/plans/2026-10-20-contract-2-6.md`](docs/plans/2026-10-20-contract-2-6.md). `date-picker` `solar`, `text-field` `multiline`, `event-row` `failed`, 그날 시트 일기 쓰기 `filled`(V37), 원전 인용 한자 `fontFallback`, writing 오류 문구 3개(#237), A43 해제.
  * `city.not_found`·`timezone.invalid`는 writing 문구 대기라 4xx 일반 문구입니다(#268).
* **계획 4(달력·일정) 완료**이고 PR #253으로 main에 병합됐습니다. 브랜치 `app/calendar`, 계획 [`docs/plans/2026-10-16-calendar.md`](docs/plans/2026-10-16-calendar.md), 결정 A32~A41(`docs/decisions.md`). `features/calendar`(달 길흉 영구 캐시와 앞뒤 달 미리 받기, `calendar` 탭, `day-sheet`)와 `features/schedule`(보이는 6주 격자 범위만 메모리에 드는 일정, `event-edit` 만들기·고치기·지우기)를 만들었고, `today`에 오늘 일정 한 줄과 `today` → `day-sheet` 출구를 붙였습니다. 시트·확인 창·toast는 셸 바깥에 그려도 글자가 Material 오류 스타일을 받지 않습니다.
  * **E2E 커버리지(도구로 확인, 2026-10-16):** 경로 45/80, 상태 26/54, 결정 5/6(`dart run tool/ia_coverage.dart --check`). Patrol 흐름 `patrol_test/calendar_test.dart`.
  * **drift 따라잡기(#224·#227·#229·#231·#234) 반영 완료**, 결정 A22·A29·A30·A31·A38 해제, A42(근거 여러 문단)·A43(빈 notice 문장 임시 키) 추가. city-search saving·지역 구분자, 생성물·fixture, 일정·반응 404 code·범위 422, calc-basis 도시 경도·서머타임 문구, app-bar 제목 13곳, 용어 한자·오늘 그런 이유·근거 basis·source 문장을 이었습니다.
  * 계획 4 때의 Issue(design #218, writing #237·#232·#236, #217·#219·#220)는 모두 닫혔습니다. 열린 server 요청 #100·#114·#165의 정리는 #282 ⑤입니다.
* **IA v3(#160·#173·#184) 완료**이고 PR #215로 main에 병합됐습니다. 계획 [`docs/plans/2026-10-16-ia-v3.md`](docs/plans/2026-10-16-ia-v3.md), 결정 A28~A31. 새 화면 `calc-basis`와 경도 보정 순수 함수(`features/calc_basis/model/time_basis.dart`)가 있습니다. #199·#201·#214의 반영은 위 drift 따라잡기로 끝났고, 남은 것은 아래 "다음 할 일" 2입니다.
* **계획 3(오늘·깊이 시트) 완료**이고 PR #196으로 main에 병합됐습니다. 계획: [`docs/plans/2026-10-15-today-depth.md`](docs/plans/2026-10-15-today-depth.md)
* **계획 2(온보딩·로그인) 완료**이고 PR #149로 main에 병합됐습니다. 계획 [`docs/plans/2026-10-14-onboarding-login.md`](docs/plans/2026-10-14-onboarding-login.md), 결정 A17~A21. 화면 13개(launch~ad-consent)와 새 계정 흐름 `welcome → 온보딩 → preview → login → consent → 프로필 저장 → notify-ask → ad-consent → today`, fake 시나리오 표는 [`README.md`](README.md)에 있습니다.
* **기반 계획(task 1~23) 완료**이고 PR #117로 main에 병합됐습니다(2026-10-13). spec [`docs/specs/2026-10-13-app-architecture-design.md`](docs/specs/2026-10-13-app-architecture-design.md), 계획 [`docs/plans/2026-10-13-foundation.md`](docs/plans/2026-10-13-foundation.md), 결정 A1~A16. 실행·생성 코드·테스트·CI는 [`README.md`](README.md)에 있습니다.
  * **남은 판단:** 글꼴 subset 여부는 release 빌드 크기로 다시 판단합니다(기반 Task 5 측정, `assets/fonts` 31M).
* 보낸 요청: #84(IA 사주 변경 확인 창, 닫힘·반영됨: 슬롯 119), #86(Crashlytics, 닫힘, **D64**: 크래시 기록에 일기 본문·출생 정보·호칭 금지), #88(오류 code 목록, 닫힘), #89(Apple App Link, 닫힘. 실제 adapter는 계획 7에서 server 결과를 따름). #90(ARB 키를 IA 슬롯 id의 lowerCamelCase로, writing, 닫힘·#128로 원고 도착). #85(ci-gate에 app CI 연결, 닫힘: ci-gate 연결 PR #125 병합, app PR 검사는 ci-gate가 부름). **열려 있음:** #87(제품 지도의 E2E 결과 표시와 통합 E2E 재사용). 계획 2에서 보낸 요청: #140(root, IA 출구·`notify-ask` 허락 슬롯·content 슬롯과 응답 차이), #141(server, 프로필 읽기·City 지역 이름·음력 변환·Preview 문장), #142(design, 명세 차이 9가지), #143(writing, 남은 임시 문구·입력칸 이름≠hint·카카오 ja·ICU plural).
* **UI 문구 원고(#128):** writing 생성 ARB를 `dart run tool/import_writing_arb.dart`로 app ARB에 합칩니다(절차는 [`README.md`](README.md)). 원고가 있는 키는 writing 문구·설명이고, app에만 있는 임시 키는 `@키.description`에 `임시`가 있고, 허용 목록은 `test/contract/app_bar_title_contract_test.dart`의 `_allowedTemporaryKeys`입니다(결정 A7·A53, 지금은 일기 화면 문구 #275 등). en·ja는 원어민 검수 전 초안입니다.
* **아직 남은 외부 준비물(계획 7·출시 전):** 카카오·Apple·Firebase(FCM, Crashlytics)·AdMob·RevenueCat 계정과 키, Android App Link 도메인 검증. 사용자 몫입니다(`docs/roadmap.md` 외부 준비물). Android SDK 라이선스 동의는 로컬에서 Android 빌드가 막히면 확인합니다.
* MVP 범위는 수익화 사이클 M0에서 다시 확정됐습니다(D53·D54).
* **REST API**: `server/api/openapi.yaml`(OpenAPI 3.1, 버전·상태는 [`docs/contracts/README.md`](../docs/contracts/README.md)). freeze(S3) 전에는 하위 호환이 깨지는 변경이 있을 수 있고, 그때 server가 `kind:notice`로 알립니다. 규칙은 계약의 `info.description`에 모두 있습니다(Issue #63).
  * 오류는 RFC 9457 problem+json이고 `code`로 분기합니다. 사용자 문구는 app이 `code`로 만듭니다(D59⑤). 400은 형식·범위 위반(`request.invalid`), 422는 의미 검사(`request.inconsistent`, `date.invalid`, 엔진 판정)입니다.
  * null을 쓰지 않습니다. "모름"·"건너뜀"·"묻지 않음"은 상태 필드로 옵니다. PATCH에서 필드가 없으면 "바꾸지 않음"입니다.
  * 근거 열람 권한은 응답의 `evidenceAccess`(`unlocked`·`locked`)로 옵니다(D60).
  * 콘텐츠 문장은 조각 배열 `segments`로 옵니다. 용어 조각에는 `term`이 붙습니다. 위치 숫자는 쓰지 않습니다(server 결정 S9). `term` 조각의 표시는 design이 정합니다.
  * 시각은 기본 UTC입니다. 화면 표시용 시각(집중 시간, 절기 시각)만 프로필 시간대 offset으로 옵니다.
  * **오류 code 목록**은 `Problem.code`의 `x-problem-codes`입니다(#88). 사용자에게 보일 수 있는 code는 모두 `problemMessages`(`lib/core/l10n/error_messages.dart`)에 임시 문구가 있고, ARB 키는 `error` + code의 lowerCamelCase입니다(`auth.exchange_invalid` → `errorAuthExchangeInvalid`). `reward.*`는 AdMob SSV 웹훅 전용이라 뺍니다. 계약 대조는 `test/contract/problem_codes_contract_test.dart`입니다.
  * **인증 규칙(#100·#114):** nonce 원문(16~256자)은 server에, SHA-256 소문자 hex는 제공자에 보냅니다(`lib/core/platform/nonce.dart`). Apple은 iOS native(`AppleNativeAuth` → `loginApple`)와 Android 웹(`AppleWebAuth`, authorize URL·App Link `/auth/apple` 복귀의 `state` 검증 → `completeAppleWebLogin`)으로 나뉩니다(`clientType` 제거). 삭제 대기 계정(`status: pending_deletion`)은 진입 계산이 `revokeAndSignOut`(server `logout` best-effort 뒤 로컬 로그아웃)하고 로그아웃 갈래로 보냅니다. `getMe` 401도 남은 토큰을 지우고 로그아웃합니다. 403 `consent.required`는 `AuthEvent.consentRequired`로 진입을 다시 계산합니다. 503 `auth.provider_unavailable`은 로그아웃하지 않습니다.
* **계정 연결과 로그아웃 정리(최종 review I1·I2):** 모든 로그아웃은 `TokenStore.signOut`의 `signedOut` 이벤트 하나를 거칩니다(`discardWithoutEvent`는 fake 시작·재설치 토큰 폐기·테스트 전용). 이벤트를 받으면 `SignOutCleaner`가 모든 계정의 캐시·초안과 온보딩 입력을 지우고(기기 플래그 유지), `AccountLinker`가 `Purchases.logOut`·`CrashReporter.setUser(null)`을 부릅니다. 로그인·세션 복원의 계정 연결(`Purchases.logIn`·`setUser`)은 `meProvider` 하나를 출처로 `AccountLinker`가 합니다. 화면 이동 breadcrumb은 라우터 delegate를 듣습니다(`lib/app/router/screen_breadcrumbs.dart`). Android 백업은 끄고, iOS는 DB 디렉터리(Application Support/Database)를 백업에서 빼고 Keychain을 `first_unlock_this_device`로 둡니다. 설치 표시가 없으면 이전 설치의 Keychain 토큰을 버립니다. 구매 계정 연결이 실패하면 다음 진입 계산·앱 재개 때 다시 시도합니다. IA에 없는 경로는 `onException`이 갈래의 첫 화면으로 보냅니다.
* **컴포넌트 명세**: 근거 깊이 잠금(잠김 4상태, `lock.veil`, `sentence-block` `locked`), 모양 규칙(동작은 둥근 사각, 표시·고르기는 알약), 화면 좌우 여백 `space.20`, 글자 수 상한이 들어갔습니다(PR #66, Issue #65).
  * #82(결정 V28): `term` 조각은 IA에 `term-token`이 있는 화면(today·day-sheet·tag-diary·my-saju·saju-chart)에서만 칩입니다. `SentenceBlock`이 slotId 첫 마디 화면으로 정하고(`termStyle`로 직접 정할 수도 있음), preview(`diary-row`)와 공유 이미지는 일반 글자입니다(`RenderedTextView.termStyle`, `lib/core/ia/ia_lookup.dart`).
  * #81: 잠긴 문장 라벨은 "구역 이름(`saju-chart.yongsin.title`), 잠김"입니다(`SentenceBlock.lockedNameSlotId`).
* **IA**(#135 D67, #157 D71): `consent.optional.label` 제거, D68(#140)로 `notify-ask.cta.allow` 추가. `system-apple-return.page.*`는 server 안내 페이지 문구라 app이 그리지 않습니다. D68은 그 밖에 `onboard-gender`·`birthplace`의 `notify-ask` 출구, `onboard-time.hour.confirm`의 ui 전환(지지 이름 ARB `branch*`는 원고 틀 `{branch}시`에 맞춰 '시' 없이), 슬롯이 모두 ui인 화면 5곳의 `sentence-block` 제거입니다. 시스템 화면 `system-push`(아침 알림 문장, 호칭 없음, D62)와 `system-apple-return`(Android Apple 로그인 복귀를 앱이 열지 못할 때의 server 안내 페이지, D66)이 있습니다.
* 광고 제거권을 만료 전에 다시 사면 남은 기간에 이어 붙습니다(D61). 계산은 server가 합니다.
* 도시 목록은 GeoNames `cities15000`(CC BY 4.0)으로 server가 만듭니다. **앱 오픈소스 고지(`legal`)에 출처를 표기합니다**(Issue #48 항목 5, #165, 계획 6).
* 받은 notice: Issue #19(토큰), #44(컴포넌트·토큰), #65(컴포넌트), #82(컴포넌트: `term` 표시는 `RenderedTextView`·`SentenceBlock`, 잠김 라벨 이름은 `SentenceBlock` locked에 반영), A1 착수 안내(#30). 받은 요청 #128(ui 원고 첫 판)과 #135(IA v2)는 계획 2 Task 20에서 반영했습니다(`writing/ia-v2-consent` 병합, 생성 코드 갱신, 가져오기 도구. 이 app PR이 #133·#138을 함께 품는 최종 PR). 받은 요청 #100(인증 규칙)·#114(Apple 웹 로그인, PR #113)는 기반 범위만 반영했고 남은 일은 아래 계획 7입니다. 앞으로 받은 요청은 `gh issue list --label to:app`.
* 반응 버튼(`reaction-button`)은 총운 문장에만 붙습니다(D57).

## 다음 할 일
1. **열린 drift 먼저:** #271·#277·#286·#295·#301은 PR #303이 닫습니다. #288·#299·#300은 원인 PR(#279·#293·#297)이 병합되면 다음 계획 5 PR에서 맞춥니다. PR #303 병합 뒤 화면은 새 브랜치(`--no-track`)에서 이어 갑니다. 이어서 #282 2~6번을 계획 5 PR마다 나눠 처리합니다(A7·A38 D77 반영, V31 음력 목표 모양, A18·A27·A32 갱신, #100·#114·#165 정리, golden Flutter 버전 고정 결정). writing #260(윤달 초하루 표지 문구)이 오면 `dayCellDataOf`의 `lunarText`에 붙입니다(A40).
2. **IA v3·drift 남은 대기.** 도시 경도(A29)·서머타임 문구(A31)·`calc-basis` 제목(A30)·app-bar 제목 13곳은 반영했습니다. 남은 것: 화면 9곳의 `<화면>.bar.title` 제목은 해당 화면을 만드는 계획 5·6에서 붙입니다(임시 키 허용 목록 `test/` 대조가 알려 줍니다, A30). #211(design) 응답은 `ProsePageBody`·skeleton·`InputStep.preface` 간격에 반영합니다. `settings` → `calc-basis` 출구는 계획 6(나·설정)에서 연결합니다.
3. **계획 5(일기) 나머지:** Task 8~12(`diary-list`·`diary-edit`·`diary-view`·`tag-diary` 화면, 흐름·E2E·golden). 계획 4가 넘긴 것:
   * `diary-view`·`diary-edit`은 날짜를 `?date=YYYY-MM-DD` 계약으로 받습니다(`lib/app/router/app_router.dart`의 `dateQuery`·`datedPathOf`). `day-sheet`의 일기 입구가 이미 이 경로로 엽니다(`today` 가이드 카드는 날짜 없이 오늘로 엽니다).
   * `date-picker`의 `calendar` 변형은 `MonthDatePicker`(Task 6)이고 미래 날짜·오늘이 든 달 뒤를 막습니다.
   * 연결 상태 provider가 생기면 달력 오프라인 배너를 그것으로 바꿉니다. 지금은 달·일정 요청의 `OfflineError`로 판단합니다(`calendar_screen.dart`).
4. **원전 source fixture.** 근거 `source` 문장의 표시는 연결했고(A22 해제, `repeat`·한자 `fontFallback`은 PR #269), 원전 인용 fixture는 writing 원고(W1-3)가 오면 채웁니다.
5. **writing 대기 문구.** `city.not_found`·`timezone.invalid` 문구가 오면 `test/contract/problem_codes_contract_test.dart`의 `_awaitingWriting`에서 지우고 `problemMessages`에 연결합니다(대기 테스트가 실패해 알려 줍니다).
6. **이후 계획으로 넘긴 사항**
   * 계획 6(나·설정): 근거 시트의 원국표와 "내 사주에서는" 개인 해석(`EvidenceSubject`에 차트 주제를 더해 잠금 해제 흐름을 그대로 씀), `legal`에 GeoNames 출처 고지(#165).
   * 계획 6(설정·계정): 자발적 로그아웃과 계정 삭제(`deleteMe` 202 뒤, 계정이 삭제 대기가 되어도 토큰은 `logout`에 쓸 수 있음)는 `revokeAndSignOut`(`lib/app/entry/sign_out.dart`)을 부릅니다. 둘 다 `signedOut` 이벤트로 정리·SDK 해제·진입 재계산이 돕니다. `discardWithoutEvent`를 쓰면 정리가 돌지 않습니다.
   * 계획 7(수익·알림): `SignOutCleaner`에 알림 기기 해제(`deleteDevice`) 연결(기기 id 저장 포함). 실제 SDK adapter(카카오·Apple·Firebase·AdMob·RevenueCat)로 override합니다. RevenueCat·Crashlytics adapter는 인터페이스만 구현하면 됩니다. 호출(`logIn`·`logOut`·`setUser`·`breadcrumb`)은 `AccountLinker`와 라우터가 이미 합니다. `AccountLinker`는 `logIn` 실패를 진입 계산·앱 재개마다 다시 시도하므로, 실제 SDK 오류 의미에 맞춰 재시도 간격과 반복 오류 보고 억제를 정합니다. Crashlytics adapter는 `sanitizeAccountId`·`sanitizeScreenId`를 거칩니다(D64). App Link `/auth/apple`은 IA 화면이 아니라 라우터 `onException`이 첫 화면으로 보내므로, 그보다 먼저 가로채는 전용 처리를 둡니다. 카카오·Apple adapter는 받은 원문 nonce를 `hashNonce`해 제공자에 보냅니다. Android Apple 웹 adapter는 `buildAppleAuthorizeUri`(Services ID, server 콜백 `redirect_uri`)로 브라우저를 열고 App Link `/auth/apple`(또는 안내 페이지 intent) 복귀를 `parseAppleWebReturn`으로 해석합니다. App Link intent filter와 **패키지 이름·서명 인증서 SHA-256 지문(debug·release·Play App Signing)과 스토어 URL을 #114에 알리는 일**도 이 계획입니다(server `ANDROID_APP_PACKAGE`·`ANDROID_CERT_SHA256`·`ANDROID_STORE_URL`).
   * 계획 6(설정·프로필 수정):
     * `profile-edit`은 `onboard-*`·`birthplace`를 수정 모드로 열 때 현재 값을 `push` extra로 넘깁니다(호칭 `String`, 생일 `BirthDateValue`). extra가 없으면 프로필 사본(`cachedProfileProvider`)에서 시작합니다.
     * 사본의 알림 값을 읽을 때 `updateProfile` fixture가 요청과 무관한 고정 응답인 점을 다시 확인합니다.
     * `toBirth(deviceRegionIsKorea)`는 한국 기기면 도시가 남아 있어도 `not_asked`·`Asia/Seoul`입니다(D29). 해외 출생 한국 거주자는 `profile-edit`에서 출생지를 지정할 수 있어야 합니다.
     * 수정 모드는 `context.pop(값)`을 받아 저장과 무거운 변경 확인 창(A6)을 합니다.
   * 계획 7(수익·알림, 실제 adapter):
     * 근거 시트의 보상형 광고(`Ads.loadRewarded`·`RewardedAdHandle.show`)와 공유(`ShareSheet.sharePng`)를 실제 AdMob·OS 공유 adapter로 바꿉니다. 화면과 잠금 해제 흐름(A26)은 인터페이스만 보므로 adapter만 더합니다.
     * 실제 로그인 adapter는 SDK 취소를 `SocialSignInCancelled`로 바꿔 던집니다(login 화면이 취소 안내를 정합니다).
     * **로그아웃 때 server 기기 등록 해제(`deleteDevice`)와 `push.deviceId` 삭제를 반드시 연결합니다**(`SignOutCleaner`, `_guard`로 감쌈). 지금은 로그아웃해도 기기 등록이 남아 이전 계정의 아침 알림이 이 기기로 계속 올 수 있습니다. 다른 사람이 같은 기기로 로그인하면 이전 계정의 운세가 알림으로 보이는 개인정보 문제라, 계획 7에서 실제 FCM을 붙일 때 함께 막습니다.
     * 스토어 앱 id(iOS App Store id, Android 스토어 URL)를 `force-update`의 스토어 열기에 연결합니다.
     * `social-login-button` 공식 자산 확인: Apple 로고 라이선스 검토, 카카오 심볼 색(파일 #191919, 가이드 표 #000000) 확인, 카카오 버튼 ja 문구는 writing W22 원고("Login with Kakao")로 정해졌습니다.
7. **출시 전(I4) 확인:** 실기기에서 iOS 백업 제외(설정 > iCloud > 저장 공간에 DB가 잡히지 않는지)와 기기 이전 뒤 로그아웃 상태로 시작하는지 확인합니다(기반은 빌드·단위 테스트까지만 확인).
   * 글꼴 31M를 release 빌드 다운로드 크기로 보고 subset 여부 재판단. Pretendard 업스트림 저작권 고지(Inter·Source Han Sans·M PLUS 1p `NOTICE.txt`)가 법적으로 충분한지 라이선스 검토. Apple 로고 라이선스 검토도 출시 전에 마칩니다.
8. 받은 요청은 `gh issue list --label to:app`으로 확인합니다. 기반 PR 때 design에 보내는 notice(아이콘 패키지 `phosphor_glyphs`, 탭 아이콘 선택, 컴포넌트 변형 등)의 답도 확인합니다.

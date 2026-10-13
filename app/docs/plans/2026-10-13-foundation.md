# app 기반 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 계획 2~7이 화면만 더하면 되도록 Flutter 앱의 뼈대를 세웁니다. 뼈대에는 계약 생성 코드, 대역 서버, 로컬 저장, 진입 갈래, 디자인 시스템 기반, 공통 컴포넌트, 테스트·E2E·CI가 들어갑니다.

**Architecture:** 계약 파일(openapi·IA·토큰·컴포넌트 명세)을 원본으로 두고, Dart 코드를 생성하거나 테스트로 대조합니다. 데이터는 생성 클라이언트 → Dio interceptor(공통 헤더·인증·대역) 순서로 흐릅니다. 상태는 Riverpod provider로 엮고, 외부 SDK는 인터페이스 뒤의 대역으로 둡니다. fake 모드로 앱 전체가 server 없이 돕니다.

**Tech Stack:** Flutter stable, Riverpod 3.x(코드 생성 없음), go_router, Dio, drift, flutter_secure_storage, timezone, intl·gen-l10n, phosphor_flutter, Widgetbook, Patrol, very_good_analysis, Python(uv, jsonschema)

**Spec:** `app/docs/specs/2026-10-13-app-architecture-design.md` (결정은 `app/docs/decisions.md` A1~A15)

## 시작 전 (사용자)

* 이 Mac에 Flutter SDK가 없습니다. spec §9의 개발 환경대로 설치하고 `flutter doctor`에 빨간 항목이 없게 합니다(Flutter, Xcode, Android Studio·SDK·에뮬레이터, VS Code 확장).
* 작업 디렉터리는 `../myungli-diary-app`(worktree)입니다. 이 plan의 브랜치는 `app/foundation`이고 `origin/main`에서 땁니다(`--no-track`, 직후 `git push -u origin app/foundation`). `app/design` PR(spec)이 먼저 병합되면 그 위에서, 아니면 `app/design`을 merge해서 시작합니다.

## Global Constraints

* 앱 식별자는 `app.myungli.diary`(iOS `PRODUCT_BUNDLE_IDENTIFIER`, Android `applicationId`·`namespace`)이고, Dart 패키지 이름은 `myungli_diary`입니다(결정 A14).
* Flutter는 stable을 따라갑니다. `pubspec.yaml`에는 `environment.sdk` 하한만 두고 FVM은 쓰지 않습니다. `pubspec.lock`은 commit하며 pre-release 의존성은 쓰지 않습니다(결정 A11). 패키지는 `flutter pub add`로 그때의 안정판을 받습니다.
* lint는 `very_good_analysis`와 `riverpod_lint`를 쓰고 `flutter analyze` 경고 0을 유지합니다.
* 생성 코드(`**/gen/**`, `*.g.dart`, l10n 출력)는 commit하고 손으로 고치지 않습니다. CI는 다시 생성했을 때 차이 0을 확인합니다.
* 계약 파일 경로는 `app/` 기준 상대 경로(`../server/api/openapi.yaml`, `../docs/ia/screens.json`, `../docs/identity/design/tokens/`, `../docs/identity/design/components/`)로 읽습니다.
* 위젯은 토큰의 **의미 역할**만 씁니다. 원시 팔레트(`color.sage.*`·`color.coral.*`·`color.neutral.*`·`color.white`)는 생성 코드에 노출하지 않습니다.
* 명세에 없는 Material 효과(물결, 그림자, 표면 색조, 상태 겹침 색)를 끄고, 스피너를 쓰지 않습니다.
* 사용자에게 보이는 문자열은 모두 ARB를 거칩니다. ARB 키는 lowerCamelCase입니다. IA 슬롯 문구 키는 슬롯 id의 lowerCamelCase(하이픈·점은 단어 경계)이고, 임시 문구는 `@키.description`에 `임시`를 적습니다(결정 A7).
* 화면 뿌리와 슬롯 위젯에는 생성된 IA id 상수를 Key와 Semantics `identifier`로 붙입니다(spec §6.6).
* 코드 주석은 저장소 관례대로 한국어로 씁니다. commit 메시지는 `feat(app): …`, `test(app): …`, `ci(app): …`, `docs(app): …` 형식입니다.
* TDD: 모든 task는 실패하는 테스트로 시작합니다.
* 비정상 종료 보고(Crashlytics)의 로그·custom key·breadcrumb에 **일기 본문, 출생 정보, 호칭을 넣지 않습니다**(D64 ②). 계정 id(UUID)만 사용자 식별값으로 씁니다.

## Review Focus

1. 기기 시간대가 프로필 시간대와 다를 때(예: 서울 프로필로 LA 여행 중), 또는 서머타임이 바뀌는 날 → "오늘"은 프로필 현재 시간대의 날짜이고 자정 갱신이 한 번만 일어나야 합니다(Task 12).
2. 오프라인에서 access token이 만료돼 refresh가 **네트워크 오류**로 실패할 때 → 로그아웃되면 안 됩니다. `offline` 오류로 남고 연결되면 다시 시도해야 합니다. 로그아웃은 `auth.refresh_reused`나 refresh의 401일 때만입니다(Task 9).
3. 같은 기기에서 로그아웃한 뒤 다른 계정으로 로그인할 때 → 이전 계정의 캐시·초안·온보딩 입력이 보이면 안 됩니다(Task 11).
4. fake 모드에서 fixture가 없는 요청 → 앱이 멈추지 않고 501 `not_implemented` Problem으로 오류 화면을 보여야 합니다(Task 10).
5. 글자 크기 2.0에서 고정 칸 컴포넌트 → 1.3배에서 멈추고, 나머지는 잘리지 않고 줄바꿈해야 합니다(Task 16 golden 조합).

---

### Task 1: 프로젝트 생성과 품질 기준

**Files:**
- Create: `app/pubspec.yaml`, `app/analysis_options.yaml`, `app/lib/main.dart`, `app/ios/**`, `app/android/**`, `app/.gitignore`
- Create: `app/.vscode/extensions.json`, `app/.vscode/launch.json`, `app/.vscode/settings.json`
- Test: `app/test/smoke_test.dart`

**Interfaces:**
- Produces: 패키지 `myungli_diary`, `flutter test`·`flutter analyze`가 도는 프로젝트

- [ ] **Step 1:** `app/`에서 `flutter create --org app.myungli --project-name myungli_diary --platforms ios,android .`를 실행합니다. 이미 있는 `CLAUDE.md`·`docs/`는 그대로 둡니다.
- [ ] **Step 2:** 식별자를 `app.myungli.diary`로 바꿉니다: iOS `Runner.xcodeproj`의 `PRODUCT_BUNDLE_IDENTIFIER`(Runner, RunnerTests는 `app.myungli.diary.RunnerTests`), Android `app/build.gradle(.kts)`의 `namespace`·`applicationId`, Kotlin `MainActivity` 패키지 경로. 확인: `grep -rn "myungliDiary\|com.example" ios android`의 출력이 비어 있어야 합니다.
- [ ] **Step 3:** 실패하는 smoke 테스트를 씁니다. `test/smoke_test.dart`: `testWidgets('앱이 뜬다', ...)`는 `const MyungliApp()`을 pump하고 `find.byType(MyungliApp)`이 하나인지 확인합니다. `flutter test test/smoke_test.dart` → FAIL(`MyungliApp` 없음).
- [ ] **Step 4:** `lib/main.dart`의 카운터 예제를 지우고, `class MyungliApp extends StatelessWidget`(빈 `WidgetsApp`이나 `MaterialApp`)을 둡니다. `flutter pub add dev:very_good_analysis`를 실행하고 `analysis_options.yaml`에서 include합니다.
- [ ] **Step 5:** `.vscode` 세 파일을 만듭니다.
  * extensions: `Dart-Code.dart-code`, `Dart-Code.flutter`
  * launch: 구성 `fake`(`--dart-define=API_MODE=fake`), `http`(`--dart-define=API_MODE=http`, `--dart-define=API_BASE_URL=http://localhost:8080`)
  * settings: `editor.formatOnSave`, `source.organizeImports`
- [ ] **Step 6:** `flutter test && flutter analyze` → PASS, `No issues found!`
- [ ] **Step 7:** Commit `feat(app): Flutter 프로젝트 생성(app.myungli.diary)과 lint 기준`

### Task 2: app CI

**Files:**
- Create: `.github/workflows/app.yml`

**Interfaces:**
- Produces: job `checks`. 이후 task가 단계를 덧붙입니다. `workflow_call`을 지원합니다.

- [ ] **Step 1:** `app.yml`을 씁니다.
  * 트리거: `pull_request`·`push`(main)에 경로 필터(spec §9 목록), `workflow_call`, `workflow_dispatch`. `ci-gate` 연결(#85) 전까지 `pull_request` 트리거를 유지합니다(ci-gate.yml 머리 주석 절차).
  * job `checks`(ubuntu-latest, `working-directory: app`): `subosito/flutter-action`(channel stable, cache), `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build apk --debug`(Java 17 설정 포함).
- [ ] **Step 2:** 확인합니다: `uvx actionlint .github/workflows/app.yml` → 출력 없음.
- [ ] **Step 3:** Commit `ci(app): app 검사 workflow`

### Task 3: IA id 상수 생성기

**Files:**
- Create: `app/tool/gen_ia.dart`, `app/lib/core/ia/gen/ia.g.dart`, `app/lib/core/ia/ia_model.dart`
- Test: `app/test/tool/gen_ia_test.dart`

**Interfaces:**
- Produces:
  * `abstract final class ScreenIds { static const String today = 'today'; … }`: 화면 36개. 이름은 id의 lowerCamelCase입니다(`onboard-call` → `onboardCall`).
  * `abstract final class SlotIds { static const String todayGuideQuestion = 'today.guide.question'; … }`: 슬롯 전부(2026-10-13 기준 119개). 이름은 슬롯 id의 lowerCamelCase입니다(A7 규칙과 같음).
  * `const List<IaScreen> iaScreens`. `IaScreen` 필드는 `id`, `tab`(String?), `presentation`(`IaPresentation` enum: page·halfSheet·fullSheet·system), `auth`(`IaAuth`: guest·member·any), `states`(List\<String>), `exits`(List\<IaExit(to, trigger)>), `components`(List\<String>)입니다.
  * `String iaKey(String id)`: id → lowerCamelCase 변환 함수. 생성기와 ARB 규칙이 같이 씁니다.
  * 명령: `dart run tool/gen_ia.dart`(입력 `../docs/ia/screens.json`, 출력 `lib/core/ia/gen/ia.g.dart`)

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `iaKey('evidence-sheet.lock.cta') == 'evidenceSheetLockCta'`
  * `iaKey('onboard-call') == 'onboardCall'`
  * `iaKey('system-push.morning.body') == 'systemPushMorningBody'`
  * 작은 JSON 문자열을 생성 함수 `String generateIaSource(Map<String, Object?> json)`에 넣으면 `ScreenIds`·`SlotIds`·`iaScreens` 선언이 담긴 문자열이 나오는지 확인합니다.
- [ ] **Step 2:** `flutter test test/tool/gen_ia_test.dart` → FAIL
- [ ] **Step 3:** `tool/gen_ia.dart`에 `iaKey`(`lib/core/ia/ia_model.dart`에 두고 tool이 import)와 `generateIaSource`, 파일 쓰기 `main`을 구현합니다. 출력 첫 줄은 `// 생성 코드: dart run tool/gen_ia.dart. 손으로 고치지 않습니다.`이고, `dart format`을 적용한 결과를 씁니다.
- [ ] **Step 4:** 테스트 → PASS. `dart run tool/gen_ia.dart`를 실행하고, `grep -c "static const String" lib/core/ia/gen/ia.g.dart`가 `screens.json`의 화면 수 + 슬롯 수(지금 36+119=155)와 같은지 확인합니다.
- [ ] **Step 5:** `app.yml`에 단계 "생성 코드 차이 확인"(`dart run tool/gen_ia.dart && git diff --exit-code`)을 더합니다.
- [ ] **Step 6:** Commit `feat(app): IA id 상수 생성`

### Task 4: 디자인 토큰 생성기

**Files:**
- Create: `app/tool/gen_tokens.dart`, `app/tool/tokens/dtcg.dart`, `app/lib/design/tokens/gen/tokens.g.dart`
- Test: `app/test/tool/gen_tokens_test.dart`

**Interfaces:**
- Produces (`tokens.g.dart`):
  * `final class ColorTokens`: 의미 역할 색 필드. 이름은 `color.` 뒤 경로의 lowerCamelCase입니다(`color.bg.base` → `bgBase`, `color.ohaeng.wood.bg` → `ohaengWoodBg`, `color.ohaeng.wood.swatch` → `ohaengWoodSwatch`). 상수는 `lightColors`, `darkColors`입니다.
  * `final class TypeTokens`: `type.*` → `TextStyle` 필드(`fontFamily`, `fontFamilyFallback`, `fontSize`, `fontWeight`, `letterSpacing`, `height`, `fontFeatures`). 상수는 `koType`(영어도 씀), `jaType`입니다.
  * `abstract final class Space`(`s2`, `s4`, …), `Radii`(`radius.*`), `Motion`(`Duration` 필드 `short`, `fade`, …와 `Cubic` 곡선 필드), `Shadows`(`List<BoxShadow>`)
  * `final class GradientTokens`(`LinearGradient today`, 각도 160°는 `$extensions`에서 읽음). 상수는 `lightGradients`, `darkGradients`입니다.
  * 명령: `dart run tool/gen_tokens.dart`

- [ ] **Step 1:** 실패하는 테스트를 씁니다. 실제 토큰 파일을 읽어 다음을 확인합니다.
  * 참조 해석: `color.seal.fill`의 값이 `color.action.primary`와 같은 hex입니다.
  * 알파: 라이트 `color.chip.bg`의 alpha가 0.70, 다크가 0.08입니다. `color.scrim`은 0.32 / 0.50입니다.
  * 짝 파일의 역할 이름 집합이 같습니다(라이트·다크, ko·ja).
  * 원시 팔레트 이름(`sage`, `coral`, `neutral`, `white`)이 생성 소스에 필드로 나오지 않습니다.
  * `type.*`의 `lineHeight` 배수가 `TextStyle.height`로, `fontFeatures: ["tnum"]`이 `FontFeature.tabularFigures()`로 바뀝니다.
  * 깨진 참조가 있는 입력에는 `TokenError`를 던집니다.
- [ ] **Step 2:** `flutter test test/tool/gen_tokens_test.dart` → FAIL
- [ ] **Step 3:** 구현합니다.
  * `tool/tokens/dtcg.dart`: `Map<String, ResolvedToken> resolveTheme(List<Map<String, Object?>> files)`. 테마 하나는 primitive + 색 모드 + 글자 언어 파일입니다(토큰 README "조합"). 참조는 재귀로 풀고 순환은 `TokenError`입니다.
  * `tool/gen_tokens.dart`: 테마 4조합을 풀어 위 클래스를 씁니다.
- [ ] **Step 4:** 테스트 → PASS. `dart run tool/gen_tokens.dart && flutter analyze` → 경고 0
- [ ] **Step 5:** `app.yml` 생성 코드 차이 단계에 `dart run tool/gen_tokens.dart`를 더합니다.
- [ ] **Step 6:** Commit `feat(app): DTCG 토큰 Dart 생성`

### Task 5: 테마와 글꼴

**Files:**
- Create: `app/lib/design/theme/myungli_tokens.dart`, `app/lib/design/theme/app_theme.dart`, `app/assets/fonts/**`(글꼴과 `OFL.txt`), `app/lib/app/licenses.dart`
- Modify: `app/pubspec.yaml`(fonts)
- Test: `app/test/design/theme_test.dart`, `app/test/support/fonts.dart`

**Interfaces:**
- Consumes: Task 4의 `lightColors`, `darkColors`, `koType`, `jaType`, `Space`, `Radii`, `Motion`, `Shadows`, `lightGradients`, `darkGradients`
- Produces:
  * `final class MyungliTokens extends ThemeExtension<MyungliTokens>`: 필드 `colors`, `type`, `gradients`
  * `extension TokensContext on BuildContext { MyungliTokens get tokens; }`
  * `ThemeData buildTheme({required Brightness brightness, required Locale locale})`: `ja`면 `jaType`, 그 밖은 `koType`
  * `void registerFontLicenses()`: `LicenseRegistry`에 글꼴 OFL을 더합니다.
  * 테스트 도우미 `Future<void> loadBundledFonts()`(`test/support/fonts.dart`): `FontLoader`로 `assets/fonts`를 올립니다.

- [ ] **Step 1:** 글꼴 파일을 받아 `assets/fonts/`에 둡니다(굵기는 토큰과 컴포넌트가 쓰는 것만).
  * Gowun Dodum 400: Google Fonts
  * Zen Maru Gothic 400: Google Fonts
  * Pretendard 400·500·600·700: GitHub `orioncactus/pretendard` 릴리스
  * Pretendard JP 400·500·600·700: 같은 저장소
  * 각 글꼴의 `OFL.txt`를 함께 둡니다.

  `pubspec.yaml`의 family 이름은 토큰 값 그대로(`Gowun Dodum`, `Pretendard`, `Pretendard JP`, `Zen Maru Gothic`) 씁니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다.
  * `buildTheme(brightness: dark, locale: ja)`의 `extension<MyungliTokens>()!.colors`가 `darkColors`이고, 문장 스타일의 `fontFamily`가 `Zen Maru Gothic`입니다.
  * `buildTheme(..., locale: en)`은 `koType`입니다.
  * `theme.splashFactory == NoSplash.splashFactory`
  * `theme.useMaterial3`에서 `surfaceTintColor`가 투명입니다.
  * 다음 글꼴 패밀리가 `pubspec.yaml`에 있습니다: 토큰의 `fontFamily` 첫 값 전부.
- [ ] **Step 3:** `flutter test test/design/theme_test.dart` → FAIL
- [ ] **Step 4:** 구현합니다. Material 위젯 기본 효과를 끄는 테마 항목: `splashFactory`, `highlightColor`·`hoverColor`·`focusColor` 투명, `cardTheme`·`appBarTheme`·`bottomSheetTheme`·`dialogTheme`의 `elevation: 0`, `surfaceTintColor: Colors.transparent`.
- [ ] **Step 5:** 테스트 → PASS. `flutter build apk --debug`로 빌드한 뒤 `ls -l build/app/outputs/flutter-apk/app-debug.apk`의 크기와 `du -sh assets/fonts`를 이 plan 파일의 Task 5 아래 "측정" 줄에 적습니다(spec §6.2 판단 근거).
- [ ] **Step 6:** Commit `feat(app): 테마 확장과 글꼴(OFL) 포함`

측정: debug apk 170,321,244 B (약 163 MiB, 디버그 빌드라 AOT·압축 전), assets/fonts 31M (Gowun Dodum 7.2M, Zen Maru Gothic 3.8M, Pretendard 4종 6.3M, Pretendard JP 4종 15M).

### Task 6: 다국어 뼈대

**Files:**
- Create: `app/l10n.yaml`, `app/lib/core/l10n/arb/app_ko.arb`, `app_en.arb`, `app_ja.arb`, `app/lib/core/l10n/gen/**`
- Test: `app/test/core/l10n_test.dart`

**Interfaces:**
- Produces:
  * `AppLocalizations`(gen-l10n 출력, `lib/core/l10n/gen/`)
  * 지원 언어 `ko`, `en`, `ja`(템플릿은 `app_ko.arb`)
  * 기반 키(IA 슬롯이 아닌 공용 문구): `errorOffline`, `errorTimeout`, `errorClient`, `errorServer`, `errorUnexpected`, `errorNotImplemented`, `actionRetry`, `traceIdLabel`(매개변수 `traceId`). 모두 `@키.description`에 `임시`를 적습니다.

- [ ] **Step 1:** 실패하는 테스트를 씁니다. `ja` 로케일로 `AppLocalizations`를 불러 `errorOffline`이 비어 있지 않은지, `traceIdLabel('abc')`에 `abc`가 들어가는지, 세 ARB의 키 집합이 같은지 확인합니다.
- [ ] **Step 2:** `flutter test test/core/l10n_test.dart` → FAIL
- [ ] **Step 3:** `l10n.yaml`을 씁니다: `arb-dir: lib/core/l10n/arb`, `template-arb-file: app_ko.arb`, `output-dir: lib/core/l10n/gen`, `nullable-getter: false`. ARB 세 개를 작성하고 `flutter gen-l10n`을 실행합니다. 영어·일본어 임시 문구도 씁니다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** `app.yml`에 두 단계를 더합니다.
  * 생성 코드 차이 단계에 `flutter gen-l10n`
  * 새 단계: `uv run --project ../docs/identity/writing/tools mlw check-arb lib/core/l10n/arb/*.arb`(저장소 루트 기준 경로로 실행)

  로컬에서 같은 명령을 돌려 통과를 확인합니다.
- [ ] **Step 6:** Commit `feat(app): gen-l10n 뼈대와 공용 오류 문구`

### Task 7: AppError와 오류 문구 표

**Files:**
- Create: `app/lib/core/api/app_error.dart`, `app/lib/core/l10n/error_messages.dart`
- Test: `app/test/core/app_error_test.dart`, `app/test/core/error_messages_test.dart`

**Interfaces:**
- Consumes: Task 6 `AppLocalizations`
- Produces:
  * `sealed class AppError implements Exception`
    * `OfflineError`
    * `TimeoutError`
    * `ProblemError({required String code, required int status, required List<FieldProblem> fieldErrors, required String traceId})`
    * `UnexpectedError(Object cause)`
  * `final class FieldProblem(String pointer, String code)`
  * `AppError appErrorFrom(DioException e)`: 연결 오류 → `OfflineError`, 시간 초과 → `TimeoutError`, `application/problem+json` 본문 → `ProblemError`, 그 밖 → `UnexpectedError`
  * `String errorMessage(AppLocalizations l10n, AppError error)`. 내부 표는 `Map<String, String Function(AppLocalizations)> problemMessages`입니다. 기반에서는 `not_implemented`만 등록하고, 각 feature 계획이 code를 더합니다. 표에 없는 code는 status 400~499 → `errorClient`, 500~ → `errorServer`입니다.

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `DioExceptionType.connectionError` → `OfflineError`
  * 422 problem 본문(`code: request.inconsistent`, `errors: [{field: /birth/time/value, code: required_by_status}]`, `traceId: t1`) → `ProblemError`이고 `fieldErrors.single.pointer == '/birth/time/value'`
  * 본문이 JSON이 아닌 502 → `UnexpectedError`
  * `errorMessage(ko, ProblemError(code: 'unknown.x', status: 409, …)) == ko.errorClient`
  * `not_implemented` → `errorNotImplemented`
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** Commit `feat(app): AppError와 code → 문구 표`

### Task 8: OpenAPI 클라이언트 생성

**Files:**
- Create: `app/tool/gen_api.sh`, `app/lib/core/api/gen/**`, `app/tool/gen_api_routes.dart`, `app/lib/core/api/gen_routes/routes.g.dart`
- Test: `app/test/core/api_models_test.dart`, `app/test/tool/gen_api_routes_test.dart`

**Interfaces:**
- Produces:
  * 생성 모델(스키마 이름 그대로): `Me`, `AppConfig`, `MinimumVersion`, `Problem`, `FieldError`, `TokenPair`, `RefreshRequest`, `Profile`, `Daily`, `Calendar`, `Chart`, `RenderedText`, `Segment`, `EvidenceAccess` 등 99개
  * 생성 클라이언트: operationId 이름의 메서드(`getMe()`, `getAppConfig()`, `refreshToken(RefreshRequest)` 등)
  * `const List<ApiRoute> apiRoutes`: `ApiRoute(String method, String pathTemplate, String operationId)` 37개
  * `ApiRoute? matchRoute(String method, String path)`: `/v1/daily/2026-10-13` → `getDaily`, path 매개변수 `{date: 2026-10-13}`
  * 명령: `tool/gen_api.sh`(클라이언트와 route 표를 모두 생성)

- [ ] **Step 1: 생성기를 확정합니다.** `swagger_parser`(dev 의존성, 설정은 `pubspec.yaml`이나 `swagger_parser.yaml`, 입력 `../server/api/openapi.yaml`, 출력 `lib/core/api/gen`, json_serializable)로 생성해 보고 아래 기준을 모두 확인합니다.
  * operation 37개와 스키마 99개가 생깁니다.
  * `flutter analyze` 오류가 0입니다.
  * `application/merge-patch+json`(`updateProfile`, `updateSchedule`)의 Content-Type이 맞게 나갑니다.

  하나라도 못 맞추면 `openapi-generator` `dart-dio`로 바꿔 같은 기준을 확인합니다. 고른 생성기와 이유를 `app/docs/decisions.md`에 A16으로 기록합니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다.
  * 손으로 쓴 `Me` JSON(필수 필드 전부, `adFree.expiresAt` 생략)을 `Me.fromJson`으로 읽고 `toJson`으로 되돌리면, 생략한 필드가 `null` 키로 생기지 않습니다(계약에 null이 없음).
  * `Problem.fromJson`에서 `errors`가 비어 있어도 읽힙니다.
  * `matchRoute('GET', '/v1/calendar/2026/10')` → `getCalendar`이고 매개변수가 `{year: 2026, month: 10}`입니다.
  * `matchRoute('GET', '/v1/nope')` → `null`
- [ ] **Step 3:** 테스트 → FAIL
- [ ] **Step 4:** 생성 설정에서 null 키를 내보내지 않게 합니다(json_serializable `include_if_null: false`). `tool/gen_api_routes.dart`(openapi YAML을 `package:yaml`로 읽음)와 `tool/gen_api.sh`를 구현합니다.
- [ ] **Step 5:** 테스트 → PASS. `app.yml` 생성 코드 차이 단계에 `tool/gen_api.sh`를 더합니다.
- [ ] **Step 6:** Commit `feat(app): openapi 생성 클라이언트와 route 표`

### Task 9: Dio와 interceptor (통신·인증)

**Files:**
- Create: `app/lib/core/api/http_client.dart`, `app/lib/core/api/interceptors/common_headers.dart`, `app/lib/core/api/interceptors/auth.dart`, `app/lib/core/api/token_store.dart`, `app/lib/core/api/api_providers.dart`, `app/lib/core/storage/secure_store.dart`
- Test: `app/test/core/auth_interceptor_test.dart`, `app/test/core/common_headers_test.dart`

**Interfaces:**
- Consumes: Task 7 `appErrorFrom`, Task 8 생성 클라이언트·`RefreshRequest`·`TokenPair`
- Produces:
  * `enum ApiMode { fake, http }`, `ApiMode apiModeFromEnvironment()`: `API_MODE` dart-define. release 빌드에서 `fake`면 `StateError`를 던집니다.
  * `abstract interface class SecureStore { Future<String?> read(String key); Future<void> write(String key, String value); Future<void> delete(String key); }`. 구현은 `FlutterSecureStore`와 테스트용 `MemorySecureStore`입니다.
  * `final class TokenStore`: access token은 메모리, refresh token은 `SecureStore` 키 `auth.refresh`. 메서드는 `save(TokenPair)`, `clear()`, `String? get accessToken`, `Future<String?> refreshToken()`, 스트림 `Stream<AuthEvent> events`(`AuthEvent.signedOut`)입니다.
  * `abstract interface class AppCheckTokenSource { Future<String> token(); }`
  * `Dio buildDio({required ApiMode mode, required Uri baseUrl, required TokenStore tokens, required AppCheckTokenSource appCheck, required Locale Function() locale, Interceptor? fakeServer})`. interceptor 순서: 공통 헤더 → 인증 → 대역.
  * `Options idempotent(String key)`: `Idempotency-Key` 헤더
  * provider: `apiModeProvider`, `secureStoreProvider`, `tokenStoreProvider`, `appCheckProvider`, `dioProvider`, `restClientProvider`(생성 클라이언트)

- [ ] **Step 1:** 실패하는 테스트를 씁니다. 가짜 `HttpClientAdapter`로 응답을 꾸밉니다.
  * 동시에 3개 요청이 401 `auth.token_expired`를 받으면 `/v1/auth/refresh`는 **한 번만** 불리고, 세 요청 모두 새 토큰으로 다시 보내져 성공합니다.
  * refresh가 401 `auth.refresh_reused`면 `TokenStore.events`에 `signedOut`이 나오고 refresh token이 지워집니다.
  * refresh가 **연결 오류**면 `signedOut`이 나오지 않고, 원 요청은 `OfflineError`로 끝나며, refresh token이 남습니다(Review Focus 2).
  * `/v1/preview`·`/v1/birth-hour` 요청에만 `X-Firebase-AppCheck`가 붙습니다.
  * access token이 없는 요청에만 `Accept-Language`(로케일 `ja` → `ja`)가 붙습니다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다. refresh 단일 비행은 진행 중인 `Future<TokenPair>`를 공유하는 방식입니다(`QueuedInterceptor`는 쓰지 않음: 401이 아닌 요청까지 줄 세우지 않기 위해).
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** Commit `feat(app): Dio 인증·공통 헤더 interceptor`

### Task 10: 대역 서버와 fixture 검증

**Files:**
- Create: `app/lib/core/api/fake/fake_server.dart`, `app/lib/core/api/fake/scenario.dart`, `app/fixtures/scenarios.json`, `app/fixtures/<시나리오>/*.json`, `app/tool/validate_fixtures.py`, `app/tool/test_validate_fixtures.py`
- Modify: `app/pubspec.yaml`(assets `fixtures/`)
- Test: `app/test/core/fake_server_test.dart`

**Interfaces:**
- Consumes: Task 8 `matchRoute`, Task 9 `buildDio(fakeServer:)`
- Produces:
  * fixture 배치:
    * `fixtures/scenarios.json`: `[{ "id", "extends"(선택), "today": "YYYY-MM-DD", "timezone": "Asia/Seoul", "network": "online"|"offline", "delayMs"(선택), "description" }]`
    * 응답 파일: `fixtures/<시나리오>/<operationId>.json`, 또는 path 매개변수 값을 `-`로 이은 `<operationId>__<값>.json`(예 `getDaily__2026-10-13.json`, `getCalendar__2026-10.json`). 내용은 `{ "status": 200, "headers": {…}(선택), "body": … }`입니다.
    * 찾는 순서: 매개변수 파일 → 기본 파일 → `extends` 시나리오
  * `final class Scenario`: `id`, `today`(DateTime 날짜), `timezone`, `offline`, `delay`
  * `Future<List<Scenario>> loadScenarios(AssetBundle bundle)`
  * `final class FakeServerInterceptor extends Interceptor`(`Scenario`, `AssetBundle`): 일치하는 fixture가 없으면 501 `not_implemented` Problem으로 응답합니다(Review Focus 4). 시나리오가 offline이면 `DioExceptionType.connectionError`를 냅니다.
  * provider: `scenarioProvider`(fake 모드에서만)
  * 기반 시나리오:
    * `new-user`: 토큰 없음, `getAppConfig`
    * `member`: `getMe`(약관 동의, 프로필 있음), `getAppConfig`
    * `consent-required`
    * `profile-required`
    * `force-update`: 최소 버전 `99.0.0`
    * `offline`

    모두 `today: 2026-10-13`, `timezone: Asia/Seoul`입니다.
  * 검증 명령: `uv run --with jsonschema --with pyyaml --with referencing python -I tool/validate_fixtures.py`(app/에서). 각 fixture의 `body`를 해당 operation·status(없으면 `default`)의 응답 스키마로 검증하고, 실패하면 파일과 JSON Pointer를 출력한 뒤 종료 코드 1입니다.

- [ ] **Step 1:** 실패하는 Dart 테스트를 씁니다.
  * `member`에서 `GET /v1/me` → 200이고 `Me`로 읽힙니다.
  * 매개변수 파일이 기본 파일보다 우선합니다.
  * `extends`로 부모 시나리오의 파일을 씁니다.
  * fixture가 없는 operation → `ProblemError(code: 'not_implemented', status: 501)`
  * `offline` → `OfflineError`
- [ ] **Step 2:** 실패하는 Python 테스트를 씁니다(`unittest`). 올바른 `Me` fixture는 통과하고, `hasProfile`이 빠진 fixture는 실패하며 메시지에 `hasProfile`이 들어갑니다.
- [ ] **Step 3:** `flutter test test/core/fake_server_test.dart` → FAIL, `uv run … python -I -m unittest tool/test_validate_fixtures.py` → FAIL
- [ ] **Step 4:** 구현하고 기반 시나리오의 fixture를 작성합니다.
- [ ] **Step 5:** 두 테스트 → PASS. 검증 명령 → `fixtures OK (n개)`. `app.yml`에 "fixture 스키마 검증" 단계를 더합니다(`astral-sh/setup-uv`).
- [ ] **Step 6:** Commit `feat(app): fixture 대역 서버와 스키마 검증`

### Task 11: 로컬 DB와 캐시 규칙

**Files:**
- Create: `app/lib/core/storage/app_database.dart`, `app/lib/core/storage/cache_store.dart`, `app/lib/core/storage/saju_fingerprint.dart`, `app/drift_schemas/`
- Test: `app/test/core/cache_store_test.dart`, `app/test/core/saju_fingerprint_test.dart`, `app/test/core/migration_test.dart`

**Interfaces:**
- Consumes: Task 8 `Profile`
- Produces:
  * `AppDatabase`(drift, 스키마 버전 1). 테이블:
    * `CachedResponses(accountId, kind, cacheKey, json, rulesetVersion?, evidenceAccess, fetchedAt)`, 키 (accountId, kind, cacheKey)
    * `DiaryDrafts(accountId, date, body, updatedAt)`, 키 (accountId, date)
    * `OnboardingInputs(id=1, json, updatedAt)`
    * `DeviceFlags(key, value)`
  * `enum CacheKind { calendar, chart, daily, glossary }`
  * `String sajuFingerprint(Profile profile)`: 출생 정보·출생지·현재 시간대를 정규화(키 정렬 JSON)한 SHA-256 hex. 호칭과 언어는 넣지 않습니다.
  * `final class CacheStore`
    * `Future<String?> read(CacheKind kind, String key)`, `Future<void> write(CacheKind kind, String key, String json, {String? rulesetVersion, required EvidenceAccess access})`
    * 키 조립: `String calendarKey({required String fingerprint, required String language, required int year, required int month})`, `chartKey({fingerprint, language, year})`, `dailyKey({fingerprint, language, date})`
    * `Future<void> dropFingerprint(String fingerprint)`: 사주 변경
    * `Future<bool> observeRulesetVersion(String version)`: 저장된 값과 다르면 calendar·chart를 모두 지우고 true
    * `Future<List<String>> lockedKeys(CacheKind kind)`: 잠금 해제 때 다시 받을 키
    * `Future<void> clearAccount(String accountId)`: 캐시, 초안, 온보딩 입력을 모두 지움
  * provider: `appDatabaseProvider`, `cacheStoreProvider`(현재 계정 id로 범위를 정함)

- [ ] **Step 1:** 실패하는 테스트를 씁니다(in-memory DB).
  * 호칭만 다른 두 프로필의 지문이 같고, 출생 시간만 다르면 지문이 다릅니다.
  * `dropFingerprint(A)` 뒤 A의 달력은 없고 B의 달력은 남습니다.
  * `observeRulesetVersion('2026.10.1')`을 처음 부르면 false이고, 같은 값이면 false, `'2026.11.0'`이면 true이며 calendar·chart가 비고 daily는 남습니다.
  * 계정 a로 쓴 캐시는 계정 b의 `CacheStore`에서 읽히지 않습니다. `clearAccount(a)` 뒤 a의 초안도 없습니다(Review Focus 3).
  * `locked`로 쓴 키만 `lockedKeys`에 나옵니다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다. `dart run build_runner build`를 실행하고, `dart run drift_dev make-migrations`(또는 `schema dump`)로 `drift_schemas/`에 v1을 저장합니다. 마이그레이션 테스트 틀(`migration_test.dart`, v1 스키마가 열리는지)을 둡니다.
- [ ] **Step 4:** 테스트 → PASS. `app.yml` 생성 코드 차이 단계에 `dart run build_runner build --delete-conflicting-outputs`를 더합니다.
- [ ] **Step 5:** Commit `feat(app): drift 로컬 DB와 사주 기반 캐시 규칙`

### Task 12: Clock과 "오늘"

**Files:**
- Create: `app/lib/core/clock/clock.dart`, `app/lib/core/clock/calendar_date.dart`
- Test: `app/test/core/clock_test.dart`

**Interfaces:**
- Produces:
  * `abstract interface class Clock { DateTime nowUtc(); }`, 구현 `SystemClock`, `FixedClock(DateTime)`
  * `final class CalendarDate implements Comparable<CalendarDate>`: `year`, `month`, `day`, `CalendarDate.parse('2026-10-13')`, `toIso()`
  * `CalendarDate todayIn(Clock clock, String ianaTimezone)`: `timezone` 패키지, 데이터 `latest_all` 초기화
  * `Stream<CalendarDate> dayChanges(Clock clock, String ianaTimezone, {Duration tick})`: 날짜가 바뀔 때만 내보냅니다.
  * provider: `clockProvider`(fake 모드면 시나리오 `today`의 정오 시각에 고정), `profileTimezoneProvider`(기반에서는 시나리오 `timezone`, 계획 2에서 프로필로 바꿈), `todayProvider`

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * UTC `2026-10-13T15:30Z`는 `Asia/Seoul`에서 `2026-10-14`, `America/Los_Angeles`에서 `2026-10-13`입니다.
  * `Pacific/Kiritimati`(UTC+14)의 경계가 맞습니다.
  * `America/New_York` 서머타임 종료일(2026-11-01) 자정 전후 1분에 날짜가 하루만 바뀝니다.
  * `dayChanges`는 자정을 넘기는 시계 진행에서 정확히 한 번 내보냅니다(Review Focus 1).
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** Commit `feat(app): Clock과 프로필 시간대 기준 오늘`

### Task 13: 플랫폼 인터페이스와 대역

**Files:**
- Create: `app/lib/core/platform/{social_auth,app_check,push,crash_reporter,ad_consent,ads,purchases,share}.dart`, `app/lib/core/platform/fakes.dart`, `app/lib/core/platform/platform_providers.dart`
- Test: `app/test/core/platform_fakes_test.dart`

**Interfaces:**
- Produces (모두 `abstract interface class`, 대역은 `Fake<이름>`):
  * `KakaoAuth { Future<KakaoCredential> signIn({required String nonce}); }`, `KakaoCredential(idToken)`
  * `AppleAuth { Future<AppleCredential> signIn({required String nonce, required String state}); }`, `AppleCredential(idToken, authorizationCode, clientType)`
  * `AppCheck implements AppCheckTokenSource`(Task 9)
  * `PushMessaging { Future<bool> requestPermission(); Future<String?> token(); Stream<String> tokenRefreshes; Stream<PushOpen> opens; }`
  * `CrashReporter { void record(Object error, StackTrace stack); void setUser(String? accountId); void breadcrumb(String screenId); }`. 자유 문자열 custom key는 두지 않습니다. `breadcrumb`은 `ScreenIds`에 있는 값만 받고(assert), 이것으로 D64 ②를 인터페이스에서 막습니다.
  * `AdConsent { Future<AdConsentResult> gather(); }`, `AdConsentResult { personalized, nonPersonalized }`
  * `Ads { Future<BannerAdHandle?> loadBanner({required int width}); Future<RewardedAdHandle?> loadRewarded({required String userId}); }`, `BannerAdHandle { Widget get view; Size get size; void dispose(); }`, `RewardedAdHandle { Future<bool> show(); }`
  * `Purchases { Future<void> logIn(String accountId); Future<List<StoreProduct>> products(); Future<PurchaseOutcome> buy(String productId); }`
  * `ShareSheet { Future<void> sharePng(Uint8List png, {required String text}); }`
  * 대역은 생성자 인자로 결과를 정합니다(예: `FakeAds(bannerAvailable: false, rewardedAvailable: false)`, `FakeKakaoAuth(failWith: AppError?)`).
  * provider: 각 인터페이스의 provider. 기본값은 대역이고, 실제 adapter는 계획 7과 A2에서 override합니다.

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `FakeAds(rewardedAvailable: false).loadRewarded(...)` → `null`
  * `FakeAds()`의 handle `.show()` → `true`
  * `FakeKakaoAuth().signIn(nonce: 'n')`의 `idToken`이 비어 있지 않습니다.
  * `FakePushMessaging.opens`에 넣은 값이 그대로 나옵니다.
  * `FakeCrashReporter.breadcrumb('today')`는 기록되고, IA 화면 id가 아닌 값(예 `'1990-01-01'`)은 assert 실패입니다(D64 ②).
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** Commit `feat(app): 외부 SDK 인터페이스와 대역`

### Task 14: 진입 갈래와 라우터

**Files:**
- Create: `app/lib/app/entry/entry_state.dart`, `app/lib/app/entry/entry_providers.dart`, `app/lib/app/router/app_router.dart`, `app/lib/app/router/screen_registry.dart`, `app/lib/app/router/placeholder_screen.dart`
- Test: `app/test/app/entry_state_test.dart`, `app/test/app/router_redirect_test.dart`

**Interfaces:**
- Consumes: Task 3 `ScreenIds`·`iaScreens`, Task 8 `Me`·`AppConfig`, Task 9 `tokenStoreProvider`, Task 11 `DeviceFlags`
- Produces:
  * `enum EntryState { forceUpdate, signedOut, consentRequired, profileRequired, adConsentRequired, ready }`
  * `EntryState computeEntry({required Version appVersion, required Version minimumVersion, required bool hasSession, Me? me, required bool adConsentDone})`. 판정 순서는 spec §3입니다.
  * `entryStateProvider`(`AsyncNotifier<EntryState>`): 실행할 때 `getAppConfig` → 토큰 확인 → `getMe` 순서로 계산합니다. `TokenStore.events`의 `signedOut`을 받으면 다시 계산합니다.
  * `final class ScreenSpec(String id, WidgetBuilder builder, {Set<String> handledStates})`, `final Map<String, ScreenSpec> screenRegistry`: 기반에서는 모든 page 화면이 `PlaceholderScreen(screenId)`이고 `handledStates`는 비어 있습니다.
  * `GoRouter buildRouter(Ref ref)`: route 이름과 경로는 IA id(`/today`, `/onboard-call` 등). 탭 4개는 `StatefulShellRoute.indexedStack`이고, `system`·시트 화면은 route가 없습니다.
  * redirect 규칙
    * `forceUpdate` → `/force-update`
    * `signedOut`일 때 `member` 화면 → `/welcome`
    * `consentRequired` → `/consent`
    * `profileRequired` → `/onboard-call`
    * `adConsentRequired` → 광고 동의 SDK 호출 뒤 다시 계산(화면 없음, IA `ad-consent`는 system)
    * `ready`일 때 `guest` 화면 → `/today`
    * `any` 화면은 그대로 둡니다.
  * `PlaceholderScreen`: 뿌리에 `Key(screenId)`와 `Semantics(identifier: screenId)`, 화면 id 텍스트

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `computeEntry` 표: IA spec §3.3의 경우 각각, 최소 버전과 같은 버전은 통과, 낮은 버전(`1.0.0` < `1.0.1`)은 `forceUpdate`이고 다른 조건보다 먼저입니다.
  * redirect: `signedOut`에서 `/today` → `/welcome`, `ready`에서 `/welcome` → `/today`, `ready`에서 `/legal`(any)은 그대로입니다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다(`pub_semver`로 버전 비교, `package_info_plus`로 앱 버전).
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** Commit `feat(app): 진입 갈래와 IA id 라우터`

### Task 15: IA 대조 테스트

**Files:**
- Create: `app/test/contract/ia_contract_test.dart`, `app/test/contract/ia_pending.dart`

**Interfaces:**
- Consumes: Task 3 `iaScreens`, Task 14 `screenRegistry`·`buildRouter`
- Produces: `const Set<String> pendingStateScreens`(`ia_pending.dart`): 아직 `states`를 처리하지 않은 화면 id. 계획 2~7이 화면을 만들 때마다 지우고, 빈 집합이 목표입니다.

- [ ] **Step 1:** 테스트를 씁니다. 실제 `../docs/ia/screens.json`을 읽고 다음을 확인합니다.
  * 1) `presentation == page`인 화면마다 route가 있습니다.
  * 2) 탭 루트 4곳이 IA `tabs[].root`와 같습니다.
  * 3) `pendingStateScreens`에 없는 화면은 `handledStates`가 IA `states`와 같습니다.
  * 4) `pendingStateScreens`의 id가 모두 실재합니다.
  * 5) `components`에 `ad-banner`가 있는 화면이 정확히 `today`·`calendar`·`diary-list`·`my-saju`입니다.
- [ ] **Step 2:** `flutter test test/contract/ia_contract_test.dart` → 기반에서는 모든 화면을 `pendingStateScreens`에 넣었으므로 PASS여야 합니다. 4)를 깨는 가짜 id를 잠시 넣어 FAIL이 나는지 확인한 뒤 되돌립니다.
- [ ] **Step 3:** Commit `test(app): IA 계약 대조 테스트`

### Task 16: 상호작용 기반, 요소, golden·Widgetbook 틀

**Files:**
- Create: `app/lib/design/interaction/{motion_prefs,patterns,haptics}.dart`, `app/lib/design/elements/{seal,app_icon,skeleton_bone,term_mark,lock_veil}.dart`, `app/lib/design/components/component_spec.dart`
- Create: `app/test/support/golden.dart`, `app/test/contract/component_contract_test.dart`
- Create: `app/widgetbook/pubspec.yaml`, `app/widgetbook/lib/main.dart`
- Modify: `.github/workflows/app.yml`(golden 갱신 job)

**Interfaces:**
- Consumes: Task 5 `buildTheme`, `loadBundledFonts`
- Produces:
  * `final class MotionPrefs(bool reduceMotion, bool reduceTransparency, bool lowEnd)`, `MotionPrefs.of(BuildContext)`: `MediaQuery.disableAnimations`, `highContrast`·`accessibleNavigation` 등
  * 패턴 12개(`interaction.json` id): `enum InteractionPattern { pressInk, appearSeep, disappearSeep, selectSeepSlide, loadingBreathe, sealStamp, sealErase, markUnderlineGrow, sheetEnter, sheetExit, sheetStack, focusRing }`. 각 패턴은 `Widget animate(InteractionPattern, {required Animation<double> t, required Widget child, required MotionPrefs prefs})`로 그리고, 시간·곡선은 `Motion` 토큰입니다. `fallbacks` 규칙(reduceMotion → 투명도만 / `instant` → 시간 0)을 지킵니다.
  * `abstract final class Haptics { static Future<void> selection(); light(); medium(); }`
  * 요소: `Seal`, `AppIcon(PhosphorIconData, {AppIconSize size, AppIconWeight weight})`(light·regular만, fill은 `mark.caution` 전용), `SkeletonBone`, `TermMark`, `LockVeil`
  * 명세 대조: `final class ComponentSpec(String id, Set<String> variants, Set<String> states)`. 컴포넌트마다 `static const spec`을 두고, 등록 목록은 `const List<ComponentSpec> implementedComponents`입니다.
  * golden 도우미: `Future<void> goldenMatrix(WidgetTester t, String name, Widget Function() build, {bool fixedCells = false})`. 라이트·다크 × ko·ja × 글자 크기 1.0·1.3·2.0 조합을 한 장의 격자 이미지로 `test/goldens/<name>.png`에 비교합니다. `fixedCells`면 2.0이 1.3에서 멈추는지 확인합니다(Review Focus 5).
  * Widgetbook 앱: `app`을 path 의존으로 두고, 테마(라이트·다크)·로케일(ko·en·ja)·글자 크기 add-on을 둡니다.

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `component_contract_test.dart`: `implementedComponents`마다 `../docs/identity/design/components/*.json`의 같은 id 컴포넌트를 찾아 `variants[].id` 집합과 `states` 키 집합이 같은지 확인합니다. 기반의 첫 대상은 Task 17~19가 채우므로 지금은 빈 목록이고, 테스트는 "목록의 id가 명세에 있는지"도 확인합니다.
  * 패턴 테스트: `reduceMotion`이면 `appearSeep`의 위치 이동(Transform)이 없고 투명도만 바뀝니다.
  * 패턴 enum 이름 집합이 `interaction.json`의 id 집합(lowerCamelCase)과 같습니다.
  * `AppIcon`에 fill 굵기를 주면 assert 실패입니다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다(`flutter pub add phosphor_flutter`; elements.json의 Phosphor 2.1.2 기준). golden 기준 이미지는 Linux에서만 만듭니다. macOS에서 실행할 때는 golden 비교를 건너뛰도록 `test/flutter_test_config.dart`에서 플랫폼으로 판단합니다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** `app.yml`에 job `update-goldens`(`workflow_dispatch` 입력 `update_goldens: true`일 때만, `flutter test --update-goldens --tags golden` 후 이미지를 artifact로 올림)를 더합니다.
- [ ] **Step 6:** Commit `feat(app): 상호작용 패턴·요소·golden·Widgetbook 기반`

### Task 17: frame 컴포넌트 (tab-bar, app-bar, sheet, ad-banner)

**Files:**
- Create: `app/lib/design/components/frame/{tab_bar,app_bar,sheet,ad_banner}.dart`
- Test: `app/test/design/frame_test.dart`, `app/test/goldens/frame_*.png`
- Modify: `app/widgetbook/lib/main.dart`, `component_spec.dart` 등록

**Interfaces:**
- Consumes: Task 16 패턴·요소·`goldenMatrix`, Task 13 `Ads`
- Produces:
  * `MyungliTabBar({required int index, required ValueChanged<int> onSelect})`
  * `MyungliAppBar.tabRoot({required String title, List<Widget> actions})`, `.inner({required String title, VoidCallback? onBack})`
  * `Future<T?> showMyungliSheet<T>(BuildContext, {required SheetSize size, required WidgetBuilder builder})`, `enum SheetSize { half, full }`. 시트 위 시트는 `sheet.stack` 패턴입니다.
  * `AdBanner({required bool adFree, required bool consentGiven})`: `Ads.loadBanner`를 부르고, 상태 `loading`, `loaded`, `noFill`, `adFree`, `noConsent`, `reduceTransparency`를 그립니다. `adFree`면 높이 0입니다.
  * 각 컴포넌트의 `static const spec`(명세 `frame.json`의 변형·상태 그대로)

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * 탭 바: 이미 선택된 탭을 다시 누르면 `onSelect`가 불리지 않고 "맨 위로" 콜백이 불립니다(명세 rules). 탭마다 Semantics 역할 tab, 최소 터치 48입니다.
  * `AdBanner`: `adFree`에서 크기 0, `noFill`에서 높이가 유지돼 레이아웃이 튀지 않습니다(`FakeAds(bannerAvailable: false)`).
  * 시트 half·full 높이와 `sheet.enter` 패턴
  * golden: 네 컴포넌트의 변형·상태별 `goldenMatrix`
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** `frame.json`·`frame.md` 명세 값대로 구현하고 Widgetbook에 등록합니다.
- [ ] **Step 4:** 테스트 → PASS(golden은 CI Linux에서 기준 이미지를 만들어 commit합니다. 로컬 macOS에서는 비교를 건너뜁니다)
- [ ] **Step 5:** Commit `feat(app): frame 컴포넌트`

### Task 18: feedback 컴포넌트 (dialog, toast, notice-banner, skeleton, empty-state, error-state)

**Files:**
- Create: `app/lib/design/components/feedback/{dialog,toast,notice_banner,skeleton,empty_state,error_state,screen_state_view}.dart`
- Test: `app/test/design/feedback_test.dart`, goldens

**Interfaces:**
- Consumes: Task 7 `AppError`·`errorMessage`, Task 16
- Produces:
  * `Future<bool> showMyungliDialog(BuildContext, {required DialogVariant variant, required String title, String? body, required String confirm, required String cancel})`, `enum DialogVariant { confirm, destructive }`. destructive는 `mark.caution` 표시와 햅틱 medium을 씁니다.
  * `void showMyungliToast(BuildContext, String message)`
  * `NoticeBanner({required NoticeBannerVariant variant, required String message})`, `enum NoticeBannerVariant { offline, timeUnknown, draft }`
  * `SkeletonBlock`, `EmptyState({required String body, Widget? action})`, `ErrorState({required AppError error, required VoidCallback onRetry})`: generic·offline 변형, `traceId`가 있으면 문의 정보를 보입니다.
  * `ScreenStateView<T>({required AsyncValue<T> value, required Widget Function(T) data, Widget? skeleton, bool Function(T)? isEmpty, Widget? empty})`: 명세 `stateMap`(loading → skeleton, error → error-state, empty → empty-state)을 구현합니다. 캐시가 있는 오프라인은 데이터와 offline 배너를 함께 보입니다.
- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `ScreenStateView`: 로딩이면 스켈레톤이고 스피너(`CircularProgressIndicator`)가 없습니다.
  * `OfflineError` → `ErrorState` offline 변형
  * `ProblemError`의 `traceId`가 문의 정보에 보입니다.
  * dialog destructive의 기본 포커스는 취소입니다.
  * golden 6개
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현하고 Widgetbook에 등록합니다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** Commit `feat(app): feedback 컴포넌트와 화면 상태 뷰`

### Task 19: sentence 컴포넌트 (sentence-block, term-token, depth-link, reaction-button)

**Files:**
- Create: `app/lib/design/components/sentence/{sentence_block,term_token,depth_link,reaction_button,rendered_text_view}.dart`
- Test: `app/test/design/sentence_test.dart`, goldens

**Interfaces:**
- Consumes: Task 8 `RenderedText`·`Segment`, Task 16
- Produces:
  * `RenderedTextView({required RenderedText text, required TextStyle style, ValueChanged<String>? onTerm})`: `segments`를 `Text.rich`로 그립니다. `term`이 있는 조각은 `TermToken`(inline)이고, 누르면 `onTerm(term)`을 부릅니다.
  * `SentenceBlock({required SentenceBlockVariant variant, required RenderedText text, bool locked = false, String? slotId})`: `card`·`body`·`preview`. `locked`면 `lock.veil`이고, `slotId`가 있으면 Key·Semantics identifier로 붙입니다.
  * `TermToken({required String label, required TermTokenVariant variant, VoidCallback? onTap})`
  * `DepthLink({required DepthLinkVariant variant, required DepthLinkState state, required String label, VoidCallback? onTap})`, `enum DepthLinkState { idle, locked, lockedNoAd, unlocking, unlocked }`
  * `ReactionButton({required bool on, required ValueChanged<bool> onChanged, required String semanticsLabel})`: 햅틱 light
- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `segments`가 `[{text:'오늘은 '}, {text:'식신', term:'TenGod.SIKSIN'}, {text:'의 날'}]`이면 글자가 이어져 보이고 `식신`만 눌립니다.
  * 빈 `segments`는 아무것도 그리지 않습니다.
  * `SentenceBlock(locked: true)`는 본문을 스크린리더에 읽히지 않습니다.
  * `DepthLink` `lockedNoAd`는 누를 수 없습니다.
  * golden
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현하고 Widgetbook에 등록합니다.
- [ ] **Step 4:** 테스트 → PASS(`component_contract_test`가 frame·feedback·sentence 14개를 대조)
- [ ] **Step 5:** Commit `feat(app): sentence 컴포넌트와 조각 배열 표시`

### Task 20: 앱 셸 조립과 fake 모드 실행

**Files:**
- Modify: `app/lib/main.dart`
- Create: `app/lib/app/bootstrap.dart`, `app/lib/app/myungli_app.dart`, `app/lib/app/dev/scenario_picker.dart`
- Test: `app/test/flows/launch_flow_test.dart`, `app/test/support/app_harness.dart`

**Interfaces:**
- Consumes: Task 9·10·11·12·13·14 provider들, Task 5 `buildTheme`, Task 6 l10n
- Produces:
  * `Future<ProviderContainer> bootstrap({ApiMode? mode, String? scenarioId, List<Override> overrides})`: timezone 초기화, DB 열기, `registerFontLicenses`, `FlutterError.onError` → `CrashReporter`
  * `MyungliApp`: `MaterialApp.router`, 테마 라이트·다크(기기 설정), 로케일 ko·en·ja
  * fake 모드 debug 빌드에서는 앱 위 개발 메뉴(길게 누르기)로 시나리오를 바꾸고 다시 시작합니다.
  * 테스트 도우미 `Future<void> pumpApp(WidgetTester t, {required String scenario, List<Override> overrides})`
- [ ] **Step 1:** 실패하는 흐름 테스트를 씁니다.
  * `new-user` → `find.byKey(ValueKey(ScreenIds.welcome))`
  * `member` → `today`
  * `force-update` → `force-update`
  * `offline`이고 캐시 없음 → `launch` 화면의 offline 상태(오류 상태와 다시 시도)
  * `consent-required` → `consent`
  * `profile-required` → `onboard-call`
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다.
- [ ] **Step 4:** 테스트 → PASS. `flutter run --dart-define=API_MODE=fake`(iOS 시뮬레이터, Android 에뮬레이터)로 띄워 시나리오 전환이 되는지 눈으로 확인합니다.
- [ ] **Step 5:** Commit `feat(app): 앱 셸과 fake 모드 실행`

### Task 21: 문서 기반 E2E 뼈대

**Files:**
- Create: `app/lib/testing/covers.dart`, `app/tool/ia_coverage.dart`, `app/tool/coverage_baseline.json`, `app/tool/decision_targets.json`, `app/tool/register_screenshots.dart`
- Create: `app/patrol_test/launch_test.dart`
- Create: `app/docs/artifacts/index.json`(빈 배열 `[]`), `app/docs/artifacts/e2e-coverage.json`
- Modify: `app/pubspec.yaml`(patrol 설정), `.github/workflows/app.yml`(커버리지 단계, job `e2e-android`)
- Test: `app/test/tool/ia_coverage_test.dart`, `app/test/tool/register_screenshots_test.dart`

**Interfaces:**
- Consumes: Task 3 `iaScreens`, Task 20 `bootstrap`
- Produces:
  * `final class Covers`(`lib/testing/covers.dart`): `const Covers({List<String> exits, List<String> states, List<String> decisions})`. 형식은 `exits: ['launch>welcome']`, `states: ['launch:offline']`, `decisions: ['D50']`입니다. 테스트에서만 import합니다.
  * 선언 위치: `test/flows/**_test.dart`와 `patrol_test/**_test.dart` 안의 `const Covers(...)` 리터럴. 도구는 `package:analyzer`로 리터럴을 읽습니다(문자열 리터럴만 허용, 변수 금지).
  * `dart run tool/ia_coverage.dart [--check]`
    * 선언을 모아 `screens.json`의 전체 경로(`<화면>><exits.to>`)·상태(`<화면>:<state>`), `tool/decision_targets.json`(동작으로 확인할 결정 id 목록)과 대조합니다.
    * 출력: `docs/artifacts/e2e-coverage.json`(`{generatedAt, exits:{covered,total,uncovered[]}, states:{…}, decisions:{…}, byScreen:{<id>:{exits,states}}}`)
    * 없는 id를 선언하면 오류입니다.
    * `--check`는 `coverage_baseline.json`보다 covered 수가 줄면 종료 코드 1입니다.
  * `dart run tool/register_screenshots.dart <dir>`: `<화면>__<상태|default>.png` 파일을 `docs/artifacts/YYYY-MM-DD-<화면>-<상태>.png`로 복사하고 `index.json`에 upsert합니다(`kind: screenshot`, `screens: [<화면>]`, `milestone: A1`, `status: draft`). 같은 화면·상태의 이전 항목은 `superseded`로 바꿉니다(workflow §7 "지우지 않음").
- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * 작은 IA JSON과 선언 2개로 covered·uncovered가 맞습니다.
  * 없는 화면 id를 선언하면 오류입니다.
  * baseline보다 줄면 `--check`가 실패합니다.
  * `register_screenshots`가 같은 화면·상태를 두 번 등록하면 앞 항목이 `superseded`가 되고 이미지 하나가 2MB를 넘으면 오류입니다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현합니다. `decision_targets.json`에는 app 동작으로 확인할 수 있는 결정만 넣습니다: `["D30","D47","D49","D50","D53","D60"]`. D61(기간 계산)은 server 몫이라 뺍니다. Task 20의 `test/flows/launch_flow_test.dart` 각 테스트에 `Covers` 선언(예 `launch>welcome`, `launch>today`, `launch>force-update`, `launch:offline`)을 더합니다.
- [ ] **Step 4:** Patrol을 설정합니다(`flutter pub add dev:patrol`, `pubspec.yaml`의 `patrol:` 블록에 `app_name: 명리일기`, `android.package_name: app.myungli.diary`, `ios.bundle_id: app.myungli.diary`, Patrol 문서의 Android·iOS 네이티브 설정). 첫 E2E `patrol_test/launch_test.dart`: `new-user` 시나리오로 띄워 `welcome`에 도착하고 스크린샷을 남깁니다. `Covers(exits: ['launch>welcome'], decisions: ['D50'])`
  * 스크린샷 방법은 Patrol이 제공하는 캡처 API를 문서로 확인해 씁니다. 저장 위치는 `build/e2e-screenshots/`입니다.
- [ ] **Step 5:** 테스트 → PASS. 로컬에서 `patrol test -t patrol_test/launch_test.dart`를 iOS 시뮬레이터와 Android 에뮬레이터에서 각각 돌려 PASS를 확인합니다. `dart run tool/ia_coverage.dart`를 실행하고 그 결과로 `coverage_baseline.json`을 만듭니다.
- [ ] **Step 6:** `app.yml`을 수정합니다.
  * `checks`에 `dart run tool/ia_coverage.dart --check`를 더합니다.
  * job `e2e-android`를 더합니다. 트리거는 `push`(main)·`schedule`(매일 18:00 UTC = 03:00 KST)·`workflow_dispatch`이고 PR에서는 돌지 않습니다. `reactivecircus/android-emulator-runner`로 `patrol test`를 돌리고, 스크린샷을 artifact로 올립니다.
  * `uvx actionlint` → 출력 없음
- [ ] **Step 7:** Commit `feat(app): 문서 기반 E2E 뼈대(Patrol, IA 커버리지, 스크린샷 등록)`

### Task 22: 마무리 문서

**Files:**
- Modify: `app/CLAUDE.md`("현재 상태"·"다음 할 일"), `app/docs/decisions.md`(A16 확인)
- Create: `app/README.md`

- [ ] **Step 1:** `app/README.md`에 다음을 적습니다.
  * 실행: VS Code 구성 `fake`, 또는 `flutter run --dart-define=API_MODE=fake`
  * 생성 명령 목록: `gen_ia`, `gen_tokens`, `gen_api.sh`, `build_runner`, `gen-l10n`
  * fixture 추가 방법과 검증 명령
  * golden 갱신 job
  * E2E 실행(`patrol test`)과 커버리지 보고
- [ ] **Step 2:** `app/CLAUDE.md`를 갱신합니다. "현재 상태"에는 기반 완료, 생성기 선택(A16), Task 5 측정값을 적습니다. "다음 할 일"은 계획 2(온보딩·로그인)입니다.
- [ ] **Step 3:** 전체 검증: `flutter analyze && flutter test && dart run tool/ia_coverage.dart --check && uv run --with jsonschema --with pyyaml --with referencing python -I tool/validate_fixtures.py` → 모두 통과
- [ ] **Step 4:** Commit `docs(app): 기반 README와 현재 상태`

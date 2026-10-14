# app 온보딩·로그인 Implementation Plan (계획 2)

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** fake 모드에서 새 사용자가 `welcome`부터 온보딩·미리보기·로그인·약관 동의·알림 허락·광고 동의를 거쳐 `today`에 닿고, 기존 사용자는 로그인만으로 `today`에 닿게 합니다. 이 흐름의 화면 11개와 입력 컴포넌트 11개를 만들고, 기반에서 넘어온 항목과 #127을 처리합니다.

**Architecture:** 화면은 `lib/features/<영역>/{data,application,presentation}`에 둡니다(spec §2). repository는 생성 클라이언트(`DefaultApi`)를 감싸 생성 모델을 그대로 돌려줍니다. 온보딩 입력은 `OnboardingDraft` 하나에 모아 단계마다 로컬 DB(`OnboardingInputs`)에 저장합니다. 계정을 만드는 쪽(약관 동의 뒤, 또는 로그인한 채 온보딩을 마친 뒤)은 `OnboardingCompleter` 하나가 프로필을 저장합니다. 화면 이동은 진입 갈래(`EntryState`)가 정합니다. 화면은 그 상태를 바꾼 뒤 `entryStateProvider.notifier.refresh()`를 부르고, 라우터 redirect가 다음 화면으로 보냅니다.

**Tech Stack:** 기반과 같음(Flutter stable, Riverpod 3.x 코드 생성 없음, go_router, Dio 생성 클라이언트, drift). 이 계획에서 더하는 패키지: `uuid`, `flutter_timezone`, `url_launcher`(모두 `flutter pub add`로 그때의 안정판).

**Spec:** `app/docs/specs/2026-10-13-app-architecture-design.md` (§3 진입 갈래, §4 데이터, §6 디자인 시스템, §7 플랫폼, §8 테스트). 결정은 `app/docs/decisions.md` A1~A16과 이 계획이 더하는 A17~A20입니다. 화면 내용은 IA `docs/ia/screens.json`, 컴포넌트는 `docs/identity/design/components/` 2.2.0, REST는 `server/api/openapi.yaml` 1.0.0-draft.2가 기준입니다.

## 시작 전

* 브랜치 `app/onboarding`(`origin/main`에서 `--no-track`으로 만들고 같은 이름으로 push함)에서 작업합니다. 작업 디렉터리는 worktree `../myungli-diary-app`의 `app/`입니다.
* Flutter 명령 앞에 `export PATH="$HOME/development/flutter/bin:$PATH"`를 둡니다.

## 이 계획이 정하는 것 (계약 사이 빈칸)

계약끼리 맞지 않거나 비어 있는 곳을 아래처럼 정하고 구현합니다. 다른 단위가 바꿔야 하는 것은 Task 19에서 Issue로 알립니다. 결정 번호는 `app/docs/decisions.md`에 적습니다(Task 5·12·15).

| 빈칸 | 정한 것 |
| --- | --- |
| IA 순서는 `consent → 프로필 저장 → notify-ask → ad-consent`인데, 진입 계산은 프로필이 생기면 바로 광고 동의를 받음 | **A17:** 진입 갈래에 `notifyAskRequired`를 `profileRequired`와 `adConsentRequired` 사이에 둡니다. 근거는 기기 플래그 `onboarding.notifyAskPending`입니다. `OnboardingCompleter`가 프로필을 만들면 켜고, `notify-ask`가 허락하거나 건너뛰면 끕니다. 로그아웃하면 끕니다 |
| 로그인했지만 프로필이 없는 사용자(`consent → onboard-call`)가 온보딩을 마친 뒤의 출구가 IA에 없음(`preview`는 guest 전용) | `onboard-gender`(한국)와 `birthplace`의 "다음"에서 세션이 있으면 미리보기를 건너뛰고 `OnboardingCompleter`로 저장한 뒤 `notify-ask`로 갑니다. IA 출구 추가를 root에 요청합니다(Task 19) |
| 프로필을 읽는 GET이 없음(`profileTimezoneProvider`의 출처, 계획 6 `profile-edit`의 현재 값) | **A18:** `createProfile`·`updateProfile` 응답의 `Profile`을 계정 범위 캐시에 사본으로 둡니다. 시간대는 이 사본에서 읽고, 없으면 기기 시간대를 씁니다. server에 GET을 요청합니다(Task 19) |
| `onboard-*`·`birthplace`를 `profile-edit`가 수정 모드로 씀(IA §4.1). 저장·확인 창은 계획 6 | **A19:** 수정 모드는 query `?mode=edit`로 엽니다. 화면은 값을 서버에 저장하지 않고 `context.pop(값)`으로 돌려줍니다. 저장과 무거운 변경 확인 창은 계획 6 `profile-edit`가 합니다 |
| `preview.character.label`·`preview.fortune.body`가 `Preview` 필드와 1:1이 아님. `onboard-time.hour.confirm`은 content 슬롯인데 `getBirthHour`는 구조값을 줌. 음력→양력 변환·윤달 유무 API가 없음(date-picker `solarConfirm`·`leapMonth`). `City`에 지역 표시값이 없음 | **A20:** 받을 수 있는 값으로 그립니다. ① 날의 성격 배지는 `dayKind` → ARB 이름 ② `preview.fortune.body`는 `fortune.tag`(없으면 그리지 않음) ③ 시진 확인 줄은 `branch`·`start`·`end`를 ARB 틀에 넣어 app이 씁니다 ④ 음력이면 윤달 체크(`check-row` inline) 하나를 두고 존재 여부는 server 422로 받습니다. 양력 확인 줄은 그리지 않습니다 ⑤ 도시 줄의 지역 자리에는 `country` 코드를 씁니다. root·server·design에 알립니다(Task 19) |
| `consent.optional.label` 슬롯이 있지만 계약에는 선택 동의 문서가 없음 | 응답 `requiredConsents`의 문서마다 `check-row` card를 그리고, 선택 항목은 그리지 않습니다 |
| 호칭 길이가 스키마 20, `name.too_long`은 ko·ja 10·en 20 | 입력 칸 상한은 프로필 언어 기준 ko·ja 10, en 20입니다. 나머지 호칭 규칙(이모지·괄호 등)은 server 422를 칸에 붙여 보입니다 |
| `getBirthHour`는 엔진 RPC 전까지 501 | 오류가 나면 시진 확인 줄을 그리지 않고 자리도 비우지 않습니다(time-picker 규칙과 같음). 입력은 막지 않습니다 |

## Global Constraints

* 기반 plan(`app/docs/plans/2026-10-13-foundation.md`)의 Global Constraints를 모두 따릅니다. 앱 식별자 `app.myungli.diary`, stable 추종, `very_good_analysis`·`riverpod_lint` 경고 0, 생성 코드 손대지 않음, 토큰 의미 역할만, Material 효과 끔·스피너 금지, ARB 경유, IA id를 Key와 Semantics `identifier`로, 한국어 주석과 `feat(app):` 형식 commit, TDD, D64가 그 내용입니다.
* 화면은 `lib/features/<영역>/presentation/<화면>_screen.dart`에 두고 `screenRegistry`(`lib/app/router/screen_registry.dart`)에 `ScreenSpec(ScreenIds.<id>, builder, handledStates: …, exits: …)`로 등록합니다(exits는 Task 6). 영역은 `onboarding`(welcome·force-update·onboard-*·birthplace·preview·notify-ask), `auth`(login·consent), `profile`(프로필 저장소·시간대)입니다.
* 의존 방향은 presentation → application → data → core입니다. feature끼리는 application provider로만 참조합니다(spec §2).
* 화면의 사용자 문구 키는 IA 슬롯 id의 lowerCamelCase(`iaKey`)이고, 임시 문구는 ko·en·ja 세 파일에 넣고 `@키.description`에 `임시`를 적습니다. 슬롯이 아닌 문구(날의 성격 이름, 지지 이름, 약관 문서 이름 등)는 영역 접두어를 붙인 lowerCamelCase 키입니다(예 `dayKindYongsinDay`, `branchIn`, `consentDocumentTerms`).
* 날짜 범위는 양력 1900-01-31 ~ 2099-12-31입니다(D41). 범위 밖이면 `input-step` `out-of-range` 상태로 다음 버튼을 막습니다.
* 기기 지역이 한국이면(`PlatformDispatcher` locale의 `countryCode == 'KR'`) 출생지는 묻지 않고 `BirthPlace(status: not_asked)`, `Birth.timezone`은 `Asia/Seoul`입니다(D29·D58). 한국 밖이면 `birthplace`에서 도시를 고르고 `Birth.timezone`은 그 도시의 `timezone`입니다.
* `PreviewRequest`·`BirthHourRequest`의 `installationId`는 기기 하나에 한 번 만든 UUID v4이고 로그아웃해도 남습니다.
* nonce 원문은 `NonceGenerator().generate()`(32자)이고 server에는 원문, 제공자 adapter에는 원문을 넘기며 adapter가 `hashNonce`합니다(#100). Apple Android 웹 흐름의 교환 코드는 `completeAppleWebLogin`에 원문 nonce와 함께 보냅니다(#114).
* 로그인·동의·프로필 저장·알림 등록이 끝나면 화면은 직접 `go`하지 않고 `entryStateProvider.notifier.refresh()`를 부릅니다. 이동은 redirect가 정합니다. 예외는 IA 출구 중 진입 상태가 바뀌지 않는 이동입니다(`welcome→login`, 온보딩 단계 사이, `preview→login`, `consent→legal`).
* 온보딩 단계 이동은 `context.push`입니다(뒤로 가면 앞 단계, 입력은 남음). 단계를 넘을 때마다 `OnboardingDraft`를 저장합니다.
* 버튼 처리 중(`primary-button` `loading`)에는 같은 동작을 다시 받지 않습니다. 같은 요청이 두 번 나가지 않아야 합니다.
* `registerDevice`의 `Idempotency-Key`는 사용자 동작 하나마다 UUID 하나이고 재시도에도 같은 키입니다(spec §4.1).
* 새 컴포넌트는 `static const ComponentSpec spec`을 두고 `implementedComponents`에 등록합니다(명세 대조 테스트). Widgetbook 항목과 golden(라이트·다크 × ko·ja × 글자 1.0·1.3·2.0 중 기반 golden과 같은 조합)을 함께 만듭니다. golden 기준 이미지는 `tool/goldens_linux.sh`로 만듭니다.
* 흐름 테스트는 `test/flows/`에 두고 `pumpApp(tester, scenario: …)`으로 띄우며, 덮는 IA 출구·상태·결정을 테스트 본문 안에 `covers(const Covers(...))` 리터럴로 적습니다.

## Review Focus

1. 미리보기 뒤 로그인·약관 동의까지 했는데 프로필 저장 전에 앱이 꺼짐 → 다시 열면 `profileRequired`지만 온보딩 입력이 완전합니다. 같은 질문을 다시 묻지 않고 저장해 `notify-ask`로 가야 합니다(Task 17).
2. 존재하지 않는 음력 날짜(윤달이 없는 해의 윤달 등) → `createPreview`나 `createProfile`이 422(`birth.invalid`·`date.invalid`)를 냅니다. 입력이 사라지지 않고, 오류 문구와 함께 `onboard-call`부터 다시 고칠 수 있어야 합니다(Task 15·17).
3. Apple Android 웹 로그인의 교환 코드가 만료(`auth.exchange_invalid`)되거나 `state`가 맞지 않음 → 같은 코드로 다시 보내지 않습니다. 새 nonce로 처음부터 다시 로그인하게 안내합니다. 503 `auth.provider_unavailable`은 같은 동작을 다시 시도하게 합니다(Task 16).
4. 저장·동의·로그인 버튼을 빠르게 두 번 누름 → 요청은 한 번만 나갑니다(Task 7 `primary-button` loading, Task 16~18 화면 테스트).
5. 앱이 백그라운드에 있는 동안 기기 시간대가 바뀜(UTC offset이 같은 다른 IANA 이름 포함) → 다시 앞으로 오면 `updateProfile(currentTimezone)`을 한 번 보냅니다. 실패해도 앱은 계속되고 다음 재개 때 다시 시도합니다(Task 3).

---

### Task 1: Android 디버그 빌드 조건 (#127)

**Files:**
- Modify: `.github/workflows/app.yml` (`workflow_call.inputs`, `Android 디버그 빌드` 단계)

**Interfaces:**
- Produces: 재사용 호출 입력 `build_apk`(boolean, 기본 true)

- [ ] **Step 1:** `workflow_call.inputs`에 `build_apk`를 더합니다(`description: "재사용 호출에서 Android 디버그 빌드를 돌린다"`, `type: boolean`, `default: true`). `Android 디버그 빌드` 단계에 `if: github.workflow == 'app' || inputs.build_apk`를 둡니다. 바로 위에 이유 주석 한 줄을 씁니다(계약 PR에서는 생성 코드 대조·analyze·테스트가 깨짐을 잡고, Gradle 문제는 `app/` 변경에서만 생김).
- [ ] **Step 2:** `uvx --from actionlint-py actionlint .github/workflows/app.yml` → 출력 없음.
- [ ] **Step 3:** spec §9 CI 단계 7에 "재사용 호출에서는 입력 `build_apk`(기본 true)를 따른다"를 한 줄 더합니다. Commit `ci(app): 재사용 호출의 Android 디버그 빌드를 입력 build_apk로(#127)`.

### Task 2: 기기 기반 값

**Files:**
- Modify: `app/lib/core/storage/device_flags.dart`
- Create: `app/lib/core/storage/installation_id.dart`, `app/lib/core/platform/device_locale.dart`, `app/lib/core/platform/device_timezone.dart`, `app/lib/core/platform/store_launcher.dart`
- Modify: `app/lib/core/platform/platform_providers.dart`, `app/lib/core/platform/fakes.dart`, `app/lib/app/myungli_app.dart`
- Test: `app/test/core/device_flags_test.dart`, `app/test/core/installation_id_test.dart`, `app/test/core/device_locale_test.dart`, `app/test/core/device_timezone_test.dart`

**Interfaces:**
- Produces:
  - `DeviceFlagsStore.readString(String key) → Future<String?>`, `DeviceFlagsStore.writeString(String key, {required String value}) → Future<void>`
  - `const installationIdKey = 'app.installationId'`, `final installationIdProvider = FutureProvider<String>`(없으면 UUID v4를 만들어 저장)
  - `Language resolveAppLanguage(Locale device)`(ko·ja면 그대로, 그 밖은 en), `final appLanguageProvider = Provider<Language>`(`localeProvider`에서), `final deviceRegionIsKoreaProvider = Provider<bool>`(`localeProvider.countryCode == 'KR'`)
  - `abstract interface class DeviceTimezone { Future<String> current(); }`(IANA 이름), `FlutterDeviceTimezone`(`flutter_timezone`), `FakeDeviceTimezone(String value)`, `deviceTimezoneProvider`(fake 모드 기본은 시나리오 `timezone`)
  - `final nonceGeneratorProvider = Provider<NonceGenerator>((ref) => NonceGenerator())`
  - `abstract interface class StoreLauncher { Future<void> openStore(); }`, `UrlStoreLauncher`(Android `market://details?id=app.myungli.diary`, iOS는 앱 id가 생기기 전까지 `https://apps.apple.com/kr/search?term=myungli`), `FakeStoreLauncher`(`opened` 횟수 기록), `storeLauncherProvider`

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `device_flags_test`: `writeString('k', value: 'v')` 뒤 `readString('k') == 'v'`, 없는 키는 `null`, 로그아웃 정리(`clearSignedOutData`) 뒤에도 남는다.
  * `installation_id_test`: 처음 읽으면 UUID v4 형식(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`), 같은 DB로 컨테이너를 다시 만들어도 같은 값이다.
  * `device_locale_test`: `resolveAppLanguage(Locale('ko','KR')) == Language.ko`, `Locale('ja')` → ja, `Locale('fr','FR')` → en. `deviceRegionIsKoreaProvider`가 `Locale('en','KR')`이면 true, `Locale('ko')`(지역 없음)이면 false.
  * `device_timezone_test`: fake 모드 컨테이너에서 `deviceTimezoneProvider`가 시나리오 `timezone`(`new-user`면 `Asia/Seoul`)을 준다.
- [ ] **Step 2:** `flutter test test/core/device_flags_test.dart test/core/installation_id_test.dart test/core/device_locale_test.dart test/core/device_timezone_test.dart` → FAIL.
- [ ] **Step 3:** 구현합니다. `flutter pub add uuid flutter_timezone url_launcher`. `MyungliApp`의 `localeResolutionCallback`이 `resolveAppLanguage`와 같은 언어를 고르게 합니다(앱 화면 언어와 프로필 `language`가 어긋나지 않게).
- [ ] **Step 4:** 위 테스트와 `flutter analyze` → PASS, `No issues found!`
- [ ] **Step 5:** Commit `feat(app): 설치 id·기기 언어와 지역·기기 시간대·nonce·스토어 열기 기반`.

### Task 3: 프로필 저장소와 시간대

**Files:**
- Create: `app/lib/features/profile/data/profile_repository.dart`, `app/lib/features/profile/application/profile_providers.dart`, `app/lib/features/profile/application/timezone_sync.dart`
- Modify: `app/lib/core/clock/clock.dart`(`profileTimezoneProvider`), `app/lib/app/myungli_app.dart`(`_onDeviceTimeZoneChanged`와 판정), `app/lib/app/bootstrap.dart`
- Test: `app/test/features/profile/profile_repository_test.dart`, `app/test/features/profile/timezone_sync_test.dart`, `app/test/core/clock_test.dart`

**Interfaces:**
- Consumes: `CacheStore`(계정 범위), `restClientProvider`, `deviceTimezoneProvider`(Task 2)
- Produces:
  - `final class ProfileRepository { Future<ProfileResponse> create(ProfileInput input); Future<ProfileResponse> update(ProfilePatch patch); Future<Profile?> cached(); }`. create·update가 성공하면 응답 `profile`을 캐시 키 `profile`에 씁니다(A18)
  - `final profileRepositoryProvider`, `final cachedProfileProvider = FutureProvider<Profile?>`
  - `profileTimezoneProvider`: 캐시 사본의 `currentTimezone` → 없으면 기기 시간대 → 그것도 아직 없으면 `Asia/Seoul`
  - `final class TimezoneSync { Future<void> syncIfChanged(); }`, `timezoneSyncProvider`. 진입이 `ready`일 때만 기기 IANA 이름과 사본을 비교해, 사본이 없거나 다르면 `update(ProfilePatch(currentTimezone: …))`. 오류는 삼키고 비정상 종료 보고에 `CrashSummary`만 남깁니다

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `profile_repository_test`: fake `member` 시나리오에서 `create` 뒤 `cached()`가 응답 profile과 같다. 로그아웃 정리 뒤 `cached()`는 null이다(계정 범위 캐시라 같이 지워짐).
  * `timezone_sync_test`: 사본 `Asia/Seoul`, 기기 `America/Los_Angeles`면 `updateProfile`이 한 번 불리고 본문이 `{"currentTimezone":"America/Los_Angeles"}`다. 같으면 부르지 않는다. 기기 `Asia/Tokyo`(offset +9, Seoul과 같음)도 다르다고 보고 보낸다. `updateProfile`이 503이어도 예외가 밖으로 나오지 않고, 다음 `syncIfChanged()`에서 다시 보낸다. 진입이 `ready`가 아니면 부르지 않는다.
  * `clock_test`의 "임시 프로필 시간대 Asia/Seoul" 테스트를 "사본이 없고 기기 시간대가 `Asia/Tokyo`면 `Asia/Tokyo`", "사본이 `Europe/Paris`면 `Europe/Paris`"로 바꿉니다.
- [ ] **Step 2:** 해당 테스트 → FAIL.
- [ ] **Step 3:** 구현합니다. `AppLifecycleHooks`는 UTC offset 비교를 지우고, resumed마다 `timezoneSync.syncIfChanged()`를 부릅니다. 진입이 `ready`가 될 때도 한 번 부릅니다. fake 모드의 `profileTimezoneProvider` 고정 override(`bootstrap.dart`)는 지우고, `deviceTimezoneProvider` override로 바꿉니다.
- [ ] **Step 4:** 해당 테스트와 `flutter test --exclude-tags golden` 전체 → PASS.
- [ ] **Step 5:** Commit `feat(app): 프로필 사본 캐시와 프로필 시간대, 기기 시간대 변경 시 PATCH`.

### Task 4: 온보딩 입력

**Files:**
- Create: `app/lib/features/onboarding/data/onboarding_draft.dart`, `app/lib/features/onboarding/data/onboarding_draft_store.dart`, `app/lib/features/onboarding/application/onboarding_providers.dart`, `app/lib/core/api/field_problems.dart`
- Test: `app/test/features/onboarding/onboarding_draft_test.dart`, `app/test/features/onboarding/onboarding_draft_store_test.dart`, `app/test/core/field_problems_test.dart`

**Interfaces:**
- Produces:
  - `@immutable final class OnboardingDraft { const new({String? honorific, BirthCalendarEnum? calendar, LunarOrSolarDate? date, bool isLeapMonth = false, BirthTime? time, BirthGenderEnum? gender, City? city}); OnboardingDraft copyWith(...); Map<String, Object?> toJson(); factory OnboardingDraft.fromJson(Map<String, Object?>); bool isCompleteFor({required bool deviceRegionIsKorea}); Birth toBirth(); }`. 생성 enum·모델 이름은 생성 코드에 있는 실제 이름을 씁니다. `toBirth`는 `city`가 있으면 `place: city(cityId)`·`timezone: city.timezone`, 없으면 `place: not_asked`·`timezone: 'Asia/Seoul'`. 양력이면 `isLeapMonth: false`. `isCompleteFor`는 한국 밖이면 `city`까지 요구합니다
  - `final class OnboardingDraftStore { Future<OnboardingDraft?> read(); Future<void> write(OnboardingDraft draft); Future<void> clear(); }`(`OnboardingInputs` 단일 행 id=1, `json`·`updatedAt`)
  - `final onboardingDraftProvider = AsyncNotifierProvider<OnboardingDraftController, OnboardingDraft>`. `OnboardingDraftController.update(OnboardingDraft Function(OnboardingDraft) change)`는 상태를 바꾸고 바로 저장. `clear()`
  - `int honorificMaxLength(Language language)`(ko·ja 10, en 20)
  - `FieldProblem? fieldProblemAt(AppError error, String pointer)`(`ProblemError.fieldErrors`에서 pointer가 같거나 그 아래인 첫 항목), `const profilePointers = (honorific: '/honorific', birthDate: '/birth/date', birthTime: '/birth/time', birthPlace: '/birth/place')`

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `onboarding_draft_test`: `toJson`→`fromJson` 왕복이 같다(음력·윤달·시간 모름·도시 포함). `toBirth`: 도시 없음 → `place.status == not_asked`, `timezone == 'Asia/Seoul'`. 도시 `{id: 5128581, timezone: America/New_York}` → `place.status == city`, `cityId == 5128581`, `timezone == 'America/New_York'`. 양력에 `isLeapMonth: true`를 넣어도 `toBirth().isLeapMonth == false`. `isCompleteFor(deviceRegionIsKorea: false)`는 도시가 없으면 false.
  * `onboarding_draft_store_test`: `write` 뒤 `read`가 같다. 두 번 써도 행은 하나다. `clear` 뒤 null. 로그아웃 정리(`clearSignedOutData`) 뒤 null.
  * `field_problems_test`: `ProblemError(code: 'request.inconsistent', fieldErrors: [FieldProblem('/birth/time/value','required_by_status')])`에서 `fieldProblemAt(e, '/birth/time')`이 그 항목이고 `fieldProblemAt(e, '/birth/date')`는 null이다. `OfflineError`면 null이다. `honorificMaxLength(Language.en) == 20`, ko·ja는 10.
- [ ] **Step 2:** 해당 테스트 → FAIL.
- [ ] **Step 3:** 구현합니다. JSON은 생성 모델의 `toJson`을 재사용하지 말고 이 클래스가 키를 정합니다(생성 모델 필드 이름이 바뀌어도 로컬 형식은 그대로 두기 위해서). 형식에 `"v": 1`을 넣고, 읽을 때 형식이 다르거나 깨졌으면 null(처음부터 입력)로 둡니다.
- [ ] **Step 4:** 해당 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): 온보딩 입력 저장소와 필드 오류 도우미`.

### Task 5: 진입 갈래의 알림 허락 단계와 진입 뒤 목적지 복귀

**Files:**
- Modify: `app/lib/app/entry/entry_state.dart`, `app/lib/app/entry/entry_providers.dart`, `app/lib/app/router/app_router.dart`, `app/lib/app/entry/sign_out_cleaner.dart`, `app/lib/core/storage/device_flags.dart`
- Create: `app/lib/app/router/pending_destination.dart`
- Modify: `app/docs/decisions.md` (A17), `app/docs/specs/2026-10-13-app-architecture-design.md` §3
- Test: `app/test/app/entry_state_test.dart`, `app/test/app/router_redirect_test.dart`, `app/test/app/pending_destination_test.dart`, `app/test/flows/push_open_flow_test.dart`

**Interfaces:**
- Consumes: `PushMessaging.initialOpen()`·`opens`(기반), `DeviceFlagsStore`
- Produces:
  - `EntryState.notifyAskRequired`(순서: forceUpdate > signedOut > consentRequired > profileRequired > **notifyAskRequired** > adConsentRequired > ready). `computeEntry(..., required bool notifyAskPending)`
  - `const notifyAskPendingKey = 'onboarding.notifyAskPending'`
  - `_homeOf(notifyAskRequired) == '/notify-ask'`, redirect 허용 목록 `{notify-ask}`
  - `final pendingDestinationProvider = NotifierProvider<PendingDestination, String?>`. `PendingDestination.remember(String path)`, `String? take()`
  - `entryRedirect({required EntryState? entry, required String path, String? pending})`: entry가 null이고 path가 `/launch`가 아니면 그 path를 기억하고 `/launch`. entry가 정해진 뒤 `/launch`에 있으면 기억한 path가 그 entry에서 허용되는 경우 그 path(그리고 비움), 아니면 home

- [ ] **Step 1:** 실패하는 테스트를 씁니다.
  * `entry_state_test` 표에 더합니다: `hasProfile: true, notifyAskPending: true, adConsentDone: false` → `notifyAskRequired`. `consentRequired: true, notifyAskPending: true` → `consentRequired`. `notifyAskPending: false, adConsentDone: false` → `adConsentRequired`.
  * `router_redirect_test` 표에 더합니다: `notifyAskRequired`에서 `/today` → `/notify-ask`, `/notify-ask` → null. entry null·`/today` → `/launch`이고 기억함. 그 뒤 entry `ready`·`/launch` → `/today`. entry `signedOut`·기억한 `/today` → `/welcome`(member 화면은 home으로).
  * `pending_destination_test`: `take()`는 한 번만 값을 준다.
  * `push_open_flow_test`(fake `member`): `FakePushMessaging(initial: PushOpen.tryCreate('today'))`로 앱을 띄우면 `today`에 닿는다. 시나리오 `new-user`(로그아웃)에서 같은 알림이면 `welcome`이다. 실행 중 `addOpen(today)`도 `today`. `covers(const Covers(exits: ['system-push>today'], decisions: ['D50']))`.
  * `EntryController`: 플래그가 켜져 있으면 광고 동의 `gather()`를 부르지 않는다(대역 호출 횟수 0). 로그아웃 이벤트 뒤 플래그가 false다.
- [ ] **Step 2:** 해당 테스트 → FAIL.
- [ ] **Step 3:** 구현합니다. `_compute`는 `notifyAskPendingKey`를 읽어 넘기고, `adConsentRequired`일 때만 `gather()`합니다. 앱 셸이 `initialOpen()`과 `opens`를 받아 `pathOf(open.screenId)`로 `router.go`합니다. `SignOutCleaner.clean()`이 `notifyAskPendingKey`를 false로 씁니다. 결정 기록에 A17(위 "이 계획이 정하는 것" 표의 첫 줄 내용)을 적고, spec §3 판정 순서를 고칩니다.
- [ ] **Step 4:** 해당 테스트와 `flutter test --exclude-tags golden` 전체 → PASS.
- [ ] **Step 5:** Commit `feat(app): 진입 갈래에 알림 허락 단계, 진입 뒤 원래 목적지와 알림 열기`.

### Task 6: IA 출구 대조

**Files:**
- Modify: `app/lib/app/router/screen_registry.dart`(`ScreenSpec.exits`), `app/test/contract/ia_contract_test.dart`, `app/test/contract/ia_pending.dart`
- Modify: `app/docs/specs/2026-10-13-app-architecture-design.md` §3(대조 방식 한 줄)

**Interfaces:**
- Produces: `ScreenSpec({..., Set<String> exits = const {}})`. 값은 화면이 실제로 이동시키는 대상 화면 id 집합. `const Set<String> pendingExitScreens`(아직 출구를 구현하지 않은 page 화면, ratchet)

- [ ] **Step 1:** 실패하는 테스트를 씁니다. `ia_contract_test`에 "pending이 아닌 page 화면의 `exits`가 IA exits의 대상 집합과 같다"와 "출구를 마친 화면은 `pendingExitScreens`에서 빠져 있다(ratchet)"를 더합니다. 지금은 `launch`만 pending이 아닙니다(`{today, ad-consent, welcome, force-update}`).
- [ ] **Step 2:** `flutter test test/contract/ia_contract_test.dart` → FAIL.
- [ ] **Step 3:** `launch` 등록에 exits를 적고, 나머지 page 화면을 `pendingExitScreens`에 넣습니다. spec §3의 "각 `exits`의 이동이 화면 코드의 이동 표에 있는지"를 "화면 등록의 `exits`와 IA exits가 같은지(구현을 마친 화면부터, ratchet)"로 고칩니다.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5:** Commit `test(app): 화면 등록의 출구를 IA exits와 대조`.

### Task 7: primary-button

**Files:**
- Create: `app/lib/design/components/action/primary_button.dart`
- Modify: `app/lib/design/components/component_spec.dart`(`implementedComponents`), `app/lib/design/components/feedback/error_state.dart`, `app/lib/design/components/feedback/empty_state.dart`, `app/lib/design/components/depth/evidence_lock_panel.dart`
- Create: `app/widgetbook/lib/action_directory.dart`; Modify `app/widgetbook/lib/main.dart`
- Test: `app/test/design/action/primary_button_test.dart`, `app/test/design/action_golden_test.dart`, 기존 feedback·depth golden 재생성

**Interfaces:**
- Produces: `enum PrimaryButtonVariant { filled, quiet, destructive }`, `final class PrimaryButton extends StatelessWidget { const PrimaryButton({required String label, required VoidCallback? onPressed, PrimaryButtonVariant variant = filled, bool loading = false, Key? key}); static const ComponentSpec spec; }`. `onPressed == null`이면 `disabled`. `loading`이면 글자를 숨기고 점 3개 숨쉬기, 너비 그대로, 누름 무시. 높이 filled·destructive 52, quiet 44(action.json)

- [ ] **Step 1:** 실패하는 테스트를 씁니다. `primary_button_test`: `loading: true`일 때 두 번 눌러도 `onPressed`가 0번 불린다. `onPressed: null`이면 Semantics `isEnabled == false`. `loading`이면 Semantics 라벨에 "처리 중"이 알려진다(action.json `busyAnnounced`). 최소 터치 48×48. `destructive`는 `AppIcon.caution`이 앞에 있다. 명세 대조 테스트가 `primary-button`의 변형·상태를 enum과 비교한다(`implementedComponents` 등록).
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** 구현합니다. 먹 번짐(`press.ink`)과 점 숨쉬기(`loading.breathe`)는 기반의 상호작용 구현을 씁니다. `ErrorState`의 다시 시도는 `quiet`, `EmptyState.action` 자리는 `PrimaryButton` filled를 받도록 형식을 좁히고, `EvidenceLockPanel._buildCta`는 `PrimaryButton(filled, loading: …)`으로 바꾸고 손으로 그린 점(`_BreathingDots`)을 지웁니다. 확인 창(`dialog`)의 글자 버튼은 dialog 명세의 버튼이라 그대로 둡니다.
- [ ] **Step 4:** golden `action_golden_test`(변형 3 × 상태 기본·pressed 없이 disabled·loading)를 만들고, 바뀐 feedback·depth golden과 함께 `tool/goldens_linux.sh`로 기준 이미지를 다시 만듭니다. `flutter test --exclude-tags golden`, `flutter analyze`(app·widgetbook) → PASS.
- [ ] **Step 5:** Commit `feat(app): primary-button과 임시 버튼 교체`.

### Task 8: 입력 컴포넌트 1 — input-step·text-field·segmented·check-row

**Files:**
- Create: `app/lib/design/components/input/{input_step,text_field,segmented,check_row}.dart`, `app/widgetbook/lib/input_directory.dart`
- Test: `app/test/design/input/{input_step,text_field,segmented,check_row}_test.dart`, `app/test/design/input_golden_test.dart`

**Interfaces:**
- Produces:
  - `InputStep({required String screenId, required InputStepVariant variant, required String question, required Widget input, String? help, String? error, required String actionLabel, required VoidCallback? onAction, bool actionLoading = false, int? step, int? stepCount})`. `error != null`이면 `out-of-range` 상태(오류 줄 보임, 버튼 disabled, liveRegion assertive). 아래 버튼은 키보드 위에 붙습니다. 진행 막대는 `onboarding` 변형에서만, 라벨 "N단계 중 M단계"(ARB `inputStepProgress`, 매개변수 2개)
  - `MyungliTextField({required String label, TextEditingController? controller, String? hint, int? maxLength, bool error = false, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted})`
  - `Segmented<T>({required List<SegmentedItem<T>> items, required T selected, required ValueChanged<T>? onChanged, required String label})`, `SegmentedItem<T>(this.value, this.label)`. 항목 2~4개(assert)
  - `CheckRow({required CheckRowVariant variant, required String label, required bool checked, required ValueChanged<bool>? onChanged, String? viewLabel, VoidCallback? onView})`
  - 모두 `static const ComponentSpec spec` 등록

- [ ] **Step 1:** 실패하는 테스트를 씁니다. `input_step_test`: `error`가 있으면 버튼 `onPressed`가 비활성이고 오류 줄 Semantics가 liveRegion이다. `step: 2, stepCount: 4`면 진행 막대 라벨이 "4단계 중 2단계"다. `standalone`이면 진행 막대가 없다. 키보드가 올라오면(`MediaQuery.viewInsets.bottom = 300`) 버튼의 아래 끝이 키보드 위 `space.16`이다. `text_field_test`: `maxLength`를 넘게 칠 수 없다. 포커스면 테두리 2px `color.action.primary`, 바탕색은 그대로다. `segmented_test`: 다른 항목을 누르면 `onChanged`가 그 값으로 한 번, 각 항목 Semantics가 radio이고 선택된 것만 `checked`다. `check_row_test`: '보기'를 누르면 `onView`만 불리고 `checked`는 바뀌지 않는다. '보기'는 따로 초점을 받는다.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** 구현합니다(input.json의 parts·states·a11y·rules 값 그대로). 햅틱은 selection.
- [ ] **Step 4:** golden(컴포넌트마다 변형·상태, 라이트·다크, ko·ja, 글자 1.0·2.0)과 Widgetbook 항목을 만들고 기준 이미지를 Linux 스크립트로 만듭니다. 테스트·analyze → PASS.
- [ ] **Step 5:** Commit `feat(app): input-step·text-field·segmented·check-row`.

### Task 9: 입력 컴포넌트 2 — date-picker·time-picker

**Files:**
- Create: `app/lib/design/components/input/{date_picker,time_picker,wheel}.dart`
- Test: `app/test/design/input/{date_picker,time_picker}_test.dart`, `input_golden_test.dart`에 더함

**Interfaces:**
- Consumes: `Segmented`, `CheckRow`(Task 8)
- Produces:
  - `enum DatePickerVariant { birth, calendar }`. `BirthDatePicker({required BirthDateValue value, required ValueChanged<BirthDateValue> onChanged, required String calendarLabelSolar, required String calendarLabelLunar, required String leapMonthLabel})`, `@immutable BirthDateValue{calendar: solar|lunar, year, month, day, isLeapMonth}`. 휠 범위는 1900~2099년. 양력이면 날 휠은 그달의 실제 날수, 음력이면 30일까지. `bool BirthDateValue.isWithinSupportedRange`(양력 1900-01-31 ~ 2099-12-31만 판정, 음력은 연도 범위만 보고 나머지는 server 422)
  - 음력일 때만 윤달 `CheckRow`(inline)를 보입니다(A20 ④). `calendar` 변형은 enum에만 두고 계획 5에서 구현합니다(위젯이 `calendar`를 받으면 `UnimplementedError`)
  - `enum TimePickerVariant { birth, notify }`. `TimePicker({required TimePickerVariant variant, required TimeOfDay value, required ValueChanged<TimeOfDay> onChanged, bool unknown = false, ValueChanged<bool>? onUnknownChanged, String? unknownLabel, String? unknownNotice, String? sijinConfirm})`. `notify`는 분 휠 5분 단위, 모름 없음. `unknown`이면 휠 opacity 0.35·blur 1.5px·비활성, 안내를 보이고 확인 줄을 숨깁니다. `sijinConfirm == null`이면 자리를 비우지 않습니다

- [ ] **Step 1:** 실패하는 테스트를 씁니다. `date_picker_test`: 양력 2월로 바꾸면 날 휠 최댓값이 그해 날수(2024 → 29, 2023 → 28)다. 1900-01-30(양력)은 `isWithinSupportedRange == false`이고 1900-01-31은 true, 2099-12-31은 true다. 음력이면 윤달 체크가 보이고 양력이면 없다. 양력으로 바꾸면 `isLeapMonth`가 false가 된다. 휠 한 칸마다 햅틱 selection 한 번. 년·월·일 휠이 각각 adjustable Semantics다. `time_picker_test`: `notify` 분 휠 값은 5의 배수뿐이다. `unknown: true`면 휠이 비활성이고 `sijinConfirm` 글자가 없다. `sijinConfirm: null`이면 확인 줄 높이가 0이다(자리 없음). 오전·오후·시·분 휠이 각각 adjustable이다.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** 구현합니다. 휠은 `ListWheelScrollView` 기반 공용 `Wheel`(visibleRows 5, rowHeight 40, `type.subtitle`, 위아래 흐림, 선택 띠 `color.status.bg` `radius.md`)에 모읍니다.
- [ ] **Step 4:** golden·Widgetbook·기준 이미지, 테스트·analyze → PASS.
- [ ] **Step 5:** Commit `feat(app): date-picker(birth)·time-picker`.

### Task 10: 컴포넌트 3 — city-search·day-character·share-button·social-login-button

**Files:**
- Create: `app/lib/design/components/input/city_search.dart`, `app/lib/design/components/today/day_character.dart`, `app/lib/design/components/action/{share_button,social_login_button}.dart`, `app/assets/brand/`(제공자 로고와 출처·이용 조건 `README.md`)
- Test: 각 `_test.dart`, `action_golden_test.dart`·`input_golden_test.dart`에 더함, `app/test/design/today_golden_test.dart`

**Interfaces:**
- Produces:
  - `CitySearch({required String label, String? hint, required ValueChanged<String> onQueryChanged, required AsyncValue<List<City>>? results, required ValueChanged<City> onSelected, required String emptyBody, required VoidCallback onRetry})`. `results == null`이면 결과 자리 없음, `loading`이면 skeleton 줄 3개, 빈 목록이면 `EmptyState`, 오류면 `ErrorState`. 줄은 도시 이름(검색어와 맞는 부분 굵게 600)과 지역 자리(`City.country`, A20 ⑤). 결과 수 알림 "결과 N개"(ARB `citySearchResults`)
  - `enum DayCharacterVariant { good, gwiin, gisin, ordinary }`, `DayCharacterVariant dayCharacterVariantOf(DayKind kind)`, `DayCharacter({required DayCharacterVariant variant, required String label, RenderedText? reason, Widget? reasonTrailing})`
  - `enum ShareButtonVariant { icon, soft }`, `ShareButton({required ShareButtonVariant variant, required String label, required VoidCallback onPressed})`
  - `enum SocialProvider { kakao, apple }`, `SocialLoginButton({required SocialProvider provider, required String label, required VoidCallback? onPressed, bool loading = false})`. 순서와 크기는 화면이 정하고(카카오 위, Apple 아래, 같은 크기), 이 위젯은 제공자 공식 색·로고를 씁니다. Apple은 라이트에서 검정, 다크에서 흰색

- [ ] **Step 1:** 제공자 로고를 받습니다. 카카오 로그인 디자인 가이드(Kakao Developers)의 심볼과 Sign in with Apple(Apple HIG) 로고를 공식 배포처에서 받아 `assets/brand/`에 두고, 출처 URL·이용 조건 요약을 `assets/brand/README.md`에 적습니다. 공식 배포처에서 받을 수 없으면 멈추고 controller에 알립니다(사용자가 받아 넣을 몫).
- [ ] **Step 2:** 실패하는 테스트를 씁니다. `city_search_test`: 검색어 "seo"에 결과 "Seoul"이면 "Seo"가 굵다. `loading`이면 skeleton 줄이 3개다. 빈 목록이면 `emptyBody` 글자가 보인다. 결과가 바뀌어도 스크롤 위치가 그대로다. 줄을 누르면 `onSelected`가 그 도시로 한 번. `day_character_test`: `dayCharacterVariantOf`가 `yongsin_day → good`, `gwiin_day → gwiin`, `gisin_day → gisin`, `ordinary_day → ordinary`다. Semantics 라벨이 "배지 글자 + 이유"다. `reason`이 없으면 이유 줄이 없다. `share_button_test`: `soft`의 높이 36, 최소 터치 44. `social_login_button_test`: `loading`이면 누름을 무시한다. 다크 테마의 Apple 바탕이 흰색이다.
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현하고 golden·Widgetbook·기준 이미지를 만듭니다. 테스트·analyze → PASS.
- [ ] **Step 5:** Commit `feat(app): city-search·day-character·share-button·social-login-button`.

### Task 11: force-update·welcome 화면

**Files:**
- Create: `app/lib/features/onboarding/presentation/{force_update_screen,welcome_screen}.dart`
- Modify: `screen_registry.dart`, `app/lib/core/l10n/arb/app_{ko,en,ja}.arb`
- Test: `app/test/flows/welcome_flow_test.dart`, `app/test/features/onboarding/force_update_screen_test.dart`

**Interfaces:**
- Consumes: `PrimaryButton`, `storeLauncherProvider`(Task 2)
- Produces: 화면 `force-update`(exits `{}`), `welcome`(exits `{onboard-call, login}`)

- [ ] **Step 1:** ARB 임시 키를 더합니다: `forceUpdateNoticeHead`·`forceUpdateNoticeBody`·`forceUpdateCtaStore`, `welcomeConceptHead`·`welcomeConceptBody`·`welcomeCtaStart`·`welcomeCtaSignin`(ko·en·ja, `@description` 임시). 슬롯 문구는 ARB 문자열이므로 `SentenceBlock`(RenderedText용)이 아니라 같은 글자 역할의 `Text`로 그리고 슬롯 id를 Key·Semantics로 붙입니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다. `welcome_flow_test`(fake `new-user`): 시작하면 `welcome`이 보이고, `welcome.cta.start`를 누르면 `onboard-call`, 뒤로 와서 `welcome.cta.signin`을 누르면 `login`. `covers(const Covers(exits: ['welcome>onboard-call', 'welcome>login']))`. `force_update_screen_test`(fake `force-update`): `force-update`의 버튼을 누르면 `FakeStoreLauncher.opened == 1`이고 뒤로 가기로 벗어날 수 없다.
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현하고 등록합니다(`welcome`의 handledStates `{}`, `force-update` `{}`). `pendingExitScreens`·`pendingStateScreens`에서 두 화면을 지웁니다(있다면). 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): force-update·welcome 화면`.

### Task 12: onboard-call·onboard-birth 화면

**Files:**
- Create: `app/lib/features/onboarding/presentation/{onboard_call_screen,onboard_birth_screen,onboarding_step_mode}.dart`
- Modify: `screen_registry.dart`, ARB, `app/docs/decisions.md`(A19), `app/test/contract/ia_pending.dart`
- Test: `app/test/flows/onboarding_flow_test.dart`, `app/test/features/onboarding/onboard_birth_screen_test.dart`

**Interfaces:**
- Consumes: `InputStep`, `MyungliTextField`, `BirthDatePicker`, `onboardingDraftProvider`, `honorificMaxLength`, `appLanguageProvider`
- Produces:
  - `enum OnboardingStepMode { onboarding, edit }`, `OnboardingStepMode onboardingStepModeOf(GoRouterState state)`(query `mode=edit`)
  - 수정 모드 반환값: `onboard-call` → `String`(호칭), `onboard-birth` → `BirthDateValue`(A19)
  - 화면 `onboard-call`(exits `{onboard-birth, profile-edit}`), `onboard-birth`(exits `{onboard-time, profile-edit}`, handledStates `{out-of-range}`)
  - 온보딩 진행 단계 수: 한국 4(call·birth·time·gender), 한국 밖 5(+birthplace)

- [ ] **Step 1:** ARB 임시 키: `onboardCallQuestionHead`·`onboardCallInputHint`·`onboardCallNoteBody`, `onboardBirthQuestionHead`·`onboardBirthCalendarHint`·`onboardBirthBasisNote`·`onboardBirthErrorRange`, 공용 `onboardingNext`(다음)·`onboardingSave`(수정 모드 저장)·`calendarSolar`·`calendarLunar`·`leapMonth`.
- [ ] **Step 2:** 실패하는 테스트를 씁니다. `onboarding_flow_test`(fake `new-user`):
  * `onboard-call`에서 빈 호칭이면 다음 버튼이 비활성이다. 한국어 11자는 칠 수 없다(10자 상한). "별님"을 넣고 다음 → `onboard-birth`이고 `OnboardingDraftStore.read().honorific == '별님'`이다. `covers(const Covers(exits: ['onboard-call>onboard-birth'], decisions: ['D50']))`.
  * `onboard-birth`에서 1990-05-17 양력 → 다음 → `onboard-time`. 뒤로 가면 `onboard-birth`에 1990-05-17이 남아 있다. `covers(const Covers(exits: ['onboard-birth>onboard-time']))`.
  * 앱을 다시 띄워도(같은 DB) `onboard-call`에 "별님"이 채워져 있다.
  * 수정 모드: 테스트용 부모 화면이 `/onboard-call?mode=edit`를 push하면 버튼 글자가 `onboardingSave`이고, 저장하면 부모가 `'달님'`을 받으며 `OnboardingDraftStore`는 바뀌지 않는다. `covers(const Covers(exits: ['onboard-call>profile-edit', 'onboard-birth>profile-edit']))`.
  * `onboard_birth_screen_test`: 양력 1900-01-30이면 `onboard-birth.error.range` 문구가 보이고 다음이 비활성이다(`covers(const Covers(states: ['onboard-birth:out-of-range'], decisions: ['D41']))`는 흐름 테스트 쪽에 둡니다).
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현합니다. `onboard-birth`는 `onboard-birth.basis.note`(한국 출생 기준)를 한국 기기에서만 보입니다(D29). 결정 기록에 A19를 적습니다. `pendingStateScreens`에서 `onboard-birth`를, `pendingExitScreens`에서 두 화면을 지웁니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): onboard-call·onboard-birth 화면과 수정 모드`.

### Task 13: onboard-time·onboard-gender 화면

**Files:**
- Create: `app/lib/features/onboarding/presentation/{onboard_time_screen,onboard_gender_screen}.dart`, `app/lib/features/onboarding/data/birth_hour_repository.dart`
- Create: `app/fixtures/new-user/getBirthHour.json`, `app/fixtures/birth-hour-unavailable/getBirthHour.json`(501), `fixtures/scenarios.json`에 `birth-hour-unavailable`(extends `new-user`)과 `overseas`(extends `new-user`, 기기 지역 US·시간대 `America/New_York`)
- Modify: `app/lib/core/api/fake/scenario.dart`(시나리오에 `locale` 필드, 기기 로케일 override), `screen_registry.dart`, ARB, `ia_pending.dart`
- Test: `onboarding_flow_test.dart`에 더함, `app/test/features/onboarding/onboard_time_screen_test.dart`

**Interfaces:**
- Consumes: `TimePicker`, `Segmented`, `installationIdProvider`, `deviceRegionIsKoreaProvider`
- Produces:
  - `final class BirthHourRepository { Future<BirthHour> fetch({required BirthDateValue date, required String time}); }`(`getBirthHour`, `installationId` 포함)
  - `final birthHourProvider = FutureProvider.autoDispose.family<BirthHour?, ({BirthDateValue date, String time})>`. 한국 기기가 아니면 요청하지 않고 null. 오류면 null(A20, 줄을 그리지 않음)
  - `String sijinConfirmText(AppLocalizations l10n, BirthHour hour)`. ARB 틀 `onboardTimeHourConfirm`(`{branch}`, `{start}`, `{end}`)과 지지 이름 12개(`branchJa`·`branchChuk`·`branchIn`·`branchMyo`·`branchJin`·`branchSa`·`branchO`·`branchMi`·`branchShin`·`branchYu`·`branchSul`·`branchHae`)
  - 화면 `onboard-time`(exits `{onboard-gender, profile-edit}`, handledStates `{time-unknown}`), `onboard-gender`(exits `{preview, birthplace, profile-edit}`)

- [ ] **Step 1:** ARB 임시 키: `onboardTimeQuestionHead`·`onboardTimeUnknownNote`·`timeUnknownLabel`, `onboardTimeHourConfirm`, 지지 12개, `onboardGenderQuestionHead`·`onboardGenderWhyBody`·`genderMale`·`genderFemale`. fixture `getBirthHour`는 `{branch: in, start: "03:30", end: "05:30"}`입니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다(`onboarding_flow_test`에 이어서).
  * `onboard-time`에서 04:00을 고르면 "인시(03:30~05:30)"를 담은 확인 줄이 보인다(휠이 멈춘 뒤 한 번 요청, 요청 본문에 `installationId`와 `"time":"04:00"`). 모름을 켜면 `onboard-time.unknown.note`가 보이고 확인 줄이 없다. 다음 → `onboard-gender`이고 초안 `time.status == unknown`이다. `covers(const Covers(exits: ['onboard-time>onboard-gender'], states: ['onboard-time:time-unknown']))`.
  * 시나리오 `birth-hour-unavailable`: 확인 줄이 없고 다음은 된다.
  * 시나리오 `overseas`: 확인 줄을 요청하지도 그리지도 않는다(`getBirthHour` 호출 0회).
  * `onboard-gender`에서 성별을 고르기 전에는 다음이 비활성이다. 한국 기기에서 다음 → `preview`. `overseas`에서 다음 → `birthplace`. `covers(const Covers(exits: ['onboard-gender>preview', 'onboard-gender>birthplace'], decisions: ['D29']))`.
  * 세션이 있는 `profile-required` 시나리오에서 `onboard-gender`의 다음은 `preview`로 가지 않고 `OnboardingCompleter.complete()`를 부른다(Task 17에서 연결, 이 task에서는 `onboardingFinishProvider` 호출만 확인. 아래 Interfaces 참고).
  * 수정 모드 반환값: `onboard-time` → `BirthTime`, `onboard-gender` → `BirthGenderEnum`. `covers(const Covers(exits: ['onboard-time>profile-edit', 'onboard-gender>profile-edit']))`.
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현합니다. 세션이 있으면 미리보기를 건너뛰는 분기는 `final onboardingFinishProvider = Provider<Future<void> Function()>`를 부르는 한 줄로 두고, 기본값은 `UnimplementedError`입니다. Task 17이 채웁니다. `pendingStateScreens`에서 `onboard-time`을 지웁니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): onboard-time(시진 확인 줄)·onboard-gender 화면`.

### Task 14: birthplace 화면

**Files:**
- Create: `app/lib/features/onboarding/presentation/birthplace_screen.dart`, `app/lib/features/onboarding/data/city_repository.dart`
- Create: `app/fixtures/new-user/listCities.json`, `app/fixtures/cities-error/listCities.json`(503), `scenarios.json`에 `cities-error`(extends `overseas`)
- Modify: `screen_registry.dart`, ARB, `ia_pending.dart`
- Test: `app/test/flows/birthplace_flow_test.dart`

**Interfaces:**
- Consumes: `CitySearch`, `appLanguageProvider`
- Produces:
  - `final class CityRepository { Future<List<City>> search(String query, {required Language language}); }`(`listCities`, `limit` 20). 같은 질의는 응답 `ETag`로 `If-None-Match`를 보내고 304면 이전 목록(spec §4.4 참조 데이터)
  - 검색은 입력이 멈추고 300ms 뒤에, 1자 미만이면 요청하지 않음, 50자 초과는 자름(계약 `q` 1~50)
  - 화면 `birthplace`(exits `{preview, profile-edit, settings}`, handledStates `{loading, empty, error}`). 수정 모드 반환값 `City`

- [ ] **Step 1:** ARB 임시 키: `birthplaceQuestionHead`·`birthplaceWhyBody`·`birthplaceSearchHint`·`birthplaceEmptyBody`, `citySearchResults`. fixture `listCities`는 `{dataVersion, items: [{id: 5128581, name: "New York City", country: "US", timezone: "America/New_York"}, …3개]}`입니다. 쿼리 매개변수별 fixture는 없으므로 빈 결과는 `sequence`의 두 번째 응답으로 재현합니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다(`overseas` 시나리오로 `birthplace`까지 진행). "new"를 치면 300ms 전에는 요청이 없고 뒤에 한 번, 결과를 받는 동안 skeleton(`birthplace:loading`), 도시를 누르면 초안 `city.timezone == 'America/New_York'`이고 `preview`로 간다. 두 번째 검색이 빈 목록이면 `birthplace.empty.body`(`birthplace:empty`). `cities-error`면 오류 상태와 다시 시도(`birthplace:error`). `covers(const Covers(exits: ['birthplace>preview'], states: ['birthplace:loading', 'birthplace:empty', 'birthplace:error'], decisions: ['D29']))`. 수정 모드에서 고르면 부모가 `City`를 받는다(`covers(const Covers(exits: ['birthplace>profile-edit', 'birthplace>settings']))`, 부모 화면을 `profile-edit`·`settings` 두 경우로).
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현합니다. 세션이 있으면 도시를 고른 뒤 `onboardingFinishProvider`를 부릅니다(Task 13과 같은 분기). `pendingStateScreens`에서 `birthplace`를 지웁니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): birthplace 화면(도시 검색)`.

### Task 15: preview 화면

**Files:**
- Create: `app/lib/features/onboarding/presentation/preview_screen.dart`, `app/lib/features/onboarding/data/preview_repository.dart`, `app/lib/features/onboarding/application/preview_providers.dart`
- Create: fixture `new-user/createPreview.json`, `preview-used/createPreview.json`(403 `preview.used`), `time-unknown/createPreview.json`(notices에 `time_unknown`), `preview-invalid/createPreview.json`(422 `birth.invalid`), 시나리오 4개(모두 extends `new-user`)
- Modify: `screen_registry.dart`, ARB, `app/docs/decisions.md`(A20), `ia_pending.dart`
- Test: `app/test/flows/preview_flow_test.dart`

**Interfaces:**
- Consumes: `DayCharacter`, `SentenceBlock`(variant `preview`), `ShareButton`(soft), `PrimaryButton`, `showMyungliDialog`, `NoticeBanner`, `ScreenStateView`, `installationIdProvider`, `deviceTimezoneProvider`
- Produces:
  - `final class PreviewRepository { Future<Preview> create({required OnboardingDraft draft}); }`(`installationId`, `currentTimezone` = 기기 시간대, `birth` = `draft.toBirth()`)
  - `final previewProvider = FutureProvider.autoDispose<Preview>`
  - 화면 `preview`(exits `{login, onboard-call}`, handledStates `{loading, error, offline, time-unknown}`)
  - 날의 성격 이름 ARB `dayKindYongsinDay`·`dayKindGwiinDay`·`dayKindGisinDay`·`dayKindOrdinaryDay`(A20 ①)

- [ ] **Step 1:** ARB 임시 키: `previewCtaSave`·`previewCtaRestart`·`previewShareLoginNotice`, `dayKind*` 4개, `shareLabel`, 확인 창 버튼 `actionLogin`·`actionClose`. fixture `createPreview` 본문은 계약 `Preview` 스키마를 따르고(`evidenceAccess: locked`, `fortune.head.text.segments`에 `term` 조각 하나 포함) fixture 검증을 통과해야 합니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다(`onboarding_flow_test`의 입력을 마치는 도우미를 공용으로 빼서 씁니다).
  * `new-user`: `preview`에 들어오면 skeleton(`preview:loading`) 뒤 배지 "용신의 날"(`dayKind: yongsin_day`의 임시 이름)과 `preview.fortune.head` 문장, `fortune.tag`가 있으면 `preview.fortune.body`. 용어 조각은 칩이 아니라 일반 글자다(V28). 요청 헤더에 `X-Firebase-AppCheck`가 있고 `Authorization`이 없다. `preview.cta.save` → `login`. `covers(const Covers(exits: ['preview>login'], states: ['preview:loading'], decisions: ['D50']))`.
  * 공유 버튼 → `preview.share.login-notice` 확인 창 → 로그인 → `login`. 닫기면 `preview`에 남는다. `covers(const Covers(exits: ['preview>login']))`.
  * `preview.cta.restart` → `onboard-call`이고 호칭이 채워져 있다. `covers(const Covers(exits: ['preview>onboard-call']))`.
  * `time-unknown`: 시간 모름 배너(`preview:time-unknown`). `offline`(`network: offline`): 오프라인 오류 상태와 다시 시도(`preview:offline`). `preview-invalid`: 오류 상태에 `birth.invalid` 문구와 다시 입력 버튼, 다시 입력하면 `onboard-call`에 입력이 그대로다(`preview:error`, Review Focus 2). `preview-used`: 오류 문구를 보이되 `preview.cta.save`는 그대로 눌러 `login`으로 갈 수 있다.
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현하고 결정 기록에 A20(위 표 그대로)을 적습니다. `pendingStateScreens`에서 `preview`를 지웁니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): preview 화면(첫 풀이)`.

### Task 16: login 화면

**Files:**
- Create: `app/lib/features/auth/data/auth_repository.dart`, `app/lib/features/auth/application/login_controller.dart`, `app/lib/features/auth/presentation/login_screen.dart`
- Create: fixture `new-user/loginKakao.json`·`loginApple.json`·`completeAppleWebLogin.json`(새 계정: `isNewAccount: true, consentRequired: true`), `returning-user/…`(기존 계정: `isNewAccount: false, consentRequired: false`, getMe `hasProfile: true`), `login-provider-down/loginKakao.json`(503 `auth.provider_unavailable`), `login-exchange-invalid/completeAppleWebLogin.json`(401 `auth.exchange_invalid`), 해당 시나리오
- Modify: `screen_registry.dart`, ARB, `ia_pending.dart`, `app/lib/design/components/feedback/dialog.dart`(필요하면 한 버튼 형식)
- Test: `app/test/features/auth/login_controller_test.dart`, `app/test/flows/login_flow_test.dart`

**Interfaces:**
- Consumes: `kakaoAuthProvider`, `appleNativeAuthProvider`, `appleWebAuthProvider`, `nonceGeneratorProvider`, `targetPlatformProvider`, `TokenStore.save`, `entryStateProvider`, `onboardingDraftProvider`, `SocialLoginButton`
- Produces:
  - `final class AuthRepository { Future<LoginResponse> kakao({required String idToken, required String rawNonce}); Future<LoginResponse> appleNative({required String idToken, required String authorizationCode, required String rawNonce}); Future<LoginResponse> appleWeb({required String exchangeCode, required String rawNonce}); }`
  - `sealed class LoginOutcome`: `LoginSucceeded(LoginResponse)`, `LoginCancelled`, `LoginFailed(AppError)`, `AppleWebFailed(AppleWebError)`
  - `final class LoginController extends AutoDisposeAsyncNotifier<void> { Future<LoginOutcome> signInWithKakao(); Future<LoginOutcome> signInWithApple(); }`. 시도마다 새 원문 nonce 하나를 만들어 adapter와 server에 같은 값을 넘깁니다. iOS는 `appleNative`, Android는 `AppleWebAuth` 결과의 `AppleWebExchange.exchangeCode`로 `appleWeb`. 성공하면 `TokenStore.save(tokens)` 뒤 `entryStateProvider.notifier.refresh()`
  - 화면 `login`(exits `{consent, today, ad-consent}`, handledStates `{error}`)

- [ ] **Step 1:** ARB 임시 키: `loginTitleHead`·`loginTitleBody`·`loginDiscardNotice`, `loginKakaoLabel`(카카오 공식 문구 "카카오 로그인")·`loginAppleLabel`(Apple 공식 문구 "Apple로 로그인"), `loginCancelled`, `appleWebError*`(state 불일치·취소·그 밖 각각). 공식 문구는 제공자 가이드의 언어별 문구를 씁니다.
- [ ] **Step 2:** 실패하는 테스트를 씁니다.
  * `login_controller_test`: 카카오 성공이면 `FakeKakaoAuth.providerNonces.single == hashNonce(server에 보낸 nonce)`이고 server 요청 `nonce` 길이 32다. 두 번 시도하면 nonce가 서로 다르다. Android(`targetPlatform: android`)에서 Apple은 `loginApple`을 부르지 않고 `completeAppleWebLogin`을 `{exchangeCode: fakeAppleExchangeCode, nonce: <원문>}`으로 한 번 부르며, 열린 authorize URL의 `nonce` 매개변수가 `hashNonce(원문)`이다. iOS에서는 `loginApple`을 부른다. `AppleWebFailure(stateMismatch)`면 server를 부르지 않고 `AppleWebFailed(stateMismatch)`. `auth.exchange_invalid`면 같은 교환 코드로 다시 보내지 않는다(다음 시도는 새 nonce·새 authorize). 카카오 adapter가 취소 오류면 `LoginCancelled`.
  * `login_flow_test`: `new-user`에서 미리보기 뒤 카카오 → `consent`(`covers(const Covers(exits: ['login>consent'], decisions: ['D50']))`). `returning-user`에서 초안이 없으면 → `today` 전에 광고 동의(대역 `gather` 1회) → `today`(`covers(const Covers(exits: ['login>ad-consent', 'ad-consent>today', 'login>today'], decisions: ['D53']))`. 광고 동의를 이미 한 기기면 바로 `today`). `returning-user`에서 초안이 있으면 `login.discard.notice` 확인 창을 보인 뒤 초안을 지우고 진행한다. `login-provider-down`: 오류 상태에 재시도 안내, 토큰 없음, 다시 누르면 다시 요청(`login:error`). 버튼을 빠르게 두 번 눌러도 `loginKakao` 요청은 한 번이다(Review Focus 4).
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현합니다. `login.discard.notice`는 버튼 하나(확인)인 안내입니다. `showMyungliDialog`가 취소 버튼을 요구하면, dialog.json에 한 버튼 형식이 있는지 확인해 `cancel`을 선택 인자로 넓히거나, 없으면 확인·닫기 두 버튼으로 두고 report에 적습니다. `pendingStateScreens`에서 `login`을 지웁니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): login 화면(카카오·Apple native·Android 웹, nonce 규칙)`.

### Task 17: consent 화면과 계정 만들기 마무리

**Files:**
- Create: `app/lib/features/auth/presentation/consent_screen.dart`, `app/lib/features/auth/data/consent_repository.dart`, `app/lib/features/onboarding/application/onboarding_completer.dart`
- Create: fixture `new-user/agreeConsents.json`(204), `new-user/createProfile.json`, `new-user/getMe.json`(`sequence`: 동의 전 `consentRequired: true, hasProfile: false` → 동의 뒤 `false, false` → 프로필 뒤 `false, true`), `new-user-signin/…`(미리보기 없이 로그인한 새 계정), `consent-mismatch/agreeConsents.json`(422 `consent.version_mismatch`, `errors: [{field: "/documents/0/version", code: "consent.version_mismatch"}]`), `profile-invalid/createProfile.json`(422 `birth.invalid`), 시나리오
- Modify: `screen_registry.dart`, ARB, `ia_pending.dart`, `onboardingFinishProvider`(Task 13) 기본값 연결
- Test: `app/test/features/onboarding/onboarding_completer_test.dart`, `app/test/flows/consent_flow_test.dart`

**Interfaces:**
- Consumes: `CheckRow`(card), `ProfileRepository.create`, `OnboardingDraftStore`, `appLanguageProvider`, `deviceTimezoneProvider`, `notifyAskPendingKey`
- Produces:
  - `final class ConsentRepository { Future<void> agree(List<ConsentDocument> documents); }`
  - `final class OnboardingCompleter { Future<void> complete(); }`: `ProfileInput(honorific, language: appLanguage, currentTimezone: 기기 시간대, birth: draft.toBirth(), notification: NotificationSetting(status: not_asked))` → `ProfileRepository.create` → `notifyAskPendingKey = true` → 초안 삭제(플래그를 먼저 써서 그 사이 꺼져도 notify-ask를 건너뛰지 않음, 리뷰 반영) → `entryStateProvider.notifier.refresh()`. 422 입력 오류(`birth.*`·`date.*`·`name.*`·`request.inconsistent`)는 초안을 남기고 `OnboardingInputRejected(AppError)`를 던집니다
  - `onboardingFinishProvider`를 `completer.complete`로 채움
  - 진입이 `profileRequired`이고 초안이 완전하면(`isCompleteFor`) 화면을 거치지 않고 `complete()`를 부르는 자리: `EntryController`가 아니라 `onboard-call` 진입 때 한 번 확인합니다(Review Focus 1)
  - 화면 `consent`(exits `{notify-ask, onboard-call, legal}`, handledStates `{error}`)

- [ ] **Step 1:** ARB 임시 키: `consentTitleHead`·`consentRequiredLabel`·`consentOptionalLabel`·`consentCtaAgree`, `consentDocumentTerms`·`consentDocumentPrivacy`, `consentView`(보기). `consentOptionalLabel`은 선택 문서가 없으므로 쓰지 않지만 슬롯 키는 둡니다(writing 원고 대비).
- [ ] **Step 2:** 실패하는 테스트를 씁니다.
  * `onboarding_completer_test`: 성공이면 `createProfile` 본문이 `{honorific, language: ko, currentTimezone: Asia/Seoul, birth: {... place: {status: not_asked}, timezone: Asia/Seoul}, notification: {status: not_asked}}`이고, 초안이 지워지고, 플래그가 켜지고, 프로필 사본이 생긴다. `profile-invalid`면 초안이 남고 `OnboardingInputRejected`다.
  * `consent_flow_test`:
    * `new-user`(미리보기 거침): 문서 두 개가 check-row로 보이고 둘 다 체크하기 전에는 동의 버튼이 비활성이다. 동의 → `agreeConsents` 본문의 문서·버전이 `getMe.requiredConsents`와 같다 → 프로필 저장 → `notify-ask`. `covers(const Covers(exits: ['consent>notify-ask'], decisions: ['D50']))`.
    * `new-user-signin`(미리보기 없음): 동의 → `onboard-call`. 그 뒤 입력을 마치고 `onboard-gender`의 다음 → `notify-ask`(미리보기 없이). `covers(const Covers(exits: ['consent>onboard-call']))`.
    * '보기' → `legal`, 체크는 그대로다. `covers(const Covers(exits: ['consent>legal']))`.
    * `consent-mismatch`: 동의 실패 뒤 `getMe`를 다시 받아 체크를 풀고 오류 문구를 보인다(`consent:error`). `covers(const Covers(states: ['consent:error']))`.
    * `profile-invalid`: 동의 뒤 프로필 저장이 422면 `onboard-call`로 가고 오류 문구를 toast로 보이며 입력이 남아 있다(Review Focus 2).
    * 앱 재시작: 동의까지 하고 프로필 저장 전에 끊긴 상태(`profile-required` + 완전한 초안)로 띄우면 같은 질문 없이 `notify-ask`에 닿는다(Review Focus 1).
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현합니다. 동의 직후에는 "프로필 저장 → refresh" 순서입니다(먼저 refresh하면 `profileRequired`로 `onboard-call`에 튕김). `pendingStateScreens`에서 `consent`를 지웁니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): consent 화면과 프로필 저장 마무리`.

### Task 18: notify-ask 화면

**Files:**
- Create: `app/lib/features/onboarding/presentation/notify_ask_screen.dart`, `app/lib/features/onboarding/data/device_repository.dart`
- Create: fixture `new-user/registerDevice.json`(201), `new-user/updateProfile.json`
- Modify: `app/lib/core/storage/device_flags.dart`(`const registeredDeviceIdKey = 'push.deviceId'`), `screen_registry.dart`, ARB
- Test: `app/test/flows/notify_ask_flow_test.dart`

**Interfaces:**
- Consumes: `TimePicker`(notify), `InputStep`(standalone), `pushMessagingProvider`, `ProfileRepository.update`, `DeviceFlagsStore`
- Produces:
  - `final class DeviceRepository { Future<Device> register({required String fcmToken, required DevicePlatformEnum platform, required String idempotencyKey}); }`. 성공하면 기기 id를 `registeredDeviceIdKey`에 저장(계획 7의 `deleteDevice`가 씀)
  - 허락: 권한 요청 → 허락이면 토큰으로 등록, `updateProfile(notification: enabled, time: HH:MM)` → 거절이면 `updateProfile(notification: disabled)` → 플래그 끔 → refresh
  - 건너뛰기: `updateProfile(notification: disabled)` → 플래그 끔 → refresh. 기본 시각 08:00(5분 단위)
  - 화면 `notify-ask`(exits `{ad-consent}`, handledStates `{}`)

- [ ] **Step 1:** ARB 임시 키: `notifyAskQuestionHead`·`notifyAskWhyBody`·`notifyAskCtaSkip`, `notifyAskCtaAllow`.
- [ ] **Step 2:** 실패하는 테스트를 씁니다. 07:30을 고르고 허락 → `registerDevice` 한 번(`Idempotency-Key` 헤더 UUID, 실패 뒤 재시도도 같은 키), `updateProfile` 본문 `{"notification":{"status":"enabled","time":"07:30"}}`, `registeredDeviceIdKey` 저장 → 광고 동의(`gather` 1회) → `today`. `covers(const Covers(exits: ['notify-ask>ad-consent', 'ad-consent>today'], decisions: ['D53']))`. 권한 거절(`FakePushMessaging(permissionGranted: false)`)이면 `registerDevice` 없이 `disabled`. 건너뛰기면 `disabled`이고 같은 흐름. 버튼 두 번 → 요청 한 번. 앱을 다시 띄워도 `notify-ask`가 다시 나오지 않는다.
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4:** 구현합니다. 테스트 → PASS.
- [ ] **Step 5:** Commit `feat(app): notify-ask 화면(알림 시각·권한·기기 등록)`.

### Task 19: 전체 흐름·E2E·커버리지·문서·요청

**Files:**
- Test: `app/test/flows/new_user_flow_test.dart`, `app/patrol_test/onboarding_test.dart`, `app/patrol_test/login_test.dart`
- Modify: `app/tool/coverage_baseline.json`, `app/test/contract/ia_pending.dart`, `app/README.md`(시나리오 표·`features/` 구조), `app/CLAUDE.md`(현재 상태·다음 할 일), `app/docs/specs/2026-10-13-app-architecture-design.md`(개정 기록), `app/docs/artifacts/index.json`

- [ ] **Step 1:** `new_user_flow_test`(fake `new-user`): `welcome → onboard-call → onboard-birth → onboard-time → onboard-gender → preview → login → consent → notify-ask → (ad-consent) → today`를 한 번에 지나고, 끝에서 온보딩 초안이 비어 있고 프로필 사본의 `currentTimezone == 'Asia/Seoul'`이다. `covers(const Covers(exits: [...앞 경로 전부], decisions: ['D50', 'D53']))`.
- [ ] **Step 2:** Patrol `onboarding_test`(새 사용자 전체 흐름)와 `login_test`(기존 사용자)를 쓰고, 각 화면에 닿을 때 `expectScreen`으로 스크린샷을 남깁니다. 로컬 Android 에뮬레이터에서 실행하고 등록 도구로 `index.json`에 올립니다(README 절차). iOS 시뮬레이터에서도 한 번 돌려 결과를 report에 적습니다.
- [ ] **Step 3:** `dart run tool/ia_coverage.dart --update-baseline` 후 `--check` → 통과. 이 계획 화면이 `pendingStateScreens`·`pendingExitScreens`에 남지 않았는지 확인합니다.
- [ ] **Step 4:** 전체 검사: `flutter analyze`(app·widgetbook) 0, `flutter test --exclude-tags golden` 전체, golden(Linux) 차이 0, 생성 코드 차이 0, fixture 검증, `mlw check-arb`, `uvx --from actionlint-py actionlint .github/workflows/app.yml`, `flutter build apk --debug`, `flutter build ios --debug --no-codesign`.
- [ ] **Step 5:** 문서를 고칩니다. `app/CLAUDE.md` 현재 상태(계획 2 완료, A17~A21, 커버리지 값)와 다음 할 일(계획 3, 계획 6이 받을 수정 모드 반환값과 프로필 사본, 계획 7이 받을 기기 id·스토어 앱 id·`social-login-button` 공식 자산 확인), README 시나리오 표, spec 개정 기록 한 줄.
- [ ] **Step 6:** Commit `test(app): 온보딩·로그인 전체 흐름과 E2E, 커버리지 기준 갱신` / `docs(app): 계획 2 상태와 다음 할 일`.
- [ ] **Step 7(controller):** 다른 단위에 Issue를 보냅니다(본문은 무엇이 필요한가·왜·영향·관련).
  * root(`kind:request`): IA 출구 `onboard-gender>notify-ask`·`birthplace>notify-ask`(로그인한 새 계정이 미리보기 없이 온보딩을 마칠 때) 추가. `preview.character.label`·`preview.fortune.body`·`onboard-time.hour.confirm`의 source와 실제 응답의 차이(A20). `consent.optional.label`에 대응하는 선택 문서가 없음
  * server(`kind:request`): 프로필 GET(또는 `Me`에 프로필 요약과 `currentTimezone`) 추가(A18, 계획 6 `profile-edit` 필요). `City`의 지역 표시값. 음력→양력 변환과 윤달 유무 조회(date-picker `solarConfirm`·`leapMonth`). `Preview`의 날의 성격 문장과 총운 이어지는 문장
  * design(`kind:notice`): date-picker `solarConfirm`·`leapMonth` 휠을 계약 공백으로 그리지 않은 것, 윤달을 inline 체크로 받은 것, city-search 지역 자리에 나라 코드를 쓴 것
  * #127에 병합 소식(PR 병합 뒤)

### Task 20 (추가): writing IA v2 브랜치 병합과 ui 원고 반영 (#135·#128)

계획 2를 진행하는 동안 main에 writing의 ui 원고(#132)가 병합됐고, IA v2(D67, 선택 동의 슬롯 제거)가 지휘 PR #133과 writing PR #138로 쌓여 있습니다. #135의 지시대로 이 app 브랜치가 그 둘을 품은 **최종 PR**이 됩니다.

**바뀐 것**
- writing 브랜치 `origin/writing/ia-v2-consent`(PR #138)는 main 최신(#132·#137 포함)과 지휘 `origin/root/ia-v2-consent`(PR #133)를 모두 포함합니다.
- IA v2: `docs/ia/screens.json` `version` 2, 슬롯 `consent.optional.label` 삭제(D67, MVP 약관 동의는 필수만).
- ui 원고(#128): `docs/identity/writing/generated/arb/app_{ko,en,ja}.arb`(writing이 생성, 직접 고치지 않음). 키 = IA 슬롯 id lowerCamelCase(#90). 한 자리에 문구가 여럿이면 대문자로 시작하는 상태 이름 접미사(예 `diaryEditDraftStatusSaving`). `@키` 메타데이터는 ko에만. 파일 머리에 `@@x-generated`. placeholder `text`→String, `number`→int. ICU plural·select 없음. en에 아포스트로피(`can't`) 있음.

**Steps**
- [ ] **Step 1:** `git merge --no-ff origin/writing/ia-v2-consent`(충돌이 나면 app/ 쪽은 이 브랜치 기준으로 해결하고 report에). `dart run tool/gen_ia.dart`로 IA 생성 코드를 다시 만들고 컴파일 오류·실패 테스트를 report에 적습니다. `consent.optional.label`(ARB `consentOptionalLabel` 포함)을 쓰는 곳을 지웁니다.
- [ ] **Step 2: ARB 가져오기 방식.** writing 생성 ARB를 app ARB(`app/lib/core/l10n/arb/app_{ko,en,ja}.arb`)에 합치는 도구를 둡니다: `tool/import_writing_arb.dart`(또는 같은 일을 하는 스크립트). 규칙:
  * writing 파일에 있는 키 → 그 값으로 바꾸고, ko의 `@키` 메타데이터도 writing 것으로(“임시” 표시는 사라짐). en·ja에 없는 키는 app이 ko 문구로 채웁니다(gen-l10n 경고 없게).
  * app에만 있는 키(오류 문구 `error*`, 슬롯 밖 문구 `dayKind*`·`branch*`·`consentDocument*` 등, 아직 원고가 없는 슬롯) → 그대로 두고 임시 표시 유지.
  * `@@x-generated` 같은 전역 속성은 gen-l10n이 받는지 확인하고, 거부하면 가져올 때 빼고 report에(writing에 알릴 거리).
  * 같은 입력으로 두 번 돌려도 결과가 같아야 합니다(멱등). 테스트: 도구 단위 테스트(작은 가짜 입력으로 위 규칙 각각).
  * 그다음 실제로 가져오고 `flutter gen-l10n`, `mlw check-arb`(app/README.md 명령).
- [ ] **Step 3: 키 이름 맞추기.** 이 계획에서 임시로 만든 슬롯 키가 writing 키와 다르면(상태 접미사 등) 코드가 writing 키를 쓰게 바꾸고, 쓰지 않게 된 임시 키는 지웁니다. 특히 `notifyAskCtaAllow`(IA 슬롯이 없던 허락 버튼), `onboardCallInputLabel`, 동의 줄 라벨, 저장 실패 안내 등 이 계획에서 만든 키를 writing 원고와 대조해 report에 표로 적습니다(유지·교체·삭제).
- [ ] **Step 4: 문구가 바뀐 화면 확인.** 원고 문구가 길어져 레이아웃이 깨지지 않는지 기존 레이아웃 테스트(`test/features/onboarding/onboarding_layout_test.dart` 등)와 흐름 테스트를 돌립니다. 흐름 테스트가 임시 한국어 문구를 직접 찾고 있었다면 IA id(Key)나 l10n 값으로 찾게 바꿉니다(문구에 기대지 않게). `profileEditRecalcConfirmBody` 등 이 계획 밖 화면 문구는 키만 들어오고 쓰이지 않아도 됩니다.
- [ ] **Step 5:** 전체 검사: `flutter analyze`(app·widgetbook) 0, `flutter test --exclude-tags golden` 전체, IA·컴포넌트 대조, fixture 검증, 커버리지 `--check`, `mlw check-arb`, 생성 코드 차이 0. golden은 macOS에서 돌리지 말고 생략(controller가 Linux로 확인).
- [ ] **Step 6:** `app/README.md`에 ARB 가져오기 절차(원고가 바뀌면 도구를 다시 돌림)를 짧게, `app/CLAUDE.md` 계약 표의 IA를 v2로, "받은 요청"에 #128·#135 반영을 적습니다. plan(`app/docs/plans/2026-10-14-onboarding-login.md`) 끝에 이 Task 20 원문을 덧붙입니다.
- [ ] **Step 7:** Commit — 병합 commit과 반영 commit을 나눕니다(`feat(app): ui 원고 가져오기와 IA v2 반영(#128·#135)`).

# app staging 배포 준비 Implementation Plan (계획 7 A2 다음 묶음)

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** server staging이 준비되면 Android release 빌드를 Play 내부 테스트 트랙에 올려 테스터가 쓸 수 있게, 앱 쪽 남은 일(release 서명, http 모드에 남은 대역)을 끝냅니다.

**Architecture:** 실제 SDK는 지금까지처럼 작은 경계 interface 뒤에 두고 분기는 adapter에서 테스트합니다(spec `2026-10-21-real-login-design.md` §3). 끼우는 곳은 `realPlatformOverrides(ApiMode.http)` 하나이고, fake 모드는 대역 그대로입니다. Firebase 초기화(A93)가 실패해도 앱은 뜨므로, Firebase를 쓰는 adapter는 초기화되지 않은 상태에서도 앱을 죽이지 않습니다.

**Tech Stack:** Flutter 3.47.7, Riverpod 3.x, `firebase_core` 4.15.2(5.1.0에서 낮춤, A96), `firebase_app_check` 0.4.9, `firebase_crashlytics` 5.4.1, `firebase_messaging` 16.7.1, `flutter_local_notifications` 22.3.3, `share_plus`(최신 안정판, Task 6에서 고정).

**Spec:** 별도 spec 없음. 근거는 결정과 계약입니다: app A81·A84·A92·A93, D62(아침 알림), D64(크래시 기록에 개인정보 금지), S92·#347 ②(알림 기기 호출 시점), #603(FCM 메시지 형식, app 답), #614·W46(채널 이름 `systemPushChannelMorning`), REST `registerDevice`·`deleteDevice`, `docs/external-prep.md` E3·E5·E8.

## Global Constraints

* 경고 0, 생성 코드 손대지 않음, `const new` 생성자 문법, 테스트는 TDD.
* SDK 경계 구현은 SDK 호출을 그대로 옮기기만 하고 분기가 없습니다. 분기는 adapter에 두고 테스트합니다.
* 크래시 기록과 breadcrumb에는 `CrashSummary`(오류 타입·code)와 `sanitizeAccountId`·`sanitizeScreenId`를 거친 값만 싣습니다. 원문 메시지, 일기 본문, 출생 정보, 호칭, 토큰, nonce는 싣지 않습니다(D64).
* fake 모드(`ApiMode.fake`)는 대역 그대로입니다. http 모드에서 대역이 남으면 안 되는 것은 결제(가짜 성공)와 App Check(가짜 토큰)입니다.
* 비밀 값과 로컬 설정 파일은 저장소 밖 보관 폴더 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/<환경>/`에 둡니다(D98, `docs/local-values.md`). 이 plan에서 `$D`로 씁니다. 스크립트는 파일을 경로로만 다루고 내용을 출력하지 않습니다.
* 사용자에게 보이는 글자는 ARB 원고 키만 씁니다. 새 문구가 필요하면 A7 임시 키와 writing Issue입니다.

## 확인한 사실 (2026-10-30, 출처와 함께)

plan의 외부 상태 가정은 이 표에 출처와 함께 적은 것만 씁니다. 표에 없는 가정이 task에 필요하면 착수 전에 출처(Issue, 대장, 계약, 코드)로 확인해 이 표에 더한 뒤 진행합니다. 2026-10-29 실행에서 App Attest(확인 안 하고 적음)와 테스트 경로가 틀렸던 데서 나왔습니다.

| 사실 | 출처 |
| --- | --- |
| iOS App Check는 DeviceCheck만 두 프로젝트에 등록. App Attest는 결정된 적 없음 | #605 닫는 코멘트, `Runner.entitlements` |
| Android Play Integrity는 prod에만 연결, staging Android는 토큰을 못 받는 것이 정상 | #657, #656, 대장 E5 |
| staging debug token은 콘솔 두 앱에 등록, 보관 `$D/app/staging/dart-defines.json` | #659, `docs/local-values.md` K4 |
| Firebase 네이티브 설정 파일은 빌드가 읽지 않음(Dart 설정으로 초기화) | A93, K5 |
| `CrashSummary`에는 `toString`이 없음 | `lib/core/platform/crash_reporter.dart` |
| FCM 메시지: 제목 없음, `data.kind`(`morning`, 열린 값), `data.date`, Android 채널 `morning`. tag·collapse-id `morning`은 app이 제안했고 server 답은 아직 없음(앱 코드 영향 없음) | #603 app 답 |
| 기기 호출: 실행 때와 토큰이 바뀔 때 `registerDevice`, 바뀌면 새 등록 뒤 이전 id `deleteDevice`, 로그아웃 전 `deleteDevice`(동의 전에도 가능), 404 `device.not_found`, 계정 삭제는 부르지 않음 | `server/api/openapi.yaml` deleteDevice·registerDevice, #347 ② |
| 기기 id 저장 키 `registeredDeviceIdKey`(`push.deviceId`). `DeviceRepository.register`는 성공하면 새 id로 덮어씀. 처음 등록은 notify-ask(새 프로필을 만들 때만)와 설정(꺼짐에서 켤 때, 저장된 id가 없을 때만) | `device_flags.dart:7-25`, `device_repository.dart:40`, `settings_controller.dart:62,131`, `notify_ask_controller.dart` |
| 프로필 알림 설정은 `Profile.notification.status`(`NotificationSettingStatusEnum`). `Me`에는 알림 상태가 없음. 프로필 사본은 로그아웃 정리(`clearSignedOutData`)로 지워지고, 사본이 없을 때 server에서 받는 것은 설정과 정보 수정 화면(`profileProvider`)뿐 | `notification_setting.dart`, `me.dart`, `profile_providers.dart`, `app_database.dart` |
| server는 알림 시각 설정이 있는 대상에게만 보냄(설정에서 알림을 꺼도 기기 등록은 남는 지금 구조의 전제) | server 결정 S13 |
| fake server는 fixture가 없는 operation에 501 `not_implemented`(ProblemError, AppError라 보고 안 함). `deleteDevice` fixture는 없음, `registerDevice`는 `new-user`, `notify-register-unavailable`에만. 204 fixture는 `{"status": 204}` | `fake_server.dart:95-110`, `fixtures/` |
| `revokeAndSignOut({api, tokens})`는 Ref 없는 최상위 함수, 호출부 `settings_controller.dart:83`, 테스트 `test/app/sign_out_test.dart`, `test/flows/sign_out_flow_test.dart`, `test/flows/settings_flow_test.dart` | 코드 |
| 광고 제거 화면은 상품이 비면 `UnexpectedError`로 오류 상태(다시 시도)를 그림. 보상형은 `loadRewarded`가 null이면 `lockedNoAd` | `ad_free_controller.dart:23-25`, `ad_free_screen.dart:96-102`, `evidence_unlock_controller.dart:419-433` |
| `adsProvider`는 `realPlatformOverrides`가 아니라 provider 안에서 모드로 분기(http는 지금 `FakeAds`) | `platform_providers.dart:62-67` |
| `AppLifecycleHooks.initState`가 `push.opens.listen`을 try 없이 부름 | `myungli_app.dart:83-84` |
| 앱은 iPad를 지원(`TARGETED_DEVICE_FAMILY = "1,2"`) | `ios/Runner.xcodeproj/project.pbxproj` |
| `share_plus` 13.3.1은 iPad에서 `sharePositionOrigin`이 없으면 화면 가운데에 띄움(죽지 않음, 예전 버전만 문제). `ShareSheet`는 그대로 둠 | share_plus 13.3.1 README "iPad"(Task 6 Step 0) |
| `tool/patrol_local.sh`는 늘 `API_MODE=fake`라 Patrol은 실제 adapter를 거치지 않음 | `patrol_local.sh:166` |
| iOS `Runner.entitlements`에 `aps-environment` 없음 | 파일 |
| RevenueCat 공개 SDK 키, 상품 id는 아직 없음(상품은 E15 뒤) | #632, 대장 E12 |
| AdMob은 계정 검증 끝, 앱 등록 전(광고 단위 id 없음) | 대장 E13(origin/main), #539 2026-10-29 |
| 패키지: `firebase_crashlytics` 6.0.1, `firebase_messaging` 17.0.1(둘 다 `firebase_core` ^5.1.0), `flutter_local_notifications` 22.3.3, `share_plus` 13.3.1 | pub.dev |
| `firebase_core` 5.x(iOS SDK 13.x, gtm 4 이상)와 `google_sign_in_ios` 6.3.8(GoogleSignIn 9.x, gtm 3.x)은 iOS SPM에서 함께 풀리지 않음. #630 병합 뒤 main iOS 빌드가 깨져 있었음. `firebase_core` 4.15.2(iOS SDK 12.19.3, gtm 3.4.1..<6)와 그 줄의 App Check 0.4.9(`debugToken` 있음), Crashlytics 5.4.1, Messaging 16.7.1로 낮추면 iOS, Android 모두 빌드됨 | 2026-10-30 `flutter build ios` 출력, firebase-ios-sdk Package.swift 12.x·13.0.0, `google_sign_in_ios` Package.swift |
| `flutter_local_notifications`는 Android core library desugaring을 요구 | 2026-10-30 `checkDebugAarMetadata` 오류 |
| 앱이 꺼진 상태(force-stop 아님)에서 FCM 알림은 채널 `morning`, tag `morning`으로 표시되고 누르면 앱이 오늘 화면으로 열림. 네이티브 기본 FirebaseApp은 초기화되지 않아(A93) 전달 통계(GA, BigQuery)만 빠짐 | 2026-10-30 에뮬레이터, FCM v1 전송(Task 4 Step 0) |
| 채널 `morning`은 앱 언어 이름(ko)과 중요도 3(default)으로 만들어짐 | 2026-10-30 `dumpsys notification` |
| Crashlytics Android SDK 21.0.1은 Gradle plugin 없이 Dart 초기화 뒤 build ID 오류 없이 초기화되고 설정을 받아 옴. 기록은 다음 실행 때 DataTransport로 전송됨(`successfully enqueued`, Task 3 Step 4) | 2026-10-30 에뮬레이터 logcat(Task 3 Step 0, 4) |
| Crashlytics Android 공식 설정은 `com.google.firebase.crashlytics` Gradle plugin과 `google-services` plugin을 씀. 이 앱은 둘 다 없음(A93) | Firebase 문서 crashlytics/android/get-started, `android/app/build.gradle.kts` |

## Review Focus

1. Firebase 초기화가 실패한 채 App Check 토큰, Crashlytics 기록, FCM 토큰을 부르면: 앱이 죽지 않고 App Check는 토큰 없음(헤더 없이 보냄, #657), Crashlytics는 조용히 버림, FCM은 토큰 없음(null)으로 끝나야 합니다.
2. 로그아웃 상태나 약관 동의 전에 FCM 토큰이 바뀌면: `registerDevice`를 부르지 않고(401·403을 만들지 않음) 다음 로그인 뒤 실행 때 등록합니다. 알림을 켠 계정이 로그아웃 뒤 다시 로그인해도 다음 실행 때 다시 등록되어 아침 알림이 끊기지 않아야 합니다.
3. 로그아웃 때 `deleteDevice`가 오프라인 등으로 실패하면: 로그아웃은 계속하고 저장된 기기 id는 지웁니다(로그아웃을 막지 않음). AppError(오프라인, 404 `device.not_found`, fake 501)는 보고하지 않고 예상 밖 오류만 요약 보고합니다. 401·refresh 거부로 강제 로그아웃되면 `deleteDevice`를 부를 수 없어 기기가 server에 활성으로 남습니다. 이 기기 토큰으로 다음 계정이 등록하면 server가 그 계정으로 옮깁니다(`registerDevice` 설명). 남는 경우는 알려진 한계로 둡니다.
4. 알림 `data.kind`가 `morning`이 아니거나 `data`가 비어 있으면: 앱만 열고 화면 이동은 하지 않습니다.
5. 앱 언어를 바꾸면: Android 채널 이름이 새 언어로 바뀝니다(같은 id로 다시 만들면 이름만 갱신됨).

---

## Task 1: Android release 서명

**Files:**
- Modify: `app/android/app/build.gradle.kts`(release `signingConfig`)
- Modify: `app/README.md`("staging 빌드" 절: 키스토어 만들기, `key.properties`, 빌드 명령)
- Modify: `app/docs/decisions.md`(A94)

**Interfaces:**
- Produces: `$D/app/shared/key.properties`(대장 K1, 키 `storeFile`·`storePassword`·`keyAlias`·`keyPassword`, `storeFile`은 `key.properties` 기준 상대 경로, 기본 `upload-keystore.jks`) 형식. 파일이 있으면 release는 그 업로드 키로 서명하고, 없으면 지금처럼 debug 키로 서명하며 Gradle 경고를 한 줄 냅니다(CI는 release를 만들지 않음).

- [ ] **Step 1:** `build.gradle.kts`에 `signingConfigs.create("upload")`를 두고 `System.getenv("MYUNGLI_LOCAL_DIR")`(없으면 `${user.home}/.config/myungli`) 아래 `app/shared/key.properties`를 `java.util.Properties`로 읽어 채웁니다. 저장소 안 경로나 절대 경로를 박지 않습니다. release는 파일이 있으면 `upload`, 없으면 `debug`.
- [ ] **Step 2: 확인(키 없음):** `flutter build apk --debug --dart-define-from-file=config/auth.json` 성공(debug 빌드는 영향 없음).
- [ ] **Step 3: 확인(키 있음):** `keytool -genkeypair -v -keystore $D/app/shared/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`로 만든 키로 `flutter build appbundle --release --dart-define-from-file=config/auth.json --dart-define=API_BASE_URL=https://example.invalid --dart-define=FIREBASE_ENV=staging` 성공, `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`의 소유자가 업로드 키입니다. (키 비밀번호는 사용자가 정합니다. 두 파일은 L1이라 기기 밖 백업이 필수이고, PR 본문에서 사용자에게 백업을 안내합니다. 업로드 키를 잃으면 Play에 재설정을 요청해야 합니다. 파일 권한 600.)
- [ ] **Step 4: README·A94:** staging 빌드 명령(`flutter build appbundle --release --dart-define-from-file=config/auth.json --dart-define=API_BASE_URL=<staging API> --dart-define=FIREBASE_ENV=staging --dart-define=AD_FREE_PRODUCT_IDS=<id>`)과 키 위치. A94는 "업로드 키는 보관 폴더 `app/shared/`(K1), 없으면 debug 서명, 앱 서명 키는 Play(E8)". `docs/local-values.md` K1 상태를 `사용 중`으로 고칩니다.
- [ ] **Step 5: Commit** `build(app): Android release 업로드 키 서명 (A94)`

## Task 2: App Check 실제 adapter (#657, #659)

**Files:**
- Create: `app/lib/core/platform/firebase_app_check.dart`
- Modify: `app/lib/core/api/interceptors/common_headers.dart`(토큰이 없으면 헤더 없이 보냄), `app/lib/app/bootstrap.dart`(`realPlatformOverrides(http)`에 `appCheckProvider`), `app/lib/app/firebase_setup.dart`(초기화 성공 뒤 App Check 활성화), `app/tool/patrol_local.sh`(로컬 토큰 파일이 있으면 `--dart-define-from-file`로 넘김), `app/README.md`(debug token 절차)
- Test: `app/test/core/firebase_app_check_test.dart`, `app/test/core/api/common_headers_test.dart`(추가), `app/test/app/firebase_setup_test.dart`(추가)

**Interfaces:**
- Consumes: `initializeFirebase`, `firebaseEnvFromEnvironment`(A93), `AppCheck`(`lib/core/platform/app_check.dart`)
- Produces:
  - `AppCheckTokenSource.token()`의 반환을 `Future<String?>`으로 바꿉니다. null이면 헤더를 붙이지 않습니다(#657).
  - `enum AppCheckMode { debug, attest }`, `AppCheckMode appCheckModeFor({required FirebaseEnv env, bool isDebug = kDebugMode})`: debug 빌드이고 staging일 때만 `debug`(S24).
  - `abstract interface class AppCheckApi { Future<void> activate({required AppCheckMode mode, String? debugToken}); Future<String?> getToken(); }`, 기본 구현 `SdkAppCheckApi`(`debug`면 `AndroidDebugProvider(debugToken:)`, `AppleDebugProvider(debugToken:)`, `attest`면 `AndroidPlayIntegrityProvider`, `AppleAppAttestWithDeviceCheckFallbackProvider`)
  - `final class FirebaseAppCheckAdapter implements AppCheck { const new({AppCheckApi api = const SdkAppCheckApi(), Duration timeout = const Duration(seconds: 3)}); }`: 시간 안에 못 받거나 SDK가 던지면 null.
  - 토큰 값은 `const String.fromEnvironment('APP_CHECK_DEBUG_TOKEN')`(빈 값이면 null, SDK가 첫 실행 토큰을 찍음). 로컬은 `$D/app/staging/dart-defines.json`(K4)을 `--dart-define-from-file`로 넘기고, CI는 GitHub Secret `APP_CHECK_DEBUG_TOKEN`(E2E를 staging에 붙일 때 만들고 K4 행에 적음).
  - `initializeFirebase`가 성공하면 `activate`까지 하고, 활성화 실패도 같은 실패 기록으로 돌려줍니다.

- [ ] **Step 1: 실패하는 테스트:** `토큰이 있으면 그 토큰`, `토큰이 null이면 null`, `SDK가 던지면 null`, `timeout을 넘기면 null`, `interceptor는 토큰이 null이면 X-Firebase-AppCheck 없이 보냄`(거절하지 않음), `appCheckModeFor: debug+staging만 debug, release staging과 prod는 attest, debug prod도 attest`, `Firebase 초기화 뒤 activate를 한 번`, `activate 실패는 failure로 돌려주고 던지지 않음`.
- [ ] **Step 2:** `flutter test test/core/firebase_app_check_test.dart test/core/api/common_headers_test.dart test/app/firebase_setup_test.dart` FAIL.
- [ ] **Step 3: 구현.** 패키지 `firebase_app_check: 0.5.1`.
- [ ] **Step 4:** 같은 명령 PASS. 에뮬레이터 debug 빌드(로컬 server)에서 사용자가 등록한 고정 토큰으로 토큰을 받는지 확인합니다(#659 사용자 할 일).
- [ ] **Step 5: Commit** `feat(app): App Check 실제 adapter, 고정 debug token, 실패해도 헤더 없이 보냄 (#657, #659)`

## Task 3: Crashlytics 실제 adapter

**Files:**
- Create: `app/lib/core/platform/firebase_crash_reporter.dart`
- Modify: `app/lib/app/bootstrap.dart`(`crashReporterProvider` override), `app/lib/app/firebase_setup.dart`(수집 켜기: `!kDebugMode`)
- Modify: `app/lib/core/platform/crash_reporter.dart`(`CrashSummary.toString()` 추가: `CrashSummary(errorType: X, code: Y, status: Z)`처럼 세 값만, 없는 값은 뺌)
- Test: `app/test/core/firebase_crash_reporter_test.dart`

**Interfaces:**
- Consumes: `CrashReporter`·`CrashSummary`·`sanitizeAccountId`·`sanitizeScreenId`(기존)
- Produces:
  - `abstract interface class CrashlyticsApi { Future<void> recordError(Object exception, StackTrace stack); Future<void> setUserIdentifier(String id); Future<void> log(String message); Future<void> setCollectionEnabled(bool enabled); }`, 기본 구현 `SdkCrashlyticsApi`
  - `final class FirebaseCrashReporter implements CrashReporter { const new({CrashlyticsApi api = const SdkCrashlyticsApi()}); }`

- [ ] **Step 0: 착수 전 확인(Android build ID).** 패키지를 넣고 http debug 빌드를 에뮬레이터에서 띄워 logcat에서 Crashlytics 초기화 오류(build ID 없음 등)를 봅니다. 오류가 없고 `FirebaseCrashlytics.instance.recordError`가 동작하면(이 확인 때만 debug에서 수집을 켜고 콘솔 staging Crashlytics에 기록이 오는지 봄) Gradle plugin 없이 갑니다. 오류가 나면 `com.google.firebase.crashlytics` plugin만 적용해(매핑 업로드 끔) build ID를 넣는 방법을 확인하고, 그것도 `google-services` plugin이나 네이티브 설정 파일을 요구하면 A93과 부딪히므로 멈추고 사용자에게 선택지를 묻습니다. 결과를 이 plan "확인한 사실"에 더합니다.
- [ ] **Step 1: 실패하는 테스트:** `CrashSummary.toString은 타입, code, status만`, `record는 원문 오류가 아니라 CrashSummary만 싣습니다`(recordError에 넘긴 exception이 그 `CrashSummary`이고, 문자열에 원문 메시지가 없음), `setUser(null)은 빈 id`, `setUser는 sanitizeAccountId를 거친 값`, `breadcrumb은 sanitizeScreenId가 null이면 싣지 않음`, `SDK가 던져도(비동기 실패와 `FirebaseCrashlytics.instance`의 동기 예외 모두) record·setUser·breadcrumb은 던지지 않음`(Review Focus 1).
- [ ] **Step 2:** FAIL 확인.
- [ ] **Step 3: 구현.** 패키지 `firebase_crashlytics: 6.0.1`. SDK 호출은 기다리지 않고(`unawaited`) 오류는 삼킵니다.
- [ ] **Step 4:** PASS. 디버그 빌드는 수집을 끕니다(`setCollectionEnabled(false)`).
- [ ] **Step 5: Commit** `feat(app): Crashlytics 실제 adapter, 요약만 기록 (D64)`

## Task 4: FCM 실제 adapter와 알림 채널

**Files:**
- Create: `app/lib/core/platform/firebase_push.dart`, `app/lib/core/platform/push_channel.dart`
- Modify: `app/lib/core/platform/platform_providers.dart`(`notificationChannelsProvider`, 기본 대역), `app/lib/core/platform/fakes.dart`(`FakeNotificationChannels`), `app/lib/app/bootstrap.dart`(`pushMessagingProvider`, `notificationChannelsProvider` http override), `app/lib/app/myungli_app.dart`(앱 언어가 정해지거나 바뀔 때 채널 만들기), `app/ios/Runner/Runner.entitlements`(`aps-environment` `development`, release 서명 때 Xcode가 production으로 바꿈), `app/android/app/build.gradle.kts`(빌드가 요구하면 core library desugaring)
- Test: `app/test/core/firebase_push_test.dart`, `app/test/core/push_channel_test.dart`, `app/test/app/lifecycle_hooks_test.dart`(채널 언어), `app/test/app/auth_sdk_setup_test.dart`(override)

**Interfaces:**
- Consumes: `PushMessaging`·`PushOpen`(기존), ARB `systemPushChannelMorning`(W46)
- Produces:
  - `abstract interface class MessagingApi { Future<bool> requestPermission(); Future<String?> getToken(); Stream<String> get onTokenRefresh; Stream<Map<String, Object?>> get onMessageOpenedApp; Future<Map<String, Object?>?> getInitialMessageData(); }`, 기본 구현 `SdkMessagingApi`
  - `final class FirebasePushMessaging implements PushMessaging { const new({MessagingApi api = const SdkMessagingApi()}); }`
  - `PushOpen? pushOpenFromData(Map<String, Object?> data)`: `data['kind'] == 'morning'`이면 `PushOpen.tryCreate(ScreenIds.today)`, 아니면 null
  - `const String morningChannelId = 'morning'`, `abstract interface class NotificationChannels { Future<void> ensureMorning(String name); }`, 실제 구현 `LocalNotificationChannels`(`flutter_local_notifications`의 `AndroidNotificationChannel(morningChannelId, name, importance: Importance.defaultImportance)`, iOS는 아무것도 안 함, 실패는 삼킴)
  - `final notificationChannelsProvider = Provider<NotificationChannels>((ref) => FakeNotificationChannels())`(기본 대역, 받은 이름을 기록), http 모드만 `LocalNotificationChannels`로 override. fake 모드와 위젯 테스트가 플러그인을 부르지 않게 합니다.
  - `FirebasePushMessaging`은 SDK 호출 전체를 try로 감쌉니다. `FirebaseMessaging.instance`가 Firebase 초기화 실패로 동기로 던져도 `token()`은 null, `opens`·`tokenRefreshes`는 빈 스트림, `initialOpen()`은 null, `requestPermission()`은 false입니다.

- [ ] **Step 0: 착수 전 확인(앱이 꺼진 상태의 Android 수신).** 이 앱은 `google-services` plugin 없이 Dart에서 초기화합니다(A93). 패키지를 넣은 http debug 빌드로 알림을 켠 뒤 앱을 완전히 끄고, Firebase 콘솔 staging 메시지 보내기(테스트 기기 토큰, 채널 `morning`, `data.kind=morning`)로 보내 표시, 누름 진입, logcat의 Firebase 초기화 오류를 봅니다. 토큰은 앱 로그에 찍지 말고 테스트 코드나 디버거로만 꺼냅니다. 표시되지 않거나 기본 앱 없음 오류가 나면 멈추고 선택지를 묻습니다. 결과를 "확인한 사실"에 더합니다.
- [ ] **Step 1: 실패하는 테스트:** `kind morning → today`, `모르는 kind·빈 data → null`(Review Focus 4), `getToken이 던지면 null`(Review Focus 1), `SDK getter가 동기로 던져도 opens·tokenRefreshes는 빈 스트림, initialOpen은 null`, `opens는 morning만 흘림`, `initialOpen은 처음 메시지의 data로`, 채널: `ensureMorning은 id morning과 받은 이름`, `언어가 바뀌면 새 이름으로 다시`(Review Focus 5, `myungli_app` 위젯 테스트에서 대역 `NotificationChannels`로).
- [ ] **Step 2:** FAIL 확인.
- [ ] **Step 3: 구현.** 패키지 `firebase_messaging: 17.0.1`, `flutter_local_notifications: 22.3.3`. Android 13 알림 권한은 기존 `requestPermission` 흐름(notify-ask)이 맡습니다.
- [ ] **Step 4:** PASS. 디버그 APK 빌드 성공(desugaring 요구 오류가 나면 `isCoreLibraryDesugaringEnabled = true`와 `coreLibraryDesugaring` 의존성을 더함), `flutter build ios --debug --no-codesign` 성공.
- [ ] **Step 5: Commit** `feat(app): FCM 실제 adapter와 아침 알림 채널 (#603, W46)`

## Task 5: 알림 기기 등록 시점과 로그아웃 해제 (#347 ②)

**Files:**
- Modify: `app/lib/features/onboarding/data/device_repository.dart`(`delete`)
- Create: `app/lib/app/entry/device_registrar.dart`
- Modify: `app/lib/app/entry/sign_out.dart`(`revokeAndSignOut`가 토큰 폐기 전에 해제), `app/lib/app/entry/sign_out_cleaner.dart`(남은 기기 id 지우기, 기존 "계획 7에서 연결" 주석 정리), `app/lib/features/me/application/settings_controller.dart`(`revokeAndSignOut` 호출부), `app/lib/app/myungli_app.dart`(진입이 `ready`가 되면 `onLaunch`, 토큰 변경 구독)
- Create: `app/fixtures/new-user/deleteDevice.json`, `app/fixtures/notify-register-unavailable/deleteDevice.json`(`{"status": 204}`)
- Test: `app/test/app/device_registrar_test.dart`, `app/test/app/sign_out_test.dart`(추가), `app/test/flows/sign_out_flow_test.dart`, `app/test/flows/settings_flow_test.dart`, `app/test/flows/notify_ask_flow_test.dart`(회귀)

**Interfaces:**
- Consumes: `DeviceRepository.register`(기존, 성공하면 새 id로 저장 키를 덮어씀), `PushMessaging.token`·`tokenRefreshes`, `registeredDeviceIdKey`, 프로필 `notification.status`, 진입 상태
- Produces:
  - `DeviceRepository.delete(String deviceId) → Future<void>`: server 해제만 합니다. 저장 키는 건드리지 않습니다(새 등록이 이미 새 id로 덮어썼을 수 있음). 404 `device.not_found`는 성공으로 봅니다.
  - `final class DeviceRegistrar { new(Ref ref); Future<void> sync(); Future<void> releaseForSignOut(); }`, `final deviceRegistrarProvider = Provider<DeviceRegistrar>(...)`.
    - `sync()`: 로그인, 약관 동의(진입 `ready`), OS 알림 권한 허락(`PushMessaging.hasPermission`, 최종 review 뒤 바꿈: 프로필 사본은 로그아웃 정리로 지워져 다시 로그인한 계정을 놓치고, 사본을 받으면 앱 전체 상태가 바뀜. 발송은 server가 프로필 설정으로 거름, S13)이고 토큰이 있을 때만 지금 토큰을 `register`합니다. 돌려받은 id가 등록 전 저장된 id와 다르고 이전 id가 있었으면 이전 id를 `delete`합니다(앱이 꺼진 사이 토큰이 바뀐 경우 포함). 실행 때(진입이 `ready`가 된 뒤 한 번)와 `tokenRefreshes`마다 부르고, 동시에 두 번 돌지 않게 앞 호출이 끝난 뒤 이어서 돕니다. 실패는 `recordUnlessAppError`로 처리하고 던지지 않습니다.
    - `releaseForSignOut()`: 저장된 id가 있으면 `delete`하고, 성공 여부와 상관없이 저장 키를 지웁니다. 실패는 `recordUnlessAppError`, 던지지 않습니다.
  - `revokeAndSignOut({required DefaultApi api, required TokenStore tokens, required Future<void> Function() releaseDevice})`: server 로그아웃 요청 **전에** `releaseDevice()`를 부릅니다(계약: "로그아웃하기 전에 `deleteDevice`"). 계정 삭제는 부르지 않습니다(server가 기기를 비활성으로 바꿈). 강제 로그아웃(`TokenStore.signOut` 직접)은 해제 없이 `SignOutCleaner`가 저장 키만 지웁니다(Review Focus 3).

- [ ] **Step 1: 실패하는 테스트:** `알림이 꺼져 있으면 실행 때 등록하지 않음`, `로그인·동의·알림 켬이면 실행 때 등록`, `로그아웃 뒤 다시 로그인하면 다음 실행 때 다시 등록`(Review Focus 2), `로그아웃·동의 전이면 토큰이 바뀌어도 등록하지 않음`(Review Focus 2), `토큰이 바뀌면 새 토큰 등록 뒤 이전 id 해제, 저장된 id는 새 id`, `앱이 꺼진 사이 토큰이 바뀌었으면 실행 때 새 id를 받고 이전 id 해제`, `실행 등록과 토큰 변경이 겹쳐도 차례로 한 번씩`, `로그아웃은 해제를 먼저 부르고 그다음 토큰 폐기`, `해제가 실패해도 로그아웃되고 기기 id는 지워짐, AppError는 보고 안 함, 예상 밖 오류만 요약 보고`, `404는 보고하지 않음`, `계정 삭제는 해제를 부르지 않음`, `강제 로그아웃은 저장 키만 지움`.
- [ ] **Step 2:** FAIL 확인.
- [ ] **Step 3: 구현.**
- [ ] **Step 4:** `flutter test test/app test/flows test/features/me test/features/profile test/features/onboarding` PASS. 로컬 server에서 `POST /v1/devices`·`DELETE /v1/devices/{id}` 로그 확인(server가 501이면 그 사실만 기록).
- [ ] **Step 5:** #347에 반영 코멘트만 남깁니다(닫기는 PR의 `Closes #347`). **Commit** `feat(app): 알림 기기 등록 시점과 로그아웃 전 해제 (#347 ②)`

## Task 6: http 모드에 남은 대역 정리

**Files:**
- Create: `app/lib/core/platform/unavailable_store.dart`(결제·광고·광고 동의의 "아직 없음" 구현), `app/lib/core/platform/os_share.dart`
- Modify: `app/lib/core/platform/platform_providers.dart`(`adsProvider`의 fake 아닌 분기를 `NoAds`로, 이 분기는 provider 안에 둠), `app/lib/app/bootstrap.dart`(`purchasesProvider`, `adConsentProvider`, `shareSheetProvider` http override)
- Test: `app/test/core/unavailable_store_test.dart`, `app/test/core/os_share_test.dart`, `app/test/app/auth_sdk_setup_test.dart`(override 목록 추가)

**Interfaces:**
- Produces:
  - `final class UnavailablePurchases implements Purchases`: `products()`는 빈 목록, `buy()`는 `PurchaseFailed(UnexpectedError(StateError('결제를 아직 쓸 수 없습니다')))`(화면은 기존 구매 실패 안내), `sync`·`logIn`·`logOut`은 아무것도 안 함. 가짜 성공을 만들지 않습니다.
  - `final class NoAds implements Ads`: `loadBanner`·`loadRewarded`는 null(배너 없음, 보상형 버튼 꺼짐).
  - `final class NonPersonalizedAdConsent implements AdConsent`: `gather()`는 `AdConsentResult.nonPersonalized`.
  - `final class OsShareSheet implements ShareSheet`(`share_plus`, 경계 `typedef ShareFiles = Future<void> Function(List<XFile> files, {String? text})`).
  - RevenueCat·AdMob 실제 adapter가 오면(E12·E13) 이 셋을 바꿉니다.

- [ ] **Step 0: 착수 전 확인.** `share_plus` 13.3.1 README와 소스에서 iPad의 `sharePositionOrigin` 요구를 봅니다. 없으면 실패하거나 죽는다면 `ShareSheet.sharePng`에 기준 위치 인자를 더하는 쪽으로 이 task를 넓히고 "확인한 사실"에 더합니다.
- [ ] **Step 1: 실패하는 테스트:** `UnavailablePurchases.buy는 PurchaseFailed(UnexpectedError)`, `products는 빈 목록`, `NoAds는 null`, `동의는 nonPersonalized`, `OsShareSheet는 PNG 파일 하나와 문구를 넘김`, `http 모드 adsProvider는 NoAds, fake는 시나리오 대역`, `realPlatformOverrides(http)는 결제, 광고 동의, 공유와 Task 2~4 adapter(App Check, Crashlytics, FCM, 알림 채널)를 끼움, fake는 대역`.
- [ ] **Step 2:** FAIL 확인.
- [ ] **Step 3: 구현.**
- [ ] **Step 4:** PASS. 기존 화면 테스트를 http override로 한 번 돌려 확인합니다: 광고 제거 화면은 상품이 없어 오류 상태(다시 시도, 기존 동작)이고 보고는 남지 않음(`UnexpectedError`는 AppError), 근거 시트 보상형은 `lockedNoAd`. 상품 없음을 따로 안내할지는 RevenueCat 값이 올 때(E12) 정합니다.
- [ ] **Step 5: Commit** `feat(app): http 모드의 결제·광고는 쓸 수 없음, 공유는 OS 공유`

## Task 7: 마무리

- [ ] **Step 1: 전체 검사:** `flutter analyze`(app·widgetbook), `dart analyze`, `dart format --set-exit-if-changed .`, `flutter test --exclude-tags golden`, `dart run tool/ia_coverage.dart --check`, `dart run tool/gen_native_config.dart --check`, `flutter build apk --debug --dart-define-from-file=config/auth.json`, `flutter build ios --debug --no-codesign --dart-define-from-file=config/auth.json`, `tool/patrol_local.sh patrol_test/login_test.dart`.
- [ ] **Step 2: 로컬 server 확인(실제 adapter는 여기서만 거침, Patrol은 fake):** http 모드 debug 빌드로 카카오 로그인 → 오늘 → 설정에서 알림 켜기(`POST /v1/devices`) → 로그아웃(`DELETE /v1/devices/{id}` 뒤 `POST /v1/auth/logout`) 순서를 server 로그로 확인.
- [ ] **Step 3: 문서:** `app/CLAUDE.md` 현재 상태·다음 할 일, README "staging 빌드". PR 본문에 사용자 할 일: 업로드 키 만들기와 기기 밖 백업(README 명령, 만든 뒤 알려 주면 app이 다음 PR에서 `docs/local-values.md` K1 상태를 `사용 중`으로), 2026-10-29에 대화 기록에 남은 staging debug token 교체(D98 §6: 콘솔에서 새로 만들고 옛 토큰 삭제, K4 파일 갱신, 지휘에 `to:root` 알림).
- [ ] **Step 4: Commit·PR** `참고 #311`, `참고 #605`, `Closes #347`, `Closes #603`.

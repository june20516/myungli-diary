# app 실제 로그인·로그인 수단·계정 합치기 Implementation Plan (계획 7 단계 A·B)

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 로그인을 대역에서 실제 제공자 넷(카카오·LINE·Google·Apple)의 adapter로 바꿉니다. 설정이 비어 있으면 "설정 안 됨"으로 실패합니다. 로그인 화면은 네 버튼이고, 맨 위 버튼은 언어마다 다릅니다. 설정 > 로그인 수단(`login-methods`)에서 수단을 붙이고 떼며, 붙이려는 수단이 다른 계정에 있으면 계정 합치기(`account-merge`)로 두 계정을 합칩니다. 연결·합치기는 server 계약 전이라 fake repository로 동작합니다.

**Architecture:**
* `lib/core/platform/`: `AuthConfig`(dart-define 값), 제공자 adapter 다섯(SDK 호출은 생성자로 받는 경계 뒤), `LineAuth`·`GoogleAuth` interface와 대역.
* `lib/features/auth/application/`: `ProviderAuthenticator`가 제공자 하나로 인증해 `ProviderProof`를 돌려줍니다. 로그인(`AuthRepository.login`)과 붙이기(`AccountLinkRepository.link`)가 함께 씁니다. 로그인 뒤 토큰 저장·진입 계산은 `SessionEntry`로 떼어 합치기도 씁니다.
* `lib/features/account/`: `AccountLinkRepository` interface와 fake, `login-methods`·`account-merge` 화면과 controller.
* 새 컴포넌트 `account-choice`(`lib/design/components/input/`). `social-login-button`에 `line`·`google` 변형을 더합니다.

**Tech Stack:** 계획 6과 같음(Flutter 3.47.7, Riverpod 3.x 코드 생성 없음, go_router, Dio 생성 클라이언트). 새 패키지: `kakao_flutter_sdk_user` 2.0.1, `flutter_line_sdk` 2.7.2, `google_sign_in` 7.2.0, `sign_in_with_apple` 8.2.0, `flutter_web_auth_2` 5.1.0(버전은 spec §2와 A70에서 고정).

**Spec:** `app/docs/specs/2026-10-21-real-login-design.md`(§1~§13. 이 plan은 §12의 단계 A·B입니다). 함께 읽을 것: IA `docs/ia/screens.json`(`login`·`settings`·`login-methods`·`account-merge`), 컴포넌트 `docs/identity/design/components/action.json`(`social-login-button`·`settings-row`), 루트 D82·D83, Issue #311·#387.

## 시작 전

* 브랜치 `app/real-login`(만들어 둠). spec commit과 drift #412 commit(`849ebef`, IA D83 생성 코드)이 이미 있습니다. PR 본문에 `Closes #412`를 적습니다.
* 열린 drift가 있으면 첫 commit에서 맞춥니다(`gh issue list --label drift`).
* 검사는 `app/CLAUDE.md` "검사" 절을 따릅니다. 반복 중에는 바꾼 범위만 돌립니다.

## 외부 대기 (이 계획은 기다리지 않고 진행)

| 대기 | 요청 | 기다리는 동안 |
| --- | --- | --- |
| LINE·Google 로그인, 연결·떼기·합치기 API | server #386 | `AuthRepository.login`의 LINE·Google은 `ProviderNotSupportedYet`, 연결·합치기는 `FakeAccountLinkRepository`(두 모드 모두). 단계 C에서 붙입니다 |
| 합치기 요약 값(일기 수·겹침) | server #407 ④ | app 모델 `MergePreview`로 두고 fake가 채웁니다 |
| `social-login-button` LINE·Google 변형, `account-choice` 명세 | design #389 | 브랜드 가이드 기본형의 임시 값과 고를 수 있는 카드 |
| 로그인 수단·계정 합치기 문구 | writing #388 | 임시 ARB(A72) |
| 외부 준비물(카카오 앱, LINE 채널, Google OAuth client, Apple Services ID, 도메인) | 사용자 | `config/auth.json`은 빈 값, adapter는 `ProviderNotConfigured` |

## 이 계획이 정하는 것 (spec 사이 빈칸)

| 빈칸 | 정한 것 |
| --- | --- |
| IA·writing에 아직 없는 문구 | **A72:** app 임시 ARB(A7 방식, `@키.description`에 `임시`). 로그인 `loginLineLabel`·`loginGoogleLabel`. 로그인 수단 화면은 IA 슬롯 키 `loginMethodsBarTitle`·`loginMethodsIntroBody`·`loginMethodsLastNotice`·`loginMethodsUnlinkConfirm`·`loginMethodsErrorBody`와 IA 밖 `loginMethodsUnlinkAction`("떼기")·`socialProviderKakao`·`socialProviderLine`·`socialProviderGoogle`·`socialProviderApple`. 계정 합치기 화면은 IA 슬롯 키 `accountMergeBarTitle`·`accountMergeTitleHead`·`accountMergeTitleBody`·`accountMergeChoiceLabel`·`accountMergeOverlapNotice`·`accountMergeCtaMerge`·`accountMergeCtaCancel`·`accountMergeMergeConfirm`와 IA 밖 `accountMergeExpired`·`accountChoiceCurrent`("지금 계정")·`accountChoiceOther`("다른 계정")·`accountChoiceDiaryCount({count})`·`accountChoiceMovedDiaryCount({count})`(ICU plural). 설정의 "로그인 수단" 줄은 `loginMethodsBarTitle`을 다시 씁니다(A64와 같은 규칙). writing #388에 이 목록을 코멘트로 알립니다 |
| 연결 안 된 줄의 붙이기 버튼 문구 | 붙이기 버튼은 `SocialLoginButton`이고 라벨은 로그인 버튼과 같은 제공자 공식 문구(`loginKakaoLabel` 등)입니다. 제공자 가이드가 정한 문구라 새 키를 만들지 않습니다 |
| 연결된 줄의 모양 | `SettingsRow` `value` 변형: label = 제공자 이름(`socialProvider*`), value = `loginMethodsUnlinkAction`, 누르면 `login-methods.unlink.confirm` dialog. 마지막 하나면 `onTap: null`(꺼짐)이고 그 줄 아래에 `loginMethodsLastNotice` |
| 합치기 표가 만료됨 | app 예외 `MergeTicketExpired`. repository가 던지고, 화면은 `accountMergeExpired` toast 뒤 `login-methods`로 돌아갑니다(spec §9 `error`) |
| `account-merge`에 표 없이 들어옴 | 첫 프레임 뒤 `context.go(pathOf(ScreenIds.loginMethods))`로 대체합니다. 스택이 `settings > login-methods`가 아니어도 같은 화면에 닿습니다 |
| fake 연결 규칙 | `FakeAccountLinkRepository`는 처음에 `[kakao]`(fake 시나리오 회원)입니다. `google`을 붙이면 `LinkConflict`이고, 나머지는 `Linked`입니다. 미리보기는 지금 계정(시나리오 호칭, 일기 3편, `[kakao]`)과 다른 계정(호칭 "다른 계정", 일기 2편, `[google]`), `hasOverlappingDays: true`입니다. 합치기에서 `other`를 고르면 새 `TokenPair`(fake 서버가 받는 회원 토큰)를 돌려줍니다 |

## Global Constraints

* 기반·계획 2~6 plan의 Global Constraints를 모두 따릅니다(경고 0, 생성 코드 손대지 않음, 토큰은 의미 역할로만, 화면 `Semantics.identifier`는 IA id, `const new` 생성자 문법).
* 제공자에게는 언제나 `hashNonce(rawNonce)`, server에는 원문(spec §5 공통). 원문 nonce·id_token·교환 코드는 로그·`CrashReporter`에 싣지 않습니다(D64). 오류 보고는 `CrashSummary.from(error)`만 씁니다.
* SDK 경계 구현(기본값)은 SDK 호출을 그대로 옮기기만 하고 분기가 없습니다. 분기는 adapter에 두고 테스트합니다(spec §3).
* 설정이 비면 adapter는 `signIn`에서 `ProviderNotConfigured`를 던집니다. 버튼은 숨기지 않습니다.
* http 모드에서 로그인 adapter의 대역을 쓰지 않습니다. fake 모드(`ApiMode.fake`)는 지금처럼 대역입니다.
* 이메일·프로필 scope를 어느 제공자에게도 요청하지 않습니다(D82 ④).
* 확인 dialog 없이는 떼기·합치기를 부르지 않습니다(D82 ⑥).
* 로그인 버튼 순서: ko `kakao, line, google, apple`, ja `line, kakao, google, apple`, en과 그 밖의 언어 `google, kakao, line, apple`.
* 계약 파일을 읽는 테스트는 `@Tags(['contract'])`입니다.

## Review Focus

1. 붙이기가 진행 중일 때 다른 줄의 붙이기·떼기를 누르면 새 요청이 나가지 않고, 진행 중인 결과 하나만 반영됩니다(로그인 화면의 진행 중 규칙과 같음).
2. Google 로그인과 붙이기가 거의 동시에 처음 불려도 `initialize`는 한 번만 불리고, 둘 다 같은 프로세스 nonce를 돌려줍니다.
3. `account-merge`에 표 없이 들어오면(복원·딥링크) 빈 화면이나 예외 없이 `login-methods`로 갑니다.
4. 다른 계정을 남기는 합치기에서 새 토큰 저장 뒤 진입 계산이 실패해도 앱이 이전 계정 토큰으로 남지 않습니다. 화면은 오류를 안내하고, 다시 들어오면 새 계정입니다.
5. 지원하지 않는 언어(예 `zh`)이거나 국가 코드가 붙은 로케일(`ja_JP`)이어도 버튼 순서가 정해집니다(en·ja 규칙).

---

## 단계 A. 실제 로그인

### Task 1: 결정 기록, 설정 파일, `AuthConfig`

**Files:**
- Modify: `app/docs/decisions.md`(A67~A72 추가, A12 행에 "→ A67로 갱신")
- Create: `app/config/auth.json`(spec §4 값 그대로, 모두 빈 문자열)
- Create: `app/lib/core/platform/auth_config.dart`
- Modify: `app/lib/core/platform/social_auth.dart`(`ProviderNotConfigured` 추가)
- Modify: `app/README.md`(실행 명령에 `--dart-define-from-file=config/auth.json`), `app/tool/patrol_local.sh`, `.github/workflows/app.yml`(`flutter build apk --debug`와 `patrol test`에 같은 옵션)
- Test: `app/test/core/auth_config_test.dart`

**Interfaces:**
- Produces:
  - `final class AuthConfig { const new({required String kakaoNativeAppKey, required String lineChannelId, required String googleIosClientId, required String googleServerClientId, required String appleServicesId, required String appleRedirectUri, required String appLinkHost}); static const AuthConfig fromEnvironment; bool get isKakaoConfigured; bool get isLineConfigured; bool isGoogleConfigured({required bool ios}); bool get isAppleWebConfigured; }`
  - `final authConfigProvider = Provider<AuthConfig>((ref) => AuthConfig.fromEnvironment);`(`platform_providers.dart`)
  - `final class ProviderNotConfigured implements Exception { const new(this.provider); final SocialProvider provider; }`. `SocialProvider`는 아직 `kakao`·`apple`뿐이라, 이 task에서는 enum을 `lib/core/platform/social_provider.dart`로 옮기고 `social_login_button.dart`가 export합니다. 화면·adapter·repository가 같은 enum을 씁니다(spec §3 "`SocialProvider` 위치"를 플랫폼 계층으로 내림. 플랫폼 코드가 design을 import하지 않게 하려는 것)

- [ ] **Step 1: 실패하는 테스트 작성**: `AuthConfig 빈 값은 모든 제공자가 설정 안 됨`, `isGoogleConfigured는 ios면 iOS client id도 봅니다`(server만 채우면 android true·ios false), `isAppleWebConfigured는 셋 중 하나라도 비면 false`.
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/core/auth_config_test.dart`. Expected: FAIL(`AuthConfig` 없음).
- [ ] **Step 3: 구현**: `fromEnvironment`는 키마다 `String.fromEnvironment('<JSON 키>')`. 판정은 `trim().isNotEmpty`.
- [ ] **Step 4: 결정 기록**: spec §11의 A67~A71을 표 형식 그대로 옮기고, 위 "이 계획이 정하는 것"의 임시 문구를 A72로 적습니다.
- [ ] **Step 5: 실행해 통과 확인**: 같은 명령 PASS, `flutter analyze` 경고 0.
- [ ] **Step 6: Commit** `feat(app): 로그인 제공자 설정 파일과 AuthConfig (A68)`

### Task 2: 패키지와 네이티브 설정

**Files:**
- Modify: `app/pubspec.yaml`(Tech Stack의 다섯 패키지, 정확한 버전 고정 `2.0.1` 등)
- Modify: `app/android/app/build.gradle.kts`(JSON을 읽어 `manifestPlaceholders["kakaoScheme"]`·`["appLinkHost"]`, 빈 값이면 `kakao-unconfigured`·`unconfigured.invalid`)
- Modify: `app/android/app/src/main/AndroidManifest.xml`(spec §4 "네이티브 설정 추가"의 Android 세 항목)
- Create: `app/tool/gen_native_config.dart`, `app/ios/Flutter/Auth.xcconfig`(생성물, commit)
- Modify: `app/ios/Flutter/Debug.xcconfig`·`Release.xcconfig`(`#include "Auth.xcconfig"`), `app/ios/Runner/Info.plist`(URL Types 셋, `LSApplicationQueriesSchemes`), Create `app/ios/Runner/Runner.entitlements`와 `project.pbxproj`의 `CODE_SIGN_ENTITLEMENTS`
- Test: `app/test/contract/native_auth_config_test.dart`(`@Tags(['contract'])`)

**Interfaces:**
- Consumes: `app/config/auth.json`(Task 1)
- Produces: `dart run tool/gen_native_config.dart`(인자 없음, `config/auth.json` → `ios/Flutter/Auth.xcconfig`). `--check`면 파일을 쓰지 않고 차이가 있을 때 종료 코드 1

- [ ] **Step 1: 실패하는 계약 테스트 작성**:
  - `Auth.xcconfig는 auth.json에서 생성한 내용과 같습니다`(생성 함수를 import해 문자열 비교)
  - `빈 GOOGLE_IOS_CLIENT_ID는 google-unconfigured`, `채운 값 123-abc.apps.googleusercontent.com은 com.googleusercontent.apps.123-abc`(생성 함수 단위)
  - `AndroidManifest에 kakao AuthCodeHandlerActivity·CallbackActivity /auth/apple·queries 두 패키지가 있습니다`(문자열 포함 검사)
  - `Info.plist에 kakao$(KAKAO_NATIVE_APP_KEY)·line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)·$(GOOGLE_REVERSED_CLIENT_ID)와 lineauth2가 있습니다`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/contract/native_auth_config_test.dart`. Expected: FAIL.
- [ ] **Step 3: 구현**: 패키지 추가(`flutter pub get`), 생성 도구(순수 함수 `String renderAuthXcconfig(Map<String, String> config)`를 `tool/gen_native_config.dart`에 두고 테스트가 import), 네이티브 파일 수정.
- [ ] **Step 4: 실행해 통과 확인**: 계약 테스트 PASS. `flutter build apk --debug --dart-define-from-file=config/auth.json` 성공. iOS는 `flutter build ios --debug --no-codesign --dart-define-from-file=config/auth.json` 성공.
- [ ] **Step 5: README**: "생성 코드" 표에 `config/auth.json` → `tool/gen_native_config.dart` → `ios/Flutter/Auth.xcconfig` 행을 더합니다. CI `checks`에 `dart run tool/gen_native_config.dart --check`를 더합니다(`app.yml`).
- [ ] **Step 6: Commit** `build(app): 로그인 SDK 다섯과 Android·iOS 네이티브 설정 (A67·A68·A70)`

### Task 3: LINE·Google interface와 대역

**Files:**
- Modify: `app/lib/core/platform/social_provider.dart`(enum에 `line`·`google`)
- Modify: `app/lib/core/platform/social_auth.dart`, `app/lib/core/platform/fakes.dart`, `app/lib/core/platform/platform_providers.dart`
- Modify: `app/lib/features/auth/presentation/login_screen.dart`(enum이 늘어 깨지는 `_signIn`의 switch만 고침: `line`·`google` 갈래는 controller를 부르지 않고 `LoginFailed(UnexpectedError(ProviderNotSupportedYet(provider)))`를 결과로 씁니다. 버튼이 아직 두 개라 닿지 않는 갈래이고 Task 7이 지웁니다)
- Modify: `app/lib/design/components/action/social_login_button.dart`(switch에 `line`·`google`. 그리는 값은 Task 8)
- Test: `app/test/core/platform_fakes_test.dart`

**Interfaces:**
- Produces:
  - `final class LineCredential { const new({required String idToken}); }`, `abstract interface class LineAuth { Future<LineCredential> signIn({required String rawNonce}); }`
  - `final class GoogleCredential { const new({required String idToken, required String rawNonce}); }`, `abstract interface class GoogleAuth { Future<GoogleCredential> signIn({required String rawNonce}); }`(돌려준 `rawNonce`를 server에 보냄)
  - `FakeLineAuth`, `FakeGoogleAuth`(`FakeKakaoAuth`와 같은 모양: `failWith`, `providerNonces`. Google 대역은 받은 `rawNonce`를 그대로 credential에 넣음)
  - `lineAuthProvider`, `googleAuthProvider`(기본값 대역)
  - `final class ProviderNotSupportedYet implements Exception { const new(this.provider); }`(`social_auth.dart`, 단계 C에서 지움)

- [ ] **Step 1: 실패하는 테스트 작성**: `FakeLineAuth는 해시 nonce를 기록하고 idToken을 돌려줍니다`, `FakeGoogleAuth는 받은 원문 nonce를 credential에 담습니다`, 두 대역의 `failWith`가 `SocialSignInCancelled`를 던집니다.
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/core/platform_fakes_test.dart`. Expected: FAIL.
- [ ] **Step 3: 구현**.
- [ ] **Step 4: 실행해 통과 확인**: 같은 파일 PASS, `flutter test test/features/auth test/design/action_golden_test.dart --exclude-tags golden` PASS(기존 동작 그대로).
- [ ] **Step 5: Commit** `feat(app): LINE·Google 로그인 interface와 대역 (D82)`

### Task 4: 카카오·LINE adapter

**Files:**
- Create: `app/lib/core/platform/kakao_auth.dart`, `app/lib/core/platform/line_auth.dart`
- Test: `app/test/core/kakao_auth_test.dart`, `app/test/core/line_auth_test.dart`

**Interfaces:**
- Consumes: `AuthConfig`(Task 1), `KakaoAuth`·`LineAuth`(Task 3), `hashNonce`
- Produces:
  - `abstract interface class KakaoLoginApi { Future<bool> isKakaoTalkInstalled(); Future<String?> loginWithKakaoTalk({required String nonce}); Future<String?> loginWithKakaoAccount({required String nonce}); Future<void> clearTokens(); }`(돌려주는 값은 `OAuthToken.idToken`), 기본 구현 `SdkKakaoLoginApi`
  - `final class KakaoSdkAuth implements KakaoAuth { const new({required AuthConfig config, KakaoLoginApi api = const SdkKakaoLoginApi()}); }`
  - `abstract interface class LineLoginApi { Future<String?> login({required String nonce}); Future<void> logout(); }`(scope `['openid']`, `LoginOption(false, 'normal')`는 경계 구현이 고정, 돌려주는 값은 `idTokenRaw`), 기본 구현 `SdkLineLoginApi`
  - `final class LineSdkAuth implements LineAuth { const new({required AuthConfig config, LineLoginApi api = const SdkLineLoginApi()}); }`

- [ ] **Step 1: 실패하는 테스트 작성**(대역 `KakaoLoginApi`·`LineLoginApi`로, spec §5.1·§5.2 순서 그대로):
  - 카카오: `카카오톡이 있으면 해시 nonce로 카카오톡 로그인`, `카카오톡 CANCELED는 SocialSignInCancelled이고 계정 로그인을 부르지 않습니다`, `카카오톡 그 밖의 실패는 계정 로그인으로 넘어갑니다`, `카카오톡이 없으면 바로 계정 로그인`, `계정 로그인 CANCELED는 SocialSignInCancelled`, `계정 로그인 그 밖의 오류는 그대로 던집니다`, `idToken이 없으면 StateError`, `성공 뒤 토큰을 지우고, 지우기 실패해도 credential을 돌려줍니다`, `설정이 없으면 ProviderNotConfigured이고 SDK를 부르지 않습니다`
  - LINE: `해시 nonce로 로그인`, `PlatformException CANCEL은 SocialSignInCancelled`, `그 밖의 오류는 그대로`, `idTokenRaw가 없으면 StateError`, `성공 뒤 logout, 실패해도 성공`, `설정이 없으면 ProviderNotConfigured`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/core/kakao_auth_test.dart test/core/line_auth_test.dart`. Expected: FAIL.
- [ ] **Step 3: 구현**: 취소 판정은 `PlatformException.code`(`'CANCELED'`, `'CANCEL'`). 세션 정리 실패는 삼킵니다(A69).
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령 PASS.
- [ ] **Step 5: Commit** `feat(app): 카카오·LINE 실제 로그인 adapter (A69·A70)`

### Task 5: Google adapter

**Files:**
- Create: `app/lib/core/platform/google_auth.dart`
- Test: `app/test/core/google_auth_test.dart`

**Interfaces:**
- Consumes: `AuthConfig`, `GoogleAuth`, `NonceGenerator`, `hashNonce`
- Produces:
  - `abstract interface class GoogleSignInApi { Future<void> initialize({String? clientId, required String serverClientId, required String nonce}); Future<String?> authenticate(); Future<void> signOut(); }`(돌려주는 값은 `authentication.idToken`), 기본 구현 `SdkGoogleSignInApi`
  - `final class GoogleSdkAuth implements GoogleAuth { new({required AuthConfig config, required bool isIos, required NonceGenerator nonces, GoogleSignInApi api = const SdkGoogleSignInApi()}); }`

- [ ] **Step 1: 실패하는 테스트 작성**(spec §5.4):
  - `첫 signIn에서만 initialize하고 두 번째는 부르지 않습니다`
  - `동시에 두 번 불러도 initialize는 한 번이고 두 credential의 rawNonce가 같습니다`(Review Focus 2)
  - `iOS는 clientId에 iOS client id, Android는 clientId null`
  - `initialize의 nonce는 hashNonce(프로세스 nonce)이고 credential.rawNonce는 그 원문입니다. 인자로 받은 rawNonce는 쓰지 않습니다`
  - `canceled는 SocialSignInCancelled`(경계가 `GoogleSignInException(code: canceled)`를 던짐)
  - `idToken이 없으면 StateError`, `성공 뒤 signOut, 실패해도 성공`
  - `설정이 없으면 ProviderNotConfigured`(server id 빔. iOS는 iOS id 빔도)
  - `initialize가 실패하면 다음 signIn이 다시 initialize합니다`(실패한 future를 붙들지 않음)
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/core/google_auth_test.dart`. Expected: FAIL.
- [ ] **Step 3: 구현**: 초기화 future를 필드에 두고, 실패하면 필드를 비웁니다. 프로세스 nonce는 처음 초기화할 때 만듭니다.
- [ ] **Step 4: 실행해 통과 확인**: PASS.
- [ ] **Step 5: Commit** `feat(app): Google 실제 로그인 adapter, 프로세스 nonce (A70)`

### Task 6: Apple iOS·Android 웹 adapter

**Files:**
- Create: `app/lib/core/platform/apple_native_auth.dart`, `app/lib/core/platform/apple_web_auth.dart`
- Test: `app/test/core/apple_native_auth_test.dart`, `app/test/core/apple_web_auth_test.dart`

**Interfaces:**
- Consumes: `AuthConfig`, `AppleNativeAuth`·`AppleWebAuth`, `buildAppleAuthorizeUri`, `parseAppleWebReturn`, `NonceGenerator`
- Produces:
  - `abstract interface class AppleIdCredentialApi { Future<({String? identityToken, String authorizationCode})> getCredential({required String nonce}); }`(scope 빈 목록은 경계 구현이 고정), 기본 구현 `SdkAppleIdCredentialApi`
  - `final class SignInWithAppleNativeAuth implements AppleNativeAuth { const new({AppleIdCredentialApi api = const SdkAppleIdCredentialApi()}); }`
  - `typedef WebAuthenticate = Future<String> Function({required Uri url, required String httpsHost, required String httpsPath});`, 기본값 `_flutterWebAuth2`(`callbackUrlScheme: 'https'`)
  - `final class WebAuthAppleWebAuth implements AppleWebAuth { new({required AuthConfig config, required NonceGenerator nonces, WebAuthenticate authenticate = _flutterWebAuth2}); }`

- [ ] **Step 1: 실패하는 테스트 작성**:
  - iOS: `해시 nonce로 요청`, `canceled는 SocialSignInCancelled`(경계가 `SignInWithAppleAuthorizationException(code: canceled)`), `그 밖의 오류는 그대로`, `identityToken이 없으면 StateError`, `authorizationCode를 credential에 담습니다`
  - 웹: `authorize URL에 Services ID·redirect_uri·해시 nonce·state`, `httpsHost는 APP_LINK_HOST, httpsPath는 /auth/apple`, `복귀 결과를 parseAppleWebReturn으로 해석(교환 코드)`, `state가 다르면 AppleWebFailure(stateMismatch)`, `CANCELED는 AppleWebFailure(userCancelled)`, `그 밖의 PlatformException은 그대로`, `설정 셋 중 하나라도 비면 ProviderNotConfigured이고 브라우저를 열지 않습니다`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/core/apple_native_auth_test.dart test/core/apple_web_auth_test.dart`. Expected: FAIL.
- [ ] **Step 3: 구현**.
- [ ] **Step 4: 실행해 통과 확인**: PASS.
- [ ] **Step 5: Commit** `feat(app): Apple iOS·Android 웹 실제 로그인 adapter (A67)`

### Task 7: 제공자 인증 경계, 로그인 합치기, 부팅 끼우기

**Files:**
- Create: `app/lib/features/auth/application/provider_authenticator.dart`
- Create: `app/lib/features/auth/application/session_entry.dart`(`login_controller.dart`의 `_Session`을 옮김)
- Modify: `app/lib/features/auth/data/auth_repository.dart`, `app/lib/features/auth/application/login_controller.dart`, `app/lib/features/auth/presentation/login_screen.dart`(`controller.signIn(provider, …)` 하나로)
- Modify: `app/lib/app/bootstrap.dart`(`realPlatformOverrides(ApiMode.http)`에 adapter 다섯, 설정이 있으면 `KakaoSdk.init`·`LineSDK.instance.setup`)
- Test: `app/test/features/auth/provider_authenticator_test.dart`, `app/test/features/auth/login_controller_test.dart`(수정), `app/test/app/bootstrap_test.dart`(있으면 수정, 없으면 만듦)

**Interfaces:**
- Consumes: Task 3~6의 interface·adapter
- Produces:
  - `sealed class ProviderProof { SocialProvider get provider; String get rawNonce; }`, `final class IdTokenProof extends ProviderProof { const new({required SocialProvider provider, required String idToken, required String rawNonce, String? authorizationCode}); }`, `final class AppleWebExchangeProof extends ProviderProof { const new({required String exchangeCode, required String rawNonce}); }`
  - `final class ProviderAuthenticator { const new(Ref ref); Future<ProviderAuthResult> authenticate(SocialProvider provider, {required String rawNonce}); }`. `sealed class ProviderAuthResult`: `ProviderAuthenticated(ProviderProof proof)`, `ProviderAppleWebFailed(AppleWebError error)`. 취소는 `SocialSignInCancelled`를 던짐
  - `final providerAuthenticatorProvider = Provider<ProviderAuthenticator>(ProviderAuthenticator.new);`
  - `AuthRepository.login(ProviderProof proof) → Future<LoginResponse>`(기존 `kakao`·`appleNative`·`appleWeb`은 private로. `line`·`google`은 `ProviderNotSupportedYet`)
  - `LoginController.signIn(SocialProvider provider, {DiscardNotice? showDiscardNotice}) → Future<LoginOutcome>`(`signInWithKakao`·`signInWithApple` 삭제)
  - `final class SessionEntry { const new({...기존 _Session 필드}); Future<AppError?> enter(LoginResponse response, DiscardNotice? notice); Future<AppError?> switchTo(TokenPair tokens); static SessionEntry read(Ref ref); }`. `switchTo`는 저장된 refresh token 폐기 → `tokens.save` → `entry.refresh()`이고, `enter`가 그것을 씁니다

- [ ] **Step 1: 실패하는 테스트 작성**:
  - authenticator: `apple은 Android면 웹, iOS면 네이티브 adapter`, `카카오·LINE credential → IdTokenProof(같은 rawNonce)`, `Google은 credential의 rawNonce를 proof에 넣습니다`, `Apple 웹 교환 → AppleWebExchangeProof`, `Apple 웹 실패 → ProviderAppleWebFailed`, `취소는 SocialSignInCancelled를 그대로`
  - repository: `IdTokenProof(kakao) → loginKakao`, `IdTokenProof(apple, authorizationCode) → loginApple`, `AppleWebExchangeProof → completeAppleWebLogin`, `line·google → ProviderNotSupportedYet`
  - controller: 기존 카카오·Apple 테스트를 `signIn(SocialProvider.x)`로 옮기고 모두 그대로 통과. 더할 것: `ProviderNotConfigured는 LoginFailed(UnexpectedError)이고 오류 요약을 보고합니다`, `google은 LoginFailed(UnexpectedError(ProviderNotSupportedYet))`
  - 부팅: `realPlatformOverrides(http)는 다섯 provider를 실제 adapter로`, `fake는 대역`(spec §12 "부팅")
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/auth test/app`. Expected: FAIL.
- [ ] **Step 3: 구현**: `LoginController._attempt`는 `SessionEntry.read(ref)`를 시도 처음에 잡습니다(지금 `_Session`과 같은 시점). 진행 중 재호출·nonce 규칙은 그대로입니다.
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령 PASS, `flutter test test/flows`(로그인 흐름 회귀) PASS.
- [ ] **Step 5: Commit** `feat(app): 제공자 인증 경계와 로그인 합치기 (A71)`

### Task 8: 로그인 화면 네 버튼

**Files:**
- Create: `app/lib/features/auth/presentation/login_provider_order.dart`
- Modify: `app/lib/design/components/action/social_login_button.dart`(`line`·`google` 그리기, `spec` 변형 집합에 둘), `app/assets/brand/line/`·`app/assets/brand/google/`(각 브랜드 가이드 공식 로고 SVG), `app/pubspec.yaml`(assets)
- Modify: `app/lib/features/auth/presentation/login_screen.dart`, `app/lib/core/l10n/app_{ko,en,ja}.arb`(`loginLineLabel`·`loginGoogleLabel` 임시), `app/test/contract/app_bar_title_contract_test.dart`(`_allowedTemporaryKeys`)
- Modify: `app/widgetbook/lib/action_directory.dart`(두 변형)
- Test: `app/test/features/auth/login_provider_order_test.dart`, `app/test/features/auth/login_screen_test.dart`(있으면 수정), `app/test/design/action_golden_test.dart`

**Interfaces:**
- Produces: `List<SocialProvider> loginProviderOrder(Locale locale)`

- [ ] **Step 1: 실패하는 테스트 작성**:
  - 순서: `ko → kakao, line, google, apple`, `ja → line, kakao, google, apple`, `en → google, kakao, line, apple`, `zh와 ja_JP`(Review Focus 5: `zh`는 en 순서, `ja_JP`는 ja 순서)
  - 화면: `네 버튼이 앱 언어 순서대로 같은 크기`, `한 버튼이 처리 중이면 나머지 셋이 꺼짐`, `LINE을 누르면 controller.signIn(line)`
  - golden: `social-login-button: 카카오·LINE·Google·Apple × 기본·loading·꺼짐`(이름을 바꾸고 두 변형 추가)
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/auth`. Expected: FAIL.
- [ ] **Step 3: 구현**: LINE은 LINE 로그인 버튼 가이드 기본형(#06C755 바탕, 흰 로고·글자), Google은 Google 로그인 브랜드 가이드 light(흰 바탕, #747775 테두리 1, #1F1F1F 글자)·dark(#131314 바탕, #8E918F 테두리, #E3E3E3 글자)입니다. 클래스 주석에 "design #389 전 임시"라고 적습니다.
- [ ] **Step 4: 실행해 통과 확인**: `flutter test test/features/auth test/contract --exclude-tags golden` PASS, `tool/goldens_linux.sh test/design/action_golden_test.dart --update-goldens` 뒤 같은 명령(갱신 없이) PASS.
- [ ] **Step 5: Commit** `feat(app): 로그인 화면 네 버튼과 언어별 순서 (D82 ①)`

## 단계 B. 로그인 수단·계정 합치기

### Task 9: 연결 데이터 경계와 fake

**Files:**
- Create: `app/lib/features/account/data/account_link_repository.dart`, `app/lib/features/account/data/fake_account_link_repository.dart`
- Test: `app/test/features/account/data/fake_account_link_repository_test.dart`

**Interfaces:**
- Consumes: `ProviderProof`(Task 7), `TokenPair`(생성 모델)
- Produces:
  - `abstract interface class AccountLinkRepository { Future<List<SocialProvider>> methods(); Future<LinkResult> link(ProviderProof proof); Future<List<SocialProvider>> unlink(SocialProvider provider); Future<MergePreview> mergePreview(MergeTicket ticket); Future<TokenPair?> merge(MergeTicket ticket, {required MergeKeep keep}); }`
  - `sealed class LinkResult`: `Linked(List<SocialProvider> methods)`, `LinkConflict(MergeTicket ticket)`
  - `final class MergeTicket { const new(this.value); final String value; }`, `enum MergeKeep { current, other }`
  - `final class AccountSummary { const new({required String callName, required String sajuLine, required int diaryCount, required List<SocialProvider> methods}); }`
  - `final class MergePreview { const new({required AccountSummary current, required AccountSummary other, required bool hasOverlappingDays}); }`
  - `final class MergeTicketExpired implements Exception { const new(); }`
  - `final accountLinkRepositoryProvider = Provider<AccountLinkRepository>(...)`(두 모드 모두 fake, 단계 C에서 http)
- [ ] **Step 1: 실패하는 테스트 작성**: "이 계획이 정하는 것"의 fake 규칙대로. `처음 목록은 [kakao]`, `line 붙이기 → Linked([kakao, line])`, `google 붙이기 → LinkConflict`, `unlink 뒤 남은 목록`, `마지막 하나 unlink는 AppError`(server 거절 흉내), `merge(other) → TokenPair`, `merge(current) → null`, `쓴 표로 다시 merge → MergeTicketExpired`.
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/account`. Expected: FAIL.
- [ ] **Step 3: 구현**.
- [ ] **Step 4: 실행해 통과 확인**: PASS.
- [ ] **Step 5: Commit** `feat(app): 로그인 수단 연결·합치기 데이터 경계와 fake (A71)`

### Task 10: `account-choice` 컴포넌트

**Files:**
- Create: `app/lib/design/components/input/account_choice.dart`
- Modify: `app/widgetbook/lib/`(input 디렉터리 파일에 use case), `app/lib/core/l10n/app_{ko,en,ja}.arb`(`accountChoiceCurrent`·`accountChoiceOther`·`accountChoiceDiaryCount`·`accountChoiceMovedDiaryCount` 임시)
- Test: `app/test/design/input_golden_test.dart`, `app/test/design/account_choice_test.dart`

**Interfaces:**
- Consumes: `AccountSummary`(Task 9)
- Produces: `class AccountChoice extends StatelessWidget { const new({required String heading, required AccountSummary summary, required bool selected, required ValueChanged<bool>? onSelected, String? identifier}); static const ComponentSpec spec; }`. 고르지 않은 카드는 일기 수 대신 `accountChoiceMovedDiaryCount`를 보입니다(spec §9 "옮겨질 일기 수")

- [ ] **Step 1: 실패하는 테스트 작성**: `selected면 접근성 selected·checked가 true이고 radio 의미`, `누르면 onSelected(true)`, `고르지 않은 카드는 옮겨질 일기 수 문구`, `고른 카드는 일기 수 문구`, golden `account-choice: 고름·안 고름 × 라이트·다크`.
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/design/account_choice_test.dart`. Expected: FAIL.
- [ ] **Step 3: 구현**: 둥근 사각 카드(동작 모양 규칙), 고르면 `border.focus` 색 테두리. 클래스 주석에 "design #389 전 임시".
- [ ] **Step 4: 실행해 통과 확인**: 테스트 PASS, golden 갱신 뒤 PASS.
- [ ] **Step 5: Commit** `feat(app): account-choice 임시 컴포넌트 (#389 전)`

### Task 11: `login-methods` 화면과 설정 줄

**Files:**
- Create: `app/lib/features/account/application/login_methods_controller.dart`, `app/lib/features/account/presentation/login_methods_screen.dart`
- Modify: `app/lib/features/me/presentation/settings_screen.dart`(줄과 `settingsExits`에 `ScreenIds.loginMethods`), `app/lib/app/router/screen_registry.dart`, `app/test/contract/ia_pending.dart`(`settings`·`login-methods` 지움), ARB(A72의 로그인 수단 키·`socialProvider*`), `_allowedTemporaryKeys`
- Test: `app/test/features/account/login_methods_screen_test.dart`, `app/test/features/account/login_methods_controller_test.dart`

**Interfaces:**
- Consumes: `ProviderAuthenticator`, `AccountLinkRepository`, `loginProviderOrder`, `SocialLoginButton`, `SettingsRow`
- Produces:
  - `class LoginMethodsController extends AsyncNotifier<List<SocialProvider>>`, `Future<LinkAttempt> link(SocialProvider provider)`, `Future<void> unlink(SocialProvider provider)`. `sealed class LinkAttempt`: `LinkDone()`, `LinkNeedsMerge(MergeTicket ticket)`, `LinkFailed()`
  - `final loginMethodsControllerProvider`(autoDispose)
  - `const Set<String> loginMethodsExits = {ScreenIds.accountMerge}`, `const Set<String> loginMethodsHandledStates = {'error'}`

- [ ] **Step 1: 실패하는 테스트 작성**:
  - controller: `link 성공이면 목록 갱신`, `LinkConflict면 LinkNeedsMerge`, `취소·Apple 웹 실패·AppError는 LinkFailed이고 목록 그대로`, `진행 중에 다시 link·unlink를 부르면 새 요청 없이 진행 중인 결과`(Review Focus 1), `unlink가 거절되면 오류 상태로 알리고 목록 그대로`
  - 화면: `네 줄이 loginProviderOrder 순서`, `연결된 줄은 SettingsRow value(떼기)`, `연결 안 된 줄은 SocialLoginButton`, `하나만 연결이면 그 줄이 꺼지고 last.notice`, `떼기는 dialog 확인 뒤에만 unlink`, `실패하면 error.body`, `LinkNeedsMerge면 account-merge로 push(extra = MergeTicket)`, 붙이기가 끝나면 목록을 다시 그림
  - 설정: `로그인 수단 줄을 누르면 login-methods`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/account test/features/me`. Expected: FAIL.
- [ ] **Step 3: 구현**: 붙이기 nonce는 시도마다 `nonceGeneratorProvider`로 만듭니다. `account-merge`에서 돌아오면(push 결과) 목록을 다시 읽습니다.
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령과 `flutter test --tags contract` PASS(IA ratchet이 `settings`·`login-methods`를 확인).
- [ ] **Step 5: Commit** `feat(app): 설정 > 로그인 수단 화면 (D82 ⑤)`

### Task 12: `account-merge` 화면

**Files:**
- Create: `app/lib/features/account/application/account_merge_controller.dart`, `app/lib/features/account/presentation/account_merge_screen.dart`
- Modify: `app/lib/app/router/screen_registry.dart`, `app/test/contract/ia_pending.dart`(`account-merge` 지움. 두 집합에 `ad-free`만 남음), ARB(A72의 합치기 키), `_allowedTemporaryKeys`
- Test: `app/test/features/account/account_merge_screen_test.dart`, `app/test/features/account/account_merge_controller_test.dart`

**Interfaces:**
- Consumes: `AccountLinkRepository`, `SessionEntry.switchTo`(Task 7), `AccountChoice`(Task 10)
- Produces:
  - `class AccountMergeController extends AsyncNotifier<MergePreview>`(family 인자 `MergeTicket`), `Future<MergeOutcome> merge(MergeKeep keep)`. `sealed class MergeOutcome`: `MergeDone()`, `MergeExpired()`, `MergeFailed(AppError error)`
  - `const Set<String> accountMergeExits = {ScreenIds.loginMethods}`, `const Set<String> accountMergeHandledStates = {'loading', 'error'}`

- [ ] **Step 1: 실패하는 테스트 작성**:
  - controller: `merge(current)는 토큰을 바꾸지 않습니다`, `merge(other)는 SessionEntry.switchTo(새 토큰)`, `switchTo가 오류를 돌려주면 MergeFailed이고, 저장된 토큰은 새 토큰입니다`(Review Focus 4), `MergeTicketExpired → MergeExpired`, `진행 중 재호출은 같은 결과`
  - 화면: `loading 동안 skeleton`, `두 카드와 처음에는 지금 계정이 고름`, `다른 계정을 고르면 두 카드의 일기 표시가 바뀜`, `hasOverlappingDays면 overlap.notice, 아니면 없음(고르기와 무관)`, `합치기는 confirm dialog 뒤에만 merge`, `합치지 않기 → login-methods`, `완료 → login-methods`, `만료 → accountMergeExpired toast 뒤 login-methods`, `미리보기 실패 → error`, `extra 없이 열면 login-methods로 go`(Review Focus 3)
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/account`. Expected: FAIL.
- [ ] **Step 3: 구현**: confirm dialog는 `showMyungliConfirm` 계열(`dialog` `destructive`, 기본 선택 취소). 완료·취소 이동은 `context.pop()`(login-methods가 목록을 다시 읽음), 표 없음·만료는 `context.go(pathOf(ScreenIds.loginMethods))`.
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령과 `flutter test --tags contract` PASS.
- [ ] **Step 5: Commit** `feat(app): 계정 합치기 화면, 일기는 모두 옮김 (D82 ⑥, D83 ④)`

### Task 13: 끝에서 끝 흐름, 커버리지, 문서

**Files:**
- Create: `app/test/flows/login_methods_flow_test.dart`, `app/patrol_test/account_test.dart`(`test_bundle.dart` 갱신)
- Modify: `app/tool/coverage_baseline.json`(도구가 갱신), `app/README.md`(fake 연결 규칙 한 줄), `app/CLAUDE.md`(현재 상태·다음 할 일), 화면 스크린샷 등록(`tool/register_screenshots.dart`, 계획 6과 같은 절차)

- [ ] **Step 1: 흐름 테스트 작성**: fake 회원으로 `settings → login-methods → LINE 붙이기(목록에 LINE) → Google 붙이기 → account-merge → 다른 계정 고름 → 확인 → login-methods`. 남은 계정의 토큰으로 진입이 다시 계산되는지 확인합니다.
- [ ] **Step 2: 실행해 통과 확인**: `flutter test test/flows/login_methods_flow_test.dart` PASS.
- [ ] **Step 3: Patrol**: 같은 흐름을 `patrol_test/account_test.dart`로 만들고 `tool/patrol_local.sh patrol_test/account_test.dart`. Expected: 종료 코드 0. 로그인 흐름 회귀로 `tool/patrol_local.sh patrol_test/login_test.dart`도 0.
- [ ] **Step 4: 커버리지**: `dart run tool/ia_coverage.dart --check` 통과(새 경로 `settings>login-methods`, `login-methods>account-merge`, `account-merge>login-methods`와 상태).
- [ ] **Step 5: 전체 검사**(PR 직전): `flutter analyze`(app·widgetbook), `dart analyze`, `flutter test --exclude-tags golden`, `dart format --set-exit-if-changed .`, `tool/goldens_linux.sh`, `dart run tool/gen_native_config.dart --check`. 모두 통과.
- [ ] **Step 6: 문서**: `app/CLAUDE.md` 현재 상태에 계획 7 단계 A·B를 적고, 다음 할 일에 단계 C(server #386·#407 ④), 실기기 확인 목록(spec §12), #347 ②, `ad-free`를 남깁니다.
- [ ] **Step 7: 알림**:
  - server #386에 Google nonce 제약을 코멘트로 남깁니다. "Google nonce는 앱 프로세스마다 하나"(spec §5.4)라서 nonce 일회용 확인과 맞지 않습니다.
  - writing #388에 A72 임시 키 목록을 남깁니다.
  - design #389에 LINE·Google 임시 값과 `account-choice` 임시 모양을 남깁니다.
- [ ] **Step 8: Commit** `test(app): 로그인 수단·계정 합치기 흐름과 Patrol, 현재 상태 갱신`

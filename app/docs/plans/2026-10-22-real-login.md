# app 실제 로그인·로그인 수단·계정 합치기 Implementation Plan (계획 7 단계 A·B)

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

> **개정 2026-10-23 (#484, `app/d85-d88`):** D85(연결 거절·합치기 별도 입구·삭제 복구 없음)와 REST 1.0.0(freeze, S114)에 맞춰 고쳤습니다. 결정 번호는 A80~A85입니다(처음 초안 번호는 일기 결정과 겹침). 이미 끝난 Task·Step은 **끝남**으로 표시했습니다. 계약이 모두 왔으므로 처음 초안의 단계 C(http 연결)는 단계 B에 합쳤습니다.

> **개정 2026-10-27 (`app/real-login-2` 첫 commit):** D95(#563, LINE·Google 제공자 허가는 어디서도 취소하지 않음)로 허가 취소 경계 `ProviderRevoker`·`FakeProviderRevoker`·`SdkProviderRevoker`, 합치기 인증의 `keepSession`, 계정 삭제 전 취소, LINE `hasAccessToken`·Google `disconnect` 경계를 지웠습니다(Task 3·4·5·7·9·11·12). #552 답(server S115, REST 1.1.0)으로 합치기 재전송 판정을 바꿨습니다(응답 없음 → 같은 토큰·본문·키로 다시 보내 200이면 합쳐짐, `getMe` 잠정 판정 삭제). #555 답(Google 프로세스 nonce 재사용 허용)을 spec §5.4에 적었습니다.

**Goal:** 로그인을 대역에서 실제 제공자 넷(카카오·LINE·Google·Apple)의 adapter로 바꿉니다. 설정이 비어 있으면 "설정 안 됨"으로 실패합니다. 로그인 화면은 네 버튼이고, 맨 위 버튼은 언어마다 다릅니다. 설정 > 로그인 수단(`login-methods`)에서 인증 계정을 붙이고 떼며, 붙이려는 인증 계정이 다른 유저 계정에 있으면 연결하지 않고 안내만 합니다(D85 ③). 같은 화면의 합치기 입구에서 계정 합치기(`account-merge`)로 다른 유저 계정의 기록·구매를 가져옵니다(D85 ④). 연결·합치기는 REST 1.0.0 operation을 쓰고 fake 모드는 대역 서버가 답합니다.

**Architecture:**
* `lib/core/platform/`: `AuthConfig`(dart-define 값), 제공자 adapter 다섯(SDK 호출은 생성자로 받는 경계 뒤), `LineAuth`·`GoogleAuth` interface와 대역. LINE·Google 제공자 허가는 취소하지 않습니다(D95).
* `lib/features/auth/application/`: `ProviderAuthenticator`가 제공자 하나로 인증해 `ProviderProof`를 돌려줍니다. 로그인(`AuthRepository.login`), 붙이기(`AccountLinkRepository.link`), 합치기 인증(`AccountLinkRepository.preview`)이 함께 씁니다.
* `lib/features/account/`: `AccountLinkRepository`(생성 클라이언트 위), `login-methods`·`account-merge` 화면과 controller.
* 컴포넌트는 끝났습니다: `social-login-button`(네 제공자·`connected`)과 `account-choice`(3.0.0).

**Tech Stack:** 계획 6과 같음(Flutter 3.47.7, Riverpod 3.x 코드 생성 없음, go_router, Dio 생성 클라이언트). 새 패키지: `kakao_flutter_sdk_user` 2.0.1, `flutter_line_sdk` 2.7.2, `google_sign_in` 7.2.0, `sign_in_with_apple` 8.2.0, `flutter_web_auth_2` 5.1.0(버전은 spec §2와 A83에서 고정).

**Spec:** `app/docs/specs/2026-10-21-real-login-design.md`(§1~§14. 이 plan은 §12의 단계 A·B입니다). 함께 읽을 것: IA `docs/ia/screens.json`(`login`·`settings`·`login-methods`·`account-merge`), 컴포넌트 `docs/identity/design/components/action.json`(`social-login-button`·`primary-button`·`dialog`)·`input.json`(`account-choice`), design spec `docs/identity/design/specs/2026-10-23-account-merge-purchase-design.md` §2·§3, REST `server/api/openapi.yaml` 1.1.0, 루트 D82·D83·D85·D95, server S115, Issue #311·#387·#484.

## 시작 전

* 브랜치는 `app/d85-d88`이 main에 병합된 뒤 main에서 새로 만듭니다(`git checkout --no-track -b app/real-login-2 origin/main`, 이름은 착수 안내를 따름). 옛 `app/real-login` 브랜치의 spec·계획은 이 개정판으로 대체됐습니다. 그 브랜치의 drift #412 생성 코드 commit은 뒤의 IA 생성 코드로 대체됐고 #412는 닫혔으므로 가져오지 않습니다.
* 열린 drift가 있으면 첫 commit에서 맞춥니다(`gh issue list --label drift`).
* 검사는 `app/CLAUDE.md` "검사" 절을 따릅니다. 반복 중에는 바꾼 범위만 돌립니다.

## 진행 순서 (루트 D91)

D91 ①로 A1은 대역 데이터로 화면을 만드는 데까지이고, 실제 SDK adapter는 A2(실제 연동)입니다. 그래서 Task 번호 차례가 아니라 아래 차례로 합니다.
1. **A1(화면, 대역):** 아래 표의 A1 몫을 Task 1 → 3 → 7 → 8 → 9 → 11 → 12 → 13 차례로 합니다. #387의 화면 일과 #484가 이것으로 끝납니다.
2. **A2(실제 연동):** 아래 표의 A2 몫을 Task 1 → 2 → 4 → 5 → 6 → 7 → A2 마무리 차례로 합니다. `local` server로 REST 연동을 먼저 확인하고, 외부 값이 필요한 adapter는 준비물이 오는 대로 합니다(`docs/external-prep.md`). spec §14 수익 쪽 과제도 A2입니다.

| Task | A1에서 할 것 | A2로 미루는 것 |
| --- | --- | --- |
| 1 | `SocialProvider`를 `lib/core/platform/social_provider.dart`로 옮김, **Step 4 결정 기록 A80~A85**(A2 내용 결정도 이때 기록), **Step 4a commit** | `auth.json`, `AuthConfig`·`authConfigProvider`, `ProviderNotConfigured`, README·`patrol_local.sh`·`app.yml`의 `--dart-define-from-file`, Step 1~3·5 |
| 2 | 없음 | 전부(패키지, 네이티브 설정, `gen_native_config.dart`, CI `--check`) |
| 3 | 전부(`LineAuth`·`GoogleAuth`와 대역) | 없음 |
| 4·5·6 | 없음 | 전부(실제 adapter) |
| 7 | `ProviderAuthenticator`(대역 adapter로), `AuthRepository.login`(LINE·Google operation, 대역 서버), `LoginController.signIn`. 테스트는 authenticator·repository·controller(`ProviderNotConfigured` 테스트 제외) | `bootstrap.dart` 부팅 끼우기(실제 adapter, `KakaoSdk.init`·`LineSDK.setup`), 부팅 테스트, `ProviderNotConfigured`가 `LoginFailed`가 되는 controller 테스트 |
| 8·9·11·12 | 전부 | 없음 |
| 13 | 전부. Step 5는 `gen_native_config --check`를 빼고, Step 6 문서는 A1 기준 | A2 마무리(아래) |

**A2 마무리:** `flutter test test/app test/features/auth`(부팅·`ProviderNotConfigured` 테스트) PASS, 전체 검사에 `dart run tool/gen_native_config.dart --check`와 `flutter build apk --debug --dart-define-from-file=config/auth.json`을 더해 통과, `tool/patrol_local.sh patrol_test/login_test.dart` 회귀 0, `app/CLAUDE.md` 현재 상태에 A2를 적음. Commit `feat(app): 계획 7 A2 실제 로그인 adapter 마무리`.

A2 산출물에 기대는 A1 Step은 위 표의 "A2로 미루는 것"으로 모두 옮겼습니다. A1의 테스트는 `AuthConfig`·실제 adapter·`gen_native_config` 없이 돕니다.

## 외부 대기 (이 계획은 기다리지 않고 진행)

| 대기 | 요청 | 기다리는 동안 |
| --- | --- | --- |
| 외부 준비물(카카오 앱, LINE 채널, Google OAuth client, Apple Services ID, 도메인) | 사용자 | `config/auth.json`은 빈 값, adapter는 `ProviderNotConfigured` |

처음 초안의 대기(server #386·#407 ④, design #389, writing #388)는 모두 왔습니다: REST 1.0.0, 컴포넌트 3.0.0, writing W39·W40·W42.

## 이 계획이 정하는 것 (spec 사이 빈칸)

| 빈칸 | 정한 것 |
| --- | --- |
| 문구 | **A85:** writing 원고 키를 씁니다. 로그인 `loginLineLabel`·`loginGoogleLabel`, 제공자 이름 `loginProviderKakao`·`loginProviderLine`·`loginProviderGoogle`·`loginProviderApple`, 로그인 수단 `loginMethodsBarTitle`·`loginMethodsIntroBody`·`loginMethodsLastNotice`·`loginMethodsUnlinkConfirm`(`{provider}`)·`loginMethodsUnlinkConfirmBody`·`loginMethodsUnlinkConfirmUnlink`·`loginMethodsUnlinkConfirmCancel`·`loginMethodsRowConnected`·`loginMethodsInUseBody`·`loginMethodsMergeCta`·`loginMethodsErrorBodyLink`·`loginMethodsErrorBodyUnlink`, 계정 합치기 `accountMergeBarTitle`·`accountMergeTitleHead`·`accountMergeAuthBody`·`accountMergeTitleBody`·`accountMergeSummaryHead`·`accountMergeSummaryDiary`·`accountMergeSummaryDiaryCount`·`accountMergeSummaryEvent`·`accountMergeSummaryEventCount`·`accountMergeSummaryAdFree`·`accountMergeSummaryAdFreeDays`·`accountMergeChoiceLabel`·`accountMergeOverlapNotice`·`accountMergeCtaMerge`·`accountMergeMergeConfirm`·`accountMergeMergeConfirmMerge`·`accountMergeMergeConfirmCancel`·`accountMergeNotOtherBodySelf`·`accountMergeNotOtherBodyNone`·`accountMergeError`·`errorMergeTokenInvalid`, 카드 `accountChoiceCurrent`·`accountChoiceOther`·`accountChoiceSaju`·`accountChoiceSajuNoTime`·`accountChoiceSajuEmpty`. 설정의 "로그인 수단" 줄은 `loginMethodsBarTitle`을 다시 씁니다(A64와 같은 규칙). 원고 없는 자리가 새로 나오면 A7 임시 키와 writing Issue입니다. 사용자에게 보이는 글자에 U+2014·U+2013·U+00B7을 쓰지 않습니다(#546) |
| 연결 안 된 줄의 붙이기 버튼 문구 | 로그인 버튼과 같은 제공자 공식 문구(`loginKakaoLabel` 등)입니다. 새 키를 만들지 않습니다 |
| 연결된 줄의 모양 | `SocialLoginButton(connected: true, connectedLabel: loginMethodsRowConnected)`. 누르면 `login-methods.unlink.confirm` dialog. 마지막 하나면 `onPressed: null`이고 그 줄 아래에 `loginMethodsLastNotice`(V39) |
| 합치기 토큰 보관 | `AccountMergeController` 상태에만 둡니다. route extra·복원 상태·URL에 두지 않습니다. 화면을 떠나면 버립니다 |
| `account-merge`에 바로 들어옴(복원·딥링크) | 언제나 인증 단계부터입니다. 들고 올 값이 없어 따로 돌려보내지 않습니다 |
| 합치기 멱등 키와 재전송 간격 | 키는 (`mergeToken`, `profile`) 조합마다 하나입니다. 같은 토큰·같은 프로필로 다시 확정하면(실패 dialog 뒤 다시 누름 등) 같은 키를 다시 쓰고, 토큰이나 프로필이 바뀌면 새 키입니다. 409 `idempotency.in_progress`는 1초 뒤 같은 키로, 최대 5번. 응답 없음(시간 초과·연결 끊김)은 같은 토큰·본문·키로 한 번 다시 보내고, 200이면 합쳐진 것, 422 `merge.token_invalid`면 `errorMergeTokenInvalid`와 인증 단계입니다(S115). 그래도 끝나지 않으면 `accountMergeError` |
| 합친 뒤 지울 것 | 계약 `mergeAccounts`대로 이 계정의 오늘·달력·일기 목록·나의 사주 캐시, 프로필 사본, 이 기기의 일기 초안. 기기 플래그는 남깁니다(spec §9 "초안") |
| fake 연결·합치기 규칙 | 대역 서버의 처음 연결은 `[kakao]`(fake 시나리오 회원). `google` 붙이기는 409 `auth.identity_in_use`, 나머지는 201. 떼기는 마지막이면 409 `auth.last_identity`. 합치기 인증은 이 계정에 이미 연결된 제공자면 422 `merge.same_account`(처음엔 카카오, 붙인 뒤엔 그 제공자도), Apple 422 `merge.no_account`, 그 밖(연결하지 않은 LINE·Google)은 요약 200(`diaries` 2, `schedules` 0, `overlapDays` 1, `addedDays.adFree` 12, `current`는 시나리오 프로필, `other`는 호칭 "다른 계정"). `mergeAccounts`는 시나리오 `Me`. 시나리오 `merge-token-invalid`는 `mergeAccounts`가 422 `merge.token_invalid`, `merge-in-progress`는 처음 한 번 409 `idempotency.in_progress` |

## Global Constraints

* 기반·계획 2~6 plan의 Global Constraints를 모두 따릅니다(경고 0, 생성 코드 손대지 않음, 토큰은 의미 역할로만, 화면 `Semantics.identifier`는 IA id, `const new` 생성자 문법).
* 제공자에게는 언제나 `hashNonce(rawNonce)`, server에는 원문(spec §5 공통). 원문 nonce·id_token·교환 코드·합치기 토큰은 로그·`CrashReporter`에 싣지 않습니다(D64). 오류 보고는 `CrashSummary.from(error)`만 씁니다.
* SDK 경계 구현(기본값)은 SDK 호출을 그대로 옮기기만 하고 분기가 없습니다. 분기는 adapter에 두고 테스트합니다(spec §3).
* 설정이 비면 adapter는 `signIn`에서 `ProviderNotConfigured`를 던집니다. 버튼은 숨기지 않습니다.
* http 모드에서 로그인 adapter의 대역을 쓰지 않습니다. fake 모드(`ApiMode.fake`)는 지금처럼 대역입니다.
* 이메일·프로필 scope를 어느 제공자에게도 요청하지 않습니다(D82 ④).
* 확인 dialog 없이는 떼기·합치기를 부르지 않습니다(D82 ⑥).
* 연결 409는 합치기로 넘기지 않습니다(D85 ③). 합치기는 언제나 합치기 입구에서 시작합니다.
* 합치기는 토큰을 바꾸지 않습니다. 남는 계정은 언제나 지금 계정입니다(D85 ④, 계약 `mergeAccounts`).
* 로그인 버튼 순서: ko `kakao, line, google, apple`, ja `line, kakao, google, apple`, en과 그 밖의 언어 `google, kakao, line, apple`.
* D90 ③ 로그인 갈래(A79)는 `LoginController` 정리 뒤에도 그대로입니다.
* 계약 파일을 읽는 테스트는 `@Tags(['contract'])`입니다.

## Review Focus

1. 붙이기가 진행 중일 때 다른 줄의 붙이기·떼기나 합치기 입구를 누르면 새 요청이 나가지 않고, 진행 중인 결과 하나만 반영됩니다(로그인 화면의 진행 중 규칙과 같음).
2. Google 로그인과 붙이기가 거의 동시에 처음 불려도 `initialize`는 한 번만 불리고, 둘 다 같은 프로세스 nonce를 돌려줍니다.
3. 합치는 동안 app-bar·시스템 뒤로 가기가 모두 막히고, 409 `idempotency.in_progress`·응답 없음에서 같은 `Idempotency-Key`로 다시 보냅니다. 키는 (`mergeToken`, `profile`) 조합마다 하나이고, 같은 조합으로 다시 확정하면 같은 키입니다.
4. 응답 없음 뒤 같은 토큰·본문·키 재전송이 200이면 성공 갈래, 422 `merge.token_invalid`면 `errorMergeTokenInvalid`와 인증 단계로 갑니다(S115). 토큰 저장소는 어느 갈래에서도 바뀌지 않습니다.
5. 지원하지 않는 언어(예 `zh`)이거나 국가 코드가 붙은 로케일(`ja_JP`)이어도 버튼 순서가 정해집니다(en·ja 규칙).
6. 로그인·붙이기·합치기 인증 모두 id_token을 받은 뒤 SDK 세션을 바로 정리하고, LINE·Google 제공자 허가는 어디서도 취소하지 않습니다(A82, D95).

---

## 단계 A. 실제 로그인

### Task 1: 결정 기록, 설정 파일, `AuthConfig`

**Files:**
- Modify: `app/docs/decisions.md`(A80~A85 추가, A12 행에 "→ A80으로 갱신")
- Create: `app/config/auth.json`(spec §4 값 그대로, 모두 빈 문자열)
- Create: `app/lib/core/platform/auth_config.dart`
- Modify: `app/lib/core/platform/social_auth.dart`(`ProviderNotConfigured` 추가)
- Modify: `app/README.md`(실행 명령에 `--dart-define-from-file=config/auth.json`), `app/tool/patrol_local.sh`, `.github/workflows/app.yml`(`flutter build apk --debug`와 `patrol test`에 같은 옵션)
- Test: `app/test/core/auth_config_test.dart`

**Interfaces:**
- Produces:
  - `final class AuthConfig { const new({required String kakaoNativeAppKey, required String lineChannelId, required String googleIosClientId, required String googleServerClientId, required String appleServicesId, required String appleRedirectUri, required String appLinkHost}); static const AuthConfig fromEnvironment; bool get isKakaoConfigured; bool get isLineConfigured; bool isGoogleConfigured({required bool ios}); bool get isAppleWebConfigured; }`
  - `final authConfigProvider = Provider<AuthConfig>((ref) => AuthConfig.fromEnvironment);`(`platform_providers.dart`)
  - `final class ProviderNotConfigured implements Exception { const new(this.provider); final SocialProvider provider; }`. `SocialProvider`(이미 `kakao`·`line`·`google`·`apple`)를 이 task에서 `lib/core/platform/social_provider.dart`로 옮기고 `social_login_button.dart`가 export합니다. 화면·adapter·repository가 같은 enum을 씁니다(spec §3 "`SocialProvider` 위치"를 플랫폼 계층으로 내림. 플랫폼 코드가 design을 import하지 않게 하려는 것)

- [ ] **Step 1: 실패하는 테스트 작성**: `AuthConfig 빈 값은 모든 제공자가 설정 안 됨`, `isGoogleConfigured는 ios면 iOS client id도 봅니다`(server만 채우면 android true·ios false), `isAppleWebConfigured는 셋 중 하나라도 비면 false`.
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/core/auth_config_test.dart`. Expected: FAIL(`AuthConfig` 없음).
- [ ] **Step 3: 구현**: `fromEnvironment`는 키마다 `String.fromEnvironment('<JSON 키>')`. 판정은 `trim().isNotEmpty`.
- [ ] **Step 4: 결정 기록**(A1): spec §11의 A80~A85를 표 형식 그대로 옮깁니다(A85는 위 "이 계획이 정하는 것"의 문구 행).
- [ ] **Step 4a: A1 몫 확인과 Commit**(A1): `SocialProvider`를 `lib/core/platform/social_provider.dart`로 옮기고(`social_login_button.dart`가 export) `flutter analyze` 경고 0, `flutter test test/design test/features/auth --exclude-tags golden` PASS. Commit `refactor(app): SocialProvider를 플랫폼 계층으로, 결정 A80~A85 기록`. 나머지 Step 1~3·5·6은 A2입니다.
- [ ] **Step 5: 실행해 통과 확인**: 같은 명령 PASS, `flutter analyze` 경고 0.
- [ ] **Step 6: Commit** `feat(app): 로그인 제공자 설정 파일과 AuthConfig (A81)`

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
- [ ] **Step 6: Commit** `build(app): 로그인 SDK 다섯과 Android·iOS 네이티브 설정 (A80·A81·A83)`

### Task 3: LINE·Google interface와 대역

**Files:**
- ~~Modify: `app/lib/core/platform/social_provider.dart`(enum에 `line`·`google`)~~ **끝남**(enum은 이미 넷)
- Modify: `app/lib/core/platform/social_auth.dart`, `app/lib/core/platform/fakes.dart`, `app/lib/core/platform/platform_providers.dart`
- ~~Modify: `login_screen.dart`의 `_signIn` switch~~ **끝남**(`line`·`google` 갈래는 `StateError`로 이미 있음, Task 7이 지움)
- ~~Modify: `social_login_button.dart`(switch에 `line`·`google`)~~ **끝남**(design 3.0.0 값까지)
- Test: `app/test/core/platform_fakes_test.dart`

**Interfaces:**
- Produces:
  - `final class LineCredential { const new({required String idToken}); }`, `abstract interface class LineAuth { Future<LineCredential> signIn({required String rawNonce}); }`
  - `final class GoogleCredential { const new({required String idToken, required String rawNonce}); }`, `abstract interface class GoogleAuth { Future<GoogleCredential> signIn({required String rawNonce}); }`(돌려준 `rawNonce`를 server에 보냄)
  - `FakeLineAuth`, `FakeGoogleAuth`(`FakeKakaoAuth`와 같은 모양: `failWith`, `providerNonces`. Google 대역은 받은 `rawNonce`를 그대로 credential에 넣음)
  - `lineAuthProvider`, `googleAuthProvider`(기본값 대역)
  - ~~`keepSession`, `ProviderRevoker`~~ **지움**(D95, spec §5.6)

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
- [ ] **Step 3: 구현**: 취소 판정은 `PlatformException.code`(`'CANCELED'`, `'CANCEL'`). 세션 정리 실패는 삼킵니다(A82).
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령 PASS.
- [ ] **Step 5: Commit** `feat(app): 카카오·LINE 실제 로그인 adapter (A82·A83)`

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
- [ ] **Step 5: Commit** `feat(app): Google 실제 로그인 adapter, 프로세스 nonce (A83)`

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
- [ ] **Step 5: Commit** `feat(app): Apple iOS·Android 웹 실제 로그인 adapter (A80)`

### Task 7: 제공자 인증 경계, 로그인 합치기, 부팅 끼우기

**Files:**
- Create: `app/lib/features/auth/application/provider_authenticator.dart`
- Modify: `app/lib/features/auth/data/auth_repository.dart`, `app/lib/features/auth/application/login_controller.dart`, `app/lib/features/auth/presentation/login_screen.dart`(`controller.signIn(provider, …)` 하나로)
- Modify(A2): `app/lib/app/bootstrap.dart`(`realPlatformOverrides(ApiMode.http)`에 adapter 다섯, 설정이 있으면 `KakaoSdk.init`·`LineSDK.instance.setup`)
- Test: `app/test/features/auth/provider_authenticator_test.dart`, `app/test/features/auth/login_controller_test.dart`(수정), `app/test/app/bootstrap_test.dart`(있으면 수정, 없으면 만듦)

**Interfaces:**
- Consumes: A1은 Task 3의 interface·대역, A2는 Task 4~6의 실제 adapter
- Produces:
  - 위치: `ProviderProof`와 그 하위 타입은 `lib/features/auth/model/provider_proof.dart`에 둡니다(`features/account`가 `features/auth/application`을 import하지 않도록 layering 검사 때문에 model로 뺌). `ProviderAuthenticator`는 `lib/features/auth/application/provider_authenticator.dart`.
  - `sealed class ProviderProof { SocialProvider get provider; String get rawNonce; }`, `final class IdTokenProof extends ProviderProof { const new({required SocialProvider provider, required String idToken, required String rawNonce, String? authorizationCode}); }`, `final class AppleWebExchangeProof extends ProviderProof { const new({required String exchangeCode, required String rawNonce}); }`
  - `final class ProviderAuthenticator { const new(Ref ref); Future<ProviderAuthResult> authenticate(SocialProvider provider, {required String rawNonce}); }`. `sealed class ProviderAuthResult`: `ProviderAuthenticated(ProviderProof proof)`, `ProviderAppleWebFailed(AppleWebError error)`. 취소는 `SocialSignInCancelled`를 던짐
  - `final providerAuthenticatorProvider = Provider<ProviderAuthenticator>(ProviderAuthenticator.new);`
  - `AuthRepository.login(ProviderProof proof) → Future<LoginResponse>`(기존 `kakao`·`appleNative`·`appleWeb`은 private로. `line`·`google`은 `loginLine`·`loginGoogle`)
  - `LoginController.signIn(SocialProvider provider, {DiscardNotice? showDiscardNotice}) → Future<LoginOutcome>`(`signInWithKakao`·`signInWithApple` 삭제). 처음 초안의 `SessionEntry` 분리는 하지 않습니다(합치기가 토큰을 바꾸지 않아 쓰는 곳이 없음). `_Session`과 A79 갈래는 그대로입니다

- [ ] **Step 1: 실패하는 테스트 작성**:
  - authenticator: `apple은 Android면 웹, iOS면 네이티브 adapter`, `카카오·LINE credential → IdTokenProof(같은 rawNonce)`, `Google은 credential의 rawNonce를 proof에 넣습니다`, `Apple 웹 교환 → AppleWebExchangeProof`, `Apple 웹 실패 → ProviderAppleWebFailed`, `취소는 SocialSignInCancelled를 그대로`
  - repository: `IdTokenProof(kakao) → loginKakao`, `IdTokenProof(line) → loginLine`, `IdTokenProof(google) → loginGoogle`, `IdTokenProof(apple, authorizationCode) → loginApple`, `AppleWebExchangeProof → completeAppleWebLogin`
  - controller: 기존 카카오·Apple 테스트를 `signIn(SocialProvider.x)`로 옮기고 모두 그대로 통과(A79 미리보기 입력 저장 갈래 포함). 더할 것: `line·google 로그인 성공은 카카오와 같은 진입 계산`, (A2) `ProviderNotConfigured는 LoginFailed(UnexpectedError)이고 오류 요약을 보고합니다`
  - 부팅(A2): `realPlatformOverrides(http)는 다섯 provider를 실제 구현으로`, `fake는 대역`(spec §12 "부팅")
- [ ] **Step 2: 실행해 실패 확인**(A1): `flutter test test/features/auth`. Expected: FAIL. 부팅 테스트(`test/app`)는 A2 마무리에서 돌립니다.
- [ ] **Step 3: 구현**: 진행 중 재호출·nonce 규칙은 그대로입니다. 대역 서버(`FakeServer`)가 `loginLine`·`loginGoogle`을 `loginKakao`와 같은 fixture 규칙으로 답하게 합니다.
- [ ] **Step 4: 실행해 통과 확인**(A1): `flutter test test/features/auth test/flows`(로그인 흐름 회귀 포함) PASS.
- [ ] **Step 5: Commit**(A1) `feat(app): 제공자 인증 경계와 로그인 합치기 (A84)`. A2의 부팅 끼우기는 A2 마무리 commit에 담습니다.

### Task 8: 로그인 화면 네 버튼

**Files:**
- Create: `app/lib/features/auth/model/login_provider_order.dart`
- ~~Modify: `social_login_button.dart`(`line`·`google` 그리기), `assets/brand/line/`·`assets/brand/google/`, `pubspec.yaml`(assets), `widgetbook/lib/action_directory.dart`, `test/design/action_golden_test.dart`~~ **끝남**(design 3.0.0 값, 공식 로고 자산, golden·widgetbook)
- ~~Modify: ARB `loginLineLabel`·`loginGoogleLabel` 임시~~ **끝남**(writing 원고 키)
- Modify: `app/lib/features/auth/presentation/login_screen.dart`
- Test: `app/test/features/auth/login_provider_order_test.dart`, `app/test/features/auth/login_screen_test.dart`(있으면 수정)

**Interfaces:**
- Produces: `List<SocialProvider> loginProviderOrder(Locale locale)`(`lib/features/auth/model/login_provider_order.dart`, `features/account`가 `features/auth/presentation`을 import하면 layering 검사에 걸려 model에 둠). `login-methods`·`account-merge` 인증 단계도 같은 함수를 씁니다

- [ ] **Step 1: 실패하는 테스트 작성**:
  - 순서: `ko → kakao, line, google, apple`, `ja → line, kakao, google, apple`, `en → google, kakao, line, apple`, `zh와 ja_JP`(Review Focus 5: `zh`는 en 순서, `ja_JP`는 ja 순서)
  - 화면: `네 버튼이 앱 언어 순서대로 같은 크기`, `한 버튼이 처리 중이면 나머지 셋이 꺼짐`, `LINE을 누르면 controller.signIn(line)`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/auth`. Expected: FAIL.
- [ ] **Step 3: 구현**: 화면만 고칩니다. 버튼 값은 컴포넌트가 이미 갖고 있습니다.
- [ ] **Step 4: 실행해 통과 확인**: `flutter test test/features/auth test/contract --exclude-tags golden` PASS. 로그인 화면 golden이 있으면 `tool/goldens_linux.sh <그 파일> --update-goldens` 뒤 갱신 없이 PASS.
- [ ] **Step 5: Commit** `feat(app): 로그인 화면 네 버튼과 언어별 순서 (D82 ①)`

## 단계 B. 로그인 수단·계정 합치기

### Task 9: 연결·합치기 데이터 경계와 대역 서버

**Files:**
- Create: `app/lib/features/account/data/account_link_repository.dart`
- Modify: `app/lib/core/api/fake/fake_server.dart`(연결 목록 메모리 상태와 `listIdentities`·`linkIdentity`·`unlinkIdentity`·`previewMerge`·`mergeAccounts`), `app/fixtures/<시나리오>/`(요약·`Me` fixture, 시나리오 `merge-token-invalid`·`merge-in-progress`), `app/README.md`(fake 시나리오 표)
- Test: `app/test/features/account/data/account_link_repository_test.dart`, `app/test/core/api/fake_server_account_test.dart`

**Interfaces:**
- Consumes: `ProviderProof`(Task 7), 생성 클라이언트 `DefaultApi`(REST 1.1.0)
- Produces:
  - `final class AccountLinkRepository { const new(DefaultApi api); Future<List<SocialProvider>> methods(); Future<List<SocialProvider>> link(ProviderProof proof); Future<void> unlink(SocialProvider provider); Future<MergePreview> preview(ProviderProof proof); Future<Me> merge({required String mergeToken, required MergeProfile profile, required String idempotencyKey}); }`. 실패는 `AppError`(`appErrorFrom`). 모르는 `LoginProvider`는 건너뜁니다
  - `final accountLinkRepositoryProvider = Provider<AccountLinkRepository>(...)`(두 모드 모두 생성 클라이언트, fake 모드는 대역 서버가 답함)

- [ ] **Step 1: 실패하는 테스트 작성**:
  - repository: `kakao·line·google IdTokenProof → idToken·nonce`, `apple iOS → idToken·authorizationCode·nonce`, `Apple 웹 → exchangeCode·nonce`(`linkIdentity`·`previewMerge` 모두, `previewMerge`는 `provider` 포함), `IdentityList의 모르는 provider는 건너뜁니다`, `409 auth.identity_in_use는 AppError code 그대로`, `merge는 Idempotency-Key 헤더와 {mergeToken, profile}`
  - 대역 서버: "이 계획이 정하는 것"의 fake 규칙대로(처음 `[kakao]`, google 409, 마지막 떼기 409, 합치기 인증 세 갈래, 시나리오 두 개)
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/account test/core/api`. Expected: FAIL.
- [ ] **Step 3: 구현**.
- [ ] **Step 4: 실행해 통과 확인**: PASS. fixture를 더했으면 fixture 검증과 `flutter test --tags contract` PASS.
- [ ] **Step 5: Commit** `feat(app): 로그인 수단 연결·합치기 데이터 경계와 대역 서버 (A84)`

### Task 10: `account-choice` 컴포넌트 — **끝남**

`app/d83-diary`(2.7.0)와 `app/d85-d88`(3.0.0: 알약 `current`·`other`, `otherLabel`, `facts`·`diaryCount`·`providers` 삭제, 처음엔 고르지 않음)에서 컴포넌트·golden·widgetbook·contract 대조까지 끝났습니다. Task 12가 그대로 씁니다.

### Task 11: `login-methods` 화면과 설정 줄

**Files:**
- Create: `app/lib/features/account/application/login_methods_controller.dart`, `app/lib/features/account/presentation/login_methods_screen.dart`
- Modify: `app/lib/features/me/presentation/settings_screen.dart`(줄과 `settingsExits`에 `ScreenIds.loginMethods`), `app/lib/app/router/screen_registry.dart`, `app/test/contract/ia_pending.dart`(`settings`·`login-methods` 지움)
- Test: `app/test/features/account/login_methods_screen_test.dart`, `app/test/features/account/login_methods_controller_test.dart`

**Interfaces:**
- Consumes: `ProviderAuthenticator`, `AccountLinkRepository`, `loginProviderOrder`, `SocialLoginButton`, `PrimaryButton` `quiet`
- Produces:
  - `class LoginMethodsController extends AsyncNotifier<List<SocialProvider>>`, `Future<LinkAttempt> link(SocialProvider provider)`, `Future<UnlinkAttempt> unlink(SocialProvider provider)`. `sealed class LinkAttempt`: `LinkDone()`, `LinkInUse()`(409 `auth.identity_in_use`·`auth.provider_taken`), `LinkFailed()`. `sealed class UnlinkAttempt`: `UnlinkDone()`, `UnlinkFailed()`
  - `final loginMethodsControllerProvider`(autoDispose)
  - `const Set<String> loginMethodsExits = {ScreenIds.accountMerge}`, `const Set<String> loginMethodsHandledStates = {'error'}`

- [ ] **Step 1: 실패하는 테스트 작성**:
  - controller: `link 성공이면 응답 목록으로 갱신`, `409 identity_in_use·provider_taken은 LinkInUse이고 목록 그대로`, `401 provider_token_invalid는 LinkFailed이고 로그아웃하지 않습니다`, `취소·Apple 웹 실패·AppError는 LinkFailed`, `진행 중에 다시 link·unlink를 부르면 새 요청 없이 진행 중인 결과`(Review Focus 1), `unlink는 unlinkIdentity 뒤 목록을 다시 읽고, 어느 제공자도 허가 취소를 부르지 않음`(D95), `409 last_identity는 UnlinkFailed`, `404 identity_not_found는 목록만 다시 읽음`
  - 화면: `네 줄이 loginProviderOrder 순서`, `연결된 줄은 connected(연결됨)`, `연결 안 된 줄은 그 제공자 로그인 버튼`, `하나만 연결이면 그 줄이 꺼지고 last.notice`, `떼기는 dialog 확인 뒤에만 unlink`, `LinkInUse면 in-use.body dialog notice이고 이 화면에 남음(account-merge로 가지 않음)`, `실패하면 errorBodyLink·errorBodyUnlink`, `합치기 입구는 가로선 아래 quiet 버튼이고 늘 보이며 누르면 account-merge`, `account-merge에서 돌아오면 목록을 다시 읽음`
  - 설정: `로그인 수단 줄을 누르면 login-methods`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/account test/features/me`. Expected: FAIL.
- [ ] **Step 3: 구현**: 붙이기 nonce는 시도마다 `nonceGeneratorProvider`로 만듭니다.
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령과 `flutter test --tags contract` PASS(IA ratchet이 `settings`·`login-methods`를 확인).
- [ ] **Step 5: Commit** `feat(app): 설정 > 로그인 수단 화면 (D82 ⑤, D85 ③)`

### Task 12: `account-merge` 화면 (두 단계)

**Files:**
- Create: `app/lib/features/account/application/account_merge_controller.dart`, `app/lib/features/account/presentation/account_merge_screen.dart`, `app/lib/features/account/presentation/merge_summary_box.dart`(가져올 기록·구매 상자, 컴포넌트 아님)
- Modify: `app/lib/app/router/screen_registry.dart`, `app/test/contract/ia_pending.dart`(`account-merge` 지움. 두 집합이 빔)
- Test: `app/test/features/account/account_merge_screen_test.dart`, `app/test/features/account/account_merge_controller_test.dart`

**Interfaces:**
- Consumes: `ProviderAuthenticator`, `AccountLinkRepository`, `AccountChoice`, 캐시 정리(`SignOutCleaner`의 계정 캐시·초안 지우기를 함수로 떼어 씀, 기기 플래그 제외), `meProvider`·진입 계산
- Produces:
  - `class AccountMergeController extends Notifier<AccountMergeState>`, `final accountMergeControllerProvider = NotifierProvider.autoDispose<AccountMergeController, AccountMergeState>(AccountMergeController.new)`(Riverpod 3.x). 상태: `MergeAuth(busy: SocialProvider?)`, `MergeSummaryLoading`, `MergeChoosing(preview, selected: MergeProfile?)`, `MergeRunning(preview, selected)`. 동작: `Future<MergeAuthOutcome> authenticate(SocialProvider provider)`(`MergeAuthDone`·`MergeNotOther(selfOrNone)`·`MergeAuthFailed`·`MergeAuthCancelled`), `void choose(MergeProfile profile)`, `Future<MergeOutcome> merge()`(`MergeDone`·`MergeTokenInvalid`·`MergeFailed`). 그만두기는 화면을 떠나 autoDispose로 상태(합치기 토큰)를 버리는 것이고, 정리할 SDK 세션이 없어 `abandon()`은 두지 않습니다(D95)
  - `const Set<String> accountMergeExits = {ScreenIds.loginMethods}`, `const Set<String> accountMergeHandledStates = {'loading', 'error'}`

- [ ] **Step 1: 실패하는 테스트 작성**:
  - controller:
    - `authenticate는 인증하고 previewMerge`, `422 same_account → MergeNotOther(self)`, `422 no_account → MergeNotOther(none)이고 linkIdentity를 부르지 않음`, `그 밖의 실패 → MergeAuthFailed`
    - `merge의 Idempotency-Key는 (mergeToken, profile) 조합마다 하나이고 같은 조합 재확정은 같은 키`, `409 idempotency.in_progress면 1초 뒤 같은 키로 다시(최대 5번)`, `응답 없음이면 같은 토큰·본문·키로 한 번 다시`, `재전송이 200이면 MergeDone`(S115), `재전송이 422 token_invalid면 MergeTokenInvalid이고 getMe를 부르지 않음`, `첫 요청 422 token_invalid도 MergeTokenInvalid`, `성공이면 캐시와 일기 초안을 지우고 meProvider를 응답 Me로·진입 다시 계산`, `어느 갈래에서도 토큰 저장소를 바꾸지 않음`(Review Focus 4), `어느 갈래에서도 허가 취소를 부르지 않음`(D95), `일기 초안도 지움`(기기 플래그는 남음)
  - 화면:
    - 인증 단계: `제목·auth.body·네 버튼(loginProviderOrder)`, `누른 버튼만 loading`, `not-other 두 갈래 dialog notice 뒤 인증 단계`, `요약 실패 accountMergeError dialog 뒤 인증 단계`
    - `loading`: `요약 상자·카드 자리 숨쉬기`
    - 요약·고르기: `title.body`, `상자 줄 순서 일기 → 일정 → 광고 제거`, `일기·일정 0이어도 보임`, `adFree 0이면 광고 제거 줄 없음`, `overlapDays 0이면 overlap.notice 없음, 1 이상이면 있음(고르기와 무관)`, `account-choice A → B, 처음엔 고르지 않음`, `고르기 전 합치기 버튼 disabled`, `status none 카드는 accountChoiceSajuEmpty`
    - 합치기: `확인 dialog destructive 뒤에만 merge`, `합치는 동안 버튼 loading·카드 disabled·뒤로 가기(app-bar·시스템) 막힘`(Review Focus 3), `완료 → login-methods(진입 계산이 회원 갈래일 때), 그 밖의 진입 갈래면 그 화면이 우선`, `MergeTokenInvalid → errorMergeTokenInvalid dialog 뒤 인증 단계`, `MergeFailed → accountMergeError dialog, 고름 유지`
    - `"합치지 않기" 버튼 없음, 뒤로 가기는 어느 단계에서든 login-methods이고 합치기 토큰을 버림`
- [ ] **Step 2: 실행해 실패 확인**: `flutter test test/features/account`. Expected: FAIL.
- [ ] **Step 3: 구현**: 확인 dialog는 `showMyungliConfirm` 계열(`dialog` `destructive`). 뒤로 가기 막기는 `PopScope(canPop: false)`와 app-bar 뒤로 버튼 비활성. 완료·그만두기 이동은 `context.pop()`(login-methods가 목록을 다시 읽음). 사용자에게 보이는 글자를 조립하지 않고 ARB 키만 씁니다(#546).
- [ ] **Step 4: 실행해 통과 확인**: 같은 명령과 `flutter test --tags contract` PASS.
- [ ] **Step 5: Commit** `feat(app): 계정 합치기 두 단계 화면 (D85 ④, V44)`

### Task 13: 끝에서 끝 흐름, 커버리지, 문서

**Files:**
- Create: `app/test/flows/login_methods_flow_test.dart`, `app/patrol_test/account_test.dart`(`test_bundle.dart` 갱신)
- Modify: `app/tool/coverage_baseline.json`(도구가 갱신), `app/README.md`(fake 연결·합치기 규칙), `app/CLAUDE.md`(현재 상태·다음 할 일), 화면 스크린샷 등록(`tool/register_screenshots.dart`, 계획 6과 같은 절차)

- [ ] **Step 1: 흐름 테스트 작성**: fake 회원으로 `settings → login-methods → LINE 붙이기(목록에 LINE) → Google 붙이기(in-use dialog, 화면에 남음) → 합치기 입구 → account-merge 인증(연결하지 않은 Google) → 요약 → 다른 계정 프로필 고름 → 확인 → login-methods`. 토큰이 그대로이고 `meProvider`가 응답 `Me`인지 확인합니다.
- [ ] **Step 2: 실행해 통과 확인**: `flutter test test/flows/login_methods_flow_test.dart` PASS.
- [ ] **Step 3: Patrol**: 같은 흐름을 `patrol_test/account_test.dart`로 만들고 `tool/patrol_local.sh patrol_test/account_test.dart`. Expected: 종료 코드 0. 로그인 흐름 회귀로 `tool/patrol_local.sh patrol_test/login_test.dart`도 0.
- [ ] **Step 4: 커버리지**: `dart run tool/ia_coverage.dart --check` 통과(새 경로 `settings>login-methods`, `login-methods>account-merge`, `account-merge>login-methods`와 상태).
- [ ] **Step 5: 전체 검사**(PR 직전): `flutter analyze`(app·widgetbook), `dart analyze`, `flutter test --exclude-tags golden`, `dart format --set-exit-if-changed lib test tool widgetbook/lib patrol_test`, `tool/goldens_linux.sh`, 생성물 차이 없음. 모두 통과. `gen_native_config --check`는 A2 마무리에서 더합니다.
- [ ] **Step 6: 문서**(A1 기준): `app/CLAUDE.md` 현재 상태에 계획 7 A1(화면·대역, 단계 B와 그 경계)을 적고, 다음 할 일에 A2 몫(진행 순서 표), 실기기 확인 목록(spec §12), #347 ②, 수익 쪽 과제(spec §14: RevenueCat `Purchases.sync()`·iOS sandbox 확인, `products()` 시간 한계, `AD_FREE_PRODUCT_IDS` 배선, `adFreeBuyCta` #548)를 남깁니다.
- [ ] **Step 7: 알림**:
  - ~~Google nonce 제약 Issue~~ #555로 답을 받았습니다(재사용 허용). ~~LINE `logout`·deauthorize 확인~~ D95로 필요 없어졌습니다.
  - #311·#387에 반영 범위를 남깁니다(#311은 ③ release 지문 때문에 열어 둠).
- [ ] **Step 8: Commit** `test(app): 로그인 수단·계정 합치기 흐름과 Patrol, 현재 상태 갱신`

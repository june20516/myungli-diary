# 실제 로그인 adapter와 로그인 수단·계정 합치기 설계

* 작성: app 세션, 2026-10-21 (D82 범위 반영 2026-10-22, D83 ④ 합치기 일기 정정 2026-10-22, **D85·REST 1.0.0 개정 2026-10-23**, **D95·REST 1.1.0 개정 2026-10-27**)
* 상태: 초안 (설계 대화 승인 2026-10-21·2026-10-22, 2026-10-23 개정은 [D85·D88 따라잡기 spec](2026-10-23-d85-d88-design.md) §7)
* 요청: Issue #311 (#100 ⑥, #114 ①④⑤의 남은 일), #387 (D82 범위 확장, D83 ④ 정정 코멘트), #484 (D85 연결 거절·합치기 별도 흐름·삭제 복구 없음)
* 관련 결정: app A12(이 spec이 A80으로 갱신), A80~A85(새로 기록. 처음 초안 번호는 일기 결정과 겹쳐 §11에서 다시 매김), A73·A74·A79(`app/d85-d88`에서 정함), 루트 D49·D53·D55·D64·D82·D83·D85·D88·D90·D95, server S15·S22·S99~S101·S105·S110·S111·S114·S115
* 쓰는 계약: REST API `server/api/openapi.yaml` `1.1.0`(1.0.0 freeze S114 뒤 하위 호환 추가, S115·S116. `loginKakao`·`loginApple`·`completeAppleWebLogin`·`loginLine`·`loginGoogle`·`listIdentities`·`linkIdentity`·`unlinkIdentity`·`previewMerge`·`mergeAccounts`·`getMe`·`deleteMe`), server spec `2026-10-13-apple-web-callback-design.md`, IA 화면 `login`·`settings`·`login-methods`·`account-merge`, design 컴포넌트 3.0.0(`social-login-button`·`account-choice`·`primary-button`·`dialog`, V39·V44), writing ARB(W39·W40·W42)
* 기다리는 계약: 없습니다. 처음 초안이 기다리던 server #386(draft.14)·#407 ④(draft.15 `MergeSummary`)는 REST 1.0.0에 포함됐고, design #389는 컴포넌트 2.7.0·3.0.0, writing #388은 W39·W40·W42 원고로 왔습니다.

## 1. 목적과 범위

로그인을 대역에서 실제 제공자 넷(카카오·LINE·Google·Apple, D82 ①)으로 바꾸고, 한 계정에 인증 계정을 붙이고 떼는 로그인 수단 화면과, 다른 유저 계정의 기록·구매를 가져오는 계정 합치기 화면을 만듭니다(D85 ③④).

카카오·Apple 인터페이스(`KakaoAuth`·`AppleNativeAuth`·`AppleWebAuth`), nonce 규칙(`NonceGenerator`·`hashNonce`), authorize URL과 복귀 해석(`buildAppleAuthorizeUri`·`parseAppleWebReturn`), 로그인 흐름(`LoginController`)은 이미 있습니다. 이 spec은 다음을 다룹니다.
* 네 제공자의 실제 adapter, 설정값 주입, 네이티브 설정(§3~§5)
* 로그인·붙이기·합치기 인증이 함께 쓰는 제공자 인증 경계(§6)
* 로그인 화면의 네 버튼(§7), 로그인 수단 화면(§8), 계정 합치기 화면(§9)

LINE·Google 제공자 허가는 app이 취소하지 않습니다(D95, §5.6).

**이미 끝난 일(`app/d85-d88`·`app/d83-diary`, 2026-10-23 기준)**
* 컴포넌트 `social-login-button`(카카오·LINE·Google·Apple, `connected`, 공식 로고 자산, 3.0.0 값)과 `account-choice`(3.0.0: 알약 `current`·`other`, `otherLabel`, 처음엔 고르지 않음), golden·widgetbook.
* REST 1.0.0 생성 클라이언트(draft.14·draft.15 변경은 1.0.0에 포함). LINE·Google 로그인, 연결·떼기, 합치기 operation과 모델이 있습니다.
* 계정 삭제 204 처리(A73)와 삭제 대기 갈래 삭제. `LoginResponse`에는 `tokens`·`isNewAccount`·`consentRequired`만 있습니다.
* 화면 문구 problem code(A74): `merge.same_account`·`merge.no_account`는 `problemMessages` 밖 `_screenMessages`(화면이 `accountMergeNotOtherBodySelf`·`accountMergeNotOtherBodyNone`을 씀), `merge.token_invalid`는 `problemMessages`의 `errorMergeTokenInvalid`.
* 로그인 뒤 동의·사주 없는 계정의 갈래(D90 ③, A79): 미리보기 입력이 있으면 로그인 화면이 저장하고 `notify-ask`로 갑니다. §6의 `LoginController` 정리는 이 갈래를 그대로 둡니다.
* 로그인 수단·계정 합치기 문구: writing 원고 키가 ARB에 있습니다(`loginLineLabel`·`loginGoogleLabel`, `loginProvider*`, `loginMethods*`, `accountMerge*`, `accountChoice*`). 지금 원고 키가 모두 있어 임시 키를 만들지 않았습니다. 원고 없는 자리가 새로 나오면 A85대로 합니다.

**성공 기준**
* fake 모드와 기존 테스트·Patrol 흐름이 그대로 통과합니다.
* 실제 adapter의 로직(nonce 전달, 취소·실패 변환, 카카오톡 → 계정 전환, SDK 세션 정리, 설정 없음)은 SDK 없이 단위 테스트로 검증합니다.
* 외부 준비물(카카오 앱, LINE 채널, Google OAuth client, Apple Services ID, 서비스 도메인)이 생기면 `app/config/auth.json` 값만 채워 실기기에서 로그인할 수 있습니다.
* 로그인 수단·계정 합치기 화면은 fake 모드(대역 서버)로 IA 상태·출구를 모두 지나고, `ia_pending.dart`에서 `settings`·`login-methods`·`account-merge`가 빠집니다.

**다루지 않는 것**
* FCM과 알림 기기 호출 시점(#347 ②), AdMob·Crashlytics adapter: 계획 7의 다른 부분입니다. RevenueCat adapter 과제는 §14에 모읍니다.
* release·Play App Signing 서명 지문과 스토어 URL(#311 ③): Google Play 개발자 계정이 생긴 뒤입니다. 패키지 이름과 debug 지문은 #114에 이미 남겼습니다.
* server 설정(`APP_LINK_BASE`, `assetlinks.json`)과 도메인 구입: server와 사용자 몫입니다.

**화면 문구 규칙:** 사용자에게 보이는 글자(ARB 값, 화면에서 조립하는 글자)에는 긴 대시(U+2014)·범위 대시(U+2013)·가운뎃점(U+00B7)을 쓰지 않습니다(사용자 지시, Issue #546). 화면이 글자를 이어 붙여야 하면 writing 구분자 키를 씁니다. 이 문서 본문의 가운뎃점은 해당하지 않습니다.

## 2. 전제 (확인한 사실, 2026-10-21~22)

* 외부 준비물은 아직 없습니다(`docs/roadmap.md` 외부 준비물). 그래서 값은 빈 문자열로 두고, 비어 있으면 "설정 안 됨"으로 동작합니다.
* Flutter 3.47.7, Android `minSdk`는 `flutter.minSdkVersion`(24)입니다.
* `kakao_flutter_sdk_user` 2.0.1: `loginWithKakaoTalk`·`loginWithKakaoAccount`가 `nonce`를 받습니다. 취소는 `PlatformException(code: 'CANCELED')`입니다(`kakao_flutter_sdk_auth`의 `TalkAuthCodeActivity`·`CustomTabsActivity`). 계정 로그인 redirect는 SDK manifest의 `AuthCodeHandlerActivity`가 받습니다.
* `sign_in_with_apple` 8.2.0: `getAppleIDCredential(nonce:)`는 받은 값을 그대로 identity token에 넣습니다. 그래서 해시를 넘깁니다. 취소는 `SignInWithAppleAuthorizationException`의 `AuthorizationErrorCode.canceled`입니다.
* `flutter_web_auth_2` 5.1.0:
  * Android는 Chrome Auth Tab을 쓰고, 지원하지 않는 브라우저에서는 Custom Tabs로 대체합니다.
  * `callbackUrlScheme: 'https'`이면 `httpsHost`·`httpsPath`가 필요합니다.
  * 앱이 다시 앞으로 왔는데 콜백이 없으면 `PlatformException(code: 'CANCELED')`로 끝납니다.
  * `CallbackActivity`는 기다리는 콜백이 없으면 링크를 버리고 앱 화면으로 돌아갑니다(`callbacks.remove(scheme)?.success`).
  * Android Gradle 파일이 `kotlin-android`를 직접 적용합니다. 6.x(AGP 9 built-in Kotlin 전용)는 alpha뿐입니다. 이 프로젝트는 AGP 9.1.0이지만 `android.builtInKotlin=false`·`android.newDsl=false` 호환 설정을 쓰므로 5.1.0이 동작합니다.
* `google_sign_in` 7.2.0(flutter.dev 공식):
  * `GoogleSignIn.instance.initialize(clientId:, serverClientId:, nonce:)`는 프로세스에서 **정확히 한 번** 불러야 하고, nonce도 이때만 받습니다.
  * `authenticate()`가 `GoogleSignInAccount`를 돌려주고, `account.authentication.idToken`이 OIDC id_token입니다. Android는 Credential Manager를 쓰며 id_token을 받으려면 `serverClientId`(웹 client id)가 필요합니다.
  * 취소는 `GoogleSignInException`의 `GoogleSignInExceptionCode.canceled`입니다.
  * iOS는 `clientId`(iOS client id)를 `initialize`로 넘기면 Info.plist `GIDClientID`가 필요 없습니다. URL Types에 reversed client id(`com.googleusercontent.apps.<앞부분>`)는 있어야 합니다.
* `flutter_line_sdk`(LINE 공식):
  * 3.0.0(2026-10-07)은 Kotlin plugin을 스스로 적용하지 않고 AGP built-in Kotlin을 요구합니다. 위의 호환 설정(`builtInKotlin=false`)과 맞지 않습니다.
  * 2.7.2는 Kotlin plugin을 스스로 적용해 지금 설정과 맞습니다. Flutter 3.38 이상, Android minSdk 24입니다.
  * `LineSDK.instance.setup(channelId)`를 부팅 때 부르고, `login(scopes: ['openid'], option: LoginOption(..)..idTokenNonce = …)`로 로그인합니다. id_token은 `result.accessToken.idTokenRaw`입니다. SDK는 받은 nonce를 그대로 id_token에 넣으므로 해시를 넘깁니다.
  * 취소는 `PlatformException(code: 'CANCEL')`입니다(Android `LineApiResponseCode.CANCEL`).
  * iOS는 URL Types `line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)`와 `LSApplicationQueriesSchemes`의 `lineauth2`가 필요합니다.

## 3. 구조

| 단위 | 위치 | 하는 일 | 의존 |
| --- | --- | --- | --- |
| `AuthConfig` | `lib/core/platform/auth_config.dart` | `String.fromEnvironment`로 §4의 값을 읽습니다. 제공자별 `isKakaoConfigured`·`isLineConfigured`·`isGoogleConfigured`·`isAppleWebConfigured` | 없음 |
| `KakaoSdkAuth` | `lib/core/platform/kakao_auth.dart` | `KakaoAuth`의 실제 구현 | `KakaoLoginApi`(SDK 경계) |
| `LineSdkAuth` | `lib/core/platform/line_auth.dart` | `LineAuth`(새 interface)의 실제 구현 | `LineLoginApi`(SDK 경계) |
| `GoogleSdkAuth` | `lib/core/platform/google_auth.dart` | `GoogleAuth`(새 interface)의 실제 구현 | `GoogleSignInApi`(SDK 경계), `NonceGenerator` |
| `SignInWithAppleNativeAuth` | `lib/core/platform/apple_native_auth.dart` | `AppleNativeAuth`의 실제 구현(iOS) | `AppleIdCredentialApi`(SDK 경계) |
| `WebAuthAppleWebAuth` | `lib/core/platform/apple_web_auth.dart` | `AppleWebAuth`의 실제 구현(Android) | `WebAuthenticate`(SDK 경계), `NonceGenerator` |
| `ProviderNotConfigured` | `lib/core/platform/social_auth.dart` | 설정이 비어 실제 제공자를 부를 수 없음 | 없음 |
| `ProviderAuthenticator` | `lib/features/auth/application/provider_authenticator.dart` | 제공자 하나로 인증해 `ProviderProof`를 돌려줌(§6) | 위 adapter들, `targetPlatformProvider` |

* **새 interface:** `LineAuth`·`GoogleAuth`는 `KakaoAuth`처럼 `signIn(rawNonce)`가 credential을 돌려주고, 취소는 `SocialSignInCancelled`입니다. fake(`fakes.dart`)도 같이 더합니다. Google credential은 실제로 쓴 원문 nonce를 함께 담습니다(§5.4).
* **SDK 경계:** 각 adapter는 SDK 호출을 생성자로 받는 작은 interface(또는 함수 typedef)로 감쌉니다. 기존 `UrlExternalBrowser.launch`와 같은 방식입니다. 기본값이 실제 SDK를 부르고, 테스트는 대역을 넘깁니다. 경계 구현은 SDK 호출을 그대로 옮기기만 하고 분기를 두지 않습니다. 분기는 모두 adapter에 있어 테스트됩니다.
* **끼우기:** `realPlatformOverrides(ApiMode.http)`에 다섯 provider를 더합니다. 카카오 설정이 있으면 부팅 때 `KakaoSdk.init(nativeAppKey:)`, LINE 설정이 있으면 `LineSDK.instance.setup(channelId)`를 부릅니다. Google `initialize`는 첫 로그인 때 adapter가 부릅니다(§5.4). fake 모드는 지금처럼 대역입니다.
* **설정이 비었을 때:** adapter가 `signIn`에서 `ProviderNotConfigured`를 던집니다. `LoginController`가 이미 `Object`를 `LoginFailed(UnexpectedError)`로 모으고 오류 요약을 보고하므로, 화면은 일반 실패 안내를 보입니다. 버튼은 숨기지 않습니다(설정은 출시 전에 모두 채움). http 모드에서 대역을 쓰지 않는 이유는 가짜 토큰을 실제 server에 보내게 되기 때문입니다.
* **`SocialProvider` 위치:** 지금 `lib/design/components/action/social_login_button.dart`에 있는 enum(이미 `kakao`·`line`·`google`·`apple`)을 `lib/core/platform/social_provider.dart`로 옮기고 컴포넌트 파일이 export합니다. 플랫폼 코드가 design을 import하지 않게 하려는 것이고, 화면·adapter·repository가 모두 이 enum을 씁니다. 생성 모델 `LoginProvider`(열린 enum)와의 변환은 repository가 하고, 모르는 값은 건너뜁니다(계약 `LoginProvider` 설명).

## 4. 설정 (결정 A81)

비밀이 아닌 식별자는 앱 바이너리에 그대로 들어가는 공개 값입니다. 저장소 JSON 한 곳에 두고 세 빌드 체계가 거기서 읽습니다.

`app/config/auth.json`(지금은 모두 빈 값):

```json
{
  "KAKAO_NATIVE_APP_KEY": "",
  "LINE_CHANNEL_ID": "",
  "GOOGLE_IOS_CLIENT_ID": "",
  "GOOGLE_SERVER_CLIENT_ID": "",
  "APPLE_SERVICES_ID": "",
  "APPLE_REDIRECT_URI": "",
  "APP_LINK_HOST": ""
}
```

* `APPLE_REDIRECT_URI`는 server 콜백 전체 주소입니다(`<API 주소>/v1/auth/apple/callback`). Apple Services ID에 등록한 값과 글자까지 같아야 합니다. `APP_LINK_HOST`는 server `APP_LINK_BASE`의 host입니다.
* `GOOGLE_SERVER_CLIENT_ID`는 Google 웹 client id입니다. server가 id_token의 `aud`로 확인하는 값이라 server 설정과 같아야 합니다. Android는 이 값만 쓰고(패키지 이름·서명 지문을 Android client로 콘솔에 등록), iOS는 `GOOGLE_IOS_CLIENT_ID`도 씁니다.
* **Dart:** 실행·빌드 명령에 `--dart-define-from-file=config/auth.json`을 붙입니다. 고칠 곳은 README 실행 명령, `tool/patrol_local.sh`, `app.yml`의 빌드·E2E 단계입니다.
* **Android:** `app/build.gradle.kts`가 같은 JSON을 읽어 `manifestPlaceholders`의 `kakaoScheme`(`kakao<키>`)과 `appLinkHost`를 채웁니다. 값이 비면 어떤 링크와도 맞지 않는 `unconfigured.invalid`(scheme은 `kakao-unconfigured`)를 넣어 manifest가 항상 유효하게 합니다. LINE·Google은 Android manifest 값이 필요 없습니다.
* **iOS:** `tool/gen_native_config.dart`가 JSON에서 `ios/Flutter/Auth.xcconfig`를 생성해 커밋하고, `Debug.xcconfig`·`Release.xcconfig`가 이 파일을 include합니다.
  * `KAKAO_NATIVE_APP_KEY`
  * `GOOGLE_REVERSED_CLIENT_ID`: `GOOGLE_IOS_CLIENT_ID`의 `.apps.googleusercontent.com` 앞부분을 `com.googleusercontent.apps.` 뒤에 붙인 값. 비면 `google-unconfigured`
  * Info.plist URL scheme은 `kakao$(KAKAO_NATIVE_APP_KEY)`, `line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)`, `$(GOOGLE_REVERSED_CLIENT_ID)`입니다.
* **동기화 검사:** `test/contract/native_auth_config_test.dart`(`@Tags(['contract'])`)가 생성한 xcconfig가 JSON과 같은지, manifest와 Info.plist에 자리가 있는지 확인합니다.

**네이티브 설정 추가**
* Android `AndroidManifest.xml`:
  * 카카오 `com.kakao.sdk.flutter.auth.AuthCodeHandlerActivity` intent filter(`scheme=${kakaoScheme}`, `host=oauth`)
  * `com.linusu.flutter_web_auth_2.CallbackActivity`(`exported`, `taskAffinity=""`)와 `autoVerify` intent filter(`https`, `${appLinkHost}`, `path=/auth/apple`)
  * `<queries>`에 카카오톡 패키지(`com.kakao.talk`)와 LINE 패키지(`jp.naver.line.android`)
* MainActivity에는 App Link filter를 두지 않습니다. 링크는 `CallbackActivity`로만 오므로 Flutter 기본 deep linking과 라우터(`onException`)에 닿지 않습니다. 그래서 A12와 계획 7 메모의 "라우터보다 먼저 가로채는 전용 처리"는 만들지 않습니다.
* iOS: `LSApplicationQueriesSchemes`(`kakaokompassauth`, `kakaolink`, `lineauth2`), URL Types(위 셋), `Runner.entitlements`(`com.apple.developer.applesignin` = `Default`)를 Runner target에 연결합니다.

## 5. 제공자별 흐름과 오류 처리

공통 규칙:
* `rawNonce`는 호출하는 쪽(`ProviderAuthenticator`를 부르는 controller)이 만들어 넘깁니다. 원문을 로그·오류 보고에 싣지 않습니다(D64).
* 제공자에게는 언제나 해시(`hashNonce(rawNonce)`)를 보내고, server에는 원문을 보냅니다(`AuthRepository` 규칙). 네 제공자 모두 받은 값을 그대로 id_token에 넣으므로, server는 제공자와 상관없이 "id_token nonce = SHA-256(원문)" 하나로 확인합니다.
* **SDK 세션 정리(결정 A82):** id_token을 받은 뒤 제공자 SDK에 남은 세션을 지웁니다. 계정은 server 토큰으로만 유지하고, 다음 인증(로그인·붙이기) 때 사용자가 제공자 계정을 다시 고를 수 있게 하려는 것입니다. 지우기 실패는 인증을 막지 않습니다.

### 5.1. 카카오

1. 설정이 없으면 `ProviderNotConfigured`를 던집니다.
2. 카카오톡이 설치돼 있으면(`isKakaoTalkInstalled`) `loginWithKakaoTalk(nonce: 해시)`를 부릅니다.
   * `PlatformException` `CANCELED`이면 `SocialSignInCancelled`를 던집니다. 카카오 공식 예제처럼 계정 로그인으로 넘어가지 않습니다.
   * 그 밖의 실패(카카오톡에 연결된 계정 없음 등)면 3으로 넘어갑니다.
3. `loginWithKakaoAccount(nonce: 해시)`를 부릅니다. `CANCELED`이면 `SocialSignInCancelled`, 그 밖의 오류는 그대로 던집니다(`LoginController`가 모음).
4. `OAuthToken.idToken`이 없으면(카카오 콘솔 OpenID Connect 미설정) `StateError`입니다.
5. 세션 정리: SDK `TokenManager`에 저장된 카카오 토큰을 지웁니다(`TokenManagerProvider.instance.manager.clear()`). 카카오 허가 취소는 server가 합니다(떼기·계정 삭제·합치기, D85 ⑥).

### 5.2. LINE

1. 설정이 없으면 `ProviderNotConfigured`를 던집니다.
2. `login(scopes: ['openid'], option: LoginOption(false, 'normal')..idTokenNonce = 해시)`을 부릅니다. `profile`·`email` scope는 받지 않습니다(D82 ④, 앱이 쓰지 않음).
3. `PlatformException` `CANCEL`이면 `SocialSignInCancelled`, 그 밖의 오류는 그대로 던집니다.
4. `accessToken.idTokenRaw`가 없으면(LINE 채널 OpenID Connect 미설정) `StateError`입니다.
5. 세션 정리: `LineSDK.instance.logout()`.

### 5.3. Apple iOS

1. 설정은 필요 없습니다. Bundle ID와 entitlement만 씁니다.
2. `getAppleIDCredential(scopes: [], nonce: 해시)`를 부릅니다. 이름·이메일 scope는 받지 않습니다. 앱이 쓰지 않고, 웹 흐름도 scope를 보내지 않습니다(S22).
3. `AuthorizationErrorCode.canceled`이면 `SocialSignInCancelled`를 던집니다. 그 밖의 오류는 그대로 던집니다.
4. `identityToken`이 없으면 `StateError`입니다. `authorizationCode`와 함께 `AppleNativeCredential`을 돌려줍니다.
5. 세션 정리: Apple은 기기에 SDK 세션을 남기지 않아 할 일이 없습니다.

### 5.4. Google (결정 A83)

1. 설정이 없으면(`GOOGLE_SERVER_CLIENT_ID`가 비거나, iOS에서 `GOOGLE_IOS_CLIENT_ID`가 빔) `ProviderNotConfigured`를 던집니다.
2. 처음 부를 때 한 번만 `initialize(clientId: iOS면 GOOGLE_IOS_CLIENT_ID, serverClientId: GOOGLE_SERVER_CLIENT_ID, nonce: hashNonce(프로세스 nonce))`를 부릅니다. 프로세스 nonce는 이때 `NonceGenerator`로 만든 원문이고 앱이 꺼질 때까지 같습니다. 초기화 future를 adapter가 들고 있어 동시에 불러도 한 번만 초기화합니다. 받은 `rawNonce` 인자는 쓰지 않습니다.
3. `authenticate()`를 부릅니다. `GoogleSignInExceptionCode.canceled`이면 `SocialSignInCancelled`, 그 밖의 오류는 그대로 던집니다.
4. `authentication.idToken`이 없으면 `StateError`입니다. `GoogleCredential(idToken, rawNonce: 프로세스 nonce 원문)`을 돌려주고, 호출하는 쪽은 이 `rawNonce`를 server에 보냅니다.
5. 세션 정리: `signOut()`. 다음 인증 때 계정 선택이 다시 뜹니다.

> **server 확인(#555, 닫힘):** server는 Google id_token의 nonce 원문을 일회용으로 기록하지 않아, 같은 프로세스 nonce를 여러 번 보내도 받습니다. 검증은 id_token의 nonce가 보낸 원문의 해시와 맞는지만 보고, 재사용 방지는 id_token 만료(`exp`)에 맡깁니다.

### 5.5. Apple Android 웹 (결정 A80, A12 갱신)

1. `APPLE_SERVICES_ID`·`APPLE_REDIRECT_URI`·`APP_LINK_HOST` 중 하나라도 비면 `ProviderNotConfigured`를 던집니다.
2. `state`를 `NonceGenerator`로 만들고, `buildAppleAuthorizeUri(clientId: Services ID, redirectUri, hashedNonce: 해시, state)`를 만듭니다.
3. `FlutterWebAuth2.authenticate(url, callbackUrlScheme: 'https', options: FlutterWebAuth2Options(httpsHost: APP_LINK_HOST, httpsPath: '/auth/apple'))`로 엽니다.
4. 결과 문자열을 `parseAppleWebReturn(Uri.parse(결과), expectedState: state)`로 해석해 돌려줍니다.
5. `PlatformException` `CANCELED`(탭을 닫음, 또는 콜백 없이 앱으로 돌아옴)이면 `AppleWebFailure(AppleWebError.userCancelled)`를 돌려줍니다. 그 밖의 `PlatformException`은 그대로 던집니다.

**경로별 동작**
* **App Link 검증됨:** Apple → server 콜백 → 303 `https://<APP_LINK_HOST>/auth/apple?exchange=…&state=…`를 Auth Tab이 받아 결과로 돌려줍니다.
* **링크가 앱을 열지 못함:** server 안내 페이지(S22 §2.3)의 intent 링크가 같은 `CallbackActivity`로 들어와, 기다리던 `authenticate`가 끝납니다.
* **기다리는 로그인이 없음**(앱이 내려간 뒤 돌아온 링크): `CallbackActivity`가 링크를 버리고 앱을 엽니다. nonce 원문이 메모리에만 있어 그 교환 코드는 쓸 수 없고, 사용자는 다시 시도합니다.
* **붙이기·합치기에서의 Android Apple:** server 콜백은 로그인과 붙이기를 가리지 않고 교환 코드를 줍니다. 그 교환 코드를 `completeAppleWebLogin`·`linkIdentity`·`previewMerge` 중 어디로 보낼지는 app이 정합니다(§6). REST 1.0.0의 `LinkIdentityRequest`·`MergePreviewRequest`가 `exchangeCode`를 받습니다.

### 5.6. LINE·Google 제공자 허가는 취소하지 않음 (D95)

* 떼기·계정 삭제·합치기 어디서도 app은 LINE·Google 제공자 허가를 취소하지 않습니다. 연결 기록은 server가 지웁니다. 카카오·Apple 허가는 지금처럼 server가 취소합니다(D85 ⑥, S106).
* 그래서 허가 취소 경계(처음 초안의 `ProviderRevoker`)와 합치기 인증의 세션 유지(`keepSession`)는 만들지 않습니다. 로그인·붙이기·합치기 인증 모두 id_token을 받은 뒤 SDK 세션을 바로 정리합니다(A82).
* 떼기·탈퇴 직전 재인증을 두지 않는 이유와 제공자 쪽 연결 앱 기록이 남는 안내는 D95에 있습니다. 안내는 화면이 아니라 개인정보 처리방침과 수집·보관 대장이 맡습니다(지휘 몫).

## 6. 제공자 인증 경계 (결정 A84)

로그인, 붙이기(D82 ⑤ "그 제공자로 다시 인증"), 합치기 인증(D85 ④ B의 인증 계정으로 인증)은 제공자 인증이 같고 server에 보내는 곳만 다릅니다(`login*`, `linkIdentity`, `previewMerge`). 그래서 인증을 한 단위로 떼어 셋이 함께 씁니다.

```dart
/// 제공자 인증 한 번의 결과입니다. server에 보낼 증명입니다.
sealed class ProviderProof {
  SocialProvider get provider;
  String get rawNonce; // server에 보낼 원문 nonce
}
final class IdTokenProof extends ProviderProof { … idToken, authorizationCode? (Apple iOS) }
final class AppleWebExchangeProof extends ProviderProof { … exchangeCode }

/// 인증이 server 요청 전에 끝난 경우입니다.
sealed class ProviderAuthFailure … // 취소(SocialSignInCancelled), Android Apple 웹 실패(AppleWebError)
```

* `ProviderAuthenticator.authenticate(SocialProvider, {required String rawNonce})`가 플랫폼에 맞는 adapter를 고르고(Apple: Android면 웹, 그 밖은 네이티브), credential을 `ProviderProof`로 바꿉니다. Google은 credential의 `rawNonce`를 proof에 넣습니다.
* 취소는 지금처럼 `SocialSignInCancelled`를 던지고, Android Apple 웹 실패는 `AppleWebFailure`를 그대로 넘깁니다(지금 `LoginController`의 `AppleWebFailed` 갈래 유지).
* `AuthRepository.login(ProviderProof)`가 proof 종류·제공자로 operation을 고릅니다(`loginKakao`·`loginLine`·`loginGoogle`·`loginApple`·`completeAppleWebLogin`). 지금 있는 `kakao`·`appleNative`·`appleWeb`은 그 안으로 들어갑니다. REST 1.0.0에 LINE·Google 로그인이 있으므로 처음 초안의 `ProviderNotSupportedYet`은 만들지 않습니다.
* 같은 proof를 `linkIdentity`·`previewMerge` 본문으로 바꾸는 일은 `AccountLinkRepository`가 합니다(§10). 본문 조합은 계약 `LinkIdentityRequest`(kakao·line·google: `idToken`, apple iOS: `idToken`·`authorizationCode`, apple 웹: `exchangeCode`, 모두 `nonce` 원문)입니다.
* `LoginController`의 `signInWithKakao`·`signInWithApple`은 `signIn(SocialProvider)` 하나로 합칩니다. 시도마다 nonce를 만들고, 진행 중이면 같은 결과를 돌려주고, 성공 뒤 토큰 저장·진입 계산을 하는 지금 규칙과 D90 ③ 갈래(A79: 동의했고 사주 없는 계정이 미리보기 입력을 가지면 저장 뒤 `notify-ask`)는 그대로입니다.

## 7. 로그인 화면 (`login`)

* 네 버튼을 같은 크기·같은 무게로 세로로 둡니다(D82 ①).
* 순서: 기본은 카카오, LINE, Google, Apple이고, 앱 언어의 대표 제공자만 맨 위로 올립니다.

| 언어 | 순서 |
| --- | --- |
| ko | 카카오, LINE, Google, Apple |
| ja | LINE, 카카오, Google, Apple |
| en | Google, 카카오, LINE, Apple |

  순서는 `loginProviderOrder(Locale)` 순수 함수 하나가 정하고 단위 테스트합니다. 지원하지 않는 언어는 en을 따릅니다(기본 언어 en, REST `Accept-Language` 규칙과 같음).
* `SocialLoginButton`의 `line`·`google` 변형은 이미 있습니다(design 3.0.0, 끝남). 순서는 명세 `parts.stack.order`와 같습니다.
* 라벨 `loginLineLabel`·`loginGoogleLabel`은 writing 원고 키입니다(끝남).
* 오류 안내(`login.error.body`)와 상태는 지금과 같습니다.

## 8. 로그인 수단 화면 (`login-methods`, D85 ③, V39·V44)

**들어오는 곳:** 설정 화면에 "로그인 수단" 줄(`settings-row`, 라벨 `loginMethodsBarTitle`)을 더하고 이 화면으로 갑니다. 설정의 출구가 IA와 같아져 `ia_pending.dart`의 `pendingExitScreens`에서 `settings`를 지웁니다.

**그리는 것**(위에서 아래, design `account-merge-purchase` spec §2)
* app-bar 제목, `login-methods.intro.body`
* `social-login-button` 네 개(순서는 §7과 같음). 목록은 `listIdentities`입니다.
  * 연결됨: 상태 `connected`(중립 줄, 제공자 이름 `loginProvider*` + `loginMethodsRowConnected`). 누르면 떼기 확인. 연결이 하나뿐이면 그 줄은 누를 수 없고 아래에 `login-methods.last.notice`.
  * 연결 안 됨: 그 제공자의 로그인 버튼(라벨은 로그인 화면과 같은 `login*Label`)으로 붙이기.
* 합치기 입구: 위 `space.32`에 1px `color.line` 가로선, 그 아래 `space.16`에 `primary-button` `quiet` `login-methods.merge.cta`. 연결 수와 관계없이 늘 보이고, 누르면 `account-merge`로 갑니다.
* `error` 상태: 붙이기·떼기를 끝내지 못하면 `loginMethodsErrorBodyLink`·`loginMethodsErrorBodyUnlink`를 보입니다(인증 창을 닫음 포함, IA state note).

**붙이기 흐름**
1. 새 원문 nonce로 `ProviderAuthenticator.authenticate`. 성공하면 SDK 세션을 정리합니다(A82).
2. `AccountLinkRepository.link(proof)`(`linkIdentity`):
   * 201·200: 응답 목록(`IdentityList`)으로 갱신합니다.
   * 409 `auth.identity_in_use`·`auth.provider_taken`: 연결하지 않습니다. `login-methods.in-use.body`를 `dialog` `notice`로 보이고, 확인하면 이 화면에 그대로 있습니다. **합치기로 넘어가지 않습니다**(D85 ③). 합치기는 아래 입구가 맡습니다.
   * 401 `auth.provider_token_invalid`·`auth.exchange_invalid`: 붙이려는 증명이 틀린 것이고 현재 세션은 유효합니다. 로그아웃하지 않고 `error` 상태로 안내합니다(auth interceptor는 `auth.token_expired`만 refresh·로그아웃 처리하므로 그대로 둠).
3. 취소·Apple 웹 실패·그 밖의 `AppError`는 `error` 상태입니다.

**떼기 흐름:** `login-methods.unlink.confirm` dialog(제공자 이름 `{provider}`) → `AccountLinkRepository.unlink(provider)`(`unlinkIdentity` 204) → `listIdentities`로 목록 갱신. 마지막 하나는 화면이 막고, server가 409 `auth.last_identity`로 거절해도 `error` 상태로 안내합니다. 404 `auth.identity_not_found`면 다른 기기에서 이미 뗀 것이므로 목록만 다시 읽습니다. 카카오·Apple 쪽 허가 취소는 server가 하고, LINE·Google 허가는 취소하지 않습니다(D95, §5.6).

**상태 관리:** `LoginMethodsController`(AsyncNotifier)가 목록 읽기·붙이기·떼기를 갖고, 진행 중에는 다른 줄의 동작과 합치기 입구를 막습니다(`LoginController`의 진행 중 규칙과 같음). `account-merge`에서 돌아오면 목록을 다시 읽습니다.

## 9. 계정 합치기 화면 (`account-merge`, D85 ④, V44)

한 화면 두 단계(인증 → 요약·고르기)입니다. 남는 계정은 언제나 지금 로그인한 계정 A이고, B의 기록·구매를 A로 가져오며 B와 그 인증 계정은 지워집니다. 인증 계정은 가져오지 않습니다. route extra는 없습니다(합치기 토큰을 URL·복원 상태에 두지 않음, 계약 `MergePreview.mergeToken`).

**인증 단계**
* app-bar 제목, `account-merge.title.head`, `account-merge.auth.body`, `social-login-button` 네 개(로그인 화면과 같은 순서·라벨, `connected` 아님). 누른 버튼만 `loading`, 나머지 `disabled`.
* 버튼 → 새 원문 nonce로 `ProviderAuthenticator.authenticate`(세션은 로그인처럼 바로 정리, §5.6) → `AccountLinkRepository.preview(proof)`(`previewMerge`, 본문 `MergePreviewRequest`. `provider`는 proof에서 읽음). 받는 동안 IA `loading`(요약 상자·카드 자리 숨쉬기).
* 422 `merge.same_account` → `accountMergeNotOtherBodySelf`, 422 `merge.no_account` → `accountMergeNotOtherBodyNone`을 `dialog` `notice`로 보이고 인증 단계에 남습니다(IA `error`, A74 `_screenMessages`). `merge.no_account`에서 `linkIdentity`로 넘어가지 않습니다(D85 ④ "연결로 넘어가지 않음").
* 401 `auth.provider_token_invalid`·`auth.exchange_invalid`, 그 밖의 요약 실패는 `accountMergeError`를 `dialog` `notice`로 보이고 인증 단계에 남습니다. 취소는 아무 안내 없이 인증 단계입니다.

**요약·고르기 단계**
* `account-merge.title.body`.
* 가져올 기록·구매 상자(컴포넌트 아님): 머리 `accountMergeSummaryHead`, 줄 순서 일기(`accountMergeSummaryDiary`·`accountMergeSummaryDiaryCount`, `MergeSummary.diaries`) → 일정(`accountMergeSummaryEvent`·`accountMergeSummaryEventCount`, `schedules`) → 광고 제거 남은 기간(`accountMergeSummaryAdFree`·`accountMergeSummaryAdFreeDays`, `addedDays.adFree`, 0보다 클 때만). 일기·일정은 0이어도 보입니다. `diaries`·`schedules`는 REST 1.0.0에서 **살아 있는 기록 수**입니다. 지운 기록도 옮기지만 세지 않습니다.
* `account-merge.choice.label`과 `account-choice` 두 장(A → B, 알약 `accountChoiceCurrent`·`accountChoiceOther`). 카드는 호칭과 사주 요약(`MergeProfileSummary`의 `honorific`·`birth`, `status: none`이면 `accountChoiceSajuEmpty`)입니다. 처음엔 고르지 않고, 고르기 전에는 합치기 버튼이 `disabled`입니다.
* `account-merge.overlap.notice`: `MergeSummary.overlapDays`가 0보다 클 때만. 고르기와 상관없습니다(같은 날 일기도 모두 옮김, D83 ④).
* 화면 아래 `primary-button` `filled` `account-merge.cta.merge`.
* **"합치지 않기" 버튼은 없습니다.** 어느 단계에서든 뒤로 가기가 그만두기이고 `login-methods`로 돌아갑니다. 받은 합치기 토큰은 버립니다.

**합치기 흐름**
1. 합치기 → `account-merge.merge.confirm` `dialog` `destructive`(되돌릴 수 없음). 확인 없이는 부르지 않습니다(D82 ⑥).
2. 확정하면 `Idempotency-Key`를 정하고(키는 (`mergeToken`, `profile`) 조합마다 하나, 같은 조합으로 다시 확정하면 같은 키, 토큰이나 프로필이 바뀌면 새 키) `AccountLinkRepository.merge(token, profile, key)`(`mergeAccounts`, 본문 `{mergeToken, profile: current|other}`). 합치는 동안 합치기 버튼 `loading`, `account-choice` `disabled`이고 **뒤로 가기(app-bar·시스템)를 모두 막습니다**.
3. 응답은 A의 `Me`이고 새 세션이 없습니다. **토큰을 바꾸지 않습니다.** 계약("합친 유저 계정 기준으로 캐시·초안을 지운 뒤 `getMe`부터 다시 읽습니다")대로 이 계정의 캐시(오늘·달력·일기 목록·나의 사주·프로필 사본)와 이 기기의 일기 초안을 지우고(기기 플래그는 남김), `meProvider`를 응답 `Me`로 갱신한 뒤 진입을 다시 계산합니다.
4. 햅틱 light를 냅니다. LINE·Google 허가는 취소하지 않습니다(D95).
5. 이동: 진입 계산이 회원 갈래 그대로(동의 있음, 사주 있음)면 `login-methods`로 돌아갑니다(IA 출구). 그 밖의 갈래(고른 쪽 프로필이 없어 `status: none` 등)면 진입 계산이 정한 화면이 우선합니다.

**재전송 규칙**(계약 `mergeAccounts` 설명, #518·#552 server 답, S115)
* 409 `idempotency.in_progress`: 잠시 뒤 **같은 키**로 다시 보냅니다. 화면은 `loading` 그대로입니다.
* 응답을 받지 못함(시간 초과·연결 끊김): **같은 토큰·같은 본문·같은 키**로 한 번 다시 보냅니다. 200 `Me`면 합쳐진 것이고 3~5의 성공 갈래입니다. server는 같은 계정 A가 24시간 안에 이미 합친 토큰을 다시 보내면 키와 상관없이 처음 결과로 200을 줍니다(S115). 그래서 처음 초안의 `getMe` 판정(요약에서 기대한 변화로 추정)은 두지 않습니다.
* 재전송이 422 `merge.token_invalid`면 합쳐지지 않은 것입니다(다른 계정의 토큰이거나 24시간 뒤, 또는 토큰 만료). `errorMergeTokenInvalid`(W42)를 `dialog` `notice`로 보이고 인증 단계로 돌아갑니다.
* 첫 요청이 422 `merge.token_invalid`(토큰 만료 10분 등)여도 `errorMergeTokenInvalid` 뒤 인증 단계입니다.
* 그 밖의 실패는 `accountMergeError` `dialog` `notice`이고 고름은 그대로 둡니다. 결과를 모르는 채 실패 안내가 나간 뒤 다른 프로필로 다시 확정해도(새 키), server가 영수증으로 처음 결과 200을 주므로 성공 갈래입니다(S115 "`profile`이 처음과 달라도 처음 결과").

**초안:** 합친 뒤 캐시와 함께 이 기기의 일기 초안도 지웁니다(계약 `mergeAccounts`). 합치기 확인 dialog(`account-merge.merge.confirm`)가 그 확인입니다.

## 10. 데이터 경계와 문구

**`AccountLinkRepository`**(`lib/features/account/data/account_link_repository.dart`, `DefaultApi` 위의 class. `PurchaseRepository`와 같은 모양)

| 메서드 | operation | 돌려주는 것 |
| --- | --- | --- |
| `methods()` | `listIdentities` | 연결된 제공자 목록(붙인 순서, 모르는 `LoginProvider`는 건너뜀) |
| `link(ProviderProof)` | `linkIdentity` | 붙인 뒤 목록. 409는 `AppError`(`auth.identity_in_use`·`auth.provider_taken`)로 던지고 화면이 code로 가릅니다 |
| `unlink(SocialProvider)` | `unlinkIdentity` | 없음(204). 화면이 `methods()`를 다시 부릅니다 |
| `preview(ProviderProof)` | `previewMerge` | 생성 모델 `MergePreview`(`mergeToken`·`expiresAt`·`summary`) |
| `merge({mergeToken, profile, idempotencyKey})` | `mergeAccounts` | 생성 모델 `Me` |

* 실패는 모두 `AppError`(`appErrorFrom`)입니다. 화면은 problem code로 가릅니다.
* **fake 모드:** 다른 기능처럼 대역 서버(`FakeServer`)가 새 operation을 답합니다. fixture(`fixtures/<시나리오>/<operationId>.json`)와 메모리 상태(연결 목록)로, 처음 목록은 `[kakao]`이고 붙이기·떼기가 목록을 바꿉니다. fake 규칙은 계획 "이 계획이 정하는 것"의 fake 행 하나가 기준입니다: Google을 붙이면 409 `auth.identity_in_use`. 합치기 인증은 이 계정에 이미 연결된 제공자면 422 `merge.same_account`, Apple이면 422 `merge.no_account`, 그 밖(연결하지 않은 LINE·Google)이면 요약 200. `mergeAccounts`는 시나리오 `Me`를 돌려줍니다. 시나리오 표는 README에 적습니다.
* **문구(A85):** 모두 writing 원고 키입니다(위 §8·§9에 적은 키, 문제 code 문구 `errorAuthIdentityInUse`·`errorAuthProviderTaken`·`errorAuthLastIdentity`·`errorMergeTokenInvalid`). 화면 설계 중 원고가 없는 자리가 나오면 A7 임시 키(`@키.description`에 `임시`, `_allowedTemporaryKeys`)로 두고 writing에 Issue로 요청합니다. 사용자에게 보이는 글자에 U+2014·U+2013·U+00B7을 쓰지 않습니다(§1 화면 문구 규칙).

## 11. 결정 기록 (`app/docs/decisions.md`)

처음 초안의 번호는 일기 결정(A67~A72, D83)과 겹쳐 A80부터 다시 매겼습니다(A73~A79는 `app/d85-d88`). 차례는 처음 초안과 같습니다.

* **A80 (A12 갱신):** Android Apple 웹 로그인은 `flutter_web_auth_2`로 열고 https 콜백(`/auth/apple`)을 받습니다. Auth Tab이 기본이고, 지원하지 않는 브라우저에서는 Custom Tabs로 대체합니다.
  * 근거: 탭을 닫은 취소를 플랫폼이 알려 주고, 링크가 `CallbackActivity`로만 와서 라우터 가로채기가 필요 없습니다. `app_links`와 직접 띄운 브라우저 조합은 취소를 앱 재개로 추정해야 합니다.
  * 안정판 5.x를 씁니다. 6.x(AGP 9 전용)가 안정판이 되고 호환 설정(`builtInKotlin=false`)을 걷어 낼 때 함께 올립니다.
* **A81:** 비밀이 아닌 제공자 식별자는 `app/config/auth.json` 한 곳에 커밋합니다. Dart는 `--dart-define-from-file`, Gradle은 `manifestPlaceholders`, iOS는 생성한 `Auth.xcconfig`로 읽고, 동기화는 `contract` 테스트가 확인합니다. 빈 값이면 해당 adapter가 `ProviderNotConfigured`입니다.
* **A82:** 카카오는 카카오톡이 있으면 카카오톡, 실패하면 계정 로그인입니다(공식 예제). 사용자 취소는 계정 로그인으로 넘어가지 않습니다. SDK 선택 시트(`loginWithKakao`)는 디자인 시스템 밖 UI라 쓰지 않습니다. 모든 제공자는 id_token을 받은 뒤 SDK 세션을 지웁니다(카카오 토큰 삭제, LINE `logout`, Google `signOut`).
* **A83:** LINE은 `flutter_line_sdk` 2.7.2, Google은 `google_sign_in` 7.2.0입니다.
  * LINE 3.x는 AGP built-in Kotlin을 요구해 `flutter_web_auth_2` 5.x와 함께 쓸 수 없습니다. 둘을 함께 3.x·6.x로 올리고 호환 설정을 걷어 냅니다(A80과 같은 시점).
  * 네 제공자 모두 제공자에게 nonce 해시를, server에 원문을 보냅니다.
  * Google SDK는 nonce를 `initialize` 한 번에만 받으므로, 프로세스마다 원문 nonce 하나를 만들어 앱이 꺼질 때까지 씁니다. adapter가 실제로 쓴 원문을 credential로 돌려줍니다.
  * LINE·Google 모두 이메일·프로필 scope를 받지 않습니다(D82 ④).
* **A84:** 제공자 인증(`ProviderAuthenticator` → `ProviderProof`)은 로그인, 로그인 수단 붙이기, 합치기 인증이 함께 씁니다. server에 보내는 곳(`AuthRepository.login`, `AccountLinkRepository.link`·`preview`)만 다릅니다. 연결·합치기 데이터는 `AccountLinkRepository`(REST 1.0.0 생성 클라이언트 위)이고 fake 모드는 대역 서버가 답합니다. 연결 409는 합치기로 넘기지 않고 안내만 하며(D85 ③), 합치기는 `previewMerge` → 확인 → `mergeAccounts`(`Idempotency-Key`는 (`mergeToken`, `profile`) 조합마다 하나이고 같은 조합 재확정은 같은 키, 응답 `Me`, 토큰 교체 없음, 합치는 동안 뒤로 가기 막음)입니다. 응답을 받지 못하면 같은 토큰·본문·키로 다시 보내 200이면 합쳐진 것이고, 422 `merge.token_invalid`면 `errorMergeTokenInvalid`와 인증 단계입니다(S115, §9). 합친 뒤 캐시와 일기 초안을 지웁니다(계약). LINE·Google 제공자 허가는 어디서도 취소하지 않습니다(D95).
* **A85:** 로그인 수단·계정 합치기 문구는 writing 원고 키(W39·W40·W42)를 그대로 씁니다. 원고 없는 자리가 새로 나오면 A7 임시 키로 두고 writing에 요청합니다. 화면 문구 problem code는 A74 규칙(`_screenMessages`)을 따릅니다. 사용자에게 보이는 글자에는 U+2014·U+2013·U+00B7을 쓰지 않습니다(#546).

## 12. 테스트와 계획 단계

**테스트**
* **adapter 단위 테스트**(`test/core/`, SDK 경계 대역):
  * 카카오: 해시를 보내는지, 카카오톡 성공·취소·실패 → 계정 전환, 계정 취소, idToken 없음, 토큰 지우기(실패해도 성공), 설정 없음.
  * LINE: 해시 nonce와 `openid`만, `CANCEL` 변환, idTokenRaw 없음, logout(실패해도 성공), 설정 없음.
  * Google: 첫 호출에만 initialize(동시 호출 포함), iOS·Android client id, initialize에 해시·credential에 원문(같은 프로세스 nonce), `canceled` 변환, idToken 없음, signOut, 설정 없음.
  * Apple iOS: 해시와 빈 scope, 취소 변환, identityToken 없음.
  * Apple 웹: authorize URL(Services ID·redirect·해시·state), `httpsHost`·`httpsPath`, 성공 결과 해석, state 불일치, `CANCELED` → `userCancelled`, 그 밖의 예외 전달, 설정 없음.
* **`ProviderAuthenticator`:** 제공자·플랫폼별 adapter 선택, proof 변환, Google nonce 전달, 취소·웹 실패 전달.
* **`AuthConfig`·`loginProviderOrder`:** 빈 값·채운 값 판정, 언어별 순서.
* **repository:** proof → `LinkIdentityRequest`·`MergePreviewRequest` 조합(제공자별), `LoginProvider` 모르는 값 건너뜀, 409·401·422 code 전달.
* **화면**(fake): 로그인 네 버튼과 순서. 로그인 수단의 붙이기·떼기·마지막 하나 막기·409 `in-use` dialog(합치기로 가지 않음)·401 증명 오류는 로그아웃 없이 `error`·합치기 입구. 계정 합치기의 인증 단계 → `loading` → 요약(0이어도 일기·일정, 광고 제거는 있을 때만, 겹침 안내는 `overlapDays`로만)·고르기 전 버튼 비활성·확인 dialog·합치는 동안 뒤로 가기 막음·`not-other` 두 갈래·`idempotency.in_progress` 같은 키 재전송·응답 없음 재전송 두 갈래(200: 성공 갈래, 422 `merge.token_invalid`: `errorMergeTokenInvalid`와 인증 단계, S115)·토큰 그대로·합친 뒤 캐시와 일기 초안 지움·진입 갈래가 `login-methods` 복귀보다 우선. IA 계약 테스트가 세 화면의 상태·출구를 확인하고, `ia_pending.dart`에서 `settings`·`login-methods`·`account-merge`를 지웁니다.
* **golden:** 두 화면(컴포넌트 golden은 끝남).
* **부팅:** `realPlatformOverrides(ApiMode.http)`가 실제 adapter를 끼우고, fake 모드는 대역인지 확인합니다(기존 테스트에 더함).
* **계약:** `native_auth_config_test.dart`(§4), `problem_codes`의 `_screenMessages`(끝남), 새 화면 문구에 금지 문자가 없는지(#546 검사가 있으면 그대로 통과).
* **Patrol:** 설정 → 로그인 수단 → 붙이기 → Google 붙이기 거절 안내 → 합치기 입구 → 인증 → 요약·고르기 → 합치기 흐름 하나를 더합니다(fake).
* Android 빌드(디버그 APK)가 manifest placeholder·새 플러그인으로 깨지지 않는지는 CI `own` 범위의 APK 빌드와 로컬 빌드로 확인합니다. iOS 빌드는 로컬에서 확인합니다.

**계획 단계** (spec 하나, 구현 계획은 단계별)
* **A. 실제 로그인:** `AuthConfig`·설정 파일·네이티브 설정, adapter 다섯(카카오·LINE·Google·Apple 둘), `ProviderAuthenticator`, `LoginController` 합치기(LINE·Google 로그인 operation 포함), 로그인 화면 네 버튼.
* **B. 로그인 수단·계정 합치기 화면:** `AccountLinkRepository`(http)와 대역 서버 응답, 설정 줄, 두 화면.
* ~~C. http 연결~~: REST 1.0.0에 연결·합치기·LINE·Google 로그인이 모두 들어와 단계 B에 합쳤습니다.
* **진행 순서(루트 D91 ①):** 화면은 A1(대역 데이터), 실제 SDK adapter는 A2(실제 연동)입니다. 그래서 단계 B와 그에 필요한 경계(제공자 인증 경계·대역)를 먼저 하고, 단계 A의 실제 adapter·네이티브 설정은 A2에서 합니다. 차례는 계획 문서 "진행 순서"에 있습니다.

**실기기 확인 목록**(외부 준비물 뒤, app `CLAUDE.md` 출시 전 항목에 적음)
* 카카오톡 로그인·계정 로그인·각 취소
* LINE 앱 로그인·웹 로그인(LINE 앱 없음)·취소
* Google 계정 선택·취소, 두 번째 로그인에서 계정 선택이 다시 뜨는지
* iOS Apple 로그인·취소
* Android Auth Tab이 server 303을 받는지, 안내 페이지 intent 복귀, 앱이 내려간 뒤 복귀
* `assetlinks.json` 검증(`adb shell pm get-app-links app.myungli.diary`)
* 붙이기·떼기·합치기(LINE·Google 허가는 제공자 쪽 연결 앱 목록에 남는 것이 맞음, D95)

## 13. 남기는 일

* #311 ③ release 지문·스토어 URL: Play 계정 뒤. 그때까지 #311은 열어 둡니다.
* 실기기 확인 목록: 외부 준비물 뒤.
* 실기기에서 Auth Tab이 303을 받지 못하면, 안내 페이지 intent 경로가 기본이 되는지 다시 판단합니다. 이 경우 server와 페이지 문구를 맞춰야 할 수 있어 Issue로 올립니다.
* 답을 받은 것(2026-10-27): 재전송 뒤 합쳐졌는지(#552 → S115, §9), 떼기·삭제의 LINE·Google 허가(#553 → D95, §5.6), Google 프로세스 nonce 재사용(#555, §5.4). LINE `logout`의 허가 범위 확인은 D95로 필요 없어졌습니다.

## 14. 계획 7 수익 쪽 과제 (`app/d85-d88`에서 넘김)

광고 제거·구매 내역 화면과 `Purchases` 인터페이스(fake)는 `app/d85-d88`에서 끝났습니다(A75~A77). 실제 SDK에 붙일 때 할 일입니다.
* **RevenueCat adapter:** `Purchases.sync()`를 RevenueCat `syncPurchases`로 구현합니다. 사용자에게 아무것도 띄우지 않는 것이 전제입니다(A76). iOS sandbox에서 `syncPurchases`가 Apple ID 로그인 창을 띄우는지 확인하고, **띄우면 지휘에 알립니다**(#493, 구매 내역 진입마다 부르는 설계를 다시 정해야 함).
* `Purchases.products()`의 시간 한계(timeout)를 정합니다. 구매 내역의 `sync`가 길어질 때의 `loading` 길이도 같은 기준으로 정합니다(d85-d88 spec §10).
* 출시 빌드에 `--dart-define=AD_FREE_PRODUCT_IDS`(광고 제거권 상품 id 쉼표 목록, A77)를 배선합니다. 상품 id는 저장소에 두지 않습니다(S89, D74).

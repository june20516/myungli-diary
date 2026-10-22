# 실제 로그인 adapter와 로그인 수단·계정 합치기 설계

* 작성: app 세션, 2026-10-21 (D82 범위 반영 2026-10-22, D83 ④ 합치기 일기 정정 2026-10-22)
* 상태: 초안 (설계 대화 승인 2026-10-21·2026-10-22, 문서 검토 대기)
* 요청: Issue #311 (#100 ⑥, #114 ①④⑤의 남은 일), #387 (D82 범위 확장, D83 ④ 정정 코멘트)
* 관련 결정: app A12(이 spec이 A67로 갱신), A67~A71(새로 기록), 루트 D49·D53·D55·D64·D82·D83, server S15·S22
* 쓰는 계약: REST API `server/api/openapi.yaml`(`loginKakao`·`loginApple`·`completeAppleWebLogin`, 버전은 `docs/contracts/README.md` 기준), server spec `2026-10-13-apple-web-callback-design.md`, IA 화면 `login`·`settings`·`login-methods`·`account-merge`
* 기다리는 계약: LINE·Google 로그인과 연결·떼기·합치기 API(server #386), 합치기 요약 값(server #407 ④), 버튼 변형과 `account-choice`(design #389), 슬롯 원고(writing #388)

## 1. 목적과 범위

로그인을 대역에서 실제 제공자 넷(카카오·LINE·Google·Apple, D82 ①)으로 바꾸고, 한 계정에 제공자를 붙이고 떼는 로그인 수단 화면과 두 계정을 합치는 화면을 만듭니다.

카카오·Apple 인터페이스(`KakaoAuth`·`AppleNativeAuth`·`AppleWebAuth`), nonce 규칙(`NonceGenerator`·`hashNonce`), authorize URL과 복귀 해석(`buildAppleAuthorizeUri`·`parseAppleWebReturn`), 로그인 흐름(`LoginController`)은 이미 있습니다. 이 spec은 다음을 다룹니다.
* 네 제공자의 실제 adapter, 설정값 주입, 네이티브 설정(§3~§5)
* 로그인과 붙이기가 함께 쓰는 제공자 인증 경계(§6)
* 로그인 화면의 네 버튼(§7), 로그인 수단 화면(§8), 계정 합치기 화면(§9)

**성공 기준**
* fake 모드와 기존 테스트·Patrol 흐름이 그대로 통과합니다.
* 실제 adapter의 로직(nonce 전달, 취소·실패 변환, 카카오톡 → 계정 전환, SDK 세션 정리, 설정 없음)은 SDK 없이 단위 테스트로 검증합니다.
* 외부 준비물(카카오 앱, LINE 채널, Google OAuth client, Apple Services ID, 서비스 도메인)이 생기면 `app/config/auth.json` 값만 채워 실기기에서 로그인할 수 있습니다.
* 로그인 수단·계정 합치기 화면은 fake repository로 IA 상태·출구를 모두 지나고, `ia_pending.dart`에서 `settings`·`login-methods`·`account-merge`가 빠집니다.

**다루지 않는 것**
* 연결·떼기·합치기와 LINE·Google 로그인의 http 구현: server 계약(#386)이 오면 계획 단계 C(§12)에서 합니다.
* FCM과 알림 기기 호출 시점(#347 ②), AdMob·RevenueCat·Crashlytics adapter, `ad-free` 화면: 계획 7의 다른 부분입니다.
* release·Play App Signing 서명 지문과 스토어 URL(#311 ③): Google Play 개발자 계정이 생긴 뒤입니다. 패키지 이름과 debug 지문은 #114에 이미 남겼습니다.
* server 설정(`APP_LINK_BASE`, `assetlinks.json`)과 도메인 구입: server와 사용자 몫입니다.

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
* **`SocialProvider` 위치:** 지금 `lib/design/components/action/social_login_button.dart`에 있는 enum에 `line`·`google`을 더합니다. 화면·adapter·repository가 모두 이 enum을 씁니다.

## 4. 설정 (결정 A68)

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
* **SDK 세션 정리(결정 A69):** id_token을 받은 뒤 제공자 SDK에 남은 세션을 지웁니다. 계정은 server 토큰으로만 유지하고, 다음 인증(로그인·붙이기) 때 사용자가 제공자 계정을 다시 고를 수 있게 하려는 것입니다. 지우기 실패는 인증을 막지 않습니다.

### 5.1. 카카오

1. 설정이 없으면 `ProviderNotConfigured`를 던집니다.
2. 카카오톡이 설치돼 있으면(`isKakaoTalkInstalled`) `loginWithKakaoTalk(nonce: 해시)`를 부릅니다.
   * `PlatformException` `CANCELED`이면 `SocialSignInCancelled`를 던집니다. 카카오 공식 예제처럼 계정 로그인으로 넘어가지 않습니다.
   * 그 밖의 실패(카카오톡에 연결된 계정 없음 등)면 3으로 넘어갑니다.
3. `loginWithKakaoAccount(nonce: 해시)`를 부릅니다. `CANCELED`이면 `SocialSignInCancelled`, 그 밖의 오류는 그대로 던집니다(`LoginController`가 모음).
4. `OAuthToken.idToken`이 없으면(카카오 콘솔 OpenID Connect 미설정) `StateError`입니다.
5. 세션 정리: SDK `TokenManager`에 저장된 카카오 토큰을 지웁니다(`TokenManagerProvider.instance.manager.clear()`).

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

### 5.4. Google (결정 A70)

1. 설정이 없으면(`GOOGLE_SERVER_CLIENT_ID`가 비거나, iOS에서 `GOOGLE_IOS_CLIENT_ID`가 빔) `ProviderNotConfigured`를 던집니다.
2. 처음 부를 때 한 번만 `initialize(clientId: iOS면 GOOGLE_IOS_CLIENT_ID, serverClientId: GOOGLE_SERVER_CLIENT_ID, nonce: hashNonce(프로세스 nonce))`를 부릅니다. 프로세스 nonce는 이때 `NonceGenerator`로 만든 원문이고 앱이 꺼질 때까지 같습니다. 초기화 future를 adapter가 들고 있어 동시에 불러도 한 번만 초기화합니다. 받은 `rawNonce` 인자는 쓰지 않습니다.
3. `authenticate()`를 부릅니다. `GoogleSignInExceptionCode.canceled`이면 `SocialSignInCancelled`, 그 밖의 오류는 그대로 던집니다.
4. `authentication.idToken`이 없으면 `StateError`입니다. `GoogleCredential(idToken, rawNonce: 프로세스 nonce 원문)`을 돌려주고, 호출하는 쪽은 이 `rawNonce`를 server에 보냅니다.
5. 세션 정리: `signOut()`. 다음 인증 때 계정 선택이 다시 뜹니다.

> server #386에 "Google nonce는 로그인마다가 아니라 앱 프로세스마다 하나"라는 제약을 코멘트로 알립니다. server가 nonce를 일회용으로 확인하려 하면 이 제약과 맞지 않습니다.

### 5.5. Apple Android 웹 (결정 A67, A12 갱신)

1. `APPLE_SERVICES_ID`·`APPLE_REDIRECT_URI`·`APP_LINK_HOST` 중 하나라도 비면 `ProviderNotConfigured`를 던집니다.
2. `state`를 `NonceGenerator`로 만들고, `buildAppleAuthorizeUri(clientId: Services ID, redirectUri, hashedNonce: 해시, state)`를 만듭니다.
3. `FlutterWebAuth2.authenticate(url, callbackUrlScheme: 'https', options: FlutterWebAuth2Options(httpsHost: APP_LINK_HOST, httpsPath: '/auth/apple'))`로 엽니다.
4. 결과 문자열을 `parseAppleWebReturn(Uri.parse(결과), expectedState: state)`로 해석해 돌려줍니다.
5. `PlatformException` `CANCELED`(탭을 닫음, 또는 콜백 없이 앱으로 돌아옴)이면 `AppleWebFailure(AppleWebError.userCancelled)`를 돌려줍니다. 그 밖의 `PlatformException`은 그대로 던집니다.

**경로별 동작**
* **App Link 검증됨:** Apple → server 콜백 → 303 `https://<APP_LINK_HOST>/auth/apple?exchange=…&state=…`를 Auth Tab이 받아 결과로 돌려줍니다.
* **링크가 앱을 열지 못함:** server 안내 페이지(S22 §2.3)의 intent 링크가 같은 `CallbackActivity`로 들어와, 기다리던 `authenticate`가 끝납니다.
* **기다리는 로그인이 없음**(앱이 내려간 뒤 돌아온 링크): `CallbackActivity`가 링크를 버리고 앱을 엽니다. nonce 원문이 메모리에만 있어 그 교환 코드는 쓸 수 없고, 사용자는 다시 시도합니다.
* **붙이기에서의 Android Apple:** server 콜백은 로그인과 붙이기를 가리지 않고 교환 코드를 줍니다. 그 교환 코드를 로그인 API로 보낼지 붙이기 API로 보낼지는 app이 정합니다(§6). server 계약이 교환 코드 붙이기를 받지 않으면 §12 C에서 다시 봅니다.

## 6. 제공자 인증 경계 (결정 A71)

로그인과 붙이기(D82 ⑤ "그 제공자로 다시 인증")는 제공자 인증이 같고 server에 보내는 곳만 다릅니다. 그래서 인증을 한 단위로 떼어 둘이 함께 씁니다.

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
* `AuthRepository.login(ProviderProof)`가 proof 종류·제공자로 operation을 고릅니다. 지금 있는 `kakao`·`appleNative`·`appleWeb`은 그 안으로 들어갑니다. LINE·Google은 server 계약 전까지 `ProviderNotSupportedYet`(§12 C에서 지움)을 던져 화면이 일반 실패 안내를 보입니다.
* `LoginController`의 `signInWithKakao`·`signInWithApple`은 `signIn(SocialProvider)` 하나로 합칩니다. 시도마다 nonce를 만들고, 진행 중이면 같은 결과를 돌려주고, 성공 뒤 토큰 저장·진입 계산을 하는 지금 규칙은 그대로입니다.

## 7. 로그인 화면 (`login`)

* 네 버튼을 같은 크기·같은 무게로 세로로 둡니다(D82 ①).
* 순서: 기본은 카카오, LINE, Google, Apple이고, 앱 언어의 대표 제공자만 맨 위로 올립니다.

| 언어 | 순서 |
| --- | --- |
| ko | 카카오, LINE, Google, Apple |
| ja | LINE, 카카오, Google, Apple |
| en | Google, 카카오, LINE, Apple |

  순서는 `loginProviderOrder(Locale)` 순수 함수 하나가 정하고 단위 테스트합니다. 지원하지 않는 언어는 en을 따릅니다(기본 언어 en, REST `Accept-Language` 규칙과 같음).
* `SocialLoginButton`에 `line`·`google` 변형을 더합니다. 색·로고는 design #389가 오기 전까지 각 제공자 브랜드 가이드의 기본형을 따른 임시 값으로 두고, golden을 함께 고칩니다.
* 라벨 `loginLineLabel`·`loginGoogleLabel`은 writing #388 전까지 임시 키입니다(§10).
* 오류 안내(`login.error.body`)와 상태는 지금과 같습니다.

## 8. 로그인 수단 화면 (`login-methods`)

**들어오는 곳:** 설정 화면에 "로그인 수단" 줄(`settings-row`)을 더하고 이 화면으로 갑니다. 설정의 출구가 IA와 같아져 `ia_pending.dart`의 `pendingExitScreens`에서 `settings`를 지웁니다.

**그리는 것**
* app-bar 제목, `login-methods.intro.body`
* 제공자 네 줄(순서는 §7과 같음). 줄마다 제공자 이름과 상태
  * 연결됨: "떼기" 동작. 연결이 하나뿐이면 떼기를 막고 줄 아래에 `login-methods.last.notice`
  * 연결 안 됨: `social-login-button`(그 제공자)으로 붙이기
* `error` 상태: 붙이기·떼기를 끝내지 못하면 `login-methods.error.body`를 보입니다(인증 창을 닫음 포함, IA state note).

**붙이기 흐름**
1. 새 원문 nonce로 `ProviderAuthenticator.authenticate`.
2. `AccountLinkRepository.link(proof)` 결과:
   * `Linked(methods)`: 목록을 갱신합니다.
   * `LinkConflict(mergeTicket)`: 그 제공자가 다른 계정에 있습니다. 합치기 표(일회용, D82 ⑥ 소유 확인)를 들고 `account-merge`로 갑니다.
3. 취소·Apple 웹 실패·`AppError`는 `error` 상태입니다.

**떼기 흐름:** `login-methods.unlink.confirm` dialog → `AccountLinkRepository.unlink(provider)` → 목록 갱신. 마지막 하나는 화면이 막고, server가 같은 이유로 거절해도 `error` 상태로 안내합니다. 제공자 쪽 연결 해제는 server가 합니다(D82 ⑤).

**상태 관리:** `LoginMethodsController`(AsyncNotifier)가 목록 읽기·붙이기·떼기를 갖고, 진행 중에는 다른 줄의 동작을 막습니다(`LoginController`의 진행 중 규칙과 같음).

## 9. 계정 합치기 화면 (`account-merge`)

**들어오는 값:** `LinkConflict`의 합치기 표(route extra). 표 없이 들어오면(앱 재시작 등) `login-methods`로 돌려보냅니다.

**그리는 것**
* app-bar 제목, `account-merge.title.head`·`title.body`
* `loading` 상태: `AccountLinkRepository.mergePreview(ticket)`로 두 계정 요약을 불러오는 중
* `account-merge.choice.label`과 `account-choice` 두 장(지금 계정, 다른 계정). 요약은 호칭, 사주 요약 한 줄, 일기 수, 연결 수단입니다. 처음에는 지금 계정이 골라져 있습니다.
* **옮겨질 일기 수:** 일기는 같은 날 것까지 지우지 않고 모두 옮깁니다(D83 ④). 고르지 않은 쪽 카드의 일기 수가 남는 계정으로 옮겨질 일기 수이고, 고른 쪽이 바뀌면 두 카드의 표시가 서로 바뀝니다. 표시 모양은 design #389, 문구는 writing #388을 따릅니다. 지워질 일기 수는 없습니다.
* `account-merge.overlap.notice`: 두 계정에 같은 날 일기가 있을 때만, 겹쳐도 지우지 않고 모두 옮긴다고 알립니다. 어느 쪽을 고르든 같으므로 고르기와 상관없이 미리보기의 겹침 여부로 정합니다.
* `account-merge.cta.merge`(primary-button)와 `account-merge.cta.cancel`
* `error` 상태: 미리보기·합치기 실패. 합치기 표가 만료됐으면 붙이기부터 다시 하도록 안내하고 `login-methods`로 돌아갑니다.

**합치기 흐름**
1. 합치기 → `account-merge.merge.confirm` dialog(되돌릴 수 없음). 확인 없이는 부르지 않습니다(D82 ⑥).
2. `AccountLinkRepository.merge(ticket, keep: 고른 계정)`.
3. 남는 계정이 지금 로그인한 계정이 아니면 응답의 새 토큰을 저장하고 진입 갈래를 다시 계산합니다(로그인 성공과 같은 처리 `_Session`을 함께 씀).
4. 끝나면 `login-methods`로 돌아가 목록을 다시 읽습니다. 합치지 않기도 `login-methods`로 돌아갑니다.

**`account-choice` 컴포넌트:** IA에 있고 design 명세는 #389에서 옵니다. 그 전까지 `lib/design/components/`에 고를 수 있는 카드(radio 의미, 접근성 `selected`)로 만들고, 명세가 오면 맞춥니다.

## 10. 데이터 경계와 문구

**`AccountLinkRepository`**(interface, `lib/features/account/data/account_link_repository.dart`)

| 메서드 | 돌려주는 것 |
| --- | --- |
| `methods()` | 연결된 제공자 목록 |
| `link(ProviderProof)` | `Linked(methods)` 또는 `LinkConflict(MergeTicket)` |
| `unlink(SocialProvider)` | 남은 목록 |
| `mergePreview(MergeTicket)` | 두 계정 요약(일기 수 포함)과 같은 날 일기가 겹치는지. 값 모양은 server #407 ④ 계약을 따릅니다 |
| `merge(MergeTicket, {required MergeKeep keep})` | 남은 계정의 토큰(지금 계정을 남기면 없음) |

* 값 타입은 app 모델로 둡니다. server 계약이 오면 http 구현이 생성 모델을 이 타입으로 옮깁니다(§12 C).
* **fake 구현:** `FakeAccountLinkRepository`가 메모리 목록으로 위 동작을 흉내 냅니다. 특정 제공자(fake 규칙: Google)를 붙이면 `LinkConflict`가 나 합치기 흐름을 지나게 합니다. fake 모드(`ApiMode.fake`)와 http 모드 모두 계약 전까지 이 구현을 씁니다. 화면 테스트·Patrol은 fake로 돕니다.
* **문구:** IA 슬롯은 writing #398이 키 없는 틀만 만들었습니다. app은 슬롯 id의 lowerCamelCase 키(`loginMethodsIntroBody` 등)와 `loginLineLabel`·`loginGoogleLabel`을 임시 키로 더합니다(`@키.description`에 `임시`, `_allowedTemporaryKeys`). #388 원고가 오면 `tool/import_writing_arb.dart`로 바꿉니다.

## 11. 결정 기록 (`app/docs/decisions.md`)

* **A67 (A12 갱신):** Android Apple 웹 로그인은 `flutter_web_auth_2`로 열고 https 콜백(`/auth/apple`)을 받습니다. Auth Tab이 기본이고, 지원하지 않는 브라우저에서는 Custom Tabs로 대체합니다.
  * 근거: 탭을 닫은 취소를 플랫폼이 알려 주고, 링크가 `CallbackActivity`로만 와서 라우터 가로채기가 필요 없습니다. `app_links`와 직접 띄운 브라우저 조합은 취소를 앱 재개로 추정해야 합니다.
  * 안정판 5.x를 씁니다. 6.x(AGP 9 전용)가 안정판이 되고 호환 설정(`builtInKotlin=false`)을 걷어 낼 때 함께 올립니다.
* **A68:** 비밀이 아닌 제공자 식별자는 `app/config/auth.json` 한 곳에 커밋합니다. Dart는 `--dart-define-from-file`, Gradle은 `manifestPlaceholders`, iOS는 생성한 `Auth.xcconfig`로 읽고, 동기화는 `contract` 테스트가 확인합니다. 빈 값이면 해당 adapter가 `ProviderNotConfigured`입니다.
* **A69:** 카카오는 카카오톡이 있으면 카카오톡, 실패하면 계정 로그인입니다(공식 예제). 사용자 취소는 계정 로그인으로 넘어가지 않습니다. SDK 선택 시트(`loginWithKakao`)는 디자인 시스템 밖 UI라 쓰지 않습니다. 모든 제공자는 id_token을 받은 뒤 SDK 세션을 지웁니다(카카오 토큰 삭제, LINE `logout`, Google `signOut`).
* **A70:** LINE은 `flutter_line_sdk` 2.7.2, Google은 `google_sign_in` 7.2.0입니다.
  * LINE 3.x는 AGP built-in Kotlin을 요구해 `flutter_web_auth_2` 5.x와 함께 쓸 수 없습니다. 둘을 함께 3.x·6.x로 올리고 호환 설정을 걷어 냅니다(A67과 같은 시점).
  * 네 제공자 모두 제공자에게 nonce 해시를, server에 원문을 보냅니다.
  * Google SDK는 nonce를 `initialize` 한 번에만 받으므로, 프로세스마다 원문 nonce 하나를 만들어 앱이 꺼질 때까지 씁니다. adapter가 실제로 쓴 원문을 credential로 돌려줍니다.
  * LINE·Google 모두 이메일·프로필 scope를 받지 않습니다(D82 ④).
* **A71:** 제공자 인증(`ProviderAuthenticator` → `ProviderProof`)은 로그인과 로그인 수단 붙이기가 함께 씁니다. server에 보내는 곳(`AuthRepository.login`, `AccountLinkRepository.link`)만 다릅니다. 연결·합치기 데이터는 `AccountLinkRepository` interface 뒤에 두고, server 계약 전에는 fake 구현으로 화면을 만듭니다.

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
* **화면**(fake): 로그인 네 버튼과 순서, 로그인 수단의 붙이기·떼기·마지막 하나 막기·`error`, 계정 합치기의 `loading`·고르기에 따라 바뀌는 옮겨질 일기 수·겹침 안내(겹칠 때만, 고르기와 무관)·확인 dialog·토큰 교체·`error`·표 없이 들어옴. IA 계약 테스트가 세 화면의 상태·출구를 확인하고, `ia_pending.dart`에서 `settings`·`login-methods`·`account-merge`를 지웁니다.
* **golden:** `SocialLoginButton` 새 변형, `account-choice`, 두 화면.
* **부팅:** `realPlatformOverrides(ApiMode.http)`가 실제 adapter를 끼우고, fake 모드는 대역인지 확인합니다(기존 테스트에 더함).
* **계약:** `native_auth_config_test.dart`(§4).
* **Patrol:** 설정 → 로그인 수단 → 붙이기 → 계정 합치기 → 합치기 흐름 하나를 더합니다(fake).
* Android 빌드(디버그 APK)가 manifest placeholder·새 플러그인으로 깨지지 않는지는 CI `own` 범위의 APK 빌드와 로컬 빌드로 확인합니다. iOS 빌드는 로컬에서 확인합니다.

**계획 단계** (spec 하나, 구현 계획은 단계별)
* **A. 실제 로그인:** `AuthConfig`·설정 파일·네이티브 설정, adapter 다섯(카카오·LINE·Google·Apple 둘), `ProviderAuthenticator`, `LoginController` 합치기, 로그인 화면 네 버튼. 지금 진행합니다.
* **B. 로그인 수단·계정 합치기 화면:** `AccountLinkRepository`와 fake, 설정 줄, 두 화면, `account-choice`, 임시 문구. 지금 진행합니다.
* **C. http 연결:** server 계약(#386)이 REST 계약에 들어오면, 그 drift PR에서 LINE·Google 로그인 operation과 `AccountLinkRepository` http 구현을 붙이고 `ProviderNotSupportedYet`를 지웁니다.

**실기기 확인 목록**(외부 준비물 뒤, app `CLAUDE.md` 출시 전 항목에 적음)
* 카카오톡 로그인·계정 로그인·각 취소
* LINE 앱 로그인·웹 로그인(LINE 앱 없음)·취소
* Google 계정 선택·취소, 두 번째 로그인에서 계정 선택이 다시 뜨는지
* iOS Apple 로그인·취소
* Android Auth Tab이 server 303을 받는지, 안내 페이지 intent 복귀, 앱이 내려간 뒤 복귀
* `assetlinks.json` 검증(`adb shell pm get-app-links app.myungli.diary`)
* 붙이기·떼기·합치기(server 계약 뒤)

## 13. 남기는 일

* #311 ③ release 지문·스토어 URL: Play 계정 뒤. 그때까지 #311은 열어 둡니다.
* 계획 단계 C: server #386 계약 뒤. 합치기 요약 값은 server #407 ④ 계약에 맞춥니다.
* design #389·writing #388 결과가 오면 버튼·`account-choice`·문구를 맞춥니다(받은 쪽 drift 또는 요청 답으로).
* 실기기 확인 목록: 외부 준비물 뒤.
* 실기기에서 Auth Tab이 303을 받지 못하면, 안내 페이지 intent 경로가 기본이 되는지 다시 판단합니다. 이 경우 server와 페이지 문구를 맞춰야 할 수 있어 Issue로 올립니다.

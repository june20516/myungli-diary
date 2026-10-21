# 실제 로그인 adapter와 Android App Link 설계

* 작성: app 세션, 2026-10-21
* 상태: 초안 (설계 대화 승인 2026-10-21, 문서 검토 대기)
* 요청: Issue #311 (#100 ⑥, #114 ①④⑤의 남은 일)
* 관련 결정: app A12(이 spec이 A67로 갱신), A67~A69(새로 기록), 루트 D55·D64, server S15·S22
* 쓰는 계약: REST API `server/api/openapi.yaml`(`loginKakao`·`loginApple`·`completeAppleWebLogin`, 버전은 `docs/contracts/README.md` 기준), server spec `2026-10-13-apple-web-callback-design.md`

## 1. 목적과 범위

카카오·Apple 로그인을 대역에서 실제 제공자로 바꿉니다. 인터페이스(`KakaoAuth`·`AppleNativeAuth`·`AppleWebAuth`), nonce 규칙(`NonceGenerator`·`hashNonce`), authorize URL과 복귀 해석(`buildAppleAuthorizeUri`·`parseAppleWebReturn`), 로그인 흐름(`LoginController`)은 이미 있습니다. 이 spec은 그 인터페이스 뒤의 실제 구현, 설정값 주입, 네이티브 설정만 다룹니다.

**성공 기준**
* fake 모드와 기존 테스트·Patrol 흐름이 그대로 통과합니다.
* 실제 adapter의 로직(해시 전달, 취소·실패 변환, 카카오톡 → 계정 전환, 설정 없음)은 SDK 없이 단위 테스트로 검증합니다.
* 외부 준비물(카카오 앱 등록, Apple Services ID, 서비스 도메인)이 생기면 `app/config/auth.json` 값만 채워 실기기에서 로그인할 수 있습니다.

**다루지 않는 것**
* FCM과 알림 기기 호출 시점(#347 ②), AdMob·RevenueCat·Crashlytics adapter, `ad-free` 화면: 계획 7의 다른 부분입니다.
* release·Play App Signing 서명 지문과 스토어 URL(#311 ③): Google Play 개발자 계정이 생긴 뒤입니다. 패키지 이름과 debug 지문은 #114에 이미 남겼습니다.
* server 설정(`APP_LINK_BASE`, `assetlinks.json`)과 도메인 구입: server와 사용자 몫입니다.

## 2. 전제 (확인한 사실, 2026-10-21)

* 외부 준비물 셋은 아직 없습니다(`docs/roadmap.md` 외부 준비물). 그래서 값은 빈 문자열로 두고, 비어 있으면 "설정 안 됨"으로 동작합니다.
* `kakao_flutter_sdk_user` 2.0.1: `loginWithKakaoTalk`·`loginWithKakaoAccount`가 `nonce`를 받습니다. 취소는 `PlatformException(code: 'CANCELED')`입니다(`kakao_flutter_sdk_auth`의 `TalkAuthCodeActivity`·`CustomTabsActivity`). 계정 로그인 redirect는 SDK manifest의 `AuthCodeHandlerActivity`가 받습니다.
* `sign_in_with_apple` 8.2.0: `getAppleIDCredential(nonce:)`는 받은 값을 그대로 identity token에 넣습니다. 그래서 해시를 넘깁니다. 취소는 `SignInWithAppleAuthorizationException`의 `AuthorizationErrorCode.canceled`입니다.
* `flutter_web_auth_2` 5.1.0:
  * Android는 Chrome Auth Tab을 쓰고, 지원하지 않는 브라우저에서는 Custom Tabs로 대체합니다.
  * `callbackUrlScheme: 'https'`이면 `httpsHost`·`httpsPath`가 필요합니다.
  * 앱이 다시 앞으로 왔는데 콜백이 없으면 `PlatformException(code: 'CANCELED')`로 끝납니다.
  * `CallbackActivity`는 기다리는 콜백이 없으면 링크를 버리고 앱 화면으로 돌아갑니다(`callbacks.remove(scheme)?.success`).
* 6.x(AGP 9 전용)는 alpha뿐입니다. 이 프로젝트는 AGP 9.1.0이지만 `android.builtInKotlin=false`·`android.newDsl=false` 호환 설정을 쓰므로, 다른 플러그인처럼 5.1.0이 동작합니다.

## 3. 구조

| 단위 | 위치 | 하는 일 | 의존 |
| --- | --- | --- | --- |
| `AuthConfig` | `lib/core/platform/auth_config.dart` | `String.fromEnvironment`로 `KAKAO_NATIVE_APP_KEY`·`APPLE_SERVICES_ID`·`APPLE_REDIRECT_URI`·`APP_LINK_HOST`를 읽습니다. 제공자별 `isKakaoConfigured`·`isAppleWebConfigured` | 없음 |
| `KakaoSdkAuth` | `lib/core/platform/kakao_auth.dart` | `KakaoAuth`의 실제 구현 | `KakaoLoginApi`(SDK 경계) |
| `SignInWithAppleNativeAuth` | `lib/core/platform/apple_native_auth.dart` | `AppleNativeAuth`의 실제 구현(iOS) | `AppleIdCredentialApi`(SDK 경계) |
| `WebAuthAppleWebAuth` | `lib/core/platform/apple_web_auth.dart` | `AppleWebAuth`의 실제 구현(Android) | `WebAuthenticate`(SDK 경계), `NonceGenerator` |
| `ProviderNotConfigured` | `lib/core/platform/social_auth.dart` | 설정이 비어 실제 제공자를 부를 수 없음 | 없음 |

* **SDK 경계:** 각 adapter는 SDK 호출을 생성자로 받는 작은 interface(또는 함수 typedef)로 감쌉니다. 기존 `UrlExternalBrowser.launch`와 같은 방식입니다. 기본값이 실제 SDK를 부르고, 테스트는 대역을 넘깁니다. 경계 구현은 SDK 호출을 그대로 옮기기만 하고 분기를 두지 않습니다. 분기는 모두 adapter에 있어 테스트됩니다.
* **끼우기:** `realPlatformOverrides(ApiMode.http)`에 세 provider를 더합니다. 카카오 설정이 있으면 부팅 때 `KakaoSdk.init(nativeAppKey:)`를 부릅니다. fake 모드는 지금처럼 대역입니다.
* **설정이 비었을 때:** adapter가 `signIn`에서 `ProviderNotConfigured`를 던집니다. `LoginController`가 이미 `Object`를 `LoginFailed(UnexpectedError)`로 모으고 오류 요약을 보고하므로, 화면은 일반 실패 안내를 보입니다. http 모드에서 대역을 쓰지 않는 이유는 가짜 토큰을 실제 server에 보내게 되기 때문입니다.

## 4. 설정 (결정 A68)

비밀이 아닌 식별자는 앱 바이너리에 그대로 들어가는 공개 값입니다. 저장소 JSON 한 곳에 두고 세 빌드 체계가 거기서 읽습니다.

`app/config/auth.json`(지금은 모두 빈 값):

```json
{
  "KAKAO_NATIVE_APP_KEY": "",
  "APPLE_SERVICES_ID": "",
  "APPLE_REDIRECT_URI": "",
  "APP_LINK_HOST": ""
}
```

* `APPLE_REDIRECT_URI`는 server 콜백 전체 주소입니다(`<API 주소>/v1/auth/apple/callback`). Apple Services ID에 등록한 값과 글자까지 같아야 합니다. `APP_LINK_HOST`는 server `APP_LINK_BASE`의 host입니다.
* **Dart:** 실행·빌드 명령에 `--dart-define-from-file=config/auth.json`을 붙입니다. 고칠 곳은 README 실행 명령, `tool/patrol_local.sh`, `app.yml`의 빌드·E2E 단계입니다.
* **Android:** `app/build.gradle.kts`가 같은 JSON을 읽어 `manifestPlaceholders`의 `kakaoScheme`(`kakao<키>`)과 `appLinkHost`를 채웁니다. 값이 비면 어떤 링크와도 맞지 않는 `unconfigured.invalid`(scheme은 `kakao-unconfigured`)를 넣어 manifest가 항상 유효하게 합니다.
* **iOS:** `tool/gen_native_config.dart`가 JSON에서 `ios/Flutter/Auth.xcconfig`(`KAKAO_NATIVE_APP_KEY`)를 생성해 커밋하고, `Debug.xcconfig`·`Release.xcconfig`가 이 파일을 include합니다. Info.plist URL scheme은 `kakao$(KAKAO_NATIVE_APP_KEY)`입니다.
* **동기화 검사:** `test/contract/native_auth_config_test.dart`(`@Tags(['contract'])`)가 생성한 xcconfig가 JSON과 같은지, manifest에 placeholder 자리가 있는지 확인합니다.

**네이티브 설정 추가**
* Android `AndroidManifest.xml`:
  * 카카오 `com.kakao.sdk.flutter.auth.AuthCodeHandlerActivity` intent filter(`scheme=${kakaoScheme}`, `host=oauth`)
  * `com.linusu.flutter_web_auth_2.CallbackActivity`(`exported`, `taskAffinity=""`)와 `autoVerify` intent filter(`https`, `${appLinkHost}`, `path=/auth/apple`)
  * `<queries>`에 카카오톡 패키지(`com.kakao.talk`)
* MainActivity에는 App Link filter를 두지 않습니다. 링크는 `CallbackActivity`로만 오므로 Flutter 기본 deep linking과 라우터(`onException`)에 닿지 않습니다. 그래서 A12와 계획 7 메모의 "라우터보다 먼저 가로채는 전용 처리"는 만들지 않습니다.
* iOS: `LSApplicationQueriesSchemes`(`kakaokompassauth`, `kakaolink`), URL Types(`kakao$(KAKAO_NATIVE_APP_KEY)`), `Runner.entitlements`(`com.apple.developer.applesignin` = `Default`)를 Runner target에 연결합니다.

## 5. 흐름과 오류 처리

공통 규칙: `rawNonce`는 `LoginController`가 만들어 넘깁니다. adapter는 제공자에게 `hashNonce(rawNonce)`만 보내고, 원문을 로그·오류 보고에 싣지 않습니다(D64).

### 5.1. 카카오 (결정 A69)

1. 설정이 없으면 `ProviderNotConfigured`를 던집니다.
2. 카카오톡이 설치돼 있으면(`isKakaoTalkInstalled`) `loginWithKakaoTalk(nonce: 해시)`를 부릅니다.
   * `PlatformException` `CANCELED`이면 `SocialSignInCancelled`를 던집니다. 카카오 공식 예제처럼 계정 로그인으로 넘어가지 않습니다.
   * 그 밖의 실패(카카오톡에 연결된 계정 없음 등)면 3으로 넘어갑니다.
3. `loginWithKakaoAccount(nonce: 해시)`를 부릅니다. `CANCELED`이면 `SocialSignInCancelled`, 그 밖의 오류는 그대로 던집니다(`LoginController`가 모음).
4. `OAuthToken.idToken`이 없으면(카카오 콘솔 OpenID Connect 미설정) `StateError`입니다.
5. idToken을 꺼낸 뒤 SDK `TokenManager`에 저장된 카카오 토큰을 지웁니다(`TokenManagerProvider.instance.manager.clear()`). 계정은 server 토큰으로만 유지하고, 카카오 API를 따로 부르지 않으며, 제공자 토큰을 기기에 남기지 않기 위해서입니다. 지우기 실패는 로그인을 막지 않습니다.

### 5.2. Apple iOS

1. 설정은 필요 없습니다. Bundle ID와 entitlement만 씁니다.
2. `getAppleIDCredential(scopes: [], nonce: 해시)`를 부릅니다. 이름·이메일 scope는 받지 않습니다. 앱이 쓰지 않고, 웹 흐름도 scope를 보내지 않습니다(S22).
3. `AuthorizationErrorCode.canceled`이면 `SocialSignInCancelled`를 던집니다. 그 밖의 오류는 그대로 던집니다.
4. `identityToken`이 없으면 `StateError`입니다. `authorizationCode`와 함께 `AppleNativeCredential`을 돌려줍니다.

### 5.3. Apple Android 웹 (결정 A67, A12 갱신)

1. `APPLE_SERVICES_ID`·`APPLE_REDIRECT_URI`·`APP_LINK_HOST` 중 하나라도 비면 `ProviderNotConfigured`를 던집니다.
2. `state`를 `NonceGenerator`로 만들고, `buildAppleAuthorizeUri(clientId: Services ID, redirectUri, hashedNonce: 해시, state)`를 만듭니다.
3. `FlutterWebAuth2.authenticate(url, callbackUrlScheme: 'https', options: FlutterWebAuth2Options(httpsHost: APP_LINK_HOST, httpsPath: '/auth/apple'))`로 엽니다.
4. 결과 문자열을 `parseAppleWebReturn(Uri.parse(결과), expectedState: state)`로 해석해 돌려줍니다.
5. `PlatformException` `CANCELED`(탭을 닫음, 또는 콜백 없이 앱으로 돌아옴)이면 `AppleWebFailure(AppleWebError.userCancelled)`를 돌려줍니다. 그 밖의 `PlatformException`은 그대로 던집니다.

**경로별 동작**
* **App Link 검증됨:** Apple → server 콜백 → 303 `https://<APP_LINK_HOST>/auth/apple?exchange=…&state=…`를 Auth Tab이 받아 결과로 돌려줍니다.
* **링크가 앱을 열지 못함:** server 안내 페이지(S22 §2.3)의 intent 링크가 같은 `CallbackActivity`로 들어와, 기다리던 `authenticate`가 끝납니다.
* **기다리는 로그인이 없음**(앱이 내려간 뒤 돌아온 링크): `CallbackActivity`가 링크를 버리고 앱을 엽니다. nonce 원문이 메모리에만 있어 그 교환 코드는 쓸 수 없고, 사용자는 로그인 화면에서 다시 시도합니다.

## 6. 결정 기록 (`app/docs/decisions.md`)

* **A67 (A12 갱신):** Android Apple 웹 로그인은 `flutter_web_auth_2`로 열고 https 콜백(`/auth/apple`)을 받습니다. Auth Tab이 기본이고, 지원하지 않는 브라우저에서는 Custom Tabs로 대체합니다.
  * 근거: 탭을 닫은 취소를 플랫폼이 알려 주고, 링크가 `CallbackActivity`로만 와서 라우터 가로채기가 필요 없습니다. `app_links`와 직접 띄운 브라우저 조합은 취소를 앱 재개로 추정해야 합니다.
  * 안정판 5.x를 씁니다. 6.x(AGP 9 전용)가 안정판이 되고 호환 설정(`builtInKotlin=false`)을 걷어 낼 때 함께 올립니다.
* **A68:** 비밀이 아닌 제공자 식별자는 `app/config/auth.json` 한 곳에 커밋합니다. Dart는 `--dart-define-from-file`, Gradle은 `manifestPlaceholders`, iOS는 생성한 `Auth.xcconfig`로 읽고, 동기화는 `contract` 테스트가 확인합니다. 빈 값이면 해당 adapter가 `ProviderNotConfigured`입니다.
* **A69:** 카카오는 카카오톡이 있으면 카카오톡, 실패하면 계정 로그인입니다(공식 예제). 사용자 취소는 계정 로그인으로 넘어가지 않습니다. SDK 선택 시트(`loginWithKakao`)는 디자인 시스템 밖 UI라 쓰지 않습니다. idToken을 받은 뒤 카카오 SDK 토큰을 지웁니다.

## 7. 테스트

* **adapter 단위 테스트**(`test/core/`, SDK 경계 대역):
  * 카카오: 해시를 보내는지, 카카오톡 성공·취소·실패 → 계정 전환, 계정 취소, idToken 없음, 토큰 지우기(실패해도 성공), 설정 없음.
  * Apple iOS: 해시와 빈 scope, 취소 변환, identityToken 없음.
  * Apple 웹: authorize URL(Services ID·redirect·해시·state), `httpsHost`·`httpsPath`, 성공 결과 해석, state 불일치, `CANCELED` → `userCancelled`, 그 밖의 예외 전달, 설정 없음.
* **`AuthConfig`:** 빈 값·채운 값 판정.
* **부팅:** `realPlatformOverrides(ApiMode.http)`가 세 실제 adapter를 끼우고, fake 모드는 대역인지 확인합니다(기존 테스트에 더함).
* **계약:** `native_auth_config_test.dart`(§4).
* **바뀌지 않는 것:** login flow 테스트와 Patrol은 fake 모드라 그대로입니다. Android 빌드(디버그 APK)가 manifest placeholder·새 플러그인으로 깨지지 않는지는 CI `own` 범위의 APK 빌드와 로컬 빌드로 확인합니다. iOS 빌드는 로컬에서 확인합니다.
* **실기기 확인 목록**(외부 준비물 뒤, app `CLAUDE.md` 출시 전 항목에 적음):
  * 카카오톡 로그인·계정 로그인·각 취소
  * iOS Apple 로그인·취소
  * Android Auth Tab이 server 303을 받는지, 안내 페이지 intent 복귀, 앱이 내려간 뒤 복귀
  * `assetlinks.json` 검증(`adb shell pm get-app-links app.myungli.diary`)

## 8. 남기는 일

* #311 ③ release 지문·스토어 URL: Play 계정 뒤. 그때까지 #311은 열어 둡니다.
* 실기기 확인 목록(§7): 외부 준비물 뒤.
* 실기기에서 Auth Tab이 303을 받지 못하면, 안내 페이지 intent 경로가 기본이 되는지 다시 판단합니다. 이 경우 server와 페이지 문구를 맞춰야 할 수 있어 Issue로 올립니다.

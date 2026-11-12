# app — 명리일기 모바일 앱 (Flutter)

iOS·Android 앱입니다. 계약 파일(REST `openapi.yaml`, IA, 디자인 토큰, 컴포넌트 명세)을 원본으로 두고, app 코드는 그것을 생성하거나 대조합니다. 외부 SDK와 server는 모두 인터페이스 뒤에 두고 대역을 함께 둡니다.

| 무엇 | 어디 |
| --- | --- |
| 범위·계약·현재 상태·다음 할 일 | [`CLAUDE.md`](CLAUDE.md) |
| 아키텍처 spec | [`docs/specs/2026-10-13-app-architecture-design.md`](docs/specs/2026-10-13-app-architecture-design.md) |
| app 결정 로그 (A1~) | [`docs/decisions.md`](docs/decisions.md) |
| 계획 | [`docs/plans/`](docs/plans/) |
| 화면 스크린샷·E2E 커버리지 보고서 | [`docs/artifacts/`](docs/artifacts/) |

## 준비물
* Flutter stable 채널(정확한 버전은 고정하지 않습니다, 결정 A11). `flutter doctor`가 통과해야 합니다.
* iOS 빌드: Xcode. Android: Android Studio(SDK·에뮬레이터 관리, 라이선스 동의 포함).
* Docker: REST 클라이언트 생성(`tool/gen_api.sh`)과 golden 기준 이미지 생성(`tool/goldens_linux.sh`).
* [uv](https://docs.astral.sh/uv/): fixture 검증(Python 도구).
* VS Code + Flutter 확장(권장 확장은 `.vscode/extensions.json`).

처음에는 `app/`에서 `flutter pub get`을 실행합니다.

## 실행
VS Code에서 `.vscode/launch.json`의 구성을 고릅니다.

| 구성 | 내용 |
| --- | --- |
| `fake` | `--dart-define=API_MODE=fake`. 대역 서버(`fixtures/`)로 전 흐름을 돌립니다 |
| `http` | `--dart-define=API_MODE=http --dart-define=API_BASE_URL=http://localhost:8080` |

터미널에서는 다음과 같습니다. `API_MODE`를 생략하면 `http`입니다. release 빌드에서는 fake 모드를 쓸 수 없습니다.
실행·빌드 명령에는 늘 `--dart-define-from-file=config/auth.json`(로그인 제공자 공개 식별자, A81)을 붙입니다. staging이나 prod server를 쓰는 빌드는 그 뒤에 `--dart-define-from-file=config/env/<staging|prod>.json`(API 주소, Firebase 환경, App Link 호스트, Apple 복귀 주소, A97)을 하나 더 붙입니다. 환경 파일 없이 만든 빌드는 Android Apple 로그인이 `ProviderNotConfigured`로 실패합니다(로컬 server 개발은 Apple 웹 복귀를 받을 수 없음).

```
flutter run --dart-define-from-file=config/auth.json --dart-define=API_MODE=fake
flutter run --dart-define-from-file=config/auth.json --dart-define=API_MODE=fake --dart-define=SCENARIO=member
```

* **로컬 server(http):** `server/`에서 `docker compose up -d --wait`(DB, 엔진), `server migrate up`, `server seed`(콘텐츠 문장 틀. 없으면 오늘 화면이 503), `server serve`로 띄웁니다(인증 값은 로컬에서도 모두 필요합니다. 서명 키는 이 기기에서만 쓰는 임시 값으로 만들어 보관 폴더 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/local/`(D98, `docs/local-values.md` K6)에 두고 `source "${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/local/env.sh"`로 읽습니다. server 바이너리와 로그처럼 버려도 되는 것만 `app/.local/`(gitignore)에 둡니다. `KAKAO_APP_KEY`는 카카오 네이티브 앱 키입니다(id_token `aud`, #610). Android 에뮬레이터는 `adb reverse tcp:8080 tcp:8080`으로 기기의 localhost를 Mac에 잇고 `API_BASE_URL`을 비워 둡니다(debug 기본값 `http://localhost:8080`). 평문 http는 debug 빌드에서만 localhost에 허용합니다(`android/app/src/debug/res/xml/network_security_config.xml`). 미리보기, 시진 확인, 음력 변환은 App Check 요청입니다. debug 빌드는 staging Firebase의 debug provider를 쓰고, 토큰은 콘솔에 등록한 고정 값을 `--dart-define-from-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/staging/dart-defines.json"`(`APP_CHECK_DEBUG_TOKEN`, D98 K4, #659)으로 넘깁니다. debug provider는 넘긴 고정 토큰도 logcat(`DebugAppCheckProvider`)에 그대로 찍으니 그 로그를 공유하거나 붙여 넣지 않습니다. 파일 없이 실행하면 SDK가 첫 실행 때 만든 토큰을 로그에 찍고, 그 토큰을 콘솔에 등록하기 전까지는 헤더 없이 나갑니다(#657). release는 staging이어도 기기 증명(Android Play Integrity, iOS DeviceCheck)만 씁니다.
* **staging 빌드(Play 내부 테스트):** release는 저장소 밖 보관 폴더의 업로드 키로 서명합니다(A94, D98 K1). 키는 한 번만 만들고, 두 파일은 잃으면 다시 얻을 수 없으니 기기 밖(비밀번호 관리자 등)에 꼭 백업합니다. 파일이 없으면 release도 debug 키로 서명되고 Gradle이 경고를 한 줄 냅니다(Play에 올릴 수 없음).
  ```
  D="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/shared"; mkdir -p "$D" && chmod 700 "$D"
  keytool -genkeypair -v -keystore "$D/upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  # $D/key.properties: storeFile=upload-keystore.jks, storePassword=…, keyAlias=upload, keyPassword=…
  chmod 600 "$D"/*
  flutter build appbundle --release --dart-define-from-file=config/auth.json \
    --dart-define-from-file=config/env/staging.json
  # 상품이 생기면(E12) --dart-define=AD_FREE_PRODUCT_IDS=<상품 id>를 더합니다
  ```
  상품 id는 스토어 상품이 생긴 뒤(E12, 판매는 E15 뒤) 로컬 값으로 넘깁니다. 그 전 빌드나 id를 빠뜨린 빌드는 상품 목록이 비어, 광고 제거 화면이 가격과 구매 버튼 없는 카드(설명, 기간 고지, 구매 내역, 약관 안내)를 보입니다. 오류가 아니라 정상 상태라 Crashlytics에도 남지 않으니, 상품이 생긴 뒤 빌드에서는 구매 버튼이 보이는지 기기에서 직접 확인합니다(A126, #922). release + staging은 Test Store 상품을 받지 못하므로 광고 제거권은 결제 없이 시험합니다(D99 ④).
  `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`의 SHA256이 업로드 키 저장소(`keytool -list -v`)의 지문과 같은지 확인합니다. 빌드 번호는 아래 "스토어 빌드 번호"를 따릅니다. 앱 서명 키는 Play가 보관합니다(E8).
* **스토어 빌드 번호(A104, #735):** `pubspec.yaml`의 `+N` 하나를 두 플랫폼이 함께 쓰고, N은 커밋 하나를 가리킵니다. 스토어에 낼 빌드를 만들 때 `+N`을 올려 commit하고 그 커밋에서 빌드합니다. 바뀐 것이 한 플랫폼에만 해당하면 그 플랫폼만 빌드해 올리고, 다른 플랫폼은 그 번호를 건너뜁니다. 올린 플랫폼과 N은 `CLAUDE.md` 현재 상태의 스토어 빌드 줄에 적습니다. release에서만 나는 문제(R8 축소 등, #728)는 debug와 Patrol로 잡히지 않으니, 올리기 전에 release 빌드를 기기에서 한 번 실행합니다(Android는 `bundletool build-apks --mode=universal`로 AAB에서 APK를 뽑아 설치).
* **iOS TestFlight(A103):** 자동 서명, 팀 `7JGP3D7B3Z`, App Store Connect 앱 `6829967838`. 이 Mac의 Xcode > Settings > Accounts에 팀 Apple ID가 로그인되어 있어야 합니다. 배포 인증서와 profile은 export 때 Xcode가 만듭니다(`-allowProvisioningUpdates`).
  ```
  flutter build ipa --release --dart-define-from-file=config/auth.json \
    --dart-define-from-file=config/env/staging.json --export-options-plist=ios/ExportOptions.plist
  # 올리기 전 확인: build/ios/ipa/*.ipa를 풀어 codesign -d --entitlements :- Payload/*.app
  #   (aps-environment production, applesignin), Info.plist의 CFBundleVersion
  cp ios/ExportOptions.plist /tmp/ExportOptionsUpload.plist
  plutil -replace destination -string upload /tmp/ExportOptionsUpload.plist
  xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
    -exportOptionsPlist /tmp/ExportOptionsUpload.plist -exportPath /tmp/upload -allowProvisioningUpdates
  ```
  * `ios/ExportOptions.plist`는 IPA만 만들고(`destination=export`), 확인한 같은 archive를 `upload`로 다시 export해 올립니다. 빌드 번호는 Android와 같은 `pubspec.yaml`의 `+N`이고, 올릴 때마다 올립니다.
  * entitlements 파일의 `aps-environment`는 `development` 그대로 둡니다. 자동 서명이 배포 profile의 값(production)으로 바꿔 넣습니다(1.0.0 (2)에서 확인).
* **Crashlytics 심볼(A105, #739):** 스토어에 올린 빌드마다, 다시 빌드하기 전에 그 빌드의 심볼을 올려야 스택이 읽힙니다. Firebase CLI 로그인(`firebase login`)이 필요하고, 빌드에 준 환경과 같은 환경을 줍니다.
  ```
  tool/upload_crashlytics_symbols.sh staging android   # flutter build appbundle 직후
  tool/upload_crashlytics_symbols.sh staging ios       # flutter build ipa 직후
  ```
  * Android: release 빌드마다 Gradle이 새 mapping file id 리소스(`com.google.firebase.crashlytics.mapping_file_id`)를 넣고(`android/app/build.gradle.kts`), 스크립트가 그 id와 R8 `mapping.txt`를 함께 올립니다. Android Crashlytics는 이 id(build ID)가 없으면 시작하지 않습니다. google-services와 Crashlytics Gradle 플러그인은 쓰지 않습니다(A93).
  * iOS: archive의 dSYM을 Crashlytics SDK의 `upload-symbols`로 올립니다.
  * Dart는 난독화하지 않아(`--obfuscate` 없음) Dart 스택은 그대로 읽힙니다.
  * **보고 경로 시험:** `--dart-define=CRASHLYTICS_SELF_TEST=true`를 더한 release 빌드는 실행할 때마다 시험용 비치명 오류(`CrashlyticsSelfTest`)를 기록합니다. Android 치명 충돌은 `adb shell am crash app.myungli.diary`로 냅니다. Crashlytics는 다음 실행 때 보고를 보냅니다(`adb shell setprop log.tag.FirebaseCrashlytics DEBUG`로 logcat에서 확인). 시험 빌드는 스토어에 올리지 않습니다.
  * **알림 메일:** Firebase 콘솔 **프로젝트 설정 → Alerts**(`console.firebase.google.com/project/<프로젝트 id>/settings/alerts`)에서 계정마다 켭니다. 새 치명, 새 비치명, ANR, 급증 알림은 기본으로 꺼져 있습니다. staging은 켰고 prod는 출시 전에 켭니다.
  * Firebase 초기화(Dart) 전에 나는 native 충돌(예 #728의 `androidx.startup` 단계)은 Crashlytics가 아직 없어 잡히지 않습니다. 그런 충돌은 Play Console의 Android vitals와 `adb logcat -b crash`로 봅니다.
  * 처음 서명할 때 키체인 창이 framework마다 반복해서 뜨면 `security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db`(로그인 키체인 암호를 물음)로 codesign 허용을 한 번에 등록합니다. 요청한 빌드가 끝났는데 창이 남으면 `SecurityAgent`를 종료하면 닫힙니다.
* **빌드 모드와 환경 값(D99 ①):** 둘은 따로입니다. 빌드 모드는 `flutter run`(debug)과 `flutter build --release`(release), 환경 값은 붙이는 환경 파일(`config/env/<staging|prod>.json`, A97)입니다. staging은 빌드 모드가 아니라 환경 값이라 debug와 release 모두 staging server에 붙을 수 있습니다.

  | 빌드 모드 \ 환경 | 환경 파일 없음(로컬 server) | staging | prod |
  | --- | --- | --- | --- |
  | debug | 개발. App Check debug provider, RevenueCat Test Store 키 | 결제 흐름 전체 시험(아래 명령). App Check debug token(K4), Test Store 키 | 쓰지 않음 |
  | release | 쓰지 않음 | T1 테스터(Play 내부 테스트). Play Integrity·DeviceCheck, 플랫폼 키라 Test Store 불가(결제 없이 광고 제거권은 #655) | 출시 |

  RevenueCat 키는 빌드 모드로 고릅니다(A98): debug는 Test Store 키, release는 Android `goog_…`, iOS `appl_…`이고, release 바이너리에는 Test Store 키 문자열이 들어가지 않습니다(SDK가 release에서 Test Store 키를 보면 앱을 종료함). App Check provider도 같은 축입니다(debug이고 staging이면 debug provider, A95).
* **결제 시험(debug + staging, D99 ④):** staging server가 결제를 켠 뒤(server S123) 다음으로 실행합니다. `AD_FREE_PRODUCT_IDS`는 **스토어 상품 id**(`getProducts`로 찾는 값, 세 스토어가 같은 값)입니다. server의 같은 이름 설정은 RevenueCat 상품 id(`prod…`, S124)라 값이 다릅니다.
  ```
  flutter run --dart-define-from-file=config/auth.json --dart-define-from-file=config/env/staging.json \
    --dart-define-from-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/staging/dart-defines.json" \
    --dart-define=AD_FREE_PRODUCT_IDS=<스토어 상품 id>
  ```
* **광고 시험(staging, D101, A106):** 광고 단위는 빌드 모드로(debug는 Google 테스트 단위, release는 실제 단위, A99), 모의 광고와 보상 경로는 환경 파일의 `STAGING_ADS`(staging `"true"`, prod `"false"`)로 고릅니다.
  * staging: AdMob을 먼저 불러오고, 광고를 받지 못하면(채울 광고 없음, 앱 검토 전) 같은 자리, 같은 크기의 모의 광고("모의 광고" 배너, 15초 전체 화면 보상형)를 보입니다. 보상형을 끝까지 보면 광고 출처와 상관없이 staging 전용 경로(`POST /test/v1/billing/rewarded-ad`, server S131)로 SSV와 같은 값을 보내고, 실제와 같은 `getEntitlements`로 권한을 다시 읽습니다. 테스트 광고와 검토 전 앱에는 SSV 콜백이 오지 않기 때문입니다(#741).
  * prod: AdMob만, 보상은 SSV 콜백만입니다. `STAGING_ADS`가 상수 false라 staging 분기는 prod 바이너리에서 빠집니다.
  * 광고 불러오기 실패는 debug 콘솔에 `AdMob 불러오기 실패 <domain> <code>`로, staging에서는 Crashlytics 비치명 오류(`AdMobLoadFailure`, code `<domain>.<code>`)로 남습니다. Android 광고 없음은 3, iOS 광고 없음은 1입니다.
  * **테스트 기기:** 실제 단위(release)로 실기기에서 광고를 누르면 계정 정지 사유가 되니 시험 기기는 AdMob에 등록합니다. AdMob 콘솔 **설정 → 테스트 기기 → 테스트 기기 추가**에서 플랫폼과 광고 식별자를 넣습니다(반영까지 보통 1시간, 길면 24시간). Android는 휴대폰 **설정 → Google → 광고**의 광고 ID, iOS는 IDFA입니다. iOS는 IDFA를 기본으로 보여 주지 않아 IDFA를 보여 주는 앱(App Store)이 필요하고, 앱 추적을 허용하지 않은 기기에서는 IDFA가 0으로 나올 수 있으니 그 앱의 추적을 허용합니다. iOS 시뮬레이터는 자동으로 테스트 기기입니다. 등록되면 광고에 "Test mode"(또는 "Test Ad") 표시가 붙습니다.
* **시나리오:** fake 모드의 시작 상태입니다. `SCENARIO`를 생략하면 `new-user`입니다.

  | id | 상태 |
  | --- | --- |
  | `new-user` | 처음 설치. 토큰 없음. 로그인하면 새 계정(약관 동의 필요, 프로필 없음). 동의하면 미리보기 입력으로 프로필을 저장합니다 |
  | `member` | 로그인한 회원. 약관 동의, 프로필 있음. 로그인 수단 연결 목록은 처음 카카오 하나이고, Google 붙이기는 409 `auth.identity_in_use`, 마지막 하나 떼기는 409 `auth.last_identity`, 합치기 인증은 연결된 제공자면 422 `merge.same_account`, Apple이면 422 `merge.no_account`, 그 밖은 요약 200입니다 |
  | `consent-required` | 로그인했지만 약관 동의 필요 |
  | `profile-required` | 약관 동의했지만 프로필 없음. 프로필을 저장하면 내 정보가 프로필 있음으로 바뀝니다 |
  | `member-overseas` | 한국 밖(America/Los_Angeles) 기기의 회원. 기기 시간대가 한국이 아니고 프로필 언어가 en이라 앱이 영어입니다(A60) |
  | `force-update` | 최소 앱 버전이 99.0.0이라 업데이트 필요 |
  | `offline` | 네트워크에 연결할 수 없음 |
  | `overseas` | 한국 밖(기기 지역 US) 기기에서 처음 설치한 사용자. 시진 확인 줄과 출생지 질문 갈래를 확인합니다 |
  | `birth-hour-unavailable` | 처음 설치한 사용자. 시진 확인(getBirthHour)이 503 service.unavailable이라 확인 줄이 보이지 않습니다 |
  | `birth-hour-rate-limited` | 처음 설치한 사용자. 시진 확인(getBirthHour)이 분당 한도(429 rate_limited)에 걸려 확인 줄이 보이지 않습니다 |
  | `cities-error` | 한국 밖 기기의 처음 설치한 사용자. 도시 검색(listCities)이 503이라 출생지 오류 상태를 확인합니다 |
  | `cities-slow` | 한국 밖 기기의 처음 설치한 사용자. 응답마다 1초가 걸려 도시 검색 중 skeleton을 확인합니다 |
  | `time-unknown` | 처음 설치한 사용자. 미리보기(createPreview)에 time_unknown notice가 있어 시간 모름 배너가 보입니다 |
  | `preview-used` | 처음 설치한 사용자. 미리보기(createPreview)가 이미 쓰여 403 preview.used로 답합니다 |
  | `preview-invalid` | 처음 설치한 사용자. 미리보기(createPreview)가 422 birth.invalid로 답해 입력을 다시 받아야 합니다 |
  | `returning-user` | 사주가 저장된 계정으로 이 기기에 처음 로그인하는 사용자. 토큰 없음, 로그인하면 기존 계정(isNewAccount false)이고 내 정보는 `member`와 같음(약관 동의, 프로필 있음) |
  | `consented-no-profile` | 약관에 동의했지만 사주가 없는 계정으로 이 기기에 처음 로그인하는 사용자. 토큰 없음, 로그인하면 기존 계정(isNewAccount false, consentRequired false)이고 getMe는 로그인 직후 두 번(사주 확인, 진입 계산)은 프로필 없음, 프로필을 만든 뒤 있음(D90 ③) |
  | `consented-profile-invalid` | `consented-no-profile`과 같지만 프로필 저장(`createProfile`)이 422 `birth.invalid`라 로그인 뒤 `onboard-call`에서 안내하고 입력을 고칩니다. getMe는 늘 프로필 없음 |
  | `login-provider-down` | 처음 설치한 사용자. 카카오 로그인(loginKakao)이 503 auth.provider_unavailable이라 로그인 오류 상태와 재시도를 확인합니다 |
  | `login-exchange-invalid` | 처음 설치한 사용자. Android Apple 웹 로그인 완료(completeAppleWebLogin)가 401 auth.exchange_invalid라 처음부터 다시 로그인 안내를 확인합니다 |
  | `new-user-signin` | 미리보기 없이 로그인한 새 계정. 약관 동의 뒤 onboard-call부터 입력을 받고 미리보기 없이 프로필을 저장합니다 |
  | `consent-mismatch` | 로그인했고 약관 동의가 필요한 새 계정. 동의(agreeConsents)가 422 consent.version_mismatch이고 다시 받은 내 정보의 이용약관 버전이 바뀌어 있습니다 |
  | `profile-invalid` | 처음 설치한 사용자. 미리보기 뒤 로그인·약관 동의까지 하지만 프로필 저장(createProfile)이 422 birth.invalid라 입력을 다시 받아야 합니다 |
  | `profile-save-unavailable` | 처음 설치한 사용자. 미리보기 뒤 로그인·약관 동의까지 하지만 프로필 저장(createProfile)이 두 번 503 service.unavailable이고 세 번째에 저장됩니다 |
  | `notify-register-unavailable` | 로그인한 회원. 알림 허락 뒤 기기 등록(registerDevice)이 한 번 503 service.unavailable이고 두 번째에 등록됩니다. 알림 허락 대기(notify-ask)는 기기 플래그라 시나리오가 아니라 테스트가 켭니다 |
  | `consent-renewal` | 프로필이 있는 회원. 약관이 개정돼 동의가 필요하고, 동의하면 내 정보가 동의 완료로 바뀝니다(getMe 두 번째 응답부터). 동의 뒤 today로 가는지 확인합니다 |
  | `notify-profile-save-unavailable` | 로그인한 회원. 알림 허락 뒤 기기 등록은 성공하지만 알림 설정 저장(updateProfile)이 한 번 503 service.unavailable이고 두 번째에 저장됩니다 |
  | `profile-name-invalid` | 미리보기 없이 로그인한 새 계정(`new-user-signin`과 같음). 첫 프로필 저장(createProfile)이 422 name.emoji(필드 `/honorific`)이고 두 번째에 저장됩니다. 호칭 칸 오류 줄을 확인합니다 |
  | `login-entry-unavailable` | 처음 설치한 사용자. 로그인은 성공하지만 직후 내 정보(getMe)가 한 번 503 service.unavailable이라 진입 계산이 실패합니다(login 화면 안내와 다시 시도). 두 번째부터는 약관 동의가 필요한 새 계정입니다 |
  | `member-time-unknown` | 로그인한 회원. 오늘(getDaily)과 나의 사주(getChart) 응답에 time_unknown notice가 있어 오늘·나의 사주·사주 표에 시간 모름 배너가 보이고, 사주 표의 시주가 빈 칸입니다 |
  | `merge-token-invalid` | `member` 규칙을 따름. 계정 합치기 확정(mergeAccounts)이 422 `merge.token_invalid`라 토큰 만료 안내와 인증 단계로 돌아가는 흐름을 확인합니다 |
  | `merge-in-progress` | `member` 규칙을 따름. 계정 합치기 확정(mergeAccounts)이 처음 한 번 409 `idempotency.in_progress`이고 같은 키로 다시 보내면 합쳐집니다 |
  | `calendar-error` | 로그인한 회원. 달력(getCalendar)이 503이라 달력 격자를 불러오지 못합니다 |
  | `schedule-save-error` | 로그인한 회원. 일정 만들기(createSchedule)와 고치기(updateSchedule)가 503이라 저장하지 못합니다 |
  | `daily-error` | 로그인한 회원. 오늘(getDaily)이 503 service.unavailable이라 오늘 화면의 오류 상태와 다시 시도를 확인합니다 |
  | `diary-written` | 로그인한 회원. 오늘 일기를 이미 써서(getDiary 200) 오늘 화면의 가이드 질문 카드가 쓴 뒤(after) 상태이고 쓴 일기 보기로 이어집니다 |
  | `diary-day-full` | 로그인한 회원. 오늘 날짜에 살아 있는 일기가 이미 10편(listDiaries)이라 새 일기 입구가 막히고, 11번째를 만들면 422 diary.day_full입니다 |
  | `reaction-failed` | 로그인한 회원. 총운 문장에 반응을 남기는 요청(putReaction)이 503 service.unavailable이라 켠 반응이 되돌아가고 오류 toast가 뜹니다 |
  | `reaction-delete-failed` | 로그인한 회원. 총운 문장의 반응을 지우는 요청(deleteReaction)이 503 service.unavailable이라 끈 반응이 다시 켜지고 오류 toast가 뜹니다. 켜진 채로 시작하는 응답은 테스트가 대는 getDaily 대역으로 만듭니다 |
  | `evidence-unlocked` | 로그인한 회원. 근거 열람 권한이 있어(getEntitlements insight 활성) 오늘(getDaily)과 나의 사주(getChart)가 evidenceAccess unlocked로 오고 근거 시트가 처음부터 열려 있습니다. 나의 사주에는 용신 판정 근거와 원국 개인 해석(`personalReadings`)이 있습니다 |
  | `reward-unlock` | 로그인한 회원. 근거 시트에서 보상형 광고를 끝까지 보면 이용권(getEntitlements)이 세 번째 응답부터 insight 활성이 되고, 다시 받은 오늘(getDaily 두 번째 응답부터)과 나의 사주(getChart 두 번째 응답부터)가 unlocked입니다 |
  | `daily-pair-virtue` | 로그인한 회원. 오늘(2026-10-19, getDaily)이 행운 색이 둘인 날(`secondColor`)이면서 천덕일과 월덕일이 함께 드는 날(`dayVirtues` 둘, 천덕일 먼저)입니다. 근거는 잠겨 있습니다. 응답 전체가 엔진 값이고 문장은 writing ko 원고를 `tool/gen_daily_fixtures.py`가 렌더한 것입니다 |
  | `daily-pair-virtue-unlocked` | `daily-pair-virtue`와 같은 날의 근거가 열린 응답(`evidence-unlocked`를 이어받음). 덕일과 두 색 문장에 근거 전부(`evidence`)가 있습니다 |
  | `reward-timeout` | 로그인한 회원. 보상형 광고를 끝까지 봐도 이용권(getEntitlements)이 계속 비활성이라 확인 시간(30초)이 지나 잠금 해제 실패 toast를 봅니다 |
  | `reward-unavailable` | 로그인한 회원. 볼 수 있는 보상형 광고가 없어 근거 시트의 광고 버튼이 꺼지고 안내가 보입니다 |
  | `reward-dismissed` | 로그인한 회원. 보상형 광고를 끝까지 보지 않고 닫아 근거 시트가 잠긴 그대로입니다 |
  | `reward-failed` | 로그인한 회원. 보상형 광고를 표시하지 못해 오류 toast를 보고 근거 시트가 잠긴 그대로입니다 |
  | `ad-free-active` | 로그인한 회원. 광고 제거권이 활성이라(getMe `adFree`, 한국 시각 11월 12일 만료) 설정의 광고 제거 줄에 만료 날짜가 보입니다 |

  `new-user`와 `profile-required`의 내 정보(getMe)는 호출 순서대로 바뀌며 **두 번째부터 "프로필 있음"**입니다(미리보기·동의 직후 프로필 저장을 흉내 냄). 그래서 fake 모드 수동 확인에서 `new-user`로 미리보기 없이 로그인·동의하거나 `profile-required`에서 저장 없이 진입을 다시 계산해도 프로필이 생긴 것처럼 진행됩니다. 미리보기 없이 로그인한 새 계정은 `new-user-signin`으로 확인합니다.

  일기(`listDiaries`·`getDiary`·`putDiary`·`deleteDiary`)는 시나리오마다 새로 만드는 메모리 저장소가 답합니다(`lib/core/api/fake/fake_diary_store.dart`). 처음 내용은 시나리오의 `listDiaries`·`getDiary` 200 응답이고, 쓰면 목록과 그날 일기에 생기고 지우면 사라집니다. 새 일기의 태그·질문은 그날 `getDaily` fixture에서 가져오고, 오늘 뒤 날짜는 422 `diary.future_date`, 없는 일기는 404 `diary.not_found`입니다. 앱을 다시 띄우면 처음 내용으로 돌아갑니다. 회고 집계(`getDiaryStats`)도 이 저장소의 살아 있는 일기로 server 규칙(S146, 편수는 편 단위, 날의 성격과 태그는 날짜 단위)대로 셉니다(`lib/core/api/fake/fake_diary_stats.dart`). `fixtures/member/getDiaryStats.json`은 스키마 검증용이고, 시나리오에 오류 응답 파일이 있으면 그 오류가 먼저입니다.

  프로필 저장(`updateProfile`)은 시나리오 파일이 200이면 보낸 필드만 그 응답의 프로필에 덮어 답하고(merge-patch) 다음 저장은 그 결과에서 이어 갑니다. 그래서 설정에서 언어·알림을 바꾸면 앱에 그대로 보입니다. 200이 아닌 파일(오류 시나리오)은 파일이 답합니다. 프로필 읽기(`getProfile`)는 파일이 없으면 마지막으로 저장한 프로필, 그것도 없으면 `updateProfile` 200 파일의 프로필입니다.

  나의 사주(`getChart`)는 `tool/gen_chart_fixtures.py`가 member 프로필(양력 1990-05-15 14:30, 여성, Asia/Seoul)로 core 엔진을 시나리오의 오늘(2026-10-13)에 돌려 만듭니다. 문장(용신 판정 근거·개인 해석·`ilganHead`·`ilganBody`·`yongsinSummary`)은 writing 슬롯 형식의 대역 문장입니다. `member`는 locked라 판정 근거와 개인 해석이 없습니다. fixture는 입력과 상관없이 같으므로, 정보 수정에서 사주를 바꾼 뒤의 새 원국은 테스트가 응답 대역으로 만듭니다(`test/flows/me_journey_flow_test.dart`). 계정 삭제(`deleteMe`)는 member에서 202(삭제 예정 시각)이고, 진입 설정(`getAppConfig`)의 `legal`은 대역 주소(`example.com`)라 약관 줄이 외부 브라우저 대역으로 열립니다(D80).

  오늘(`getDaily`)은 손으로 쓴 응답(시나리오의 오늘을 용신의 날로 보이려고 고른 값)에 REST 1.11.0 값(`dayVirtues`, 낮과 밤 집중 시간의 `dayDate`·`dayPillar`·문장·근거, `nightFocusTime`, `previousNightFocusTime`)만 `tool/gen_daily_fixtures.py`가 엔진으로 채우고, `daily-pair-virtue`, `daily-pair-virtue-unlocked`는 그 도구가 응답 전체를 엔진 값과 writing ko 원고로 만듭니다. 달력(`getCalendar`)은 `tool/gen_calendar_fixtures.py`, 용어 사전(`member/getGlossary.json`)은 server 규칙대로 writing ko 원고와 `hanja.yaml`에서 만드는 `tool/gen_glossary_fixtures.py`입니다. 원고 읽기와 렌더는 `tool/fixture_content.py`가 함께 맡습니다. 엔진을 쓰는 도구는 core/에서 `uv run python ../app/tool/<도구> <출력 경로>`로 돌립니다(도구 머리 설명).

  원본은 `fixtures/scenarios.json`입니다. `extends`로 다른 시나리오의 fixture를 이어받습니다. `rewardedAd`(`earned`·`dismissed`·`unavailable`·`failed`, 생략하면 `earned`)는 보상형 광고 대역의 결과이고, 이어받지 않고 시나리오마다 정합니다.
* **개발 메뉴:** debug 빌드의 fake 모드에서 화면 왼쪽 위 상태 표시줄 칸을 길게 누르면 시나리오 목록이 열립니다. 고르면 앱이 그 시나리오로 처음부터 다시 시작합니다(로컬 DB도 비웁니다).

## 구조
`lib/`은 `app`(부트스트랩·라우터·개발 메뉴), `core`(api·storage·l10n·clock·platform·ia), `design`(토큰·테마·컴포넌트), `features/<영역>`(data·application·presentation)로 나뉩니다. `features/`는 영역별로 `onboarding`(welcome·force-update·onboard-*·birthplace·preview·notify-ask), `auth`(login·consent), `profile`(프로필 사본·시간대)가 있고 이후 계획이 영역을 더합니다. `testing/covers.dart`는 E2E·흐름 테스트가 덮는 IA 경로·상태·결정을 선언하는 `Covers`입니다. 별도 도메인 계층은 없고 repository가 생성 모델을 돌려줍니다. 자세한 구조와 이유는 spec [§2](docs/specs/2026-10-13-app-architecture-design.md)에 있습니다.

## 생성 코드
생성 코드는 commit하며 **손대지 않습니다.** 원본(계약·ARB)을 고친 뒤 아래 명령으로 다시 만듭니다. 모두 `app/`에서 실행합니다.

| 원본 | 명령 | 생성물 |
| --- | --- | --- |
| `../docs/ia/screens.json` | `dart run tool/gen_ia.dart` | `lib/core/ia/gen/` (화면·슬롯 id 상수) |
| `../docs/identity/design/tokens/` | `dart run tool/gen_tokens.dart` | `lib/design/tokens/gen/` |
| `lib/core/l10n/arb/*.arb` | `flutter gen-l10n` | `lib/core/l10n/gen/` |
| `../server/api/openapi.yaml` | `tool/gen_api.sh` (Docker) | `lib/core/api/gen/`, route 표. 끝에 `build_runner`를 돌립니다 |
| `config/auth.json` | `dart run tool/gen_native_config.dart` | `ios/Flutter/Auth.xcconfig` (카카오 키, Google reversed client id). CI는 `--check`. Android는 `build.gradle.kts`가 같은 파일을 바로 읽습니다 |
| drift·json 직렬화 | `dart run build_runner build --delete-conflicting-outputs` | `*.g.dart` |
| `lib/core/l10n/arb/*.arb`의 `appTitle`, `iosTrackingUsageDescription` | `dart run tool/gen_native_strings.dart` | iOS `ios/Runner/<en\|ko\|ja>.lproj/InfoPlist.strings`(홈 화면 앱 이름 `CFBundleDisplayName`, ATT 권한 창 문구)와 Info.plist 기본값, Android `res/values(-ko, -ja)/strings.xml`(`app_name`). 기본 언어는 앱 화면과 같은 en입니다(A101). CI는 다시 만들어 차이를 봅니다 |
| `../docs/identity/design/logo/icon-*.svg`(design V7) | `dart run tool/gen_app_icons.dart` | iOS `AppIcon.appiconset`, Android `mipmap-*/ic_launcher*.png`, `mipmap-anydpi-v26/ic_launcher.xml`. 아래 "앱 아이콘" |

* REST 클라이언트는 openapi-generator 7.26.0 `dart-dio`이며 이미지 버전은 `tool/gen_api.sh`에 고정되어 있습니다(결정 A16).
* 계약의 열린 enum(`info.description` "호환과 버전" 절)만 모르는 값을 `unknownDefaultOpenApi`로 읽습니다(`isKnown`으로 거름). `gen_api.sh`가 계약 사본에 표시를 달고(`tool/mark_open_enums.dart`) 생성기 기본 템플릿에 `tool/openapi-templates/open_enum.patch`를 적용해 만듭니다. 생성기 버전을 올려 patch가 맞지 않으면 새 기본 템플릿에서 같은 변경으로 patch를 다시 만듭니다. 대조는 `test/contract/open_enums_contract_test.dart`입니다(결정 A66).
  * **생성기를 올릴 때 patch 다시 만들기:** `gen_api.sh`의 이미지(버전·digest)를 바꾸면 `git apply` 단계에서 멈춥니다. 새 이미지로 `docker run --rm -v "$PWD/build/tpl:/work" <이미지> author template -g dart-dio --library dio -o /work`로 기본 템플릿을 꺼내 그 디렉터리를 git 저장소로 commit하고, 이전 patch의 변경(`{{! myungli: … }}` 표시가 붙은 줄)을 같은 자리에 옮긴 뒤 `git diff`로 `tool/openapi-templates/open_enum.patch`를 새로 씁니다. 머리말(첫 `--- a/` 줄 앞 글)의 생성기 버전도 고칩니다. 그 뒤 `tool/gen_api.sh`를 돌리고 열린 enum 대조 테스트로 확인합니다.
* Riverpod provider는 코드 생성 없이 직접 선언합니다(결정 A15).
* CI의 `checks` job이 위 명령을 모두 다시 돌린 뒤 `git status`가 깨끗하지 않으면 실패합니다. 원본을 고치고 생성물을 commit하지 않으면 CI가 잡습니다.

### 앱 아이콘 (A102)
원본은 design 로고(`docs/identity/design/logo/`, 결정 V7)이고, 크기별 PNG는 app이 만들어 commit합니다. 원본이 바뀌면 다시 만듭니다.

```sh
brew install resvg imagemagick   # 한 번만. resvg는 SVG 렌더링, magick은 알파 제거와 메타데이터 정리
dart run tool/gen_app_icons.dart
```

* 픽셀 60 이상은 큰 원형(`icon-large.svg`), 그보다 작으면 작은 원형(`icon-small.svg`)입니다. iOS는 `AppIcon.appiconset/Contents.json`의 자리마다 그리고 모두 알파 없이 씁니다(App Store 1024는 알파 채널이 있으면 거부됨). 모서리는 OS가 깎습니다.
* Android는 이전 기기용 `ic_launcher.png`(48dp)와 Android 8 이상 adaptive 아이콘(전경 `icon-android-foreground.svg`, 배경 `icon-android-background.svg`, 108dp)입니다. 테마 아이콘(monochrome)과 스플래시는 아직 없습니다.
* 같은 원본과 도구 버전이면 결과 파일이 같습니다(PNG 시각 정보를 넣지 않음). ImageMagick 내장 SVG 렌더러는 그라데이션과 상대 곡선을 틀리게 그려 쓰지 않습니다.

## ui 원고 가져오기
화면 문구 원고는 writing이 만든 ARB(`../docs/identity/writing/generated/arb/app_{ko,en,ja}.arb`, #128)입니다. 원고가 바뀌면 `app/`에서 다시 가져옵니다. 같은 원고로 다시 돌려도 결과가 같습니다.

```sh
dart run tool/import_writing_arb.dart
flutter gen-l10n
# 저장소 루트에서
uv run --project docs/identity/writing/tools mlw check-arb app/lib/core/l10n/arb/app_ko.arb app/lib/core/l10n/arb/app_en.arb app/lib/core/l10n/arb/app_ja.arb
```

* 원고에 있는 키는 값을 원고로 바꾸고, ko의 `@키` 설명·placeholder도 원고 것으로 바꿉니다(임시 표시가 사라짐). en·ja 번역이 없는 키는 ko 문구로 채웁니다.
* `@키` 메타데이터는 ko에만 둡니다(gen-l10n은 기준 언어 것만 읽음). 도구가 en·ja의 `@키`를 모두 지우므로 app 전용 키도 메타데이터는 ko에만 적습니다.
* app에만 있는 키(오류 `error*`, 슬롯 밖 문구, 원고가 없는 슬롯)는 그대로 두며 `임시` 표시가 남습니다. 이 키를 고칠 때는 ARB를 직접 고칩니다.
* `@@locale`만 app 파일 것을 두고, 원고의 `@@x-generated`는 가져오지 않습니다(app ARB는 전체가 생성물이 아니므로).
* 원고에서 키가 바뀌면(상태 이름 접미사 등) 화면 코드가 새 키를 쓰게 고치고, 쓰지 않게 된 키를 세 ARB에서 지웁니다. 도구는 키를 지우지 않습니다.

## fixture 추가와 검증
fake 모드의 대역 응답은 `fixtures/<시나리오>/` 아래 JSON입니다.

* 파일 이름: `<operationId>.json`, 경로 매개변수가 있는 operation은 값별로 `<operationId>__<값>.json`(값이 여럿이면 `-`로 잇습니다). 쿼리 매개변수는 지원하지 않으며, 경로 매개변수가 없는 operation에 `__`가 붙으면 검증이 실패합니다.
* 찾는 순서: 시나리오 lineage가 바깥입니다(자기 자신 → 부모 → 조상). 각 시나리오 안에서 매개변수 파일을 먼저, 없으면 기본 파일을 봅니다. 그래서 자식의 기본 파일이 부모의 매개변수 파일보다 먼저 쓰입니다.
* 내용: `{ "status": 200, "headers": {…}, "body": {…} }`. `status`는 필수이고 그 operation에 정의된 응답(없으면 `default`)의 스키마로 검증합니다.
* 같은 요청을 여러 번 불러 응답이 바뀌어야 하면(예: 권한 확인 폴링) `{ "sequence": [응답, 응답, …] }` 형식을 씁니다. `sequence`는 다른 키와 함께 쓸 수 없고 비어 있으면 안 됩니다. 호출 순서대로 응답합니다.
* 새 시나리오는 `fixtures/scenarios.json`에 등록합니다.

검증은 `app/`에서 합니다. 실패하면 파일과 JSON Pointer를 출력합니다.

```
uv run --with jsonschema --with pyyaml --with referencing --with rfc3339-validator sh -c '
  python -I tool/test_validate_fixtures.py &&
  python -I tool/validate_fixtures.py'
```

## 테스트
| 종류 | 위치 | 명령 |
| --- | --- | --- |
| 단위·위젯·계약 대조(IA·컴포넌트)·도구 | `test/` | `flutter test --exclude-tags golden` |
| 앱 흐름(위젯 수준, fake 모드) | `test/flows/` | 위와 같음 |
| golden | `test/goldens/` | `flutter test --tags golden` (Linux에서만) |
| 기기 E2E | `patrol_test/` | 아래 |
| 정적 분석 | | `flutter analyze` (`widgetbook/`에서도 한 번) |

### golden
기준 이미지는 글꼴 래스터화가 플랫폼마다 달라 **Linux에서만** 만들고 비교합니다. macOS에서 golden을 비교하거나 갱신하면 테스트가 실패합니다(`test/flutter_test_config.dart`). 그래서 일반 `flutter test`에는 `--exclude-tags golden`을 붙입니다.

* **갱신(로컬):** `tool/goldens_linux.sh`. Docker(linux/amd64)에서 기준 이미지를 만들어 `test/goldens/`에 되돌려 놓습니다. 반복 중에는 바꾼 golden 테스트 파일만 줍니다(`tool/goldens_linux.sh test/design/saju_golden_test.dart`). 이때는 다른 기준 이미지를 지우지 않으므로, golden을 지운 변경은 대상 없이 전체로 돌립니다.
* **갱신(CI):** Actions에서 `app` workflow를 수동 실행하고(`workflow_dispatch`) `update_goldens`를 켭니다. `update-goldens` job이 `goldens` artifact로 올리면 받아서 `test/goldens/`에 덮어 commit합니다.
* **Flutter 버전:** golden을 만드는 버전은 `tool/golden_flutter_version` 한 곳(현재 3.47.7)에서 정합니다. 로컬 Flutter와 무관하게 `goldens_linux.sh`와 CI의 `goldens`·`update-goldens` job이 이 값을 읽습니다. Flutter를 올릴 때는 이 값을 올리고 같은 PR에서 golden을 다시 만듭니다.

### 화면 스크린샷 (#336)
화면별·상태별 스크린샷을 golden과 같은 Linux 렌더(Docker)로 그려 `docs/artifacts/`에 등록합니다. 제품 지도가 `index.json`의 `screens`로 화면 카드 그림을 고릅니다.

```
tool/screens_linux.sh
```

* 사례(화면·상태·fake 시나리오)는 `test/screenshots/screens_test.dart`에 있습니다. 환경 변수 `MYUNGLI_SCREENSHOTS=1`일 때만 돌아 평소 테스트와 CI에서는 건너뜁니다.
* 결과는 `tool/register_screenshots.dart --origin render`로 등록합니다. 같은 화면·상태의 이전 렌더는 파일까지 바꾸고, 그림이 같으면 새로 등록하지 않습니다(id 접두어 `render.`). Patrol 캡처(`e2e.`)는 지금처럼 `superseded`로 남깁니다.
* 화면을 새로 만들거나 바꾼 계획 PR에서 사례를 더하고 다시 돌립니다(세션 마무리 체크리스트의 산출물 등록).

### Widgetbook
컴포넌트 카탈로그입니다. 테마(라이트·다크), 로케일(ko·en·ja), 글자 크기를 바꿔 볼 수 있습니다.

```
cd widgetbook
flutter pub get
flutter run -d chrome   # 또는 -d macos, 기기 id
```

### 기기 E2E (Patrol)
문서 기반 E2E입니다(결정 A13). 테스트는 IA 화면·슬롯 id(Key)로 자리를 찾고, 덮는 경로·상태·결정을 `covers(const Covers(...))`로 선언합니다. 선언은 문자열 리터럴만 씁니다. 흐름 테스트(`test/flows`)도 같은 선언을 씁니다.

```
dart pub global activate patrol_cli 4.8.0
tool/patrol_local.sh                              # patrol_test 전체
tool/patrol_local.sh patrol_test/diary_test.dart  # 흐름 하나
```

* 에뮬레이터가 필요합니다. 연결된 에뮬레이터가 하나면 그것을 쓰고, 여럿이면 `PATROL_DEVICE`, 하나도 없으면 `PATROL_AVD`(띄울 AVD 이름)를 줍니다. CI(`e2e-android`)는 API 34 에뮬레이터에서 `patrol test`를 직접 돌립니다.
* `tool/patrol_local.sh`는 `patrol test -d <기기> --dart-define-from-file=config/auth.json --dart-define=API_MODE=fake --test-server-port 47281 --app-server-port 47282`를 감싸 멈춤을 막습니다.
  * 기기를 늘 지정하고 입력을 닫습니다. 기기가 여러 대일 때 patrol이 고르라고 묻는 입력에서 멈추지 않게 하기 위해서입니다.
  * 실행 중 기기 상태를 10초마다 봅니다. 기기가 `PATROL_OFFLINE_GRACE`(기본 60초)보다 오래 빠지거나 `PATROL_RUN_TIMEOUT`(기본 1800초)을 넘기면 끝냅니다.
  * 테스트가 하나도 돌지 못한 기기 문제(설치 단계 `device offline` 등)는 기기가 돌아오면 `PATROL_RETRIES`(기본 1)번 다시 돌립니다. 테스트 실패는 다시 돌리지 않습니다.
  * 잠금으로 동시 실행을 막고, 실행마다 새 로그를 `build/patrol-local/`에 씁니다.
  * 종료 코드: 0 통과, 1 테스트 실패, 2 기기 문제, 3 환경 문제(잠금·기기 없음·CLI 없음), 4 시간 초과.
  * adb 서버는 다른 프로젝트와 함께 쓰므로 `adb kill-server`를 하지 않습니다.
* **테스트 뒤 Activity 닫기(A100, #700):** `MainActivityTest`의 `@After`가 테스트마다 앱 Activity를 `finishAndRemoveTask()`로 닫고 destroy될 때까지(최대 10초) 기다립니다. Patrol은 앱을 닫지 않는데, Activity가 살아 있는 채로 instrumentation이 끝나면 API 34 에뮬레이터는 task 제거를 약 1.4초 뒤로 미루고 그때 같은 이름의 앱 프로세스를 죽입니다. Orchestrator가 그 사이에 다음 테스트 프로세스를 띄우면 그 테스트가 "Test instrumentation process crashed"로 빠집니다.
* **실패 읽기:** Patrol 요약(`Total`)은 프로세스가 죽어 돌지 못한 테스트를 세지 않습니다. 요약이 모두 통과인데 `Gradle test execution failed`면 `androidTest-results/connected/debug/*/testlog/test-results.log` 끝(`Tests found`, `There was N failure`)을 봅니다. CI는 실패할 때 이 끝을 로그에 찍고, artifact `e2e-gradle-reports`에 기기 전체 logcat을 남깁니다. logcat에서는 `remove task`, `failed to attach`를 찾습니다. CI는 통과해도 `remove-task destroy timeout=<개수>`를 찍고, 0이 아니면 경고를 남깁니다(A100이 깨졌다는 신호).
* **커버리지 보고:** `dart run tool/ia_coverage.dart`가 선언을 `screens.json`·결정 로그와 대조해 `docs/artifacts/e2e-coverage.json`을 씁니다. `--check`는 `tool/coverage_baseline.json`보다 줄었을 때만 실패합니다(개수만 비교). 덮는 범위를 넓힌 PR은 `dart run tool/ia_coverage.dart --update-baseline`으로 baseline을 올려 같이 commit합니다. 대상 결정은 `tool/decision_targets.json`입니다.
* **스크린샷 등록:** `expectScreen`이 `<화면>__<상태|default>` 태그로 캡처합니다(네이티브 캡처는 Android만 동작).
  ```
  tool/collect_e2e_screenshots.sh <patrol 스크린샷 디렉터리> [build/e2e-screenshots]
  dart run tool/register_screenshots.dart build/e2e-screenshots [--date YYYY-MM-DD] [--decisions D50,D49]
  ```
  이미지를 `docs/artifacts/`에 복사하고 `index.json`에 등록합니다. 같은 화면·상태의 이전 항목은 `superseded`로 바뀝니다(`docs/workflow.md` §7).

#### staging 실행 (#781, 결정 A108)
같은 흐름을 fake 대신 staging server에 대고 돌립니다. 로그인 요청은 Mac의 relay가 staging 테스트 로그인으로 대신 부르고, 시나리오마다 새 테스트 계정을 만들어 끝나면 지웁니다.

```
tool/patrol_staging.sh                               # patrol_test 전체
tool/patrol_staging.sh patrol_test/diary_test.dart   # 흐름 하나
```

* **준비물:** `gcloud auth login`, staging 프로젝트의 `TEST_LOGIN_SECRET` 읽기 권한, `$MYUNGLI_LOCAL_DIR/app/staging/dart-defines.json`(K4, `docs/local-values.md`). `MYUNGLI_LOCAL_DIR`를 바꿨다면 공백 없는 경로만 쓸 수 있습니다(공백이 있으면 종료 코드 3). 프로젝트가 다르면 `MYUNGLI_STAGING_PROJECT`를 줍니다(기본 `myungli-diary-staging`).
* **대체한 것:** 로그인 SDK, 결제, 푸시는 대역이고 광고는 staging 모의 광고입니다(결정 A106). 비밀은 relay 메모리에만 있고 relay는 `127.0.0.1:47283`에서 받으며 기기에는 `adb reverse`로 닿습니다. 계정 연결과 합치기(`account_test`)는 server가 제공자 토큰을 검증하므로 staging에서는 건너뜁니다.
* **문의 흐름:** 실행마다 support@로 실제 메일이 한 통 갑니다. 내용 첫머리가 `[E2E]`라 메일함에서 가려 볼 수 있습니다.
* **정리 출력 읽기:** 끝에 `[patrol_staging] 테스트 계정 정리: {"deleted":N,"failed":[]}`가 나옵니다. `failed`가 비어 있으면 이 실행의 계정이 모두 지워진 것입니다. 비어 있지 않거나 "relay가 먼저 끝났습니다"가 나오면 relay 로그의 `정리 결과`에서 지우지 못한 label을 확인합니다. 중단(Ctrl-C)해도 wrapper의 `trap`이 같은 정리를 합니다.
* **relay 로그:** `build/patrol-local/relay-<시각>.log`. 요청 줄에는 METHOD, 경로, 상태만 남고 본문, 토큰, 비밀, label은 남기지 않습니다. 지우지 못한 label은 `정리 결과` 줄의 `failed` 목록에만 나오며, 그 label로 남은 계정을 확인해 손으로 지웁니다. 실패한 단계는 `POST /session → 503 (POST /test/v1/auth/login)`처럼 적힙니다.
* **종료 코드:** `patrol_local.sh`와 같습니다(0 통과, 1 테스트 실패, 2 기기 문제, 3 환경 문제, 4 시간 초과). gcloud 로그인 없음, dart-define 파일 없음, relay 준비 안 됨은 3입니다.

## CI (`.github/workflows/app.yml`)
| job | 언제 | 하는 일 |
| --- | --- | --- |
| `checks` | `ci-gate` 호출(PR, `main` push), 수동 | `own`: format, 생성 코드 차이, ARB 검사(`mlw check-arb`), fixture 검증, analyze, 커버리지 ratchet, Widgetbook analyze·테스트, 테스트(golden 제외), Android debug 빌드(NDK·CMake 캐시). `drift`·`gate`: 생성 코드 차이, ARB 검사, fixture 검증, 커버리지 ratchet, `contract` 태그 테스트만 |
| `goldens` | `ci-gate` 호출 중 `own`, 수동 | `golden_flutter_version`의 Flutter로 golden 비교 |
| `update-goldens` | 수동(`update_goldens`) | golden을 Linux에서 다시 만들어 artifact로 올림 |
| `e2e-android` | `main` push, 매일 03:00 KST, 수동 | Android 에뮬레이터에서 Patrol 실행, 스크린샷 artifact. PR에서는 돌지 않고 `ci-gate` 판정에도 넣지 않습니다 |

`workflow_call`을 지원합니다. 입력 `mode`(`own`·`drift`·`gate`, 기본 `own`)는 `ci-gate`가 넘기고 검사 범위를 정합니다(D81, `docs/workflow.md` §6.2). `main` push에서는 `ci-gate`가 `checks`·`goldens`를 한 번 돌리므로, 이 workflow의 `push` 트리거는 `e2e-android`만 돕니다. 호출되면 `e2e-android`는 돌지 않아 호출 측 판정에 들어가지 않습니다(입력 `run_e2e: true`로만 켬). 재사용 workflow 안의 `github.event_name`은 호출 측 이벤트라, 직접 실행 여부는 `github.workflow == 'app'`으로 가립니다.

### NDK·CMake 캐시
Gradle이 Android 디버그 빌드에서 NDK·CMake를 설치하는 시간을 줄이려고 `checks`·`e2e-android`가 두 디렉터리를 `actions/cache`로 남깁니다(#358). 빌드 도구만 담고 테스트 입력·결과에는 영향이 없습니다.
* **키:** `android-native-ndk-<flutter.ndkVersion>-cmake-<ANDROID_CMAKE_VERSION>`. NDK는 Flutter SDK에서 읽으므로 Flutter를 올리면 새 키로 바뀝니다. CMake는 `app.yml`의 고정 값(jni plugin이 쓰는 AGP 기본 3.22.1)입니다.
* **범위:** 만든 ref에서만 읽힙니다. PR에서 만든 캐시는 그 PR만 쓰고, `main` push의 `ci-gate`(own)가 만든 캐시를 모든 브랜치가 씁니다. 7일 동안 쓰이지 않거나 저장소 캐시 한도(10GB)를 넘으면 GitHub이 오래된 것부터 지웁니다.
* **키를 맞출 때:** 빌드 뒤 `NDK·CMake 캐시 대상 확인` 단계가 키 밖의 NDK·CMake 설치를 warning으로 남깁니다. 보이면 `ANDROID_CMAKE_VERSION`(두 job 모두)을 그 버전으로 바꿉니다. NDK 쪽이 보이면 `build.gradle.kts`의 `ndkVersion`이 `flutter.ndkVersion`과 달라진 것이므로 키를 읽는 방법을 맞춥니다.
* **비울 때:** 캐시가 있는데도 빌드가 NDK·CMake 문제(빠진 파일, `source.properties` 오류, 툴체인 실행 실패)로 실패하면 캐시가 깨진 것으로 보고 `gh cache delete <키>`로 지운 뒤 다시 돌립니다(그 키의 모든 ref 캐시가 지워집니다). 캐시 없이 한 번 확인하려면 지운 뒤 실행하면 됩니다. 테스트 실패는 이 캐시와 관계없으므로 비우지 않습니다.

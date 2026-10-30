# 로컬 값 보관 규칙과 대장

저장소에 넣지 않는 값(비밀, 빌드 설정 파일, 개발용 키)을 어디에 두고, 어떻게 찾고, 잃으면 어떻게 되찾는지 정한 규칙입니다(D98). 모든 단위와 지휘가 따릅니다. 값 자체는 이 문서에 적지 않습니다.

## 1. 등급
| 등급 | 뜻 | 예 | 원본 | 기기 밖 백업 |
| --- | --- | --- | --- | --- |
| L1 | 잃으면 다시 얻을 수 없는 비밀 | Android upload keystore와 비밀번호, Apple `.p8` | 보관 폴더 | **필수.** 사용자가 고른 비밀번호 관리자 등 |
| L2 | 다시 만들 수 있는 비밀 | App Check debug token, 로컬 JWT 키, 로컬 `env.sh`, API 키 | 보관 폴더 | 선택 |
| L3 | 공개지만 저장소에 넣지 않는 파일과 값 | Firebase 네이티브 설정 파일, D74로 공개 저장소에서 빼는 값 | 보관 폴더 | 선택 |
| L4 | 버려도 되는 작업 산출물 | 스크린샷, 로그, 로컬 바이너리, 빌드용 사본 | 단위 `.local/`(gitignore) | 없음 |

* 저장소 폴더(본 checkout과 단위 worktree)에는 **L4만** 둡니다. `git worktree remove --force`, `git clean -fdX`, 다시 clone만으로 gitignore된 파일이 사라지기 때문입니다.
* 클라우드에만 있는 비밀(GCP Secret Manager, GitHub Secret, Firebase 콘솔에 올린 키)은 그곳이 원본입니다. 로컬에 내려받아 두지 않습니다.

## 2. 보관 폴더
* 위치: `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}`. 이 문서에서는 `$MYUNGLI_LOCAL_DIR`로 씁니다.
* 구조: `<단위>/<환경>/<파일>`
  * 단위: `core`, `server`, `app`, `writing`, `design`, `root`(어느 단위도 실행 중에 쓰지 않는 값, 지휘가 관리)
  * 환경: `local`, `staging`, `prod`, `shared`(환경과 상관없는 것)
* 권한: 폴더 700, 파일 600
* 파일 이름은 소문자와 하이픈으로, 무엇인지 드러나게 짓습니다(예 `upload-keystore.jks`).

## 3. 찾는 방법
* 스크립트와 빌드는 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/<단위>/<환경>/<파일>`을 읽습니다. 그래서 본 checkout과 모든 worktree가 같은 원본을 봅니다. 저장소 안 경로나 절대 경로를 코드에 박지 않습니다.
* symlink는 쓰지 않습니다(worktree마다 따로 걸어야 합니다).
* 예외: 외부 도구가 저장소 밖 기본 경로를 쓰는 값(예: `~/.android/debug.keystore`)은 그 경로를 그대로 쓰고, 대장에 그 경로를 적습니다.
* 빌드 도구가 정해진 위치를 요구하면(예: `android/app/google-services.json`) 스크립트가 원본을 그 위치로 복사합니다. 그 사본은 L4이고 gitignore합니다.
* 파일이 없으면 스크립트는 찾은 경로와 이 문서(§6)를 알려 주며 실패합니다. 값을 대신 만들거나 비워 둔 채 계속하지 않습니다.

## 4. 전달 규칙
* **L1, L2:** 저장소, Issue, PR, commit, 채팅, 로그 어디에도 값을 적지 않습니다. 사용자가 제자리(보관 폴더, Secret Manager, GitHub Secret, 외부 콘솔)에 직접 넣고 "넣음"만 남깁니다.
* **세션은 비밀 파일을 경로로만 다룹니다.** 내용을 출력하지 않습니다. 예를 들어 `--dart-define-from-file=<경로>`나 `gh secret set <이름> < <경로>`는 되지만, `cat`, `echo`, 로그 출력은 안 됩니다. 있는지 확인할 때는 `test -f`나 `ls -l`을 씁니다.
* **L3 공개 식별자**(ID, client ID, 인증서 지문, 주소)는 지금처럼 Issue와 문서에 적어도 됩니다. **D74로 빼는 값**(가격, 수익 수치 등)은 공개 저장소의 Issue와 문서에 적지 않습니다.
* 외부 준비물(`docs/external-prep.md`)에서 받는 값도 이 등급을 따릅니다. 대장의 "넘길 값" 칸은 아래 §5의 id를 가리킵니다.

## 5. 대장
값 하나가 한 행입니다. 새 값이 생기면 **그 값을 쓰는 단위**가 이름(보관 경로, GitHub Secret, Secret Manager 이름)을 정하고, 그 PR에서 자기 행을 더하거나 고칩니다. 지휘는 외부 준비물 대장과 맞는지 봅니다. 행은 지우지 않고, 더 쓰지 않으면 상태 칸에 `안 씀`을 적습니다.

| id | 값 | 등급 | 보관 경로 | CI, 클라우드 짝 | 고치는 단위 | 잃었을 때 | 관련 | 상태 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| K1 | Android upload keystore와 비밀번호 | L1 | `app/shared/upload-keystore.jks`, `app/shared/key.properties` | GitHub Secret(CI 서명을 붙일 때 app이 정함) | app | Play Console에 upload key 재설정을 요청하고 새 keystore를 만듭니다(Play 앱 서명 키는 Google이 보관하므로 앱 서명 지문은 그대로) | E3, E8 | 만들기 전(Gradle은 이 경로를 읽음, app A94) |
| K2 | Apple Sign in with Apple 키(`.p8`, Key ID `34D2V94KFV`) | L1 | `server/shared/apple-signin.p8` | Secret Manager `APPLE_PRIVATE_KEY`(staging, prod) | server | 다시 내려받을 수 없습니다. Apple Developer에서 새 키를 만들고, 두 Secret Manager 값과 `APPLE_KEY_ID`를 바꿉니다 | E7 | 사용 중 |
| K3 | Apple APNs, DeviceCheck 키(`.p8`, Key ID `AP9H8R45ZZ`) | L1 | `root/shared/apns-devicecheck.p8` | Firebase 콘솔(두 프로젝트의 App Check DeviceCheck, 클라우드 메시징 개발과 프로덕션 칸) | 지휘 | 다시 내려받을 수 없습니다. 새 키를 만들고 Firebase의 여섯 곳을 모두 바꿉니다 | E5 | 사용 중 |
| K4 | App Check debug token(staging) | L2 | `app/staging/dart-defines.json` | GitHub Secret(E2E를 CI에서 돌릴 때 app이 정함), Firebase 콘솔 staging 디버그 토큰 | app | Firebase 콘솔에서 새로 만들고 옛 토큰을 지웁니다 | E5, #659 | 만듦(staging 두 앱에 등록, 앱 연결은 App Check adapter) |
| K5 | Firebase 네이티브 설정 파일(`google-services.json`, `GoogleService-Info.plist`) | L3 | `app/staging/`, `app/prod/` 아래 같은 이름 | - | app | `flutterfire configure`나 Firebase 콘솔에서 다시 받습니다 | E5 | 보관만(빌드는 Dart 설정 `firebase_options_*.dart`로 초기화, A93) |
| K6 | app의 로컬 server 실행 값(`env.sh`, JWT 키, Apple 대역 키) | L2 | `app/local/` | - | app | 로컬에서 새로 만듭니다 | - | 사용 중 |
| K7 | TypeSafe jev API 키 | L2 | `writing/shared/typesafe.key` | - | writing | TypeSafe에서 다시 발급합니다 | - | 사용 중 |
| K8 | server 배포 비밀(`JWT_SIGNING_KEY`, `TOKEN_ENCRYPTION_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_PRIVATE_KEY`, `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`, staging `TEST_LOGIN_SECRET`, 키 교체 중에만 `JWT_PREVIOUS_KEY`, `TOKEN_PREVIOUS_KEY`) | 클라우드 원본 | 로컬에 두지 않음 | Secret Manager(staging, prod 각각, Terraform이 틀을 만듦) | server | 키 교체는 `server/deploy/terraform/README.md`의 Secret 절을 따릅니다(이전 키 id를 tfvars에 넣어 `*_PREVIOUS_KEY`를 둠). `TOKEN_ENCRYPTION_KEY`를 잃으면 저장된 token을 풀 수 없으니 교체 전 버전을 지우지 않습니다 | E17 | 사용 중 |
| K9 | App Store In-App Purchase 키(`.p8`) | L1 | `root/shared/appstore-iap.p8` | RevenueCat 대시보드 | 지휘 | 다시 내려받을 수 없습니다. 새 키를 만들어 RevenueCat에 다시 올리고 옛 키는 폐기합니다 | E12, #632 | 만들기 전 |
| K10 | Play 서비스 계정 키(JSON, RevenueCat 연결용) | 클라우드 원본 | 로컬에 두지 않음(올린 뒤 내려받은 파일을 지움) | RevenueCat 대시보드 | 지휘 | GCP에서 새 키를 만들어 다시 올리고 옛 키를 지웁니다 | E12, #632 | 만들기 전 |
| K11 | Android debug keystore | L2 | `~/.android/debug.keystore`(도구 기본 경로, §3 예외) | - | app | 새로 생기지만 지문이 바뀌어, 카카오 키 해시, Google OAuth client, server `assetlinks.json`의 debug 지문을 다시 등록해야 합니다. 백업을 권장합니다 | E8, #311 | 사용 중 |
| K12 | Terraform bootstrap state(staging, prod) | 클라우드 원본 | 로컬에 두지 않음 | 각 프로젝트의 state bucket `<프로젝트>-tfstate`의 `bootstrap/default.tfstate`(버전 관리, backend `gcs`) | server | bucket의 이전 버전으로 되살립니다. bucket까지 잃으면 bootstrap이 만든 자원을 import로 되살려야 합니다(`server/deploy/terraform/README.md`) | E17, #636, #662 | 사용 중 |

## 6. 새 기기로 옮기기, 값을 잃었을 때
* **새 기기:** 옛 기기의 보관 폴더를 통째로 옮기거나(암호화된 매체로), L1은 기기 밖 백업에서 되살립니다. 권한을 700/600으로 맞춘 뒤, §5의 행마다 보관 경로에 파일이 있는지 `test -f`로 확인합니다. L2, L3 중 없는 것은 "잃었을 때" 칸대로 다시 만듭니다.
* **값을 잃었을 때:** 대장의 "잃었을 때" 칸을 따릅니다. 바뀐 값이 공개 식별자(Key ID 등)이면 그 값을 쓰는 단위에 Issue로 알립니다.
* **새어 나갔을 때(L1, L2):** 잃었을 때와 같이 새로 만들고, 옛 값은 발급처에서 폐기합니다. 지휘에게 `to:root` Issue로 알립니다(값은 적지 않습니다).

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

```
flutter run --dart-define=API_MODE=fake
flutter run --dart-define=API_MODE=fake --dart-define=SCENARIO=member
```

* **시나리오:** fake 모드의 시작 상태입니다. `SCENARIO`를 생략하면 `new-user`입니다.

  | id | 상태 |
  | --- | --- |
  | `new-user` | 처음 설치. 토큰 없음, 앱 설정만 받을 수 있음 |
  | `member` | 로그인한 회원. 약관 동의, 프로필 있음 |
  | `consent-required` | 로그인했지만 약관 동의 필요 |
  | `profile-required` | 약관 동의했지만 프로필 없음 |
  | `force-update` | 최소 앱 버전이 99.0.0이라 업데이트 필요 |
  | `offline` | 네트워크에 연결할 수 없음 |

  원본은 `fixtures/scenarios.json`입니다. `extends`로 다른 시나리오의 fixture를 이어받습니다.
* **개발 메뉴:** debug 빌드의 fake 모드에서 화면 왼쪽 위 상태 표시줄 칸을 길게 누르면 시나리오 목록이 열립니다. 고르면 앱이 그 시나리오로 처음부터 다시 시작합니다(로컬 DB도 비웁니다).

## 구조
`lib/`은 `app`(부트스트랩·라우터·개발 메뉴), `core`(api·storage·l10n·clock·platform·ia), `design`(토큰·테마·컴포넌트), `features/<영역>`(data·application·presentation)로 나뉩니다. 별도 도메인 계층은 없고 repository가 생성 모델을 돌려줍니다. 자세한 구조와 이유는 spec [§2](docs/specs/2026-10-13-app-architecture-design.md)에 있습니다.

## 생성 코드
생성 코드는 commit하며 **손대지 않습니다.** 원본(계약·ARB)을 고친 뒤 아래 명령으로 다시 만듭니다. 모두 `app/`에서 실행합니다.

| 원본 | 명령 | 생성물 |
| --- | --- | --- |
| `../docs/ia/screens.json` | `dart run tool/gen_ia.dart` | `lib/core/ia/gen/` (화면·슬롯 id 상수) |
| `../docs/identity/design/tokens/` | `dart run tool/gen_tokens.dart` | `lib/design/tokens/gen/` |
| `lib/core/l10n/arb/*.arb` | `flutter gen-l10n` | `lib/core/l10n/gen/` |
| `../server/api/openapi.yaml` | `tool/gen_api.sh` (Docker) | `lib/core/api/gen/`, route 표. 끝에 `build_runner`를 돌립니다 |
| drift·json 직렬화 | `dart run build_runner build --delete-conflicting-outputs` | `*.g.dart` |

* REST 클라이언트는 openapi-generator 7.26.0 `dart-dio`이며 이미지 버전은 `tool/gen_api.sh`에 고정되어 있습니다(결정 A16).
* Riverpod provider는 코드 생성 없이 직접 선언합니다(결정 A15).
* CI의 `checks` job이 위 명령을 모두 다시 돌린 뒤 `git status`가 깨끗하지 않으면 실패합니다. 원본을 고치고 생성물을 commit하지 않으면 CI가 잡습니다.

## fixture 추가와 검증
fake 모드의 대역 응답은 `fixtures/<시나리오>/` 아래 JSON입니다.

* 파일 이름: `<operationId>.json`, 경로·쿼리 매개변수별로는 `<operationId>__<값>.json`(값이 여럿이면 `-`로 잇습니다). 매개변수 파일을 먼저 찾고, 없으면 기본 파일을, 그래도 없으면 `extends`의 부모 시나리오를 차례로 봅니다.
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

* **갱신(로컬):** `tool/goldens_linux.sh`. Docker(linux/amd64)에서 기준 이미지를 만들어 `test/goldens/`에 되돌려 놓습니다.
* **갱신(CI):** Actions에서 `app` workflow를 수동 실행하고(`workflow_dispatch`) `update_goldens`를 켭니다. `update-goldens` job이 `goldens` artifact로 올리면 받아서 `test/goldens/`에 덮어 commit합니다.
* **Flutter 버전:** golden을 만드는 버전은 `tool/golden_flutter_version` 한 곳(현재 3.47.7)에서 정합니다. 로컬 Flutter와 무관하게 `goldens_linux.sh`와 CI의 `goldens`·`update-goldens` job이 이 값을 읽습니다. Flutter를 올릴 때는 이 값을 올리고 같은 PR에서 golden을 다시 만듭니다.

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
patrol test -t patrol_test --dart-define=API_MODE=fake
```

* 에뮬레이터나 기기가 필요합니다. CI(`e2e-android`)는 API 34 에뮬레이터에서 같은 명령을 돌립니다.
* **커버리지 보고:** `dart run tool/ia_coverage.dart`가 선언을 `screens.json`·결정 로그와 대조해 `docs/artifacts/e2e-coverage.json`을 씁니다. `--check`는 `tool/coverage_baseline.json`보다 줄었을 때만 실패합니다(개수만 비교). 덮는 범위를 넓힌 PR은 `dart run tool/ia_coverage.dart --update-baseline`으로 baseline을 올려 같이 commit합니다. 대상 결정은 `tool/decision_targets.json`입니다.
* **스크린샷 등록:** `expectScreen`이 `<화면>__<상태|default>` 태그로 캡처합니다(네이티브 캡처는 Android만 동작).
  ```
  tool/collect_e2e_screenshots.sh <patrol 스크린샷 디렉터리> [build/e2e-screenshots]
  dart run tool/register_screenshots.dart build/e2e-screenshots [--date YYYY-MM-DD] [--decisions D50,D49]
  ```
  이미지를 `docs/artifacts/`에 복사하고 `index.json`에 등록합니다. 같은 화면·상태의 이전 항목은 `superseded`로 바뀝니다(`docs/workflow.md` §7).

## CI (`.github/workflows/app.yml`)
| job | 언제 | 하는 일 |
| --- | --- | --- |
| `checks` | PR, `main` push | format, 생성 코드 차이, ARB 검사(`mlw check-arb`), fixture 검증, analyze, 커버리지 ratchet, Widgetbook analyze, 테스트(golden 제외), Android debug 빌드 |
| `goldens` | PR, `main` push | `golden_flutter_version`의 Flutter로 golden 비교 |
| `update-goldens` | 수동(`update_goldens`) | golden을 Linux에서 다시 만들어 artifact로 올림 |
| `e2e-android` | `main` push, 매일 03:00 KST, 수동 | Android 에뮬레이터에서 Patrol 실행, 스크린샷 artifact. PR에서는 돌지 않고 `ci-gate` 판정에도 넣지 않습니다 |

`workflow_call`을 지원합니다. `ci-gate` 연결은 Issue #85에서 진행합니다.

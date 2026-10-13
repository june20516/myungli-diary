# app — 모바일 앱 (Flutter)

이 디렉터리에서 시작한 세션은 **app 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 플랫폼: iOS / Android (Flutter, 01 §1.1)
* **온보딩:**
  * 생년월일시 입력, 양력·음력(윤달 포함), 시간 모름, 성별 (D18-①②③)
  * 호칭(앱이 사용자를 부를 말) 필수 입력 (D36)
  * 태어난 시간 아래 시진 확인 줄: 기기 지역이 한국일 때만, server의 비로그인 시진 확인 요청 값으로 (D58)
  * 음력 생일은 KASI 한국 음력 기준입니다. 생년월일 입력 범위는 양력 1900-01-31 ~ 2099-12-31입니다 (D41)
  * 출생지는 기본적으로 받지 않고 한국 출생으로 가정해 표시합니다. 언어나 기기의 위치·로케일이 한국이 아닐 때는 도시 단위 출생지 입력을 안내합니다 (D29)
  * 소셜 로그인: 카카오·Apple, iOS·Android 모두. Android의 Apple 로그인은 웹 흐름 (D55)
* **데일리 화면:**
  * 총운 문장, 카드 4종(행운 컬러·방향·숫자·집중 시간), 대표 해시태그 (D18-④⑤, D19~D21·D25)
  * 용신의 날은 "좋은 날"로 강조합니다 (D20)
  * 총운 문장에 대한 반응(좋아요)을 수집합니다 (D40·D57)
  * 깊이 단계(D37) `surface` → `explain` → `evidence`는 카드 → 바텀시트 Half → Full로 펼칩니다 (06 §1)
* **나의 사주:**
  * `surface`: 일간 소개, 용신·행운 색
  * `evidence`: 사주팔자 표, 십성·지장간·12운성·신살, 오행 분포, 용신 근거, 대운·세운 표 (D16·D18-⑥⑦)
* **탭 4개:** 오늘·달력·일기·나 (D48). 로그인은 첫 풀이 미리보기 뒤에 받습니다 (D50)
* **캘린더:** 월간 길흉(날짜 칸 채우기, design 결정 V10), 음력 날짜, 절기 (04 §4.4, D18-⑧). 기본 일정(제목·날짜·종일 또는 시간·메모, D47③). 다른 날 전체 풀이는 없고 그날 성격 한 줄만 (D47⑥)
* **일기:** 텍스트 작성, 작성 전 가이드 질문, 저장 후 해시태그 칩 (04 §4.3, D22, 06 §4). 하루 1편, 지난 날 쓰기 가능 (D49). 태그를 누르면 같은 태그의 일기 목록 (D47①). 오프라인은 로컬 초안만 (D47②)
* **공유:** 오늘 카드 이미지 공유, 로그인 필요 (D47④). 일기는 공유하지 않습니다
* **수익 (D53·D54):** 탭 루트 4곳 하단 적응형 배너 광고(AdMob 기본안), 광고 동의(iOS ATT, 필요한 지역 UMP)는 이 기기에서 처음 광고를 보이기 전에, 1개월 광고 제거권 인앱결제(자동 갱신 없음, 잠정 ₩2,500, RevenueCat 기본안)와 구매 복원. 근거 시트의 잠금 안내와 보상형 광고(D60): 사용자가 고를 때만, 매번 보상 고지 후, 광고가 준비됐을 때만 버튼을 켬. SSV `userId`로 계정을 넘기고 server 권한을 받아 엶
* **알림 수신:** 아침 운세 (D18-⑨)
* **안내 문구:** 엔진 notice를 안내 문구로 보여줍니다. 예: 자시 출생 계산 기준(D6), 시간 모름, 절입 전후 출생. 계산 기준 안내에 "동경 127.5° 기준 -30분 보정, 진태양시 미적용"을 넣습니다 (D42, 우선순위 낮음)
* **다국어:** 한국어·영어·일본어. UI 문자열은 ARB로 관리하고, 콘텐츠 문장은 서버가 렌더해 줍니다. app은 문장을 고르거나 조사를 붙이지 않고, 받은 그날 응답을 캐시해 오프라인에 보입니다 (D27·D28·D59). ARB 메시지 이름은 lowerCamelCase Dart 식별자이며, writing `slots/ui/`와 검사기 `mlw check-arb`가 이 규약을 전제합니다. A1에서 어긋나면 요청함으로 알립니다
* **화면 구성:** 지휘 세션의 MVP 화면 목록(IA, D39)을 따릅니다.
* **디자인:** 기준은 [`docs/identity/README.md`](../docs/identity/README.md)(브랜드 기반)와 [`docs/identity/design/visual-identity.md`](../docs/identity/design/visual-identity.md)(시각 정체성)입니다. **다크 모드는 MVP에 포함**됩니다(design 결정 V4). 앱 아이콘 원본은 `docs/identity/design/logo/`이고, 크기별 PNG 내보내기는 app이 합니다. 디자인 토큰과 컴포넌트 명세는 design 작업 단위가 제공합니다(V1·V2). UI 구현은 V2 이후에 시작하고, 설계는 병행할 수 있습니다.
* **MVP 범위 밖:** 인스타그램 스토리·카카오 템플릿 공유, 궁합, 일기 감성 코멘트(LLM), 구독 결제는 Phase 2 이후입니다 (05, D22·D23·D53)

## 고칠 수 있는 곳
`app/`, `.github/workflows/app.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:app`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| REST API `server/api/openapi.yaml` 1.0.0-draft.2 (freeze는 S3) | **사용** | server |
| `source_ref`·enum 값 (엔진 spec §9·§11, server가 그대로 전달) | **사용** (`evidence` 단계 표시) | core → server |
| 디자인 토큰 1.1.0 (`docs/identity/design/tokens/`, Dart 코드 생성은 app) | **사용** | design |
| 컴포넌트 명세 2.2.0 (`docs/identity/design/components/`) | **사용** | design |
| MVP 화면 목록 (IA) `docs/ia/screens.json` v1 (화면·상태·경로·슬롯·컴포넌트) | **사용** | 지휘 |

## 현재 상태 (2026-10-14, app 세션 갱신)
* **기반 계획(task 1~23) 완료**입니다. task 23에서 main을 병합하고 REST draft.2·인증 규칙·컴포넌트 2.2.0을 기반 코드가 닿는 범위만 반영했습니다. 브랜치 `app/foundation`이고 PR 예정입니다. 실행·생성 코드·테스트·CI는 [`README.md`](README.md)에 있습니다.
  * spec: [`docs/specs/2026-10-13-app-architecture-design.md`](docs/specs/2026-10-13-app-architecture-design.md) (승인), 계획: [`docs/plans/2026-10-13-foundation.md`](docs/plans/2026-10-13-foundation.md)
  * 결정: [`docs/decisions.md`](docs/decisions.md) A1~A16. Riverpod(코드 생성 없음), 생성 클라이언트와 fixture 대역, go_router, drift 영구 캐시, 사주 변경 확인 창, golden(Linux)과 Widgetbook, SDK 대역 adapter, 문서 기반 E2E(Patrol), 앱 식별자 `app.myungli.diary`입니다.
  * **REST 생성기(A16):** openapi-generator 7.26.0 `dart-dio`(Docker 이미지 고정)입니다. `swagger_parser`는 path 수준 `parameters` 생성 실패와 merge-patch Content-Type 누락으로 탈락했습니다.
  * **글꼴 측정(Task 5):** debug apk 170,321,244 B(약 163 MiB, AOT·압축 전), `assets/fonts` 31M(Gowun Dodum 7.2M, Zen Maru Gothic 3.8M, Pretendard 4종 6.3M, Pretendard JP 4종 15M). subset 여부는 release 빌드 크기로 다시 판단합니다(I4).
  * **만들어 둔 것:** 앱 셸과 fake 모드(시나리오 6개, 개발 메뉴), 라우터·진입 갈래, drift, 토큰·테마·글꼴, 오류 문구 표, 플랫폼 인터페이스와 대역, 공통 컴포넌트(frame·feedback·sentence)와 Widgetbook, golden 기반, IA id 상수 생성, E2E 뼈대(Patrol, 커버리지 도구, 스크린샷 등록, `e2e-android` job)입니다.
  * **E2E 커버리지(도구로 확인, 2026-10-14):** 경로 3/76, 상태 1/54, 결정 1/6. CI가 이 값보다 줄면 막습니다(`tool/coverage_baseline.json`). 화면을 구현하는 계획마다 올립니다.
* 보낸 요청: #84(IA 사주 변경 확인 창, 닫힘·반영됨: 슬롯 119), #86(Crashlytics, 닫힘, **D64**: 크래시 기록에 일기 본문·출생 정보·호칭 금지), #88(오류 code 목록, 닫힘), #89(Apple App Link, 닫힘. 실제 adapter는 계획 7에서 server 결과를 따름). **열려 있음:** #85(ci-gate에 app CI 연결), #87(제품 지도의 E2E 결과 표시와 통합 E2E 재사용), #90(ARB 키를 IA 슬롯 id의 lowerCamelCase로, writing).
* UI 문구 원고는 writing이 작업 중입니다(#15·#27·#42·#52). 그전까지는 IA 슬롯 id의 lowerCamelCase 키와 임시 문구를 씁니다(결정 A7).
* **아직 남은 외부 준비물(계획 7·출시 전):** 카카오·Apple·Firebase(FCM, Crashlytics)·AdMob·RevenueCat 계정과 키, Android App Link 도메인 검증. 사용자 몫입니다(`docs/roadmap.md` 외부 준비물). Android SDK 라이선스 동의는 로컬에서 Android 빌드가 막히면 확인합니다.
* MVP 범위는 수익화 사이클 M0에서 다시 확정됐습니다(D53·D54).
* **REST API 초안**: `server/api/openapi.yaml`(OpenAPI 3.1, 1.0.0-draft.2, operation 38개). freeze(S3) 전에는 하위 호환이 깨지는 변경이 있을 수 있고, 그때 server가 `kind:notice`로 알립니다. 규칙은 계약의 `info.description`에 모두 있습니다(Issue #63).
  * 오류는 RFC 9457 problem+json이고 `code`로 분기합니다. 사용자 문구는 app이 `code`로 만듭니다(D59⑤). 400은 형식·범위 위반(`request.invalid`), 422는 의미 검사(`request.inconsistent`, `date.invalid`, 엔진 판정)입니다.
  * null을 쓰지 않습니다. "모름"·"건너뜀"·"묻지 않음"은 상태 필드로 옵니다. PATCH에서 필드가 없으면 "바꾸지 않음"입니다.
  * 근거 열람 권한은 응답의 `evidenceAccess`(`unlocked`·`locked`)로 옵니다(D60).
  * 콘텐츠 문장은 조각 배열 `segments`로 옵니다. 용어 조각에는 `term`이 붙습니다. 위치 숫자는 쓰지 않습니다(server 결정 S9). `term` 조각의 표시는 design이 정합니다.
  * 시각은 기본 UTC입니다. 화면 표시용 시각(집중 시간, 절기 시각)만 프로필 시간대 offset으로 옵니다.
  * **오류 code 목록**은 `Problem.code`의 `x-problem-codes`입니다(#88). 사용자에게 보일 수 있는 code는 모두 `problemMessages`(`lib/core/l10n/error_messages.dart`)에 임시 문구가 있고, ARB 키는 `error` + code의 lowerCamelCase입니다(`auth.exchange_invalid` → `errorAuthExchangeInvalid`). `reward.*`는 AdMob SSV 웹훅 전용이라 뺍니다. 계약 대조는 `test/contract/problem_codes_contract_test.dart`입니다.
  * **인증 규칙(#100·#114, draft.2):** nonce 원문(16~256자)은 server에, SHA-256 소문자 hex는 제공자에 보냅니다(`lib/core/platform/nonce.dart`). Apple은 iOS native(`AppleNativeAuth` → `loginApple`)와 Android 웹(`AppleWebAuth`, authorize URL·App Link `/auth/apple` 복귀의 `state` 검증 → `completeAppleWebLogin`)으로 나뉩니다(`clientType` 제거). 삭제 대기 계정(`status: pending_deletion`)은 진입 계산이 `signOut`하고 로그아웃 갈래로 보냅니다. 403 `consent.required`는 `AuthEvent.consentRequired`로 진입을 다시 계산합니다. 503 `auth.provider_unavailable`은 로그아웃하지 않습니다.
* **컴포넌트 명세 2.2.0**: 2.0.0에 근거 깊이 잠금(잠김 4상태, `lock.veil`, `sentence-block` `locked`), 모양 규칙(동작은 둥근 사각, 표시·고르기는 알약), 화면 좌우 여백 `space.20`, 글자 수 상한이 들어갔습니다(PR #66, Issue #65).
  * 2.1.0(#82, 결정 V28): `term` 조각은 IA에 `term-token`이 있는 화면(today·day-sheet·tag-diary·my-saju·saju-chart)에서만 칩입니다. `SentenceBlock`이 slotId 첫 마디 화면으로 정하고(`termStyle`로 직접 정할 수도 있음), preview(`diary-row`)와 공유 이미지는 일반 글자입니다(`RenderedTextView.termStyle`, `lib/core/ia/ia_lookup.dart`).
  * 2.2.0(#81): 잠긴 문장 라벨은 "구역 이름(`saju-chart.yongsin.title`), 잠김"입니다(`SentenceBlock.lockedNameSlotId`).
* **IA v1**: 화면 37·슬롯 124(그중 `system-apple-return.page.*` 4개는 server 안내 페이지 문구라 app이 그리지 않으므로 app이 쓰는 슬롯은 120). 시스템 화면 `system-push`(아침 알림 문장, 호칭 없음, D62)와 `system-apple-return`(Android Apple 로그인 복귀를 앱이 열지 못할 때의 server 안내 페이지, D66)이 있습니다.
* 광고 제거권을 만료 전에 다시 사면 남은 기간에 이어 붙습니다(D61). 계산은 server가 합니다.
* 도시 목록은 GeoNames `cities15000`(CC BY 4.0)으로 server가 만듭니다. **앱 오픈소스 고지(`legal`)에 출처를 표기합니다**(Issue #48 항목 5).
* 받은 notice: Issue #19(토큰 1.0.0), #44(컴포넌트 1.0.0·토큰 1.1.0), #65(컴포넌트 2.0.0), #82(컴포넌트 2.1.0·2.2.0: `term` 표시는 `RenderedTextView`·`SentenceBlock`, 잠김 라벨 이름은 `SentenceBlock` locked에 반영), A1 착수 안내(#30). 받은 요청 #100(인증 규칙)·#114(Apple 웹 로그인 draft.2)는 기반 범위만 반영했고 남은 일은 아래 계획 2·7입니다. 앞으로 받은 요청은 `gh issue list --label to:app`.
* 반응 버튼(`reaction-button`)은 총운 문장에만 붙습니다(D57).

## 다음 할 일
1. **기반 PR 병합.** `app/foundation` → `main`. `ci-gate` 연결(#85) 뒤에는 app CI가 판정에 포함되며, 연결되면 `app.yml`의 `pull_request` 트리거를 지휘 세션이 지웁니다. 병합 전 `git merge origin/main`.
2. **계획 2(온보딩·로그인)를 writing-plans로** 씁니다(`app/docs/plans/`). 화면: `launch`·`force-update`·`welcome`·`onboard-*`·`birthplace`·`preview`·`login`·`consent`·`notify-ask`·`ad-consent`. 기반에서 넘어온 것:
   * `primary-button`(action.json)을 이 계획에서 만들고, ErrorState·EmptyState·근거 잠금 안내의 임시 `FeedbackTextAction`을 교체합니다.
   * 약관 동의 직후에는 "프로필 저장 → `entryStateProvider.notifier.refresh()`" 순서입니다(먼저 refresh하면 profileRequired로 `/onboard-call`에 튕깁니다).
   * 딥링크·알림 열기 뒤 원래 목적지로 돌아가는 방식을 설계합니다. 진입 갈래가 entry null이면 모든 경로를 `/launch`로 보내므로(`PushMessaging.initialOpen()` 포함) 진입 뒤 복귀가 필요합니다.
   * `profileTimezoneProvider`의 http 기본값 `Asia/Seoul`을 프로필 `currentTimezone`으로 바꾸고, 기기 시간대가 바뀌면 `PATCH /v1/me/profile`을 보냅니다(앱 셸의 훅 자리).
   * 온보딩 입력 저장소(OnboardingInputs 테이블)의 읽기·쓰기 API를 만들고, 프로필 저장에 성공하면 지웁니다.
   * 화면마다 `covers(...)` 선언과 흐름 테스트를 더하고 커버리지 baseline을 올립니다(`dart run tool/ia_coverage.dart --update-baseline`).
   * 로그인 화면(#100·#114): 원문 nonce를 `NonceGenerator`로 만들어 adapter와 server에 넘기고, Android는 `AppleWebAuth` 결과의 교환 코드로 `completeAppleWebLogin`을 부릅니다. `auth.exchange_invalid`(2분 일회용)와 `AppleWebError`(취소·state 불일치 등)별 안내, 503 `auth.provider_unavailable`은 재시도 안내입니다. 약관 동의 화면은 422 `consent.version_mismatch`(`errors[].field` `/documents/<i>/version`)를 받으면 문서를 다시 받습니다.
3. **이후 계획으로 넘긴 사항**
   * 계획 3(오늘·깊이 시트): 시트 3개(explain·evidence·day-sheet)의 IA states 처리 등록 방식을 정하고 `test/contract/ia_pending.dart`의 `pendingStateScreens`에서 지웁니다(ratchet). 표시용 시각(`FocusSlot.start·end`, `SolarTerm.at`)은 생성 모델이 UTC로 바꾸므로 화면에서 프로필 시간대로 변환합니다(계획 4 달력 절기도). 근거 잠금 해제 중 "세 구역 skeleton" 단계와 시간 초과 toast(`evidence-sheet.unlock.failed`)는 화면 흐름 몫입니다. 보상형 광고 뒤 권한 확인 폴링은 fixture `sequence`로 재현합니다.
   * 계획 7(수익·알림): `SignOutCleaner`에 알림 기기 해제(`deleteDevice`) 연결(기기 id 저장 포함). 실제 SDK adapter(카카오·Apple·Firebase·AdMob·RevenueCat)로 override합니다. 카카오·Apple adapter는 받은 원문 nonce를 `hashNonce`해 제공자에 보냅니다. Android Apple 웹 adapter는 `buildAppleAuthorizeUri`(Services ID, server 콜백 `redirect_uri`)로 브라우저를 열고 App Link `/auth/apple`(또는 안내 페이지 intent) 복귀를 `parseAppleWebReturn`으로 해석합니다. App Link intent filter와 **패키지 이름·서명 인증서 SHA-256 지문(debug·release·Play App Signing)과 스토어 URL을 #114에 알리는 일**도 이 계획입니다(server `ANDROID_APP_PACKAGE`·`ANDROID_CERT_SHA256`·`ANDROID_STORE_URL`).
4. **출시 전(I4) 확인:** 글꼴 31M를 release 빌드 다운로드 크기로 보고 subset 여부 재판단. Pretendard 업스트림 저작권 고지(Inter·Source Han Sans·M PLUS 1p `NOTICE.txt`)가 법적으로 충분한지 라이선스 검토.
5. 받은 요청은 `gh issue list --label to:app`으로 확인합니다. 기반 PR 때 design에 보내는 notice(아이콘 패키지 `phosphor_glyphs`, 탭 아이콘 선택, 컴포넌트 변형 등)의 답도 확인합니다.

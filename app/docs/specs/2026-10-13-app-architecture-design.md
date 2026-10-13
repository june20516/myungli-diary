# app 아키텍처 설계

* 작성: app 세션, 2026-10-13
* 상태: 검토 대기
* 마일스톤: A1 (app 설계, 대역 데이터로 화면 구현)
* 관련 결정: app 결정 A1~A13([`../decisions.md`](../decisions.md)), 루트 D13·D27~D30·D36~D41·D47~D62
* 쓰는 계약
  * REST API `server/api/openapi.yaml` 1.0.0-draft
  * IA `docs/ia/screens.json` v1
  * 디자인 토큰 1.1.0
  * 컴포넌트 명세 2.0.0
  * 슬롯 명세 v1
  * 라이팅 검사기 `mlw` v0.1.0

## 1. 목적과 범위

app이 화면 36개, 컴포넌트 41개, 슬롯 118개, REST operation 37개를 **계약을 기준으로 어긋남 없이 오래 유지할 수 있는 구조**를 정합니다. 기준은 "안정적으로 지속 가능한 개발"입니다. 구체적으로는 다음과 같습니다.

* 계약 파일이 원본이고 app 코드는 그것을 생성하거나 대조합니다. 계약이 바뀌면 컴파일 오류나 CI 실패로 먼저 드러납니다.
* 외부 SDK와 server는 모두 인터페이스 뒤에 두고 대역을 함께 둡니다. 계정 준비나 server 진행을 기다리지 않고 전 흐름을 개발하고 테스트합니다.
* 성숙한 안정판 도구를 쓰고, 기술 스택의 커뮤니티 표준을 따릅니다.

**이 spec이 다루지 않는 것**
* 화면별 내용(슬롯·컴포넌트·경로·상태): IA와 컴포넌트 명세가 이미 정했으므로 다시 적지 않습니다. 화면 구현은 §10의 계획에서 다룹니다.
* 실제 API 연동: 마일스톤 A2(S3 freeze 뒤)입니다. A1은 fake 모드로 완성하고, A2는 base URL과 adapter를 바꾸는 일이 되도록 설계합니다.

## 2. 프로젝트 구조와 계층 (결정 A3)

```
app/
  lib/
    main.dart              # --dart-define=API_MODE=fake|http
    app/                   # 부트스트랩, 라우터, 테마 연결, 전역 provider
    core/
      api/gen/             # openapi.yaml 생성 코드 (commit, 손대지 않음)
      api/                 # Dio, interceptor(공통 헤더·인증·대역), Problem → AppError
      storage/             # drift DB(사주 캐시·그날 캐시·일기 초안·온보딩 입력), 보안 저장소
      l10n/                # ARB와 생성 코드
      clock/               # "오늘" 계산 (D30)
      platform/            # 외부 SDK 인터페이스와 대역 구현 (§7)
    design/
      tokens/gen/          # DTCG → Dart 생성 코드 (commit)
      theme/               # ThemeExtension 조립
      components/          # 컴포넌트 41개, 명세 파일 묶음대로
    features/<영역>/        # onboarding, auth, today, depth, calendar, diary, me, monetization
      data/                # repository
      application/         # Riverpod provider·notifier
      presentation/        # 화면 (IA 화면 id 하나당 하나)
  widgetbook/              # 컴포넌트 카탈로그 앱 (app을 path 의존)
  fixtures/<시나리오>/       # 대역 JSON (assets, 스키마 검증 대상)
  tool/                    # 토큰 생성기, fixture 검증기, E2E 커버리지 보고 도구
  test/                    # 단위·위젯·golden·앱 흐름·계약 대조
  patrol_test/             # 기기 E2E (Patrol, §8.1)
  docs/  specs/ plans/ artifacts/
```

* **의존 방향은 presentation → application → data → core 한쪽입니다.**
  * feature끼리는 서로의 application provider로만 참조합니다.
  * `design/`은 feature를 모릅니다.
* **도메인 계층을 따로 두지 않습니다.**
  * repository는 생성 모델을 그대로 돌려줍니다. 계약이 원본이므로 매핑 계층을 두면 스키마 99개를 한 번 더 옮겨 적게 되고, 그만큼 어긋날 자리가 생깁니다.
  * app이 의미를 더하는 곳에만 작은 값 객체를 둡니다. 예: `segments`를 표시 조각으로 바꾼 것, 근거 잠금 상태, 진입 갈래.
* **상태 관리는 Riverpod 3.x입니다(결정 A1).**
  * 이 앱의 상태는 대부분 "server 응답 + 캐시 + 권한"입니다. 비동기 상태(`AsyncValue`)와 의존성 주입이 내장된 Riverpod가 이 구조에 맞습니다.
  * 대역 교체는 provider override 한 줄입니다. 코드 생성(`riverpod_generator`) 사용 여부는 기반 계획에서 그때의 안정판을 확인하고 정합니다.

## 3. 라우팅과 진입 갈래 (결정 A4)

* **go_router**를 씁니다.
  * route 이름은 IA 화면 id 그대로입니다.
  * 탭 4개(D48)는 `StatefulShellRoute`로 탭마다 스택을 유지합니다.
* **시트는 route가 아닙니다.** `explain-sheet`·`evidence-sheet`·`day-sheet`·`share-preview`는 시트 서비스로 엽니다. 어느 화면 위에서도 겹쳐 열리고, 닫히면 원래 화면으로 돌아와야 하기 때문입니다.
* **시스템 화면은 SDK 호출입니다.** 대상은 `system-push`, `system-share`, `system-purchase`, `system-rewarded-ad`, `ad-consent`입니다.
* **진입 갈래는 상태 하나에서 계산합니다.**
  * 판정 순서는 `force-update` > 로그아웃 > 약관 미동의 > 프로필 없음 > 이 기기 광고 동의 전 > 완료입니다.
  * 이 상태는 다음 값에서 나옵니다: 앱 버전과 `getAppConfig`, 토큰 유무, `getMe`(`consentRequired`·`hasProfile`·`status`), 기기 플래그(광고 동의).
  * 라우터 redirect는 이 상태만 보고 IA `auth`(guest·member·any)를 가립니다.
  * 갈래 규칙은 한 함수에 모으고, 표 형태로 단위 테스트합니다(IA spec §3.3의 경우 전부).
* **온보딩 입력은 로컬에 저장합니다.**
  * 미리보기 뒤 로그인 도중 앱이 꺼져도 입력이 남습니다. 프로필 저장이 성공하면 지웁니다.
  * `profile-edit`에서 연 `onboard-*`·`birthplace`는 같은 화면을 수정 모드로 쓰고, 저장 뒤 `profile-edit`로 돌아갑니다(IA §4.1).
* **IA 대조 테스트**(CI)는 `docs/ia/screens.json`을 읽어 다음을 확인합니다.
  * page 화면마다 route가 있는지
  * 각 `exits`의 이동이 화면 코드의 이동 표에 있는지
  * 화면이 자기 `states`를 모두 처리하는지(화면마다 상태 목록을 선언하고 대조)
  * 탭 루트 4곳에만 `ad-banner`가 있는지

## 4. 데이터 계층

### 4.1 통신 (결정 A2)

* `openapi.yaml`에서 Dart 모델과 클라이언트를 생성해 `core/api/gen/`에 commit합니다(D33 관례).
  * 생성기 후보: ① 순수 Dart인 `swagger_parser`(우선), ② `openapi-generator` `dart-dio`.
  * 기반 계획에서 실제로 생성해 보고 확정합니다. 계약은 `oneOf`·`allOf`·`discriminator`가 없는 평범한 형태여서 둘 다 처리할 수 있습니다.
* HTTP는 Dio입니다. interceptor 순서는 다음과 같습니다.
  1. **공통 헤더:**
     * 비로그인 요청에는 `Accept-Language`를 붙입니다.
     * `createPreview`·`getBirthHour`에는 `X-Firebase-AppCheck`를 붙입니다.
  2. **인증:**
     * bearer를 붙입니다.
     * 401 `auth.token_expired`면 refresh를 **한 번만** 하고 원 요청을 다시 보냅니다. 동시에 실패한 요청들은 같은 refresh를 기다립니다.
     * `auth.refresh_reused`나 refresh 실패면 로그아웃 상태로 바꿉니다.
  3. **대역:** fake 모드에서만 끼웁니다(§4.2).
* access token은 메모리에, refresh token은 보안 저장소(Keychain·Keystore)에 둡니다.
* `Idempotency-Key`(`createSchedule`·`registerDevice`)는 사용자 동작 하나마다 UUID를 만들고, 재시도에도 같은 키를 씁니다.
* 기기 시간대가 바뀌면 `PATCH /v1/me/profile`로 알립니다(server spec §5.3). 앱이 포그라운드로 돌아올 때 확인합니다.

### 4.2 대역과 fixture (결정 A2)

* fake 모드에서는 대역 interceptor가 `fixtures/<시나리오>/`의 JSON을 돌려줍니다.
  * 생성 클라이언트와 직렬화를 실제와 똑같이 거치므로, A2에서는 interceptor를 빼고 base URL을 정하면 됩니다.
* **시나리오**는 fixture 세트입니다. 시나리오에 따라 오류를 응답하거나 지연시키거나 오프라인처럼 굴 수 있습니다.
  * 기본 시나리오: 신규 사용자, 기존 사용자, 시간 모름, 근거 잠김·열림, 광고 제거 기간, 오프라인, 지원 범위 밖, 주요 오류 `code`
  * 개발 빌드에서는 앱 안 메뉴로 시나리오를 바꿉니다. 테스트는 시나리오를 지정해 앱을 띄웁니다.
* **fixture는 CI에서 `openapi.yaml` 스키마로 검증합니다.** 계약과 대역이 어긋나는 일을 기계가 잡습니다. 저장소가 Python 도구를 `uv`로 돌리는 관례를 따릅니다. 계약에 `example`이 없으므로 fixture는 직접 작성합니다.

### 4.3 오류

* 모든 실패는 sealed 타입 `AppError` 하나로 모읍니다. 종류는 `offline`, `timeout`, `problem(code, status, errors, traceId)`, `unexpected`입니다.
* 화면은 **`code` → ARB 문구 표 한 곳**을 거쳐 문구를 고릅니다(D59⑤). 표에 없는 `code`는 status 대역별 기본 문구를 씁니다.
* 필드 오류(`request.inconsistent`, `errors[].field` JSON Pointer)는 해당 입력 칸에 붙입니다.
* `traceId`는 오류 화면의 문의 정보와 로그에 남깁니다.
* server가 `Problem.code` 목록을 계약에 넣으면(§11 요청) "모든 코드에 문구가 있는지"를 테스트로 겁니다.

### 4.4 로컬 저장과 캐시 (결정 A5)

로컬 DB는 **drift(SQLite)**입니다. 타입 안전한 질의와 스키마 마이그레이션 도구·테스트가 있어, 앱 업데이트 때 로컬 데이터가 깨지지 않게 지킬 수 있습니다. 모든 행의 키에는 계정 id가 들어갑니다. 로그아웃·계정 삭제 때 그 계정의 행을 모두 지웁니다.

**사주 기반 영구 캐시: 달력(`getCalendar`), 나의 사주(`getChart`)**
* 달력의 길흉과 나의 사주는 (내 사주, 그 달·그해)로 정해집니다. server도 `birth_hash + rulesetVersion + 연·월 + 시간대`로 캐시합니다. 그날 문장(`level`)도 server가 (계정, 날짜, 슬롯)마다 한 번 골라 고정합니다(D59②).
* **키:** 계정 + **사주 지문** + 언어 + 연·월. 나의 사주는 연·월 대신 연도를 씁니다(세운 표가 해마다 바뀜).
  * 사주 지문은 프로필의 출생 정보, 출생지, 현재 시간대를 정규화해 해시한 값입니다.
* 한 번 받은 달은 다시 요청하지 않고 바로 그립니다. 보고 있는 달의 앞뒤 한 달은 미리 받습니다. D41 범위(1900-01 ~ 2099-12) 밖으로는 넘기지 않습니다.
* **버리는 때**
  1. **사주가 바뀜:** 프로필 수정이 성공하면 이전 지문의 캐시를 모두 지웁니다.
  2. **규칙이 바뀜:** `getDaily` 응답의 `rulesetVersion`이 저장된 값과 다르면 사주 기반 캐시를 모두 버리고 새 값을 저장합니다.
  3. **잠금이 풀림:** `evidenceAccess: locked`로 받은 항목은 근거 열람 권한이 생기면 다시 받습니다.
  4. **시간대·언어가 바뀜:** 키가 달라지므로 자연히 새로 받습니다.

**그날 캐시: 오늘(`getDaily`)**
* 날짜가 키라 날마다 새로 받습니다. 마지막으로 받은 응답은 오프라인 표시용으로 남깁니다(D59③, IA `offline`).
* 화면은 캐시를 먼저 그리고 서버 응답으로 바꿉니다.
* 잠금이 풀리면 다시 받습니다.

**사용자 데이터: 일정·일기**
* 일정(`listSchedules`)은 사주 캐시와 분리합니다. 만들기·수정·삭제가 성공하면 해당 달 일정만 다시 받습니다.
* 일기 목록과 본문은 캐시하지 않고 매번 받습니다. 동기화는 MVP 밖입니다(D47②).

**참조 데이터**
* `getGlossary`·`listCities`는 `ETag`/`If-None-Match`를 씁니다.

**일기 초안 (D47②·D49)**
* 편집 중 입력을 짧은 지연(debounce)으로 로컬에 계속 저장합니다. 초안은 날짜당 1개입니다.
* 저장이 성공하면 초안을 지웁니다.
* 오프라인이면 저장 대신 초안 상태와 안내를 보입니다(IA `draft`·`offline`). 다시 연결되면 저장할 수 있다고 알립니다. 자동 업로드는 하지 않습니다.

### 4.5 시간

* "오늘"은 `Clock` provider가 프로필의 현재 시간대로 계산합니다(D30).
* 화면이 열려 있는 동안 자정을 넘기면 오늘 화면을 갱신합니다.
* 테스트에서는 시계를 고정합니다.

## 5. 사주 변경의 무게 (결정 A6)

사주를 바꾸면 앱이 보여 주던 "나"가 통째로 바뀝니다. 사용자가 그 무게를 알고 바꾸게 합니다.

| 다시 계산됨 | 그때 기록 그대로 남음 |
| --- | --- |
| 오늘 풀이, 달력 길흉 전체, 나의 사주(원국·용신·대운), 행운 카드, 아침 알림 | 이미 쓴 일기와 그 태그·가이드 질문(저장할 때 기록, D59④). 태그 모아보기에서 옛 사주로 붙은 태그와 새 사주로 붙은 태그가 섞임 |

* **가벼운 변경:** 호칭입니다. 다시 계산하지 않고 문장 속 부르는 말만 바뀌므로 바로 저장합니다.
* **무거운 변경:** 생일(양력·음력·윤달), 태어난 시간, 성별(대운 방향), 출생지입니다.
  1. `profile-edit` 위쪽에 안내(`profile-edit.recalc.notice`)를 둡니다.
  2. 무거운 항목을 고쳐 저장하면 확인 창을 띄웁니다. 창에는 바뀌기 전 → 바뀐 뒤 값과 위 표의 영향을 보입니다. 기본 선택은 취소입니다.
  3. 확정하면 저장하고, 사주 기반 캐시를 지운 뒤(§4.4) 나의 사주로 이동해 새 원국을 먼저 보여 줍니다.
* 확인 창에 필요한 `dialog` 컴포넌트와 슬롯 `profile-edit.recalc.confirm`(ui)은 IA에 없으므로 지휘 세션에 추가를 요청합니다(§11).
* 태그 모아보기에서 옛 사주와 새 사주 태그를 구분해 보이는 일은 Phase 2 아이디어로 넘깁니다.

## 6. 디자인 시스템과 문장 표시

### 6.1 토큰과 테마

* `tool/`의 Dart 생성기가 `docs/identity/design/tokens/*.json`(DTCG 2025.10)을 읽어 `design/tokens/gen/`에 씁니다.
  * 참조를 모두 풀고, 테마 조합 4개(라이트·다크 × ko·ja)마다 값 클래스를 만듭니다. 영어는 ko 글자 파일을 씁니다.
* 색·글자·간격·반경·모션·그림자·그라데이션을 `ThemeExtension`으로 노출합니다.
  * 위젯은 **의미 역할 이름**(예 `tokens.color.bgBase`)으로만 접근합니다. 원시 팔레트는 노출하지 않습니다(토큰 README 규칙).
* 다크 모드는 기기 설정을 따릅니다(design 결정 V4). 공유 이미지만 라이트로 고정합니다(V5).
* CI는 생성기를 다시 돌려 commit된 코드와 같은지 확인합니다.

### 6.2 글꼴

* Gowun Dodum, Pretendard, Pretendard JP, Zen Maru Gothic(모두 SIL OFL 1.1)을 앱에 포함합니다. 오프라인에서도 처음부터 맞는 글꼴이 보여야 하기 때문입니다.
* 토큰이 쓰는 굵기만 넣습니다.
* 일본어 글꼴은 용량이 크므로 기반 계획에서 앱 크기를 재 보고 판단합니다. 일기 본문에 어떤 글자가 올지 모르므로 글리프를 잘라내는 subset은 하지 않는 것이 기본입니다.

### 6.3 컴포넌트 (결정 A8)

* `design/components/`에 명세 파일 묶음(frame·feedback·input·action·sentence·today·calendar·diary·saju)대로 둡니다. 변형·상태 id는 명세 그대로 Dart enum으로 씁니다.
* 공통 규칙은 기반 계획에서 한 번 구현하고 모든 컴포넌트가 따릅니다.
  * 명세에 없는 효과(물결, 그림자, 표면 색조, 상태 겹침 색)는 끕니다.
  * 기기 글자 크기를 따르고, 고정 칸 표는 1.3배 상한(`a11y.textScaleMax`)을 둡니다.
  * 동작 줄이기(투명도 변화만 남김), 투명도 줄이기, 저사양 대체(`interaction.json` `fallbacks`)를 지킵니다.
  * 햅틱은 selection·light·medium 세 단계이고 시스템 설정을 따릅니다.
  * 스피너를 쓰지 않습니다. 불러오는 중은 skeleton, 버튼 처리 중은 점 숨쉬기입니다.
  * 모양 규칙(결정 V26): 동작은 둥근 사각, 값 표시·고르기는 알약입니다. 화면 좌우 여백은 `space.20`입니다.
  * 길흉은 색만으로 전하지 않고 스크린리더 라벨에 길흉 낱말을 넣습니다.
* **검증**
  * **golden:** 컴포넌트 × 변형·상태 × 라이트·다크 × ko·ja × 글자 크기(1.0·1.3·2.0). 기준 이미지는 CI(Linux)에서 만듭니다. Flutter 버전이 올라가 렌더가 달라지면 수동 실행 job(`--update-goldens`)으로 다시 만듭니다.
  * **Widgetbook:** 변형과 상태를 넘겨 보며 명세와 눈으로 대조합니다.
  * **명세 대조 테스트:** 컴포넌트 JSON의 변형·상태 id가 Dart enum에 모두 있는지 확인합니다.

### 6.4 다국어 (결정 A7)

* UI 문구는 `flutter gen-l10n`과 ARB(ko·en·ja)를 씁니다. CI에서 `mlw check-arb`로 검사합니다.
* **ARB 키 이름**
  * writing 슬롯의 `keys`를 따릅니다.
  * 원고가 오기 전에는 IA 슬롯 id를 lowerCamelCase로 바꾼 키(예 `today.guide.cta` → `todayGuideCta`)와 임시 한국어 문구를 씁니다. 임시 문구는 `@<키>` 메타데이터의 `description`에 `임시`라고 표시합니다.
  * 같은 이름 규칙을 슬롯에 써 달라고 writing에 요청합니다(§11). 나중에 키 이름을 바꾸는 비용을 없애기 위해서입니다.
* 언어는 기기 설정이 기본이고 설정에서 바꿀 수 있습니다. 바꾸면 프로필 `language`를 고치고 출생지 안내를 띄웁니다(D29, IA `settings.language.birthplace-notice`).
* 날짜·숫자는 `intl`로 언어별 형식을 씁니다. 음력은 응답의 `lunar` 값을 그대로 보이고, app은 음력을 계산하지 않습니다(D41).

### 6.5 콘텐츠 문장

* 공용 위젯 하나가 `RenderedText.segments`를 `Text.rich`로 그립니다. app은 문장을 고르거나 조사를 붙이지 않습니다(D59).
* `term` 조각은 `term-token`(색 표시, 누르면 풀이 시트)으로 그립니다. 표시 방식의 남은 결정(server spec §13, Issue #48 항목 3)은 design이 정하는 대로 따릅니다.
* enum 값(오행·십성·태그 등)의 표시 이름은 `getGlossary`에서 받습니다. 원국표의 천간·지지 한자는 고정값이라 app이 가집니다.
* 근거 잠금(D60)은 응답의 `evidenceAccess`로만 판단합니다. 잠긴 상태의 표시는 컴포넌트 명세 2.0.0 `depth-link.evidenceSheet`의 잠김 4상태와 `sentence-block` `locked`를 따릅니다.

### 6.6 IA id 부착

* 화면 뿌리 위젯에는 IA 화면 id를, 슬롯을 그리는 위젯에는 IA 슬롯 id를 **Key와 Semantics `identifier`로 함께** 붙입니다. 예: `today`, `today.guide.question`.
* id 문자열은 `screens.json`에서 생성한 Dart 상수만 씁니다. 손으로 적은 문자열은 쓰지 않으며, IA가 id를 바꾸면 컴파일 오류로 드러납니다.
* 테스트(§8)는 이 id로 화면과 자리를 찾습니다. Semantics `identifier`는 사용자에게 보이지도 읽히지도 않으므로 접근성 라벨과 겹치지 않습니다.

## 7. 플랫폼 연동 (결정 A9·A10·A12)

**모든 외부 SDK는 `core/platform/`의 인터페이스 뒤에 두고 대역 구현을 함께 둡니다(결정 A9).**
* 대상: 카카오, Apple, Firebase(App Check·FCM·Crashlytics), AdMob, UMP·ATT, RevenueCat, 공유.
* A1은 fake 모드로 모든 흐름을 끝까지 돌립니다. 실제 구현은 사용자가 계정을 준비하는 대로(`docs/roadmap.md` 외부 준비물) adapter만 바꿉니다.

| 영역 | 설계 |
| --- | --- |
| 카카오 로그인 (D55) | 카카오 SDK로 OIDC `id_token`을 받습니다. app이 만든 nonce를 함께 보냅니다(`loginKakao`) |
| Apple 로그인 iOS | 네이티브 로그인, `clientType: native` |
| Apple 로그인 Android (결정 A12) | Custom Tabs로 Apple 인증을 엽니다. server 콜백(`appleCallback`)의 303이 **Android App Link**(https, 도메인 검증)로 app에 돌아옵니다. app은 자기가 만든 `state`가 맞는지 확인한 뒤 `loginApple(clientType: web)`을 부릅니다. custom scheme보다 다른 앱의 가로채기에 안전합니다. Location 형식은 server에 요청합니다(§11) |
| 로그인 뒤 | RevenueCat `logIn(accountId)`, FCM 기기 등록(알림을 켠 경우) |
| App Check | iOS App Attest, Android Play Integrity. 비로그인 요청에만 붙입니다 |
| 알림 (D18⑨·D62) | `notify-ask`에서 시각을 고르면 권한을 요청하고 `registerDevice`로 등록합니다. 토큰이 바뀌면 다시 등록하고, 로그아웃하면 `deleteDevice`로 해제합니다. 알림을 누르면 `today`로 갑니다(로그아웃 상태면 `welcome`) |
| 비정상 종료 보고 (결정 A10) | Firebase Crashlytics. 개인정보 처리방침에 수집 항목을 반영하도록 지휘 세션에 알립니다(§11) |
| 광고 동의 (D53④) | 이 기기에서 처음 광고를 보이기 전에 UMP(필요한 지역) → iOS ATT 순서로 한 번 받습니다. 거절해도 비맞춤 광고로 계속합니다. 동의를 받았다는 기기 플래그는 로컬에 둡니다 |
| 배너 (D53①) | 적응형 배너를 탭 루트 4곳 하단에만 둡니다. `adFree.active`면 자리째 숨깁니다. 불러오지 못하면 자리를 비우고 레이아웃이 튀지 않게 합니다 |
| 보상형 광고 (D60) | 근거 시트의 잠금 안내에서 사용자가 고를 때만 띄웁니다. 매번 보상을 먼저 알리고, 광고가 준비됐을 때만 버튼을 켭니다. SSV `userId`는 계정 id입니다. 다 보면 "확인 중" 상태로 `getEntitlements`를 2초 간격으로 최대 30초 동안 다시 묻습니다(값은 상수 하나로 두고 A2에서 실측해 조정). `insight.active`가 되면 열고(§4.4 잠금 해제 캐시 규칙), 30초 안에 안 되면 `evidence-sheet.unlock.failed` toast를 보입니다. 권한은 server만 부여하며 app이 스스로 열지 않습니다 |
| 광고 제거권 (D53·D54·D61) | RevenueCat. 상품은 1개월 광고 제거권 하나(Apple 비갱신 구독, Google 일회성)입니다. 구매가 끝나면 `getEntitlements`로 server 기준 상태를 받아 반영합니다. 남은 기간은 server가 계산합니다. 구매 복원은 `restorePurchases`입니다 |
| 공유 (D47④) | `share-image`를 라이트 테마로 화면 밖에서 그려 PNG로 만들고 OS 공유 시트에 넘깁니다. 로그인이 필요합니다 |
| 버전 강제 | 실행할 때 `getAppConfig`의 플랫폼별 최소 버전보다 낮으면 `force-update`로 막습니다 |
| 오픈소스 고지 | `legal`에 Flutter 라이선스 목록과 함께 글꼴(OFL)과 GeoNames 출처(CC BY 4.0, Issue #48 항목 5)를 표기합니다 |

## 8. 테스트

개발은 TDD로 합니다.

| 층 | 대상 | 실행 |
| --- | --- | --- |
| 단위 | 진입 갈래 계산, refresh 단일 비행, 캐시 키와 무효화 규칙, 사주 지문, 오류 → 문구, 초안 저장, `Clock`, 토큰 생성기 | CI |
| 위젯 | 화면마다 IA `states` 전부(fixture 시나리오로) | CI |
| golden | 컴포넌트 조합(§6.3) | CI (Linux 기준) |
| 앱 흐름 | fake 모드 앱 전체를 위젯 테스트로 띄워 주요 흐름을 끝까지 실행합니다. 흐름: 온보딩 → 미리보기 → 로그인 → 오늘, 일기 쓰기와 오프라인 초안, 근거 잠금 해제, 사주 변경 확인, 광고 제거권 구매 | CI |
| 기기 E2E | Patrol로 실제 iOS·Android 위에서 흐름 전체와 네이티브 화면(권한 대화상자, 알림 누르기, 네트워크 끊김, 다크 모드)까지 실행(§8.1) | CI(Android 에뮬레이터, 병합 뒤·매일 밤·수동), 로컬(iOS·Android, 계획마다 마무리 때) |
| 계약 대조 | IA 대조(§3), 컴포넌트 명세 대조(§6.3), fixture 스키마 검증(§4.2), 생성 코드 차이 0, `mlw check-arb` | CI |
| DB 마이그레이션 | drift 스키마 버전마다 이전 → 다음 마이그레이션 테스트 | CI |

### 8.1 문서 기반 E2E (결정 A13)

IA·결정 로그·계약이 기계가 읽을 수 있는 형태로 있으므로, E2E는 이 문서를 명세로 삼습니다.

* **도구는 Patrol입니다.**
  * Flutter 전용이고 `integration_test` 위에서 돕니다. 네이티브 화면(권한 대화상자, 알림, 시스템 설정)을 다룰 수 있습니다.
  * app 코드와 언어가 같아 fixture 시나리오, IA id 상수(§6.6), provider override를 그대로 공유합니다.
* **문서의 어휘로 씁니다.** 테스트는 IA 화면·슬롯 id로 자리를 찾습니다. 예: "`today`에서 `today.guide.question`을 누르면 `diary-edit`".
* **덮는 범위를 선언합니다.** 각 E2E와 앱 흐름 테스트는 덮는 대상을 메타데이터로 적습니다.
  * IA 경로: `today→diary-edit`
  * 화면 상태: `diary-edit:offline`
  * 결정: `D49`
* **커버리지 보고서**
  * `tool/`의 도구가 위 선언을 `screens.json`과 결정 로그에 대조해 JSON과 표를 만듭니다.
  * 담는 것: 덮지 못한 경로·상태, 결정 → 테스트 표.
  * CI는 커버리지가 줄어들면 실패합니다(ratchet). 계획 2~7을 진행하며 IA 경로·상태 100%까지 올립니다.
  * 결정은 동작으로 확인할 수 있는 것만 대상입니다. 대상 목록은 보고서 설정 파일에 둡니다.
* **시나리오 이름은 문서 조건으로 짓습니다.** 예: `time-unknown`, `evidence-locked`, `ad-free-active`, `offline`, `preview-used`.
* **같은 E2E를 두 모드로 돌립니다.** A1은 fake 모드입니다. A2·I2·I3에서는 http 모드로 스테이징 server를 상대로 같은 테스트를 돌립니다. 지휘 세션의 통합 마일스톤이 이 E2E를 재사용할 수 있습니다.
* **스크린샷이 저절로 쌓입니다.**
  * E2E가 IA 화면·상태에 도착하면 캡처합니다.
  * 캡처는 `app/docs/artifacts/`에 저장하고 `index.json`에 등록합니다(`kind: screenshot`, `screens`에 IA id).
  * 커버리지 보고서 JSON도 함께 두어, 제품 지도가 화면별 E2E 결과를 보일 수 있게 합니다(§11 제안).

## 9. 도구와 CI (결정 A11)

**도구 버전: 커뮤니티 표준을 따릅니다.**
* Flutter는 **stable 채널을 따라갑니다.** `pubspec.yaml`에는 Dart SDK 하한(`sdk: ^3.x`)만 둡니다. FVM이나 정확한 SDK 고정은 쓰지 않습니다.
* `pubspec.lock`은 commit합니다. 의존성은 안정판만 씁니다(pre-release 금지). 올릴 때는 PR 하나로 묶어 CI로 확인합니다.
* 의존성 자동 갱신은 규약대로 MVP 안정화 뒤에 합니다(workflow §8).
* lint는 엄격한 규칙 세트(`very_good_analysis` 수준)를 쓰고 경고 0을 유지합니다.

**개발 환경**
* 편집기는 VS Code + 공식 Flutter 확장입니다. Android Studio는 Android SDK·에뮬레이터 관리용입니다. iOS 빌드에는 Xcode가 필요합니다. 설치 확인은 `flutter doctor`로 합니다.
* 저장소에 함께 넣는 것:
  * `app/.vscode/extensions.json`: 권장 확장
  * `app/.vscode/launch.json`: fake·http 실행 구성
  * `app/.vscode/settings.json`: 저장할 때 format과 import 정리
  * `analysis_options.yaml`

**CI (`.github/workflows/app.yml`, app 소유)**
* 처음부터 `workflow_call`을 지원합니다. `ci-gate` 연결은 지휘 소유라 요청합니다(§11).
* 경로 필터: `app/`, `.github/workflows/app.yml`, 그리고 app이 쓰는 계약 경로입니다.
  * `server/api/openapi.yaml`
  * `docs/ia/screens.json`
  * `docs/identity/design/tokens/`, `docs/identity/design/components/`
  * `docs/identity/writing/slots/`
* 단계:
  1. format 확인, analyze
  2. 생성 코드 차이 확인: openapi, 토큰, `build_runner`, l10n
  3. fixture 스키마 검증
  4. 테스트(단위·위젯·golden·앱 흐름·계약 대조·마이그레이션)
  5. E2E 커버리지 보고서(선언 대조, ratchet)
  6. `mlw check-arb`
  7. Android debug 빌드
* iOS 빌드는 규약대로 로컬 Mac에서 합니다(workflow §8).
* golden 갱신용 수동 실행 job(`workflow_dispatch`)을 둡니다.
* **기기 E2E job**은 Android 에뮬레이터(Linux, KVM)에서 Patrol을 돌립니다.
  * 비공개 저장소의 무료 플랜이라 Actions 사용 시간이 제한되므로 PR마다 돌리지 않습니다. `main` 병합 뒤, 매일 밤, 수동 실행으로 돕니다.
  * PR에서는 위젯 수준 앱 흐름 테스트가 같은 흐름을 지킵니다.
  * 이 job은 `ci-gate` 판정에 넣지 않고, 실패하면 Issue로 다룹니다.

**산출물:** E2E가 만든 화면 스크린샷과 커버리지 보고서를 `app/docs/artifacts/`에 두고 `index.json`에 등록합니다(workflow §7, §8.1).

## 10. 계획 분할

계획마다 브랜치 하나(`app/<주제>`)와 PR 하나를 씁니다. 계획 문서는 `app/docs/plans/`에 둡니다.

| 순서 | 계획 | 내용 |
| --- | --- | --- |
| 1 | 기반 | 프로젝트 생성, 구조, lint, CI, `.vscode`, 토큰 생성·테마·글꼴, 생성 클라이언트·대역 interceptor·fixture 검증, drift, `Clock`, 라우터·진입 갈래, l10n 뼈대·오류 문구 표, 플랫폼 인터페이스와 대역, Widgetbook·golden 기반, IA id 상수 생성, E2E 뼈대(Patrol 설정, 커버리지 도구, 에뮬레이터 CI job, 스크린샷 등록), 공통 컴포넌트(frame·feedback·sentence) |
| 2 | 온보딩·로그인 | `launch`·`force-update`·`welcome`·`onboard-*`·`birthplace`·`preview`·`login`·`consent`·`notify-ask`·`ad-consent`, 로그인 adapter(대역), 온보딩 입력 보존 |
| 3 | 오늘·깊이 시트 | `today`, `explain-sheet`, `evidence-sheet`(잠금 4상태), 반응, `share-preview`, 그날 캐시 |
| 4 | 달력·일정 | `calendar`(사주 기반 영구 캐시·미리 받기), `day-sheet`, `event-edit` |
| 5 | 일기 | `diary-list`·`diary-edit`·`diary-view`·`tag-diary`, 로컬 초안, 오프라인 |
| 6 | 나·설정 | `my-saju`, `saju-chart`, `settings`, `profile-edit`(무거운 변경 확인, §5), `calc-basis`, `account-delete`, `legal` |
| 7 | 수익·알림 | 배너, 광고 동의, 보상형 해제, `ad-free`, FCM. 대역 adapter로 끝내고, 계정이 준비되면 실제 adapter로 바꿉니다 |

각 계획은 앞 계획의 공통 부품을 씁니다. 계획 3~6에 필요한 컴포넌트는 그 계획에서 만듭니다(예: 달력 컴포넌트는 계획 4).

## 11. 다른 단위에 보낼 요청

spec 승인 뒤 Issue로 보냅니다.

| 받는 쪽 | 종류 | 내용 | 막는가 |
| --- | --- | --- | --- |
| root | request | IA `profile-edit`에 컴포넌트 `dialog`와 슬롯 `profile-edit.recalc.confirm`(ui) 추가(§5, 추가만이라 v1 유지) | 계획 6 |
| root | request | `ci-gate`에 `app.yml` 연결(§9) | 아니요 (그전까지 `app.yml`이 단독으로 돎) |
| root | notice | Crashlytics 사용(결정 A10). 개인정보 처리방침 수집 항목에 반영 | 아니요 |
| root | request | 제품 지도에 app E2E 커버리지 보고서(화면별 E2E 결과)를 보이기, 통합 마일스톤(I2·I3)에서 app E2E를 http 모드로 재사용하기(결정 A13) | 아니요 |
| server | request | `Problem.code` 목록을 openapi에 기계가 읽을 형태로 넣기(예: `x-problem-codes`), §4.3 | 아니요 |
| server | request | Apple 웹 콜백 303의 Location을 Android App Link 형식으로 정하기(결정 A12), §7 | 계획 7의 실제 adapter |
| writing | request | ui 슬롯의 ARB 키 이름을 IA 슬롯 id의 lowerCamelCase로 맞추기(결정 A7), §6.4 | 아니요 |

## 12. 위험과 대응

| 위험 | 대응 |
| --- | --- |
| REST 계약이 freeze(S3) 전에 바뀜 | 생성 코드 차이 검사와 fixture 스키마 검증이 CI에서 바로 알립니다. server의 `kind:notice`를 받아 반영합니다 |
| UI 문구 원고가 늦음 | 임시 문구로 진행하고 키 이름 규칙을 맞춰 두어, 원고가 오면 ARB 값만 바꿉니다 |
| Flutter stable 갱신으로 golden이 달라짐 | 수동 실행 job으로 다시 만들고, 차이를 PR에서 눈으로 확인합니다 |
| 일본어 글꼴로 앱 크기가 커짐 | 기반 계획에서 재 보고 판단합니다(§6.2) |
| 외부 계정 준비가 늦음 | 모든 SDK가 대역 adapter라 A1을 막지 않습니다 |

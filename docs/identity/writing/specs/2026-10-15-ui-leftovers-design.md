# 공용 ui 문구와 ICU plural 설계

* 날짜: 2026-10-15
* 다루는 요청: #143(app 임시 문구, 입력칸 이름≠hint, 카카오 ja, ICU plural), #148(writing.yml 트리거 제거)
* 근거: app ARB(`app/lib/core/l10n/arb/app_<lang>.arb`)에서 writing 원고가 없는 키 116개(PR #149 기준), #143 writing 답(2026-10-14), IA 컴포넌트 목록(`docs/ia/screens.json`), W17·W19·W20

## 1. 목표

1. app이 임시로 둔 문구 116개를 writing 원고로 바꿉니다. app은 `tool/import_writing_arb.dart`를 다시 돌리기만 하면 됩니다.
2. 지지·날의 성격 이름은 content 문장과 같은 이름이 되도록 glossary 이름 원고에서 ARB를 만듭니다.
3. `mlw check`와 `mlw check-arb`가 ICU plural을 받습니다.

바꾸지 않는 것: app 키 이름과 자리표시자 이름·타입, 기존 ui 슬롯 id와 키, ARB 생성 규칙(키 순서, 메타데이터는 ko에만).

## 2. 공용 ui 슬롯 (키 100개)

116개 중 지지·날의 성격 16개(§3)를 뺀 100개를 `slots/ui/common.yaml`에 둡니다.

* id는 `ui.<묶음>.<이름>`입니다. IA 밖 공용 문구이므로 자리를 `components`(IA 컴포넌트 id)로 적고, 키 이름은 app 이름을 그대로 씁니다(`ia.key_name`은 IA id 슬롯에만 걸림).
* 목적·구조가 같은 키는 슬롯 하나에 여러 키로 묶습니다.

| 슬롯 | components | 키 |
| --- | --- | --- |
| `ui.error.client` | `error-state`, `toast` | `errorOffline`, `errorTimeout`, `errorClient`, `errorServer`, `errorUnexpected`, `errorNotImplemented` |
| `ui.error.code` | `error-state`, `toast` | 서버 오류 코드별 `error*` 39개 |
| `ui.app.name` | `app-bar` | `appTitle` (W17 앱 이름) |
| `ui.app.bootstrap` | `error-state` | `bootstrapFailed` |
| `ui.app.notice` | `notice-banner`, `empty-state` | `noticeOffline`, `emptyStateDefault` |
| `ui.app.trace` | `error-state`, `toast` | `traceIdLabel`, `traceIdCopied` |
| `ui.action.button` | `primary-button`, `dialog`, `share-button`, `check-row`, `text-field`, `input-step` | `actionRetry`, `actionClose`, `actionConfirm`, `onboardingNext`, `onboardingSave`, `shareLabel`, `consentView`, `textFieldClear` |
| `ui.nav.tab` | `tab-bar` | `tabToday`, `tabCalendar`, `tabDiary`, `tabMe` |
| `ui.nav.a11y` | `app-bar`, `sheet` | `appBarBack`, `sheetDismiss` |
| `ui.a11y.label` | `primary-button`, `ad-banner`, `skeleton`, `term-token`, `input-step`, `text-field`, `city-search` | `actionBusy`, `adBannerLabel`, `skeletonLabel`, `termTokenSemantics`, `inputStepProgress`, `textFieldCounter`, `citySearchResults`, `onboardCallInputLabel`, `birthplaceSearchLabel` |
| `ui.picker.label` | `date-picker`, `time-picker` | 휠 이름 6개(`datePicker*Label`, `timePicker*Label`) |
| `ui.picker.item` | `date-picker`, `time-picker` | 칸 글자 `datePicker{Year,Month,Day}Item`, `timePicker{Hour,Minute}Item`, `timePickerAm`, `timePickerPm`, `datePickerLeapMonthValue` |
| `ui.birth.option` | `segmented`, `check-row` | `calendarSolar`, `calendarLunar`, `leapMonth`, `timeUnknownLabel`, `genderMale`, `genderFemale` |
| `ui.login.provider` | `social-login-button` | `loginKakaoLabel`, `loginAppleLabel` |
| `ui.login.error` | `toast`, `error-state` | `loginCancelled`, `appleWebErrorStateMismatch`, `appleWebErrorCancelled`, `appleWebErrorOther` |

* **자리표시자 값 종류는 app ARB 타입과 맞춥니다.** writing 메타데이터가 app 것을 덮어쓰기 때문입니다. `int`는 `number`, `String`은 `text`입니다(`traceId`·`term`·`minute`은 `text`, 나머지는 `number`).
* **입력칸 접근성 이름은 hint와 다른 말로 씁니다**(#143 ①). hint가 예시("예: 민지", "도시 이름")라면 이름은 칸의 목적을 말합니다.
* **로그인 버튼 라벨은 제공자 문구 그대로입니다**(#143 ③). 카카오는 ko "카카오 로그인", en·ja "Login with Kakao"(카카오 디자인 가이드에 일본어 지침 없음)이고, Apple은 Sign in with Apple HIG의 언어별 문구입니다. 보이스 규칙과 부딪히는 규칙은 슬롯 `allowed`에 적습니다.
* 글자 수 상한은 모두 `null`로 두고 design #131에 함께 요청합니다.
* 오류 문구는 "무엇이 안 됐는지 + 할 수 있는 일"을 해요체로 씁니다(W6). 사용자가 할 일이 없으면 한 문장으로 끝냅니다.

## 3. 지지·날의 성격 이름 → ARB

* glossary 이름 원고 `branch.*` 12개와 `day_kind.*` 4개를 3개 언어로 처음 씁니다(`content/<lang>/glossary.yaml`). 나머지 glossary 이름은 W1에서 씁니다.
  * ko는 한글 이름입니다(`인`, `용신의 날`).
  * ja는 한자 표기입니다(`寅`, `用神の日`).
  * **en은 영어권에서 통하는 이름입니다.** 지지는 띠 동물(Rat, Ox, Tiger…)이고, 날의 성격은 뜻이 보이는 이름입니다. 이 점이 가이드의 "en 용어 토큰은 로마자 표기"와 다른 예외입니다(W22).
  * 지지 이름에는 시·hour·刻 같은 접미사를 붙이지 않습니다. `onboardTimeHourConfirm` 틀이 접미사를 붙입니다.
* `arb_export`에 ARB로 내보낼 glossary 범주를 상수 `ARB_TERM_CATEGORIES = ("branch", "day_kind")`로 둡니다.
  * 키는 `<범주>.<값>`을 `.`·`_` 경계에서 lowerCamelCase로 바꾼 이름입니다(`branch.in` → `branchIn`, `day_kind.yongsin_day` → `dayKindYongsinDay`). app 키와 같습니다.
  * 메타데이터 설명은 `glossary.value_name: <용어 id>`입니다.
  * ui 키와 이름이 겹치면 `gen-docs`가 오류로 멈춥니다.

## 4. ICU plural

* 새 모듈 `icu.py`의 `expand_plural(text, lang)`는 plural이 없으면 `[text]`를 돌려주고, 있으면 형태마다 펼친 문장 목록을 돌려줍니다. 문법이 틀리면 `ValueError`입니다.
  * 형식은 `{<변수>, plural, <형태>{<문장>} …}`이고, 문장 안에는 `#` 대신 `{<변수>}`를 씁니다. 지금 자리표시자 문법을 그대로 쓰기 위해서입니다.
  * 한 문장에 plural은 하나만 허용합니다. 앞뒤 글자는 펼친 문장마다 붙습니다.
* 새 규칙 `icu.plural`(error)
  * 문법 오류
  * 언어별 형태가 정확히 맞지 않음: ko·ja `other`, en `one`·`other`
  * 변수가 슬롯의 `number` 매개변수가 아님(`mlw check`만. ARB에는 슬롯이 없을 수 있음)
  * content 슬롯 원고에 plural을 씀(server 렌더는 ICU를 읽지 않음)
* 문장 규칙, 글자 수, ui 표기, 자리표시자 대조는 펼친 문장마다 적용합니다. `mlw check`(ui 원고)와 `mlw check-arb` 둘 다입니다.
* 첫 쓰임은 `citySearchResults`입니다. 검사기 버전은 v0.3.0입니다.

## 5. 기록과 알림

* 결정 W22: §2·§3·§4와 en 지지 이름 예외를 기록합니다.
* `guide/voice-tone.md` 영어·일본어 표의 en 용어 토큰 칸에 지지(띠 동물)·날의 성격 예외를 적습니다.
* en·ja 원고는 W1 원어민 검수 전 초안입니다.
* `.github/workflows/writing.yml`의 `push`·`pull_request` 트리거를 지웁니다(#148).
* #143에 키 목록과 가져오기 방법(`dart run tool/import_writing_arb.dart`)을 보고하고, #148에도 보고합니다.

## 6. 테스트

* `icu.expand_plural`: 펼치기, plural 없음, 문법 오류, 형태 검사, 앞뒤 글자.
* `check`·`check-arb`: plural 원고 통과, ko에 `one`을 쓰면 `icu.plural`, 변수가 `number`가 아니면 `icu.plural`.
* `arb_export`: glossary 범주 키 생성과 lowerCamelCase 이름, ui 키와 겹치면 오류.
* 저장소 대조: app ARB의 app 전용 키 중 writing ARB에 없는 것이 0개인지 일회성 스크립트로 확인합니다(CI에는 넣지 않습니다. app 소유 파일이기 때문입니다).

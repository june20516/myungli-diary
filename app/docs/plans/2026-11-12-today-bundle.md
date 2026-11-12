# 오늘 화면 묶음 계획 (drift #1018, REST 1.11.0, D119 #983, D124 #1032)

브랜치 `app/today-bundle`(`app/bugs-review2` 위, 그 브랜치는 draft PR #1057). PR 하나에 drift #1018 전체(컴포넌트 6.3.0→7.3.0, 토큰 1.7.0→1.9.0, IA, writing 원고, REST 1.10.0→1.11.0)와, 그 계약 몫을 구현하면 끝나는 요청 #983(D119 행운 색 칩 둘), #1032(D124 신살 도입)를 함께 담습니다. 원인 PR: #1015, #1016, #1022, #1023, #1025, #1033, #1036, #1039, #1040, #1042, #1043, #1045, #1048, #1049, #1050(#1052는 design 내부 문서만이라 app 몫 없음).

Spec은 따로 없습니다. 구속력 있는 기준은 계약 파일입니다: `docs/identity/design/components/*.json`과 `*.md`(변경 기록은 `components/README.md` "버전" 표의 7.0.0~7.3.0 행), `docs/identity/design/tokens/`(README 1.8.0, 1.9.0 행), `docs/identity/design/fonts/hanja-supplement/`, `docs/identity/design/lengths.md`, `docs/identity/design/decisions.md`(V114~V122), `docs/ia/screens.json`, `server/api/openapi.yaml`(1.11.0), `docs/identity/writing/slots/`, 루트 `docs/decisions.md`(D119, D122~D125). 계약 diff는 `git diff 92413145 origin/main -- docs/identity/design/components docs/identity/design/tokens docs/identity/design/fonts docs/identity/design/lengths.md docs/ia server/api/openapi.yaml docs/identity/writing/slots`로 봅니다(92413145 = 직전 drift #916 따라잡기 PR #993 병합).

이미 들어온 것: `app/bugs-review2`의 #1013 원고와 IA 가져오기로 #1018 몫 ARB 키(`todayDateVirtue*`, `todayLuckyColorPairIntro`, `todayLuckyTime*`, `shinsalWeighingNote`, `diaryEditGuideAttachHint`)와 IA 슬롯이 이미 있습니다(`app/docs/decisions.md` A132). 2026-11-12 origin/main 기준으로 다시 가져와도 ARB와 `ia.g.dart`는 차이가 없습니다. 화면 연결은 이 계획의 몫입니다.

## 현재 상태 (2026-11-12, 생성 도구를 돌려 확인한 뒤 되돌림)

| 검사 | 결과 | 원인과 맡는 task |
| --- | --- | --- |
| `import_writing_arb.dart`, `gen_ia.dart`, `flutter gen-l10n`, `gen_native_strings.dart`, `gen_native_config.dart --check` | 차이 없음 | A132로 이미 들어옴 |
| `gen_tokens.dart` | `tokens.g.dart` 바뀜 | `color.time.day`, `color.time.night`(1.8.0), 글꼴 fallback에 `Myungli Hanja Supplement`(1.9.0). Task 1 |
| `tool/gen_api.sh` | 생성 모델 13개 바뀜, 새 파일 3개 | `DayVirtue`, `DayVirtueKind`(새), `Daily.dayVirtues`, `CalendarDay.dayVirtues`, `DailyCards.secondColor`, `nightFocusTime`, `previousNightFocusTime`, `FocusSlot.dayDate`, `dayPillar`, `ShinsalAt.positions`, `ShinsalKind` 13개 더함. Task 1 |
| `flutter analyze`(다시 생성한 코드로) | 0건 | 컴파일은 깨지지 않음 |
| fixture 검사 `validate_fixtures.py` | 105건 실패 | `dayVirtues` 필수: `getDaily.json`(member, member-time-unknown, evidence-unlocked, reward-unlock 2개 응답), `getCalendar__2026-{9,10,11}.json`의 날 91개. `positions` 필수: `getChart.json`(member, member-time-unknown, evidence-unlocked, reward-unlock)의 `shinsal` 9개. Task 1 |
| fixture 검사 `test_validate_fixtures.py` | 17개 중 1개 실패 | `test_committed_fixtures_pass`(위 105건). Task 1 |
| `flutter test --tags contract --exclude-tags golden`(다시 생성한 코드로) | 29개 실패 | 아래 표 |
| `flutter test --exclude-tags golden`(다시 생성한 코드로) | 38개 파일 410개 실패 | 대부분 fixture에 `dayVirtues`, `positions`가 없어 `CheckedFromJsonException`(Task 1로 사라져야 함). 남는 것은 화면 task가 고침 |

계약 테스트 실패 29개:

| 테스트 | 실패 | 맡는 task |
| --- | --- | --- |
| `test/features/today/today_presentation_test.dart` | 23개. 22개는 fixture `Daily`에 `dayVirtues`가 없음, `formatFocusRange`는 계약에서 지운 `time.repeat`를 읽다 null | Task 1(fixture), Task 2(`repeat` 대조를 `periods`로) |
| `test/contract/open_enums_contract_test.dart` | 2개: 계약 열린 enum 목록에 `DayVirtueKind`가 더해짐, 그 enum을 쓰는 필드(`day_virtue.dart:kind`, `calendar_day.dart:dayVirtues`)가 모르는 값을 그 값으로 읽어야 함 | Task 1 |
| `test/tool/open_enums_test.dart` | "실제 계약에서 14개를 읽는다"(이제 15개) | Task 1 |
| `test/contract/component_contract_test.dart` `hanja-tag` 변형 | `compact` 없음 | Task 4 |
| `test/contract/component_contract_test.dart` 글자표 | 17자 → 21자(孤 寡 元 德) | Task 4(德), Task 5(孤 寡 元). 글자표 대조는 Task 4에서 21자로 한 번에 맞춤 |
| `test/contract/component_contract_test.dart` `settings-row` 변형 | `readonly` 없음 | Task 6 |

확인한 사실: 이전 앱이 남긴 캐시(`Daily`, `Calendar`, `Chart`)에 새 필수 필드가 없으면 `fromJson`이 실패하지만 `daily_repository.dart`, `calendar_repository.dart`, `chart_repository.dart`의 `cached()`가 실패를 캐시 없음(null)으로 다루고, 규칙 버전이 바뀌면 캐시를 지웁니다(`CacheStore.observeRulesetVersion`). 캐시 이주는 필요 없습니다.

## Global Constraints

* 작업 디렉터리는 worktree `/Users/bran/personal/myungli-diary-app`(app은 `app/`). 원 저장소 루트로 cd하지 않습니다. `git stash` 맨손 금지. push 금지(controller가 함).
* 먼저 `app/CLAUDE.md`를 읽습니다(규약, 도구, 테스트 방법). 사용자에게 보이는 글(ARB, 화면)에 U+2014, U+2013, U+00B7 금지(D93). 주석과 문서는 한국어 경어체, 기존 파일 문체를 따릅니다.
* **받는 값은 계약에 없으면 비어 있을 수 있습니다.** 빈 값은 오류가 아니고, 무엇이 늘 오는지는 `openapi.yaml`의 `required` 기준입니다. 선택 필드(`secondColor`, `nightFocusTime`, `previousNightFocusTime`, `FocusSlot.dayDate`, `dayPillar`)가 없거나 빈 배열(`dayVirtues`)이면 그 칸째 없이 그립니다. 열린 enum의 모르는 값은 그 항목만 건너뜁니다.
* **중복 표시는 그리는 단계에서 식별 키로 거릅니다.** 예: 한 칸에 같은 신살이 두 번 오면(`positions`로 펼친 결과) `(kind, 기둥)` 키로 한 번만, 덕일은 `kind`로 한 번만. 받은 데이터를 고치지 않습니다.
* **화면 판단은 app 몫입니다.** 계약이 정하지 않은 화면 배치, 상태 전이, 접근성 세부는 app이 정하고 `app/docs/decisions.md`에 A133부터 차례로 기록합니다(사용자 영향 칸 포함, 기존 행 형식).
* **다른 단위 몫이면 멈추고 보고합니다.** Issue 코멘트와 `to:` 라벨은 controller가 답니다. 보고서에 무엇이 누구 몫인지만 적습니다.
* ARB 문구는 손으로 쓰지 않고 원고에서만 가져옵니다(`dart run tool/import_writing_arb.dart` 뒤 `flutter gen-l10n`). 원고에 없는 문구가 필요하면 멈추고 보고합니다.
* 계약 값(크기, 색 토큰, 시간, 글자표)은 하드코딩하지 않고 생성 토큰(`lib/design/tokens/gen/tokens.g.dart`)과 기존 상수를 씁니다. 컴포넌트가 계약을 따른다는 대조는 `test/contract/component_contract_test.dart` 방식(spec 대조)으로 추가합니다. 계약 파일을 읽는 테스트는 `@Tags(['contract'])`.
* golden은 Docker `tool/goldens_linux.sh <테스트 파일>`로만 만듭니다(로컬 macOS golden 금지). 화면 스크린샷 문서(`docs/artifacts`)는 Task 7이 모읍니다.
* 리뷰 지적은 Minor도 같은 패스에서 고칩니다.
* 각 task 끝: `flutter analyze` 0건, 건드린 영역 테스트 통과, `flutter test --tags contract --exclude-tags golden` 결과를 보고(앞 task가 남긴 실패 수가 줄어야 하며 늘면 안 됨). commit 메시지 끝에:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01KrC1eUD8gYZBnEUBXGA4mg
  ```
* `dart fix`가 `pubspec.yaml`을 바꾸면 되돌립니다.

## Task 1: 생성 코드, fixture, 토큰과 글꼴, 열린 enum

계약: `server/api/openapi.yaml` 1.11.0(`Daily`, `DayVirtue`, `DayVirtueKind`, `DailyCards`, `FocusTimeCard`, `FocusSlot`, `ShinsalAt`, `ShinsalKind`, `CalendarDay`, `info.description`의 열린 enum 목록), `docs/identity/design/tokens/`(README 1.8.0, 1.9.0 행, `color.*.tokens.json`, `typography*.tokens.json`), `docs/identity/design/fonts/hanja-supplement/`(`manifest.json`, `OFL.txt`). 결정 D119, D122, D124 ①⑤, V115, V121. Issue #1018, #1032 design 코멘트(글꼴).

* 생성 도구를 모두 다시 돌려 commit에 넣습니다: `gen_ia.dart`, `gen_tokens.dart`, `import_writing_arb.dart`와 `flutter gen-l10n`, `gen_native_strings.dart`, `tool/gen_api.sh`. 위 "현재 상태"의 차이만 나와야 합니다.
* 열린 enum `DayVirtueKind`: `tool/mark_open_enums.dart`가 표시하는지 확인하고, `test/tool/open_enums_test.dart`의 개수와 `test/contract/open_enums_contract_test.dart`의 기대 목록(`day_virtue.dart:kind`, `calendar_day.dart:dayVirtues`)을 계약대로 맞춥니다. `ShinsalKind` 새 값 13개는 이미 열린 enum이라 표시만 확인합니다.
* 한자 대체 글꼴(V121, 토큰 1.9.0): `docs/identity/design/fonts/hanja-supplement/`의 굵기 넷을 앱 애셋으로 복사하고 `pubspec.yaml`과 `widgetbook/pubspec.yaml`에 family `Myungli Hanja Supplement`(굵기는 `manifest.json`)로 선언합니다(`test/contract/pubspec_fonts_test.dart` 유지). OFL 고지는 기존 Pretendard 글꼴 라이선스 등록 방식을 따릅니다. 새 계약 테스트: 생성 토큰의 모든 `fontFamilyFallback` 이름(sans-serif 제외)이 pubspec family에 있음.
* 토큰 대조: `color.time.day`, `color.time.night`를 기존 토큰 대조 테스트(라이트, 다크)에 넣습니다.
* fixture(`tool/validate_fixtures.py`와 `tool/test_validate_fixtures.py` 통과가 기준):
  * `positions`: `tool/gen_chart_fixtures.py`가 엔진 `hit.positions`를 옮기게 고치고 core/에서 다시 돌립니다(엔진이 2026.11.7 규칙이면 새 신살도 함께 나옴, 그 결과 신살 개수 변화와 원국 개인 해석 대역 문장 범위를 보고서에 적음). 엔진이 아직 positions를 내지 않으면 손으로 `[position]`을 넣고 보고합니다.
  * 달력 `dayVirtues`: `tool/gen_calendar_fixtures.py`도 같은 방식(엔진 덕일 판정, 없으면 빈 배열).
  * `getDaily.json` 전부: `dayVirtues`(member 오늘 2026-10-13은 엔진 판정 그대로), member에는 `nightFocusTime`, `previousNightFocusTime`과 `FocusSlot.dayDate`, `dayPillar`를 엔진 값으로 더합니다(문장은 writing `content/ko/daily.yaml`의 `focus_time.day`, `focus_time.night` 형식). `focusTime.picks`는 1개, `fallback` false(규칙 2026.11.4 이후, FocusTimeCard 설명).
  * 새 시나리오 하나(이름은 기존 `scenarios.json` 규칙, 예 `daily-pair-virtue`): `secondColor`가 있는 날(문장 `color.balance.*`, `color.source.*`)과 덕일 둘인 날(`day_virtue.cheondeok`, `day_virtue.woldeok`, 천덕일 먼저)을 한 응답에 담아 Task 3, 4의 흐름 테스트가 씁니다. 덕일 하나인 날 변주는 위젯 테스트에서 만듭니다. 잠긴 근거와 열린 근거는 기존 시나리오 짝(member, evidence-unlocked)과 같은 방식.
  * 사전 fixture(`getGlossary.json`, 대상 시나리오 전부): 새 신살 13개 이름, 오늘 태그 고신, 과숙, 원진 이름과 뜻은 writing ko 원고(`content/ko/glossary.yaml`, `term.yaml`) 값 그대로(A121, A130 ⑤ 기준).
* 화면은 고치지 않습니다. 이 task 뒤 전체 테스트 실패는 화면 task 몫(`repeat`, 글자표, 변형)만 남아야 하고, 남은 목록을 보고합니다.

## Task 2: 집중 시간 낮과 밤 칩 (D122, D123 ③④⑤, V115~V117, V118 일부)

계약: `today.json` `lucky-card`(`time`의 `periods`, `screens`, `row.order`, `explain.evidenceLink`, `timeBand`, `a11y.nightLabel`, `timeLabel`, `rules`), `today.md`, `share-image`(`rules` 시간은 낮 칩 하나), `elements.json` `icon.weights.timeOfDay`, `lengths.md`의 `today.lucky-time.*` 행, `openapi.yaml` `DailyCards` 설명(낮, 밤, 전날 밤 고르기와 07:30 경계, 지난 날짜), IA `today` 슬롯 `today.lucky-time.*`. 결정 D122, D123, V115~V118. Issue #1018.

* `time` 칩은 낮 `focusTime` 하나, 밤 하나(07:30 전 `previousNightFocusTime`, 그 뒤 `nightFocusTime`, 둘 다 없으면 밤 칩 없음). `repeat`와 `clock` 아이콘을 지우고 해, 달 Fill 아이콘(`color.time.day`, `color.time.night`). 밤 칩 때 낱말 `todayLuckyTimeNightDawn`/`Tonight`. 07:30 경계를 지나는 순간 칩과 띠가 바뀌도록 화면이 시각 변화를 구독합니다(기존 날짜 바뀜 처리 방식을 찾아 따름, 가짜 시계 테스트).
* 낮, 밤 칩은 각자 explain-sheet(제목 `todayLuckyTimeDayTitle`/`NightTitle`, 본문 그 카드 `text`), 본문 아래 `timeBand`(새 컴포넌트, 계약 `timeBand`의 칸, 머리, 고리, 지금 줄, 눈금, 날 낱말 `todayLuckyTimeBand*`, 칸 이름 ko와 ja는 기존 시진 이름 ARB `branch*`, en은 지지 한자 `font.family.hanja`), 맨 끝 근거 진입점(`depth-link` `block`, 근거는 그 카드 `text`의 근거, 잠금은 `evidenceAccess`).
* `formatFocusRange`와 `luckyItemsOf`를 `periods` 기준으로 고치고 `today_presentation_test`의 V52 `repeat` 대조를 `periods` 대조로 바꿉니다.
* 공유 이미지: 시간은 낮 칩 하나(V116).
* a11y: 낮은 제목 + 값, 밤은 제목 + 때 낱말 + 값, 해와 달은 읽지 않음, 띠는 그림으로 숨김.
* 계약 대조(`time.periods`, `timeBand` 숫자 값, `icon.weights.timeOfDay`), 위젯 테스트(07:30 앞뒤, 밤 카드 없음, 지난 날짜 화면이 있으면 그날 밤 고정), 흐름 테스트(`today_flow`).

## Task 3: 행운 색 둘인 날 (D119 ②③④, D123 ①②, V114, V118, #983)

계약: `today.json` `lucky-card` `color.pair`, `colorPairSheet`, `explain.evidenceLink`, `a11y.pairLabel`, `share-image`(첫째 색 하나), `lengths.md` `today.lucky-color.pair.intro`, `openapi.yaml` `DailyCards` 설명(`color`, `secondColor`, 문장 키와 근거), IA 슬롯 `today.lucky-color.*`. 결정 D119, D123, V114, V118. Issue #983, #1018.

* `secondColor`가 있으면 색 칩 하나를 두 칸 알약(세로선, 칸마다 누름 자리 44, 이름표 없음, 열림 테두리는 알약 전체). 어느 칸이든 같은 `colorPairSheet`: 맨 위 `todayLuckyColorPairIntro`, 색마다 견본과 이름, 그 카드 `text`, 그 색의 근거 진입점, 사이 구분선. 기준 이름 부제목을 두지 않습니다(D123 ①).
* 색이 하나인 날 행운 색 시트에도 본문 아래 근거 진입점(V118). 방향, 숫자 시트에는 없음.
* 숫자는 server가 첫째 색 기준으로 계산해 주므로 app 변경 없음을 확인만 합니다(D119 ③).
* 공유 이미지는 첫째 색 하나(D119 ④).
* a11y: 칸마다 항목 이름 + 값 + 두 개 중 몇째(계약 `pairLabel`, 문구가 ARB에 없으면 멈추고 보고).
* 계약 대조(`pair` 숫자 값, `colorPairSheet` 구조), 위젯 테스트(하나인 날, 둘인 날, 근거 잠김과 열림), 흐름 테스트(Task 1의 새 시나리오).

## Task 4: 덕일과 `hanja-tag` `compact` (D124 ⑤⑥, V119, #1032 ①)

계약: `sentence.json` `hanja-tag`(변형 `compact`, `glyphs.virtueDay`, `tone.toneAllowedIn`, `a11y.hitSlop`, `rules`), `today.json` `date-header`(`parts.virtue`, `meta.order`, `states.loading`, `a11y.virtueLabel`, `rules`), `lengths.md` `today.date.virtue`, `openapi.yaml` `Daily.dayVirtues`, `DayVirtue`, `DayVirtueKind`, `CalendarDay.dayVirtues`, IA `today` 슬롯 `today.date.virtue`와 출구 `explain-sheet`(덕일 trigger). 결정 D124 ⑤⑥, V70 개정, V119. Issue #1032, #1018.

* `hanja-tag` 변형 `compact`(알약, 한자 원, 이름 글자, hitSlop 44). 글자표 대조를 계약 21자로 맞춥니다(A112 대조 테스트, 德 추가와 孤 寡 元은 Task 5가 쓰지만 표는 여기서 한 번에).
* `date-header` `today`: meta 줄 일진 뒤 덕마다 알약 하나(`verdictTone.good`, 德, 이름 `todayDateVirtueCheondeok`/`Woldeok`, 응답 순서, `kind`로 중복 거름), 모르는 `kind`는 건너뜀, 빈 배열이면 칸째 없음, 뼈 없음. 그날 시트 머리(`day-sheet` 변형)에는 두지 않습니다(`virtue.visible: false`). `CalendarDay.dayVirtues`는 지금 그리는 곳이 없어 받기만 합니다.
* 알약을 누르면 explain-sheet: 제목은 알약 이름, 본문은 `DayVirtue.text`, 근거는 다른 문장과 같이 `evidenceAccess`. 원국 천덕귀인, 월덕귀인 풀이와 섞이지 않게 별도 주제로 엽니다.
* a11y: 머리 덩어리 뒤 따로 초점 가는 버튼, 이름은 알약 글자.
* 계약 대조(`compact` 숫자 값, 21자, `toneAllowedIn`), 위젯 테스트(없음, 하나, 둘, 모르는 kind), 흐름 테스트(덕일 → 풀이 시트 → 근거), IA 커버리지(`today>explain-sheet` 덕일 출구) 유지.

## Task 5: 신살 확장 (D124 ①②③⑦, V120, V121, #1032 ②③④)

계약: `saju.json` `band-table` 신살 칸(`column`, `order`, `orderWithin`, `overflow`, `stemMark`, `rules`), `saju.md`, `sentence.json` `hanja-tag` `glyphs.sinsal`(孤 寡 元), `frame.json` explain-sheet `weighingNote`, `lengths.md` `ui.shinsal.weighing`, writing `slots/ui/saju.yaml` `ui.shinsal.weighing`(키 `shinsalWeighingNote`), `openapi.yaml` `ShinsalAt`(대표 `position`과 `positions`), `ShinsalKind`, `PersonalReading`(개인 해석은 (`shinsal`, `position`)으로 찾음). 결정 D124, V120, V121. Issue #1032, #1018.

* 만세력 신살 띠: `positions`의 기둥마다 칸에 하나(천간 자리도 그 기둥, 일주 신살은 일주 칸 하나, 삼기는 세 칸), 칸 안 순서는 천간 자리 → 일주 신살 → 지지 자리, 무리 안은 계약 `ShinsalKind` 열거 순서, 모두 쌓음(자르지 않음, 띠는 가장 높은 칸만큼). 같은 칸 같은 신살은 `(kind, 기둥)`으로 한 번만. 칩을 누르면 원국 개인 해석은 대표 `position`으로 찾습니다.
* 원국 개인 해석 목록(나의 사주): 새 신살 13개가 기존 목록 규칙대로 나오는지, 이름은 사전에서, 사전에 없으면 기존 A112 건너뛰기.
* 오늘 태그 고신, 과숙, 원진: 글자표 孤 寡 元으로 사주 기운 섹션, 일기 줄 태그, 태그 모아보기, 그날 시트에서 그려지고 태그 시트가 열리는지.
* 흉 신살 마무리 한 줄 `weighingNote`: 계약 `when`의 흉 신살 목록(공망, 고신, 과숙, 원진, 구교)의 explain-sheet와 tag-sheet 뜻 바로 아래(체크 아이콘, `fill.soft` 상자, 두 줄, 누를 수 없음). 근거 시트와 원국 개인 해석에는 두지 않습니다. 목록은 계약 `when`에서 읽어 한곳에 두고, 계약 대조 테스트로 묶습니다.
* 한자 대체 글꼴: 괴강 魁罡이 `term-token`과 근거 원전에서 대체 글꼴로 그려지는지 golden 한 장(Task 7에서 재생성)으로 확인합니다.
* 계약 대조(`band-table` 신살 칸 규칙, `weighingNote` 값), 위젯 테스트(한 칸 다섯 개 이상, 삼기, 일주 신살, 중복 거름), 흐름 테스트(`saju_chart_flow`, `my_saju_flow`, 태그 시트).

## Task 6: 컴포넌트 7.3.0 문구와 `settings-row` `readonly` (V122, IA PR #1049), D125 확인

계약: `action.json` `settings-row` 변형 `readonly`, `action.md`, IA `preview`(components에 `settings-row`), `interaction.json` `tab.switch` `interrupt`, `scope`, `diary.json` `guide.remove.visibleWhen`, `calendar.json` `fortune-verdict` `toggle.label.collapsed`, writing `slots/ui/diary.yaml`(`diaryEditGuideAttachHint`). 결정 V122, D117, D125. Issue #1018.

* `settings-row` `readonly`(이름 왼쪽 값 오른쪽, 꺾쇠와 눌림 없음, 값은 줄 절반까지이고 넘치면 값 쪽 줄바꿈 오른쪽 맞춤, 스크린리더는 이름 다음 값). 미리보기를 이미 쓴 기기의 입력 정보 목록(`preview_screen.dart`, `previewUsedInput*`)을 이 변형으로 바꿉니다.
* 문구만 바뀐 셋(`tab.switch` A122, `guide.remove` A123, `fortune-verdict` 내역 보기 개수 없음)은 app이 이미 이대로인지 확인하고, 계약 대조 테스트가 새 문구 기준인지 봅니다. 어긋나면 고칩니다.
* `diaryEditGuideAttachHint`가 질문 뗀 자리 권유 줄의 스크린리더 hint로 연결됐는지 확인(#1013에서 했으면 그대로).
* D125(대표 태그는 길 먼저): app은 응답 순서대로 그리므로 변경 없음을 확인하고, fixture의 대표 태그 순서가 새 규칙과 어긋나면 보고만 합니다(fixture는 대역 값).
* 계약 대조, 위젯과 흐름 테스트(`onboarding`/`preview` 흐름), IA 커버리지.

## Task 6A: main 계약 따라잡기 (컴포넌트 7.4.0~7.6.0, IA v5 보충, 슬롯 v1.44, ruleset 2026.11.8)

main은 controller가 merge해 둠(merge commit). 계약: 컴포넌트 7.4.0(V123 빈 상태 둘), 7.5.0(V124 시간 띠 pick, `list.divider` `inSheet`), 7.6.0(V125 마무리 줄 대상), IA v5 보충(`ad-free` `empty`, `ad-free.unavailable.body`, explain-sheet 12운성 띠 진입점), writing W71~W74(슬롯 v1.44, ARB), core ruleset 2026.11.8(도화 태그 중립), 루트 D124 ⑦ 보충, D125 개정(도화 중립). 받은 확인 답 #922, #957, #1069, #1072, #1073, #1065, #1081, #1090, #1091.

* 생성 코드와 원고 다시 생성: `gen_tokens.dart`, `import_writing_arb.dart` + `flutter gen-l10n`, `gen_ia.dart`, `gen_native_strings.dart`, 사전 fixture(원고에서 생성). 생성 결과가 바뀐 이유를 보고합니다.
* 광고 제거 빈 상태(#922, V123, W71): `offer-card` `unavailable` 상태와 부품(가격, 기간 고지, 구매 버튼 대신 `adFreeUnavailableBody` 한 줄, `type.body.ui` `text.secondary`, 위 `space.16`, 2줄까지, 아이콘 없음, 누르지 않음). 카드, 아이콘, 주는 것 한 줄, 구매 내역, 약관 안내는 그대로. 이용 중이면 `active`가 먼저. 스크린리더는 주는 것 한 줄 + 안내. A126에서 둔 임시 구현(그 값에 기대는 부분만 그리지 않음)을 이 상태로 바꿉니다.
* 빈 풀이 시트(#957, V123, W71): `term-token` 풀이 시트 `emptyNote`. 뜻과 오늘 이유가 모두 없고 근거 출처도 없을 때만 제목과 한자 아래 `explainSheetTermEmpty`(위 `space.12`, 2줄까지), 근거 진입점은 그리지 않음. 출처만 있으면 지금처럼 근거 시트를 바로 엶(A130). 칩 모양과 누름은 같음. A130 판단 자리(`DepthSheets.openExplain`) 하나에서 갈립니다.
* 12운성 띠 진입점(IA 보충, design V91): 12단계 띠는 만세력 띠 머리의 "12운성" 칩으로 열 때만, 값 칩(목욕 등)의 뜻 시트에는 두지 않음. app이 이미 이대로인지 확인하고 어긋나면 고칩니다(#957 나머지).
* 시간 띠 pick(#1072, V124): 고리를 칸 안쪽에(`placement` `inside`), 연 칩 시진 `opened`(primary 2px, 틈 2px `bg.sheet`, 글자 700), 다른 칩 시진 `other`(`text.secondary` 1px). 옛 `pick.*` 대조 테스트를 새 구조로.
* `list.divider` `inSheet`(V124): 시트 본문에 바로 놓인 목록과 구역(행운 색 둘 시트 두 색 사이, 사주 기운 시트 문장 목록)은 들임 0. Task 3의 A135 임시 들임 0을 계약 값으로 바꾸고 대조 테스트를 더합니다.
* 행운 색 두 칸 알약 칸 순서(#1073, W73): `todayLuckyPairPosition({index},{total})`를 칸마다 이름과 값 뒤에. A135 임시(이름과 값만)를 바꿉니다.
* 간지 독음(#1069, W72): glossary `stem_reading`, `branch_reading`(ARB `stemReading*`, `branchReading*`)과 틀 `ganjiReading`, `ganjiReadingSuffix`. date-header 일진, date-block 일진, saju-pillars, luck-pillar, manse-table에서 한자 뒤 괄호 독음과 스크린리더 독음. A133 `GanjiReading`의 null(한자만)을 이 값으로 채웁니다. 한자는 틀에 넣지 않고 한자 글꼴로 따로 그립니다. en 앞 한 칸, ja 전각 괄호는 틀이 가짐.
* 마무리 줄 대상(D124 ⑦, V125, W74): `weighingShinsal`을 design 계약 목록(열하나: 고신, 과숙, 원진, 구교, 천라지망, 십악대패, 음착양차, 도화, 공망, 양인, 괴강)으로. 계약 대조 테스트가 새 `when` 문장 기준인지. 화개, 길 신살은 붙지 않음을 단언.
* 도화 중립(D125 개정, ruleset 2026.11.8): app이 길흉으로 색이나 순서를 정하는 곳이 있는지 확인하고, fixture는 엔진 값 그대로 다시 받습니다(대역 값을 손으로 고르지 않음).
* A133, A135, A137의 "확인 필요" 문장을 닫고, 새 판단이 있으면 A138 다음 번호로 행을 더합니다.
* 계약 대조, 위젯과 흐름 테스트, IA 커버리지, check-arb, fixture 검사.

## Task 6B: REST 1.12.0 집중 시간 시진 경계 (#1064, server PR #1084)

server PR #1084 병합됨(main에 있음, Task 6A 전에 controller가 merge함). 계약: REST 1.12.0 `FocusTime.hours`(5~7개, 시간 순, 時破 포함), openapi 설명(전환 시각은 프로필 현재 시간대 그날 진시 시작 `focusTime.hours[0].start`, `hours` 없는 응답은 한국 시각 07:30), D122 ⑦.

* `gen_api.sh`로 생성 코드 갱신, fixture는 server 시드나 엔진 값 그대로.
* 밤 칩 전환: Task 2의 `isBeforeDayStart`(07:30 한 곳, `_dayStart`)를 그날 낮 카드 `hours[0].start` 기준으로. `hours`가 없거나 비면 07:30(한국 시각) 대체. 비교는 응답 시각의 오프셋 그대로(기기 시간대로 바꾸지 않음).
* 24시간 띠: 보이는 밤 카드의 `hours`와 그날 낮 카드의 `hours`로 그립니다. 지금 띠 칸을 고정 시진표로 그리면 응답 값으로 바꾸고, `hours`가 없으면 지금 방식 유지(빈 값은 오류 아님).
* A134의 07:30 임시 판단을 닫고 결정 행을 고칩니다.
* 시각 경계 테스트(진시 시작 직전과 직후, 서울 외 시간대 응답, `hours` 없음), 흐름 테스트, 계약 대조.

## Task 7: 마무리

* `tool/goldens_linux.sh`로 전체 golden 재생성과 확인. 새 사례가 golden에 있는지 봅니다: `hanja-tag` `compact`, 덕일 `date-header`, 행운 색 두 칸 알약, 두 색 시트, `TimeBand`(연 칩과 다른 칩 고리), `sentence_hanja_supplement`(원전 罡 대체 글꼴), `settings-row` `readonly`, `offer-card` `unavailable`. 없는 사례는 더합니다.
* 바뀐 화면 스크린샷(`tool/screens_linux.sh`) 갱신: 오늘(날짜 머리 덕일과 일진 독음), 행운 색 둘(칩과 두 색 시트), 시간 시트(낮, 밤, 띠 고리), 만세력 신살 띠와 기준 줄 일간 표기, 신살 풀이 시트 마무리 상자(괴강 등 새 대상), 빈 풀이 시트, 일기 쓰기 날짜 블록 일진 독음, 미리보기 사용함(readonly 목록), 광고 제거 상품 없음(`ad-free` `empty`). 스크린샷 사례가 없으면 등록합니다.
* `flutter analyze`, `dart analyze`, `flutter test --exclude-tags golden`, 계약 테스트, `mlw check-arb`, fixture 검사, `dart run tool/ia_coverage.dart --check`, widgetbook analyze와 test, 생성 코드 차이 없음(CI "생성 코드 차이 확인" 단계와 같은 명령, `gen_api.sh` 포함), `dart format --set-exit-if-changed .`.
* Patrol: 바뀐 흐름(`today_test`, `calendar_test`, `onboarding_test`, `me_test`, `diary_test`, 광고 제거 화면이 든 흐름)을 `PATROL_AVD=Medium_Phone tool/patrol_local.sh`로.
* `app/CLAUDE.md` 현재 상태 맨 위에 이 PR 항목을 둡니다. 이 PR은 버그 묶음 `app/bugs-review2`(draft PR #1057, A126~A132)를 아래에 품으므로 두 묶음을 한 항목으로 정리합니다(결정 A126~A140, 함께 닫는 #922, #924, #931, #936, #957, #1013, #983, #1032, drift #1018). 기존 "검수 회차2 버그 묶음" 항목은 이 항목으로 합칩니다. 답을 기다리는 것: writing #1095(만세력 기준 줄 일간 표기), design #1063 문구 보충(밤 칩 전환 "07:30"을 진시 시작으로). 다음 할 일 0번을 갱신합니다.

## 확인 필요

1. **밤 칩 07:30 경계의 시간대.** design `today.json`(V116)은 "프로필 시간대 07:30", `openapi.yaml` `DailyCards` 설명은 "진시 시작, 한국 시각 07:30 전"입니다. 프로필 시간대가 한국이 아닌 사용자(D29)에서 두 기준이 갈립니다. server가 `previousNightFocusTime`을 "프로필 현재 시간대의 오늘"에만 주므로 app은 프로필 시간대 07:30으로 구현하고, 어긋남은 root, design, server 확인 몫으로 보고합니다.
2. **`timeBand` 칸 이름 원천.** 계약은 "ko, ja는 writing 시진 이름 한 글자"라고만 합니다. 기존 ARB `branch*`(온보딩 시진 이름)가 그 원고인지 Task 2에서 확인하고, 다르면 writing 몫으로 보고합니다.
3. **`pairLabel`의 "두 개 중 몇째".** 계약 a11y 문구에 맞는 ARB 키가 원고에 없으면 writing 몫(원고 요청)이고 그 전까지 Task 3의 해당 부분을 멈춥니다.
4. **`weighingNote` 대상 목록.** writing 슬롯은 "어느 신살에 붙일지는 app이 정합니다", design `frame.json`은 다섯(공망, 고신, 과숙, 원진, 구교)을 정합니다. design 목록을 따르고 A 결정으로 남깁니다. 앞으로 흉 신살이 늘 때 누가 목록을 갱신하는지는 root 확인 몫으로 보고합니다.
5. **fixture 엔진 값.** 이 worktree의 core 엔진이 규칙 2026.11.7(positions, 덕일, 밤 카드)을 내는지 Task 1에서 확인합니다. 내지 않으면 손으로 넣은 값임을 fixture 생성기 설명과 보고서에 적습니다.
6. **원국 개인 해석 대역 문장.** 새 신살 13개의 개인 해석 대역 문장은 writing `content/ko/personal.yaml` 형식을 따릅니다. 원고가 없는 키는 server처럼 빼고(DayVirtue 설명의 "원고가 없는 항목은 빠집니다"와 같은 원칙), 그 사실만 보고합니다.

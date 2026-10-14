# IA 슬롯 정렬과 ui 슬롯 설계

* 날짜: 2026-10-13
* 다루는 요청: #15(IA 슬롯 목록), #27(광고 제거권), #42(V2 문구 자리), #52(잠금 ui 슬롯, 개인 해석 원고는 W1), #69(호칭 없는 미리보기·아침 알림), #90·#94(ui 키 이름, 확인 창·용신 근거 이름), #116(Apple 로그인 복귀 안내), #54(글자 수 상한 반영)
* 근거: IA 계약 v1 `docs/ia/screens.json`(슬롯 124개: ui 91, content 33), D36·D50·D59·D60·D62·D66, design V27·V28(`lengths.md`, `sentence.md` 문장 조각), app A7(spec §6.4)

## 1. 목표

1. writing 슬롯 명세가 IA 슬롯 124개를 빠짐없이 담고, 검사기가 이를 지킵니다.
2. ui 슬롯 91개의 명세와 3개 언어 원고를 쓰고, app이 그대로 가져갈 ARB를 생성합니다.
3. content 33자리를 기존 슬롯과 새 슬롯에 대응합니다. writing 혼자 못 채우는 자리는 슬롯 틀을 두고 상대에게 요청합니다.
4. 호칭이 없는 화면(미리보기, 아침 알림)의 규칙, 용어 토큰의 고정 id, 글자 수 상한을 정합니다.

바꾸지 않는 것: 기존 슬롯 id와 메시지 키, content 원고 형식, server 시드의 `(message_key, variant)` 저장 방식.

## 2. 슬롯 명세 v1.1 (추가 필드)

| 필드 | 타입 | 뜻 |
| --- | --- | --- |
| `ia` | `list[string]` | 이 슬롯의 문장이 들어가는 IA 슬롯 id. 여러 개일 수 있습니다 |
| `components` | `list[string]` | IA 슬롯이 아니라 컴포넌트 안에 들어가는 이름의 자리(IA 컴포넌트 id). 예 `tag-chip`, `day-cell` |
| `select` | `string` | 렌더하는 쪽이 키를 고르는 방법. core 메시지 키가 아닌 writing 식별자 키를 쓰는 content 슬롯에 적습니다. 예: "`DailyResponse.day_kind` 값 v → 키 `character.reason.<v>`" |
| `vocative` | `bool` | 호칭 자리(D36). `true`인 슬롯만 `{name}`을 씁니다(§5) |

* 매개변수 값 종류에 `text`를 더합니다. 렌더하는 쪽이 만든 문자열(날짜, 시각, 가격, 일정 제목)을 그대로 넣습니다. 범주를 붙일 수 없고 글자 수 계산에서는 값을 모르는 자리로 봅니다.
* ui 슬롯
  * **id는 IA 슬롯 id 그대로**입니다. `ia`는 적지 않아도 그 자리에 놓인 것으로 봅니다. IA 밖 공용 문구(`ui.depth.*`)는 `components`로 자리를 적습니다.
  * **키 이름(#90):** `lowerCamelCase(IA id)` 그대로이거나 그 뒤에 접미사 하나를 붙입니다. 하이픈과 점은 단어 경계입니다(`evidence-sheet.lock.cta` → `evidenceSheetLockCta`).
    * 변주가 여럿이면 숫자 접미사를 붙입니다(`…1`, `…2`).
    * 한 자리에 상태가 여럿이면 대문자로 시작하는 상태 이름을 붙입니다. 예: `diaryEditDraftStatusSaving`, `sharePreviewRatioLabelStory`.
    * `ui.*`는 지금 이름 그대로입니다(`depthDefaultLabel`).

## 3. 검사기 규칙 (v0.2.0)

`mlw check`가 `docs/ia/screens.json`을 읽습니다(`--ia`로 경로 변경).

| 규칙 | 내용 | 등급 |
| --- | --- | --- |
| `ia.unknown` | `ia`·`components`·ui 슬롯 id가 IA에 없음 | error |
| `ia.source` | `slots/content/` 슬롯이 ui IA 슬롯을 담거나, 그 반대 | error |
| `ia.uncovered` | 어떤 writing 슬롯에도 담기지 않은 IA 슬롯(ui·content 모두) | error |
| `ia.unplaced` | 자리가 없는 슬롯: content는 `ia`·`components`가 모두 없음, ui는 IA id가 아니면서 `components`가 없음 | error |
| `ia.key_name` | ui 키가 §2 이름 규칙과 다름 | error |
| `slot.empty_keys` | 키가 하나도 없는 슬롯(상대 자료를 기다리는 틀, §4.3) | warn |
| `name.position` | `{name}`이 `vocative: true`가 아닌 슬롯에 있거나, 문장 맨 앞의 호칭 덩어리(§5)가 아님 | error |
| `ui.markup` | ui 원고에 `{name}`, 조사 표기, 용어 토큰이 있음(ARB는 조사·토큰을 렌더하지 않음) | error |
| `token.term` | 용어 토큰을 용어 id로 풀 수 없음(§6) | error |

* 생성 문서
  * `slot-catalog.md`에 "자리" 열(`ia`·`components`)을 더합니다.
  * 새 `ia-coverage.md`: IA 124자리마다 source와 담는 writing 슬롯을 보입니다.
  * 새 `arb/app_{ko,en,ja}.arb`: ui 원고에서 만듭니다(§4.1).
* `gen-docs --check`가 위 문서들이 최신인지 확인합니다.
* ui 슬롯도 원고 검사(완결성, 문장 규칙)를 받습니다. 하루·한 주 묶음 검사는 지금처럼 content만 봅니다.

## 4. 슬롯 대응

### 4.1 ui 91자리

* 화면 묶음별 파일 `slots/ui/`: `onboarding.yaml`, `today.yaml`, `sheets.yaml`, `diary.yaml`, `saju.yaml`, `settings.yaml`, `ad-free.yaml`, 기존 `depth.yaml`
* 원고 파일: `content/<lang>/ui.yaml`. 형식은 content 원고와 같습니다(`slot`, `key`, `text`).
* **ARB 생성:** `mlw gen-docs`가 `generated/arb/app_<lang>.arb`를 씁니다.
  * `@<키>.description`에는 IA id와 역할을 넣습니다.
  * `placeholders`는 매개변수 값 종류로 정합니다(`text` → `String`, `number` → `int`).
  * ICU plural·select는 쓰지 않습니다. 개수는 단복수가 갈리지 않게 문장을 짭니다(en "Events today: 3").
  * app은 이 파일을 `app/`의 ARB로 가져갑니다(D59 ⑤, 저장·렌더는 app). app 공지 Issue로 알립니다.
* 같은 자리의 상태 변형(#42) 키
  * `today.event.summary`: 기본(개수 + 첫 일정), `Ongoing`, `Next`, `Done`
  * `diary-edit.draft.status`: `Local`, `Saving`, `Saved`
  * `diary-edit.saved.tags`: 붙은 태그 알림
  * `share-preview.ratio.label`: `Story`, `Feed`, `Square`
  * 여러 항목이 있는 자리(동의 항목 등)도 같은 방식으로 상태 이름을 붙입니다. 정확한 목록은 IA spec 화면 설명을 따릅니다.
* 역할이 바뀐 자리: `ad-free.offer.head`는 "배너 제거 + 근거·해석 열림"을 한 줄로 전합니다(#52).
* `settings.calculation_basis`(content)는 IA의 ui `calc-basis.longitude.body`와 같은 문구라 **ui로 옮기고 content 슬롯을 지웁니다**. core 키가 아니라 영향이 없습니다.
* **라운드 R8(n지선다):** 브랜드를 대표하거나 정책이 걸린 문구 6자리는 사용자가 고릅니다.
  * 고르는 자리: `welcome.concept.head`, `welcome.concept.body`, `notify-ask.why.body`, `evidence-sheet.lock.reward`, `ad-free.offer.head`, `share-preview.image.tagline`
  * 나머지는 가이드 규칙으로 쓰고 검사기로 확인합니다.
* en·ja 원고는 초안이며, 원어민 검수(W1)를 받기 전 상태임을 파일 머리 주석에 적습니다.

### 4.2 content 33자리

| IA 자리 | writing 슬롯 | 비고 |
| --- | --- | --- |
| `today`·`preview`·`day-sheet`·`diary-view` `.character.label` | `glossary.value_name` (`day_kind.*`) | 값 이름 |
| `today`·`preview` `.fortune.head`, `system-push.morning.body` | `daily.fortune.head` | 호칭 자리, 미리보기·알림은 호칭 생략(§5) |
| `today`·`preview` `.fortune.body` | `daily.fortune.tag` | 대표 태그가 있는 날만 |
| `today.lucky-color`·`-direction`·`-number`·`-time` `.body` | `daily.color`·`direction`·`number`·`focus_time` | 시간 사유 이름 `daily.focus_reason`은 `components: [lucky-card]` |
| `today`·`diary-edit` `.guide.question` | `daily.guide` | |
| `today`·`day-sheet` `.character.reason`, `event-edit.character.hint` | **새** `character.reason` | 키 `character.reason.<day_kind>` 4개, `select`는 날의 성격 |
| `explain-sheet.term.meaning`, `tag-diary.tag.meaning` | **새** `term.meaning` | 키 `term.<용어 id>`(§6) |
| `explain-sheet.today.reason` | **새** `explain.today_reason` | 키는 core 자료 뒤(§4.3) |
| `evidence-sheet.basis.body` | **새** `evidence.basis` | 같음 |
| `evidence-sheet.source.quote` | **새** `evidence.source` | 같음 |
| `evidence-sheet.personal.body` | `personal.*` 5개 | 원고는 W1 |
| `my-saju.ilgan.head` | **새** `chart.ilgan_head` | 키 `ilgan.head.<stem>` 10개, 호칭 자리 |
| `my-saju.ilgan.body` | **새** `chart.ilgan_body` | 키 `ilgan.body.<stem>` 10개 |
| `my-saju.yongsin.body` | **새** `chart.yongsin_summary` | 키 `yongsin.summary`, `{yongsin: [element, color]}` |
| `saju-chart.yongsin.basis` | `chart.yongsin_method` | |
| `onboard-time.hour.confirm` | **새** `onboard.hour_confirm` | 키 `hour.confirm`, `{branch: [branch], start: text, end: text}` |
| `system-apple-return.page.title`·`body`·`open`·`install` | **새** `system.apple_return` | 키 `apple_return.<부분>` 4개, 호칭 없음 |

* IA 밖에서 컴포넌트에 들어가는 이름
  * `daily.tag_label` → `tag-chip`
  * `calendar.day_level` → `day-character`, `day-cell`
  * `calendar.score_item` → `term-token`
  * `calendar.solar_term` → `day-cell`
  * `glossary.value_name` → `lucky-card`, `saju-pillars`, `manse-table`, `daeun-table`, `ohaeng-bar`
* 새 content 원고
  * 이번에 쓰는 것: server를 막는 `system.apple_return`(#116)과 `onboard.hour_confirm`(#42)의 3개 언어 원고
  * W1에 쓰는 것: 나머지 새 슬롯(`character.reason`, `term.meaning`, `ilgan`, `yongsin_summary`)

### 4.3 상대 자료를 기다리는 자리

`explain.today_reason`, `evidence.basis`, `evidence.source`는 엔진 `Evidence`(`rule_id`, `source_ref`, `detail`)로 문장을 고릅니다. `select`는 아래와 같습니다.
* `evidence.basis`: `rule_id` → 키 `basis.<rule_id>`
* `evidence.source`: `source_ref` → 키 `source.<source_ref>`
* `explain.today_reason`: 그 용어를 낸 판정의 `rule_id` → 키 `reason.<rule_id>`

writing은 쓸 수 있는 `rule_id`·`source_ref` 목록과 원전 원문을 모릅니다. 그래서 슬롯 틀만 키 없이 두고(`slot.empty_keys` warn), core에 목록 파일을 요청합니다. 요청할 목록은 `message_keys.json`처럼 내보내는 것으로, rule id 목록과 source_ref별 원문입니다. 목록이 오면 키를 채우고 `complete.unslotted_key`처럼 대조합니다.

## 5. 호칭 생략 (#69, 호칭·조사 규칙 v1.1)

* `{name}`은 `vocative: true` 슬롯(`daily.fortune.head`, `chart.ilgan_head`)에서만, **문장 맨 앞 호칭 덩어리**로만 씁니다.
  * ko: `{name}님, `
  * ja: `{name}さん、`
  * en: `{name}, `
* 렌더러는 호칭이 없을 때(미리보기 D50, 아침 알림 D62, 그 밖에 호칭을 모르는 경우) 이 덩어리를 통째로 지웁니다. en은 렌더가 끝난 최종 문장의 첫 글자를 대문자로 바꿉니다(지운 직후 원고에는 하지 않음).
* 그래서 아침 알림은 그날 `daily.fortune.head`의 같은 문장 틀을 호칭 없이 씁니다. 별도 슬롯이나 변주를 두지 않습니다.
* 검사기 `name.position`이 덩어리 모양과 위치를 지킵니다. 덩어리를 지운 문장도 문장 규칙과 글자 수 검사를 받습니다.

## 6. 용어 id (design V28 "term 값은 풀이를 찾는 키")

* **용어 id**는 glossary 키(`<범주>.<값>`)이거나 태그 이름 키(`tag.*`)입니다.
  * 용어 범주: `element`, `stem`, `branch`, `ten_god`, `ten_god_group`, `shinsal`, `day_kind`, `relation`, `role`, `luck`, `tag`
  * 모두 77개이고, `term.meaning`이 모두 담습니다(테스트로 확인).
* 토큰 표기 세 가지
  1. `[[{param}]]` / `[[{param:cat}]]`: 매개변수 값의 용어 id(`<범주>.<값>`). 범주는 용어 범주여야 합니다. `color`는 안 됩니다.
  2. `[[글자]]`: 같은 언어 glossary·태그 원고에서 그 글자를 이름으로 가진 용어 id 하나로 풉니다. 없거나 둘 이상이면 오류입니다. 예: ko "신"은 `stem.sin`과 `branch.shin` 둘이라 오류입니다. 그 언어의 glossary 원고가 아직 없으면 건너뜁니다.
  3. `[[글자|용어 id]]`: 2가 모호할 때 id를 직접 적습니다.
* server는 조각의 `term`에 **용어 id**를 넣습니다. 화면에 보이는 글자는 지금처럼 `text`입니다. 풀이 시트는 `term.<용어 id>` 문장을 엽니다.
* `calendar.score_item`의 용어 id 대응:
  * `gwiin_day`·`yongsin_day`·`gisin_day` → `day_kind.*`
  * `hap` → `relation.branch_hap`
  * `chung_*` → `relation.chung`
  * `hyeong` → `relation.hyeong`
  * 이 대응은 슬롯의 `select`에 적습니다.

## 7. 글자 수 상한 (#54)

* `lengths.md`의 확정값을 해당 슬롯 `max_length`에 넣습니다.
* `settings.calculation_basis` 값(120/120/216)은 ui `calc-basis.longitude.body`로 옮깁니다.
* **en 절기 줄임 표기(6자 이하):** 영어 절기 이름의 핵심 단어 하나를 씁니다.
  * 예: Grain Rain → `Grain`, Cold Dew → `Dew`
  * 핵심 단어가 겹치는 쌍(Start of Spring과 Spring Equinox 등)은 점 줄임으로 가릅니다. 예: `Spr.`, `Sp.Eq`
  * 24개 목록은 원고 `content/en/`의 `calendar.solar_term`에 둡니다.
  * 일본어는 절기 이름이 2~3자라 그대로 씁니다.
* 새 슬롯과 ui 91자리 중 이름 자리(버튼, 라벨, toast, 칩)의 값은 design에 요청합니다. 오기 전까지는 `null`입니다.
  * 문장 자리 가운데 이미 같은 칸이 있는 곳은 그 값을 씁니다. 예: `character.reason`은 `day-character` 한 줄이라 상한을 design에 함께 묻습니다.

## 8. 바깥에 알릴 것

| 받는 쪽 | 내용 | 방식 |
| --- | --- | --- |
| app | ARB 생성 위치와 키 접미사 규칙, ui 원고 첫 판(en·ja는 초안) | notice Issue, #90 닫음 |
| server | 호칭 덩어리 생략, `term` = 용어 id와 토큰 표기 3가지, `select` 필드, 새 content 슬롯(`apple_return`·`hour_confirm` 원고 포함) | request Issue(#55에 이어서) |
| core | `rule_id` 목록, `source_ref`별 원전 원문 내보내기 | request Issue |
| design | ui 이름 자리와 새 content 슬롯의 글자 수 상한 | request Issue |
| 지휘 | 계약 목록 갱신: 슬롯 명세 v1.1, 호칭·조사 규칙 v1.1, 검사기 v0.2.0 | PR 본문 |

## 9. Issue 처리

* 닫음: #15, #27, #42, #69, #90, #94, #116
* 참고: #52. 잠금 ui 슬롯은 이번에 처리합니다. 원국 개인 해석 원고는 W1입니다.

## 10. 테스트

* 검사기 규칙마다 통과·실패 예시 테스트를 둡니다(`ia.*`, `name.position`, `ui.markup`, `token.term`, `slot.empty_keys`).
* ARB 생성 결과는 고정 입력으로 정확히 비교합니다.
* 저장소 실제 자료 테스트
  * IA 124자리가 모두 담겼는지
  * ui 키가 모두 이름 규칙을 따르는지
  * `term.meaning` 키가 용어 id 77개와 같은지
* CI 단계는 그대로입니다. `mlw check --partial`과 `gen-docs --check`가 새 규칙을 함께 돌립니다.

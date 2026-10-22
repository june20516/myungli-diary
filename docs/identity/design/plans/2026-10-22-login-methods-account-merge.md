# 로그인 수단·계정 합치기 (컴포넌트 계약 2.7.0) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** D82·D83의 두 화면(`login-methods`·`account-merge`)을 위한 컴포넌트 명세 2.7.0을 채워 drift #395(`account-choice` 명세 없음)를 풀고, 글자 수 상한과 윤달 표지 슬롯을 더합니다.

**Architecture:** 명세는 `components/<묶음>.json`(사실) + `.md`(설명) 쌍이고, `tools/components.py`가 IA·토큰·패턴·MD를 대조합니다. 값별 고정은 `tools/test_components.py`의 테스트가 맡습니다. 글자 수 상한은 `tools/lengths.py`의 `TARGETS`로 재고 `lengths.md` 표와 같아야 합니다.

**Tech Stack:** Python 3(표준 라이브러리), pytest 8.3.5, fonttools 4.54.1(`uv run`), JSON 명세

**Spec:** `docs/identity/design/specs/2026-10-22-login-methods-account-merge-design.md`

## Global Constraints

* 저장소 루트에서 실행합니다. 테스트: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`. 측정 글꼴은 `.suberpowers/fonts`에 있습니다(없으면 `python3 docs/identity/design/tools/fonts.py --font-dir .suberpowers/fonts`).
* 고칠 수 있는 곳은 `docs/identity/design/` 아래와 `docs/contracts/README.md`의 "컴포넌트 명세" 행뿐입니다. IA·writing 파일은 읽기만 합니다.
* 명세 JSON에 Material 위젯 이름을 쓰지 않습니다. 색·간격·글자는 토큰 참조(`{color.bg.sheet}` 꼴, 값 하나에 참조 하나)입니다. 제공자 색(LINE·Google 가이드 값)만 hex 문자열입니다.
* 빨간색 없음(V18), 동작은 `radius.md`·고르기 표시는 `radius.full`(V26), 아이콘은 Phosphor(V15).
* 문서·커밋에 가격·수익 수치를 적지 않습니다(D74).
* 커밋 메시지 끝: `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>` 과 `Claude-Session: https://claude.ai/code/session_015UuApz6Ye5AAbvaZtRPFvh`.
* 기존 확정 글자 수 행(`EXISTING_ROWS`)과 기존 테스트는 그대로 통과해야 합니다.

## Review Focus

1. IA `login-methods`·`account-merge`에 새 ui 슬롯이 생겨도 글자 수 표에서 빠진 슬롯이 없어야 합니다(app-bar 제목 `*.bar.title` 제외). → Task 5 `test_d82_ia_slots_are_measured`
2. `account-choice`가 처음부터 한쪽을 골라 두면 안 됩니다(되돌릴 수 없는 합치기). → Task 1 `test_account_choice_starts_unselected`
3. 언어별 순서표가 네 변형을 모두 담고, ko·ja·en 맨 위가 D82 ①과 같아야 합니다. → Task 2 `test_social_login_order_per_language`
4. `connected` 상태가 제공자 색을 쓰거나 Google "G"를 흰 바탕 밖에 두면 가이드 위반입니다. → Task 2 `test_social_login_connected_is_neutral`
5. 겹치는 날 안내에 경고 표시가 붙으면 사용자 결정(안심 안내)과 어긋납니다. → Task 3 `test_account_merge_layout_keeps_emphasis_on_confirm`

---

### Task 1: `account-choice` 명세 (drift #395 해소)

**Files:**
- Modify: `docs/identity/design/components/input.json` (components 끝에 추가)
- Modify: `docs/identity/design/components/input.md` (`## check-row` 뒤에 절 추가)
- Test: `docs/identity/design/tools/test_components.py` (끝에 추가)

**Interfaces:**
- Produces: `input.json`의 컴포넌트 `account-choice`(Task 3이 MD에서 가리킴)

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# 로그인 수단·계정 합치기 (#389, D82·D83, 결정 V39~V41)


def test_account_choice_starts_unselected():
    choice = component("input", "account-choice")
    assert set(choice["states"]) == {"none", "selected", "pressed", "loading"}
    assert choice["states"]["selected"]["parts"]["card"]["border"] == {"color": "{color.action.primary}", "width": {"value": 2, "unit": "px"}}
    assert choice["states"]["loading"]["pattern"] == "loading.breathe"
    assert any("처음부터 어느 쪽도 골라 두지 않는다" in rule for rule in choice["rules"])
    assert choice["a11y"]["role"] == "radio-group" and choice["a11y"]["labelSlot"] == "account-merge.choice.label"
    assert choice["haptic"] == [{"when": "고름이 바뀜", "strength": "selection"}]


def test_account_choice_card_lines():
    parts = component("input", "account-choice")["parts"]
    assert parts["card"]["bg"] == "{color.bg.sheet}" and parts["card"]["radius"] == "{radius.md}"
    assert parts["current"]["radius"] == "{radius.full}" and parts["current"]["slot"] == "ui.account-merge.choice"
    assert parts["saju"]["slot"] == "ui.account-merge.saju"
    assert parts["providers"]["logo"] is False
    assert parts["mark"]["radius"] == "{radius.full}"
```

- [ ] **Step 2: 실패 확인**

Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_components.py -q -k account_choice`
Expected: FAIL (`StopIteration` — 컴포넌트 없음)

- [ ] **Step 3: `input.json`에 `account-choice` 추가**

spec §3 값 그대로. 필드: `id`, `summary`("합칠 두 계정 가운데 남길 쪽 고르기 (D82 ⑥)"), `uses`(`press.ink`, `select.seep-slide`, `appear.seep`, `loading.breathe`), `parts`, `states`, `haptic`, `a11y`, `rules`.
* `parts.group.gap` `{space.12}`; `parts.card`: `bg` `{color.bg.sheet}`, `radius` `{radius.md}`, `padding` `{space.16}`, `gap` `{space.8}`, `border` `{ "color": "transparent", "width": 2px }`.
* `parts.name`(`{type.subtitle}`, `{color.text.primary}`), `parts.current`(`{type.caption.sm}`, `{color.text.secondary}`, 테두리 `{color.line}` 1px, `radius` `{radius.full}`, `paddingX` `{space.8}`, `slot` `ui.account-merge.choice`, `key` `accountChoiceCurrent`, `onlyWhen` "현재 로그인한 계정").
* `parts.saju`(`{type.caption.lg}`, `{color.text.secondary}`, `numerals` "tabular", `slot` `ui.account-merge.saju`, `timeUnknown`·`noSaju` 설명 문자열).
* `parts.facts`(`gap` `{space.12}`), `parts.diaryCount`(`{type.caption.lg}`, `{color.text.primary}`, `key` `accountChoiceDiaryCount`), `parts.providers`(`{type.caption.lg}`, `{color.text.primary}`, `names` `ui.login-methods.row` `loginProvider*`, `logo: false`, `note` "Google G 단독 금지").
* `parts.mark`: 22px, 테두리 `{color.line}` 1.5px, `radius` `{radius.full}`, 위치 오른쪽 위 `{space.16}`.
* `states.none`(note: 합치기 버튼 disabled), `states.selected`(`pattern` `select.seep-slide`, note: 이동 없이 스밈, 처음 고를 때 `appear.seep`; `parts.card.border` 위 테스트 값; `parts.mark` 테두리 `{color.action.primary}` + `dot` 12px `{color.action.primary}`), `states.pressed`(`press.ink`), `states.loading`(`loading.breathe`, note: 카드 두 장 크기, 글줄 자리는 skeleton 모양, skeleton 컴포넌트를 쓰지 않음).
* `a11y`: `role` radio-group, `itemRole` radio, `labelSlot` `account-merge.choice.label`, `label` "카드 안 글자를 위에서 아래로", `minTarget` "card".
* `rules`: "처음부터 어느 쪽도 골라 두지 않는다. 되돌릴 수 없는 합치기라 남길 계정은 사용자가 직접 고른다.", "연결된 수단은 로고 없이 이름 글자로 보인다(Google 가이드: G 단독 금지).", "카드는 고르기 묶음의 항목이고, 고름 표시는 알약 동그라미다(V26)."

- [ ] **Step 4: `input.md`에 절 추가**

`## account-choice` 절: 첫 줄 `* 쓰는 화면: account-merge`, 이어 카드 구성·상태·a11y 요약(spec §3)과 결정 V40. 테스트 `test_md_used_on_matches_ia_components`가 이 줄을 읽습니다.

- [ ] **Step 5: 통과 확인**

Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_components.py -q -k "account_choice or committed or cli"` 와 `python3 docs/identity/design/tools/components.py`
Expected: 새 테스트 PASS, 검사기 출력에 `account-choice` 문제 없음(다른 MD 대조 실패는 Task 2·3에서 고침)

- [ ] **Step 6: Commit** — `feat(design): account-choice 명세 (#389, drift #395)`

---

### Task 2: `social-login-button` LINE·Google·`connected`·언어별 순서 (V39)

**Files:**
- Modify: `docs/identity/design/components/action.json` (`social-login-button`)
- Modify: `docs/identity/design/components/action.md` (`## social-login-button` 절)
- Test: `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Produces: 변형 id `kakao`·`line`·`google`·`apple`, 상태 id `connected`, `parts.stack.order`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_social_login_order_per_language():
    button = component("action", "social-login-button")
    assert [v["id"] for v in button["variants"]] == ["kakao", "line", "google", "apple"]
    assert button["parts"]["stack"]["order"] == {"base": ["kakao", "line", "google", "apple"],
                                                 "top": {"ko": "kakao", "ja": "line", "en": "google"}}
    assert not any("카카오 위, Apple 아래" in rule for rule in button["rules"])


def test_social_login_provider_guides():
    variants = {v["id"]: v for v in component("action", "social-login-button")["variants"]}
    line = variants["line"]["parts"]
    assert line["container"]["bg"] == "#06C755" and line["label"]["fg"] == "#FFFFFF"
    assert line["pressed"]["overlay"] == {"color": "#000000", "opacity": 0.3}
    google = variants["google"]["parts"]
    assert google["container"]["lightMode"] == {"bg": "#FFFFFF", "border": "#747775", "fg": "#1F1F1F"}
    assert google["container"]["darkMode"] == {"bg": "#131314", "border": "#8E918F", "fg": "#E3E3E3"}
    assert google["label"]["fontFamily"] == "Google Sans Medium"


def test_social_login_connected_is_neutral():
    connected = component("action", "social-login-button")["states"]["connected"]
    parts = connected["parts"]
    assert parts["container"]["bg"] == "{color.bg.sheet}"
    assert parts["container"]["border"] == {"color": "{color.line}", "width": {"value": 1, "unit": "px"}}
    assert parts["state"]["fg"] == "{color.action.primary}" and parts["state"]["icon"] == "check"
    assert parts["logo"]["googleBackdrop"] == "white-circle"
    assert connected["lastOne"]["pressable"] is False and connected["lastOne"]["noticeSlot"] == "login-methods.last.notice"
    assert connected["onPress"] == {"component": "dialog", "variant": "destructive", "slot": "login-methods.unlink.confirm"}
```

- [ ] **Step 2: 실패 확인** — Run: `... pytest docs/identity/design/tools/test_components.py -q -k social_login` / Expected: FAIL (변형 2개, 키 없음)

- [ ] **Step 3: `action.json` 고치기**

* `summary`: "소셜 로그인 버튼: 카카오·LINE·Google·Apple (D82)".
* `kakao`·`apple`의 `when`에서 "(위)"·"(아래)"를 지움. `line`(style `line-login-button-guidelines`, 위 테스트 값, `disabled` 가이드 값: `bg` "#FFFFFF", `border` {"color": "#E5E5E5", "opacity": 0.6}, `fg` {"color": "#1E1E1E", "opacity": 0.2}), `google`(style `google-sign-in-branding`, 위 테스트 값, `label.fontFamily` "Google Sans Medium", `label.size` 14, `label.lineHeight` 20)을 `kakao`와 `apple` 사이에 넣음.
* `parts.stack.order`(테스트 값), `parts.logo.inset` `{space.16}`, `parts.label.align` "center".
* `states.connected`: `parts.container`(`bg`·`border` 테스트 값), `parts.name`(`{type.label.lg}`, `{color.text.primary}`, `key` `loginProvider*`), `parts.state`(`icon` "check", `weight` "regular", `size` 14px, `label` `{type.caption.lg}`, `fg` `{color.action.primary}`, `slot` `ui.login-methods.row`, `note` "연결됨 키는 writing에 요청"), `parts.logo.googleBackdrop` "white-circle", `onPress`(테스트 값), `lastOne`(`pressable` false, `noticeSlot` `login-methods.last.notice`, `notice` 글자 `{type.caption.lg}`·`{color.text.secondary}`·위 `{space.12}`), `a11y`(`label` "제공자 이름, 연결됨", `hint` `loginMethodsRowUnlink`, 마지막 하나는 hint 없음), `note` "로그인 동작이 아니라 연결 상태 줄이라 제공자 색을 쓰지 않음(V39)".
* `states.loading`에 note "누른 버튼만. 나머지(연결됨 포함)는 disabled".
* `rules`: 기존 "순서는 카카오 위, Apple 아래…" 규칙을 "네 버튼은 같은 크기·같은 무게다(D82 ①, App Store 4.8, Google 가이드). 순서는 parts.stack.order: 언어마다 맨 위만 다르다."로 바꾸고, "connected는 login-methods에서만 쓴다." 추가.

- [ ] **Step 4: `action.md` 절 고치기**

`* 쓰는 화면: login, login-methods`. 변형 넷과 가이드 출처, 언어별 순서표(spec §2.2 표), `connected`, 그리고 **`login-methods` 화면 배치**(spec §4.1: intro → 버튼 넷 → 하나 남으면 last.notice, 오류는 `dialog` `notice`, 다른 계정에 있으면 account-merge로). 결정 V39.

- [ ] **Step 5: `settings-row`의 IA 차이를 예외로 둠**

`test_md_used_on_matches_ia_components` 위에 상수를 두고, 대조 전에 IA 쪽 집합에서 뺌:

```python
# IA 보완 요청 중인 쓰는 화면 차이 (컴포넌트 → 화면). 지휘가 IA를 고치면 지움
USED_ON_EXCEPTIONS = {"settings-row": {"login-methods"}}  # 시안 B(V39)로 social-login-button connected를 씀, spec §7.1
```

`assert listed == used[component_id] - USED_ON_EXCEPTIONS.get(component_id, set()), (name, component_id)`. `settings-row`의 MD 줄은 그대로(settings, profile-edit, legal).

- [ ] **Step 6: 통과 확인** — Run: `... pytest docs/identity/design/tools/test_components.py -q -k "social_login or used_on"` / Expected: PASS(`dialog`·`primary-button` MD 대조는 Task 3에서 고치므로 used_on이 그 둘로 실패하면 Task 3 뒤 확인)

- [ ] **Step 7: Commit** — `feat(design): social-login-button LINE·Google 변형, connected 상태, 언어별 순서 (#389, V39)`

---

### Task 3: `dialog` 첫 초점 규칙(V41)과 `account-merge` 배치(V40)

**Files:**
- Modify: `docs/identity/design/components/feedback.json` (`dialog`)
- Modify: `docs/identity/design/components/feedback.md` (`## dialog`)
- Modify: `docs/identity/design/components/action.md` (`## primary-button` 쓰는 화면 줄)
- Modify: `docs/identity/design/components/input.md` (`## account-choice` 절에 화면 배치)
- Test: `docs/identity/design/tools/test_components.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_two_button_dialogs_have_no_first_focus():
    dialog = component("feedback", "dialog")
    variants = {v["id"]: v for v in dialog["variants"]}
    assert "focusOnOpen" not in dialog["a11y"]
    assert variants["destructive"]["a11y"] == {"dismissOnScrim": False, "backIs": "cancel"}
    assert variants["notice"]["a11y"] == {"focusOnOpen": "confirm", "dismissOnScrim": True}
    assert not any("처음 초점" in rule for rule in dialog["rules"])
    assert any("뒤로 가기는 취소" in rule and "V41" in rule for rule in dialog["rules"])
    assert "계정 합치기" in variants["destructive"]["when"] and "로그인 수단 떼기" in variants["destructive"]["when"]


def test_account_merge_layout_keeps_emphasis_on_confirm():
    input_md = (COMPONENTS_DIR / "input.md").read_text(encoding="utf-8")
    section = input_md.split("## account-choice", 1)[1]
    assert "`account-merge.overlap.notice`" in section and "`mark.caution`을 쓰지 않" in section
    assert "`account-merge.merge.confirm`" in section and "`destructive`" in section
    assert "`ui.account-merge.error`" in section and "`notice`" in section
```

- [ ] **Step 2: 실패 확인** — Run: `... -k "first_focus or account_merge_layout"` / Expected: FAIL

- [ ] **Step 3: `feedback.json` `dialog` 고치기**

* 기본 `a11y`에서 `focusOnOpen` 삭제. `destructive.a11y` = `{"dismissOnScrim": false, "backIs": "cancel"}`. `notice`는 그대로.
* `destructive.when`: "되돌릴 수 없는 동작(일기 삭제, 일정 삭제, 계정 삭제, 계정 합치기, 로그인 수단 떼기)". `notice.when`에 `login-methods.error.body`·`ui.account-merge.error` 추가.
* `rules`: "destructive 변형은 처음 초점과 기본 동작을 취소에 둔다." → "destructive 변형에서 뒤로 가기는 취소와 같다. 버튼 두 개짜리 확인 창에는 첫 초점 규칙을 두지 않는다(앱, V41)."

- [ ] **Step 4: MD 고치기**

* `feedback.md` `## dialog`: 쓰는 화면 줄에 `login-methods`, `account-merge` 추가(IA 순서와 무관, 집합 대조). 첫 초점 문장을 V41 문장으로 바꾸고 #354 ② 답(파괴적이지 않은 무거운 변경은 `confirm`, 첫 초점 옵션 없음)을 한 줄.
* `action.md` `## primary-button` 쓰는 화면 줄에 `account-merge` 추가.
* `input.md` `## account-choice` 끝에 **`account-merge` 화면 배치**: spec §4.2의 1~6 순서·토큰 그대로. 겹치는 날 안내 문장에 "`mark.caution`을 쓰지 않습니다"와 "바탕 상자 없음", 최종 확인 `dialog` `destructive`(`account-merge.merge.confirm`)가 유일한 강조, 실패는 `ui.account-merge.error`를 `dialog` `notice`로.

- [ ] **Step 5: 기존 테스트 정리**

`test_dialog_notice_has_one_button`은 그대로 통과해야 합니다. 첫 초점을 확인하던 다른 테스트가 있으면 V41에 맞춰 고칩니다(`grep -n focusOnOpen docs/identity/design/tools/test_components.py`).

- [ ] **Step 6: 통과 확인** — Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_components.py -q` 와 `python3 docs/identity/design/tools/components.py` / Expected: 버전 테스트를 뺀 전부 PASS, 검사기 "문제 없음"

- [ ] **Step 7: Commit** — `feat(design): 두 버튼 확인 창 첫 초점 삭제, 계정 합치기 배치 (#389, #354, V40·V41)`

---

### Task 4: 윤달 표지 슬롯 (#260, V38 마무리)

**Files:**
- Modify: `docs/identity/design/components/calendar.json` (`day-cell` `parts.lunar.leapNewMoon`)
- Modify: `docs/identity/design/components/calendar.md` (윤달 문장)
- Test: `docs/identity/design/tools/test_components.py` (`test_day_cell_leap_month_and_height_rule`)

- [ ] **Step 1: 테스트에 단언 추가**

```python
    assert cell["parts"]["lunar"]["leapNewMoon"] == {"slot": "ui.day-cell.lunar", "key": "dayCellLeapNewMoon",
                                                      "text": "윤달 표지 + M.1 (예: 윤6.1)"}
```

- [ ] **Step 2: 실패 확인** — Run: `... -k day_cell_leap` / Expected: FAIL

- [ ] **Step 3:** `leapNewMoon`을 위 값으로 바꾸고(“정해지기 전에는 M.1” note 삭제), `calendar.md`의 윤달 문장에 슬롯 `ui.day-cell.lunar`(`dayCellLeapNewMoon`, writing W33)를 적음.

- [ ] **Step 4: 통과 확인** — 같은 명령 PASS

- [ ] **Step 5: Commit** — `feat(design): day-cell 윤달 초하루 표지 슬롯 (#260)`

---

### Task 5: 글자 수 상한 행 (spec §6)

**Files:**
- Modify: `docs/identity/design/tools/lengths.py` (`DIALOG_SLOTS`, `TARGETS`, `NO_LIMIT`)
- Modify: `docs/identity/design/lengths.md` (표 다시 만듦)
- Test: `docs/identity/design/tools/test_lengths.py`

**Interfaces:**
- Consumes: Task 1~4의 칸 폭(아래 표에 숫자로 고정)

- [ ] **Step 1: 실패하는 테스트 작성**

`test_every_requested_slot_has_a_value_or_no_limit`의 기대 집합에 `issue_389`를 더하고(`assert slots == issue_54 | issue_131 | set(D77_SLOTS.values()) | issue_389`), `NO_LIMIT` 기대 집합에 `"login-methods.error.body"`, `"ui.account-merge.error"`를 더함. `DIALOG_SLOTS_EXPECTED`에 `"login-methods.unlink.confirm"`, `"account-merge.merge.confirm"`을 더함. 새 테스트:

```python
ISSUE_389 = {
    "login-methods.intro.body", "login-methods.last.notice", "login-methods.unlink.confirm",
    "account-merge.title.head", "account-merge.title.body", "account-merge.choice.label",
    "account-merge.overlap.notice", "account-merge.cta.merge", "account-merge.cta.cancel", "account-merge.merge.confirm",
    "ui.login-methods.row", "ui.account-merge.choice", "ui.account-merge.saju", "ui.settings.login-methods",
    "ui.day-cell.lunar",
}


def test_d82_ia_slots_are_measured():
    ia = json.loads((REPO_ROOT / "docs" / "ia" / "screens.json").read_text(encoding="utf-8"))
    screens = {screen["id"]: screen for screen in ia["screens"]}
    ia_slots = {slot["id"] for sid in ("login-methods", "account-merge") for slot in screens[sid]["slots"]
                if not slot["id"].endswith(".bar.title")}
    measured = {slot for target in lengths.TARGETS for slot in target.slots}
    assert ia_slots <= measured | set(lengths.NO_LIMIT)
    places = {slot: target.where for target in lengths.TARGETS for slot in target.slots}
    assert places["account-merge.cta.merge"].startswith("primary-button")
    assert places["ui.day-cell.lunar"].startswith("day-cell")
```

(`issue_389 = ISSUE_389` 를 기대 집합 계산에 씀.)

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_lengths.py -q` / Expected: FAIL

- [ ] **Step 3: `lengths.py` 고치기**

* `DIALOG_SLOTS`에 두 확인 창 슬롯 추가.
* primary-button 대상에 `account-merge.cta.merge`, `account-merge.cta.cancel` 추가(주석 "D82 account-merge 아래 버튼").
* `NO_LIMIT`에 `"login-methods.error.body": "확인 창 본문(창이 늘어남)"`, `"ui.account-merge.error": "확인 창 본문(창이 늘어남)"`.
* 새 `Target` (모두 `draft=None`; 주석 `# D82·D83 로그인 수단·계정 합치기 (#389, spec 2026-10-22 §6)`):

| slots | where | font | size | tracking | width | lines | sentence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `login-methods.intro.body` | "login-methods 첫머리 (본문 폭)" | ui-400 | 14 | -0.28 | `CONTENT_WIDTH` | 3 | True |
| `login-methods.last.notice` | "login-methods 마지막 수단 안내 (본문 폭)" | ui-400 | 13 | -0.26 | `CONTENT_WIDTH` | 2 | True |
| `ui.login-methods.row` | "social-login-button connected 이름·연결됨 (좌우 16, 로고 20 + 간격 8, check 14 + 간격 4, 둘이 나눔)" | ui-600 | 14 | -0.28 | `(CONTENT_WIDTH - 2 * 16 - 20 - 8 - 14 - 4) / 2` | 1 | False |
| `ui.settings.login-methods` | "settings-row 이름 (좌우 16, 화살표 16)" | ui-400 | 14 | -0.28 | `CONTENT_WIDTH - 2 * 16 - 16` | 1 | False |
| `account-merge.title.head` | "account-merge 제목 (본문 폭)" | ui-600 | 20 | -0.4 | `CONTENT_WIDTH` | 2 | False |
| `account-merge.title.body` | "account-merge 설명 (본문 폭)" | ui-400 | 14 | -0.28 | `CONTENT_WIDTH` | 4 | True |
| `account-merge.choice.label` | "account-choice 묶음 이름 (본문 폭)" | ui-500 | 12 | -0.24 | `CONTENT_WIDTH` | 1 | False |
| `account-merge.overlap.notice` | "account-merge 겹치는 날 안내 (아이콘 16 + 간격 8)" | ui-400 | 13 | -0.26 | `CONTENT_WIDTH - 16 - 8` | 2 | True |
| `ui.account-merge.choice` | "account-choice 현재 계정 알약 (카드 안 256의 절반, 좌우 8 + 테두리 1)" | ui-500 | 11 | -0.22 | `(CONTENT_WIDTH - 2 * 16 - 32) / 2 - 2 * 8 - 2` | 1 | False |
| `ui.account-merge.saju` | "account-choice 사주 요약 (카드 안 폭, 고름 표시 22 + 간격 10)" | ui-400 | 13 | -0.26 | `CONTENT_WIDTH - 2 * 16 - 22 - 10` | 1 | False |
| `ui.day-cell.lunar` | "day-cell lunar 줄 윤달 초하루 (칸 폭 44px, type.caption.sm 500)" | ui-500 | 10.5 | -0.22 | `(CONTENT_WIDTH - 2 * 6) / 7` | 1 | False |

- [ ] **Step 4: `lengths.md` 다시 만들기**

Run: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts` (출력은 세션 scratchpad 파일로 받음). 그 출력 표로 `lengths.md`의 표 블록 전체를 바꿉니다. 표 앞뒤 설명 문단은 그대로 두고, 근거 문단에 한 줄을 더합니다: "2.7.0(#389): 로그인 수단·계정 합치기 11행, 윤달 표지 1행. 기존 확정값 그대로".

- [ ] **Step 5: 통과 확인** — Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_lengths.py -q` / Expected: PASS(skip 0, `test_existing_rows_keep_their_values`·`test_committed_table_matches_measurement` 포함)

- [ ] **Step 6: Commit** — `feat(design): 로그인 수단·계정 합치기·윤달 표지 글자 수 상한 (#389, #260)`

---

### Task 6: 컴포넌트 계약 2.7.0

**Files:**
- Modify: `docs/identity/design/tools/components.py:20` (`CONTRACT_VERSION = "2.7.0"`)
- Modify: `docs/identity/design/components/*.json` 11개의 `"version"`
- Modify: `docs/identity/design/components/README.md` (버전 표 행, 계약 줄)
- Modify: `docs/contracts/README.md` ("컴포넌트 명세" 행의 버전 칸과 이력)
- Test: `docs/identity/design/tools/test_components.py` (`test_contract_version_is_2_6` → `test_contract_version_is_2_7`, `assert VERSION == "2.7.0"`)

- [ ] **Step 1:** 테스트 이름·값을 2.7.0으로 바꿈 → Run `... -k contract_version` → FAIL 확인
- [ ] **Step 2:** `CONTRACT_VERSION`, JSON 11개 `version`, README 계약 줄을 2.7.0으로. README 버전 표에 행: `| 2.7.0 | 2026-10-22 | D82·D83(#389): social-login-button line·google 변형과 언어별 순서·connected(V39), account-choice 새 컴포넌트와 account-merge 배치(V40), 두 버튼 dialog 첫 초점 삭제(V41, #354 ②), day-cell 윤달 표지 슬롯(#260). 추가와 값 변경 |`. 계약 표 행: 버전 칸 2.7.0, 이력 끝에 "2.7.0: 로그인 수단·계정 합치기(D82·D83), 첫 초점 삭제(V41)."
- [ ] **Step 3:** Run 전체 테스트 + `python3 docs/identity/design/tools/components.py` → 전부 PASS, 검사기 문제 없음
- [ ] **Step 4: Commit** — `feat(design): 컴포넌트 계약 2.7.0`

---

### Task 7: 결정·시안 기록·현재 상태

**Files:**
- Modify: `docs/identity/design/decisions.md` (V39~V41 행, spec §8 문장 그대로, 근거 "Issue #389, 사용자 결정(시안 B, 첫 초점)")
- Modify: `docs/identity/design/artifacts/index.json` (항목 둘)
- Create: `docs/identity/design/artifacts/2026-10-22-v2-login-methods.png`, `2026-10-22-v2-account-merge.png`
- Modify: `docs/identity/design/CLAUDE.md` ("현재 상태" 맨 앞 항목, "다음 할 일")

- [ ] **Step 1: 시안 PNG** — 각 HTML을 `<!doctype html><meta charset="utf-8">`로 감싼 임시 파일(scratchpad)로 만들어 Chrome headless로 찍음:
`"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --window-size=1240,1100 --screenshot=<png 경로> file://<임시 html>`
- [ ] **Step 2: `index.json` 항목** — 기존 형식(`id`, `title`, `kind` "concept", `file`, `source`, `date` "2026-10-22", `milestone` "V2", `screens`, `decisions`, `status`, `note`):
  * `design-v2-login-methods`: screens `["login-methods"]`, decisions `["V39"]`, status "chosen", note "B 네 버튼 그대로 + connected 채택. A(연결된 것은 settings-row 줄), C(네 줄 모두 settings-row) 탈락".
  * `design-v2-account-merge`: screens `["account-merge"]`, decisions `["V40", "V41"]`, status "chosen", note "고르기 전 none, 강조는 최종 확인 dialog destructive 한 곳, 겹치는 날 안내는 경고 표시 없는 안심 안내. 표시 문구 '현재 계정'은 사용자 결정. 카드의 수단 로고는 spec에서 이름 글자로 바꿈".
  * `python3 -c "import json; json.load(open('docs/identity/design/artifacts/index.json'))"` 로 JSON 확인.
- [ ] **Step 3: `decisions.md`** — V39~V41 세 행 추가.
- [ ] **Step 4: `CLAUDE.md`** — "현재 상태 (2026-10-22, design 세션 작성)" 맨 앞에 이 작업 한 항목(브랜치 `design/account-choice`, 2.7.0 요점, spec·결정 링크), 첫 항목(#362)은 끝난 것으로 줄임. "다음 할 일" 0번(#362 코멘트)과 1번(윤달 표지) 삭제, 새 0번: "#389 PR 병합 뒤 app #311에 2.7.0 요약(첫 초점 변경은 기존 삭제 확인 창에도 걸림)", 1번: "#410 diary-row 같은 날 여러 편 + 10편 상한 입구(D83 ②)", 2번: "지휘가 IA `login-methods`에서 settings-row를 빼면 `USED_ON_EXCEPTIONS` 삭제", 3번: "writing이 §7.2 키를 더하면 `account-choice`·`connected` 슬롯 키 확인". 기존 대기 항목(V31·app 대응·W1·토큰)은 번호만 밀기.
- [ ] **Step 5:** 전체 테스트 한 번 → PASS
- [ ] **Step 6: Commit** — `docs(design): 결정 V39~V41, 시안 기록, 현재 상태 (#389)`

---

### Task 8: 요청함 (PR을 연 뒤)

외부에 남는 글이므로 PR을 연 다음에 씁니다. 본문 끝에 `---` + `_Generated by [Claude Code](https://claude.ai/code)_`.

- [ ] **Step 1: 지휘 요청 Issue** — `gh issue create --label from:design,to:root,kind:request --title "[design→root] IA login-methods에서 settings-row 빼기 (D82, V39)"`: 무엇(spec §7.1 1번), 왜(시안 B), 영향(design 테스트 예외 `USED_ON_EXCEPTIONS` 삭제 대기), 관련(#389, PR 번호).
- [ ] **Step 2: writing 코멘트** — #388에 spec §7.2 1~6번을 그대로(PR #419는 병합됨).
- [ ] **Step 3: #354 코멘트** — ②의 답(V41: 첫 초점 옵션 없음, 파괴적이지 않은 무거운 변경은 `confirm`), ①③④는 열린 채 다음 작업.
- [ ] **Step 4:** PR 본문에 `Closes #389`, `Closes #395`, `참고 #354`.

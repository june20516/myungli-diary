# 구현 대응·IA v3·글자 수 상한 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 컴포넌트 명세를 2.3.0으로 올려 app 구현 대응(#118·#142·#154)과 `depth-link` `navigate`(#159)를 적고, 글자 수 상한을 ui 이름 자리와 새 content 슬롯까지 넓힙니다(#131).

**Architecture:** 명세는 `components/*.json`(사실)과 같은 이름의 `.md`(설명)입니다. 검사기 `tools/components.py`가 IA·토큰·버전·필드를 보고, `tools/test_components.py`가 명세 값을 고정합니다. 글자 수는 `tools/lengths.py`가 칸(`Target`)마다 계산하고, `lengths.md`의 표는 도구 출력 그대로입니다(`test_lengths.py`가 비교).

**Tech Stack:** JSON, Markdown, Python 3, fontTools 4.54.1, pytest 8.3.5

**Spec:** `docs/identity/design/specs/2026-10-15-spec-followups-design.md`

## Global Constraints

* 명령은 저장소 루트(`/Users/bran/personal/myungli-diary-design`, 브랜치 `design/spec-followups`)에서 실행합니다. 테스트: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`. 측정 글꼴은 `.suberpowers/fonts/`에 있으므로 `lengths.md` 표 비교가 실제로 돕니다(skip이면 실패로 봅니다).
* 고칠 수 있는 곳은 `docs/identity/design/`과 GitHub Issues뿐입니다. `docs/ia/`, writing 파일은 읽기만 합니다.
* 부 버전입니다. 기존 구성 요소·필드·변형·상태의 이름을 바꾸거나 빼지 않습니다. 값과 규칙 문장만 바꾸고, 새 것은 더합니다.
* 새 토큰은 없습니다. 참조는 기존 토큰만 씁니다.
* JSON에 넣는 `slot` 값은 모두 main의 `docs/ia/screens.json`에 있어야 합니다(`test_every_slot_exists_in_ia`). `birthplace.standard.link`(IA v3 전용)는 JSON에 넣지 않고 `sentence.md`에만 적습니다.
* 문서는 한국어 경어체, 기술 용어는 원어를 씁니다. 로마자 표기는 `myungli`입니다.
* 커밋 메시지 끝에 다음 두 줄을 붙입니다.
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01DSycKkQRTW38GxQJxMvJQp
  ```

## Review Focus

1. 기존 `lengths.md` 확정값이 바뀜: 칸을 더하면서 기존 13행의 값이 달라지면 writing이 이미 넣은 상한과 어긋납니다. Task 6이 기존 행을 문자열로 고정합니다.
2. 버전을 일부 파일만 올리거나 `icon.set.version`(2.1.2)까지 바꿈: Task 1 테스트가 `elements.icon.set.version == "2.1.2"`를 확인합니다.
3. 화살표 표기가 세 곳 중 한 곳만 아이콘: Task 2 테스트가 `depth-link.parts.chevron`, `sentence-block` `locked.open.chevron`, `lockPanel.pass.chevron`이 같은 객체인지 봅니다.
4. 탭 아이콘 키가 IA 탭 id와 다름: Task 5 테스트가 키 집합을 IA의 `tab` 값 집합과 비교합니다.
5. 한 슬롯이 두 칸에 들어가 서로 다른 값을 받음(의도한 확인 창 슬롯 제외): Task 6 테스트가 확인 창 슬롯만 두 칸(제목·버튼)에 있고 나머지는 한 칸에만 있는지 봅니다.

---

### Task 1: 계약 버전 2.3.0과 최소 높이 규칙

**Files:**
- Modify: `docs/identity/design/tools/components.py:20`
- Modify: `docs/identity/design/components/*.json` 11개의 최상위 `"version"`
- Modify: `docs/identity/design/components/README.md` (첫 줄 계약 버전, 근거 줄, 공통 규칙, 버전 표)
- Test: `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Produces: `CONTRACT_VERSION = "2.3.0"`. 이후 task의 테스트는 이 버전을 전제로 합니다.

- [ ] **Step 1: 테스트 고치기.** `test_contract_version_is_2_2`를 `test_contract_version_is_2_3`으로 바꾸고 `assert VERSION == "2.3.0"`. 새 테스트를 더합니다.

```python
def test_icon_set_version_is_not_contract_version():
    assert load_documents(COMPONENTS_DIR)["elements"]["elements"]["icon"]["set"]["version"] == "2.1.2"


def test_readme_states_minimum_height_rule():
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "최소 높이" in readme and "| 2.3.0 | 2026-10-15 |" in readme
```

- [ ] **Step 2: 실패 확인.** Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_components.py -q` → `test_contract_version_is_2_3`, `test_readme_states_minimum_height_rule` FAIL
- [ ] **Step 3: 구현.** `CONTRACT_VERSION = "2.3.0"`. JSON 11개의 최상위 `"version": "2.2.0"`만 `"2.3.0"`으로 바꿉니다. README: 첫 줄 "컴포넌트 계약 2.3.0", 근거 줄에 이 spec 링크와 결정 V13~V33, 공통 규칙에 spec §2.1 문장 그대로("명세의 고정 높이(`height`)는 기본 글자 크기에서의 높이다. 기기 글자가 커지면 글자가 잘리지 않게 늘어나는 최소 높이로 구현한다." + 표·달력 예외), 버전 표에 `| 2.3.0 | 2026-10-15 | ... |` 한 줄(링크 화살표 아이콘, `depth-link` `navigate`, `dialog` `notice`, `segmented` `none`, 윤달 대체, `social-login-button` `disabled`, 탭 아이콘, 시간 형식, 빈 구역, 최소 높이, 요소 값 3개).
- [ ] **Step 4: 통과 확인.** 같은 명령 → 전부 PASS. `python3 docs/identity/design/tools/components.py` → 문제 0
- [ ] **Step 5: Commit** `feat(design): 컴포넌트 계약 2.3.0, 고정 높이는 최소 높이 (#142)`

### Task 2: `sentence.json` — 링크 화살표, `navigate`, 빈 구역

**Files:**
- Modify: `docs/identity/design/components/sentence.json`, `sentence.md`
- Test: `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Produces: 화살표 객체 `CHEVRON = {"icon": "caret-right", "weight": "regular", "size": "link-text-size", "color": "link-color", "gap": {"value": 2, "unit": "px"}, "decorative": True}`. Task 3 이후 테스트가 재사용하지 않지만 Task 8의 notice 문구가 이 표기를 인용합니다.

- [ ] **Step 1: 실패하는 테스트**

```python
CHEVRON = {"icon": "caret-right", "weight": "regular", "size": "link-text-size", "color": "link-color",
           "gap": {"value": 2, "unit": "px"}, "decorative": True}


def test_text_link_chevrons_are_component_drawn_icons():
    depth_link = component("sentence", "depth-link")
    block = component("sentence", "sentence-block")
    assert depth_link["parts"]["chevron"] == CHEVRON
    assert block["states"]["locked"]["parts"]["open"]["chevron"] == CHEVRON
    assert depth_link["states"]["locked"]["parts"]["evidenceSheet"]["lockPanel"]["pass"]["chevron"] == CHEVRON
    assert any("원고에 넣지 않" in rule for rule in depth_link["rules"])


def test_depth_link_navigate_goes_to_a_page():
    depth_link = component("sentence", "depth-link")
    navigate = next(v for v in depth_link["variants"] if v["id"] == "navigate")
    assert navigate["parts"]["target"] == {"presentation": "page", "transition": "platform-default"}
    assert "slot" not in json.dumps(navigate)
    assert any("navigate" in rule and "sheet.enter" in rule for rule in depth_link["rules"])
    assert "birthplace" in (COMPONENTS_DIR / "sentence.md").read_text(encoding="utf-8")


def test_unlocked_evidence_sheet_omits_empty_sections():
    rules = component("sentence", "depth-link")["rules"]
    assert any("unlocked" in rule and "본문이 없는 구역" in rule for rule in rules)
```

`component(group, id)` 도우미가 없으면 같은 파일에 `load_documents(COMPONENTS_DIR)[group]["components"]`에서 id로 찾는 함수로 더합니다(이미 있는 도우미가 있으면 그것을 씁니다).

- [ ] **Step 2: 실패 확인** → 세 테스트 FAIL
- [ ] **Step 3: 구현** (spec §2.2·§2.10·§4)
  * `depth-link.parts.chevron`, `sentence-block.states.locked.parts.open.chevron`을 `CHEVRON`으로 바꾸고, `lockPanel.pass`에 `"chevron": CHEVRON`을 더합니다.
  * `depth-link.summary`: "한 단계 깊이로 가는 링크 ('근거 보기 ›'), 또는 다른 페이지로 가는 같은 모양의 링크".
  * `variants`에 `{"id": "navigate", "when": "다른 페이지로 이동(출생지 → 계산 기준). 시트를 열지 않음", "parts": {"label": {"align": "start"}, "container": {"marginTop": "{space.12}"}, "target": {"presentation": "page", "transition": "platform-default"}}}`.
  * `rules`: 기존 "누르면 evidence-sheet 등…" 문장 앞에 "inline-end·block은 "을 붙이고, 세 문장을 더합니다: "navigate는 시트를 열지 않고 페이지로 이동한다(플랫폼 기본 전환). sheet.enter·sheet.stack을 쓰지 않는다.", "화살표(chevron)는 원고에 넣지 않고 컴포넌트가 그린다. 아이콘 caret-right, 링크 글자 크기, 스크린리더는 읽지 않음, 링크가 감기면 마지막 줄 끝에 붙는다(결정 V29).", "unlocked에서 본문이 없는 구역은 제목까지 그리지 않고 자리도 남기지 않는다. locked의 lock.veil은 그대로 그린다."
  * `sentence.md`: depth-link 쓰는 화면에 `birthplace`, `navigate` 설명(자리 `birthplace.standard.note` 아래·검색칸 위, 슬롯 `birthplace.standard.link`, IA v3 D71), 화살표 설명(V29), 빈 구역, 구현 힌트(`inline-end` = 문장 끝 `WidgetSpan` 하나), sentence-block 배치에 "my-saju 일간 소개 첫 문장(`my-saju.ilgan.head`)은 `card`, 이어지는 문장은 `body`". 근거 줄에 이 spec과 V29·V32.
- [ ] **Step 4: 통과 확인** → 테스트 전부 PASS, `components.py` 문제 0
- [ ] **Step 5: Commit** `feat(design): 링크 화살표는 컴포넌트가 그림, depth-link navigate, 빈 구역 생략 (#142·#154·#159)`

### Task 3: `input.json` — segmented `none`, 아래 버튼, 윤달 대체, 지역 줄

**Files:**
- Modify: `docs/identity/design/components/input.json`, `input.md`
- Test: `docs/identity/design/tools/test_components.py`

- [ ] **Step 1: 실패하는 테스트**

```python
def test_segmented_has_unselected_state():
    segmented = component("input", "segmented")
    none = segmented["states"]["none"]
    assert none["parts"]["indicator"] == {"visible": False}
    assert none["parts"]["label"] == {"fg": "{color.text.secondary}"}
    assert none["pattern"] == "appear.seep" and "appear.seep" in segmented["uses"]


def test_input_step_omits_bottom_action_for_pick_and_go_steps():
    step = component("input", "input-step")
    assert "birthplace" in step["parts"]["bottomAction"]["omitWhen"]
    assert any("아래 버튼을 두지 않는다" in rule for rule in step["rules"])


def test_date_picker_leap_month_fallback():
    birth = next(v for v in component("input", "date-picker")["variants"] if v["id"] == "birth")
    fallback = birth["parts"]["leapMonthFallback"]
    assert (fallback["component"], fallback["variant"]) == ("check-row", "inline")
    assert fallback["replaces"] == ["leapMonth", "solarConfirm"]
    assert "leapMonth" in birth["parts"] and "solarConfirm" in birth["parts"]


def test_city_search_never_shows_country_code():
    city = component("input", "city-search")
    assert city["parts"]["region"]["whenMissing"] == "hidden"
    assert any("나라 코드" in rule for rule in city["rules"])
```

- [ ] **Step 2: 실패 확인** → 네 테스트 FAIL
- [ ] **Step 3: 구현** (spec §2.4·§2.5·§2.8·§2.9)
  * `segmented`: `uses`에 `appear.seep`. `states.none = {"note": "아직 고르지 않음(성별 고르기 전). 처음 고르면 표시 막대가 미끄러지지 않고 그 자리에 스밈", "pattern": "appear.seep", "parts": {"indicator": {"visible": false}, "label": {"fg": "{color.text.secondary}"}}}`. 규칙 "none에서는 input-step 아래 버튼이 disabled다."
  * `input-step.parts.bottomAction.omitWhen = "고르면 바로 넘어가는 단계(birthplace 도시 결과 줄)"`, 규칙 "고르면 바로 넘어가는 단계에는 아래 버튼을 두지 않는다. 비활성 버튼이 늘 떠 있지 않게 한다."
  * `date-picker` birth `parts.leapMonthFallback = {"component": "check-row", "variant": "inline", "when": "음력이고 음력→양력·윤달 조회가 계약에 없을 때", "position": "below-wheels", "replaces": ["leapMonth", "solarConfirm"]}`. 규칙 두 문장(spec §2.8): 목표는 휠의 `윤N월` + 확인 줄, 조회가 없으면 대체를 쓰고 확인 줄 자리를 비우지 않으며 없는 윤달은 저장 때 오류 줄로 보인다(결정 V31).
  * `city-search.parts.region`에 `"content": "행정 구역, 나라 이름"`, `"whenMissing": "hidden"`. 규칙 "나라 코드를 그대로 보이지 않는다. 지역 이름이 없으면 region 줄을 그리지 않고 줄 최소 높이 56px는 그대로다."
  * `input.md`: 위 설명과 구현 힌트(segmented: Flutter `radioGroup` / `checked` + `inMutuallyExclusiveGroup`, city-search: combobox 미적용 flutter#159741), 근거 줄 V31.
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: Commit** `feat(design): segmented none, 고르고 넘어가는 단계, 윤달 대체, 지역 줄 (#142)`

### Task 4: `feedback`·`action` — dialog `notice`, 소셜 로그인 꺼짐

**Files:**
- Modify: `docs/identity/design/components/feedback.json`, `feedback.md`, `action.json`, `action.md`
- Test: `docs/identity/design/tools/test_components.py`

- [ ] **Step 1: 실패하는 테스트**

```python
def test_dialog_notice_has_one_button():
    notice = next(v for v in component("feedback", "dialog")["variants"] if v["id"] == "notice")
    assert notice["parts"]["cancel"] == {"visible": False}
    assert notice["a11y"] == {"focusOnOpen": "confirm", "dismissOnScrim": True}
    assert "login.discard.notice" in notice["when"]


def test_social_login_disabled_and_apple_label():
    button = component("action", "social-login-button")
    assert button["states"]["disabled"]["parts"]["container"] == {"opacity": 0.4}
    apple = next(v for v in button["variants"] if v["id"] == "apple")
    assert apple["parts"]["label"] == {"fontFamily": "platform-system", "type": "{type.label.lg}"}
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** (spec §2.3·§2.6·§3)
  * `dialog.variants`에 `{"id": "notice", "when": "고를 것 없이 읽었다는 확인만 받는 안내(login.discard.notice)", "a11y": {"focusOnOpen": "confirm", "dismissOnScrim": true}, "parts": {"cancel": {"visible": false}}}`. 규칙 "notice는 확인 버튼 하나다. 바깥을 누르거나 뒤로 가면 확인과 같다."
  * `social-login-button.states.disabled = {"note": "다른 버튼이 처리 중일 때. 제공자 색을 바꿀 수 없어 버튼 전체를 흐림", "parts": {"container": {"opacity": 0.4}}}`, apple 변형 `parts.label = {"fontFamily": "platform-system", "type": "{type.label.lg}"}`.
  * `feedback.md`: notice 설명, 구현 힌트 표(skeleton → `loadingSpinner`, empty-state → `container`, toast·notice-banner·error-state → role 노드와 liveRegion 노드 분리). `action.md`: disabled·Apple 글자(HIG 시스템 글꼴).
- [ ] **Step 4: 통과 확인** (`{type.label.lg}`가 4개 테마 조합에서 풀리는지 검사기가 봄)
- [ ] **Step 5: Commit** `feat(design): dialog notice, 소셜 로그인 disabled (#142·#118)`

### Task 5: `frame`·`today`·`elements` — 탭 아이콘, 뒤로 숨김, 시간 형식, 요소 값

**Files:**
- Modify: `docs/identity/design/components/frame.json`, `frame.md`, `today.json`, `today.md`, `elements.json`, `elements.md`
- Test: `docs/identity/design/tools/test_components.py`

- [ ] **Step 1: 실패하는 테스트**

```python
def test_tab_icons_cover_ia_tabs():
    icons = component("frame", "tab-bar")["parts"]["icons"]
    assert icons == {"today": "sun", "calendar": "calendar-blank", "diary": "notebook", "me": "user"}
    assert set(icons) == {screen["tab"] for screen in ia_screens().values() if screen["tab"]}


def test_app_bar_hides_back_on_flow_first_screens():
    rules = component("frame", "app-bar")["rules"]
    assert any("consent" in rule and "notify-ask" in rule and "뒤로" in rule for rule in rules)


def test_lucky_time_value_format():
    time = next(v for v in component("today", "lucky-card")["variants"] if v["id"] == "time")
    assert time["parts"]["value"] == {"format": "HH:mm–HH:mm", "clock": "24h", "timeZone": "profile",
                                      "join": " · ", "fontFeatures": ["tnum"]}


def test_element_values_from_app_feedback():
    elements = load_documents(COMPONENTS_DIR)["elements"]["elements"]
    assert elements["icon"]["set"]["flutter"] == "phosphor_glyphs"
    assert elements["icon"]["set"]["flutterVersion"] == "2.1.2+1"
    assert elements["mark.caution"]["size"] == {"ratio": 0.707, "of": "font-size",
                                                "basis": "Pretendard OS/2 sCapHeight 1448 / 2048"}
    assert elements["lock.veil"]["lines"] == {"default": "server 길이 힌트, 없으면 2", "sentence-block locked": 1}
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** (spec §2.7·§2.11·§2.12·§2.13)
  * `tab-bar.parts.icons`를 위 값으로, 규칙 없음(아이콘 굵기는 기존 `icon`·`selected` 그대로).
  * `app-bar.rules`에 "갈래의 첫 화면이라 돌아갈 곳이 없으면(consent, notify-ask) inner여도 뒤로 버튼을 숨긴다. 뒤로 자리를 비워 두지 않고 제목은 같은 자리에서 시작한다."
  * `lucky-card` time 변형 `parts.value`를 위 값으로. 규칙 "time 값은 프로필 시간대 24시간 HH:mm–HH:mm(en dash), 구간이 여럿이면 ' · '로 잇는다. 세 언어 같은 형식."
  * `elements`: `icon.set.flutter`·`flutterVersion`, `mark.caution.size`, `lock.veil.lines`를 위 값으로.
  * `.md`: 탭 아이콘(app 제안 채택, V15), 뒤로 숨김, 시간 형식 예 `09:30–11:30 · 13:30–15:30`, 요소 값의 근거(phosphor_flutter 2.1.0 컴파일 불가, cap-height 실측, `LockVeil.line` = `lines: 1`), `frame.md`에 AdBanner 높이 0은 명세와 같다는 구현 힌트.
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: Commit** `feat(design): 탭 아이콘, 뒤로 숨김, 행운 시간 형식, 요소 값 (#118·#142·#154)`

### Task 6: 글자 수 상한 확장 (`lengths.py`, `lengths.md`)

**Files:**
- Modify: `docs/identity/design/tools/lengths.py`, `docs/identity/design/tools/test_lengths.py`, `docs/identity/design/lengths.md`

**Interfaces:**
- Produces: `Target`에 `reserve_px: float = 0.0`(마지막 필드), `free_width`가 이를 뺌. `NO_LIMIT: dict[str, str]`(슬롯 → 이유), `DIALOG_SLOTS: tuple[str, ...]`, `render_table(results) -> str`는 기존 표 뒤에 "상한 없음" 표를 덧붙임.

- [ ] **Step 1: 실패하는 테스트**

```python
EXISTING_ROWS = [  # lengths.md 2.2.0 시점의 확정 13행. 값이 바뀌면 안 됨 (spec §5.6)
    # 구현 전 lengths.md의 표 행을 그대로 복사해 넣습니다(머리 2줄 제외, 13줄).
]

DIALOG_SLOTS_EXPECTED = {"diary-view.delete.confirm", "event-edit.delete.confirm", "account-delete.delete.confirm",
                         "settings.logout.confirm", "preview.share.login-notice", "profile-edit.recalc.confirm"}


def test_reserve_px_is_subtracted():
    target = Target(("n",), "칸", "ui", 10, 0, 100, 1, False, None, reserve_px=30)
    assert free_width(target, FAKE, {}) == 70


def test_no_limit_rows_are_rendered():
    table = render_table([])
    assert "| `ui.a11y.label` |" in table and "| `system.apple_return` |" in table and "상한 없음" in table


def test_only_dialog_slots_sit_in_two_targets():
    seen = {}
    for target in lengths.TARGETS:
        for slot in target.slots:
            seen[slot] = seen.get(slot, 0) + 1
    assert {slot for slot, count in seen.items() if count > 1} == DIALOG_SLOTS_EXPECTED == set(lengths.DIALOG_SLOTS)


@pytest.mark.skipif(not FONTS_PRESENT, reason="측정 글꼴이 .suberpowers/fonts에 없음 (lengths.md 참고)")
def test_existing_rows_keep_their_values(capsys):
    lengths.main(["--font-dir", str(FONT_DIR)])
    table = capsys.readouterr().out
    assert all(row in table for row in EXISTING_ROWS)
```

`test_corpus_reads_round_choices`는 main에서 이미 실패합니다(R8 `8ac564c`가 glob에 들어와 46 → 49). R8도 원고 라운드이므로 기대값을 `49`로 바꾸고, `lengths.md`·`lengths.py` docstring의 "R1~R7, 46개"를 "R1~R8, 49개"로 고칩니다(기존 확정값은 바뀌지 않음, `test_committed_table_matches_measurement`가 확인).

`test_every_writing_slot_from_issue_54_has_a_value`는 이름을 `test_every_requested_slot_has_a_value_or_no_limit`로 바꾸고, 기대 집합에 spec §5.2 표의 슬롯 전부(+ `DIALOG_SLOTS_EXPECTED`, `chart.ilgan_head`, `character.reason`)를 더하며, `set(lengths.NO_LIMIT)`도 합쳐 spec §5.3 표의 슬롯 전부와 같은지 봅니다. `test_render_table_lists_targets_and_unbounded_slots`는 그대로 통과해야 합니다.

- [ ] **Step 2: 실패 확인** (`EXISTING_ROWS`는 지금 `lengths.md`에서 복사하므로 `test_existing_rows_keep_their_values`만 PASS, 나머지 FAIL)
- [ ] **Step 3: 구현** (spec §5)
  * `Target`에 `reserve_px`. `free_width`에서 `width -= target.reserve_px`.
  * 글자 스타일 대응(토큰 값): label.lg `ui-600 14 −0.28`, label.md `ui-500 13 −0.26`, body.ui `ui-400 14 −0.28`, caption.lg `ui-400 13 −0.26`, caption.sm `ui-500 11 −0.22`, subtitle `ui-600 16 −0.32`, 입력칸 `ui-400 17 0`, sentence.body `sentence 15 0`, sentence.card `sentence 17 0`.
  * `TARGETS` 뒤에 spec §5.2 표 순서대로 칸을 더합니다. 칸 폭은 표의 식을 Python 식 그대로 씁니다(예: `CONTENT_WIDTH - 2 * 20`). `draft`는 모두 `None`. "이름" 칸은 `sentence=False`, "문장" 칸은 `sentence=True`.
  * 확인 창: `DIALOG_SLOTS`(위 6개). 제목 칸 `Target(DIALOG_SLOTS, "dialog title (확인 창 슬롯의 제목 키, 안쪽 28·24)", "ui-600", 16, -0.32, 360 - 2 * 28 - 2 * 24, 2, False, None)`, 버튼 칸 `Target(("ui.action.button",) + DIALOG_SLOTS, "dialog 버튼 두 개 중 하나 (확인 창 슬롯은 버튼 키)", "ui-600", 14, -0.28, (360 - 2 * 28 - 2 * 24 - 8) / 2, 1, False, None)`.
  * 이유 줄 `character.reason`: `reserve_px`는 Pretendard SemiBold 14px 자간 −0.28로 잰 "근거 보기" 폭 + 앞 공백(U+00A0) 폭 + 화살표 14 + 간격 2를 올림한 정수입니다. 한 번 재서 숫자로 적고, 잰 방법을 주석 한 줄로 남깁니다.
  * `NO_LIMIT`: spec §5.3 표의 슬롯 → 이유("스크린리더 전용", "스크롤 본문", "app 밖 화면"). `render_table`은 기존 표와 `UNBOUNDED` 행 뒤에 빈 줄을 두고 `| 슬롯 | 상한 없음 이유 |` 표를 덧붙입니다.
  * 모듈 docstring의 계산 방법에 "여러 자리에 쓰는 슬롯은 가장 좁은 자리" 한 줄.
  * 도구를 돌려 `lengths.md`의 표를 출력으로 바꿉니다: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts`. `lengths.md` 본문에 #131 근거, "여러 자리 슬롯은 가장 좁은 자리" 원칙, 확인 창 슬롯 설명(제목·버튼 키만 상한, 본문 없음, writing에 나누기 요청), `calendar.solar_term` en 줄임 표기 확인 결과(가장 넓은 표기를 같은 칸 스타일로 재 6자 칸 안에 드는지 한 줄), 결정 V33 근거 줄을 더합니다.
- [ ] **Step 4: 통과 확인** → `test_lengths.py` 전부 PASS(skip 0), 도구 출력 = `lengths.md` 표
- [ ] **Step 5: Commit** `feat(design): 글자 수 상한을 ui 이름 자리와 새 content 슬롯까지 (#131)`

### Task 7: 결정 기록과 `CLAUDE.md`

**Files:**
- Modify: `docs/identity/design/decisions.md`, `docs/identity/design/CLAUDE.md`

- [ ] **Step 1:** `decisions.md`에 V29~V33 다섯 줄(날짜 2026-10-15, 근거 열은 "사용자 결정 (#118·#142·#154·#159·#131 brainstorming), [spec](specs/2026-10-15-spec-followups-design.md) §n"): V29 화살표 §2.2, V30 최소 높이 §2.1, V31 윤달 §2.8, V32 navigate §4, V33 글자 수 확장 §5. 기존 표 형식(`| V29 | 2026-10-15 | 링크 | … | … |`)을 따릅니다.
- [ ] **Step 2:** `CLAUDE.md`: 범위 표와 계약 표의 "계약 2.2.0" → 2.3.0. "현재 상태" 머리를 `(2026-10-15, design 세션 작성)`으로, 맨 위에 이 작업 항목(브랜치 `design/spec-followups`, 계약 2.3.0, Issue #118·#142·#154·#159·#131, 요점 4줄, 근거 spec·V29~V33). "다음 할 일"에 ① writing 확인 창 슬롯 답(Task 8 Issue 번호) ② server 윤달 조회(#141)가 계약에 들어오면 app에 목표 모양 전환 확인 ③ 기존 2·3 유지.
- [ ] **Step 3: 전체 검사.** `python3 docs/identity/design/tools/components.py` → 문제 0. 전체 pytest → 전부 PASS, skip은 워드마크 글꼴 테스트 외 0.
- [ ] **Step 4: Commit** `docs(design): 결정 V29~V33, CLAUDE.md 현재 상태`

### Task 8: PR과 Issue

- [ ] **Step 1: 요청 Issue 두 개 만들기**(본문 파일은 scratchpad에 씀, 항목은 무엇이 필요한가·왜·영향·관련)
  * `[design→app] 컴포넌트 계약 2.3.0 대응: …` `--label from:design,to:app,kind:request`. app이 바꿀 것(region 줄 숨김, birthplace 아래 버튼 제거, `login.discard.notice` → dialog `notice`, segmented `none`, 링크 화살표는 `caret-right` 아이콘 표기 확인, 시간 형식 확인)과 그대로 둘 것(#118·#142 나머지)을 나눠 적음.
  * `[design→writing] 확인 창 슬롯을 역할별로 나눌지, 상한 없음 표기` `--label from:design,to:writing,kind:request`. spec §5.3·§5.4와 `lengths.md` 위치.
  * 마일스톤은 지금 열린 Issue(#142 등)의 마일스톤을 `gh issue view 142 --json milestone`으로 보고 같은 것을 붙입니다.
- [ ] **Step 2: PR 열기.** `gh pr create --base main --head design/spec-followups`, 제목 `design: 컴포넌트 계약 2.3.0 — 구현 대응·depth-link navigate·글자 수 상한 (#118·#142·#154·#159·#131)`. 본문: 요약, 검사 결과, `Closes #118`·`Closes #142`·`Closes #154`·`Closes #159`·`Closes #131` 한 줄씩, "#159: IA v3(PR #157)보다 먼저 병합되어도 검사 통과. 병합 순서는 지휘 판단", 새 Issue 두 번호.
- [ ] **Step 3: 답 코멘트.** #118·#142·#154·#131·#159에 항목별 판단 요약과 PR 번호, 명세 위치를 코멘트로 남깁니다(PR 병합 때 `Closes`로 닫힘).
- [ ] **Step 4:** Task 7의 `CLAUDE.md` "다음 할 일"에 writing Issue 번호를 채워 commit·push(`docs(design): CLAUDE.md에 후속 Issue 번호`).
- [ ] **Step 5:** PR의 CI(`ci-gate`)가 통과하는지 `gh pr checks <번호> --watch`로 확인합니다.

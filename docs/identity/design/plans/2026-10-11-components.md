# V2 컴포넌트 명세 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** IA 컴포넌트 39개의 중립 명세(`components/` JSON+MD)와 디자인 토큰 1.1.0을 만들고, 검사 도구로 IA·토큰과의 일치를 증명합니다.

**Architecture:** 토큰은 지금처럼 생성기(`tools/tokens.py`)가 원본이고, 새 역할 색은 `tools/palette.py`의 역할 표에 더해 대비 검사를 받습니다. 명세는 손으로 쓰는 JSON(사실)과 MD(설명)이고, 새 검사기 `tools/components.py`가 IA·토큰·요소·패턴 참조를 검사합니다. 테스트가 커밋된 실제 파일에 검사기를 돌려 V2의 완료를 증명합니다.

**Tech Stack:** Python 3(표준 라이브러리), pytest 8.3.5, DTCG 2025.10 JSON, Markdown.

**Spec:** `docs/identity/design/specs/2026-10-11-components-design.md` (결정 기록 원본: `.suberpowers/v2-brainstorm-decisions.md`, git 제외)

## Global Constraints

* 모든 경로는 저장소 루트 기준이고, design 세션은 `docs/identity/design/` 아래만 고칩니다(Issue 본문은 `.suberpowers/issues/`, git 제외).
* 테스트 명령: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q` (V1 끝 기준 83 passed).
* 문서 검사: `python3 tools/docs-check/docs_check.py` → `OK`.
* 대비 검사: `python3 docs/identity/design/tools/palette.py --check` → 모든 조합 통과. 글자 기준 4.5:1(반올림 전 값), 비활성 글자만 3:1.
* 토큰 파일은 손으로 고치지 않습니다: `python3 docs/identity/design/tools/tokens.py`로 다시 만듭니다.
* 토큰 계약 1.0.0 → **1.1.0**(추가만). 컴포넌트 계약 **1.0.0**.
* 토큰 참조 표기는 `{이름}`(예: `{color.action.primary}`), 치수 직접 값은 `{"value": n, "unit": "px"}`.
* 컴포넌트 JSON 필드는 spec §2.2 목록만: 문서 `version`·`group`·`components`, 컴포넌트 `id`·`summary`·`uses`·`variants`·`parts`·`states`·`motion`·`haptic`·`a11y`·`rules`.
* 커밋 범위 `feat|docs|fix(design)`, 메시지 끝에 두 줄:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>` / `Claude-Session: https://claude.ai/code/session_018daG4i4NbX9EUgB9r3hqLm`
* 문장·UI 문구는 자리 채우기입니다. 명세에 적는 문구 예시는 Markdown에만 두고 "예시"라고 밝힙니다.
* Material 위젯 이름은 JSON에 쓰지 않습니다(MD 참고 힌트만).

## Review Focus

1. 어떤 토큰이 라이트에는 있고 다크(또는 ko에는 있고 ja)에는 없을 때 — 검사기는 테마 조합마다 따로 빠짐을 알려야 합니다(Task 4 `test_reference_missing_in_one_theme_is_reported`).
2. `{참조}`가 `variants` 목록, `states` 안 `parts`, 패턴 `keyframes` 같은 깊은 곳에 있을 때 — 검사기가 모든 깊이를 훑어야 합니다(Task 4 `test_nested_references_are_checked`).
3. `stateMap` 값이 IA에 없는 컴포넌트 id를 가리킬 때 — 실패해야 합니다(Task 4 `test_state_map_target_must_be_component`).
4. 반투명 도장(`seal.soft`)이 길흉 바탕 위에 겹친 색에서 숫자 대비 — 겹친 색을 계산해 검사해야 합니다(Task 2 `test_seal_soft_composite_pairs_pass`).
5. 동작 줄이기 대체가 빠진 패턴 — 모든 패턴에 `reduceMotion`이 있어야 합니다(Task 4 `test_pattern_without_reduce_motion_is_reported`).

---

### Task 1: DTCG 검사기에 움직임·그림자 타입 추가

**Files:**
- Modify: `docs/identity/design/tools/dtcg.py` (`ALLOWED_TYPES`, `_check_value`)
- Test: `docs/identity/design/tools/test_dtcg.py`

**Interfaces:**
- Produces: `dtcg.ALLOWED_TYPES`에 `"duration"`, `"cubicBezier"`, `"shadow"` 추가. `find_problems(documents)` 시그니처는 그대로.

- [ ] **Step 1: 실패하는 테스트 작성** (`test_dtcg.py`)

```python
def test_duration_value():
    assert find_problems({"a": {"d": {"$type": "duration", "$value": {"value": 200, "unit": "ms"}}}}) == []
    assert find_problems({"a": {"d": {"$type": "duration", "$value": {"value": 200, "unit": "px"}}}})

def test_cubic_bezier_value():
    assert find_problems({"a": {"e": {"$type": "cubicBezier", "$value": [0.2, 0.7, 0.2, 1]}}}) == []
    assert find_problems({"a": {"e": {"$type": "cubicBezier", "$value": [1.2, 0, 0.2, 1]}}})  # x는 0~1
    assert find_problems({"a": {"e": {"$type": "cubicBezier", "$value": [0.2, 0.7, 0.2]}}})

def test_shadow_value():
    shadow = {"color": {"colorSpace": "srgb", "components": [0.1686, 0.1686, 0.1647], "hex": "#2b2b2a", "alpha": 0.14},
              "offsetX": {"value": 0, "unit": "px"}, "offsetY": {"value": 4, "unit": "px"},
              "blur": {"value": 16, "unit": "px"}, "spread": {"value": 0, "unit": "px"}}
    assert find_problems({"a": {"s": {"$type": "shadow", "$value": shadow}}}) == []
    broken = dict(shadow); del broken["blur"]
    assert find_problems({"a": {"s": {"$type": "shadow", "$value": broken}}})
```

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 pytest docs/identity/design/tools/test_dtcg.py -q` / Expected: 새 3개 FAIL(알 수 없는 타입).
- [ ] **Step 3: 구현** — `duration`: `{"value": 숫자 ≥ 0, "unit": "ms"|"s"}`. `cubicBezier`: 숫자 4개, x1·x2는 0~1. `shadow`: 키 `color`(색 검사 재사용)·`offsetX`·`offsetY`·`blur`·`spread`(치수 검사 재사용), `inset`은 있으면 bool. 참조(`{...}`)는 기존처럼 각 값 자리에서 허용.
- [ ] **Step 4: 통과 확인** — 같은 명령 / Expected: 모두 PASS.
- [ ] **Step 5: Commit** — `feat(design): DTCG 검사기에 duration·cubicBezier·shadow 타입 추가`

### Task 2: 팔레트 새 역할 색과 대비 조합

**Files:**
- Modify: `docs/identity/design/tools/palette.py` (`_roles`, `_text_pairs`, 새 함수 `composite`, 상수 `MIN_DISABLED_CONTRAST`, `SEAL_SOFT`)
- Test: `docs/identity/design/tools/test_palette.py`

**Interfaces:**
- Produces:
  - `palette.composite(foreground_hex: str, alpha: float, background_hex: str) -> str` (sRGB 감마 공간 단순 합성, 소문자 hex)
  - `palette.SEAL_SOFT = {"light": ("sage", 700, 0.22), "dark": ("sage", 200, 0.28)}` (Task 3이 토큰에 씀)
  - 새 단색 역할(라이트 / 다크): `inverse.bg` neutral-900 / neutral-100, `inverse.fg` neutral-100 / neutral-900, `disabled.bg` neutral-100 / neutral-800, `disabled.fg` neutral-600 / neutral-500, `seal.knock` sage-50 / neutral-900, `tag.good.bg` coral-100 / coral-800, `tag.good.fg` coral-700 / coral-200, `tag.bad.bg` neutral-100 / neutral-800, `tag.bad.fg` neutral-700 / neutral-200, `tag.neutral.border` neutral-300 / neutral-700, `tag.neutral.fg` neutral-700 / neutral-400
  - `ContrastResult`는 그대로. `check_contrast`가 비활성 조합은 `MIN_DISABLED_CONTRAST = 3.0`으로 판정.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_v2_roles_follow_spec():
    roles = build_palette()["roles"]; n = build_palette()["brand"]["neutral"]
    assert roles["light"]["disabled.fg"] == n[600] and roles["dark"]["disabled.fg"] == n[500]
    assert roles["light"]["inverse.bg"] == n[900] and roles["dark"]["inverse.bg"] == n[100]
    assert roles["light"]["tag.good.bg"] == roles["light"]["badge.gwiin.bg"]

def test_composite():
    assert composite("#000000", 0.5, "#ffffff") == "#808080"
    assert composite("#47634c", 0.0, "#ffe9e5") == "#ffe9e5"

def test_contrast_covers_v2_pairs():
    names = {name for name, _, _ in _text_pairs(build_palette())}
    for mode in ("light", "dark"):
        for pair in ("tag.good", "tag.bad", "inverse", "seal.knock on seal.fill", "status",
                     "calendar.weekday.sun on bg.base", "calendar.weekday.sat on bg.base"):
            assert f"{mode} {pair}" in names
        for cell in ("bg.base", "calendar.good.bg", "calendar.caution.bg"):
            assert f"{mode} text.primary on seal.soft over {cell}" in names
        assert f"{mode} tag.neutral.fg on bg.sheet" in names

def test_seal_soft_composite_pairs_pass():
    results = {r.name: r for r in check_contrast(build_palette())}
    assert all(r.passed for name, r in results.items() if "seal.soft over" in name)

def test_disabled_pair_uses_three_to_one():
    results = {r.name: r for r in check_contrast(build_palette())}
    assert results["light disabled"].passed and results["dark disabled"].passed
    assert results["light disabled"].ratio >= 3.0
```

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 pytest docs/identity/design/tools/test_palette.py -q` / Expected: 새 테스트 FAIL.
- [ ] **Step 3: 구현** — 위 역할을 `_roles`에 추가. `_text_pairs`에 조합 추가(이름은 테스트 문자열 그대로): `tag.good`·`tag.bad`(fg/bg), `tag.neutral.fg on bg.sheet`·`on bg.base`, `inverse`, `disabled`, `status`(term.fg/term.bg), `seal.knock on seal.fill`(knock/action.primary), `calendar.weekday.sun|sat on bg.base`(ohaeng fire·earth의 모드별 ink), `text.primary on seal.soft over <바탕>`(바탕 = 그 모드의 `bg.base`·`calendar.good.bg`·`calendar.caution.bg`에 `SEAL_SOFT`를 `composite`). `check_contrast`는 이름이 `<mode> disabled`면 3.0, 나머지 4.5.
- [ ] **Step 4: 통과 확인** — 같은 명령, 그리고 `python3 docs/identity/design/tools/palette.py --check` / Expected: 모두 PASS, 대비 전부 통과. (실패하는 조합이 나오면 spec §5.3 값과 대조해 Ruling으로 기록)
- [ ] **Step 5: Commit** — `feat(design): V2 역할 색(토스트·비활성·태그·도장)과 대비 조합`

### Task 3: 토큰 1.1.0 생성

**Files:**
- Modify: `docs/identity/design/tools/tokens.py`, `docs/identity/design/tokens/*.tokens.json`(재생성), `docs/identity/design/tokens/README.md`
- Test: `docs/identity/design/tools/test_tokens.py`

**Interfaces:**
- Consumes: Task 1 타입, Task 2 역할·`SEAL_SOFT`.
- Produces (토큰 이름 — Task 5~7이 참조):
  - primitive: `motion.duration.{short:200, medium:320, select:340, long:420, stamp:520, breathe:1800, toast-hold:2500}`(ms), `motion.easing.{seep:[0.2,0.7,0.2,1], enter:[0.2,0.8,0.2,1], exit:[0.4,0,1,1], stamp-press:[0.5,0,0.9,0.6], standard:[0.4,0,0.2,1]}`, `shadow.raised`(color neutral-900 알파 0.14, offset 0/4, blur 16, spread 0)
  - color.light/dark: Task 2의 단색 역할 전부(`color.inverse.*`, `color.disabled.*`, `color.seal.knock`, `color.tag.*`), 참조 역할 `color.seal.fill → {color.action.primary}`, `color.status.bg → {color.term.bg}`, `color.status.fg → {color.term.fg}`, `color.calendar.weekday.sun → {color.ohaeng.fire.fg}`, `color.calendar.weekday.sat → {color.ohaeng.earth.fg}`, `color.timeline.line → {color.line}`, 알파 역할 `color.scrim`(라이트 neutral-950 0.32 / 다크 `#000000` 0.50), `color.bar.bg`(라이트 white 0.62 / 다크 neutral-900 0.62), `color.seal.soft`(`SEAL_SOFT`), `color.skeleton.bone`(라이트 neutral-900 0.07 / 다크 neutral-100 0.08)
  - typography(ko/ja): `type.body.ui` (ui, 14, 400, 1.5/1.5), `type.caption.lg` (ui, 13, 400, 1.45/1.45). ko 자간 규칙(-2%) 그대로.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_motion_and_shadow_tokens():
    tokens = flatten(build_token_files()["primitive.tokens.json"])
    assert tokens["motion.duration.stamp"]["$value"] == {"value": 520, "unit": "ms"}
    assert tokens["motion.easing.seep"]["$value"] == [0.2, 0.7, 0.2, 1]
    assert tokens["shadow.raised"]["$type"] == "shadow"

def test_v2_color_roles_present_in_both_modes():
    files = build_token_files()
    for mode in ("light", "dark"):
        names = flatten(files[f"color.{mode}.tokens.json"]).keys()
        for name in ("color.scrim", "color.inverse.bg", "color.disabled.fg", "color.bar.bg", "color.seal.fill",
                     "color.seal.soft", "color.seal.knock", "color.status.bg", "color.tag.good.bg",
                     "color.tag.neutral.border", "color.calendar.weekday.sun", "color.skeleton.bone", "color.timeline.line"):
            assert name in names

def test_v2_reference_roles():
    tokens = flatten(build_token_files()["color.light.tokens.json"])
    assert tokens["color.seal.fill"]["$value"] == "{color.action.primary}"
    assert tokens["color.calendar.weekday.sat"]["$value"] == "{color.ohaeng.earth.fg}"

def test_v2_type_styles():
    tokens = flatten(build_token_files()["typography.tokens.json"])
    assert tokens["type.caption.lg"]["$value"]["fontSize"] == {"value": 13, "unit": "px"}
    assert tokens["type.body.ui"]["$value"]["letterSpacing"] == {"value": -0.28, "unit": "px"}
```
그리고 `test_readme_states_version_and_lists_files`의 기대 버전을 `1.1.0`으로 바꿉니다.

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_tokens.py -q` / Expected: 새 테스트와 README 테스트 FAIL.
- [ ] **Step 3: 구현** — `tokens.py`에 상수 `MOTION_DURATIONS`, `MOTION_EASINGS`, `SHADOWS`, 알파 역할 표, 참조 역할 표, `ROLE_DESCRIPTIONS` 새 항목(한국어 한 줄), `TYPE_STYLES` 두 줄을 더하고 문서 함수에서 놓습니다. `python3 docs/identity/design/tools/tokens.py`로 다섯 파일 재생성. `tokens/README.md`: 계약 버전 줄 1.1.0, 버전 기록(1.1.0: motion·shadow·V2 역할·글자 스타일 2개 추가), 파일 표에 motion·shadow 설명.
- [ ] **Step 4: 통과 확인** — 전체 테스트 명령 / Expected: 모두 PASS(기존 83 + 새 테스트). `test_committed_files_match_generator`, `test_files_pass_dtcg_checks` 포함.
- [ ] **Step 5: Commit** — `feat(design): 디자인 토큰 1.1.0 (motion·shadow·V2 역할·글자 스타일)`

### Task 4: 컴포넌트 검사기

**Files:**
- Create: `docs/identity/design/tools/components.py`, `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Consumes: `dtcg.flatten`, `tokens.TOKENS_DIR`.
- Produces:
  - `COMPONENTS_DIR: pathlib.Path` (`docs/identity/design/components`), `IA_PATH: pathlib.Path` (`docs/ia/screens.json`)
  - `GROUPS = ("frame", "feedback", "input", "action", "sentence", "today", "calendar", "diary", "saju")`, `COMMON = ("interaction", "elements")`
  - `DOCUMENT_FIELDS = {"version", "group", "components"}` (feedback만 `stateMap` 추가 허용), `COMPONENT_FIELDS = {"id","summary","uses","variants","parts","states","motion","haptic","a11y","rules"}`
  - `load_documents(directory: pathlib.Path) -> dict[str, dict]` (파일 stem → JSON; 없는 파일은 넣지 않음)
  - `token_names_by_theme(tokens_dir: pathlib.Path) -> dict[str, set[str]]` (키 `"light-ko"`, `"light-ja"`, `"dark-ko"`, `"dark-ja"`; primitive + 색 모드 + 글자 언어 이름 합집합)
  - `find_problems(documents: dict[str, dict], ia: dict, token_names: dict[str, set[str]], directory: pathlib.Path | None = None) -> list[str]` (문제 문장 목록, 빈 목록이면 통과. `directory`가 있으면 짝 `.md`와 README 검사)
  - `main() -> int` (실제 파일 검사, 문제를 출력하고 있으면 1)
- `interaction.json` 모양: `{"version": "1.0.0", "patterns": {id: {"summary", "duration", "easing", "reduceMotion", ...}}, "haptics": {...}}`. `elements.json` 모양: `{"version": "1.0.0", "elements": {id: {"summary", ...}}}`.

- [ ] **Step 1: 실패하는 테스트 작성** — 작은 가짜 IA(`components`: `a`, `b`, `state-x`, 화면 `states`: `loading`)와 가짜 토큰 이름 세트로 문서를 만들어 검사합니다.

```python
def test_valid_documents_pass(): assert find_problems(valid_docs(), IA, TOKENS) == []
def test_missing_ia_component_is_reported(): ...  # 'b' 빠짐 → "b" 포함 문장
def test_duplicate_component_is_reported(): ...   # 'a'가 두 묶음에 → "a" 와 "두 번"
def test_unknown_component_id_is_reported(): ...  # IA에 없는 'z'
def test_unknown_field_is_reported(): ...         # "colour" 필드
def test_reference_missing_in_one_theme_is_reported():
    # {color.only-light}이 light-* 세트에만 있음 → "dark-ko"와 "dark-ja"가 문장에 들어감
def test_nested_references_are_checked():
    # variants[0].parts.label.fg, states.pressed.parts.x.bg, patterns.p.keyframes[1].color 의 {없는.토큰} 모두 보고
def test_unknown_element_or_pattern_is_reported(): ...  # uses ["없는요소"], states.pressed.pattern "없는패턴"
def test_pattern_without_reduce_motion_is_reported(): ...
def test_pattern_duration_must_be_reference(): ...      # "duration": 200 → 보고
def test_state_map_must_cover_ia_states(): ...          # stateMap에 loading 없음
def test_state_map_target_must_be_component(): ...      # {"loading": "없는-컴포넌트"}
def test_markdown_pair_and_readme(tmp_path): ...        # 짝 .md 없음, README가 파일 이름·"컴포넌트 계약 1.0.0"을 안 적음 → 보고
```
각 테스트는 반환 목록에 해당 id·이름이 든 문장이 있는지 `any(... in p for p in problems)`로 확인합니다.

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 pytest docs/identity/design/tools/test_components.py -q` / Expected: ImportError(모듈 없음).
- [ ] **Step 3: 구현** — 참조 수집은 재귀(dict 값·list 원소의 문자열에서 `{...}` 전체 일치, `dtcg.REFERENCE` 재사용). 요소·패턴 id 수집은 `elements.json["elements"]`, `interaction.json["patterns"]` 키. 검사 순서: 문서 필드 → 컴포넌트 필드 → IA id 일치(빠짐·넘침·겹침) → 참조(테마별) → uses/pattern → 패턴 필수 키(`duration`·`easing`은 참조, `reduceMotion` 있음) → stateMap → 짝 MD·README. 문제 문장은 한국어 한 줄, 대상 id·파일 이름을 포함.
- [ ] **Step 4: 통과 확인** — 같은 명령 / Expected: 모두 PASS.
- [ ] **Step 5: Commit** — `feat(design): 컴포넌트 명세 검사기`

### Task 5: 공통 명세 — interaction·elements

**Files:**
- Create: `docs/identity/design/components/interaction.json`, `interaction.md`, `elements.json`, `elements.md`
- Test: `docs/identity/design/tools/test_components.py` (실파일 테스트 추가)

**Interfaces:**
- Consumes: Task 3 토큰 이름, Task 4 검사기.
- Produces: 패턴 id `press.ink`, `appear.seep`, `disappear.seep`, `select.seep-slide`, `loading.breathe`, `seal.stamp`, `seal.erase`, `mark.underline-grow`, `sheet.enter`, `sheet.exit`, `sheet.stack`, `focus.ring`. 요소 id `seal`, `ohaeng.cell`, `ohaeng.swatch`, `tone`, `tag.status`, `tag.me`, `highlight.current`, `mark.underline-grow`(요소: 모양), `mark.caution`, `link.inline-nowrap`, `surface.paper`, `rail.timeline`, `term`, `skeleton.bone`, `icon`. (패턴과 요소에 같은 id `mark.underline-grow`가 있어도 됨 — 모양은 요소, 움직임은 패턴.)

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_common_files_define_spec_ids():
    docs = load_documents(COMPONENTS_DIR)
    assert set(docs["interaction"]["patterns"]) == {"press.ink","appear.seep","disappear.seep","select.seep-slide","loading.breathe",
        "seal.stamp","seal.erase","mark.underline-grow","sheet.enter","sheet.exit","sheet.stack","focus.ring"}
    assert set(docs["elements"]["elements"]) == {"seal","ohaeng.cell","ohaeng.swatch","tone","tag.status","tag.me","highlight.current",
        "mark.underline-grow","mark.caution","link.inline-nowrap","surface.paper","rail.timeline","term","skeleton.bone","icon"}

def test_seal_element_matches_logo():
    seal = load_documents(COMPONENTS_DIR)["elements"]["elements"]["seal"]
    assert seal["path"] == "M1.2 1.5 q8.8 -1.3 17.6 0 q1.2 8.5 0 17 q-8.8 1.3 -17.6 0 q-1.2 -8.5 0 -17 z"
    assert seal["rotate"] == -8 and set(seal["variants"]) == {"fill", "soft", "outline"}
    assert seal["path"] in (DESIGN_DIR / "logo" / "icon-large.svg").read_text()

def test_seal_stamp_pattern_values():
    p = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]["seal.stamp"]
    assert p["duration"] == "{motion.duration.stamp}"
    assert [k["offset"] for k in p["keyframes"]] == [0, 0.35, 1]
```

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 pytest docs/identity/design/tools/test_components.py -q -k "common or seal"` / Expected: FAIL(파일 없음).
- [ ] **Step 3: 작성** — 값은 spec §3.1·§3.2·§3.3·§4 그대로. 패턴마다 `summary`, `duration`/`easing` 참조, 필요하면 `keyframes`(`offset`과 속성), `reduceMotion`(`"opacity-only"` 또는 문장), `haptic`(있으면). `interaction.json`의 `haptics`: `selection`·`light`·`medium` 순간 목록. `seal`: `path`, `rotate`, `variants{fill:{color:"{color.seal.fill}", knock:"{color.seal.knock}"}, soft:{color:"{color.seal.soft}"}, outline:{color:"{color.seal.fill}", width:{value:1.6,unit:"px"}}}`, `sizes`(26·34·40·52·64와 쓰는 곳), `contentAlign: "center"`. MD는 spec 표를 풀어 쓰고 Flutter 구현 메모(§3.3, spec §9 app 항목)를 둡니다.
- [ ] **Step 4: 통과 확인** — 같은 명령 / Expected: PASS. `python3 docs/identity/design/tools/components.py`는 아직 묶음 파일이 없어 IA 빠짐을 보고해도 됩니다(Task 8에서 0이 됨).
- [ ] **Step 5: Commit** — `feat(design): 컴포넌트 공통 명세 (상호작용 패턴·요소)`

### Task 6: 범용 명세 — frame·feedback·input·action

**Files:**
- Create: `docs/identity/design/components/{frame,feedback,input,action}.{json,md}`
- Test: `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Consumes: Task 5 id, Task 3 토큰.
- Produces: 컴포넌트 id 20개 — frame: `tab-bar`, `app-bar`, `sheet`; feedback: `dialog`, `toast`, `notice-banner`, `skeleton`, `empty-state`, `error-state`; input: `input-step`, `text-field`, `date-picker`, `time-picker`, `segmented`, `city-search`, `check-row`; action: `primary-button`, `social-login-button`, `share-button`, `settings-row`. `feedback.json["stateMap"]` = `{"loading":"skeleton","empty":"empty-state","error":"error-state","offline":"notice-banner","draft":"draft-indicator","time-unknown":"notice-banner","out-of-range":"input-step"}`.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_generic_groups_contain_spec_components():
    docs = load_documents(COMPONENTS_DIR)
    ids = {g: {c["id"] for c in docs[g]["components"]} for g in ("frame","feedback","input","action")}
    assert ids["frame"] == {"tab-bar","app-bar","sheet"}
    assert ids["action"] == {"primary-button","social-login-button","share-button","settings-row"}
    assert len(ids["feedback"]) == 6 and len(ids["input"]) == 7

def test_generic_spec_values():
    c = {c["id"]: c for g in ("frame","feedback","input","action") for c in load_documents(COMPONENTS_DIR)[g]["components"]}
    assert c["primary-button"]["parts"]["container"]["radius"] == "{radius.md}"
    assert {v["id"] for v in c["primary-button"]["variants"]} == {"filled","quiet","destructive"}
    assert {v["id"] for v in c["app-bar"]["variants"]} == {"tab-root","inner"}
    assert {v["id"] for v in c["date-picker"]["variants"]} == {"birth","calendar"}
    assert {v["id"] for v in c["time-picker"]["variants"]} == {"birth","notify"}
    assert "seal" in c["tab-bar"]["uses"] and "select.seep-slide" in c["segmented"]["uses"]
    assert c["toast"]["parts"]["container"]["bg"] == "{color.inverse.bg}"
    assert "mark.caution" in json.dumps(c["dialog"])
```

- [ ] **Step 2: 실패 확인** — Run: `uv run --with pytest==8.3.5 pytest docs/identity/design/tools/test_components.py -q -k generic` / Expected: FAIL.
- [ ] **Step 3: 작성** — 값은 spec §6.1~§6.4와 §2.2 예시 그대로. 상태(`pressed`, `disabled`, `focused`, `selected`, `loading`, `error` 등)는 컴포넌트에 해당하는 것만. 햅틱은 spec §3.2. 접근성: 역할, 라벨 규칙, `minTarget` 44 또는 48. MD는 묶음마다: 컴포넌트별 설명, 상태 표, 배치 규칙, 쓰는 화면(IA), Material 대응 힌트(참고), 시안 id(Task 10의 `design-v2-*`).
- [ ] **Step 4: 통과 확인** — 같은 명령 / Expected: PASS.
- [ ] **Step 5: Commit** — `feat(design): 범용 컴포넌트 명세 (frame·feedback·input·action)`

### Task 7: 브랜드 명세 — sentence·today·calendar·diary·saju

**Files:**
- Create: `docs/identity/design/components/{sentence,today,calendar,diary,saju}.{json,md}`
- Test: `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Consumes: Task 5 id, Task 3 토큰.
- Produces: 컴포넌트 id 19개 — sentence: `sentence-block`, `term-token`, `depth-link`, `reaction-button`; today: `day-character`, `lucky-card`, `guide-question-card`, `share-image`; calendar: `calendar-month`, `day-cell`, `event-row`; diary: `diary-row`, `diary-editor`, `draft-indicator`, `tag-chip`; saju: `saju-pillars`, `ohaeng-bar`, `manse-table`, `daeun-table`.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_brand_spec_values():
    c = {c["id"]: c for g in ("sentence","today","calendar","diary","saju") for c in load_documents(COMPONENTS_DIR)[g]["components"]}
    assert {v["id"] for v in c["share-image"]["variants"]} == {"story","feed","square"}
    assert {v["id"] for v in c["term-token"]["variants"]} >= {"inline","label"} and "locked" in json.dumps(c["term-token"])
    assert {v["id"] for v in c["event-row"]["variants"]} == {"summary","list"}
    assert {v["id"] for v in c["lucky-card"]["variants"]} == {"color","direction","number","time"}
    assert set(c["guide-question-card"]["states"]) >= {"before","after"}
    assert set(c["draft-indicator"]["states"]) == {"local","saving","saved"}
    day = json.dumps(c["day-cell"])
    assert "{color.seal.soft}" in day and "outline" in day and "mark.underline-grow" in day
    assert "{color.tag.good.bg}" in json.dumps(c["tag-chip"]) and "tone" in c["tag-chip"]["uses"]
    assert "link.inline-nowrap" in json.dumps(c["depth-link"])
    assert "tag.me" in c["saju-pillars"]["uses"] and "highlight.current" in c["daeun-table"]["uses"]
    assert "surface.paper" in c["diary-editor"]["uses"] and "rail.timeline" in c["diary-row"]["uses"]
```

- [ ] **Step 2: 실패 확인** — Run: `... -k brand` / Expected: FAIL.
- [ ] **Step 3: 작성** — 값은 spec §6.5~§6.9 그대로. day-cell의 표시 우선(겹침 순서: 길흉 바탕 → 일기 도장 soft → 오늘 윤곽 → 숫자 → 선택 밑줄 → 일정 점), event-row summary의 상태 결정 규칙(진행 중 > 다음 > 모두 지남, 하루 종일은 진행 중이지만 시각 있는 진행 중·다음 일정이 앞섬), diary-editor 저장 순서(spec §6.8)를 `rules`에 적습니다. MD에 사주 표 "표준 배치 + 차별은 깊이·풀이·시각 언어" 원칙과 잠김 변형(#32) 설명.
- [ ] **Step 4: 통과 확인** — 같은 명령 / Expected: PASS.
- [ ] **Step 5: Commit** — `feat(design): 브랜드 컴포넌트 명세 (문장·오늘·달력·일기·사주)`

### Task 8: 계약 설명과 실파일 검사

**Files:**
- Create: `docs/identity/design/components/README.md`
- Test: `docs/identity/design/tools/test_components.py`

**Interfaces:**
- Consumes: Task 4 `main`/`find_problems`, Task 5~7 파일.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_committed_component_files_pass_all_checks():
    ia = json.loads(IA_PATH.read_text(encoding="utf-8"))
    problems = find_problems(load_documents(COMPONENTS_DIR), ia, token_names_by_theme(TOKENS_DIR), COMPONENTS_DIR)
    assert problems == []

def test_cli_exit_code_is_zero():
    assert components.main() == 0
```

- [ ] **Step 2: 실패 확인** — Expected: README 없음으로 FAIL.
- [ ] **Step 3: 작성** — `README.md`: 첫머리에 "컴포넌트 계약 1.0.0"과 토큰 계약 1.1.0 기대, 읽는 법(JSON은 사실·MD는 설명, `{토큰}` 표기, `uses`·`pattern`), 파일 표(11개 JSON 이름 전부), 버전 규칙(spec §2.1), 공통 규칙(spec §2.3), 검사 명령 `python3 docs/identity/design/tools/components.py`. 실파일 검사에서 나온 문제는 해당 JSON을 고쳐 0으로 만듭니다.
- [ ] **Step 4: 통과 확인** — 전체 테스트 명령, `python3 docs/identity/design/tools/components.py`(문제 없음, 종료 0), `python3 tools/docs-check/docs_check.py`(OK).
- [ ] **Step 5: Commit** — `docs(design): 컴포넌트 계약 설명 1.0.0`

### Task 9: 기준 문서·결정·견본·CLAUDE.md

**Files:**
- Modify: `docs/identity/design/visual-identity.md`, `docs/identity/design/decisions.md`, `docs/identity/design/specimen/index.html`, `docs/identity/design/CLAUDE.md`
- Test: `docs/identity/design/tools/test_specimen.py`

- [ ] **Step 1: 실패하는 테스트 작성** (`test_specimen.py`)

```python
def test_specimen_has_v2_section():
    html = SPECIMEN.read_text(encoding="utf-8")
    assert 'id="v2-elements"' in html
    for element in ("seal-fill", "seal-soft", "seal-outline", "tag-good", "tag-bad", "tag-neutral", "status-tag"):
        assert f'data-element="{element}"' in html
```
(파일 상단의 기존 경로 상수 이름을 그대로 씁니다.)

- [ ] **Step 2: 실패 확인** — Expected: FAIL.
- [ ] **Step 3: 작성**
  - `specimen/index.html`: V2 절 `id="v2-elements"` — 낙관 도장 세 변형(라이트·다크 변수), 태그 칩 세 톤, 상태 꼬리표, 경고 표시 자리, 패턴 이름 목록과 `components/` 링크. 새 역할 CSS 변수를 라이트·다크·prefers-color-scheme 세 블록에 추가(`test_specimen_role_variables_match_palette`가 새 역할도 확인하면 그 값과 맞춤).
  - `visual-identity.md`: 제목 "(V0·V1·V2)", 아이콘(Phosphor·Light/Regular·경고 표시만 Fill), 낙관 도장 요소, 상호작용 언어 요약 표(spec §3.1), 요일 오행색, "그림자와 모션 토큰은 두지 않습니다" 문장을 1.1.0 내용으로 교체, 반경 표 `radius.md` 쓰임을 "버튼, 입력창"으로 유지하되 실제 쓰임 확인, 새 글자 스타일 두 줄, 새 역할 색 표.
  - `decisions.md`: V13~V22 한 줄씩(spec §8의 주제, 날짜 2026-10-11, 근거 "사용자 결정 (V2 brainstorming)", 시안 id).
  - `CLAUDE.md`: 현재 상태 첫 항목을 V2(브랜치 `design/components`, 컴포넌트 계약 1.0.0, 토큰 1.1.0, 검사 명령)로, 산출물 표의 컴포넌트 명세 행 위치 `components/`, 계약 표 토큰 1.1.0·컴포넌트 명세 1.0.0, 다음 할 일(지휘 회신 #31·#35, M0 #32, W1 일본어 줄 간격).
- [ ] **Step 4: 통과 확인** — 전체 테스트, 대비 검사, docs 검사 / Expected: 모두 통과.
- [ ] **Step 5: Commit** — `docs(design): V2 기준 문서·결정 V13~V22·견본`

### Task 10: 시안 기록과 전달 Issue 본문

**Files:**
- Create: `docs/identity/design/artifacts/2026-10-11-v2-*.html`, `*.png`
- Modify: `docs/identity/design/artifacts/index.json`
- Create (git 제외): `.suberpowers/issues/v2-notice-app.md`, `.suberpowers/issues/v2-report-root.md`

- [ ] **Step 1: 시안 HTML 만들기** — 아래 원본(`.suberpowers/brainstorm/73008-1791650272/content/`)을 V1과 같은 방식(brainstorm frame template로 감싼 독립 HTML, `/files/lockup.svg`는 `../logo/lockup.svg`로)으로 `artifacts/2026-10-11-v2-<이름>.html`에 둡니다.

| id | 원본 | 상태 | 결정 |
| --- | --- | --- | --- |
| `design-v2-press-feedback` | v2-press-feedback.html | chosen(B 먹 번짐) | V14 |
| `design-v2-appear` | v2-appear.html | chosen(B 스밈) | V14 |
| `design-v2-select` | v2-select-v2.html | chosen(15%) | V14 |
| `design-v2-skeleton` | v2-skeleton.html | chosen(B) | V14 |
| `design-v2-focus` | v2-focus-v2.html | chosen(A) | V14 |
| `design-v2-frame` | v2-frame.html | chosen(C) | V17 |
| `design-v2-kit` | v2-kit.html | chosen(둥근 사각) | V13 |
| `design-v2-caution-mark` | v2-caution-mark-v2.html | superseded(B 모양만 채택, Phosphor로 대체) | V18 |
| `design-v2-icon-sets` | v2-icon-sets.html | chosen(Phosphor) | V15 |
| `design-v2-tab-seal` | v2-tab-brand.html | chosen(B 낙관 도장) | V15·V16 |
| `design-v2-stamp-easing` | v2-stamp-easing.html | chosen(C) | V16 |
| `design-v2-birth-date` | v2-birth-date.html | chosen(A) | V13 |
| `design-v2-birth-time` | v2-birth-time.html | chosen(A) | V13 |
| `design-v2-sheet` | v2-sheet-close.html | chosen(A, 닫기 1) | V17 |
| `design-v2-today` | v2-today-heart.html | chosen(0-나, 하트 아래) | V20 |
| `design-v2-calendar-alternatives` | v2-calendar-v3.html | superseded | V19 |
| `design-v2-calendar` | v2-calendar-full-v5.html | chosen | V19 |
| `design-v2-diary-save` | v2-diary-long.html | chosen(3) | V20 |
| `design-v2-diary-list` | v2-diary-rows-mix.html | chosen(가) | V20 |
| `design-v2-tag-chip` | v2-diary-list.html | chosen(B) | V20 |
| `design-v2-saju-pillars` | v2-saju-pillars.html | chosen(A) | V21 |
| `design-v2-saju-manse` | v2-saju-manse.html | chosen(A) | V21 |
| `design-v2-saju-flow` | v2-saju-flow.html | chosen | V21 |
| `design-v2-share-image` | v2-share-image.html | chosen(세 비율) | V22 |
| `design-v2-rest` | v2-rest.html | chosen | V19·V20·V21·V22 |

- [ ] **Step 2: PNG 캡처** — 저장소 루트 HTTP 서버 + Playwright로 각 HTML을 1280px 폭 전체 페이지 캡처(`2026-10-11-v2-<이름>.png`). 끝나면 `.playwright-mcp/`를 지웁니다.
- [ ] **Step 3: `index.json` 등록** — 위 표 25개를 V1 항목과 같은 키(`id`, `title`, `kind`, `file`, `source`, `date`, `milestone: "V2"`, `screens`, `decisions`, `status`, `note`)로 추가. `screens`는 IA 화면 id. `kind`는 V1에서 쓴 값 중 맞는 것.
- [ ] **Step 4: Issue 본문 초안** — `.suberpowers/issues/v2-notice-app.md`(spec §9 app 항목: 계약·토큰 1.1.0·Phosphor·구현 메모·성능 확인), `.suberpowers/issues/v2-report-root.md`(V2 완료, 계약 목록 갱신, 로드맵 V2 완료, 열린 #31·#32·#35). PR 번호 자리는 마무리 때 채웁니다(Ruling).
- [ ] **Step 5: 확인과 Commit** — 전체 테스트·docs 검사 통과 / Commit `docs(design): V2 시안 기록`

---

## Self-Review 메모
* spec §1~§10 → Task 1~3(§5), 4·8(§7), 5(§3·§4), 6(§6.1~6.4), 7(§6.5~6.9), 9(§8 문서), 10(§8 산출물·§9 본문). §9의 Issue 생성·PR은 마무리 단계(finishing)에서 합니다.
* 이름 일치: 토큰 이름은 Task 3 Produces, 요소·패턴 id는 Task 5 Produces를 Task 6·7 테스트가 그대로 씁니다.

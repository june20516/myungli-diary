# 마일스톤 V1 디자인 토큰 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** V0 값과 V1 새 값(배지 3종, 캘린더 칸 채우기, 타이포 추가, 간격·반경)을 DTCG 토큰 파일 다섯 개로 생성해 계약 1.0.0으로 동결합니다.

**Architecture:**
* `palette.py`가 색의 단일 출처입니다. 이번에 새 역할과 대비 조합을 더합니다.
* 새 `tools/tokens.py`(표준 라이브러리만)가 그 결과와 타이포·간격·반경 상수로 `tokens/*.tokens.json`을 씁니다.
* 새 `tools/dtcg.py`는 토큰 문서를 펼치고, 참조를 풀고, 형식 문제를 찾습니다. 테스트가 이것으로 커밋된 파일을 검사합니다.
* 견본 페이지와 기준 문서는 손으로 고치고, 색은 테스트가 지킵니다.

**Tech Stack:** Python 3.13 표준 라이브러리, pytest 8.3.5(`uv run --with`), 정적 HTML/CSS, Playwright MCP(PNG 캡처), `gh` CLI(Issue).

**Spec:** [`../specs/2026-10-11-design-tokens-design.md`](../specs/2026-10-11-design-tokens-design.md)

## Global Constraints

* **고칠 수 있는 곳:** `docs/identity/design/` 아래만 고칩니다. 그 밖은 GitHub Issue로만 주고받습니다.
* **의존성:** 저장소에 의존성 파일을 추가하지 않습니다. 외부 패키지는 `uv run --with <패키지>==<버전>`으로만 씁니다.
* **테스트 명령(이하 `TEST`):** 저장소 루트에서 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`
* **값 표기:**
  * hex는 소문자 7자(`#rrggbb`)입니다. 알파는 hex에 넣지 않고 DTCG `alpha`로 적습니다.
  * 치수 단위는 `px`만 씁니다.
  * 확장 키는 `myungli-diary` 하나입니다.
* **대비:** 글자 조합 대비 기준은 4.5:1이고, 반올림하지 않은 값으로 비교합니다(V0 그대로).
* **토큰 출력:** `json.dumps(document, indent=2, ensure_ascii=False) + "\n"`입니다. 키 순서는 생성기가 만드는 삽입 순서이고, 토큰 안에서는 `$type`, `$value`, `$description`, `$extensions` 순입니다.
* **표기 규칙(D46):** 결정은 "결정 V8"처럼, 마일스톤은 "마일스톤 V1"처럼 종류를 앞에 붙입니다.
* **commit:**
  * 범위 표기는 `feat(design)` / `docs(design)` / `fix(design)`입니다.
  * 메시지 끝에 다음 두 줄을 붙입니다.
    ```
    Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_018daG4i4NbX9EUgB9r3hqLm
    ```
* **시각 산출물:** workflow §7을 따릅니다. HTML에는 같은 이름 PNG를 두고, `index.json`을 갱신하며, 이미지는 2MB 이하입니다.

## Review Focus

1. **원시 팔레트에 없는 hex인 역할 값**(예: 나중에 손으로 넣은 색): 생성기는 참조 대신 값을 직접 적습니다. 멈추거나, 엉뚱한 단계를 참조하면 안 됩니다.
2. **같은 hex를 가진 원시 단계가 둘 이상일 때:** 참조는 매번 같은 단계를 고르고, 풀었을 때 원래 hex와 같아야 합니다.
3. **알파가 있는 색**(`chip.bg`, `swatch.border`): `hex`는 6자리, `alpha`는 0~1 숫자, `components`는 hex와 일치해야 합니다.
4. **두 파일이 같은 토큰 이름을 정의할 때:** 검사기가 그 이름과 두 파일을 알려 줍니다.
5. **오타 난 참조**(`{color.sage.705}`): 검사기가 참조한 토큰 이름과 깨진 참조를 알려 줍니다.

---

### Task 1: palette.py에 V1 역할과 대비 조합 추가

**Files:**
- Modify: `docs/identity/design/tools/palette.py` (`_roles`, `_text_pairs`, 모듈 docstring의 spec 경로에 V1 spec 추가)
- Test: `docs/identity/design/tools/test_palette.py`

**Interfaces:**
- Produces: `build_palette()["roles"][mode]`에 다음 키가 더해집니다. 값은 hex 문자열입니다.
  - `badge.gwiin.bg`, `badge.gwiin.fg`, `badge.gisin.bg`, `badge.gisin.fg`
  - `badge.ordinary.border`, `badge.ordinary.fg`
  - `calendar.good.bg`, `calendar.caution.bg`
- 대비 조합 이름 형식은 기존과 같고(`"<mode> <조합>"`), 총 52개입니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`test_palette.py`에 추가)

```python
V1_ROLES = {
    "light": {"badge.gwiin.bg": ("coral", 100), "badge.gwiin.fg": ("coral", 700),
              "badge.gisin.bg": ("neutral", 100), "badge.gisin.fg": ("neutral", 700),
              "badge.ordinary.border": ("neutral", 300), "badge.ordinary.fg": ("neutral", 700),
              "calendar.good.bg": ("coral", 100), "calendar.caution.bg": ("neutral", 100)},
    "dark": {"badge.gwiin.bg": ("coral", 800), "badge.gwiin.fg": ("coral", 200),
             "badge.gisin.bg": ("neutral", 800), "badge.gisin.fg": ("neutral", 200),
             "badge.ordinary.border": ("neutral", 700), "badge.ordinary.fg": ("neutral", 400),
             "calendar.good.bg": ("coral", 900), "calendar.caution.bg": ("neutral", 900)},
}

def test_v1_roles_follow_spec():
    palette = build_palette()
    for mode, roles in V1_ROLES.items():
        for role, (scale, step) in roles.items():
            assert palette["roles"][mode][role] == palette["brand"][scale][step], (mode, role)

def test_contrast_covers_v1_pairs():
    names = {result.name for result in check_contrast(build_palette())}
    assert len(names) == 52
    for mode in ("light", "dark"):
        assert f"{mode} badge.gwiin" in names
        assert f"{mode} badge.gisin" in names
        for background in ("bg.base", "bg.sheet", "gradient[0]", "gradient[1]"):
            assert f"{mode} badge.ordinary.fg on {background}" in names
        for text_role in ("text.primary", "text.secondary"):
            for cell in ("calendar.good.bg", "calendar.caution.bg"):
                assert f"{mode} {text_role} on {cell}" in names
```

기존 테스트 중 "32/32"처럼 개수를 고정한 assertion은 52로 바꿉니다.

- [ ] **Step 2: 실패 확인**

Run: `TEST -k "v1 or contrast"`
Expected: FAIL. `KeyError: 'badge.gwiin.bg'`, 그리고 개수 불일치.

- [ ] **Step 3: `_roles`에 위 표의 값, `_text_pairs`에 새 조합 추가**

- [ ] **Step 4: 통과 확인**

Run: `TEST`와 `python3 docs/identity/design/tools/palette.py --check`
Expected: 전부 통과, 마지막 줄은 `52/52 조합 통과 (기준 4.5:1)`.

- [ ] **Step 5: Commit** — `feat(design): V1 배지·캘린더 역할과 대비 조합 추가`

---

### Task 2: DTCG 검사기 `dtcg.py`

**Files:**
- Create: `docs/identity/design/tools/dtcg.py`
- Test: `docs/identity/design/tools/test_dtcg.py`

**Interfaces:**
- Produces:
  - `flatten(document: dict) -> dict[str, dict]`: 점으로 이은 토큰 이름 → 토큰 객체. `$`로 시작하는 키는 그룹 속성으로 보고 건너뜁니다.
  - `find_problems(documents: dict[str, dict]) -> list[str]`: 파일 이름 → 문서. 문제를 사람이 읽는 한 줄씩 돌려줍니다. 빈 목록이면 통과입니다.
  - `resolve(name: str, tokens: dict[str, dict]) -> object`: 참조를 끝까지 따라가 `$value`를 돌려줍니다. 순환하거나 없는 참조면 `KeyError`입니다.
  - `ALLOWED_TYPES = {"color", "dimension", "fontFamily", "typography", "gradient"}`

- [ ] **Step 1: 실패하는 테스트 작성**

`find_problems`가 아래 각각을 잡고, 메시지에 이름이 들어 있는지 확인합니다. 정상 문서 하나는 빈 목록이어야 합니다.

| 테스트 | 입력 | 메시지에 들어 있어야 하는 것 |
| --- | --- | --- |
| `test_clean_documents_have_no_problems` | 정상 문서 | (빈 목록) |
| `test_reports_missing_type` | `$type`이 없는 토큰 | 토큰 이름 |
| `test_reports_unknown_type` | `$type: "shadow"` | `shadow` |
| `test_reports_broken_reference` (Review Focus 5) | `{color.sage.705}` 참조 | 참조한 토큰 이름, `color.sage.705` |
| `test_reports_name_defined_in_two_files` (Review Focus 4) | 두 파일이 같은 이름 정의 | 이름, 두 파일 이름 |
| `test_reports_hex_components_mismatch` | `hex` `#ffffff`, `components` `[0,0,0]` | 토큰 이름 |
| `test_reports_alpha_out_of_range` (Review Focus 3) | `alpha: 1.5` | 토큰 이름 |
| `test_reports_non_px_dimension` | `unit: "rem"` | 토큰 이름 |
| `test_reports_token_that_is_also_group` | `$value`와 하위 토큰이 함께 있는 객체 | 토큰 이름 |
| `test_resolve_follows_reference_chain` | a → b → 값 | `resolve`가 값을 돌려줌 |
| `test_resolve_rejects_cycle` | a → b → a | `KeyError` |

`components`는 hex 각 채널/255를 소수 넷째 자리에서 반올림한 값과 같아야 일치로 봅니다. 참조 검사는 모든 문서를 합친 이름 집합에서 합니다. 참조는 `$value` 자체이거나, typography 하위 값이거나, gradient stop의 `color`일 수 있습니다.

- [ ] **Step 2: 실패 확인**

Run: `TEST -k dtcg`
Expected: FAIL. `ModuleNotFoundError: No module named 'dtcg'`

- [ ] **Step 3: `dtcg.py` 구현** (위 Interfaces 그대로)

- [ ] **Step 4: 통과 확인**

Run: `TEST`
Expected: 전부 통과.

- [ ] **Step 5: Commit** — `feat(design): DTCG 토큰 검사기`

---

### Task 3: 토큰 생성기 `tokens.py`와 토큰 파일

**Files:**
- Create: `docs/identity/design/tools/tokens.py`
- Create (생성기가 씀):
  - `docs/identity/design/tokens/primitive.tokens.json`
  - `docs/identity/design/tokens/color.light.tokens.json`, `color.dark.tokens.json`
  - `docs/identity/design/tokens/typography.tokens.json`, `typography.ja.tokens.json`
- Test: `docs/identity/design/tools/test_tokens.py`

**Interfaces:**
- Consumes: `palette.build_palette()` (Task 1의 역할 포함), `dtcg.flatten`, `dtcg.find_problems`, `dtcg.resolve`
- Produces:
  - `TOKENS_DIR: pathlib.Path` (= `DESIGN_DIR / "tokens"`)
  - `color_value(hex_color: str, alpha: float | None = None) -> dict`: `{"colorSpace": "srgb", "components": [...], "hex": ...}`이고, 알파가 있으면 `"alpha"`를 더합니다.
  - `reference_or_value(hex_color: str, primitives: dict[str, str]) -> str | dict`: `primitives`는 원시 토큰 이름 → hex입니다. 같은 hex가 있으면 `"{이름}"`을 돌려주고, 여럿이면 이름순으로 첫 번째입니다. 없으면 `color_value(hex)`입니다.
  - `build_token_files() -> dict[str, dict]`: 파일 이름(위 다섯 개) → 문서
  - `serialize(document: dict) -> str`
  - `main() -> None`: `TOKENS_DIR`에 다섯 파일을 쓰고 경로를 출력합니다.

**값 (spec에서 그대로)**

- **primitive:**
  - `color.{sage,coral,neutral}.<단계>`
  - `color.white` = `#ffffff`
  - `color.ohaeng.<wood|fire|earth|metal|water>.swatch`
  - `space.{2,4,8,12,16,20,24,32,48}`
  - `radius.xs 4`, `sm 8`, `md 12`, `lg 20`, `xl 28`, `full 9999`
- **color.light / color.dark:**
  - `color.<역할>`: 역할 이름의 점이 그대로 그룹이 됩니다. 예: `color.badge.gwiin.bg`
  - `color.chip.bg`: `#ffffff`에 alpha 0.70(라이트) / 0.08(다크)
  - `color.swatch.border`: neutral-900에 alpha 0.18(라이트) / neutral-100에 alpha 0.28(다크)
  - `color.ohaeng.<오행>.bg/.fg`: 라이트는 `tint`/`ink`, 다크는 `tint_dark`/`ink_dark`
  - `gradient.today`: stop 두 개, position 0과 1, `$extensions` `{"myungli-diary": {"angle": 160}}`
- **typography / typography.ja:** spec §4.1의 `font.family.*`와 §4.2의 `type.*` 표 그대로입니다.
  - `fontFamily`는 `{font.family.<sentence|ui|hanja>}` 참조입니다.
  - 자간은 ko·en의 ui 스타일만 `round(fontSize * -0.02, 2)`이고, 그 밖은 0입니다.
  - `numeric.calendar`와 `numeric.table`에는 `$extensions` `{"myungli-diary": {"fontFeatures": ["tnum"]}}`를 붙입니다.
- **설명:** `$description`은 역할마다 한 줄씩 붙입니다(`visual-identity.md` 역할 표의 설명). `gradient.today`에는 "데일리 카드·온보딩·공유 이미지에만 씁니다. 단색으로 바뀌어도 깨지지 않게 씁니다"를 적습니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
FILES = ["primitive.tokens.json", "color.light.tokens.json", "color.dark.tokens.json",
         "typography.tokens.json", "typography.ja.tokens.json"]

def test_committed_files_match_generator():
    for name, document in build_token_files().items():
        assert (TOKENS_DIR / name).read_text(encoding="utf-8") == serialize(document), name

def test_generator_is_deterministic():
    assert {k: serialize(v) for k, v in build_token_files().items()} == \
           {k: serialize(v) for k, v in build_token_files().items()}

def test_files_pass_dtcg_checks():
    files = build_token_files()
    assert sorted(files) == sorted(FILES)
    assert find_problems(files) == []

def test_paired_files_have_same_names():
    files = build_token_files()
    assert flatten(files["color.light.tokens.json"]).keys() == flatten(files["color.dark.tokens.json"]).keys()
    assert flatten(files["typography.tokens.json"]).keys() == flatten(files["typography.ja.tokens.json"]).keys()

def test_resolved_roles_match_palette():  # Review Focus 2
    files, palette = build_token_files(), build_palette()
    for mode in ("light", "dark"):
        tokens = {**flatten(files["primitive.tokens.json"]), **flatten(files[f"color.{mode}.tokens.json"])}
        for role, hex_color in palette["roles"][mode].items():
            assert resolve(f"color.{role}", tokens)["hex"] == hex_color, (mode, role)

def test_unknown_hex_is_written_as_value():  # Review Focus 1
    assert reference_or_value("#123456", {"color.sage.50": "#f2f9f3"}) == color_value("#123456")

def test_duplicate_hex_picks_first_name():  # Review Focus 2
    assert reference_or_value("#ffffff", {"color.white": "#ffffff", "color.a": "#ffffff"}) == "{color.a}"

def test_alpha_colors():  # Review Focus 3
    light = flatten(build_token_files()["color.light.tokens.json"])
    assert light["color.chip.bg"]["$value"] == color_value("#ffffff", 0.7)
    assert light["color.swatch.border"]["$value"]["alpha"] == 0.18

def test_typography_values():
    ko = flatten(build_token_files()["typography.tokens.json"])
    ja = flatten(build_token_files()["typography.ja.tokens.json"])
    assert ko["type.sentence.card"]["$value"]["lineHeight"] == 1.65
    assert ja["type.sentence.card"]["$value"]["lineHeight"] == 1.75
    assert ja["type.sentence.body"]["$value"]["lineHeight"] == 1.7
    assert ko["type.label.lg"]["$value"]["letterSpacing"] == {"value": -0.28, "unit": "px"}
    assert ja["type.label.lg"]["$value"]["letterSpacing"] == {"value": 0, "unit": "px"}
    assert ko["type.numeric.calendar"]["$extensions"] == {"myungli-diary": {"fontFeatures": ["tnum"]}}
    assert ko["font.family.sentence"]["$value"] == ["Gowun Dodum", "Pretendard", "sans-serif"]
    assert ja["font.family.ui"]["$value"] == ["Pretendard JP", "sans-serif"]
```

- [ ] **Step 2: 실패 확인**

Run: `TEST -k tokens`
Expected: FAIL. `ModuleNotFoundError: No module named 'tokens'`

- [ ] **Step 3: `tokens.py` 구현**

토큰 객체는 `{"$type": ..., "$value": ...}`이고, 필요하면 `$description`, `$extensions` 순으로 더합니다. 그룹마다 `$type`을 두지 않고 토큰마다 적습니다. 그래야 app이 파일 하나만 읽어도 타입을 압니다.

- [ ] **Step 4: 파일 생성**

Run: `python3 docs/identity/design/tools/tokens.py`
Expected: 다섯 경로가 출력됩니다.

- [ ] **Step 5: 통과 확인**

Run: `TEST`
Expected: 전부 통과.

- [ ] **Step 6: Commit** — `feat(design): DTCG 토큰 생성기와 토큰 파일 (계약 1.0.0)`

---

### Task 4: 계약 설명 `tokens/README.md`

**Files:**
- Create: `docs/identity/design/tokens/README.md`
- Test: `docs/identity/design/tools/test_tokens.py` (추가)

**Interfaces:**
- Consumes: Task 3의 파일 이름 다섯 개

**담을 것:**
1. 첫 줄 아래에 `계약 버전: 1.0.0` 줄
2. 파일 표(spec §6.2)
3. 조합법: `primitive` + 색 모드 하나 + 글자 언어 하나. 영어는 한국어 파일
4. 형식 요약: 색·치수·참조·typography·gradient 각도 확장·`fontFeatures` 확장(spec §6.1)
5. 버전 규칙(spec §6.3)
6. app이 맡는 것: Dart 코드 생성, 알파 색 처리, 시스템 글자 크기(기기 설정을 따르고, 고정 칸만 상한, 상한 값은 V2)
7. 다시 만드는 법: `python3 docs/identity/design/tools/tokens.py`. 토큰 파일을 손으로 고치지 않습니다.
8. 길흉 표시 규칙: 칸 채우기, `NEUTRAL`은 토큰 없음, 색 외의 전달 수단은 V2

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_readme_states_version_and_lists_files():
    readme = (TOKENS_DIR / "README.md").read_text(encoding="utf-8")
    assert "계약 버전: 1.0.0" in readme
    for name in FILES:
        assert name in readme
```

- [ ] **Step 2: 실패 확인**

Run: `TEST -k readme`
Expected: FAIL. `FileNotFoundError`

- [ ] **Step 3: README 작성** (위 8항목)

- [ ] **Step 4: 통과 확인**

Run: `TEST`
Expected: 전부 통과.

- [ ] **Step 5: Commit** — `docs(design): 디자인 토큰 계약 설명`

---

### Task 5: 견본 페이지 V1 판

**Files:**
- Modify: `docs/identity/design/specimen/index.html`
- Test: `docs/identity/design/tools/test_specimen.py`

**Interfaces:**
- Consumes: Task 1의 역할 키

**바꿀 것:**
1. **CSS 변수:** `:root`에 `--role-<mode>-<역할의 점을 ->`로 바꾼 이름>` 변수를 V1 역할 8개에 대해 더합니다. 값은 `var(--<scale>-<step>)`입니다.
   * `.mode-light`/`.mode-dark`/`prefers-color-scheme` 블록에도 짧은 이름 변수를 더합니다(기존 패턴과 같음).
2. **새 섹션 4개:** 기존 "그라데이션" 섹션 뒤에 둡니다.
   * **날의 성격 배지:** 4종을 그라데이션 위에 놓습니다. 강도 순서를 한 줄로 설명합니다.
   * **캘린더 길흉:** 7×3 날짜 칸에 좋음·보통·주의 칸 채우기를 보여주고, 범례를 둡니다.
   * **일본어 줄 간격:** Zen Maru Gothic으로 카드 1.75 / 본문 1.7 예문을 넣고, 한국어 1.65 / 1.6과 나란히 놓습니다. Google Fonts `Zen+Maru+Gothic`을 링크합니다.
   * **간격·반경:** `space.*` 막대와 `radius.*` 모서리 견본을 둡니다.
3. **타이포 섹션:** `type.*` 표(spec §4.2)로 바꿉니다.
4. **문구:** "V1에서 정합니다" 같은 남은 문구를 지웁니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_specimen_role_variables_match_palette():
    html = SPECIMEN.read_text()
    variables = css_vars(html)
    references = dict(re.findall(r"(--role-[\w-]+):\s*var\((--[\w-]+)\)", html))
    for mode, roles in build_palette()["roles"].items():
        for role, hex_value in roles.items():
            name = f"--role-{mode}-{role.replace('.', '-')}"
            assert name in references, name
            assert variables[references[name]] == hex_value, name
```

- [ ] **Step 2: 실패 확인**

Run: `TEST -k specimen`
Expected: FAIL. `--role-light-badge-gwiin-bg`가 없습니다.

- [ ] **Step 3: 견본 수정** (위 "바꿀 것")

- [ ] **Step 4: 통과 확인**

Run: `TEST`
Expected: 전부 통과. 기존의 "팔레트 밖 색 없음" 테스트도 포함합니다.

- [ ] **Step 5: 눈으로 확인**

`python3 -I -m http.server 53999`(저장소 루트, 백그라운드)를 띄우고, Playwright로 `http://localhost:53999/docs/identity/design/specimen/index.html`을 라이트·다크로 엽니다. 확인할 것:
- 새 섹션 4개가 보이는지
- 다크에서 글자가 읽히는지
- 일본어 예문이 Zen Maru Gothic으로 렌더링되는지

- [ ] **Step 6: Commit** — `feat(design): 견본 페이지 V1 판 (배지·캘린더·일본어·간격)`

---

### Task 6: 시안 기록 `artifacts/`

**Files:**
- Create: `docs/identity/design/artifacts/` 아래 HTML·PNG 쌍 네 개와 견본 PNG 두 개

  | 원본 (`.suberpowers/brainstorm/16536-1791643845/content/`) | 산출물 |
  | --- | --- |
  | `v1-day-badges-luck-dots.html` | `2026-10-11-v1-day-badges-luck-dots.{html,png}` |
  | `v1-luck-cell-tint.html` | `2026-10-11-v1-luck-cell-tint.{html,png}` |
  | `v1-color-meaning.html` | `2026-10-11-v1-color-meaning.{html,png}` |
  | `v1-ja-line-height.html` | `2026-10-11-v1-ja-line-height.{html,png}` |
  | 견본 페이지 | `2026-10-11-v1-specimen.png`, `2026-10-11-v1-specimen-dark.png` |

- Modify: `docs/identity/design/artifacts/index.json`
- Test: 없음(지휘 세션의 `ci-gate` artifacts 검증과, 아래 Step의 JSON 검사)

- [ ] **Step 1: HTML 만들기**

V0 산출물과 같은 방식으로 만듭니다. `~/.claude/plugins/cache/suberpower/suberpower/2.0.0/skills/brainstorming/scripts/frame-template.html`의 `<!-- CONTENT -->`를 각 fragment로 바꾸고, `<title>`을 시안 제목으로 바꿉니다.

- [ ] **Step 2: PNG 캡처**

HTTP 서버와 Playwright로 각 HTML을 열어 전체 페이지를 캡처하고, 견본은 라이트·다크 둘 다 캡처합니다. 각 PNG는 2MB 이하입니다. 다 찍으면 `.playwright-mcp/`를 지웁니다.

- [ ] **Step 3: `index.json`에 항목 다섯 개 추가**

기존 필드 형식을 따릅니다. `milestone`은 `"V1"`, `screens`는 `[]`입니다.

| id | kind | decisions | status | note |
| --- | --- | --- | --- | --- |
| `design-v1-day-badges-luck-dots` | `concept` | `["V10"]` | `superseded` | 점 방식(A/B/C)과 귀인 sage 안. 점은 이벤트로 읽혀 칸 채우기로, 귀인은 결정 V8에 따라 coral로 바뀜 |
| `design-v1-luck-cell-tint` | `concept` | `["V10"]` | `chosen` | A(아주 옅게) 채택. B는 확인해야 할 무언가가 있는 느낌이라 탈락 |
| `design-v1-color-meaning` | `concept` | `["V8", "V10"]` | `chosen` | sage=나와 기록·조작, coral=오늘의 좋은 기운, neutral=그 밖 |
| `design-v1-ja-line-height` | `copy-sample` | `["V11"]` | `chosen` | B(카드 1.75 / 본문 1.7) 채택. 예문은 임시, W1 검수 문장으로 재확인 |
| `design-v1-specimen` | `token-sheet` | `["V8", "V9", "V10", "V11", "V12"]` | `chosen` | `file`: 라이트 PNG, `source`: `../specimen/index.html`. 다크 PNG는 note에 이름을 적음 |

- [ ] **Step 4: 검증**

Run: `python3 -c "import json;json.load(open('docs/identity/design/artifacts/index.json'))"`
그리고 `ls -l`로 PNG 크기를 확인합니다.
Expected: 오류 없음, 모든 PNG가 2MB 이하.

- [ ] **Step 5: Commit** — `docs(design): V1 시안 기록`

---

### Task 7: 기준 문서·결정·현재 상태

**Files:**
- Modify:
  - `docs/identity/design/visual-identity.md`
  - `docs/identity/design/decisions.md`
  - `docs/identity/design/CLAUDE.md`
- Test: `TEST` 전체(문서 변경이라 새 테스트 없음)

**바꿀 것:**
1. **`visual-identity.md`**
   * 제목을 "(V0)"에서 "(V0·V1)"로 바꿉니다.
   * "이 문서의 위상"의 요청 경로를 "GitHub Issues(`to:design`)"로 바꿉니다.
   * 토큰 파일 안내를 한 줄 넣습니다: `tokens/README.md`, 값이 다르면 토큰이 맞습니다.
   * 원칙에 색의 의미 규칙 표를 넣습니다(spec §2).
   * 의미 역할 표에 V1 역할 8개와 `chip.bg`·`swatch.border` 단일 값을 넣고, "V1에서 정합니다" 줄을 지웁니다.
   * 새 절 "캘린더 길흉"을 넣습니다(spec §3.2와 색 외 전달 규칙).
   * 타이포 표를 spec §4.2로 바꾸고, 글꼴 묶음(§4.1)과 자간·고정폭 숫자 규칙을 넣습니다.
   * 새 절 "간격과 반경"을 넣습니다(spec §5).
2. **`decisions.md`:** 결정 V8~V12를 행으로 추가합니다. 날짜 2026-10-11, 근거 "사용자 결정 (V1 brainstorming)"과 시안 id.
   * V8: 색의 의미 규칙
   * V9: DTCG 형식, 모드·언어별 파일, 생성기가 원본, 계약 1.0.0
   * V10: 배지 4종과 캘린더 칸 채우기(점은 이벤트용으로 남김)
   * V11: 타이포 추가(범위 값 분리, display, 숫자 스타일, 자간 -2%, 대체 글꼴)와 일본어 줄 간격 1.75/1.7
   * V12: 간격·반경 값
3. **`CLAUDE.md`**
   * "현재 상태"를 V1 완료로 바꾸고, 토큰 재생성 명령을 넣습니다.
   * "다음 할 일"을 바꿉니다: V2(IA 대기), W1 뒤 일본어 줄 간격 재확인.
   * 로고 재생성 순서는 그대로 둡니다.

- [ ] **Step 1: 세 문서 수정**

- [ ] **Step 2: 남은 문구 확인**

Run: `grep -n "V1에서 정합니다\|docs/coordination" docs/identity/design/visual-identity.md`
Expected: 출력 없음.

- [ ] **Step 3: 전체 검사**

Run: `TEST`와 `python3 docs/identity/design/tools/palette.py --check`
Expected: 전부 통과, `52/52`.

- [ ] **Step 4: Commit** — `docs(design): 마일스톤 V1 기준 문서, 결정 V8~V12, 현재 상태`

---

### Task 8: Issue 본문 준비

**Files:**
- Create (git 제외 작업 파일): `.suberpowers/issues/v1-notice-app.md`, `.suberpowers/issues/v1-report-root.md`

**Interfaces:**
- Consumes: Task 3·4의 파일 경로와 버전

**본문 형식:** 각 본문은 무엇·왜·영향·관련 항목을 담습니다(workflow §5.2).

- **app 앞 notice:**
  - 토큰 위치와 조합법
  - Dart 코드 생성은 app이 한다는 것
  - 칩·견본 테두리의 알파
  - `fontFeatures` 확장, `gradient` 각도 확장
  - 시스템 글자 크기 규칙
  - 길흉은 칸 채우기이고, `NEUTRAL`은 토큰이 없다는 것
- **root 앞 report:**
  - 완료 보고
  - 계약 목록의 디자인 토큰 상태를 "동결 1.0.0"으로 바꿔 달라는 요청
  - 길흉 표시가 점에서 칸 채우기로 바뀐 것: 엔진 spec §8과 `app/CLAUDE.md`의 "길흉 점" 표기
  - 결정 V8 요약
  - PR 번호(병합 전이면 브랜치 이름)

Issue 열기와 PR은 finishing 단계에서 사용자 확인 뒤에 합니다. 이 task는 본문 파일까지만 만듭니다.

- [ ] **Step 1: 두 본문 작성**
- [ ] **Step 2: 확인** — 두 파일에 위 항목이 모두 있는지 읽어서 확인합니다(commit 없음, git 제외 경로).

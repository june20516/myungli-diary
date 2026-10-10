# V0 시각 정체성 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** V0 spec의 색·그라데이션·타이포·로고를 검사 가능한 생성기, SVG 원본, 견본 페이지, 기준 문서로 만듭니다.

**Architecture:** `tools/palette.py`(표준 라이브러리만)가 모든 색 값의 단일 출처입니다. 로고 SVG와 견본 페이지는 손으로 쓰되, 그 안의 색이 `palette.py` 결과와 같은지 테스트가 지킵니다. 워드마크는 `tools/wordmark.py`가 고운돋움 글리프를 아웃라인 path로 바꿔 만듭니다.

**Tech Stack:** Python 3.13 표준 라이브러리, pytest 8.3.5와 fontTools 4.54.1(둘 다 `uv run --with`로 실행 시에만), SVG, 정적 HTML/CSS, Playwright(PNG 캡처).

**Spec:** [`../specs/2026-10-10-visual-identity-design.md`](../specs/2026-10-10-visual-identity-design.md)

## Global Constraints

* 모든 경로는 `docs/identity/design/` 아래입니다. 그 밖은 `docs/coordination/`에 보고서를 쓰는 것만 허용됩니다.
* 저장소에 의존성 파일(pyproject, requirements)을 추가하지 않습니다. 외부 패키지는 `uv run --with <패키지>==<버전>`으로만 씁니다.
* 테스트 실행 명령(이하 `TEST`): `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q` (저장소 루트에서)
* hex 값은 소문자 7자(`#rrggbb`)로 씁니다.
* 글자 조합 대비 기준은 4.5:1입니다(spec §2).
* 글꼴 파일은 저장소에 넣지 않습니다. 고운돋움 TTF는 `.suberpowers/fonts/GowunDodum-Regular.ttf`(git 제외)에 내려받습니다: `https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf`
* 결정은 "결정 V1"처럼, 마일스톤은 "V1"처럼 적습니다(spec §9).
* commit 범위 표기는 `docs(design)` 또는 `feat(design)`, 메시지 끝에 세션 attribution 두 줄을 붙입니다.
* 시각 산출물은 `docs/workflow.md` §7을 따릅니다(HTML·SVG에는 같은 이름 PNG, `index.json` 갱신, 2MB 이하).

## Review Focus

1. 대문자 hex(`#FFFFFF`)나 3자리 hex(`#fff`)를 대비 함수에 넣었을 때 → 대문자는 받아들이고, 3자리·형식 오류는 `ValueError`로 거절합니다(조용히 틀린 값을 내지 않음).
2. sRGB 밖의 OKLCH(예: L 0.9, C 0.4)를 넣었을 때 → 채도를 줄여 유효한 `#rrggbb`를 냅니다(음수나 256 이상 채널이 섞인 hex를 내지 않음).
3. 견본 페이지나 로고에 팔레트에 없는 색이 섞였을 때 → 테스트가 그 색과 파일을 이름으로 알려 주며 실패합니다.
4. `palette.py --check`가 기준 미달 조합을 만났을 때 → 그 조합 이름과 대비를 출력하고 종료 코드 1로 끝납니다.
5. 같은 입력으로 두 번 생성했을 때 → 결과 JSON이 바이트 단위로 같습니다(V1 토큰 diff가 흔들리지 않게).

---

### Task 1: 팔레트 생성기와 대비 검사기

**Files:**
- Create: `docs/identity/design/tools/palette.py`
- Test: `docs/identity/design/tools/test_palette.py`

**Interfaces:**
- Produces:
  - `oklch_to_hex(lightness: float, chroma: float, hue: float) -> str` — sRGB 밖이면 채도를 0.001씩 줄여 맞춤
  - `contrast_ratio(foreground: str, background: str) -> float` — WCAG 2 공식, 소수 둘째 자리 반올림
  - `brand_scale(hue: float, peak_chroma: float, steps: tuple[int, ...]) -> dict[int, str]`
  - `build_palette() -> dict` — 키 구조:
    `{"brand": {"sage": {50: hex, …, 900: hex}, "coral": {…}, "neutral": {50…950}},
      "ohaeng": {"wood"|"fire"|"earth"|"metal"|"water": {"swatch", "tint", "ink", "tint_dark", "ink_dark"}},
      "gradient": {"light": [hex, hex], "dark": [hex, hex]},
      "roles": {"light": {role: hex}, "dark": {role: hex}}}`
    역할 키: `bg.base`, `bg.sheet`, `text.primary`, `text.secondary`, `line`, `action.primary`, `action.on-primary`, `term.bg`, `term.fg`, `badge.good.bg`, `badge.good.fg` (칩은 투명도 값이라 제외)
  - `check_contrast(palette: dict) -> list[ContrastResult]` — `ContrastResult`는 `name: str, foreground: str, background: str, ratio: float, passed: bool`인 frozen dataclass
  - CLI: 인자 없으면 `build_palette()`를 `json.dumps(…, indent=2, sort_keys=True)`로 출력, `--check`면 결과 표를 출력하고 미달이 있으면 종료 코드 1

- [ ] **Step 1: 실패하는 테스트 작성** — `test_palette.py`에 아래를 씁니다(`from palette import …`, 테스트 파일 첫머리에서 `sys.path`에 자기 디렉터리를 넣음).

```python
def test_contrast_known_values():
    assert contrast_ratio("#ffffff", "#000000") == 21.0
    assert contrast_ratio("#FFFFFF", "#a75c53") == 4.89

@pytest.mark.parametrize("bad", ["#fff", "ffffff", "#gggggg", ""])
def test_contrast_rejects_malformed_hex(bad):
    with pytest.raises(ValueError):
        contrast_ratio(bad, "#000000")

def test_out_of_gamut_is_mapped_to_valid_hex():
    assert re.fullmatch(r"#[0-9a-f]{6}", oklch_to_hex(0.9, 0.4, 145))

def test_brand_scales_match_spec():
    palette = build_palette()["brand"]
    assert palette["sage"] == SPEC_SAGE      # spec §3.1 표의 sage 열 50~900 그대로
    assert palette["coral"] == SPEC_CORAL    # coral 열
    assert palette["neutral"] == SPEC_NEUTRAL  # neutral 열 50~950

def test_ohaeng_matches_spec():
    ohaeng = build_palette()["ohaeng"]
    assert ohaeng["wood"]["swatch"] == "#418e47"
    assert ohaeng["water"]["swatch"] == "#153e78"
    assert ohaeng["metal"]["tint"] == "#e8ebef"
    assert ohaeng["metal"]["ink"] == "#454e58"
    assert ohaeng["fire"]["tint_dark"] == "#402623"
    assert ohaeng["earth"]["ink_dark"] == "#ead4b3"

def test_gradient_matches_spec():
    assert build_palette()["gradient"] == {"light": ["#eef4ef", "#fbefee"], "dark": ["#162017", "#271818"]}

def test_all_text_pairs_pass():
    results = check_contrast(build_palette())
    assert [r.name for r in results if not r.passed] == []
    ratios = {r.name: r.ratio for r in results}
    assert ratios["light badge.good"] == 4.89
    assert ratios["light term"] == 5.80

def test_check_contrast_flags_failure():
    palette = build_palette()
    palette["roles"]["light"]["badge.good.bg"] = "#f4b6ae"
    failed = [r for r in check_contrast(palette) if not r.passed]
    assert [r.name for r in failed] == ["light badge.good"]

def test_generation_is_deterministic():
    assert json.dumps(build_palette(), sort_keys=True) == json.dumps(build_palette(), sort_keys=True)

def test_cli_check_exit_code():
    result = subprocess.run([sys.executable, PALETTE_PY, "--check"], capture_output=True, text=True)
    assert result.returncode == 0
```

`SPEC_SAGE`·`SPEC_CORAL`·`SPEC_NEUTRAL`은 spec §3.1 hex 표를 int 키 dict로 그대로 옮긴 상수입니다.

- [ ] **Step 2: 실패 확인** — Run: `TEST`. Expected: `ModuleNotFoundError: No module named 'palette'`로 FAIL.

- [ ] **Step 3: `palette.py` 구현**
  * 변환: OKLab→linear sRGB 표준 행렬(Björn Ottosson), sRGB 감마 인코딩, 채널은 `round(x * 255)`.
  * 명도 단계와 채도 가중치는 spec §3.1(`weight = max(1 - |L - 0.6| / 0.45, 0.12)`), 팔레트 hue·최대 채도는 spec §3.1 표.
  * 오행 견본·바탕·글자의 L·C는 spec §3.3(금은 별도 채도).
  * 그라데이션: 라이트는 고정 hex, 다크는 `oklch_to_hex(0.23, 0.022, 150)`, `oklch_to_hex(0.23, 0.024, 20)`.
  * 역할 매핑은 spec §3.2 표.
  * `check_contrast`가 검사할 조합(이름 → 글자, 바탕), 모드마다(`light`/`dark` 접두):
    `text.primary on bg.base`, `text.primary on bg.sheet`, `text.secondary on bg.base`, `text.secondary on bg.sheet`, `action.primary`(on-primary on primary), `term`(term.fg on term.bg), `badge.good`(fg on bg), 그라데이션 양 끝 각각에 대한 `text.primary on gradient[0|1]`, `text.secondary on gradient[0|1]`, 그리고 오행 다섯 개의 `ohaeng.<원소>`(ink on tint, 다크는 ink_dark on tint_dark).
  * 이름 형식은 `"<mode> <조합>"` (예: `"light badge.good"`, `"dark ohaeng.metal"`).

- [ ] **Step 4: 통과 확인** — Run: `TEST`. Expected: 모두 PASS. 이어서 `python3 docs/identity/design/tools/palette.py --check`가 미달 0건, 종료 코드 0.

- [ ] **Step 5: Commit** — `git add docs/identity/design/tools/palette.py docs/identity/design/tools/test_palette.py` → `feat(design): OKLCH 팔레트 생성기와 대비 검사기`

---

### Task 2: 앱 아이콘 SVG

**Files:**
- Create: `docs/identity/design/logo/icon-large.svg`, `icon-small.svg`, `icon-android-background.svg`, `icon-android-foreground.svg`
- Create: `docs/identity/design/tools/svg_colors.py`
- Test: `docs/identity/design/tools/test_logo.py`

**Interfaces:**
- Consumes: `build_palette()` (Task 1)
- Produces:
  - `palette_colors(palette: dict) -> set[str]` — 팔레트 안의 모든 hex 집합(`svg_colors.py`)
  - `colors_in_markup(text: str) -> set[str]` — 문서 안 `#rrggbb`/`#RRGGBB`를 소문자로 모은 집합(`svg_colors.py`). Task 4가 견본 페이지 검사에 재사용

- [ ] **Step 1: 실패하는 테스트 작성** (`test_logo.py`)

```python
LOGO = DESIGN_DIR / "logo"
ICONS = ["icon-large.svg", "icon-small.svg", "icon-android-background.svg", "icon-android-foreground.svg"]

@pytest.mark.parametrize("name", ICONS)
def test_icon_uses_only_palette_colors(name):
    stray = colors_in_markup((LOGO / name).read_text()) - palette_colors(build_palette()) - {"#ffffff"}
    assert stray == set(), f"{name}: 팔레트 밖 색 {sorted(stray)}"

@pytest.mark.parametrize("name, size", [("icon-large.svg", 100), ("icon-small.svg", 100),
                                        ("icon-android-background.svg", 108), ("icon-android-foreground.svg", 108)])
def test_icon_is_square_full_bleed(name, size):
    root = ET.parse(LOGO / name).getroot()
    assert root.get("viewBox") == f"0 0 {size} {size}"
    first_rect = root.find("{http://www.w3.org/2000/svg}rect")
    if name != "icon-android-foreground.svg":
        assert first_rect.get("width") == str(size) and first_rect.get("rx") is None

def test_android_foreground_sits_in_safe_zone():
    root = ET.parse(LOGO / "icon-android-foreground.svg").getroot()
    groups = root.findall("{http://www.w3.org/2000/svg}g")
    assert [g.get("transform") for g in groups] == ["translate(21 21) scale(0.66)"]
    assert root.find("{http://www.w3.org/2000/svg}rect") is None  # 전경에는 바탕이 없음

def test_colors_in_markup_finds_uppercase():
    assert colors_in_markup('fill="#A75C53"') == {"#a75c53"}
```

- [ ] **Step 2: 실패 확인** — Run: `TEST`. Expected: `svg_colors` import 실패 또는 파일 없음으로 FAIL.

- [ ] **Step 3: `svg_colors.py`와 SVG 4개 작성**
  * 출발점은 시안 `artifacts/2026-10-10-v0-logo-diary-seal-v2.html`의 `icon-lg`·`icon-sm`·`seal-lg`·`seal-sm` 심볼입니다. 바깥 `rx="22"`를 없애 풀블리드로 만들고, 심볼 참조(`<use>`)를 풀어 단독 SVG로 씁니다.
  * 색은 spec §6.1 표: 바탕 sage-100→coral-100 대각선 `linearGradient`, 표지 sage-600, 등판 sage-700, 낙관 coral-600, 양각 日 coral-50.
  * 치수는 spec §6.1 표(큰 원형: 공책 x21 y14 w58 h72, 낙관 28 단위 `rotate(-30 60 63)` / 작은 원형: 공책 x18 y12 w64 h76, 등판 폭 13, 낙관 38 단위 `rotate(-30 59 61)`).
  * Android 배경: 108×108 그라데이션 rect만. 전경: 큰 원형의 공책·낙관을 `<g transform="translate(21 21) scale(0.66)">` 하나로 감쌈.

- [ ] **Step 4: 통과 확인** — Run: `TEST`. Expected: 모두 PASS.

- [ ] **Step 5: 렌더링 확인** — 저장소 루트에서 `python3 -I -m http.server 53999 --bind 127.0.0.1 --directory docs/identity/design`을 백그라운드로 띄우고, Playwright로 `logo/icon-large.svg`, `logo/icon-small.svg`를 엽니다. 낙관이 반시계 30°이고 공책 밖으로 넘치지 않으면 통과입니다. 서버는 끕니다.

- [ ] **Step 6: Commit** — `feat(design): 앱 아이콘 SVG(큰·작은 원형, Android 적응형)와 색 검사`

---

### Task 3: 워드마크와 가로 조합

**Files:**
- Create: `docs/identity/design/tools/wordmark.py`
- Create: `docs/identity/design/logo/wordmark.svg`, `wordmark-dark.svg`, `lockup.svg`, `lockup-dark.svg`
- Test: `docs/identity/design/tools/test_wordmark.py`

**Interfaces:**
- Consumes: `build_palette()` (Task 1), `colors_in_markup`·`palette_colors` (Task 2), `logo/icon-large.svg` (Task 2)
- Produces:
  - `wordmark_svg(font_path: Path, text: str, fill: str, letter_spacing_em: float = 0.02) -> str` — 글리프마다 fontTools `SVGPathPen`으로 path를 만들고 y축을 뒤집어 한 줄로 배치. `<text>` 요소 없음
  - `lockup_svg(icon_svg: str, wordmark: str, gap_ratio: float = 0.25, icon_to_cap_ratio: float = 1.5) -> str` — spec §6.2 비율
  - CLI: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py --font <ttf> --out-dir docs/identity/design/logo` 가 4개 파일을 씀. 색은 라이트 `text.primary`, 다크 `text.primary`

- [ ] **Step 1: 글꼴 내려받기** — `mkdir -p .suberpowers/fonts && curl -fsSL -o .suberpowers/fonts/GowunDodum-Regular.ttf https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf`. Expected: 파일 크기 0보다 큼. (실패하면 멈추고 보고)

- [ ] **Step 2: 실패하는 테스트 작성** (`test_wordmark.py`, 글꼴이 없으면 `pytest.skip`)

```python
def test_wordmark_is_outlined(font_path):
    svg = wordmark_svg(font_path, "명리일기", "#2b2b2a")
    root = ET.fromstring(svg)
    assert root.find(".//{http://www.w3.org/2000/svg}text") is None
    assert len(root.findall(".//{http://www.w3.org/2000/svg}path")) == 4
    assert colors_in_markup(svg) == {"#2b2b2a"}

def test_wordmark_rejects_missing_glyph(font_path):
    with pytest.raises(ValueError):
        wordmark_svg(font_path, "명리일기☃", "#2b2b2a")

@pytest.mark.parametrize("name", ["wordmark.svg", "wordmark-dark.svg", "lockup.svg", "lockup-dark.svg"])
def test_logo_files_use_palette_colors(name):
    stray = colors_in_markup((LOGO / name).read_text()) - palette_colors(build_palette()) - {"#ffffff"}
    assert stray == set()
```

- [ ] **Step 3: 실패 확인** — Run: `TEST`. Expected: `wordmark` import 실패로 FAIL.

- [ ] **Step 4: `wordmark.py` 구현 후 CLI로 4개 파일 생성** — 글리프가 없으면(`cmap`에 없음) `ValueError`. `lockup_svg`는 아이콘 SVG를 `<svg>` 중첩으로 넣고 워드마크를 옆에 둡니다.

- [ ] **Step 5: 통과 확인** — Run: `TEST`. Expected: 모두 PASS.

- [ ] **Step 6: Commit** — `feat(design): 고운돋움 아웃라인 워드마크와 가로 조합`

---

### Task 4: 견본 페이지

**Files:**
- Create: `docs/identity/design/specimen/index.html`
- Test: `docs/identity/design/tools/test_specimen.py`

**Interfaces:**
- Consumes: `build_palette()` (Task 1), `colors_in_markup`·`palette_colors` (Task 2), `logo/*.svg` (Task 2·3)

- [ ] **Step 1: 실패하는 테스트 작성** (`test_specimen.py`)

```python
def css_vars(html: str) -> dict[str, str]:
    return {m[0]: m[1].lower() for m in re.findall(r"(--[\w.-]+):\s*(#[0-9a-fA-F]{6})", html)}

def test_specimen_variables_match_palette():
    palette = build_palette()
    variables = css_vars(SPECIMEN.read_text())
    for name, scale in palette["brand"].items():
        for step, hex_value in scale.items():
            assert variables[f"--{name}-{step}"] == hex_value
    for element, parts in palette["ohaeng"].items():
        for part, hex_value in parts.items():
            assert variables[f"--ohaeng-{element}-{part}"] == hex_value

def test_specimen_uses_only_palette_colors():
    stray = colors_in_markup(SPECIMEN.read_text()) - palette_colors(build_palette()) - {"#ffffff"}
    assert stray == set(), sorted(stray)

def test_specimen_references_existing_logos():
    for src in re.findall(r'src="\.\./logo/([\w.-]+\.svg)"', SPECIMEN.read_text()):
        assert (DESIGN_DIR / "logo" / src).exists(), src
```

- [ ] **Step 2: 실패 확인** — Run: `TEST`. Expected: `specimen/index.html` 없음으로 FAIL.

- [ ] **Step 3: `specimen/index.html` 작성** — 섹션 순서와 내용은 spec §7 "견본 페이지" 행:
  1. `:root`에 원시 팔레트(`--sage-50`…), 오행(`--ohaeng-wood-swatch`…), 역할(`--role-light-text-primary`…)을 CSS 변수로 둡니다. 페이지의 다른 곳은 hex를 직접 쓰지 않고 이 변수만 씁니다.
  2. 원시 팔레트 띠 3개, 역할 표(라이트·다크, 각 조합의 대비 숫자는 `palette.py --check` 출력값을 옮김), 오행 견본·원국표 칸, 그라데이션 두 장, 타이포 크기표(한·영·일 예문, 글꼴은 Google Fonts의 Gowun Dodum·Zen Maru Gothic과 jsDelivr의 Pretendard v1.3.9·Pretendard JP v1.3.9), 데일리 카드 L1 라이트·다크(배지 B, 시안 `design-v0-brand-palette`의 카드 구조), 로고 일체(`<img src="../logo/…">`, 아이콘은 20·29·40·60·180px).
  * 예문의 이름과 행운 값은 시안과 같은 예시("지윤님", 남색·북쪽·1 · 6)를 씁니다.

- [ ] **Step 4: 통과 확인** — Run: `TEST`. Expected: 모두 PASS.

- [ ] **Step 5: 렌더링 확인** — Task 2 Step 5와 같은 서버로 `specimen/index.html`을 Playwright에서 열고 `document.fonts.ready` 후 라이트·다크(`emulate_media`)를 각각 봅니다. 글꼴 4종이 `loaded`이고 깨진 이미지가 없으면 통과입니다.

- [ ] **Step 6: Commit** — `feat(design): V0 견본 페이지`

---

### Task 5: 기준 문서, 결정 로그, 산출물 기록

**Files:**
- Create: `docs/identity/design/visual-identity.md`
- Modify: `docs/identity/design/decisions.md`
- Modify: `docs/identity/design/artifacts/index.json`
- Create: `docs/identity/design/artifacts/2026-10-10-v0-specimen.html`·`.png`, `2026-10-10-v0-specimen-dark.png`, `2026-10-10-v0-logo-final.svg`·`.png`

- [ ] **Step 1: `visual-identity.md` 작성** — 받는 쪽(app, writing, 지휘)이 읽는 문서. 위상(06을 대체, 고치는 쪽 design), 원칙(spec §2), 원시 팔레트·역할·오행 표(spec §3 값 그대로, 생성 규칙은 `tools/palette.py`를 가리킴), 그라데이션 규칙(spec §4), 타이포 표(spec §5), 로고 사용 규칙(spec §6, 파일은 `logo/`를 가리킴), 견본 링크. 근거 설명은 넣지 않고 spec 절을 가리킵니다.

- [ ] **Step 2: `decisions.md`에 결정 V1~V7 기록** — 표 형식은 기존 머리글(`ID | 날짜 | 분류 | 결정 | 근거`). 결정 내용은 spec §9 표, 날짜 2026-10-10, 근거는 "사용자 결정 (V0 brainstorming)"과 관련 시안 id.

- [ ] **Step 3: 산출물 캡처** — 견본 페이지를 `artifacts/2026-10-10-v0-specimen.html`로 그대로 복사합니다(`specimen/`과 `artifacts/`는 같은 깊이라 `../logo/` 경로가 그대로 통합니다). Playwright로 라이트 전체 페이지를 `2026-10-10-v0-specimen.png`, 다크를 `2026-10-10-v0-specimen-dark.png`로 캡처. 로고 일체를 한 장에 모은 `2026-10-10-v0-logo-final.svg`(아이콘 큰·작은 원형, 워드마크, 가로 조합을 중첩)와 그 PNG를 만듭니다. 이미지마다 2MB 이하인지 `ls -l`로 확인.

- [ ] **Step 4: `index.json` 갱신** — 새 항목 2개(`design-v0-specimen` kind `token-sheet` status `chosen`, `design-v0-logo-final` kind `concept` status `chosen`, milestone `V0`), 기존 5개 항목의 `decisions`를 채웁니다: brand-palette → `["V1","V3"]`, ohaeng-palette → `["V2"]`, logo 3건 → `["V7"]`, specimen → `["V1","V2","V3","V4","V5","V6"]`, logo-final → `["V7"]`.

- [ ] **Step 5: 검사** — Run: `TEST`와 아래 스크립트(artifacts 디렉터리에서): `index.json`의 모든 항목에 필수 필드(`id, title, kind, file, date, milestone, screens, decisions, status, note`)가 있고 `file`·`source`가 실제로 있는지. Expected: 누락 0.

- [ ] **Step 6: Commit** — `docs(design): V0 정체성 기준 문서, 결정 V1~V7, 견본·로고 산출물`

---

### Task 6: 마무리 보고

**Files:**
- Modify: `docs/identity/design/CLAUDE.md` ("현재 상태", "다음 할 일")
- Create: `docs/coordination/2026-10-10-design-to-root-v0-visual-identity.md` (`docs/coordination/TEMPLATE.md` 형식, `kind: report`, `status: done`)

- [ ] **Step 1: `CLAUDE.md` 갱신** — 현재 상태: V0 완료, 기준 문서 `visual-identity.md`. 다음 할 일: V1(토큰 형식·Dart 생성을 app과 요청함으로 합의, 날의 성격 배지 나머지 3종, 캘린더 길흉 점, 일본어 줄 간격), V2는 IA 대기.

- [ ] **Step 2: 완료 보고 작성** — spec §11의 네 가지(06 대체, README 시안 값과 달라진 배지·용어 토큰, 결정 번호와 마일스톤 이름 겹침, V1 착수 예정)와 `root-to-design-artifacts` 요청을 반영했다는 사실(시안 7건 등록).

- [ ] **Step 3: 최종 검사** — Run: `TEST`, `python3 docs/identity/design/tools/palette.py --check`, `git status --short`(design 소유 경로와 `docs/coordination/`의 새 보고서 외 변경 없음).

- [ ] **Step 4: Commit** — `docs(design): V0 완료 보고와 현재 상태 갱신`

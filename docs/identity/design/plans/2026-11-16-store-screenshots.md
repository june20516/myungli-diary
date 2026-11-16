# 스토어 스크린샷 명세 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** app이 읽어 스토어 이미지를 만들 `store/store.json`과 설명 `store/README.md`, 이를 검사하고 글자 수 상한을 재는 `tools/store.py`를 만듭니다.

**Architecture:** 사실은 JSON 하나(장면, 렌더 조건, 틀, 그래픽 이미지). `tools/store.py`는 `validate(doc, repo_root) -> list[str]`(오류 목록)과 `caption_limits(fonts) -> dict`(언어별 한 줄 상한)를 내고, 상한 측정은 `lengths.py`의 `ko_name_chars`, `ja_line_chars`, `en_line_chars`를 그대로 씁니다. README 상한 표는 도구 출력과 같아야 합니다.

**Tech Stack:** Python 3 표준 라이브러리, fonttools 4.54.1(상한 측정만), pytest 8.3.5.

**Spec:** `docs/identity/design/specs/2026-11-16-store-screenshots-design.md`

## Global Constraints
* 글자 수 상한(한 줄): ko 14, ja 11, en 23(최종 review에서 Title Case 감안으로 24에서 고침). 두 줄까지.
* App Store 1320×2868, Play 1080×1920, 그래픽 이미지 1024×500. `store.json` `version` "1.0.0".
* 장면 여섯(순서, IA 화면, 상태, 시나리오)은 spec §4 표 그대로.
* 틀 수치는 spec §6 표 그대로. 글 Pretendard SemiBold(600), 자간 −0.02em, 색 `#2b2b2a`(`text.primary` 라이트), 줄 높이 1.3.
* 바탕 `gradient.today` 라이트 `#eef4ef` → `#fbefee`, 160°.
* 사용자에게 보이는 글(README의 예시 글 포함)에 U+2014, U+2013, U+00B7을 쓰지 않습니다(D93).
* 저장소 루트에서 실행: `python3 docs/identity/design/tools/store.py`, 테스트 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`.

## Review Focus
1. 장면 (화면, 상태, 시나리오)가 app 렌더 사례에 없는 조합(예: 상태 `unlocked-still`)이면 검사가 그 화면과 상태를 이름으로 짚어 실패해야 함.
2. fixture 시나리오 디렉터리가 지워지거나 이름이 바뀌면 검사가 실패해야 함(app 쪽 변경을 design CI가 잡음).
3. Play 크기를 긴 변 2배 초과(예: 1080×2340)로 바꾸면 실패해야 함.
4. 글 두 줄 끝이 화면 판 위를 넘으면(글 크기를 키움) 실패해야 함.
5. 글꼴이 없는 로컬에서는 상한 대조만 skip되고 나머지 검사는 돌아야 함.

---

### Task 1: `store.json`과 검사

**Files:**
- Create: `docs/identity/design/store/store.json`
- Create: `docs/identity/design/tools/store.py`
- Test: `docs/identity/design/tools/test_store.py`

**Interfaces:**
- Produces: `store.app_shots(repo_root: pathlib.Path = REPO_ROOT) -> set[tuple[str, str, str]]`(정규식 `_Shot\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)'`, 여러 줄 허용), `store.load(path: pathlib.Path = STORE_JSON) -> dict`, `store.validate(doc: dict, repo_root: pathlib.Path = REPO_ROOT) -> list[str]`, 상수 `STORE_JSON`, `REPO_ROOT`. `main(argv)`는 오류가 있으면 줄마다 출력하고 1, 없으면 `OK: 장면 6개` 출력하고 0.

`store.json` 모양(키 이름 고정):
```json
{
  "version": "1.0.0",
  "spec": "specs/2026-11-16-store-screenshots-design.md",
  "render": { "logicalSize": [390, 844], "pixelRatio": 3, "theme": "light", "locales": ["ko", "en", "ja"],
              "hide": ["bannerAd", "statusBar"], "notes": { "evidence-sheet": "..." } },
  "scenes": [ { "order": 1, "id": "today", "screen": "today", "state": "default", "scenario": "member" }, ... ],
  "background": { "from": "#eef4ef", "to": "#fbefee", "angle": 160 },
  "caption": { "font": "Pretendard", "weight": 600, "tracking": -0.02, "lineHeight": 1.3, "color": "#2b2b2a",
               "align": "center", "maxLines": 2, "lineBreak": "writing", "slot": "writing이 정함" },
  "frames": {
    "appStore": { "size": [1320, 2868], "caption": { "top": 200, "side": 120, "size": 88 },
                  "screen": { "top": 560, "width": 1080, "radius": 72, "shadow": { "y": 24, "blur": 64, "color": "rgba(40, 50, 40, 0.14)" } } },
    "play": { "size": [1080, 1920], "caption": { "top": 120, "side": 96, "size": 72 },
              "screen": { "top": 400, "width": 700, "radius": 48, "shadow": { "y": 16, "blur": 44, "color": "rgba(40, 50, 40, 0.14)" } } }
  },
  "featureGraphic": { "size": [1024, 500], "logo": "logo/lockup.png", "logoWidth": 472, "text": false }
}
```
장면 `id`는 `today`, `evidence`, `calendar`, `daySheet`, `mySaju`, `share`(writing 키 제안과 같음).

- [ ] **Step 1: 실패하는 테스트 작성** (`test_store.py`)
  * `test_store_json_is_valid`: `store.validate(store.load()) == []`.
  * `test_scenes_follow_spec_order`: `[(s["screen"], s["state"], s["scenario"]) for s in scenes]`가 spec §4 여섯 줄과 같고 `order`가 1~6.
  * `test_unknown_state_is_named` (Review 1): 장면 2의 state를 `"unlocked-still"`로 바꾼 사본 → 오류 중 하나에 `evidence-sheet`와 `unlocked-still`이 모두 들어 있음.
  * `test_app_shots_parsed`: `store.app_shots()`에 `("evidence-sheet", "unlocked", "evidence-unlocked")`와 `("today", "default", "member")`가 있음(여러 줄에 걸친 `_Shot(` 포함).
  * `test_missing_scenario_fails` (Review 2): `tmp_path`에 IA 사본, `screens_test.dart` 사본, 빈 `app/fixtures/`를 둔 `repo_root`로 검사 → `member` 오류.
  * `test_play_aspect_limit` (Review 3): play size `[1080, 2340]` → 오류.
  * `test_caption_must_end_above_screen` (Review 4): appStore caption size 200 → 오류.
  * `test_feature_graphic_size`: size `[1024, 512]` → 오류.
  * `test_scene_count_bounds`: 장면 하나뿐 → 오류(Play 2장 미만).
- [ ] **Step 2: 실행해 실패 확인**: `uv run --with pytest==8.3.5 pytest docs/identity/design/tools/test_store.py -q` → `ModuleNotFoundError: store`.
- [ ] **Step 3: `store.json`과 `store.py` 구현**. 검사 규칙(spec §9): IA `screens[].id`, (화면, 상태, 시나리오)가 `app_shots()`에 있음, `app/fixtures/<시나리오>/` 디렉터리, 순서 1..n 빈틈 없음, 2 ≤ n ≤ 8, App Store 정확히 1320×2868, Play 긴 변 ≤ 짧은 변×2 그리고 짧은 변 ≥ 1080, 그래픽 1024×500, 각 틀 `side*2 < 폭`, 화면 판 폭 ≤ 그림 폭, `caption.top + maxLines*size*lineHeight <= screen.top`, 그래픽 `logoWidth < 폭`이고 `logo` 파일이 design 디렉터리에 있음.
- [ ] **Step 4: 통과 확인**: 같은 명령 → 모두 PASS, `python3 docs/identity/design/tools/store.py` → `OK: 장면 6개`.
- [ ] **Step 5: Commit** `feat(design): 스토어 이미지 명세 store.json과 검사 (#1202)`

### Task 2: 글자 수 상한과 README

**Files:**
- Modify: `docs/identity/design/tools/store.py`
- Create: `docs/identity/design/store/README.md`
- Test: `docs/identity/design/tools/test_store.py`

**Interfaces:**
- Consumes: `lengths.Fonts`, `lengths.ko_name_chars(advances, size, tracking, width)`, `lengths.ja_line_chars(advances, size, width)`, `lengths.en_line_chars(advances, size, tracking, width)`.
- Produces: `store.caption_limits(fonts: lengths.Fonts, doc: dict) -> dict[str, int]`(언어별 한 줄 상한, 두 틀 중 작은 값), `store.render_limits_table(limits: dict[str, int], max_lines: int) -> str`(README 표 Markdown). `main`에 `--font-dir`이 있으면 표를 재어 README와 대조하고 다르면 1.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `test_caption_limits_measured` (글꼴 없으면 skip, `DESIGN_FONTS_REQUIRED=1`이면 실패, `test_lengths.py`와 같은 방식): `caption_limits(...) == {"ko": 14, "ja": 11, "en": 24}`.
  * `test_readme_table_matches_tool` (같은 skip 규칙, Review 5): `render_limits_table(caption_limits(...), 2)`가 README 본문에 그대로 들어 있음.
  * `test_readme_has_no_banned_dashes`: README에 U+2014, U+2013, U+00B7 없음.
- [ ] **Step 2: 실패 확인**: 위 명령 → `AttributeError: caption_limits`.
- [ ] **Step 3: 구현**. 글꼴은 `ui-600`(ko, en은 Pretendard-SemiBold, ja는 전각 1em). tracking은 `-0.02 * size`(px). 표는 `| 언어 | 한 줄 | 두 줄 |` 세 줄(ko, ja, en). README 절: 목적과 맡는 쪽, 장면 표, 렌더 조건, 틀 표, 글 자리와 상한 표, 그래픽 이미지, 검사 명령, 판 기록(1.0.0).
- [ ] **Step 4: 통과 확인**: 테스트 PASS, `uv run --with fonttools==4.54.1 python docs/identity/design/tools/store.py --font-dir .suberpowers/fonts` → `OK`.
- [ ] **Step 5: Commit** `feat(design): 스토어 글 상한 실측과 README (#1202)`

### Task 3: 결정, 시안 기록, 단위 안내

**Files:**
- Modify: `docs/identity/design/decisions.md` (V133 행)
- Modify: `docs/identity/design/artifacts/index.json` (관문 질문 셋)
- Modify: `docs/identity/design/CLAUDE.md`
- Test: `docs/identity/design/tools/test_store.py`

- [ ] **Step 1: 실패하는 테스트**: `test_question_pages_recorded`: index.json에 `design-store-scenes-questions`, `design-store-frame-questions`, `design-store-feature-graphic-questions`가 `kind` "concept", `status` "chosen", `decisions`에 "V133", 각 `file`이 artifacts에 있음.
- [ ] **Step 2: 실패 확인.**
- [ ] **Step 3: 고치기**. V133 행(영역 "출시", 사용자 영향 `#1201`로 writing 글 자리, 근거 사용자 결정 2026-11-16 A, F1, G1과 #1202). index 세 항목(milestone "S1", screens 장면 화면들, note에 사용자 답). CLAUDE.md: "현재 상태"의 #1180 항목을 #1202로 바꾸고, "기준 문서와 도구"에 `store/` 한 줄, "다음 할 일" 1번을 #1202 마무리로.
- [ ] **Step 4: 전체 검사**: 전체 pytest, `components.py`, `store.py --font-dir`, `python3 tools/docs-check/docs_check.py`(저장소 루트) 모두 통과.
- [ ] **Step 5: Commit** `docs(design): 스토어 이미지 명세 결정 V133과 시안 기록 (#1202)`

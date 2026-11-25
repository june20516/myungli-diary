# 원어민 검수 시트 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** `mlw review-export`로 en, ja 원고를 묶음과 차수별 xlsx 검수 시트로 내보내고, `mlw review-import`로 돌아온 시트를 키로 원고에 반영합니다(#1283).

**Architecture:** 새 패키지 `mlw.review`에 시트 입출력(`sheet.py`, 원고 모델과 무관), 원고에서 행 만들기(`export.py`), 수정안 판정과 원고 쓰기(`apply.py`)를 둡니다. 반영 뒤 검사는 `cli._check`에서 꺼낸 `collect_findings`를 임시 사본에 돌려 바뀐 줄을 가리키는 error만 되돌립니다.

**Tech Stack:** Python 3.13, openpyxl, pyyaml, pytest, ruff, mypy(strict 설정은 기존 그대로).

**Spec:** `docs/identity/writing/specs/2026-11-25-native-review-sheet-design.md`

모든 명령은 `docs/identity/writing/tools`에서 실행합니다.

## Global Constraints

* 대상 언어는 `en`, `ja`뿐입니다. `ko`를 주면 오류입니다.
* 차수: 1 `store, ui, system, web` / 2 `daily-fortune, daily-cards, daily-reasons, personal, calendar, chart` / 3 `term, glossary, evidence, source`.
* 빈 시트 기본 출력: `docs/identity/writing/review/<언어>/tier<n>.xlsx`, `--bundle`이면 `<묶음>-<묶음>.xlsx`(지정 순서).
* 받은 시트, 결과 시트는 저장소에 넣지 않습니다. 결과 시트는 받은 시트 옆 `<이름>-result.xlsx`.
* 칸 머리는 `감수자 언어 (한국어)` 형식. 분류 값(en): `Mistranslation (오역)`, `Unnatural (어색함)`, `Grammar (문법)`, `Terminology (용어)`. ja: `誤訳 (오역)`, `不自然 (어색함)`, `文法 (문법)`, `用語 (용어)`.
* 호칭 표본: en `Alex`, ja `ゆき`. 숫자 표본 `3`. `text` 값은 `‹<자리표시자 이름>›`.
* 원고 파일은 `text` 값만 바꿉니다. 주석, 줄 순서, 다른 필드는 바이트 그대로.
* 검사기 버전 0.16.0, 결정 W84.
* 사용자에게 보이는 글(안내 탭 문구, 칸 머리)에는 긴 대시, 범위 대시, 가운뎃점을 쓰지 않습니다(D93).
* `uv.lock`은 CI와 같은 uv 0.11.3으로 갱신합니다(`uvx uv@0.11.3 lock`). 로컬 uv로 lock하면 revision이 내려갑니다.

## Review Focus

1. 감수자가 Sheets에서 행을 정렬하거나 필터한 시트: 행 순서가 아니라 숨긴 `id`로 맞춰야 함. 칸 순서가 바뀌어도 칸 머리 이름으로 읽어야 함.
2. 수정안 앞뒤 공백, 끝 줄바꿈(Sheets 붙여넣기): 앞뒤 공백은 지우고 비교. 안쪽 줄바꿈은 그대로.
3. Sheets가 숫자처럼 보이는 수정안(`3`, `10`)을 숫자 셀로 바꾼 경우: 문자열로 읽어야 함(`3.0`이 되면 안 됨).
4. 감수자가 행을 복사해 같은 `id`가 두 번 나온 경우: 두 행 모두 "같은 줄이 두 번" 이유로 반영 안 함.
5. 같은 원고 파일에서 여러 줄이 바뀌는 경우: 줄 번호로 교체하므로 한 줄 교체가 다른 줄 위치를 바꾸지 않아야 함(한 줄 원고 형식, 줄바꿈은 `\n` 이스케이프).

---

### Task 1: 의존성과 시트 입출력

**Files:**
- Modify: `pyproject.toml` (dependencies에 `openpyxl>=3.1`, dev에 `types-openpyxl`), `uv.lock`
- Create: `src/mlw/review/__init__.py`, `src/mlw/review/sheet.py`
- Test: `tests/test_review_sheet.py`

**Interfaces:**
- Produces:
  - `TIERS: dict[int, tuple[str, ...]]` (Global Constraints 값)
  - `ReviewRow` frozen dataclass: `id: str, key: str, bundle: str, place: str, source: str, current: str, example: str, suggestion: str = "", category: str = "", memo: str = "", verdict: str = ""`
  - `SheetMeta` frozen dataclass: `lang: str, commit: str, exported: str, tool_version: str`
  - `write_sheet(path: Path, meta: SheetMeta, guide: Sequence[str], rows_by_bundle: Mapping[str, Sequence[ReviewRow]]) -> None`
  - `read_sheet(path: Path) -> tuple[SheetMeta, list[ReviewRow]]`
  - `write_results(src: Path, dst: Path, results: Mapping[str, str]) -> None` (row id → `반영함` 또는 `반영 안 함: <이유>`)
  - `class SheetError(Exception)`: 칸 머리 없음, `_meta` 없음 등

- [ ] **Step 1: 의존성 추가와 lock**
  `pyproject.toml` 고친 뒤 `uvx uv@0.11.3 lock && uv sync`. `git diff uv.lock | head`로 `revision`이 그대로인지 확인합니다.

- [ ] **Step 2: 실패하는 test 작성** (`tests/test_review_sheet.py`, `tmp_path` 사용)
  * `test_round_trip`: 두 묶음 `store`, `ui`에 행 하나씩, 큰따옴표와 줄바꿈이 든 `current`로 `write_sheet` → `read_sheet` 결과 메타와 행이 같음.
  * `test_tabs_and_hidden`: openpyxl로 열어 탭 이름이 `["Guide (안내)", "store", "ui", "_meta"]`, `_meta` 시트 `sheet_state == "hidden"`, 묶음 탭 A열 `hidden is True`, 첫 행 고정(`freeze_panes == "A2"`).
  * `test_category_dropdown`: 묶음 탭 `data_validations.dataValidation[0].formula1`이 en 분류 값 네 개를 `,`로 이은 따옴표 문자열.
  * `test_read_by_header_name`: 저장한 시트에서 `수정안` 칸과 `메모` 칸 열을 맞바꾼 뒤 읽어도 값이 맞음.
  * `test_read_sorted_rows`: 데이터 행 순서를 뒤집어 저장해도 `id`별 값이 같음.
  * `test_numeric_suggestion`: 수정안 셀에 정수 `3`을 넣으면 `suggestion == "3"`, 실수 `2.5`면 `"2.5"`.
  * `test_strip_suggestion`: `"  Hello\n"` → `"Hello"`, 안쪽 `"a\nb"`는 그대로.
  * `test_results_column`: `write_results` 뒤 각 묶음 탭 마지막 칸 머리가 `Result (반영 결과)`이고 id별 값이 들어가며, 기존 `메모` 값은 그대로.
  * `test_missing_meta`: `_meta` 탭을 지운 파일은 `SheetError`.

- [ ] **Step 3: 실패 확인**
  Run: `uv run pytest tests/test_review_sheet.py -q` → FAIL(import error).

- [ ] **Step 4: `src/mlw/review/sheet.py` 구현**
  * 칸 머리는 언어별 표(`_HEADERS[lang]`)로, 읽을 때는 괄호 안 한국어 부분(`(수정안)` 등)으로 찾습니다. 감수자 언어 부분이 바뀌어도 읽힙니다.
  * 편집 안 하는 칸은 회색 채우기(`F2F2F2`), 모든 셀 `wrap_text`, 칸 너비 고정(키 28, 자리 설명 36, 원문, 번역, 예시, 수정안 48, 분류 18, 메모 36, writing 판정 28).
  * 안내 탭은 A열에 `guide` 문단 하나씩, 너비 100, 줄바꿈.
  * `read_sheet`는 `_meta`, `Guide`가 아닌 탭을 모두 묶음 탭으로 읽고, 셀 값 `None`은 `""`, 숫자는 `int`면 `str(int)`, `float`가 정수값이면 정수 문자열, 아니면 `repr` 없이 `str`. 모든 편집 칸은 `strip()`.
  * 분류 드롭다운은 `DataValidation(type="list", allow_blank=True)`를 분류 칸 2행부터 끝 행까지.

- [ ] **Step 5: 통과 확인**
  Run: `uv run pytest tests/test_review_sheet.py -q && uv run ruff check . && uv run mypy src` → PASS, 오류 없음.

- [ ] **Step 6: Commit** `feat(writing): 검수 시트 xlsx 입출력 (#1283)`

### Task 2: 원고에서 검수 행 만들기

**Files:**
- Create: `src/mlw/review/export.py`
- Test: `tests/test_review_export.py`

**Interfaces:**
- Consumes: `ReviewRow`, `TIERS` (Task 1). 기존 `Entry`, `Slot`, `Slot.length_limit`, `placeholders.parse/substitute/strip_token_marks`, `icu.expand_entry`, `cli.GLOSSARY_SLOT`.
- Produces:
  - `row_id(entry: Entry) -> str` = `f"{slot}|{key}|{type or ''}|{variant}"`
  - `bundles_for(tier: int | None, bundles: Sequence[str] | None) -> tuple[str, ...]`
  - `check_tier_coverage(content_dir: Path, lang: str) -> list[str]` (차수 표에 없는 파일 이름과 표에만 있는 이름, 정렬)
  - `build_rows(entries: Sequence[Entry], slots: Mapping[str, Slot], lang: str, bundles: Sequence[str]) -> dict[str, list[ReviewRow]]` (묶음 → 원고 순서 행)
  - `place_text(slot: Slot, lang: str, key: str) -> str`
  - `example_text(entry: Entry, slot: Slot, glossary: Mapping[str, Sequence[str]]) -> str`
  - `glossary_by_category(entries: Sequence[Entry], lang: str) -> dict[str, tuple[str, ...]]` (원고 순서, 정렬 안 함)

- [ ] **Step 1: 실패하는 test 작성** (Entry, Slot은 테스트 안에서 직접 만듦. 기존 `tests/test_web.py`의 Slot 생성 방식 참고)
  * `test_row_id`: type 없는 줄 `"s|k||1"`, type 있는 줄 `"s|k|advice|2"`.
  * `test_source_matches_across_files`: ko 줄 파일이 `daily.yaml`, en 줄 파일이 `daily-fortune.yaml`이어도 같은 `(slot, key, type, variant)`의 ko text가 `source`. ko에 없으면 `""`.
  * `test_bundle_is_file_stem` 과 `test_rows_keep_file_order`.
  * `test_place_text`: `where="오늘 화면 머리"`, en 상한 40 → `"오늘 화면 머리\n최대 40자"`. 바이트 단위면 `최대 40바이트`, `max_lines=2`면 `최대 40자, 2줄`, UNBOUNDED면 `상한 없음`, None이면 `상한 미정`, 키별 상한이 있으면 그 값.
  * `test_example_glossary`: 슬롯 params `{"stem": glossary(stem)}`, 용어집 en `stem.gap="Gap Wood"`, `stem.eul="Eul Wood"` 순서 → `"{stem} today"` 예시 `"Gap Wood today"`.
  * `test_example_list`: 두 값 `", "`로 이음.
  * `test_example_plural`: `"{count, plural, one {# day} other {# days}}"` → 형태별 줄 `"1 day\n3 days"`가 아니라 `icu.expand_entry`가 주는 형태 각각에 `count=3`을 넣은 결과를 줄바꿈으로 이음(테스트는 `expand_entry` 결과 개수만큼 줄이 있고 `3`이 들어 있음을 확인).
  * `test_example_name_and_text`: `"{name}, see {date}"` en → `"Alex, see ‹date›"`, ja 호칭 `ゆき`.
  * `test_example_strips_tokens`: `"[[Bigyeop|ten_god_group.bigyeop]] comes"` → `"Bigyeop comes"`.
  * `test_bundles_for`: `tier=1` → 차수 1 튜플, `bundles=["ui","store"]` → 그 순서, 둘 다 또는 둘 다 없음, 모르는 묶음 → `ValueError`.
  * `test_repo_tier_coverage` (`@pytest.mark.contract`): 저장소 `content/en`, `content/ja`에 `check_tier_coverage` 결과가 `[]`.
  * `test_repo_tier1_rows` (`contract`): 저장소 원고로 en 1차 `build_rows`가 예외 없이 묶음 네 개를 내고 모든 행 `current`가 비어 있지 않음.

- [ ] **Step 2: 실패 확인** `uv run pytest tests/test_review_export.py -q` → FAIL.

- [ ] **Step 3: 구현**
  * 예시 값은 `placeholders.substitute`의 `value_of`로 넣습니다. 종류를 해석하지 못하면 자리표시자 원문(`{x}`)을 그대로 돌려줍니다. 복수형은 `icu.expand_entry(entry)`의 각 형태 text에 같은 치환을 하고 `"\n"`으로 잇습니다.
  * `text` 종류 값은 `f"‹{placeholder.name}›"`.
  * 용어 토큰 표시 지우기가 ValueError면 원문 그대로.

- [ ] **Step 4: 통과 확인** `uv run pytest tests/test_review_export.py -q && uv run ruff check . && uv run mypy src` → PASS.

- [ ] **Step 5: Commit** `feat(writing): 원고에서 검수 행 만들기 (#1283)`

### Task 3: 안내 원문과 `review-export` 명령

**Files:**
- Create: `../review/guide-en.md`, `../review/guide-ja.md`
- Modify: `src/mlw/paths.py` (`REVIEW_DIR = WRITING_DIR / "review"`), `src/mlw/cli.py`
- Test: `tests/test_cli.py`에 추가

**Interfaces:**
- Consumes: Task 1 `write_sheet`, `SheetMeta`; Task 2 `bundles_for`, `check_tier_coverage`, `build_rows`.
- Produces: `mlw review-export <content> --lang {en,ja} (--tier N | --bundle a,b) [--out PATH]`. 종료 코드 0 성공, 1 차수 표 불일치나 잘못된 인자.

- [ ] **Step 1: 안내 원문 작성**
  문단은 빈 줄로 나눕니다(문단 하나가 셀 하나). 각 언어 원어로, 내용은 spec §4.1 안내 탭 항목 순서 그대로: 이 시트의 목적, 칸 설명(편집할 칸은 Suggestion, Category, Note 셋뿐), 톤(`guide/voice-tone.md` 요약), 고치면 안 되는 것(`{...}` 자리표시자, ICU 복수형 구조, Example 칸은 참고용), 글자 상한, 분류 네 값의 뜻, 금지 문자(긴 대시, 범위 대시, 가운뎃점), 작성 예 한 줄. 마지막 문단에 한국어 요약 한 문단.

- [ ] **Step 2: 실패하는 test 작성** (`tests/test_cli.py`)
  * `test_review_export_tier1`: `main(["review-export", str(CONTENT_DIR), "--lang", "en", "--tier", "1", "--out", str(tmp_path/"t.xlsx")])` → 0, `read_sheet` 메타 `lang == "en"`, `commit`이 40자 16진수, 묶음 집합 `{"store","ui","system","web"}`, 안내 탭 첫 셀이 `guide-en.md` 첫 문단.
  * `test_review_export_bundle_name`: `--bundle store,ui`, `--out` 없이 `REVIEW_DIR`을 `tmp_path`로 monkeypatch → `tmp_path/"en"/"store-ui.xlsx"` 생김.
  * `test_review_export_rejects_ko`: `--lang ko` → argparse `SystemExit`.

- [ ] **Step 3: 실패 확인** `uv run pytest tests/test_cli.py -q -k review_export` → FAIL.

- [ ] **Step 4: 구현**
  * commit은 `git rev-parse HEAD`(`subprocess.run(..., cwd=paths.WRITING_DIR, check=True)`), 도구 버전은 `importlib.metadata.version("myungli-writing")`, 날짜는 `date.today().isoformat()`.
  * `--tier`, `--bundle`은 argparse 상호 배타 그룹(required). `check_tier_coverage`가 비지 않으면 파일 이름을 `review.tier_coverage error` 형식으로 출력하고 1.
  * 성공하면 출력 경로 한 줄을 찍습니다.

- [ ] **Step 5: 통과 확인** `uv run pytest tests/test_cli.py -q && uv run ruff check . && uv run mypy src` → PASS.

- [ ] **Step 6: Commit** `feat(writing): mlw review-export (#1283)`

### Task 4: 검사 묶음 꺼내기

**Files:**
- Modify: `src/mlw/cli.py:345-381`
- Test: 기존 `tests/test_cli.py`

**Interfaces:**
- Produces: `CheckInputs` frozen dataclass(`rules_dir, slots_dir, message_keys, message_params, evidence_rules, evidence_sources, fixture: Path, ia: Sequence[Path]`), `CheckInputs.from_args(args) -> CheckInputs`, `default_check_inputs() -> CheckInputs`(paths 기본값), `collect_findings(inputs: CheckInputs, content_dir: Path, *, partial: bool = False) -> list[Finding]`. `_check`는 `_print_findings(collect_findings(...))`만 합니다.

- [ ] **Step 1: 동작을 바꾸지 않는 리팩터링**
  `_check` 본문을 `collect_findings`로 옮깁니다. conftest 캐시가 감싸는 함수(`load_rules` 등)는 여전히 `mlw.cli` 모듈 이름으로 부릅니다(캐시가 걸리도록).

- [ ] **Step 2: 확인** `uv run pytest -q && uv run mlw check ../content` → 전부 PASS, `OK`(기존과 같은 출력).

- [ ] **Step 3: Commit** `refactor(writing): check 검사 묶음을 collect_findings로 꺼냄 (#1283)`

### Task 5: 수정안 판정과 원고 쓰기

**Files:**
- Create: `src/mlw/review/apply.py`
- Test: `tests/test_review_apply.py`

**Interfaces:**
- Consumes: `ReviewRow`(Task 1), `row_id`(Task 2), `collect_findings`, `CheckInputs`(Task 4), `load_content`, `placeholders.parse/parse_tokens`.
- Produces:
  - `Outcome` frozen dataclass: `row_id: str, applied: bool, reason: str = ""`; `Outcome.text` → `"반영함"` 또는 `f"반영 안 함: {reason}"`
  - `rewind_tokens(current: str, suggestion: str) -> str | None` (토큰 되감기, 실패 None)
  - `prejudge(rows: Sequence[ReviewRow], entries_by_id: Mapping[str, Entry]) -> tuple[dict[str, str], list[Outcome]]` (id → 쓸 새 text, 미리 걸린 결과)
  - `replace_text_in_line(line: str, new_text: str) -> str` (한 줄 flow mapping의 `text: "..."`만 교체, 형식이 다르면 ValueError)
  - `write_texts(content_dir: Path, changes: Mapping[Entry, str]) -> None`
  - `apply_review(content_dir: Path, rows: Sequence[ReviewRow], lang: str, inputs: CheckInputs, *, dry_run: bool) -> list[Outcome]`

이유 문구(정확히 이 글자):
`writing 판정: <내용>`, `원고에 없는 줄`, `같은 줄이 두 번`, `내보낸 뒤 원고가 바뀜, 다시 확인`, `자리표시자가 바뀜`, `용어 표기가 바뀜, writing이 직접 반영`, `변경 없음`, `원고 줄 형식을 바꿀 수 없음`, `검사: <rule_id> <message>`.

- [ ] **Step 1: 실패하는 test 작성**
  * `test_prejudge_reasons`: 위 이유마다 행 하나씩 만들어 각 결과 이유가 정확히 그 문구. 수정안 빈 행은 결과에 없음.
  * `test_placeholder_multiset`: 현재 `"{a} and {b}"`, 수정안 `"{b} then {a}"`는 통과, `"{a} only"`와 `"{a} {a} {b}"`는 `자리표시자가 바뀜`.
  * `test_rewind_tokens`: 현재 `"With [[Bigyeop|ten_god_group.bigyeop]] here"`, 수정안 `"Bigyeop is here"` → `"[[Bigyeop|ten_god_group.bigyeop]] is here"`. 수정안에 토큰이 그대로 있으면 그대로. 표기 `Bigyeop`이 없으면 None. 토큰 둘이면 앞에서부터 차례로.
  * `test_replace_text_in_line`: `'- {slot: a, key: b, text: "old"}'` → `"new \"q\" \\ x\ny"` 넣고 `yaml.safe_load`가 같은 text를 돌려줌. `text: 'x'`(작은따옴표)는 ValueError.
  * `test_write_texts_preserves_file`: 주석 두 줄과 원고 세 줄 파일에서 1, 3번째 원고를 바꾸면 주석과 2번째 줄은 바이트 그대로, 줄 수 같음.
  * `test_apply_review_end_to_end`(tmp 사본): `shutil.copytree(CONTENT_DIR, tmp)` 뒤 en `store.yaml` 한 줄 수정안(상한 안)은 반영, 다른 줄 수정안에 가운뎃점 `·`를 넣으면 `검사:`로 시작하는 이유로 반영 안 함, 그 파일의 해당 줄은 원래 text. `dry_run=True`면 파일이 바뀌지 않음.

- [ ] **Step 2: 실패 확인** `uv run pytest tests/test_review_apply.py -q` → FAIL.

- [ ] **Step 3: 구현**
  * `replace_text_in_line`: 정규식 `text: "(?:[^"\\]|\\.)*"`가 그 줄에 정확히 한 번이어야 합니다. 새 값은 `yaml.dump(new_text, default_style='"', allow_unicode=True, width=10**9)`에서 끝 줄바꿈(과 있으면 `...` 문서 끝 표시)을 뗀 문자열. 교체한 줄을 `yaml.safe_load`해 text가 같은지 확인하고 아니면 ValueError.
  * `apply_review` 순서: `load_content`로 `row_id(entry)` 맵(대상 언어만) → `prejudge` → tmp 디렉터리에 `content_dir` 복사, `write_texts` → `collect_findings(inputs, tmp)`에서 `severity == "error"`이고 `(file 이름, line)`이 바뀐 줄인 finding을 찾아 그 행을 원래 text로 되돌림 → 더 없을 때까지 반복 → `dry_run`이 아니면 남은 변경을 실제 `content_dir`에 `write_texts`.
  * tmp 사본의 finding 경로는 tmp 기준이므로 `content_dir` 상대 경로로 비교합니다.
  * 바뀐 줄과 상관없는 기존 error는 무시합니다(반영과 무관).

- [ ] **Step 4: 통과 확인** `uv run pytest tests/test_review_apply.py -q && uv run ruff check . && uv run mypy src` → PASS.

- [ ] **Step 5: Commit** `feat(writing): 검수 수정안 판정과 원고 반영 (#1283)`

### Task 6: `review-import` 명령

**Files:**
- Modify: `src/mlw/cli.py`
- Test: `tests/test_cli.py`에 추가

**Interfaces:**
- Consumes: `read_sheet`, `write_results`(Task 1), `apply_review`, `Outcome`(Task 5), `CheckInputs`, `collect_findings`(Task 4), `render_docs`, `write_docs`.
- Produces: `mlw review-import <content> <sheet.xlsx> [--dry-run] [--out-dir DIR]`. 종료 코드: 0(반영 안 한 행이 있어도), 1(끝 검사에 error), 2(시트를 읽지 못함).

- [ ] **Step 1: 실패하는 test 작성** (tmp 원고 사본, `--out-dir`은 생성물 출력 위치)
  * `test_review_import_round_trip`: `review-export`로 `--bundle store` 시트를 만들고 openpyxl로 한 행 수정안과 분류 `Grammar (문법)`을 넣어 저장 → `review-import` 0, 사본 `content/en/store.yaml` 그 줄 변경, `<이름>-result.xlsx`에 `반영함`, `--out-dir` 아래 `web/en.json`이나 store 생성물이 새 문장을 담음.
  * `test_review_import_dry_run`: 원고와 `--out-dir`이 그대로, 결과 시트는 생김.
  * `test_review_import_summary`: stdout에 `반영 1`, `반영 안 함 1`, 이유별 줄, `용어 분류 0`이 나옴(형식: 한 줄에 하나).
  * `test_review_import_warns_repo_path`: 시트 경로가 `paths.WRITING_DIR` 아래면 stderr에 `저장소 안 시트` 경고.

- [ ] **Step 2: 실패 확인** `uv run pytest tests/test_cli.py -q -k review_import` → FAIL.

- [ ] **Step 3: 구현**
  끝 단계: dry-run이 아니면 `write_docs(out_dir, render_docs(...))`(기본 `paths.GENERATED_DIR`) 뒤 `collect_findings(default_check_inputs(), content)`를 출력하고 그 종료 코드를 따릅니다.

- [ ] **Step 4: 통과 확인** `uv run pytest -q && uv run ruff check . && uv run mypy src` → PASS.

- [ ] **Step 5: Commit** `feat(writing): mlw review-import (#1283)`

### Task 7: 기록, 1차 시트, PR

**Files:**
- Modify: `pyproject.toml`(0.16.0), `uv.lock`(버전 줄), `../decisions.md`(W84), `../guide/review-procedure.md`, `../CLAUDE.md`(진행 중), `../../../../docs/contracts/README.md`(검사기 행), `../../../../docs/contracts/CHANGELOG.md`
- Create: `../review/en/tier1.xlsx`, `../review/ja/tier1.xlsx`

- [ ] **Step 1: 기록**
  * W84: spec §2, §3 요지(xlsx를 Google Sheets로 감수, 차수 표, 돌아온 시트는 로컬만, `사용자 영향` 없음).
  * `review-procedure.md`에 "## 원어민 검수 (E18)" 절: 내보내기 명령, Drive 업로드와 공유, xlsx 받기와 로컬 보관 경로, `review-import --dry-run` 먼저, 이유별 처리.
  * 계약 표 검사기 행 0.16.0, CHANGELOG 검사기 절 맨 위에 `review-export`, `review-import` 추가.

- [ ] **Step 2: 1차 시트 내보내기**
  Run: `uv run mlw review-export ../content --lang en --tier 1 && uv run mlw review-export ../content --lang ja --tier 1`
  Expected: 두 경로 출력, 파일 생김.

- [ ] **Step 3: 전체 확인**
  Run: `uv sync --frozen && uv run ruff check . && uv run mypy src && uv run pytest -q && uv run mlw gen-docs --check && uv run mlw check ../content`
  Expected: 모두 통과, `OK`.

- [ ] **Step 4: Commit, push, PR**
  commit `docs(writing): 검수 시트 기록과 1차 시트 (#1283, W84)`. `git push -u origin writing/review-sheet-1283`, base `staging`, 본문 `Closes #1283`.

- [ ] **Step 5: Issue 코멘트**
  #1283에 1차 시트 위치(`docs/identity/writing/review/{en,ja}/tier1.xlsx`, PR 브랜치), Sheets 업로드 절차 한 줄, 다시 읽기 명령을 남깁니다.

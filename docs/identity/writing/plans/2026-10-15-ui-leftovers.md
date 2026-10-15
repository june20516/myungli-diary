# 공용 ui 문구와 ICU plural Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** app 임시 문구 116개를 writing 원고와 ARB로 바꾸고, 검사기가 ICU plural을 받게 합니다(#143).

**Architecture:**
- 검사기에 `icu.py`(plural 파싱·펼치기·형태 검사)를 더하고, 문장·표기·자리표시자 검사와 `check-arb`가 펼친 문장을 검사하게 합니다.
- `arb_export`가 glossary 범주 `branch`·`day_kind` 이름 원고도 ARB 키로 냅니다.
- 공용 ui 슬롯 `slots/ui/common.yaml`(15개 슬롯, 키 100개)과 3개 언어 원고, glossary 이름 원고 16개를 씁니다.

**Tech Stack:** Python 3.13 + uv, pytest, ruff, mypy, regex (기존 `docs/identity/writing/tools`)

**Spec:** `docs/identity/writing/specs/2026-10-15-ui-leftovers-design.md`

## Global Constraints

- 고치는 곳은 `docs/identity/writing/`, `.github/workflows/writing.yml`(#148, 이미 커밋), GitHub Issues뿐입니다. `app/`은 읽기만 합니다.
- 명령은 `docs/identity/writing/tools`에서 실행합니다. CI 단계는 다음과 같습니다.
  - `uv run ruff check .`
  - `uv run mypy src`
  - `uv run pytest -q`
  - `uv run mlw gen-docs --check`
  - `uv run mlw check ../content --partial`
- app 키 이름, 자리표시자 이름과 타입(`int` → `number`, `String` → `text`)은 바꾸지 않습니다. 기준은 `app/lib/core/l10n/arb/app_ko.arb`입니다.
- plural 형태: ko `other`, ja `other`, en `one`·`other`(정확히 이 집합). 문장 안에서는 `#` 대신 `{<변수>}`를 씁니다.
- glossary ARB 범주: `("branch", "day_kind")`. 키는 `.`·`_` 경계 lowerCamelCase입니다(`day_kind.yongsin_day` → `dayKindYongsinDay`).
- 새 규칙 id: `icu.plural`(error), `arb.duplicate_key`(LoadError). 검사기 버전은 `0.3.0`입니다.
- 코드 주석과 문서는 기존 파일처럼 합니다체로 쓰고, 원고는 가이드(해요체 W6, 느낌표·말줄임 금지)를 따릅니다.

## Review Focus

1. plural 앞뒤에 글자가 있는 원고(`"검색 결과 {count, plural, other{{count}개}}"`): 펼친 문장마다 앞뒤 글자가 붙어 검사됩니다.
2. plural 안 문장에 잘못된 자리표시자(`{cnt}`): 펼친 문장의 자리표시자 대조에서 `complete.unknown_param`이 납니다.
3. 형태 이름 오타(`others{…}`)나 중괄호 짝이 안 맞는 원고: 검사기가 죽지 않고 `icu.plural`로 보고합니다.
4. ARB 파일에서 plural 값이 언어 형태와 다름(ko ARB에 `one`): `check-arb`가 `icu.plural`을 냅니다.
5. glossary 원고가 한 언어에만 있음(en `branch.in` 없음): 그 언어 ARB에서 키가 빠지고(기존 규칙) 오류가 나지 않습니다.

---

### Task 1: ICU plural 모듈

**Files:**
- Create: `tools/src/mlw/icu.py`
- Test: `tools/tests/test_icu.py`

**Interfaces:**
- Produces:
  - `RULE_PLURAL = "icu.plural"`
  - `PLURAL_FORMS: dict[str, frozenset[str]]` (ko·ja `{"other"}`, en `{"one", "other"}`)
  - `@dataclass(frozen=True) class Plural: variable: str; forms: dict[str, str]; prefix: str; suffix: str`
  - `parse_plural(text: str) -> Plural | None`: plural이 없으면 None, 문법이 틀리면 `ValueError`
  - `expand_plural(text: str) -> list[str]`: plural이 없으면 `[text]`, 있으면 형태 순서대로 `prefix + 문장 + suffix`. 문법이 틀리면 `ValueError`
  - `plural_problem(text: str, lang: str) -> str | None`: 문법 오류 또는 형태 집합이 `PLURAL_FORMS[lang]`과 다르면 이유

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_no_plural():
    assert parse_plural("결과 {count}개") is None
    assert expand_plural("결과 {count}개") == ["결과 {count}개"]

def test_expand_with_prefix_suffix():
    text = "Found {count, plural, one{{count} city} other{{count} cities}}."
    assert expand_plural(text) == ["Found {count} city.", "Found {count} cities."]
    assert parse_plural(text).variable == "count"

def test_bad_syntax_raises():
    for text in ["{count, plural, other{a}", "{count, plural, other a}", "{count, plural, }",
                 "{a, plural, other{x}} {b, plural, other{y}}"]:
        with pytest.raises(ValueError):
            expand_plural(text)

def test_forms_by_lang():
    assert plural_problem("{count, plural, other{{count}개}}", "ko") is None
    assert plural_problem("{count, plural, one{a} other{b}}", "ko") is not None
    assert plural_problem("{count, plural, other{b}}", "en") is not None
    assert plural_problem("{count, plural, one{a} other{b}}", "en") is None
    assert plural_problem("{count, plural, others{b}}", "ja") is not None
    assert plural_problem("결과", "ko") is None
```

- [ ] **Step 2: `uv run pytest tests/test_icu.py -q` 실행 → import 오류로 FAIL 확인**

- [ ] **Step 3: `icu.py` 구현**

정규식 `\{\s*(\w+)\s*,\s*plural\s*,`로 시작 위치를 찾고, 그 뒤를 직접 훑어 `<형태>{<중괄호 짝을 센 문장>}`을 반복해서 읽은 다음 닫는 `}`까지 처리합니다. 형태가 0개이거나, 같은 형태가 두 번 나오거나, 짝이 안 맞거나, plural이 두 개 이상이면 `ValueError`입니다.

- [ ] **Step 4: `uv run pytest tests/test_icu.py -q` 실행 → PASS 확인**

- [ ] **Step 5: Commit** `feat(writing): ICU plural 파싱·펼치기 (#143)`

### Task 2: 검사기에 plural 연결, v0.3.0

**Files:**
- Modify: `tools/src/mlw/cli.py`(`sentence_findings`, `markup_findings`, `_check`), `tools/src/mlw/completeness.py`(`_check_placeholders`), `tools/src/mlw/arb.py`(`check_arb`), `tools/pyproject.toml`(version), `tools/uv.lock`
- Test: `tools/tests/test_cli.py`, `tools/tests/test_arb.py`, `tools/tests/test_completeness.py`

**Interfaces:**
- Consumes: Task 1의 `expand_plural`, `parse_plural`, `plural_problem`, `RULE_PLURAL`
- Produces: `plural_findings(slots: Mapping[str, Slot], entries: Sequence[Entry]) -> list[Finding]`(cli.py). 원고 하나당 문제 하나씩입니다.
  - `plural_problem`
  - 변수가 그 키의 `number` 매개변수가 아님
  - content 슬롯(ui가 아닌 슬롯)에 plural이 있음

- [ ] **Step 1: 실패하는 테스트 작성**
  - `test_cli.py`
    - ui 슬롯 키 `citySearchResults`(params `count: number`)에 ko `"결과 {count, plural, other{{count}개}}"`를 넣으면 `plural_findings`가 `[]`이고, `sentence_findings`·`markup_findings`에 `placeholder.syntax` 같은 문법 오류가 없습니다.
    - 같은 원고를 ko `one{…} other{…}`로 쓰면 `icu.plural` 1개가 납니다.
    - 변수가 `text` 매개변수면 `icu.plural`이 납니다.
    - content 슬롯 원고에 plural이 있으면 `icu.plural`이 납니다.
    - 펼친 문장 하나에 느낌표가 있으면(`other{{count}개!}`) 해당 slop 규칙 finding이 납니다.
  - `test_completeness.py`: plural 문장 안에 `{cnt}`(없는 매개변수)가 있으면 `complete.unknown_param`이 납니다.
  - `test_arb.py`
    - ko ARB `{"@@locale":"ko","citySearchResults":"결과 {count, plural, other{{count}개}}"}`는 finding이 없습니다.
    - 같은 키를 `one{…} other{…}`로 쓰면 `icu.plural`이 납니다.
    - 중괄호 짝이 안 맞으면 `icu.plural`이 나고 예외가 나지 않습니다.

- [ ] **Step 2: `uv run pytest tests/test_cli.py tests/test_arb.py tests/test_completeness.py -q` 실행 → 새 테스트 FAIL 확인**

- [ ] **Step 3: 구현**
  - `sentence_findings`·`markup_findings`: `parse_plural`이 `ValueError`를 내지 않으면 `expand_plural`로 펼친 문장마다 `dataclasses.replace(entry, text=form)`로 검사합니다. 같은 `(rule_id, message)`는 한 번만 냅니다. 문법 오류인 원고는 펼치지 않고 건너뜁니다(`plural_findings`가 보고).
  - `_check_placeholders`: 펼친 문장마다 `parse`합니다. 문법 오류면 지금처럼 `[]`입니다.
  - `_check`: `findings`에 `*plural_findings(all_slots, entries)`를 더합니다.
  - `check_arb`: 값마다 `plural_problem(value, lang)`가 있으면 `icu.plural`을 내고 그 값은 건너뜁니다. 없으면 펼친 문장마다 `check_sentence`를 돌립니다.
  - `pyproject.toml` version을 `0.3.0`으로 바꾸고 `uv lock`을 실행합니다.

- [ ] **Step 4: CI 단계 다섯 개(Global Constraints) 실행 → 모두 통과 확인**

- [ ] **Step 5: Commit** `feat(writing): check·check-arb가 ICU plural을 펼쳐 검사, 검사기 v0.3.0 (#143)`

### Task 3: glossary 이름을 ARB로

**Files:**
- Modify: `tools/src/mlw/arb_export.py`
- Test: `tools/tests/test_arb_export.py`

**Interfaces:**
- Produces:
  - `ARB_TERM_CATEGORIES = ("branch", "day_kind")`
  - `term_arb_key(term_id: str) -> str`
  - `render_arb`(signature 그대로)가 `glossary.value_name` 슬롯 원고 중 범주가 `ARB_TERM_CATEGORIES`인 키를 ui 키 뒤에 glossary 슬롯 키 순서대로 냅니다. 메타데이터는 ko에만 `{"description": "glossary.value_name: <용어 id>"}`입니다.
  - 키가 ui 키와 겹치면 `LoadError([Finding(slot.file, slot.line, "arb.duplicate_key", "error", …)])`입니다.

- [ ] **Step 1: 실패하는 테스트 작성**
  - `term_arb_key("branch.in") == "branchIn"`
  - `term_arb_key("day_kind.yongsin_day") == "dayKindYongsinDay"`
  - glossary 슬롯(`glossary.value_name`, content 그룹, 키 `branch.in`·`element.wood`)과 원고 ko `인`·`목`이 있으면, ko ARB에 `branchIn: "인"`과 그 메타데이터가 있고 `elementWood`는 없습니다.
  - en 원고에 `branch.in`이 없으면 en ARB에 `branchIn`이 없습니다(Review Focus 5).
  - ui 슬롯에 키 `branchIn`이 이미 있으면 `pytest.raises(LoadError)`입니다.

- [ ] **Step 2: `uv run pytest tests/test_arb_export.py -q` 실행 → FAIL 확인**

- [ ] **Step 3: 구현.** 범주는 용어 id의 첫 `.` 앞부분입니다. 모듈 docstring에 glossary 내보내기를 한 줄로 더합니다.

- [ ] **Step 4: CI 단계 다섯 개 실행 → 통과 확인**(`gen-docs --check`는 glossary 원고가 없으므로 변화 없음)

- [ ] **Step 5: Commit** `feat(writing): 지지·날의 성격 이름을 ARB로 내보냄 (#143)`

### Task 4: 공용 ui 슬롯과 원고

**Files:**
- Create: `slots/ui/common.yaml`
- Modify: `content/ko/ui.yaml`, `content/en/ui.yaml`, `content/ja/ui.yaml`, `generated/*`(gen-docs)

**Interfaces:**
- Consumes: Task 2의 plural 검사(`citySearchResults`)

- [ ] **Step 1: `common.yaml` 작성.** 슬롯 15개의 id·components·키는 spec §2 표를 따릅니다.
  - 필수 필드는 `slots/ui/depth.yaml`과 같은 형식입니다. 파일 머리 주석에는 #143과 "키 이름은 app 이름 그대로"를 적습니다.
  - `max_length`는 모두 `{ko: null, en: null, ja: null}`입니다.
  - 매개변수가 있는 키
    - `traceIdLabel{traceId: text}`
    - `termTokenSemantics{term: text}`
    - `inputStepProgress{step: number, stepCount: number}`
    - `textFieldCounter{current: number, max: number}`
    - `datePicker{Year,Month,Day}Item{year|month|day: number}`
    - `timePickerHourItem{hour: number}`
    - `timePickerMinuteItem{minute: text}`
    - `datePickerLeapMonthValue{month: number}`
    - `citySearchResults{count: number}`
  - `ui.login.provider`의 `allowed`에는 Step 3에서 실제로 걸린 규칙만 근거와 함께 적습니다.

- [ ] **Step 2: 3개 언어 원고 작성.** app 임시 문구에서 출발해 가이드에 맞게 고칩니다.
  - 해요체(W6), 느낌표·말줄임 금지, ja です・ます, en 평서문을 따릅니다.
  - 입력칸 이름은 hint와 다른 말로 씁니다. 예: `onboardCallInputLabel` ko "불러 드릴 이름", `birthplaceSearchLabel` ko "태어난 도시 찾기".
  - 로그인 라벨은 제공자 문구 그대로 씁니다. ko "카카오 로그인"·"Apple로 로그인", en "Login with Kakao"·"Sign in with Apple", ja "Login with Kakao"·"Appleでサインイン".
  - `citySearchResults`는 ko `"결과 {count, plural, other{{count}개}}"`, ja `"{count, plural, other{結果{count}件}}"`, en `"{count, plural, one{{count} result} other{{count} results}}"`입니다.

- [ ] **Step 3: `uv run mlw check ../content --partial` 실행.** error가 나면 원고를 고치거나, 제공자 문구처럼 정당한 경우만 `allowed`에 적습니다. 결과가 error 0개여야 합니다.

- [ ] **Step 4: `uv run mlw gen-docs` 후 CI 단계 다섯 개 실행 → 통과 확인**

- [ ] **Step 5: Commit** `writing: 공용 ui 슬롯 15개와 3개 언어 원고 — app 임시 문구 100개 (#143)`

### Task 5: 지지·날의 성격 이름 원고

**Files:**
- Create: `content/ko/glossary.yaml`, `content/en/glossary.yaml`, `content/ja/glossary.yaml`
- Modify: `generated/*`(gen-docs)

**Interfaces:**
- Consumes: Task 3의 glossary ARB 내보내기

- [ ] **Step 1: 원고 작성.** 형식은 `- {slot: glossary.value_name, key: branch.in, text: "인"}`이고 파일 머리 주석에 W1에서 나머지를 채운다고 적습니다.
  - ko: 지지 `자 축 인 묘 진 사 오 미 신 유 술 해`, 날의 성격 `귀인의 날`·`용신의 날`·`기신의 날`·`평범한 날`
  - ja: 지지 `子 丑 寅 卯 辰 巳 午 未 申 酉 戌 亥`, 날의 성격 `貴人の日`·`用神の日`·`忌神の日`·`普通の日`
  - en: 지지 `Rat Ox Tiger Rabbit Dragon Snake Horse Goat Monkey Rooster Dog Pig`, 날의 성격은 뜻이 보이는 이름으로 씁니다. 원어민 검수 전 초안입니다. 기신의 날은 겁주지 않는 이름이고(브랜드 원칙), 용신의 날은 좋은 날이 보이는 이름입니다(D20).

- [ ] **Step 2: `uv run mlw gen-docs` 후 CI 단계 다섯 개 실행 → 통과 확인**

- [ ] **Step 3: app 임시 키가 남지 않았는지 확인(일회성, 커밋하지 않음)**

Run(저장소 루트):
```bash
python3 -c "import json;a=json.load(open('app/lib/core/l10n/arb/app_ko.arb'));w=json.load(open('docs/identity/writing/generated/arb/app_ko.arb'));print([k for k in a if not k.startswith('@') and k not in w])"
```
Expected: `[]`
같은 스크립트로 app ARB의 `@키.placeholders` 타입과 writing ARB 타입이 같은지도 확인합니다. 출력은 차이 없음이어야 합니다.

- [ ] **Step 4: Commit** `writing: 지지·날의 성격 이름 원고 3개 언어와 ARB (#143)`

### Task 6: 결정·가이드·상태 기록

**Files:**
- Modify: `decisions.md`(W22), `guide/voice-tone.md`(영어·일본어 표), `CLAUDE.md`(현재 상태, 다음 할 일)

- [ ] **Step 1: W22 기록.** 다음을 한 행에 적습니다. 근거는 #143, spec, 사용자 결정(en 지지 B안)입니다.
  - 공용 ui 슬롯 `ui.*`에서 app 키 이름을 그대로 쓰기
  - 슬롯 밖 문구도 writing 원고로 쓰기
  - 지지·날의 성격 ARB는 glossary 이름 원고에서 만들기
  - en 지지는 띠 동물, 날의 성격은 뜻이 보이는 이름(로마자 예외)
  - 카카오 en·ja는 "Login with Kakao"
  - ICU plural 허용(ko·ja `other`, en `one`·`other`, ui 원고만)

- [ ] **Step 2: voice-tone 표 갱신.** en 용어 토큰 칸에 "지지는 띠 동물, 날의 성격은 뜻이 보이는 이름(W22)"을 더합니다.

- [ ] **Step 3: CLAUDE.md 갱신.** 현재 상태에 이 브랜치와 산출물을 넣고, 다음 할 일에서 #148·#143 항목을 PR 번호로 바꿉니다.

- [ ] **Step 4: CI 단계 다섯 개 실행 → 통과 확인 후 Commit** `docs(writing): W22 공용 ui 문구·plural·en 지지 이름`

### Task 7: PR과 요청함 보고

- [ ] **Step 1: `git push` 후 PR 생성.** 제목은 `writing: 공용 ui 문구 116개, ICU plural, ci-gate 3단계 (#143·#148)`입니다. 본문에는 다음을 적습니다.
  - 요약
  - 키 목록 위치
  - app 할 일: `dart run tool/import_writing_arb.dart` 후 `flutter gen-l10n`. `citySearchResults`가 plural로 바뀜
  - 검증 명령 결과
- [ ] **Step 2: #143 코멘트.** 키별 처리와 가져오기 방법을 적고, 지지 이름 en이 띠 동물이라는 점을 알립니다. 닫는 것은 app 확인 뒤입니다(workflow §5.2).
- [ ] **Step 3: #148 코멘트.** PR 번호를 적습니다.
- [ ] **Step 4: #131 코멘트.** 새 공용 ui 슬롯 15개의 글자 수 상한도 요청합니다.

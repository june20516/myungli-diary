# 라이팅 시스템 기반 (W0) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 슬롯 명세·규칙 데이터(YAML)와 그것을 읽는 검사기 `mlw`를 만들고, n지선다 라운드 R1~R7로 규칙 값을 채워 W0을 마칩니다.

**Architecture:** `docs/identity/writing/rules/`·`slots/`의 YAML이 원본입니다. `tools/`의 Python 패키지 `mlw`가 이 YAML을 읽어 원고(`content/<lang>/*.yaml`)와 ARB를 검사하고, 사람이 읽는 표를 `generated/`에 만듭니다. 한 주 단위 검사는 엔진 gRPC로 만든 고정 자료를 씁니다.

**Tech Stack:** Python 3.13, uv 0.11.3, PyYAML, `regex`(유니코드 속성), grpcio 1.84.0 + grpcio-tools(클라이언트 생성 코드), pytest, ruff, mypy strict.

**Spec:** `docs/identity/writing/specs/2026-10-10-writing-system-foundation-design.md`

## Global Constraints

* 고칠 수 있는 경로: `docs/identity/writing/`, `docs/coordination/`, `.github/workflows/writing.yml`. 그 밖(특히 `core/`, `proto/`)은 읽기만 합니다.
* 커밋 범위 표기: `feat(writing): …`, `docs(writing): …`, `test(writing): …`, `ci(writing): …`. 커밋 메시지 끝에 세션의 attribution 줄을 붙입니다.
* 패키지 관례는 `core/pyproject.toml`을 따릅니다: `requires-python = ">=3.13"`, hatchling, `src/` 레이아웃, ruff `line-length = 110`, mypy `strict = true`, 생성 코드(`src/mlw/_gen/`)는 ruff·mypy 제외.
* 패키지 이름 `myungli-writing`, import 이름 `mlw`, 콘솔 스크립트 `mlw = "mlw.cli:main"`.
* 실행 형태: 저장소 루트에서 `uv run --project docs/identity/writing/tools mlw <명령>`. 경로 인자가 없으면 기준 디렉터리는 `docs/identity/writing/`(패키지 위치에서 계산)입니다.
* 메시지 키 원본: `core/message_keys.json`(93개). enum 원본: `proto/myungli/engine/v1/engine.proto`를 `tools/gen_proto.sh`로 생성한 `mlw._gen`.
* 언어 코드: `ko`, `en`, `ja`. 문장 유형: `advice`, `state`, `care`. 슬롯 목적: `info`, `guide`, `care`. 심각도: `error`, `warn`. 범위(scope): `sentence`, `slot`, `screen`, `day`, `week`.
* 결과 출력 한 줄 형식: `<파일>:<줄> <규칙ID> <심각도> <메시지>`. `error`가 하나라도 있으면 종료 코드 1, YAML 로드·구조 오류면 2, 그 밖에는 0.
* 문서·주석·메시지는 한국어 경어체, 이 저장소 문서 문체(짧은 문장, "~합니다")를 따릅니다.
* 라운드 task(Task 11~13)는 subagent에게 넘기지 않고 메인 세션이 사용자와 터미널에서 진행합니다.

## Review Focus

1. 원고가 키의 엔진 매개변수에 없는 자리표시자(예: `fortune.*`에 `{direction}`)를 쓰면, 렌더 실패가 아니라 `check`의 `error`로 잡혀야 합니다. 키별 매개변수는 계약이 아니라 엔진 코드에서 옮겨 적은 값이라 어긋날 수 있습니다. → Task 5 테스트, Task 15 요청함.
2. 호칭 입력이 "님" 하나뿐이거나 "님님"이면, "님"을 떼고 나서 빈 값이므로 거부되어야 합니다. → Task 3 테스트.
3. 조사 앞 값이 숫자(`10`, `1`), 라틴 문자(`L`, `A`), 한자(`甲`, `丑`)로 끝나도 맞는 조사가 나와야 하고, 읽을 수 없는 글자(`★` 등)면 병기형이어야 합니다. → Task 3 테스트.
4. 슬롯이 존재하지 않는 규칙 ID를 `allowed`/`forbidden`에 쓰거나 YAML 필드가 빠지면, 파이썬 예외가 아니라 `<파일>:<줄>` 오류로 끝나야 합니다. → Task 2·Task 5 테스트.
5. 엔진 규칙이 바뀌어 한 주 고정 자료에 `message_keys.json`에 없는 키가 있으면, 조용히 건너뛰지 않고 `error`로 알려야 합니다. → Task 8 테스트.

---

## 파일 구조

```
docs/identity/writing/
  rules/slop.yaml limits.yaml style.yaml josa.yaml
  slots/_schema.yaml
  slots/content/daily.yaml chart.yaml calendar.yaml settings.yaml glossary.yaml
  slots/ui/depth.yaml
  content/ko/example.yaml                예시 원고 (CI 대상)
  generated/slop-patterns.md slot-catalog.md josa-table.md
  guide/voice-tone.md review-procedure.md honorific-josa.md
  artifacts/index.json  artifacts/2026-10-10-round-R<n>.md
  tools/
    pyproject.toml uv.lock gen_proto.sh
    fixtures/week_samples.json
    src/mlw/__init__.py
    src/mlw/paths.py         기준 경로(writing 디렉터리, 저장소 루트, message_keys.json)
    src/mlw/model.py         dataclass: Finding, SlopRule, Limit, StyleRule, Slot, Entry, …
    src/mlw/yamlio.py        줄 번호를 보존하는 YAML 읽기
    src/mlw/loader.py        rules/·slots/·content/ 읽기와 구조 검증
    src/mlw/josa.py          받침 판정, 조사 렌더, 호칭 정규화
    src/mlw/placeholders.py  자리표시자 파싱
    src/mlw/sentence.py      문장 단위 검사
    src/mlw/completeness.py  완결성 검사
    src/mlw/bundles.py       화면·하루·한 주 묶음 검사
    src/mlw/week_fixture.py  엔진 gRPC로 한 주 고정 자료 생성
    src/mlw/arb.py           ARB 검사
    src/mlw/docs.py          generated/ 생성
    src/mlw/cli.py           명령 진입점
    src/mlw/_gen/            proto 생성 코드
    tests/…                  모듈별 test_*.py, tests/data/ 작은 예시
.github/workflows/writing.yml
```

---

### Task 1: D40 범위 확인 요청

**Files:**
- Create: `docs/coordination/2026-10-10-writing-to-root-d40-scope.md`

- [ ] **Step 1: `TEMPLATE.md` 형식으로 요청 작성** — `from: writing`, `to: root`, `kind: request`, `status: open`, `related: [D40, W4, W0 spec §4.2]`. "무엇이 필요한가"에 spec §4.2의 표(유형은 총운 35키에만, 가이드 변주 2, 정보·식별자 1)와 언어당 약 219개·3개 언어 약 660개를 적고, "D40의 '콘텐츠 문장'을 총운 슬롯으로 해석해도 되는지" 확인을 요청합니다. "영향"에 server의 유형 순환·반응 저장 대상이 총운 슬롯으로 좁아진다는 점을 적습니다.
- [ ] **Step 2: Commit** — `docs(writing): D40 문장 유형 적용 범위 확인 요청`

### Task 2: 패키지 골격, 모델, YAML 로더

**Files:**
- Create: `tools/pyproject.toml`, `tools/src/mlw/{__init__,paths,model,yamlio,loader}.py`, `rules/{slop,limits,style,josa}.yaml`(초기값), `slots/_schema.yaml`
- Test: `tools/tests/test_loader.py`, `tools/tests/data/broken/*.yaml`

**Interfaces:**
- Produces:
  - `Finding(file: Path, line: int, rule_id: str, severity: Severity, message: str)` frozen dataclass, `Finding.format() -> str`(Global Constraints의 한 줄 형식). `Severity = Literal["error", "warn"]`.
  - `LoadError(Exception)`에 `findings: list[Finding]`.
  - `RuleSet(slop: dict[str, SlopRule], limits: dict[str, Limit], style: dict[str, StyleRule], josa: JosaData)`, `load_rules(rules_dir: Path) -> RuleSet`.
  - `SlopRule(id, name, judge: Literal["rule","llm"], severity, detect: Detect | None, rubric: str | None, exempt_purposes: frozenset[str], examples: Examples, line: int)`. `Detect(kind: Literal["regex","lexicon","template"], pattern: str | None, words: tuple[str, ...], langs: frozenset[str])`.
  - `Limit(id, name, scope, count: CountSelector, max: dict[str, int | None], severity, line)`. `max`는 언어별(`{"ko": 1, "en": 1, "ja": 1}`), YAML에서 정수 하나면 세 언어에 같게 펼칩니다. `CountSelector(placeholder: str | None, type: str | None, rule: str | None)` 중 하나만 채웁니다.
  - `StyleRule(id, name, severity, detect: Detect, exempt_purposes, examples, line)`.
  - `Examples(hit: tuple[Example, ...], pass_: tuple[Example, ...])`, `Example(lang, slot_purpose, text)`.
  - `yamlio.load_with_lines(path: Path) -> list[tuple[dict[str, object], int]]`: 최상위 리스트의 각 항목과 1부터 세는 줄 번호.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_load_rules_reads_seed_files`(실제 `rules/`를 읽어 `slop`에 `slop.P1`~`slop.P8`이 있고 `slop.P8.judge == "rule"`), `test_missing_field_reports_file_and_line`(`tests/data/broken/slop_missing_judge.yaml` → `LoadError`, finding 하나, `line == 3`, `rule_id == "load.schema"`), `test_unknown_judge_value_is_error`, `test_limit_max_int_expands_to_all_langs`.
- [ ] **Step 2: 실행해 실패 확인** — `cd docs/identity/writing/tools && uv run pytest tests/test_loader.py -q` → import 오류로 FAIL.
- [ ] **Step 3: 구현과 초기 규칙 데이터 작성**
  * `pyproject.toml`: dependencies `pyyaml>=6`, `regex>=2024.11`, `grpcio==1.84.0`, `protobuf>=7.35.1`; dev `grpcio-tools==1.84.0`, `pytest>=9`, `ruff`, `mypy`, `types-pyyaml`, `types-protobuf`, `types-grpcio>=1.84.0.20260928`. 그 밖은 Global Constraints.
  * `yamlio`: `yaml.compose`로 노드를 얻어 각 항목의 `start_mark.line + 1`을 줄 번호로 씁니다.
  * `rules/slop.yaml`: README slop 패턴 8개를 `slop.P1`~`slop.P8`로 옮깁니다. `judge`는 spec §5.1 초안(P2·P5·P7·P8 `rule`, P1·P3·P6 `llm`, P4는 `slop.P4a` 기획 용어 노출 `rule` lexicon `["사용자", "콘텐츠", "유저"]` + `slop.P4b` 시점 혼재 `llm`으로 나눔). `rule` 패턴의 초기 `detect`:
    | ID | kind | 값 |
    | --- | --- | --- |
    | P2 | regex | `^\S+(은|는) .+(한|인) \S+(입니다|이에요|예요)[.]?$` (ko) |
    | P5 | lexicon | `["주인공은", "언제나 당신", "당신만을 위한"]` (ko) |
    | P7 | regex | `\S+도 \S+도 아닌` (ko) |
    | P8 | regex | `[!！]|\p{Extended_Pictographic}` (모든 언어), `exempt_purposes: []`, `severity: error` |
    `llm` 패턴은 README 설명을 `rubric`으로, README 예문을 `examples.hit`으로 옮깁니다. P1은 `exempt_purposes: [care]`.
  * `rules/style.yaml`: `style.S1` 괄호 풀이 금지(regex `[가-힣]+\([가-힣\s]+\)`, ko, error), `style.S2` 말줄임 금지(regex `…|\.\.\.`, warn). 나머지는 Task 11~12에서 채웁니다.
  * `rules/limits.yaml`: `limit.L1` 호칭 한 화면 1회(scope `screen`, count `placeholder: name`, max `{ko: 1, ja: 1, en: 1}`, error), `limit.L2` 돌봄 유형 하루 상한(scope `day`, count `type: care`, max `null`, warn), `limit.L3` 돌봄 유형 한 주 상한(scope `week`, 같은 count, max `null`, warn), `limit.L4` 영어 호칭 한 주 상한(scope `week`, count `placeholder: name`, max `{en: null}`, warn — spec §7 "영어는 더 드물게"). `null`은 "아직 정하지 않음"이며 검사에서 건너뜁니다.
  * `rules/josa.yaml`: Task 3에서 채우는 빈 구조(`pairs: []`, `name_rules: {}`, `examples: []`)로 시작합니다.
  * `slots/_schema.yaml`: spec §4.1의 필드 17개를 `name`, `required`, `type`, `description`으로 적습니다. 로더는 이 파일을 슬롯 검증 기준으로 씁니다.
  * `loader.load_rules`: 필수 필드·허용 값을 검사하고, 문제를 모두 모은 뒤 `LoadError`로 한 번에 던집니다.
- [ ] **Step 4: 통과 확인** — 같은 명령 → PASS. `uv run ruff check . && uv run mypy src` → 오류 없음.
- [ ] **Step 5: Commit** — `uv.lock` 포함. `feat(writing): 검사기 골격과 규칙 YAML 로더`

### Task 3: 조사·호칭 (`josa.py`, `rules/josa.yaml`)

**Files:**
- Create: `tools/src/mlw/josa.py`
- Modify: `rules/josa.yaml`
- Test: `tools/tests/test_josa.py`

**Interfaces:**
- Produces:
  - `class Batchim(Enum): NONE, RIEUL, OTHER`
  - `final_batchim(text: str) -> Batchim | None` (None = 판정 불가)
  - `render_josa(text: str) -> str`: 문자열 안의 `X(이)가` 같은 6쌍 표기를 앞 글자 기준으로 바꿉니다. 판정 불가면 `이(가)`처럼 병기형으로 바꿉니다.
  - `NameResult(value: str | None, findings_codes: tuple[str, ...])`, `normalize_name(lang: str, raw: str) -> NameResult`. 코드: `name.empty`, `name.too_long`, `name.emoji`, `name.control`, `name.suffix_stripped`, `name.suffix_warning`.

- [ ] **Step 1: `rules/josa.yaml` 채우기** — `pairs`: spec §7 표 6쌍(`(이)가`, `(은)는`, `(을)를`, `(과)와`, `(으)로`(RIEUL이면 "로"), `(이)에요`). `readings`: 숫자 0~9(영·일·이·삼·사·오·육·칠·팔·구), 끝자리 0의 자릿수(십·백·천·만), 라틴 문자 26개의 한국어 이름(L·R → RIEUL, M·N → OTHER, 그 밖 NONE), 천간 10자·지지 12자의 한자 → 한글 독음. `name_rules`: `max_length: {ko: 10, ja: 10, en: 20}`, `strip_suffix: {ko: ["님"]}`, `warn_suffix: {ja: ["さん", "様", "ちゃん"]}`. `examples`: 아래 테스트의 입력·기대값을 그대로 둡니다(server 테스트 자료 겸용).
- [ ] **Step 2: 실패하는 테스트 작성** — `josa.yaml`의 `examples`를 매개변수화해 읽는 `test_render_examples`, 그리고 명시 케이스:
  기대값은 문자열 그대로 적습니다:
  | 입력 | 기대 |
  | --- | --- |
  | `남색(이)가` | `남색이` |
  | `파랑(이)가` | `파랑이` |
  | `하늘(으)로` | `하늘로` |
  | `동쪽(으)로` | `동쪽으로` |
  | `서(으)로` | `서로` |
  | `1(이)에요` | `1이에요` |
  | `2(이)에요` | `2예요` |
  | `10(은)는` | `10은` |
  | `L(으)로` | `L로` |
  | `A(과)와` | `A와` |
  | `甲(을)를` | `甲을` |
  | `丑(이)가` | `丑이` |
  | `★(이)가` | `★이(가)` |
  | `보라(이)가` | `보라가` |
  * `test_normalize_name`: `("ko", " 민지님 ")` → value `"민지"`, codes `("name.suffix_stripped",)`; `("ko", "님")` → value None, `name.empty`; `("ko", "님님")` → None, `name.empty`; `("ko", "가"*11)` → None, `name.too_long`; `("ja", "ゆきさん")` → value `"ゆきさん"`, `name.suffix_warning`; `("en", "Sam🙂")` → None, `name.emoji`; `("en", "Sam\u0007")` → None, `name.control`.
- [ ] **Step 3: 실패 확인** — `uv run pytest tests/test_josa.py -q` → FAIL.
- [ ] **Step 4: 구현** — 판정표는 코드에 두지 않고 `josa.yaml`에서 읽습니다. 한글 음절은 `(ord(ch) - 0xAC00) % 28`로 받침을 구합니다(0 → NONE, 8 → RIEUL). 숫자는 끝에서부터 연속한 0의 개수로 자릿수 읽기를 고르고, 0이 아니면 끝자리 읽기를 씁니다. "님"은 끝에서 반복해서 뗍니다.
- [ ] **Step 5: 통과 확인** → PASS.
- [ ] **Step 6: Commit** — `feat(writing): 조사 렌더와 호칭 정규화 규칙`

### Task 4: 자리표시자와 문장 단위 검사

**Files:**
- Create: `tools/src/mlw/placeholders.py`, `tools/src/mlw/sentence.py`, `content/ko/example.yaml`(Task 6에서 슬롯이 생긴 뒤 내용 확정, 여기서는 테스트용 `tests/data/content/`만)
- Test: `tools/tests/test_placeholders.py`, `tools/tests/test_sentence.py`, `tools/tests/test_rule_examples.py`

**Interfaces:**
- Consumes: Task 2 `RuleSet`, `SlopRule`, `StyleRule`, `Finding`; Task 3 `render_josa`.
- Produces:
  - `Placeholder(name: str, category: str | None, josa: str | None)`; `parse(text: str) -> list[Placeholder]`. 문법: `{param}` 또는 `{param:category}`, 바로 뒤에 6쌍 조사 표기가 올 수 있음. 닫히지 않은 `{`는 `ValueError`.
  - `Entry(file: Path, line: int, slot: str, key: str, type: str | None, variant: int, lang: str, text: str)`.
  - `check_sentence(entry: Entry, purpose: str, rules: RuleSet, max_length: int | None, longest_values: Mapping[str, str]) -> list[Finding]`.
  - `matches(detect: Detect, lang: str, text: str) -> bool`.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `test_parse`: `"{name}님, {element:color}(이)가 좋아요"` → `[Placeholder("name", None, None), Placeholder("element", "color", "(이)가")]`; `"{name"` → `ValueError`.
  * `test_rule_examples`: `rules/slop.yaml`·`style.yaml`의 `judge: rule` 규칙마다 `examples.hit`은 `matches == True`, `examples.pass`는 `False`. 데이터가 바뀌면 자동으로 늘어나는 매개변수화 테스트입니다.
  * `test_exempt_purpose_skips_rule`: `exempt_purposes: [care]`인 테스트용 규칙이 `purpose="care"`에서는 finding 0개, `"info"`에서는 1개.
  * `test_length_uses_longest_value`: `"{element:color}(이)가 좋아요"`, `longest_values={"element:color": "청록색"}`. 렌더 결과 `청록색이 좋아요`는 8자이므로 `max_length=8`이면 finding 0개, `max_length=7`이면 `style.length` error 1개. 호칭은 `longest_values["name"]`에 언어별 최대 길이만큼의 문자열을 넣어 계산합니다.
  * `test_bad_placeholder_syntax_reported`: `"{name님"` → `placeholder.syntax` error, 예외 없음.
- [ ] **Step 2: 실패 확인** — `uv run pytest tests/test_placeholders.py tests/test_sentence.py tests/test_rule_examples.py -q` → FAIL.
- [ ] **Step 3: 구현** — 정규식은 `regex` 모듈로 컴파일합니다. `lexicon`은 부분 문자열 포함, `template`은 `regex`와 같되 의미상 틀(문장 전체) 매칭입니다. `detect.langs`가 비어 있으면 모든 언어에 적용합니다. 길이는 자리표시자를 `longest_values`로 바꾸고 `render_josa`를 적용한 뒤 `len()`으로 셉니다. finding의 `rule_id`는 규칙 ID, 길이는 `style.length`, 문법 오류는 `placeholder.syntax`.
- [ ] **Step 4: 통과 확인** → PASS.
- [ ] **Step 5: Commit** — `feat(writing): 자리표시자 파싱과 문장 단위 검사`

### Task 5: 콘텐츠 슬롯 명세와 완결성 검사

**Files:**
- Create: `slots/content/{daily,chart,calendar,settings,glossary}.yaml`, `tools/gen_proto.sh`, `tools/src/mlw/_gen/…`(생성), `tools/src/mlw/completeness.py`
- Modify: `tools/src/mlw/loader.py` (`load_slots`, `load_content` 추가)
- Test: `tools/tests/test_slots.py`, `tools/tests/test_completeness.py`

**Interfaces:**
- Consumes: Task 2 로더, Task 4 `Entry`, `parse`.
- Produces:
  - `Slot(id, where, purpose, types: tuple[str, ...], variants: int, keys: dict[str, tuple[str, ...]], co_display: tuple[str, ...], max_length: dict[str, int | None], allowed: frozenset[str], forbidden: frozenset[str], examples, line, file)`. `keys`는 키 → 허용 매개변수 이름.
  - `load_slots(slots_dir: Path, rules: RuleSet) -> dict[str, Slot]` (규칙 ID 참조 검사 포함, 오류는 `slot.unknown_rule`).
  - `load_content(content_dir: Path) -> list[Entry]`.
  - `check_completeness(slots: Mapping[str, Slot], entries: Sequence[Entry], message_keys: Sequence[str], langs: Sequence[str]) -> list[Finding]`.
  - `glossary_values() -> dict[str, tuple[str, ...]]`: 범주 → enum 값 이름 목록(`mlw._gen`에서 `UNSPECIFIED`를 뺀 값, 접두어 제거).

- [ ] **Step 1: `gen_proto.sh` 작성과 생성** — `core/tools/gen_proto.sh`와 같은 방식으로 `proto/myungli/engine/v1/engine.proto`에서 `src/mlw/_gen/`에 Python 코드와 grpc 스텁을 만듭니다. 생성 결과를 커밋합니다.
- [ ] **Step 2: 슬롯 YAML 작성** — 슬롯 ID와 키(spec §4.2·§4.3). `max_length`는 Task 15(design 요청) 전까지 `null`.
  | 파일 | 슬롯 ID | purpose | types | variants | 키 → 매개변수 |
  | --- | --- | --- | --- | --- | --- |
  | daily | `daily.fortune.head` | care | advice, state, care | 1 | `fortune.<gwiin_day\|yongsin_day\|gisin_day\|ordinary_day>.<bigyeop\|siksang\|jaeseong\|gwanseong\|inseong>` 20개 → `day_kind, ten_god, element, emphasis, name` |
  | daily | `daily.fortune.tag` | care | advice, state, care | 1 | `fortune.tag.*` 15개 → 위와 같음 |
  | daily | `daily.guide` | guide | - | 2 | `guide.*` 20개 → `ten_god, element` |
  | daily | `daily.color` | info | - | 1 | `color.*` 4 → `element, role` |
  | daily | `daily.direction` | info | - | 1 | `direction.day_kind.*` 4 → `direction, rule_id` |
  | daily | `daily.number` | info | - | 1 | `number.*` 4 → `number, element` |
  | daily | `daily.focus_time` | info | - | 1 | `focus_time.*` 5 → `branches, score` |
  | daily | `daily.tag_label` | info | - | 1 | `tag.*` 15 → 없음 |
  | daily | `daily.focus_reason` | info | - | 1 | `gwiin, yongsin, huisin, hap` → 없음 |
  | chart | `chart.yongsin_method` | info | - | 1 | `yongsin.method.*` 3 → 없음 |
  | calendar | `calendar.day_level` | info | - | 1 | `calendar.*` 3 → 없음 |
  | calendar | `calendar.score_item` | info | - | 1 | spec §4.3 7개 → 없음 |
  | calendar | `calendar.solar_term` | info | - | 1 | `SolarTermKind` 24개(소문자 이름) → 없음 |
  | settings | `settings.calculation_basis` | info | - | 1 | `notice.calculation_basis` → 없음 |
  | glossary | `glossary.value_name` | info | - | 1 | 범주 `element, element_color, stem, branch, ten_god, ten_god_group, direction8, shinsal, day_kind`의 값 → 없음 |
  * `daily.*` 슬롯의 `co_display`는 같은 파일의 다른 `daily.*` 슬롯 전부입니다.
  * 키별 매개변수는 `core/src/myungli_engine/composers/daily.py`, `rules/messages.py`에서 옮긴 값임을 파일 머리 주석에 적습니다.
  * `ten_god_group` 값: `bigyeop, siksang, jaeseong, gwanseong, inseong`(proto enum이 아니므로 YAML에 직접 둠).
- [ ] **Step 3: 실패하는 테스트 작성**
  * `test_content_slots_cover_message_keys`: `daily/chart/calendar` 슬롯의 메시지 키 합집합 == `message_keys.json` 93개 집합.
  * `test_glossary_covers_enums`: `glossary_values()`의 범주별 값이 `glossary.value_name` 키와 일치.
  * `test_missing_type_reported`: `daily.fortune.head`의 한 키에 `advice`·`state`만 있는 ko 원고 → `complete.missing` error 1개(메시지에 키·유형·언어).
  * `test_placeholder_not_in_params`: `fortune.*` 원고에 `{direction}` → `complete.unknown_param` error.
  * `test_unknown_key_in_content`: 슬롯에 없는 키 → `complete.unknown_key` error.
  * `test_unknown_rule_reference`: `allowed: [slop.P99]` → `LoadError`, `slot.unknown_rule`, 줄 번호 있음.
- [ ] **Step 4: 실패 확인 → 구현 → 통과 확인** — `uv run pytest tests/test_slots.py tests/test_completeness.py -q`. `name`은 모든 슬롯에서 허용 매개변수로 취급합니다. `{param:category}`의 `category`는 `glossary_values()`의 범주여야 합니다(`complete.unknown_category`).
- [ ] **Step 5: Commit** — `feat(writing): 콘텐츠 슬롯 명세와 완결성 검사`

### Task 6: 화면·하루 묶음 검사

**Files:**
- Create: `tools/src/mlw/bundles.py`
- Test: `tools/tests/test_bundles_day.py`

**Interfaces:**
- Consumes: Task 2 `Limit`, Task 5 `Slot`, `Entry`.
- Produces:
  - `DayKeys(head: str, tag_sentence: str | None, guide: str, color: str, direction: str, number: str, focus: str, tag_label: str | None)`.
  - `enumerate_days() -> Iterator[DayKeys]`.
  - `Bundle(keys: tuple[tuple[str, str], ...])` — (슬롯 ID, 키) 나열; `assemble(day: DayKeys, entries_by: Mapping[tuple[str, str, str], Sequence[Entry]], lang: str, rotation: int, guide_variant: int) -> list[Entry]`.
  - `check_limits(entries: Sequence[Entry], limits: Iterable[Limit], scope: str, lang: str, where: str) -> list[Finding]`.
  - `check_days(slots, entries, limits, langs) -> list[Finding]`.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `test_enumerate_days_respects_engine_rules`: 모든 `DayKeys`에서 `tag_sentence == "fortune.tag.gwiin_day"`면 `head`가 `fortune.gwiin_day.`로 시작하고, `fortune.tag.yongsin_day`면 `fortune.yongsin_day.`로 시작합니다. 대표 태그가 있으면 `guide == "guide." + 태그 접미사`, 없으면 `guide == "guide.ten_god." + 십성 그룹`. `color`·`number`는 `head`의 날의 성격과 같고 `direction`은 `direction.day_kind.<성격에서 _day 뺀 값>`.
  * `test_name_twice_on_screen_is_error`: 헤드라인과 가이드 원고가 둘 다 `{name}`을 쓰면 `limit.L1` error 1개(파일·줄은 둘째로 나온 원고).
  * `test_null_limit_is_skipped`: `limit.L2`가 `null`이면 돌봄 유형 3개여도 finding 0개.
  * `test_rotation_positions_all_checked`: 총운 헤드라인·보조가 각각 3유형일 때 `rotation` 0·1·2(헤드라인과 보조가 같은 순환 위치) 모두 검사됨을 돌봄 상한 1로 확인.
- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인** — `uv run pytest tests/test_bundles_day.py -q`.
  * 열거 규칙: 날의 성격 4 × 십성 그룹 5 × 대표 태그(없음 + `tag.*` 15개, 단 `gwiin_day`·`yongsin_day` 태그는 해당 성격에서만) × 집중 시간 키 5. 대표 태그 둘째는 열거하지 않습니다(`tag_label`은 첫째만).
  * 순환: 유형 적용 슬롯은 `rotation` 0~2에서 `types[(rotation) % 3]`, 가이드는 변주 1~2. 화면 범위와 하루 범위는 같은 묶음으로 검사합니다(MVP 데일리 화면 하나 = 하루).
- [ ] **Step 3: Commit** — `feat(writing): 화면·하루 빈도·밀도 검사`

### Task 7: 한 주 고정 자료 생성 (`gen-week-fixture`)

**Files:**
- Create: `tools/src/mlw/week_fixture.py`, `tools/fixtures/week_samples.json`
- Test: `tools/tests/test_week_fixture.py`

**Interfaces:**
- Consumes: Task 5 `mlw._gen`, Task 6 `DayKeys`.
- Produces:
  - `SAMPLE_BIRTHS: tuple[BirthSample, ...]` 10개, `START_DATE = date(2026, 11, 2)`, `DAYS = 28`.
  - `day_keys_from_response(resp: engine_pb2.DailyResponse) -> DayKeys`.
  - `generate(address: str) -> dict[str, object]` — 형식 `{"engine_version", "ruleset_version", "start": "2026-11-02", "samples": [{"birth_id": str, "days": [DayKeys를 dict로, 28개]}]}`.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_day_keys_from_response`: 손으로 만든 `DailyResponse`(fortune 2개, featured_tags `["tag.dohwa"]`, guide `guide.dohwa`, 각 카드 judgment)에서 `DayKeys` 필드가 그대로 옮겨짐. `fortune`이 1개면 `tag_sentence is None`.
- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인** — `uv run pytest tests/test_week_fixture.py -q`.
  * 표본 10개: 양력, `Asia/Seoul`, 1970~2005년 사이 서로 다른 날짜·시각, 성별 반반, 하나는 시간 모름. 값은 코드 상수로 고정합니다.
  * `current_timezone = "Asia/Seoul"`, 연결은 `grpc.insecure_channel(address)`.
- [ ] **Step 3: 실제 엔진으로 고정 자료 생성**
  ```bash
  (cd core && uv sync --frozen && uv run python -m myungli_engine --port 50051) &
  uv run --project docs/identity/writing/tools mlw gen-week-fixture --engine localhost:50051 \
    > docs/identity/writing/tools/fixtures/week_samples.json
  ```
  Expected: 표본 10개 × 28일, `ruleset_version`이 `2026.10.1`. 엔진 프로세스를 종료합니다. (`cli.py`의 이 명령은 Task 9에서 묶으므로, 여기서는 `week_fixture.py`에 `if __name__ == "__main__"` 진입점을 두고 `python -m mlw.week_fixture --engine …`로 실행합니다. 실행한 명령을 커밋 메시지에 적습니다.)
- [ ] **Step 4: Commit** — `feat(writing): 엔진 gRPC로 한 주 표본 고정 자료 생성`

### Task 8: 한 주 묶음 검사

**Files:**
- Modify: `tools/src/mlw/bundles.py`
- Test: `tools/tests/test_bundles_week.py`

**Interfaces:**
- Consumes: Task 6 `assemble`, `check_limits`; Task 7 고정 자료 형식.
- Produces: `check_weeks(slots, entries, limits, langs, fixture: Mapping[str, object], message_keys: Sequence[str]) -> list[Finding]`.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `test_week_care_limit`: 작은 고정 자료(표본 1개, 7일, 매일 같은 헤드라인 키)와 `limit.L3` max 2, 헤드라인 3유형 → 순환상 7일 중 돌봄 2~3회가 나오는 시작 위치가 있으므로 `limit.L3` warn 1개 이상.
  * `test_fixture_unknown_key_is_error`: 고정 자료에 `fortune.unknown` → `week.fixture_stale` error.
  * `test_windows_slide`: 28일 자료는 표본마다 연속 7일 창 22개를 검사(창 개수를 세는 보조 함수 `week_windows(days, 7)` 결과 22).
- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인** — `uv run pytest tests/test_bundles_week.py -q`. 순환은 사용자별로 키마다 따로 돌기 때문에, 표본의 28일을 앞에서부터 지나며 키별 출현 횟수로 유형을 정하고, 시작 위치 0·1·2 세 경우를 모두 검사합니다.
- [ ] **Step 3: Commit** — `feat(writing): 한 주 빈도 검사`

### Task 9: ARB 검사와 CLI

**Files:**
- Create: `tools/src/mlw/arb.py`, `tools/src/mlw/cli.py`, `slots/ui/depth.yaml`(빈 슬롯: `ui.depth.default_label`, `ui.depth.surface`, `ui.depth.explain`, `ui.depth.evidence`, purpose info, 원고 없음)
- Test: `tools/tests/test_arb.py`, `tools/tests/test_cli.py`

**Interfaces:**
- Consumes: Task 2~8 전부.
- Produces:
  - `check_arb(arb_paths: Sequence[Path], slots: Mapping[str, Slot], rules: RuleSet) -> list[Finding]`. ARB 키 → 슬롯 매핑은 `slots/ui/*.yaml`의 `keys`(ARB 메시지 이름)로 합니다. 슬롯에 없는 ARB 키는 문장 단위 규칙만 적용하고 `purpose: info`로 봅니다. 언어는 ARB의 `@@locale`.
  - `main(argv: Sequence[str] | None = None) -> int` — 하위 명령 `check <경로>`, `check-arb <경로…>`, `gen-docs [--check]`, `gen-week-fixture --engine <주소>`.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `test_arb_exclamation`: `{"@@locale": "ko", "hello": "반가워요!"}` → `slop.P8` error, 줄 번호는 해당 키의 줄.
  * `test_arb_metadata_keys_ignored`: `@hello` 같은 `@` 키는 검사하지 않음.
  * `test_cli_check_exit_codes`: error 있는 예시 디렉터리 → 반환 1, 출력 첫 줄이 Global Constraints 형식과 맞음(정규식 `^\S+:\d+ \S+ (error|warn) .+$`); 깨끗한 디렉터리 → 0.
  * `test_cli_load_error_exit_code`: 깨진 규칙 디렉터리 → 반환 2, 예외 추적 없이 finding 형식 출력.
- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인** — `uv run pytest tests/test_arb.py tests/test_cli.py -q`. `check`는 완결성 → 문장 → 하루 → 한 주 순서로 모두 돌린 뒤 결과를 파일·줄 순으로 정렬해 출력합니다. 종료 코드: error 1, 로드 실패 2, 그 밖 0.
- [ ] **Step 3: 예시 원고 작성** — `content/ko/example.yaml`에 `daily.color`의 4개 키 ko 원고를 넣습니다. 문장은 "{element:color}(이)가 오늘 잘 맞아요." 같은 담백한 형태로, 라운드 전 임시 원고임을 파일 머리 주석에 적습니다. `check content/`의 완결성 검사는 `content/`에 있는 키만 대상으로 하도록 `--partial` 옵션을 두고, CI에서는 `--partial`로 돌립니다.
- [ ] **Step 4: Commit** — `feat(writing): ARB 검사와 mlw 명령`

### Task 10: 생성 문서와 CI

**Files:**
- Create: `tools/src/mlw/docs.py`, `generated/{slop-patterns,slot-catalog,josa-table}.md`, `.github/workflows/writing.yml`
- Test: `tools/tests/test_docs.py`

**Interfaces:**
- Produces: `render_docs(rules: RuleSet, slots: Mapping[str, Slot]) -> dict[str, str]` (파일 이름 → 내용), `write_docs(out_dir: Path, docs: Mapping[str, str]) -> None`, `stale_docs(out_dir, docs) -> list[str]`.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_render_is_deterministic`(두 번 렌더한 결과가 같음), `test_slop_doc_lists_every_rule`(모든 `slop.*` ID가 표에 한 줄씩), `test_generated_files_are_current`(저장소의 `generated/`가 `render_docs` 결과와 같음 — CI의 `gen-docs --check`와 같은 보장), `test_header_warns_generated`(각 파일 첫 줄 `<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->`).
- [ ] **Step 2: 실패 확인 → 구현 → `mlw gen-docs` 실행 → 통과 확인** — `uv run pytest tests/test_docs.py -q`. 표 열: slop(ID, 이름, 판정, 심각도, 예외 목적, 탐지식 또는 루브릭), 슬롯(ID, 목적, 유형, 변주, 키 수, 글자 수 상한), 조사(표기, 받침 있음, 없음, ㄹ, 예시).
- [ ] **Step 3: `writing.yml` 작성** — `core.yml`의 `check` job 형식을 따릅니다. 트리거 경로 `docs/identity/writing/**`, `.github/workflows/writing.yml`, `core/message_keys.json`, `proto/**`. `working-directory: docs/identity/writing/tools`, `setup-uv@v7` 0.11.3·Python 3.13, `uv sync --frozen`, `uv run ruff check .`, `uv run mypy src`, `uv run pytest -q`, `uv run mlw gen-docs --check`, `uv run mlw check ../content --partial`, 그리고 `bash gen_proto.sh && git diff --exit-code src/mlw/_gen`.
- [ ] **Step 4: 로컬에서 CI 명령 전부 실행** → 모두 종료 코드 0.
- [ ] **Step 5: Commit** — `ci(writing): 생성 문서와 writing 워크플로`

### Task 11: 라운드 R1~R3 (메인 세션, 사용자와 터미널)

**Files:**
- Create: `artifacts/index.json`, `artifacts/2026-10-10-round-R1.md`~`R3.md`, `guide/voice-tone.md`, `guide/review-procedure.md`
- Modify: `rules/style.yaml`, `decisions.md`

- [ ] **Step 1: `guide/review-procedure.md` 작성** — spec §8.2를 절차로 옮깁니다(4~5지선다 + "다 별로", 숨긴 대조군 1개, 이전 문항 1개 재출제, 출처 공개 시점, 규칙으로 굳히는 기준 "같은 성격의 선택 2회", 기록 형식).
- [ ] **Step 2: R1 문장 맺음** — 슬롯 목적 3종(info·guide·care)마다 같은 내용을 해요체·합니다체·섞음으로 쓴 선택지를 냅니다. 커뮤니티·리뷰 표현은 WebSearch로 표현 단위 확인 후 출처를 기록합니다.
- [ ] **Step 3: R2 구두점·리듬, R3 어휘·용어 토큰 범위** — 같은 방식.
- [ ] **Step 4: 결과 반영** — 라운드마다 `artifacts/2026-10-10-round-R<n>.md`(문항, 선택지, 대조군 표시, 선택, 출처, 굳힌 규칙)와 `index.json` 항목(`kind: copy-sample`, `milestone: W0`, `screens: []`, `status: chosen`). 굳힌 규칙은 `style.yaml`에 `examples`와 함께 추가하고 `decisions.md`에 W#로 기록합니다. `guide/voice-tone.md`의 보이스 절(성격 5항목 → 규칙 ID)을 씁니다.
- [ ] **Step 5: 검증** — `uv run --project docs/identity/writing/tools pytest -q` (새 규칙의 `examples` 테스트 통과), `mlw gen-docs`로 `generated/` 갱신.
- [ ] **Step 6: Commit** — `docs(writing): 라운드 R1~R3 결과와 보이스 규칙`

### Task 12: 라운드 R4~R6 (메인 세션)

**Files:**
- Create: `artifacts/2026-10-10-round-R4.md`~`R6.md`
- Modify: `slots/content/daily.yaml`(`examples`, `structure`, `tone`, `endings`, `user_state`, `a11y`), `rules/limits.yaml`(`limit.L2`~`limit.L4` max), `rules/slop.yaml`(추가 패턴), `guide/voice-tone.md`(톤 절), `decisions.md`

- [ ] **Step 1: R4 총운 유형별 예문** — `fortune.yongsin_day.siksang`, `fortune.gisin_day.gwanseong`, `fortune.ordinary_day.inseong` 세 키로 advice·state·care 각각의 선택지를 냅니다. 고른 것과 탈락한 대조군을 `daily.fortune.head`의 `examples`(good/bad, 이유)로 넣습니다.
- [ ] **Step 2: R5 돌봄 빈도** — 하루 화면에 돌봄 문장 1·2·3개, 한 주에 2·3·5회인 묶음을 보여 주고 과한 지점을 고르게 합니다. 결과를 `limit.L2`·`limit.L3`의 `max`로 넣습니다. 같은 라운드에서 영어 호칭의 한 주 횟수(`limit.L4`)도 1·2·3회 묶음으로 고르게 합니다.
- [ ] **Step 3: R6 가이드 질문 형태** — 열린 질문, 선택 질문, 길이 3단계. 결과를 `daily.guide`의 `structure`와 `examples`로 넣습니다.
- [ ] **Step 4: 톤 좌표 작성** — 목적별 기본 좌표(진지·격식·존중·담백 1~5)를 `voice-tone.md` 톤 절에, 슬롯별 조정을 각 슬롯 `tone`에 씁니다. 모든 `daily.*` 슬롯의 `user_state`, `endings`, `a11y`를 채웁니다.
- [ ] **Step 5: 검증 → Commit** — `pytest -q`, `mlw gen-docs`, `mlw check ../content --partial` 통과. `docs(writing): 라운드 R4~R6 결과와 슬롯 예시·상한`

### Task 13: 라운드 R7과 나머지 슬롯 채우기 (메인 세션)

**Files:**
- Modify: `slots/ui/depth.yaml`, `slots/content/{chart,calendar,settings,glossary}.yaml`, `decisions.md`
- Create: `artifacts/2026-10-10-round-R7.md`

- [ ] **Step 1: R7 깊이 이름** — "기본 깊이"와 `surface`·`explain`·`evidence`의 사용자용 이름(ko). 선택 결과를 `ui/depth.yaml`의 `examples`에 둡니다(ARB 문구는 app 소유이므로 이름만 정함).
- [ ] **Step 2: 남은 슬롯 필드 채우기** — Task 12에서 다루지 않은 슬롯의 `user_state`, `structure`, `endings`, `tone`, `a11y`, `examples`(good 1·bad 1 이상)를 R1~R3 규칙에 맞춰 씁니다. `settings.calculation_basis`는 D42 문구를 그대로 ko 예시로 둡니다.
- [ ] **Step 3: 검증 → Commit** — `pytest -q`, `mlw gen-docs`. `docs(writing): 라운드 R7과 슬롯 명세 완성`

### Task 14: 호칭·조사 가이드

**Files:**
- Create: `guide/honorific-josa.md`

- [ ] **Step 1: 작성** — spec §7을 server 구현자가 읽는 계약 문서로 씁니다. 판정표는 `generated/josa-table.md`를, 테스트 자료는 `rules/josa.yaml`의 `examples`를 가리킵니다. 자리표시자 문법(`{param}`, `{param:category}`, 조사 표기)과 `glossary.value_name`으로 enum 값을 바꾸는 렌더 순서(값 이름 → 호칭 접미사 → 조사)를 적습니다. 버전 `v1`을 머리에 둡니다.
- [ ] **Step 2: Commit** — `docs(writing): 호칭·조사 처리 규칙 v1`

### Task 15: 요청함 문서와 마무리

**Files:**
- Create: `docs/coordination/2026-10-10-writing-to-root-contracts.md`, `2026-10-10-writing-to-design-length.md`, `2026-10-10-writing-to-server-josa.md`, `2026-10-10-writing-to-root-w0-done.md`
- Modify: `docs/identity/writing/CLAUDE.md`("현재 상태", "다음 할 일"), `docs/coordination/2026-10-10-root-to-writing-engine-keys-scale.md`(처리 기록 `done`)

- [ ] **Step 1: `writing-to-root-contracts`** — 제공 계약 3개의 원본 위치·버전(슬롯 명세 `slots/` v1, 검사기 `mlw` v0.1.0, 호칭·조사 v1) 등록 요청. 추가로 **키별 매개변수 목록이 계약에 없다**는 점(Review Focus 1)을 적고, core가 `message_keys.json`에 매개변수를 함께 내보내도록 하는 요청을 지휘 세션이 판단해 달라고 씁니다.
- [ ] **Step 2: `writing-to-design-length`** — 슬롯별 글자 수 상한 초안(R2 결과의 문장 길이 기준)을 표로 보내고 레이아웃 기준 조정을 요청합니다.
- [ ] **Step 3: `writing-to-server-josa`** — `guide/honorific-josa.md`, `rules/josa.yaml` 예시를 테스트 자료로 쓰는 방법, 원고 → 시드 변환 시 `mlw check` 실행 위치를 안내합니다.
- [ ] **Step 4: 완료 보고와 상태 갱신** — `writing-to-root-w0-done`(`kind: report`, `status: done`)에 spec §11 완료 기준 1~5의 충족 근거를 적습니다. `root-to-writing-engine-keys-scale`의 처리 기록에 `- 2026-10-10 (writing): done — <커밋>`을 덧붙이고 `status: done`. `CLAUDE.md` "현재 상태"를 W0 완료로, "다음 할 일"을 IA 대기·LLM 판정 명령·W1로 고칩니다.
- [ ] **Step 5: 최종 검증** — Task 10 Step 4의 CI 명령 전부 → 종료 코드 0.
- [ ] **Step 6: Commit** — `docs(writing): W0 완료 보고와 계약 등록 요청`

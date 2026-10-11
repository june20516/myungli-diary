# 원국 개인 해석·출생 시진·엔진 정보 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 다음 세 가지를 proto v1에 추가만 하는 방식으로 넣습니다.
* `GetChart` 응답에 원국 개인 해석 목록(`personal_readings`)
* 출생 시진 RPC(`GetBirthHour`)
* 엔진 정보 RPC(`GetInfo`)

**Architecture:**
* 개인 해석은 `rules/personal.py`의 순수 함수가 Judgment를 만들고, `composers/chart.py`가 원국·대운·세운을 돌며 목록으로 모읍니다.
* 출생 시진은 `calendar_core/birth.py`가 원국과 같은 출생 시각 해석으로 계산합니다.
* 두 RPC는 `grpc_api`에 붙입니다.

**Tech Stack:** Python 3.13, uv, grpcio, protobuf(buf), pytest, hypothesis, syrupy

**Spec:** `core/docs/specs/2026-10-11-personal-reading-design.md`

## Global Constraints

* proto는 추가만 합니다. 기존 필드 번호와 이름은 그대로 둡니다. 새 enum의 0번은 `<ENUM>_UNSPECIFIED`입니다.
* 메시지 키 형식은 `personal.<묶음>.<enum 이름 소문자>`입니다. 키와 매개변수는 `constants/message_keys.py`의 `KEY_PARAMS`에만 선언합니다.
* 모든 Judgment는 `require(key, params)`를 거칩니다. 근거(evidence)는 하나 이상입니다.
* 개인 해석의 `source_ref`는 `gungtong-bogam/five_elements#balance_principle`입니다(C8). 여기에 용신 판정 근거(`yongsin.evidence`)를 덧붙입니다.
* `ruleset_version`은 `2026.10.2`입니다.
* `lunar_python`은 `calendar_core` 안에서만 import합니다.
* 검사 명령은 모두 `core/`에서 실행합니다: `uv run ruff check .`, `uv run mypy src tools`, `uv run pytest -q -m "not slow"`.

## Review Focus

1. 시간 모름 원국: 시주 자리(`HOUR_STEM`·`HOUR_BRANCH`)와 그 지장간의 개인 해석이 없어야 합니다. 시진 RPC는 `INVALID_ARGUMENT`입니다.
2. 한 자리에 신살이 둘 이상인 원국: 신살마다 해석이 하나씩 있고, `shinsal` 값으로 구분돼야 합니다.
3. `as_of`가 첫 대운 시작 전이거나 세운 목록 밖: 모든 대운의 `current`가 거짓이고, 세운 목록(첫 대운 구간의 10년, `chart/luck_cycles.py`)에 `as_of` 연도가 없으면 세운 `current`도 모두 거짓이어야 합니다.
4. 서머타임 공백·중복 시각에 태어난 경우: 시진 RPC도 원국과 같은 해석(공백은 뒤로 밀기, 중복은 앞)을 쓰고, 같은 notice를 냅니다.
5. 보정 시각 자시(23:00~00:59) 출생: 시진 구간은 보정 23:00에 시작해 다음 날 01:00에 끝나는 한 구간입니다.

---

### Task 1: 십성 묶음 개수 공용화와 개인 해석 도메인 타입

**Files:**
- Create: `core/src/myungri_engine/rules/group_count.py`
- Modify: `core/src/myungri_engine/rules/tags.py` (`_natal_group_count`를 새 모듈 호출로 바꿈)
- Modify: `core/src/myungri_engine/domain/enums.py` (`PersonalTermKind` 추가)
- Create: `core/src/myungri_engine/chart/personal_target.py` (`PersonalReading`)
- Test: `core/tests/unit/rules/test_group_count.py`

**Interfaces:**
- Produces: `natal_group_count(natal: FourPillars, group: TenGodGroup) -> int`. 일간을 뺀 천간과 각 지지 정기에서 그 묶음 개수를 셉니다. 시주를 모르면 시주를 뺍니다. 지금 `tags._natal_group_count`와 결과가 같습니다.
- Produces: `PersonalTermKind` enum. 멤버는 `DAY_MASTER`, `TEN_GOD`, `HIDDEN_TEN_GOD`, `TWELVE_STAGE`, `SHINSAL`, `DAEUN_STEM_TEN_GOD`, `DAEUN_BRANCH_TEN_GOD`, `DAEUN_TWELVE_STAGE`, `SEUN_TEN_GOD`이고, 이 순서로 `auto()`를 씁니다.
- Produces: frozen dataclass `PersonalReading`. 필드는 `kind: PersonalTermKind`, `position: Position | None`, `index: int`, `shinsal: Shinsal | None`, `judgment: Judgment`입니다.
  * `Position`은 `chart/positions.py`에 있습니다. `domain`이 `chart`를 import하면 계층이 거꾸로 되므로, `PersonalReading`은 `domain/models.py`가 아니라 **`chart/personal_target.py`(새 파일)**에 둡니다.
  * `PersonalTermKind`는 `domain/enums.py`에 둡니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# tests/unit/rules/test_group_count.py
def test_counts_stems_and_branch_main_stems_without_day_stem(): ...
    # 甲 일간 원국(연 甲子, 월 丙寅, 일 甲辰, 시 庚午): 비겁 = 연간 甲 + 월지 寅 정기 甲 → 2, 식상 = 월간 丙 + 시지 午 정기 丁 → 2
def test_unknown_hour_excluded(): ...  # 같은 원국에서 hour=None이면 식상 1(시지 午 제외), 관성 0(시간 庚 제외)
def test_matches_tag_rush_rule(): ...  # tags._rush_tags가 쓰는 개수와 같은 값(공용 함수 호출 확인)
```

- [ ] **Step 2: 실패 확인** — `uv run pytest tests/unit/rules/test_group_count.py -q` → ImportError
- [ ] **Step 3: `rules/group_count.py` 구현, `tags.py`가 이를 호출하게 바꿈, `PersonalTermKind`와 `chart/personal_target.py` 추가**
- [ ] **Step 4: 통과 확인** — `uv run pytest tests/unit/rules -q` (기존 태그 테스트 포함) PASS
- [ ] **Step 5: Commit** — `refactor(core): 십성 묶음 개수를 공용 함수로, 개인 해석 대상 타입 추가 (#51)`

### Task 2: 개인 해석 규칙과 메시지 키

**Files:**
- Create: `core/src/myungri_engine/rules/personal.py`
- Modify: `core/src/myungri_engine/constants/message_keys.py` (키 60개)
- Test: `core/tests/unit/rules/test_personal.py`, `core/tests/unit/constants/test_tables.py`

**Interfaces:**
- Consumes: `natal_group_count` (Task 1), `YongsinResult`, `StrengthResult`
- Produces (모두 `Judgment` 반환):
  * `PersonalRole(Enum)`: `YONGSIN`, `HUISIN`, `GISIN`, `NEUTRAL`(`rules/personal.py`). 데일리 컬러의 `ElementRole`과 값 집합이 다르므로 따로 둡니다. 매개변수에는 `.name`을 넣습니다.
  * `element_role(element: Element, yongsin: YongsinResult) -> PersonalRole` — 용신, 희신, 기신 순서로 먼저 맞는 값이고, 어디에도 맞지 않으면 `NEUTRAL`입니다.
  * `day_master_reading(stem: Stem, strength: StrengthResult, yongsin: YongsinResult) -> Judgment` — 키 `personal.day_master.<stem>`, 매개변수 `strength`, `yongsin`, `gisin`
  * `ten_god_reading(god: TenGod, position: Position, hidden: bool, stem: Stem, natal: FourPillars, strength: StrengthResult, yongsin: YongsinResult) -> Judgment` — 키 `personal.ten_god.<god>`, 매개변수 `place`, `element`(stem의 오행), `role`, `group_count`(`natal_group_count(natal, god.group)`), `strength`. 지지 자리는 정기 천간을 `stem`으로 넘깁니다
  * `twelve_stage_reading(stage: TwelveStage, position: Position, branch: Branch, strength, yongsin) -> Judgment` — 키 `personal.twelve_stage.<stage>`, 매개변수 `place`, `element`(branch의 오행), `role`, `strength`
  * `shinsal_reading(kind: Shinsal, position: Position, branch: Branch, yongsin) -> Judgment` — 키 `personal.shinsal.<kind>`, 매개변수 `place`, `element`, `role`
  * `luck_ten_god_reading(god: TenGod, luck: str, part: str, stem: Stem, current: bool, yongsin) -> Judgment` — 키 `personal.luck.ten_god.<god>`, 매개변수 `luck`(`"DAEUN"`·`"SEUN"`), `part`(`"STEM"`·`"BRANCH"`), `element`, `role`, `current`. 지지는 정기 천간을 넘깁니다.
  * `luck_twelve_stage_reading(stage: TwelveStage, branch: Branch, current: bool, yongsin) -> Judgment` — 키 `personal.luck.twelve_stage.<stage>`, 매개변수 `element`, `role`, `current`
  * `place` 값: 원국 자리는 `position.name`, 지장간(`hidden=True`)은 `f"{position.name}_HIDDEN"`입니다. `place`는 함수 안에서 만듭니다.
  * 근거: 첫 항목은 `Evidence(rule_id="personal/<묶음>", source_ref=FIVE_ELEMENTS_REF["balance_principle"], detail=<매개변수를 문자열로>)`이고, 뒤에 `*yongsin.evidence`를 붙입니다. `<묶음>`은 `day_master`, `ten_god`, `twelve_stage`, `shinsal`, `luck_ten_god`, `luck_twelve_stage`입니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
def test_element_role_priority(): ...       # 용신·희신·기신 오행이면 각 역할, 그 밖의 두 오행은 NEUTRAL
def test_ten_god_reading_key_and_params(): ...  # ten_god_reading(TenGod.SIKSIN, Position.MONTH_STEM, False, ...)
    # key == "personal.ten_god.siksin", params == {"place": "MONTH_STEM", "element": "FIRE", "role": ..., "group_count": 2, "strength": "STRONG"}
def test_hidden_place_suffix(): ...         # hidden=True → place == "MONTH_BRANCH_HIDDEN"
def test_luck_reading_current_flag(): ...   # params["current"] is True / False, params["luck"] == "DAEUN"
def test_every_reading_has_balance_and_yongsin_evidence(): ...  # evidence[0].rule_id == "personal/ten_god", evidence[1:] == yongsin.evidence
# test_tables.py
def test_personal_keys_registered(): ...
    # personal.* 키 60개, KEY_PARAMS["personal.ten_god.siksin"] == ("place", "element", "role", "group_count", "strength")
```

- [ ] **Step 2: 실패 확인** — `uv run pytest tests/unit/rules/test_personal.py tests/unit/constants -q` → FAIL
- [ ] **Step 3: `KEY_PARAMS`에 6개 묶음 선언, `rules/personal.py` 구현**
- [ ] **Step 4: 통과 확인** — 위 명령 PASS (`message_keys.json` 일치 테스트는 Task 7에서 파일 재생성 전까지 실패하므로, 여기서 파일 두 개를 바로 재생성합니다: README "메시지 키와 매개변수 목록" 명령)
- [ ] **Step 5: Commit** — `feat(core): 원국 개인 해석 규칙과 메시지 키 60개 (#51)`

### Task 3: 원국 composer에 개인 해석 목록

**Files:**
- Modify: `core/src/myungri_engine/composers/chart.py` (`ChartView.personal_readings: tuple[PersonalReading, ...]`)
- Modify: `core/src/myungri_engine/version.py` (`RULESET_VERSION = "2026.10.2"`)
- Update: `core/tests/snapshots/__snapshots__/`, `core/tests/snapshots/RULESET_HASH`
- Test: `core/tests/unit/composers/test_chart.py`

**Interfaces:**
- Consumes: Task 1의 `PersonalReading`·`PersonalTermKind`, Task 2의 함수들
- Produces: `ChartView.personal_readings`. 목록 순서는 아래로 고정합니다.
  1. 일간 1개
  2. 원국 십성(`chart.ten_gods`, `Position` 정의 순서)
  3. 지장간(지지 자리 순서, 자리 안은 지장간 순서. `index`는 지장간 순서)
  4. 12운성(지지 자리 순서)
  5. 신살(`chart.shinsal` 순서)
  6. 대운: 구간 i마다 천간 십성, 지지 십성, 12운성 순서이고 `index=i`
  7. 세운: `luck.years` 순서이고 `index`는 목록 위치

  `current`는 다음 기준으로 정합니다.
  * 대운: `start_year <= as_of.year < 다음 구간 start_year`인 구간만 참입니다. 마지막 구간은 끝이 없습니다. 첫 구간 전이면 모두 거짓입니다.
  * 세운: `year == as_of.year`인 항목만 참입니다. 목록에 그 연도가 없으면 모두 거짓입니다.

  신살·12운성에 넘길 지지는 `chart.pillars`에서 자리의 기둥을 골라 구합니다. 도우미는 `_pillar_at(pillars: FourPillars, position: Position) -> Pillar`이고 composer 안에 둡니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`spring_birth`·`unknown_time_birth` 등 기존 fixture 사용)

```python
def test_personal_readings_cover_every_natal_term(spring_birth): ...
    # DAY_MASTER 1, TEN_GOD == len(chart.ten_gods), HIDDEN == 지장간 총수, TWELVE_STAGE == 4, SHINSAL == len(chart.shinsal)
def test_personal_readings_cover_luck_tables(spring_birth): ...
    # DAEUN_* 각 10개, SEUN_TEN_GOD == len(luck.years), index는 0부터 연속
def test_unknown_time_has_no_hour_readings(unknown_time_birth): ...
    # position이 HOUR_STEM·HOUR_BRANCH인 항목 없음
def test_current_flags_follow_as_of(spring_birth): ...
    # as_of 2026-10-10: 대운 current 참이 정확히 하나, 세운은 2026년 항목 하나
def test_no_current_before_first_period(spring_birth): ...
    # as_of가 첫 대운 start_year 이전(예: 출생 이듬해): 대운·세운 current 모두 거짓 (Review Focus 3)
def test_multiple_shinsal_at_one_position_are_distinct(spring_birth): ...
    # spring_birth는 YEAR_BRANCH에 CHEONEUL_GWIIN·HWAGAE가 함께 있음: 두 해석 모두 있고 (position, shinsal) 쌍이 중복 없음 (Review Focus 2)
```

- [ ] **Step 2: 실패 확인** — `uv run pytest tests/unit/composers/test_chart.py -q` → FAIL
- [ ] **Step 3: `compose_chart`가 목록을 만들도록 구현** (도우미 `_personal_readings(natal: NatalContext, luck: LuckCycles, as_of: date) -> tuple[PersonalReading, ...]`)
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS
- [ ] **Step 5: 버전과 스냅샷 갱신** — `RULESET_VERSION`을 `2026.10.2`로 올리고 README "ruleset 버전과 스냅샷 갱신" 절차 2~3을 실행합니다. 원국 스냅샷(`test_chart_regression`)에만 `personal_readings`가 더해지고 데일리·월간 스냅샷은 그대로여야 합니다. 이후 task는 도메인 view를 바꾸지 않으므로 스냅샷이 다시 바뀌면 안 됩니다. `uv run pytest -q -m "not slow"` 전체 PASS
- [ ] **Step 6: Commit** — `feat(core): 나의 사주 view에 원국 개인 해석 목록, ruleset 2026.10.2 (#51)`

### Task 4: proto와 gRPC 매핑 — personal_readings

**Files:**
- Modify: `proto/myungri/engine/v1/engine.proto` (spec §2.3의 `PersonalTermKind`, `PersonalReading`, `ChartResponse.personal_readings = 13`; 머리 주석의 ChartResponse 개요에 한 줄)
- Regenerate: `core/src/myungri_engine/_gen/` (`bash tools/gen_proto.sh`)
- Modify: `core/src/myungri_engine/grpc_api/mapping.py` (`_PREFIX_PERSONAL_TERM_KIND = "PERSONAL_TERM_KIND"`, `chart_to_proto`가 `personal_readings` 채움. `position`·`shinsal`이 None이면 `_optional_name`으로 UNSPECIFIED)
- Modify: `core/tests/unit/test_proto_generated.py` (`DOMAIN_TO_PROTO_ENUMS`에 `(enums.PersonalTermKind, "PersonalTermKind", "PERSONAL_TERM_KIND")` 추가)
- Test: `core/tests/integration/test_grpc_server.py`

- [ ] **Step 1: 실패하는 통합 테스트 작성**

```python
def test_chart_personal_readings(stub): ...
    # resp.personal_readings[0].kind == pb.PERSONAL_TERM_KIND_DAY_MASTER, position == pb.POSITION_DAY_STEM
    # judgment.message_key.startswith("personal.day_master."), judgment.evidence 비어 있지 않음
    # SEUN 항목의 position == POSITION_UNSPECIFIED
```

- [ ] **Step 2: 실패 확인** — `uv run pytest tests/integration -q` → FAIL
- [ ] **Step 3: proto 수정, 코드 재생성, 매핑 구현**
- [ ] **Step 4: 통과 확인** — `uv run pytest tests/integration tests/unit/test_proto_generated.py -q` PASS, `(cd ../proto && buf lint)` 출력 없음. 재생성한 `_gen`은 이 commit에 함께 넣습니다
- [ ] **Step 5: Commit** — `feat(core): ChartResponse.personal_readings proto와 매핑 (#51)`

### Task 5: 출생 시진 계산과 GetBirthHour

**Files:**
- Modify: `core/src/myungri_engine/calendar_core/birth.py`
- Modify: `proto/myungri/engine/v1/engine.proto` (spec §3), `_gen` 재생성
- Modify: `core/src/myungri_engine/grpc_api/server.py` (`_required_birth`의 타입 주석 union에 `pb.BirthHourRequest` 추가), `mapping.py`
- Modify: `core/tests/unit/test_proto_generated.py` (서비스 메서드 목록 끝에 `GetBirthHour`. proto에서도 `GetMonthCalendar` 다음에 선언)
- Test: `core/tests/unit/calendar_core/test_birth.py`, `core/tests/integration/test_grpc_server.py`

**Interfaces:**
- Produces: frozen dataclass `BirthHour(branch: Branch, start: datetime, end: datetime, notices: tuple[Notice, ...])`. `start`·`end`는 UTC aware입니다.
- Produces: `birth_hour(birth: BirthInput) -> BirthHour`. `birth.time is None`이면 날짜 검사보다 **먼저** `InvalidInputError("birth.time가 없습니다.")`를 냅니다. `notices`는 `resolve_birth_moment`의 notice를 그대로 씁니다(자시 경계, 서머타임 공백·중복, 절입 근처).
- Produces: `mapping.birth_hour_to_proto(hour: BirthHour) -> pb.BirthHourResponse`
- 알고리즘(시그니처가 정하지 못하는 부분):

```python
moment = resolve_birth_moment(birth)               # utc, corrected_local, notices
correction = moment.corrected_local - moment.utc.replace(tzinfo=None)
h = moment.corrected_local.hour
start_corrected = moment.corrected_local.replace(minute=0, second=0, microsecond=0) - timedelta(hours=0 if h % 2 == 1 else 1)
branch = list(Branch)[((start_corrected.hour + 1) // 2) % 12]
start_utc = (start_corrected - correction).replace(tzinfo=UTC); end_utc = start_utc + timedelta(hours=2)
```

- [ ] **Step 1: 실패하는 테스트 작성** (기대 구간은 서울 벽시계로 비교)

```python
def test_seoul_inshi(): ...          # 1990-05-05 04:00 → IN, 03:30~05:30 KST
def test_zi_hour_spans_midnight(): ...  # 1990-05-15 00:10 → JA, 05-14 23:30 ~ 05-15 01:30 KST (Review Focus 5)
def test_dst_1987(): ...             # 1987-07-01 04:00 (서머타임 UTC+10, 표준시 03:00) → CHUK, 벽시계 02:30~04:30
def test_utc_0830_dst(): ...         # 1956-07-01 04:00 (UTC+8:30 시기 서머타임, +09:30) → IN, 벽시계 04:00~06:00
def test_utc_0830_standard(): ...    # 1958-01-15 04:00 (+08:30, 서머타임 없음) → IN, 벽시계 03:00~05:00
def test_dst_gap_notice_matches_chart(): ...  # 1987-05-10 02:30(공백) → notices가 resolve_birth_moment와 같음 (Review Focus 4)
def test_explicit_longitude(): ...   # longitude=129.0 → 구간이 대표 경도보다 6분 앞당겨짐
def test_branch_matches_chart_hour_pillar(): ...  # hypothesis: 무작위 출생에서 birth_hour().branch == build_chart().pillars.hour.branch
def test_unknown_time_rejected(): ...  # InvalidInputError
def test_unknown_time_checked_before_range(): ...  # 시간 없음 + 1800년 날짜 → InvalidInputError (OutOfRangeError 아님)
# integration
def test_get_birth_hour(stub): ...  # branch == pb.BRANCH_IN, start/end Timestamp, 시간 없음 → INVALID_ARGUMENT, details에 "birth.time"
```

- [ ] **Step 2: 실패 확인** — `uv run pytest tests/unit/calendar_core/test_birth.py tests/integration tests/unit/test_proto_generated.py -q` → FAIL
- [ ] **Step 3: `birth_hour` 구현, proto에 `GetBirthHour`·`BirthHourRequest`·`BirthHourResponse` 추가, 재생성, servicer `GetBirthHour` 구현**(`_required_birth` 재사용, `run_or_abort`)
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS, `uv run mypy src tools` 통과, `buf lint` 통과
- [ ] **Step 5: Commit** — `feat(core): 출생 시각의 시진을 돌려주는 GetBirthHour RPC (#41)`

### Task 6: GetInfo

**Files:**
- Modify: `proto/myungri/engine/v1/engine.proto` (spec §4, `GetBirthHour` 다음에 선언), `_gen` 재생성, `grpc_api/server.py`
- Modify: `core/tests/unit/test_proto_generated.py` (서비스 메서드 목록 끝에 `GetInfo`)
- Test: `core/tests/integration/test_grpc_server.py`

- [ ] **Step 1: 실패하는 테스트** — `test_get_info(stub)`: `resp.engine_version == ENGINE_VERSION`, `resp.ruleset_version == RULESET_VERSION` (`myungri_engine.version`)
- [ ] **Step 2: 실패 확인** — `uv run pytest tests/integration tests/unit/test_proto_generated.py -q` → FAIL
- [ ] **Step 3: proto 추가, 재생성, servicer `GetInfo` 구현**
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS
- [ ] **Step 5: Commit** — `feat(core): 엔진·규칙 버전을 돌려주는 GetInfo RPC (#49)`

### Task 7: 불변 조건, 계약 파일, 문서

**Files:**
- Modify: `core/tests/properties/test_invariants.py` (원국 개인 해석 불변 조건)
- Update: `core/message_keys.json`, `core/message_params.json`
- Modify: `core/docs/decisions.md` (C27: spec §2.2 결정 원문), `core/CLAUDE.md` (현재 상태·계약·다음 할 일), spec 상태 `구현 완료`

- [ ] **Step 1: 불변 조건 테스트 추가**

```python
@PROPERTY_SETTINGS
@given(birth=birth_inputs, as_of=daily_dates)
def test_all_personal_readings_have_evidence(birth, as_of): ...
    # compose_chart의 모든 reading: key in ALL_KEYS, evidence 있음, validate_refs 통과,
    # (kind, position, index, shinsal) 중복 없음
```

- [ ] **Step 2: 실행** — `uv run pytest tests/properties -q` PASS (Task 3까지의 구현으로 통과해야 함. 실패하면 해당 task로 돌아가 고침)
- [ ] **Step 3: 스냅샷 확인** — `uv run pytest tests/snapshots tests/unit/test_ruleset_version.py -q` PASS(Task 3 이후 변화 없음)
- [ ] **Step 4: 계약 파일 재생성과 문서 갱신** — README "메시지 키와 매개변수 목록" 명령, `message_keys.json` 153개 확인
- [ ] **Step 5: 전체 검증** — `uv run ruff check .`, `uv run mypy src tools`, `uv run pytest -q -m "not slow"`, `uv run pytest -q -m slow`, `bash tools/gen_proto.sh && git diff --exit-code src/myungri_engine/_gen`, `(cd ../proto && buf lint)`, `python3 -I ../tools/docs-check/docs_check.py ..` 모두 통과
- [ ] **Step 6: Commit** — `chore(core): 개인 해석 불변 조건, 계약 파일·문서 갱신 (#51, #41, #49)`

### Task 8: PR과 알림

- [ ] **Step 1: push 후 PR 생성** (`main` 대상). CI의 `core-proto`에서 `buf breaking`이 실제로 실행됐는지 로그로 확인합니다(#5-1 후속).
- [ ] **Step 2: Issue 댓글**
  * #51: C27 키 구조, 응답 위치, 키 60개, writing 기준 값(`place`·`role` 값 목록. `role`은 데일리 컬러의 역할 값과 집합이 다름)
  * #41, #49: RPC 이름과 메시지
  * server 앞으로 `ruleset_version` `2026.10.2` 변경 알림(`from:core`)

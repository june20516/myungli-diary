# 명리 엔진 (core/) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 출생 정보로 원국을 세우고, 일진 × 원국으로 데일리·월간 판정을 계산해 gRPC로 반환하는 상태 없는 Python 명리 엔진을 `core/`에 만듭니다.

**Architecture:** 계층형 순수 함수 구조입니다: `domain`(enum·값 객체) → `constants` / `references`(상수·근거 데이터) → `calendar_core`(시각 변환과 lunar-python 어댑터) → `chart`(원국·대운) → `rules`(판정 규칙, 파일 하나에 규칙 하나) → `composers`(화면 단위 조립) → `grpc_api`. 엔진은 문장을 만들지 않고, 메시지 키·매개변수·근거만 반환합니다.

**Tech Stack:** Python 3.13, uv 0.11, lunar-python 1.4.8, grpcio / grpcio-tools 1.84.0, protobuf, pytest 9, hypothesis, syrupy 6, ruff, mypy(strict), buf(lint·breaking 전용).

**Spec:** `core/docs/specs/2026-10-10-myungri-engine-design.md` (승인됨, D34). 상위 근거는 `core/docs/engine-logic-wiki.md` v1.4와 `docs/decisions.md`(루트, 읽기 전용)입니다. 작업 규약은 `core/CLAUDE.md`와 `docs/workflow.md`를 따릅니다.

## Global Constraints

- 이 plan이 고칠 수 있는 곳은 `core/`, `proto/myungri/engine/`과 `proto/buf.yaml`, `.github/workflows/core.yml`, 그리고 요청·보고용 `docs/coordination/`뿐입니다. 루트의 `README.md`, `docs/background/`, `docs/decisions.md`는 고치지 않습니다. 바꿔야 하면 `docs/coordination/`에 요청을 남깁니다(`docs/workflow.md`).
- 모든 코드는 `core/` 아래에 둡니다. 패키지 이름은 `myungri_engine`, 소스 위치는 `core/src/myungri_engine/`, 테스트 위치는 `core/tests/`입니다.
- `lunar_python`은 `myungri_engine/calendar_core/` 안에서만 import합니다(D9). 다른 패키지에서 import하면 Task 1의 import 규칙 테스트가 실패합니다.
- `rules/`는 문장을 만들지 않습니다. 사용자에게 보일 문자열은 엔진 어디에도 넣지 않습니다(D27). 메시지 키는 `constants/message_keys.py`에 등록된 것만 씁니다.
- 천간·지지·오행·십성·방위는 enum이며, 문자열 표기를 비교 키로 쓰지 않습니다.
- 합·충·형 매핑의 키는 `frozenset`입니다(07 §5).
- 모든 `Judgment`에는 근거가 하나 이상 있어야 합니다. 모든 `source_ref`는 `<자료 디렉터리>/<파일 이름>#<키 경로>` 형식이며, 로더로 실제 데이터를 찾을 수 있어야 합니다(spec §11).
- 지원 출생 범위는 양력 1900-01-31 ~ 2099-12-31입니다. 범위 밖이면 `OutOfRangeError`입니다(spec §3).
- `Asia/Seoul`의 대표 경도는 127.5°입니다. 그 밖의 시간대는 표준 자오선(표준 오프셋 시간 × 15°)을 씁니다(spec §4.2).
- 자시는 보정 시각 23:00~00:59이며, 다음 날 일주 + 자시로 계산합니다. lunar-python에서는 `setSect(1)`입니다(D6).
- 타입 힌트는 모든 공개 함수에 붙이고, `mypy --strict`를 통과해야 합니다. `Any`는 쓰지 않습니다.
- 명령은 모두 `core/` 디렉터리에서 실행합니다(`cd core`). commit은 저장소 루트 기준 경로로 합니다.
- commit 메시지 끝에는 attribution 두 줄을 붙입니다:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_011nrXCUfLSPFWfQkqmq1gvQ`

## Review Focus

1. 음력 입력의 무효 날짜: 그해 윤달이 다른 달인데 `is_leap_month=True`로 들어오거나, 작은달(29일)에 30일이 들어오는 경우 → `InvalidInputError` (Task 4에서 고정).
2. 양력 1월~입춘 전 출생자의 연주: 연주가 1월 1일이 아니라 입춘에서 바뀌어야 함. 예: 2024-02-04 17:26 KST 출생은 癸卯년, 17:28 출생은 甲辰년 (Task 5에서 고정).
3. 해외 현재 시간대의 서머타임 시작일: `current_timezone="America/New_York"`, 2026-03-08처럼 시계가 건너뛰는 날에도 집중 시간 후보 시진 7개가 겹치지 않고 시간순으로 나와야 함 (Task 5에서 고정).
4. 데일리 요청 날짜가 지원 범위 밖(예: 2100-01-01)이면 `OutOfRangeError` (Task 4에서 고정).
5. 양력의 존재하지 않는 날짜(예: 2023-02-29)는 proto `LocalDate`로 들어올 수 있으므로 `InvalidInputError` (Task 4에서 고정).

---

## File Structure

```
core/
  pyproject.toml                  uv 프로젝트, 의존성, ruff·mypy·pytest 설정
  README.md                       실행·테스트·코드 생성 방법
  tools/
    gen_proto.sh                  proto → src/myungri_engine/_gen/ 생성
    calibrate_strength.py         강약 임계값·조후 기준값 산출 (spec §6.1·§6.2)
    fetch_kasi.py                 KASI 골든 데이터 수집
  src/myungri_engine/
    domain/      enums.py, elements.py, ten_gods.py, models.py, errors.py
    constants/   johu.py, gwiin.py, relations.py, shinsal.py, numbers.py,
                 directions.py, longitudes.py, calibration.py, message_keys.py
    references/  loader.py, data/gungtong_bogam/{johu_evidence,five_elements,corrections}.json
    calendar_core/ birth.py (시각 변환), lunar_adapter.py (lunar-python 감싸기)
    chart/       pillars.py, luck_cycles.py, shinsal.py
    rules/       strength.py, yongsin.py, relations.py, day_kind.py, color.py,
                 direction.py, number.py, focus_time.py, tags.py, messages.py,
                 calendar_luck.py
    composers/   chart.py, daily.py, month.py
    grpc_api/    server.py, mapping.py, errors.py
    _gen/        (생성 코드, commit 대상)
  tests/
    unit/...                       모듈별 단위 테스트 (소스 구조와 같은 경로)
    golden/                        KASI·기준 앱 골든 테스트와 fixtures/
    properties/                    hypothesis 불변 조건 테스트
    snapshots/                     syrupy 회귀 스냅샷
proto/
  buf.yaml
  myungri/engine/v1/engine.proto
.github/workflows/core.yml
```

---

### Task 1: core 프로젝트 골격과 domain 기초

**Files:**
- Create: `core/pyproject.toml`, `core/README.md`, `core/src/myungri_engine/__init__.py`
- Create: `core/src/myungri_engine/domain/{__init__,enums,elements,ten_gods,models,errors}.py`
- Test: `core/tests/unit/domain/test_elements.py`, `core/tests/unit/domain/test_ten_gods.py`, `core/tests/unit/test_import_rules.py`

**Interfaces:**
- Produces:
  - `enums.Stem` (`GAP 甲, EUL 乙, BYEONG 丙, JEONG 丁, MU 戊, GI 己, GYEONG 庚, SIN 辛, IM 壬, GYE 癸`), 속성 `.hanja: str`, `.element: Element`, `.is_yang: bool`, `Stem.from_hanja(s) -> Stem`
  - `enums.Branch` (`JA 子, CHUK 丑, IN 寅, MYO 卯, JIN 辰, SA 巳, O 午, MI 未, SHIN 申, YU 酉, SUL 戌, HAE 亥`), 속성 `.hanja`, `.element`(정기 오행), `.is_yang`, `Branch.from_hanja(s)`
  - `enums.Element` (`WOOD, FIRE, EARTH, METAL, WATER`)
  - `enums.TenGod` (`BIGYEON, GEOPJAE, SIKSIN, SANGGWAN, PYEONJAE, JEONGJAE, PYEONGWAN, JEONGGWAN, PYEONIN, JEONGIN`), `.group: TenGodGroup`
  - `enums.TenGodGroup` (`BIGYEOP, SIKSANG, JAESEONG, GWANSEONG, INSEONG`)
  - `enums.Gender` (`MALE, FEMALE`), `enums.CalendarType` (`SOLAR, LUNAR`), `enums.Direction8` (`N, NE, E, SE, S, SW, W, NW`), `enums.DayKind` (`GWIIN_DAY, YONGSIN_DAY, GISIN_DAY, ORDINARY_DAY`), `enums.StrengthLevel` (`VERY_WEAK, WEAK, NEUTRAL, STRONG, VERY_STRONG`), `enums.YongsinMethod` (`JOHU, JOHU_NEUTRAL, EOKBU`), `enums.LuckLevel` (`GOOD, NEUTRAL, CAUTION`), `enums.NoticeCode` (spec §9.1의 7개), `enums.Shinsal` (`CHEONEUL_GWIIN, DOHWA, YEOKMA, HWAGAE, YANGIN, GONGMANG`), `enums.TwelveStage` (12운성 12개: `JANGSAENG, MOKYOK, GWANDAE, GEONROK, JEWANG, SOE, BYEONG, SA, MYO, JEOL, TAE, YANG`)
  - `elements.generates(e) -> Element`, `elements.controls(e) -> Element`, `elements.generated_by(e) -> Element`, `elements.controlled_by(e) -> Element`
  - `ten_gods.ten_god(day_stem: Stem, other: Stem) -> TenGod`
  - `models.Pillar(stem: Stem, branch: Branch)` (frozen dataclass), `models.FourPillars(year, month, day: Pillar, hour: Pillar | None)`, `models.Evidence(rule_id: str, source_ref: str, detail: Mapping[str, str])`, `models.Judgment(message_key: str, params: Mapping[str, str | int | float | bool], evidence: tuple[Evidence, ...])`, `models.Notice(code: NoticeCode, detail: Mapping[str, str])`
  - `errors.InvalidInputError(ValueError)`, `errors.OutOfRangeError(ValueError)`

- [ ] **Step 1: uv 프로젝트 생성**

`core/pyproject.toml`: 프로젝트 이름은 `myungri-engine`, `requires-python = ">=3.13"`이고 src 레이아웃입니다. 의존성은 `lunar-python==1.4.8`, `grpcio==1.84.0`, `protobuf`입니다. 개발 의존성은 `grpcio-tools==1.84.0`, `pytest>=9`, `hypothesis`, `syrupy>=6`, `ruff`, `mypy`, `types-protobuf`입니다. 설정은 `[tool.mypy] strict = true`, `[tool.ruff] line-length = 110`, `[tool.pytest.ini_options] testpaths = ["tests"]`입니다.
Run: `cd core && uv sync`
Expected: `.venv` 생성, 오류 없음.

- [ ] **Step 2: 실패하는 테스트 작성**

```python
# tests/unit/domain/test_elements.py
from myungri_engine.domain.elements import generates, controls, generated_by, controlled_by
from myungri_engine.domain.enums import Element as E

def test_generation_cycle():
    assert [generates(e) for e in (E.WOOD, E.FIRE, E.EARTH, E.METAL, E.WATER)] == [E.FIRE, E.EARTH, E.METAL, E.WATER, E.WOOD]

def test_control_cycle():
    assert [controls(e) for e in (E.WOOD, E.EARTH, E.WATER, E.FIRE, E.METAL)] == [E.EARTH, E.WATER, E.FIRE, E.METAL, E.WOOD]

def test_inverse_relations():
    for e in E:
        assert generates(generated_by(e)) == e and controls(controlled_by(e)) == e
```

```python
# tests/unit/domain/test_ten_gods.py
import pytest
from myungri_engine.domain.enums import Stem as S, TenGod as T, TenGodGroup as G
from myungri_engine.domain.ten_gods import ten_god

@pytest.mark.parametrize("other,expected", [
    (S.GAP, T.BIGYEON), (S.EUL, T.GEOPJAE), (S.BYEONG, T.SIKSIN), (S.JEONG, T.SANGGWAN),
    (S.MU, T.PYEONJAE), (S.GI, T.JEONGJAE), (S.GYEONG, T.PYEONGWAN), (S.SIN, T.JEONGGWAN),
    (S.IM, T.PYEONIN), (S.GYE, T.JEONGIN),
])
def test_ten_gods_for_gap_day_master(other, expected):
    assert ten_god(S.GAP, other) == expected

def test_yin_day_master():
    assert ten_god(S.EUL, S.GAP) == T.GEOPJAE and ten_god(S.EUL, S.GYEONG) == T.JEONGGWAN

def test_groups():
    assert T.PYEONGWAN.group == G.GWANSEONG and T.JEONGIN.group == G.INSEONG
```

```python
# tests/unit/test_import_rules.py  — lunar_python은 calendar_core 안에서만 import
from pathlib import Path
SRC = Path(__file__).resolve().parents[2] / "src" / "myungri_engine"

def test_lunar_python_imported_only_in_calendar_core():
    offenders = [p for p in SRC.rglob("*.py")
                 if "lunar_python" in p.read_text(encoding="utf-8") and "calendar_core" not in p.parts]
    assert offenders == []
```

- [ ] **Step 3: 실패 확인**

Run: `uv run pytest tests/unit -q`
Expected: FAIL (`ModuleNotFoundError: myungri_engine.domain`). 단, `test_import_rules`는 통과합니다.

- [ ] **Step 4: Interfaces에 적은 domain 모듈 구현**

십성은 일간과 상대 천간의 오행 관계(같음 / 내가 생 / 내가 극 / 나를 극 / 나를 생)와 음양 일치 여부로 정합니다. 음양이 같으면 앞의 것(비견·식신·편재·편관·편인), 다르면 뒤의 것(겁재·상관·정재·정관·정인)입니다.

- [ ] **Step 5: 통과 확인과 정적 검사**

Run: `uv run pytest tests/unit -q && uv run ruff check . && uv run mypy src`
Expected: 전부 PASS, `Success: no issues found`.

- [ ] **Step 6: Commit**

```bash
git add core/pyproject.toml core/uv.lock core/README.md core/src core/tests
git commit -m "feat(core): 엔진 프로젝트 골격과 domain enum·오행·십성 추가"
```

---

### Task 2: 상수표와 메시지 키 레지스트리

**Files:**
- Create: `core/src/myungri_engine/constants/{__init__,johu,gwiin,relations,shinsal,numbers,directions,longitudes,message_keys}.py`
- Test: `core/tests/unit/constants/test_tables.py`

**Interfaces:**
- Consumes: Task 1의 enum.
- Produces:
  - `johu.JOHU_YONGSIN: Mapping[Stem, Mapping[Branch, tuple[Stem, ...]]]` — 07 위키 §5 `JOHU_YONGSIN`(정정 11칸 반영본)을 enum으로 옮깁니다.
  - `gwiin.CHEONEUL_GWIIN: Mapping[Stem, frozenset[Branch]]` (07 §5)
  - `relations.STEM_HAP: Mapping[frozenset[Stem], Element]`, `relations.BRANCH_HAP: Mapping[frozenset[Branch], Element]`(午未=火), `relations.BRANCH_CHUNG: frozenset[frozenset[Branch]]`(子午·丑未·寅申·卯酉·辰戌·巳亥), `relations.BRANCH_HYEONG_GROUPS: tuple[frozenset[Branch], ...]`(寅巳申, 丑戌未), `relations.BRANCH_HYEONG_PAIRS: frozenset[frozenset[Branch]]`(子卯), `relations.SELF_HYEONG: frozenset[Branch]`(辰·午·酉·亥)
  - `shinsal.DOHWA / YEOKMA / HWAGAE: Mapping[Branch, Branch]` (spec §5.4, 삼합 그룹의 각 지지 → 신살 지지), `shinsal.YANGIN: Mapping[Stem, Branch]`(양간 5개만)
  - `numbers.HADO: Mapping[Element, tuple[int, int]]` = 수(1,6) 화(2,7) 목(3,8) 금(4,9) 토(5,10)
  - `directions.ELEMENT_DIRECTION: Mapping[Element, Direction8]`(수 N, 화 S, 목 E, 금 W), `directions.BAGUA_ELEMENT: Mapping[Direction8, Element]`(spec §7.3), `directions.BRANCH_DIRECTION: Mapping[Branch, Direction8]`(spec §7.3.1)
  - `longitudes.representative_longitude(timezone: str, standard_offset_hours: float) -> float` (`Asia/Seoul` → 127.5, 그 밖은 `offset × 15`)
  - `message_keys.ALL_KEYS: frozenset[str]`, `message_keys.require(key: str) -> str` (등록되지 않은 키면 `KeyError`)
  - `python -m myungri_engine.constants.message_keys` → 정렬된 키 목록 JSON을 표준 출력으로 냅니다. 결과는 `core/message_keys.json`에 commit합니다. Go 콘텐츠 모듈 시드의 키 검사에 씁니다(spec §10).

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# tests/unit/constants/test_tables.py
import json
from pathlib import Path
from myungri_engine.constants.johu import JOHU_YONGSIN
from myungri_engine.constants.gwiin import CHEONEUL_GWIIN
from myungri_engine.constants.relations import STEM_HAP, BRANCH_HAP, BRANCH_CHUNG
from myungri_engine.constants.shinsal import DOHWA, YEOKMA, HWAGAE, YANGIN
from myungri_engine.constants.numbers import HADO
from myungri_engine.constants.longitudes import representative_longitude
from myungri_engine.constants import message_keys
from myungri_engine.domain.enums import Stem as S, Branch as B, Element as E
import pytest

CORRECTIONS = Path(__file__).resolve().parents[4] / "core/docs/references/gungtong-bogam/corrections.json"

def test_johu_has_120_cells_and_matches_corrections():
    assert sum(len(m) for m in JOHU_YONGSIN.values()) == 120
    for c in json.loads(CORRECTIONS.read_text(encoding="utf-8"))["corrections"]:
        cell = JOHU_YONGSIN[S.from_hanja(c["stem"])][B.from_hanja(c["branch"])]
        assert [s.hanja for s in cell] == c["after"]

def test_spot_values():
    assert JOHU_YONGSIN[S.GAP][B.IN] == (S.BYEONG, S.GYE)
    assert CHEONEUL_GWIIN[S.SIN] == frozenset({B.IN, B.O})
    assert STEM_HAP[frozenset({S.GI, S.GAP})] == E.EARTH          # 순서 무관
    assert BRANCH_HAP[frozenset({B.MI, B.O})] == E.FIRE
    assert frozenset({B.HAE, B.SA}) in BRANCH_CHUNG
    assert DOHWA[B.SHIN] == B.YU and YEOKMA[B.IN] == B.SHIN and HWAGAE[B.HAE] == B.MI
    assert YANGIN == {S.GAP: B.MYO, S.BYEONG: B.O, S.MU: B.O, S.GYEONG: B.YU, S.IM: B.JA}
    assert HADO[E.METAL] == (4, 9)

def test_representative_longitude():
    assert representative_longitude("Asia/Seoul", 9) == 127.5
    assert representative_longitude("Asia/Tokyo", 9) == 135.0
    assert representative_longitude("America/New_York", -5) == -75.0

def test_unknown_message_key_rejected():
    with pytest.raises(KeyError):
        message_keys.require("no.such.key")

def test_exported_key_list_up_to_date():
    exported = json.loads((Path(__file__).resolve().parents[3] / "message_keys.json").read_text(encoding="utf-8"))
    assert exported == sorted(message_keys.ALL_KEYS)
```

- [ ] **Step 2: 실패 확인**

Run: `uv run pytest tests/unit/constants -q`
Expected: FAIL (`ModuleNotFoundError`).

- [ ] **Step 3: 상수 모듈 구현**

값은 spec §5.4·§7.3·§7.4·§4.2와 07 위키 §5를 그대로 옮깁니다. `message_keys.ALL_KEYS`에는 spec §7.2~§7.8·§8에 나오는 키를 전부 등록합니다.
- 컬러·방향·숫자·집중 시간: `color.<day_kind>`, `direction.day_kind.<gwiin|yongsin|gisin|ordinary>`, `number.<day_kind>`, `focus_time.<gwiin|yongsin|huisin|hap|fallback>`
- 태그: spec §7.7 표의 키 전부
- 총운: `fortune.<day_kind 소문자>.<ten_god_group 소문자>` 20개와 `fortune.tag.<태그 키>`
- 가이드 질문: `guide.<태그 키>`, `guide.ten_god.<group>`
- 판정: `yongsin.method.<johu|johu_neutral|eokbu>`, `calendar.<good|neutral|caution>`

키 목록은 코드로 조합해도 됩니다.

- [ ] **Step 4: 통과 확인**

Run: `uv run pytest tests/unit/constants -q && uv run mypy src`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
uv run python -m myungri_engine.constants.message_keys > message_keys.json
git add core/src/myungri_engine/constants core/tests/unit/constants core/message_keys.json
git commit -m "feat(core): 조후표·귀인·합충형·신살·하도수·방위 상수와 메시지 키 레지스트리 추가"
```

---

### Task 3: 근거 데이터를 core로 이전하고 로더 추가

**Files:**
- Move: `core/docs/references/gungtong-bogam/{johu_evidence,five_elements,corrections}.json` → `core/src/myungri_engine/references/data/gungtong_bogam/`
- Modify: `core/docs/references/gungtong-bogam/tools/build_evidence.py` (출력 경로를 core 데이터 디렉터리로, 조후표 입력을 `core/src/myungri_engine/constants/johu.py`의 `JOHU_YONGSIN` 한자 표로 변경)
- Modify: `core/docs/references/README.md`, `core/docs/engine-logic-wiki.md` §3.3-0·§5의 경로 표기
- Create: `core/src/myungri_engine/references/{__init__,loader}.py`
- Modify: `core/tests/unit/constants/test_tables.py` (CORRECTIONS 경로를 새 위치로)
- Test: `core/tests/unit/references/test_loader.py`

**Interfaces:**
- Produces:
  - `loader.resolve(source_ref: str) -> object` — `"gungtong-bogam/johu_evidence#甲.子"`처럼 `#` 뒤의 점 경로로 JSON 안을 찾습니다. `johu_evidence`는 `cells` 아래를 찾습니다. 없으면 `KeyError`입니다.
  - `loader.validate_refs(refs: Iterable[str]) -> None` — 하나라도 없으면 `KeyError`
  - `loader.johu_ref(stem: Stem, branch: Branch) -> str`, `loader.FIVE_ELEMENTS_REF: Mapping[str, str]` (`"color"`, `"direction"`, `"number"`, `"balance_principle"` → source_ref)
  - 패키지 데이터 디렉터리 이름은 `gungtong_bogam`이고, source_ref 접두어는 spec대로 `gungtong-bogam`입니다. 로더가 둘을 매핑합니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# tests/unit/references/test_loader.py
import pytest
from myungri_engine.references import loader
from myungri_engine.domain.enums import Stem as S, Branch as B

def test_resolve_johu_cell():
    cell = loader.resolve(loader.johu_ref(S.GAP, B.JA))
    assert cell["yongsin"][0] == "丁" and cell["evidence_level"] == "month"

def test_resolve_five_elements():
    assert loader.resolve(loader.FIVE_ELEMENTS_REF["direction"])["mapping"]["水"] == "北"

def test_every_johu_cell_resolvable():
    loader.validate_refs(loader.johu_ref(s, b) for s in S for b in B)

def test_missing_ref_raises():
    with pytest.raises(KeyError):
        loader.resolve("gungtong-bogam/johu_evidence#甲.없음")
```

- [ ] **Step 2: 실패 확인**

Run: `uv run pytest tests/unit/references -q`
Expected: FAIL (`ModuleNotFoundError`).

- [ ] **Step 3: 데이터 이전**

`git mv`로 JSON 3개를 옮깁니다. `build_evidence.py`는 다음처럼 바꿉니다. `entries.json`과 `verification-report.md`는 문서 쪽에 그대로 둡니다.
- 조후표는 `core/src/myungri_engine/constants/johu.py`를 `ast`로 읽어 한자 표를 만듭니다.
- 출력 경로는 `core/src/myungri_engine/references/data/gungtong_bogam/`입니다.

문서 3곳의 경로 표기도 새 위치로 고칩니다. `pyproject.toml`에는 패키지 데이터로 `references/data/**/*.json`을 포함합니다.

- [ ] **Step 4: 로더 구현과 생성기 재실행**

Run: `cd .. && python3 -I core/docs/references/gungtong-bogam/tools/build_evidence.py && cd core && git status --short`
Expected: 생성기가 `OK 72 / REVIEWED 48`을 출력하고, 옮긴 JSON에 내용 변경(diff)이 없습니다.

- [ ] **Step 5: 통과 확인**

Run: `uv run pytest -q && uv run mypy src`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A core
git commit -m "refactor(core): 엔진 근거 데이터를 core 패키지로 이전하고 source_ref 로더 추가"
```

---

### Task 4: 출생 시각 변환 (`calendar_core/birth.py`)

**Files:**
- Create: `core/src/myungri_engine/calendar_core/{__init__,birth}.py`
- Test: `core/tests/unit/calendar_core/test_birth.py`

**Interfaces:**
- Consumes: Task 1 enum·errors, Task 2 `representative_longitude`.
- Produces:
  - `birth.BirthInput(calendar: CalendarType, is_leap_month: bool, date: datetime.date, time: datetime.time | None, gender: Gender, timezone: str, longitude: float | None)` (frozen). 음력이면 `date`의 연·월·일을 음력 값으로 해석합니다.
  - `birth.BirthMoment(solar_date: date, utc: datetime | None, solar_term_wallclock: datetime, corrected_local: datetime, time_known: bool, notices: tuple[Notice, ...])`
    - 시간 모름이면 `utc`는 `None`이고, `solar_term_wallclock`·`corrected_local`은 출생일 현지 정오를 같은 방식으로 변환한 값입니다.
  - `birth.resolve_birth_moment(birth: BirthInput) -> BirthMoment`
  - `birth.validate_civil_date(d: date) -> None` (데일리·월간 요청 날짜 범위 검사, 범위 밖 → `OutOfRangeError`)
  - 이 task는 `SOLAR` 입력만 처리합니다. `LUNAR` 입력이면 `NotImplementedError`를 냅니다. 음력 연결은 Task 5에서 `lunar_to_solar`를 만든 뒤 붙입니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# tests/unit/calendar_core/test_birth.py
from datetime import date, time, datetime, timezone
import pytest
from myungri_engine.calendar_core.birth import BirthInput, resolve_birth_moment, validate_civil_date
from myungri_engine.domain.enums import CalendarType, Gender, NoticeCode
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError

def seoul(d, t=None, tz="Asia/Seoul", lon=None):
    return BirthInput(CalendarType.SOLAR, False, d, t, Gender.MALE, tz, lon)

def codes(m): return {n.code for n in m.notices}

def test_modern_seoul_offset_and_lmt():
    m = resolve_birth_moment(seoul(date(2024, 3, 15), time(23, 40)))
    assert m.utc == datetime(2024, 3, 15, 14, 40, tzinfo=timezone.utc)
    assert m.solar_term_wallclock == datetime(2024, 3, 15, 22, 40)      # UTC+8
    assert m.corrected_local == datetime(2024, 3, 15, 23, 10)           # UTC+8:30 (= KST-30분)
    assert NoticeCode.ZI_HOUR_NEXT_DAY in codes(m)

@pytest.mark.parametrize("d,t,utc_hour_min", [
    (date(1956, 7, 1), time(12, 0), (2, 30)),   # UTC+8:30 + 서머타임 = +9:30
    (date(1958, 1, 1), time(12, 0), (3, 30)),   # UTC+8:30
    (date(1987, 7, 1), time(12, 0), (2, 0)),    # UTC+9 + 서머타임 = +10
])
def test_historical_offsets(d, t, utc_hour_min):
    m = resolve_birth_moment(seoul(d, t))
    assert (m.utc.hour, m.utc.minute) == utc_hour_min

def test_dst_gap_shifts_forward_with_notice():
    m = resolve_birth_moment(seoul(date(1987, 5, 10), time(2, 30)))
    assert NoticeCode.NONEXISTENT_LOCAL_TIME in codes(m)
    assert m.utc == datetime(1987, 5, 9, 17, 30, tzinfo=timezone.utc)   # 03:30 KDT로 해석

def test_dst_overlap_uses_first_with_notice():
    m = resolve_birth_moment(seoul(date(1987, 10, 11), time(2, 30)))
    assert NoticeCode.AMBIGUOUS_LOCAL_TIME in codes(m)
    assert m.utc == datetime(1987, 10, 10, 16, 30, tzinfo=timezone.utc)  # 서머타임(+10) 쪽

def test_explicit_longitude_overrides_representative():
    m = resolve_birth_moment(seoul(date(2024, 3, 15), time(12, 0), tz="Asia/Tokyo", lon=139.7))
    assert m.corrected_local == datetime(2024, 3, 15, 12, 18, 48)        # UTC+9:18:48

def test_time_unknown():
    m = resolve_birth_moment(seoul(date(2024, 3, 15)))
    assert m.time_known is False and m.utc is None and NoticeCode.TIME_UNKNOWN in codes(m)

@pytest.mark.parametrize("d", [date(1900, 1, 30), date(2100, 1, 1)])
def test_birth_out_of_range(d):
    with pytest.raises(OutOfRangeError):
        resolve_birth_moment(seoul(d, time(12, 0)))

def test_unknown_timezone():
    with pytest.raises(InvalidInputError):
        resolve_birth_moment(seoul(date(2024, 3, 15), time(12, 0), tz="Mars/Base"))

def test_civil_date_range():                     # Review Focus 4
    validate_civil_date(date(2099, 12, 31))
    with pytest.raises(OutOfRangeError):
        validate_civil_date(date(2100, 1, 1))
```

존재하지 않는 양력 날짜(Review Focus 5)는 `datetime.date`가 만들어지지 않으므로, proto → domain 변환(Task 18)에서 `InvalidInputError`로 고정합니다.

- [ ] **Step 2: 실패 확인**

Run: `uv run pytest tests/unit/calendar_core/test_birth.py -q`
Expected: FAIL (`ModuleNotFoundError`).

- [ ] **Step 3: `resolve_birth_moment` 구현**

spec §4.1의 1·3·4단계와 §4.2를 구현합니다.
- 공백·중복 판정: `zoneinfo` 결과를 `fold=0`과 `fold=1`로 각각 UTC 왕복 변환해 비교합니다.
- 대표 경도에 쓰는 표준 오프셋: 출생 시점의 `utcoffset() - dst()`입니다.
- `NEAR_SOLAR_TERM` notice는 절기 시각이 필요하므로 Task 5에서 붙입니다.

- [ ] **Step 4: 통과 확인**

Run: `uv run pytest tests/unit/calendar_core/test_birth.py -q && uv run mypy src`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/calendar_core core/tests/unit/calendar_core
git commit -m "feat(core): 출생 시각 변환 — 역사적 표준시·서머타임·지방평균시·자시 처리"
```

---

### Task 5: lunar-python 어댑터 (`calendar_core/lunar_adapter.py`)

**Files:**
- Create: `core/src/myungri_engine/calendar_core/lunar_adapter.py`
- Modify: `core/src/myungri_engine/calendar_core/birth.py` (`NEAR_SOLAR_TERM` notice 추가, `LUNAR` 입력을 `lunar_to_solar`로 변환. Task 4의 `NotImplementedError` 제거)
- Test: `core/tests/unit/calendar_core/test_lunar_adapter.py`

**Interfaces:**
- Consumes: Task 4 `BirthMoment`, `BirthInput`.
- Produces:
  - `lunar_to_solar(year: int, month: int, day: int, is_leap_month: bool) -> date` (무효 → `InvalidInputError`)
  - `pillars_for(moment: BirthMoment) -> FourPillars`: 연주·월주는 `solar_term_wallclock`, 일주·시주는 `corrected_local` + `setSect(1)`로 정합니다. 시간 모름이면 `hour=None`입니다.
  - `hidden_stems(branch: Branch) -> tuple[Stem, ...]` (정기가 맨 앞)
  - `twelve_stage(day_stem: Stem, branch: Branch) -> TwelveStage`
  - `day_gongmang(day: Pillar) -> frozenset[Branch]`
  - `day_pillar(civil_date: date) -> Pillar` (현지 정오 기준, spec §4.4)
  - `HourSlot(branch: Branch, pillar: Pillar, start: datetime, end: datetime, huangdao_lucky: bool)` (start/end는 시간대가 붙은 현지 시각, end는 포함하지 않음)
  - `hour_slots(civil_date: date, current_timezone: str) -> tuple[HourSlot, ...]` (그날 12시진. 경계는 그 시간대 대표 경도의 지방평균시를 거꾸로 적용)
  - `DeityKind` enum (`XI, FU, CAI, YANG_GUI, YIN_GUI`), `deity_directions(civil_date: date) -> tuple[tuple[DeityKind, Direction8], ...]` (이 순서)
  - `DayInfo(date: date, pillar: Pillar, lunar_month: int, lunar_day: int, is_leap_month: bool, solar_term: tuple[str, datetime] | None)`, `month_days(year: int, month: int, current_timezone: str) -> tuple[DayInfo, ...]` (절기 이름은 `JIE_QI` 원문 한자, 시각은 현재 시간대로 변환)
  - `nearest_solar_term_minutes(utc: datetime) -> float` (가장 가까운 절기와의 차이, 분)
  - `luck_cycles_raw(moment: BirthMoment, gender: Gender) -> tuple[int, int, tuple[Pillar, ...]]` (시작 연수, 시작 개월, 대운 간지 10개. 첫 빈 항목은 제외)

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# tests/unit/calendar_core/test_lunar_adapter.py
from datetime import date, time
import pytest
from myungri_engine.calendar_core import lunar_adapter as la
from myungri_engine.calendar_core.birth import BirthInput, resolve_birth_moment
from myungri_engine.domain.enums import CalendarType, Gender, Stem as S, Branch as B, Direction8 as D, NoticeCode
from myungri_engine.domain.models import Pillar
from myungri_engine.domain.errors import InvalidInputError

def moment(d, t, cal=CalendarType.SOLAR, leap=False):
    return resolve_birth_moment(BirthInput(cal, leap, d, t, Gender.MALE, "Asia/Seoul", None))

def test_zi_hour_next_day_pillar():           # 보정 23:10 → 다음 날 己卯일 甲子시 (07 §6 실행 확인값)
    p = la.pillars_for(moment(date(2024, 3, 15), time(23, 40)))
    assert p.day == Pillar(S.GI, B.MYO) and p.hour == Pillar(S.GAP, B.JA)

def test_year_changes_at_ipchun_not_jan1():   # Review Focus 2. 2024 입춘 = KST 17:27
    assert la.pillars_for(moment(date(2024, 2, 4), time(17, 26))).year == Pillar(S.GYE, B.MYO)
    assert la.pillars_for(moment(date(2024, 2, 4), time(17, 28))).year == Pillar(S.GAP, B.JIN)

def test_near_solar_term_notice():
    assert NoticeCode.NEAR_SOLAR_TERM in {n.code for n in moment(date(2024, 2, 4), time(18, 0)).notices}

def test_hidden_stems_main_qi_first():
    assert la.hidden_stems(B.SA) == (S.BYEONG, S.GYEONG, S.MU)

def test_lunar_to_solar_and_invalid():        # Review Focus 1
    assert la.lunar_to_solar(2023, 2, 1, True) == date(2023, 3, 22)   # 2023년 윤2월 1일
    with pytest.raises(InvalidInputError):
        la.lunar_to_solar(2024, 2, 1, True)                           # 2024년에는 윤2월 없음
    with pytest.raises(InvalidInputError):
        la.lunar_to_solar(2024, 1, 30, False)                         # 2024년 음력 1월은 29일까지

def test_lunar_birth_input_converted():
    m = moment(date(2023, 2, 1), time(12, 0), cal=CalendarType.LUNAR, leap=True)
    assert m.solar_date == date(2023, 3, 22)

def test_day_deity_directions():              # 2026-10-10 丁巳 (07 대화 실행값)
    assert dict(la.deity_directions(date(2026, 10, 10)))[la.DeityKind.XI] == D.S

def test_seoul_hour_slot_boundaries():
    slots = la.hour_slots(date(2026, 10, 13), "Asia/Seoul")
    jin = next(s for s in slots if s.branch == B.JIN)
    assert (jin.start.hour, jin.start.minute, jin.end.hour, jin.end.minute) == (7, 30, 9, 30)

def test_dst_start_day_slots_ordered():       # Review Focus 3
    slots = la.hour_slots(date(2026, 3, 8), "America/New_York")
    assert len(slots) == 12 and all(a.end <= b.start for a, b in zip(slots, slots[1:]))
```

음력 기댓값(2023년 윤2월 1일 = 2023-03-22, 2024년은 윤달 없음, 2024년 음력 1월은 29일)은 lunar-python 1.4.8로 확인한 값입니다(2026-10-10). Task 18의 KASI 골든 테스트에서 다시 검증됩니다.

- [ ] **Step 2: 실패 확인**

Run: `uv run pytest tests/unit/calendar_core/test_lunar_adapter.py -q`
Expected: FAIL.

- [ ] **Step 3: 어댑터 구현**

- 음력→양력: lunar-python의 `LunarYear.getLeapMonth()`와 `LunarMonth.getDayCount()`로 먼저 검증한 뒤 `Lunar.fromYmd`(윤달은 음수 월)로 변환합니다.
- 방위 문자열 매핑: `正北→N, 东北→NE, 正东→E, 东南→SE, 正南→S, 西南→SW, 正西→W, 西北→NW`

- [ ] **Step 4: 통과 확인**

Run: `uv run pytest tests/unit/calendar_core -q && uv run mypy src`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/calendar_core core/tests/unit/calendar_core
git commit -m "feat(core): lunar-python 어댑터 — 사주팔자·음력 변환·시진·길신 방위·월간 정보"
```

---

### Task 6: 원국과 대운·세운 (`chart/`)

**Files:**
- Create: `core/src/myungri_engine/chart/{__init__,pillars,luck_cycles,shinsal}.py`
- Test: `core/tests/unit/chart/test_pillars.py`, `test_luck_cycles.py`, `test_shinsal.py`

**Interfaces:**
- Consumes: Task 5 어댑터, Task 2 신살·귀인 상수.
- Produces:
  - `pillars.Position` enum (`YEAR_STEM, YEAR_BRANCH, MONTH_STEM, MONTH_BRANCH, DAY_STEM, DAY_BRANCH, HOUR_STEM, HOUR_BRANCH`)
  - `pillars.Chart(pillars: FourPillars, ten_gods: Mapping[Position, TenGod], hidden_stems: Mapping[Position, tuple[tuple[Stem, TenGod], ...]], twelve_stages: Mapping[Position, TwelveStage], shinsal: tuple[ShinsalHit, ...], gongmang: frozenset[Branch], notices: tuple[Notice, ...])`. 십성은 `DAY_STEM`을 제외한 천간과 각 지지의 정기에 대해 계산합니다. 시간 모름이면 HOUR 자리는 키에서 빠집니다.
  - `pillars.build_chart(moment: BirthMoment) -> Chart`
  - `shinsal.ShinsalHit(kind: Shinsal, position: Position)`, `shinsal.natal_shinsal(pillars: FourPillars) -> tuple[ShinsalHit, ...]`, `shinsal.shinsal_branches(pillars: FourPillars) -> Mapping[Shinsal, frozenset[Branch]]` (발동 판정용. 천을귀인·도화·역마·화개·양인·공망 각각의 대상 지지 집합), `shinsal.activated(branches: Mapping[Shinsal, frozenset[Branch]], today: Branch) -> tuple[Shinsal, ...]`
  - `luck_cycles.LuckPeriod(pillar: Pillar, start_age: int, start_age_korean: int, stem_ten_god: TenGod, branch_ten_god: TenGod, twelve_stage: TwelveStage)`, `luck_cycles.YearLuck(year: int, pillar: Pillar, ten_god: TenGod, relations_with_natal: tuple[str, ...])`, `luck_cycles.LuckCycles(forward: bool, start_years: int, start_months: int, periods: tuple[LuckPeriod, ...], years: tuple[YearLuck, ...], notices: tuple[Notice, ...])`
  - `luck_cycles.build_luck_cycles(moment: BirthMoment, gender: Gender, natal: FourPillars, as_of: date) -> LuckCycles`. `years`는 `as_of`가 속한 대운 구간의 10년이며, `relations_with_natal`은 Task 9의 관계 종류 이름입니다. Task 9 이전에는 빈 튜플로 두고, Task 9의 Step 5에서 채웁니다.

- [ ] **Step 1: 실패하는 테스트 작성**

테스트 이름과 assertion:
- `test_chart_ten_gods_exclude_day_stem`: `Position.DAY_STEM not in chart.ten_gods`
- `test_time_unknown_has_no_hour_positions`: `Position.HOUR_STEM not in chart.ten_gods and chart.pillars.hour is None`
- `test_twelve_stage_known_value`: 甲 일간, 亥 → `TwelveStage.JANGSAENG`
- `test_natal_shinsal_dohwa`: 일지 申, 연지 子인 원국에 酉가 있으면 `ShinsalHit(Shinsal.DOHWA, <酉 자리>)` 포함
- `test_activated_cheoneul`: 甲 일간의 `shinsal_branches`에서 `activated(..., B.MI)`에 `Shinsal.CHEONEUL_GWIIN` 포함
- `test_luck_direction`: 양간 연주 + MALE → `forward is True`, 양간 연주 + FEMALE → `False`
- `test_luck_periods_count_and_ages`: `len(periods) == 10`, 나이가 10씩 증가, `start_age_korean == start_age + 1`
- `test_time_unknown_luck_notice`: `NoticeCode.DAYUN_START_APPROXIMATE in codes`

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/chart -q` / Expected: FAIL

- [ ] **Step 3: 구현** — 연지·일지 기준 신살은 spec §5.4 표대로, 원국에 실제로 있는 자리만 `natal_shinsal`에 넣습니다.

- [ ] **Step 4: 통과 확인** — Run: `uv run pytest tests/unit/chart -q && uv run mypy src` / Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/chart core/tests/unit/chart
git commit -m "feat(core): 원국(십성·지장간·12운성·신살·공망)과 대운·세운 계산"
```

---

### Task 7: 신강·신약과 분포 보정 (`rules/strength.py`, `tools/calibrate_strength.py`)

**Files:**
- Create: `core/src/myungri_engine/rules/{__init__,strength}.py`, `core/src/myungri_engine/constants/calibration.py`, `core/tools/calibrate_strength.py`
- Test: `core/tests/unit/rules/test_strength.py`, `core/tests/unit/rules/test_calibration.py`

**Interfaces:**
- Consumes: Task 5 `hidden_stems`, Task 1 enum.
- Produces:
  - `strength.StrengthResult(score: float, level: StrengthLevel, element_weights: Mapping[Element, float])`
  - `strength.element_weights(pillars: FourPillars) -> Mapping[Element, float]`
  - `strength.compute_strength(pillars: FourPillars) -> StrengthResult`
  - `calibration.STRENGTH_THRESHOLDS: tuple[float, float, float, float]` (15·40·60·85 백분위), `calibration.JOHU_SUMMER_FIRE_SHARE: float`, `calibration.JOHU_WINTER_WATER_SHARE: float` (같은 계절 출생 중 상위 40% 경계값, spec §6.2), `calibration.SAMPLE_SEED = 20261010`, `calibration.SAMPLE_SIZE = 20000`
  - `tools/calibrate_strength.py --check` (상수와 다시 계산한 값이 다르면 exit 1), `--write` (상수 파일 갱신)

- [ ] **Step 1: 실패하는 테스트 작성**

- `test_position_weights`: 원국 하나를 손으로 계산한 오행 가중치와 일치하는지 봅니다. 가중치는 월지 3, 그 밖의 지지 1.5, 천간 1이고, 지장간 비율은 3개면 0.6/0.3/0.1, 2개면 0.7/0.3, 1개면 1.0입니다. 일간은 제외합니다. 예: `FourPillars(庚午, 辛巳, 庚辰, 辛巳)`의 기댓값을 테스트 안에 직접 계산해 적습니다.
- `test_time_unknown_drops_hour`: 시주가 없을 때 전체 가중 합 = 1(연간) + 1(월간) + 1.5(연지) + 3(월지) + 1.5(일지) = 8.0
- `test_score_is_support_share`: `score == 100 * (비겁 + 인성) / 전체`
- `test_level_boundaries`: `STRENGTH_THRESHOLDS` 경계값 바로 위·아래 점수가 인접 등급으로 나뉨
- `test_calibration_constants_up_to_date`(느린 테스트, `@pytest.mark.slow`): `subprocess.run([python, "tools/calibrate_strength.py", "--check"]).returncode == 0`

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/rules/test_strength.py -q` / Expected: FAIL

- [ ] **Step 3: 구현과 보정값 산출**

보정 스크립트는 `random.Random(SAMPLE_SEED)`로 1900-01-31 ~ 2099-12-31의 날짜와 00:00~23:59의 시각을 균등하게 뽑습니다. 출생지는 `Asia/Seoul`입니다. Task 5의 `pillars_for`로 원국을 세우고 점수를 모읍니다.
Run: `uv run python tools/calibrate_strength.py --write`
Expected: `constants/calibration.py` 생성. 실행 결과(임계값 4개, 조후 기준 2개)를 commit 메시지에 적습니다.

- [ ] **Step 4: 통과 확인** — Run: `uv run pytest tests/unit/rules -q -m "slow or not slow" && uv run mypy src tools` / Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/rules core/src/myungri_engine/constants/calibration.py core/tools/calibrate_strength.py core/tests/unit/rules core/pyproject.toml
git commit -m "feat(core): 신강·신약 점수와 분포 보정 임계값 (seed 20261010, n=20000)"
```

`pyproject.toml`에는 `markers = ["slow: 분포 보정 등 느린 테스트"]`를 등록합니다.

---

### Task 8: 용신 판정 (`rules/yongsin.py`)

**Files:**
- Create: `core/src/myungri_engine/rules/yongsin.py`
- Test: `core/tests/unit/rules/test_yongsin.py`

**Interfaces:**
- Consumes: Task 7 `StrengthResult`, `calibration.*`, Task 2 `JOHU_YONGSIN`, Task 3 `loader.johu_ref`, `loader.FIVE_ELEMENTS_REF`.
- Produces:
  - `yongsin.YongsinResult(yongsin: Element, huisin: Element, gisin: Element, tonggwan: Element, method: YongsinMethod, johu_stem: Stem | None, evidence: tuple[Evidence, ...])`
  - `yongsin.determine_yongsin(pillars: FourPillars, strength: StrengthResult) -> YongsinResult`

- [ ] **Step 1: 실패하는 테스트 작성** (`StrengthResult`를 직접 만들어 넣습니다)

- `test_summer_fire_heavy_uses_johu`: 월지 午, 화 비중이 `JOHU_SUMMER_FIRE_SHARE` 이상, 일간 丙 → `method == JOHU`, `yongsin == WATER`(조후표 丙午 첫 글자 壬), `johu_stem == S.IM`, `evidence[0].source_ref == loader.johu_ref(S.BYEONG, B.O)`
- `test_winter_water_heavy_uses_johu`: 월지 子, 수 비중 기준 이상, 일간 甲 → `yongsin == FIRE`(甲子 첫 글자 丁)
- `test_neutral_uses_johu_neutral`: level `NEUTRAL`, 봄 출생 → `method == JOHU_NEUTRAL`
- `test_weak_uses_inseong`: 甲 일간, `WEAK`, 조후 조건 불충족 → `yongsin == WATER`, `method == EOKBU`, 근거에 `FIVE_ELEMENTS_REF["balance_principle"]` 포함
- `test_strong_uses_weakest_output`: 甲 일간, `STRONG`, `element_weights`에서 토가 가장 약함 → `yongsin == EARTH`
- `test_strong_tie_order`: 식상·재성·관성 가중치가 같으면 식상(화)
- `test_derived_elements`: `huisin == generated_by(yongsin)`, `gisin == controlled_by(yongsin)`, `tonggwan == huisin`

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/rules/test_yongsin.py -q` / Expected: FAIL
- [ ] **Step 3: spec §6.2 순서대로 구현**
- [ ] **Step 4: 통과 확인** — Run: `uv run pytest tests/unit/rules -q -m "not slow" && uv run mypy src` / Expected: PASS
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/rules/yongsin.py core/tests/unit/rules/test_yongsin.py
git commit -m "feat(core): 용신 판정 — 조후 우선, 중화 시 조후, 그 밖 억부"
```

---

### Task 9: 합·충·형과 탐합망충 (`rules/relations.py`)

**Files:**
- Create: `core/src/myungri_engine/rules/relations.py`
- Modify: `core/src/myungri_engine/chart/luck_cycles.py` (세운 `relations_with_natal` 채우기)
- Test: `core/tests/unit/rules/test_relations.py`, `core/tests/unit/chart/test_luck_cycles.py`(1개 추가)

**Interfaces:**
- Consumes: Task 2 `relations.*`, Task 6 `Position`.
- Produces:
  - `relations.RelationKind` enum (`STEM_HAP, BRANCH_HAP, CHUNG, HYEONG`)
  - `relations.Relation(kind: RelationKind, natal_position: Position, suppressed_by: RelationKind | None)`
  - `relations.find_relations(natal: FourPillars, day: Pillar) -> tuple[Relation, ...]` (오늘 천간 ↔ 원국 천간, 오늘 지지 ↔ 원국 지지)
  - `relations.active(rels: Iterable[Relation]) -> tuple[Relation, ...]` (`suppressed_by is None`인 것만)

- [ ] **Step 1: 실패하는 테스트 작성**

- `test_stem_hap`: 원국 연간 己, 오늘 甲 → `STEM_HAP`
- `test_branch_chung`: 원국 일지 午, 오늘 子 → `CHUNG` at `DAY_BRANCH`
- `test_tamhap_mangchung`: 원국 월지 丑, 일지 午, 오늘 子 → 子丑합이 성립하고, 子午충은 `suppressed_by == BRANCH_HAP`, `active()`에는 충이 없음
- `test_hyeong_group`: 원국에 寅, 오늘 巳 → `HYEONG`
- `test_self_hyeong`: 원국에 辰, 오늘 辰 → `HYEONG`
- `test_time_unknown_skips_hour`: `natal.hour is None`이면 HOUR 자리 관계 없음
- (luck_cycles) `test_year_luck_relations_filled`: 세운 항목에 관계 종류 이름이 채워짐

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/rules/test_relations.py -q` / Expected: FAIL
- [ ] **Step 3: 구현** — 탐합망충은 spec §7.6 정의(오늘 지지가 한 원국 지지와 합하면서 **다른** 원국 지지와 충)를 따릅니다.
- [ ] **Step 4: 통과 확인** — Run: `uv run pytest tests/unit -q -m "not slow" && uv run mypy src` / Expected: PASS
- [ ] **Step 5: 세운 관계 채우기** — `relations_with_natal`에 `find_relations(natal, year_pillar)`의 활성 관계 종류 이름을 넣고, 위 luck_cycles 테스트로 확인합니다.
- [ ] **Step 6: Commit**

```bash
git add core/src/myungri_engine/rules/relations.py core/src/myungri_engine/chart/luck_cycles.py core/tests/unit
git commit -m "feat(core): 합·충·형 판정과 탐합망충, 세운의 원국 관계"
```

---

### Task 10: 날의 성격과 행운 컬러·방향·숫자

**Files:**
- Create: `core/src/myungri_engine/rules/{day_kind,color,direction,number}.py`
- Test: `core/tests/unit/rules/test_day_kind.py`, `test_color.py`, `test_direction.py`, `test_number.py`

**Interfaces:**
- Consumes: Task 8 `YongsinResult`, Task 5 `deity_directions`·`DeityKind`, Task 2 `directions.*`·`HADO`·`BRANCH_CHUNG`(토 방위의 충 판정용).
- Produces:
  - `day_kind.classify_day(day: Pillar, yongsin: YongsinResult, gwiin: frozenset[Branch]) -> DayKind`
  - `color.ElementRole` enum (`YONGSIN, TONGGWAN`), `color.ElementPick(element: Element, role: ElementRole, evidence: tuple[Evidence, ...])`, `color.lucky_element(kind: DayKind, yongsin: YongsinResult) -> ElementPick`
  - `direction.DirectionPick(direction: Direction8, rule_id: str, evidence: tuple[Evidence, ...])`, `direction.lucky_direction(kind: DayKind, day: Pillar, yongsin: YongsinResult, deities: Sequence[tuple[DeityKind, Direction8]]) -> DirectionPick`
  - `number.lucky_number(element: Element, day_stem: Stem) -> int`

- [ ] **Step 1: 실패하는 테스트 작성**

공통 fixture는 겨울생 甲 일간(`yongsin=FIRE, huisin=WOOD, gisin=WATER, tonggwan=WOOD`), 귀인 지지 {丑, 未}입니다. 2026-10-10~16의 실제 일진과 길신 방위로 고정합니다. 10/13·10/14의 길신 방위는 각각 `[西北, 西南, 正东, 正南, 东北]`, `[西南, 西北, 正东, 东北, 正南]`이고(2026-10-10 실행 확인), spec §7.3에 따라 용신(화) 방위 正南이 희신(목) 방위 正东보다 우선합니다.

```python
@pytest.mark.parametrize("ganzhi,kind,direction", [
    ("丁巳", DayKind.YONGSIN_DAY, D.S), ("戊午", DayKind.YONGSIN_DAY, D.S),
    ("己未", DayKind.GWIIN_DAY, D.SW),
    ("庚申", DayKind.ORDINARY_DAY, D.S), ("辛酉", DayKind.ORDINARY_DAY, D.S),   # 양귀 正南(화=용신)이 희신보다 우선
    ("壬戌", DayKind.GISIN_DAY, D.E), ("癸亥", DayKind.GISIN_DAY, D.E),
])
def test_week_simulation(ganzhi, kind, direction, winter_gap, deities_for):
    ...  # classify_day → kind, lucky_direction(..., deities_for(ganzhi)) → direction
```

`deities_for`는 2026-10-10~16 각 날짜의 `la.deity_directions`를 호출합니다. 다른 테스트:
- `test_gisin_overrides_yongsin`: 일진에 용신과 기신이 함께 있으면(예: 丙子) `GISIN_DAY`
- `test_color_roles`: `GISIN_DAY` → `(WOOD, TONGGWAN)`, 나머지 성격 → `(FIRE, YONGSIN)`. 근거에 `FIVE_ELEMENTS_REF["color"]` 포함
- `test_earth_direction`: 용신 토, 오늘 지지 未(丑과 충) → `SW`. 오늘 지지 丑(未와 충) → `NE`. 오늘 지지 子 → `NE`
- `test_ordinary_fallback_to_yongsin`: 길신 방위 중 용신·희신 오행이 없으면 용신 대표 방위
- `test_lucky_number`: 양간은 홀수, 음간은 짝수입니다. `(FIRE, 丙) → 7`, `(FIRE, 丁) → 2`, `(WATER, 壬) → 1`, `(WATER, 癸) → 6`, `(EARTH, 戊) → 5`, `(EARTH, 己) → 10`

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/rules -q -m "not slow" -k "day_kind or color or direction or number or week"` / Expected: FAIL
- [ ] **Step 3: spec §7.1~§7.4 구현**
- [ ] **Step 4: 통과 확인** — 위 명령 + `uv run mypy src` / Expected: PASS
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/rules core/tests/unit/rules
git commit -m "feat(core): 날의 성격 4단계와 행운 컬러·방향·숫자 규칙"
```

---

### Task 11: 집중하기 좋은 시간 (`rules/focus_time.py`)

**Files:**
- Create: `core/src/myungri_engine/rules/focus_time.py`
- Test: `core/tests/unit/rules/test_focus_time.py`

**Interfaces:**
- Consumes: Task 5 `HourSlot`, Task 8 `YongsinResult`, Task 2 `BRANCH_CHUNG`·`BRANCH_HAP`.
- Produces:
  - `focus_time.ScoredSlot(slot: HourSlot, score: int, reasons: tuple[str, ...])` (reasons는 `"gwiin"`, `"yongsin"`, `"huisin"`, `"hap"`)
  - `focus_time.FocusResult(picks: tuple[ScoredSlot, ...], fallback: bool, evidence: tuple[Evidence, ...])`
  - `focus_time.pick_focus_times(slots: Sequence[HourSlot], natal: FourPillars, yongsin: YongsinResult, gwiin: frozenset[Branch]) -> FocusResult`

- [ ] **Step 1: 실패하는 테스트 작성**

- `test_candidates_are_jin_to_sul`: 결과 시진은 항상 辰·巳·午·未·申·酉·戌 중 하나입니다.
- `test_chung_with_natal_excluded`: 원국 일지 子 → 午시는 결과에 없음
- `test_scores`: 귀인 +3, 시진 천간 또는 지지 오행이 용신 +2, 희신 +1, 원국과 육합 +1을 손으로 만든 slot 3개로 확인
- `test_tie_prefers_huangdao_then_earlier`
- `test_second_pick_only_on_equal_score`: 1등과 2등 점수가 같을 때만 2개
- `test_all_excluded_fallback`: 모든 후보가 충으로 빠지면 `fallback is True`, 황도길시 첫 후보 1개
- `test_time_unknown_ignores_hour_branch`: `natal.hour is None`이면 시지 충 판정을 하지 않음

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/rules/test_focus_time.py -q` / Expected: FAIL
- [ ] **Step 3: spec §7.5 구현**
- [ ] **Step 4: 통과 확인** — Run: 위 명령 + `uv run mypy src` / Expected: PASS
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/rules/focus_time.py core/tests/unit/rules/test_focus_time.py
git commit -m "feat(core): 집중하기 좋은 시간 — 원국 충 제외, 귀인·용신·합 가점, 황도길시 보조"
```

---

### Task 12: 해시태그와 총운·가이드 질문 메시지 (`rules/tags.py`, `rules/messages.py`)

**Files:**
- Create: `core/src/myungri_engine/rules/{tags,messages}.py`
- Test: `core/tests/unit/rules/test_tags.py`, `test_messages.py`

**Interfaces:**
- Consumes: Task 9 `Relation`·`active`, Task 6 `shinsal.activated`, Task 1 `ten_god`, Task 10 `DayKind`, Task 2 `message_keys.require`.
- Produces:
  - `tags.TagResult(all_keys: tuple[str, ...], featured: tuple[str, ...], evidence: tuple[Evidence, ...])`
  - `tags.select_tags(natal: FourPillars, day: Pillar, relations: Sequence[Relation], activated: Sequence[Shinsal], kind: DayKind) -> TagResult`
  - `messages.fortune(kind: DayKind, day: Pillar, natal_day_stem: Stem, featured: Sequence[str], yongsin: YongsinResult) -> tuple[Judgment, ...]` (첫 항목이 헤드라인, 대표 태그가 있으면 보조 문장 키를 둘째로)
  - `messages.guide_question(day: Pillar, natal_day_stem: Stem, featured: Sequence[str]) -> Judgment`

- [ ] **Step 1: 실패하는 테스트 작성**

- `test_big_change_on_day_or_month_branch_chung`: 일지와 충 → `"tag.big_change" in featured`
- `test_suppressed_chung_not_tagged`: 탐합망충으로 무효가 된 충은 태그 없음, 대신 `"tag.harmony"`
- `test_ten_god_rush`: 오늘 천간·지지 정기가 모두 재성이고 원국에도 재성이 2개 이상 → `"tag.ten_god_rush.jaeseong"`
- `test_priority_order`: 합충 태그 > 쏠림 태그 > 신살 태그 순서로 `featured` 최대 2개
- `test_tie_bad_first`: 같은 그룹 동점이면 흉 태그 먼저(spec §7.7, 07 §4.3)
- `test_auxiliary_only_when_empty`: 1~3그룹이 비었을 때만 `"tag.yongsin_day"`
- `test_all_keys_superset_of_featured`
- `test_fortune_key`: `YONGSIN_DAY`, 오늘 천간이 일간에게 인성 → 첫 키 `"fortune.yongsin_day.inseong"`, `params["emphasis"] == "POSITIVE"`
- `test_guide_key_fallback`: 대표 태그가 없으면 `"guide.ten_god.<group>"`
- `test_all_emitted_keys_registered`: 무작위 입력 200개에서 나온 모든 키가 `message_keys.ALL_KEYS`에 있음

- [ ] **Step 2: 실패 확인** — Run: `uv run pytest tests/unit/rules/test_tags.py tests/unit/rules/test_messages.py -q` / Expected: FAIL
- [ ] **Step 3: spec §7.7·§7.8 구현**
- [ ] **Step 4: 통과 확인** — Run: 위 명령 + `uv run mypy src` / Expected: PASS
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/rules/tags.py core/src/myungri_engine/rules/messages.py core/tests/unit/rules
git commit -m "feat(core): 해시태그 선택 규칙과 총운·가이드 질문 메시지 키"
```

---

### Task 13: 월간 길흉 (`rules/calendar_luck.py`)

**Files:**
- Create: `core/src/myungri_engine/rules/calendar_luck.py`
- Test: `core/tests/unit/rules/test_calendar_luck.py`

**Interfaces:**
- Consumes: Task 10 `DayKind`, Task 9 `Relation`.
- Produces:
  - `calendar_luck.LuckScore(score: int, level: LuckLevel, breakdown: tuple[tuple[str, int], ...])`
  - `calendar_luck.score_day(kind: DayKind, relations: Sequence[Relation]) -> LuckScore`

- [ ] **Step 1: 실패하는 테스트 작성**

spec §8 점수표의 항목마다 테스트 하나씩 둡니다(귀인 +2, 용신 +2, 합 +1, 기신 -1, 일지·월지 충 -2, 그 밖의 충 -1, 형 -1).
- 경계: 합계 +2 → `GOOD`, +1 → `NEUTRAL`, -2 → `CAUTION`
- `test_suppressed_chung_not_scored`
- `test_breakdown_sums_to_score`

- [ ] **Step 2~4:** 실패 확인 → 구현 → 통과 확인 (`uv run pytest tests/unit/rules/test_calendar_luck.py -q`)
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/rules/calendar_luck.py core/tests/unit/rules/test_calendar_luck.py
git commit -m "feat(core): 월간 캘린더 길흉 점수와 수준"
```

---

### Task 14: proto 계약과 코드 생성

**Files:**
- Create: `proto/buf.yaml`, `proto/myungri/engine/v1/engine.proto`, `core/tools/gen_proto.sh`, `core/src/myungri_engine/_gen/` (생성 코드)
- Delete: `proto/.gitkeep`
- Test: `core/tests/unit/test_proto_generated.py`

**Interfaces:**
- Produces: spec §9의 서비스·메시지 전체입니다. 아래는 spec이 고정하지 않은 세부 결정입니다.
  - 공통 타입: `LocalDate { int32 year; int32 month; int32 day; }`, `LocalTime { int32 hour; int32 minute; }`
  - `Param`: `oneof value { string text; int64 integer; double number; bool flag; }`
  - enum은 proto 관례대로 `<ENUM_NAME>_UNSPECIFIED = 0`을 둡니다. 값 이름은 Task 1 enum 이름에 접두어를 붙인 것입니다. 예: `STEM_GAP`, `BRANCH_JA`, `ELEMENT_FIRE`, `DAY_KIND_YONGSIN_DAY`.
  - `ChartResponse`, `DailyResponse`, `MonthResponse` 필드는 spec §9의 bullet 목록 순서대로 번호를 붙입니다. 각 카드는 `XxxCard { Judgment judgment; <원본 값 필드>; }` 형태입니다.
  - Python 생성 위치: `core/src/myungri_engine/_gen/myungri/engine/v1/engine_pb2.py`, `engine_pb2_grpc.py`, `engine_pb2.pyi`

- [ ] **Step 1: buf 설치와 lint 설정**

Run: `brew install bufbuild/buf/buf && buf --version`
`proto/buf.yaml`: `version: v2`, `lint: use: [STANDARD]`, `breaking: use: [FILE]`.

- [ ] **Step 2: proto 작성 후 lint**

Run: `cd ../proto && buf lint`
Expected: 출력 없음(통과).

- [ ] **Step 3: 생성 스크립트와 실패하는 테스트**

`gen_proto.sh`는 `uv run python -m grpc_tools.protoc -I ../proto --python_out --pyi_out --grpc_python_out`로 `_gen/`에 생성합니다. 테스트 `test_generated_code_up_to_date`는 스크립트를 임시 디렉터리로 실행하고, 커밋된 `_gen/`과 바이트 단위로 비교합니다.
Run: `uv run pytest tests/unit/test_proto_generated.py -q` / Expected: FAIL (`_gen` 없음)

- [ ] **Step 4: 생성 후 통과 확인**

Run: `bash tools/gen_proto.sh && uv run pytest tests/unit/test_proto_generated.py -q`
Expected: PASS. mypy 설정에서 `_gen`은 `exclude`로 뺍니다.

- [ ] **Step 5: Commit**

```bash
git rm -q proto/.gitkeep
git add proto core/tools/gen_proto.sh core/src/myungri_engine/_gen core/tests/unit/test_proto_generated.py core/pyproject.toml
git commit -m "feat(proto): 엔진 gRPC 계약 v1과 Python 생성 코드"
```

---

### Task 15: composers — 화면 단위 조립

**Files:**
- Create: `core/src/myungri_engine/composers/{__init__,chart,daily,month}.py`
- Test: `core/tests/unit/composers/test_chart.py`, `test_daily.py`, `test_month.py`

**Interfaces:**
- Consumes: Task 4~13 전부.
- Produces (도메인 객체, proto 아님):
  - `chart.ChartView(chart: Chart, strength: StrengthResult, yongsin: YongsinResult, yongsin_judgment: Judgment, luck: LuckCycles, notices: tuple[Notice, ...])`, `chart.compose_chart(birth: BirthInput, as_of: date) -> ChartView`
  - `daily.DailyView(date: date, day: Pillar, kind: DayKind, color: tuple[ElementPick, Judgment], direction: tuple[DirectionPick, Judgment], number: tuple[int, Judgment], focus: tuple[FocusResult, Judgment], relations: tuple[Relation, ...], tags: TagResult, fortune: tuple[Judgment, ...], guide: Judgment, notices: tuple[Notice, ...])`, `daily.compose_daily(birth: BirthInput, target: date, current_timezone: str) -> DailyView`
  - `month.MonthDay(info: DayInfo, kind: DayKind, luck: LuckScore, featured_tag: str | None)`, `month.MonthView(days: tuple[MonthDay, ...], notices: tuple[Notice, ...])`, `month.compose_month(birth: BirthInput, year: int, month: int, current_timezone: str) -> MonthView`
  - 각 compose는 원국을 한 번만 계산합니다. `compose_month`는 날짜마다 `classify_day`·`find_relations`·`score_day`만 호출합니다.

- [ ] **Step 1: 실패하는 테스트 작성**

- `test_every_judgment_has_resolvable_evidence`: 세 view의 모든 `Judgment.evidence`가 비어 있지 않고, `loader.validate_refs`를 통과함
- `test_daily_not_determined_by_day_alone`: 같은 날짜, 서로 다른 원국 두 개 → (kind, color, direction, tags) 중 하나 이상이 다름
- `test_month_has_all_days`: 2026년 2월 → 28개, 2028년 2월 → 29개
- `test_chart_notices_propagated`: 자시 출생 → `ZI_HOUR_NEXT_DAY`가 view 레벨 notices에 있음
- `test_daily_target_out_of_range`: `target=date(2100,1,1)` → `OutOfRangeError`

- [ ] **Step 2~4:** 실패 확인 → 구현 → 통과 확인 (`uv run pytest tests/unit/composers -q && uv run mypy src`)
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/composers core/tests/unit/composers
git commit -m "feat(core): 나의 사주·데일리·월간 composer"
```

---

### Task 16: gRPC 서버와 오류 매핑 (`grpc_api/`)

**Files:**
- Create: `core/src/myungri_engine/grpc_api/{__init__,mapping,errors,server}.py`, `core/src/myungri_engine/__main__.py`, `core/src/myungri_engine/version.py`
- Test: `core/tests/integration/test_grpc_server.py`

**Interfaces:**
- Consumes: Task 14 생성 코드, Task 15 compose 함수.
- Produces:
  - `version.ENGINE_VERSION: str` (= 패키지 버전), `version.RULESET_VERSION = "2026.10.0"`
  - `mapping.birth_from_proto(msg) -> BirthInput` (존재하지 않는 양력 날짜·시각, `*_UNSPECIFIED` enum → `InvalidInputError`), `mapping.chart_to_proto(view) -> ChartResponse`, `mapping.daily_to_proto(view) -> DailyResponse`, `mapping.month_to_proto(view) -> MonthResponse`
  - `errors`: `InvalidInputError → INVALID_ARGUMENT`, `OutOfRangeError → OUT_OF_RANGE`, 그 밖 → `INTERNAL`(메시지에 내부 정보를 넣지 않음)
  - `server.serve(port: int = 50051) -> grpc.Server`. 시작할 때 `loader.validate_refs`로 근거 데이터를 검증합니다(spec §11).
  - 실행: `uv run python -m myungri_engine --port 50051`

- [ ] **Step 1: 실패하는 통합 테스트 작성** (in-process 서버, 임의 포트)

- `test_get_chart_roundtrip`: `meta.ruleset_version == "2026.10.0"`, 시주 있음
- `test_get_daily_has_four_cards_and_tags`
- `test_get_month_calendar_day_count`
- `test_invalid_solar_date_is_invalid_argument`: `LocalDate(2023, 2, 29)` → `StatusCode.INVALID_ARGUMENT` (Review Focus 5)
- `test_out_of_range_is_out_of_range`: 1899년 출생 → `StatusCode.OUT_OF_RANGE`
- `test_unspecified_gender_rejected`
- `test_notices_mapped`: 자시 출생 → `NOTICE_CODE_ZI_HOUR_NEXT_DAY`

- [ ] **Step 2~4:** 실패 확인 → 구현 → 통과 확인 (`uv run pytest tests/integration -q && uv run mypy src`)
- [ ] **Step 5: Commit**

```bash
git add core/src/myungri_engine/grpc_api core/src/myungri_engine/__main__.py core/src/myungri_engine/version.py core/tests/integration
git commit -m "feat(core): gRPC 서버, proto 매핑, 오류 상태 코드"
```

---

### Task 17: 불변 조건·정합성·회귀 스냅샷 테스트

**Files:**
- Create: `core/tests/properties/test_invariants.py`, `core/tests/snapshots/test_daily_snapshots.py`, `core/tests/snapshots/__snapshots__/` (syrupy 생성), `core/tests/unit/test_ruleset_version.py`

**Interfaces:**
- Consumes: Task 15 compose 함수, Task 16 `RULESET_VERSION`.

- [ ] **Step 1: 불변 조건 테스트 (hypothesis, `max_examples=300`)**

- `test_day_pillar_advances_one_step`: 임의의 날짜 d에 대해 `day_pillar(d+1)`은 60갑자에서 `day_pillar(d)`의 다음 간지
- `test_deterministic`: 같은 입력이면 `compose_daily` 결과가 같음
- `test_all_judgments_have_evidence`: 임의의 출생 정보와 날짜에서 근거가 비어 있지 않음
- `test_focus_slots_within_candidates`

- [ ] **Step 2: 회귀 스냅샷**

샘플 원국 10개(아래 고정) × 2026-10-01부터 30일의 `compose_daily` 결과를 정렬된 dict로 직렬화해 syrupy 스냅샷으로 저장합니다. 샘플 원국은 다음과 같습니다.
- 자시 출생 1명
- 시간 모름 1명
- 1956년 서머타임 출생 1명
- 1958년 UTC+8:30 출생 1명
- 입춘 직전 출생 1명
- 음력 윤달 출생 1명
- 그 밖의 일반 출생 4명(남녀 각 2명)

Run: `uv run pytest tests/snapshots --snapshot-update -q`, 그다음 `uv run pytest tests/snapshots -q`
Expected: 두 번째 실행이 PASS.

- [ ] **Step 3: 버전 연동 테스트**

`test_ruleset_version.py`는 스냅샷 디렉터리의 해시를 `tests/snapshots/RULESET_HASH`에 `RULESET_VERSION`과 함께 기록해 둡니다. 스냅샷이 바뀌었는데 버전이 그대로면 실패하게 합니다. 실패 메시지는 "스냅샷이 바뀌었으면 version.RULESET_VERSION을 올리세요"입니다.

- [ ] **Step 4: 전체 통과 확인** — Run: `uv run pytest -q -m "not slow"` / Expected: PASS
- [ ] **Step 5: Commit**

```bash
git add core/tests
git commit -m "test(core): 불변 조건·회귀 스냅샷·ruleset 버전 연동 테스트"
```

---

### Task 18: 천문 골든 테스트 (KASI)

**전제:** 공공데이터포털(data.go.kr)에서 한국천문연구원 API 활용 신청이 필요합니다. 대상은 특일 정보의 24절기, 그리고 음양력 정보입니다. 이 신청은 사용자가 해야 합니다. 발급받은 키는 `KASI_SERVICE_KEY` 환경 변수로 넘기며, 저장소에는 넣지 않습니다.

**Files:**
- Create: `core/tools/fetch_kasi.py`, `core/tests/golden/fixtures/kasi_solar_terms.json`, `core/tests/golden/fixtures/kasi_lunar.json`, `core/tests/golden/test_kasi.py`

**Interfaces:**
- Consumes: Task 5 `month_days`, `lunar_to_solar`.

- [ ] **Step 1: 수집 스크립트 작성과 실행**

`fetch_kasi.py --years 1900-2099`는 연도별 24절기 날짜·시각과 매월 1일·15일의 음양력 대응을 받아 위 fixture 2개로 저장합니다. 첫 실행에서 응답 필드 이름과 시각 형식을 확인하고, 스크립트 상단 docstring에 기록합니다.
Run: `KASI_SERVICE_KEY=... uv run python tools/fetch_kasi.py --years 1900-2099`
Expected: 절기 fixture 4800건(200년 × 24), 음력 fixture 4800건(200년 × 12개월 × 2일).

- [ ] **Step 2: 골든 테스트 작성과 실행**

- `test_solar_terms_match_kasi`: 모든 절기 시각이 ±1분 안에서 일치(spec §13.2)
- `test_lunar_conversion_matches_kasi`: 모든 음양력 대응이 일치

Run: `uv run pytest tests/golden/test_kasi.py -q`
Expected: PASS. 불일치가 있으면 원인(시간대 변환 vs 라이브러리 오차)을 조사하고, 해결하지 못한 건은 `tests/golden/fixtures/kasi_known_differences.json`에 사유와 함께 기록합니다. 그 기록은 07 위키 §8에도 요약합니다.

- [ ] **Step 3: Commit**

```bash
git add core/tools/fetch_kasi.py core/tests/golden
git commit -m "test(core): KASI 절기·음양력 골든 테스트"
```

---

### Task 19: 만세력 골든 테스트 (기준 앱)

**Files:**
- Create: `core/tests/golden/fixtures/reference_cases.json`, `core/tests/golden/fixtures/reference_results.json`, `core/tests/golden/test_reference_apps.py`
- Modify: `core/docs/engine-logic-wiki.md` §2.3·§8 (확인 결과 기록)
- Create: `core/docs/decisions.md` (core 내부 결정 로그. 번호는 `C1`부터), `docs/coordination/` 보고 문서 (자시 확인 결과)

**Interfaces:**
- Consumes: Task 15 `compose_chart`.

- [ ] **Step 1: 경계 사례 목록 작성**

`reference_cases.json`에 30건을 넣습니다. 범주별 건수는 다음과 같습니다.
- 자시 경계(표준시 23:29·23:30·01:29·01:30): 4건
- 1954~1961년 UTC+8:30: 3건
- 서머타임 기간: 1950·1956·1987년 각 1건
- 서머타임 중복 시각: 1건
- 서머타임 공백 시각: 1건
- 절입 직전·직후: 입춘·경칩·추분 근처 6건
- 1912년 이전: 2건
- 윤달 출생: 2건
- 시간 모름: 2건
- 일반: 6건

남녀를 섞습니다.

- [ ] **Step 2: 기준 앱 결과 수집 (브라우저)**

포스텔러 만세력(https://pro.forceteller.com/)과 사공만세력(https://mobiwise.kr/)에 기본 설정으로 사례를 입력합니다. 사주팔자 8글자와 대운 시작 나이를 `reference_results.json`에 앱별로 기록합니다. 수집은 사람이 조회하는 수준의 속도로 합니다(사례당 한 번). 두 앱의 **자시 처리 기본 동작**이 D6(자시 통합)과 같은지도 함께 기록합니다.

- [ ] **Step 3: 골든 테스트 작성과 실행**

- `test_pillars_match_reference_apps`: 사례마다 두 앱과 일치. 두 앱끼리 다르거나 엔진과 다르면 `known_differences`(사유·채택 앱)에 있어야 통과
- `test_daeun_start_age_matches`

Run: `uv run pytest tests/golden/test_reference_apps.py -q`
Expected: PASS.

- [ ] **Step 4: 결과 반영**

자시 처리 기본 동작이 D6과 다르면 구현을 멈추고 사용자에게 보고합니다. 07 §2.3의 "확정 조건"에 해당하며, D6은 루트 결정이므로 `docs/coordination/`에 변경 요청도 남깁니다. 같으면 07 §2.3에 "확인 완료(날짜, 앱)"를 적고, `docs/coordination/`에 확인 보고를 남깁니다. `known_differences`의 채택 근거는 `core/docs/decisions.md`에 새 항목으로 기록합니다.

- [ ] **Step 5: Commit**

```bash
git add core/tests/golden core/docs docs/coordination
git commit -m "test(core): 기준 앱(포스텔러·사공만세력) 만세력 골든 테스트와 확인 결과"
```

---

### Task 20: CI와 문서 마무리

**Files:**
- Create: `.github/workflows/core.yml`
- Modify: `core/README.md`, `core/docs/engine-logic-wiki.md` (spec §14 항목), `core/CLAUDE.md` (현재 상태)
- Create: `docs/coordination/` 완료 보고 (엔진 MVP 완료, 제공 계약 버전, 다음 사용자 안내)

- [ ] **Step 1: CI 워크플로 작성**

트리거는 `push`/`pull_request`이고, 경로 필터는 `paths: ["core/**", "proto/**", ".github/workflows/core.yml"]`입니다. 작업 내용은 다음과 같습니다.
1. `astral-sh/setup-uv`
2. `uv sync`
3. `uv run ruff check .`, `uv run mypy src tools`
4. `uv run pytest -q -m "not slow"`
5. `bash tools/gen_proto.sh` 후 `git diff --exit-code src/myungri_engine/_gen`
6. `bufbuild/buf-action`으로 `buf lint`와, PR일 때 `buf breaking --against ".git#branch=main,subdir=proto"`

`slow` 테스트는 `workflow_dispatch`와 매주 스케줄로만 돌립니다.

- [ ] **Step 2: 로컬에서 같은 명령 확인**

Run: `cd core && uv run ruff check . && uv run mypy src tools && uv run pytest -q -m "not slow"`
Expected: 전부 PASS.

- [ ] **Step 3: 문서 반영**

- 07 위키에 spec §14 항목을 반영합니다: §3.1 지장간 비율·등급, §4.2 택일 Phase 2 명시, §4.3 태그 목록, §8 사례 목록.
- 07 위키 버전은 v1.5로 올립니다.
- `core/CLAUDE.md`의 "현재 상태"를 "엔진 MVP 완료"로 고칩니다.
- `docs/coordination/`에 완료 보고를 남깁니다: 제공 계약(`proto/myungri/engine/v1`, `core/message_keys.json`)의 버전과, server가 이제 엔진을 실제로 호출할 수 있다는 안내입니다.
- `core/README.md`에 실행, 테스트, 코드 생성, 보정 스크립트 사용법을 씁니다.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/core.yml core docs/coordination
git commit -m "ci(core): 경로 필터 CI와 엔진 문서 정리 (위키 v1.5)"
```

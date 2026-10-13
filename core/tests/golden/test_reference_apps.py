"""만세력 골든 테스트 (spec 1.2-2, 13.3, D10): 사주팔자·대운 시작 나이를 기준 앱 두 곳과 대조한다.

기준 앱은 포스텔러 만세력(forceteller)과 사공만세력(mobiwise)의 기본 설정이며, 결과는 브라우저로
한 번 수집해 reference_results.json에 두었다. 이 테스트는 네트워크를 쓰지 않는다.

사례·필드마다 엔진과 두 앱이 모두 같아야 한다. 하나라도 다르면 reference_known_differences.json에
그 (사례, 필드)가 엔진·두 앱 값까지 정확히 같게 기록되어 있어야 통과한다. 기록은 있는데 실제로는
모두 같으면 낡은 기록이므로 실패한다.

대운 시작 나이의 비교 단위: 엔진의 `LuckCycles.start_years`(첫 대운 시작 만 나이의 연수, 개월은 버림.
lunar-python getStartYear)와 각 앱 결과 화면의 '대운수' 정수를 비교한다. 사공만세력의 대운수는 만 나이
소수의 정수 부분이라 같은 단위다. 포스텔러의 대운수는 반올림에 가까워 차이가 known_differences에 있다.
"""

import json
from dataclasses import dataclass
from datetime import date, time
from functools import cache
from pathlib import Path

from myungli_engine.calendar_core.birth import BirthInput, LunarDate
from myungli_engine.composers.chart import ChartView, compose_chart
from myungli_engine.domain.enums import Branch, CalendarType, Gender, Stem
from myungli_engine.domain.models import Pillar

FIXTURES = Path(__file__).parent / "fixtures"
APPS = ("forceteller", "mobiwise")
PILLAR_FIELDS = ("year", "month", "day", "hour")
DAEUN_FIELD = "daeun_start"
# 대운 표의 현재 구간 계산에만 쓰이며 사주·대운 시작 나이에는 영향이 없다.
AS_OF = date(2026, 10, 10)

type Value = Pillar | int | None


@dataclass(frozen=True)
class Observed:
    engine: Value
    forceteller: Value
    mobiwise: Value

    @property
    def all_equal(self) -> bool:
        return self.engine == self.forceteller == self.mobiwise


def _load(name: str) -> dict[str, object]:
    data = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
    assert isinstance(data, dict)
    return data


@cache
def _cases() -> dict[str, dict[str, object]]:
    cases = _load("reference_cases.json")["cases"]
    assert isinstance(cases, list)
    return {case["id"]: case for case in cases}


@cache
def _app_results(app: str) -> dict[str, dict[str, object]]:
    apps = _load("reference_results.json")["apps"]
    assert isinstance(apps, dict)
    results = apps[app]["results"]
    assert isinstance(results, dict)
    return results


@cache
def _known_differences() -> dict[tuple[str, str], Observed]:
    entries = _load("reference_known_differences.json")["differences"]
    assert isinstance(entries, list)
    known: dict[tuple[str, str], Observed] = {}
    for entry in entries:
        key = (entry["case_id"], entry["field"])
        assert key not in known, f"중복 기록: {key}"
        assert entry["reason"] and entry["adopted"], f"사유·채택 근거가 비어 있음: {key}"
        known[key] = Observed(
            engine=_parse_value(entry["field"], entry["engine"]),
            forceteller=_parse_value(entry["field"], entry["forceteller"]),
            mobiwise=_parse_value(entry["field"], entry["mobiwise"]),
        )
    return known


def _parse_value(field: str, raw: object) -> Value:
    if raw is None:
        return None
    if field == DAEUN_FIELD:
        assert isinstance(raw, int)
        return raw
    assert isinstance(raw, str) and len(raw) == 2, f"간지 형식이 아님: {raw!r}"
    return Pillar(Stem.from_hanja(raw[0]), Branch.from_hanja(raw[1]))


def _birth_input(case: dict[str, object]) -> BirthInput:
    calendar = CalendarType[str(case["calendar"])]
    year, month, day = (int(part) for part in str(case["date"]).split("-"))
    birth_date = LunarDate(year, month, day) if calendar is CalendarType.LUNAR else date(year, month, day)
    raw_time = case["time"]
    birth_time = None if raw_time is None else time.fromisoformat(str(raw_time))
    longitude = case["longitude"]
    assert longitude is None or isinstance(longitude, float)
    return BirthInput(
        calendar=calendar,
        is_leap_month=bool(case["is_leap_month"]),
        date=birth_date,
        time=birth_time,
        gender=Gender[str(case["gender"])],
        timezone=str(case["timezone"]),
        longitude=longitude,
    )


@cache
def _engine_view(case_id: str) -> ChartView:
    return compose_chart(_birth_input(_cases()[case_id]), AS_OF)


def _engine_value(case_id: str, field: str) -> Value:
    view = _engine_view(case_id)
    if field == DAEUN_FIELD:
        return view.luck.start_years
    pillar: Pillar | None = getattr(view.chart.pillars, field)
    return pillar


def _observe(case_id: str, field: str) -> Observed:
    forceteller, mobiwise = (_parse_value(field, _app_results(app)[case_id][field]) for app in APPS)
    return Observed(engine=_engine_value(case_id, field), forceteller=forceteller, mobiwise=mobiwise)


def _time_unknown(case_id: str) -> bool:
    return _cases()[case_id]["time"] is None


def _assert_matches_known(fields: tuple[str, ...]) -> None:
    actual = {
        (case_id, field): observed
        for case_id in _cases()
        for field in fields
        if not (field == "hour" and _time_unknown(case_id))
        if not (observed := _observe(case_id, field)).all_equal
    }
    expected = {key: value for key, value in _known_differences().items() if key[1] in fields}
    unrecorded = {key: actual[key] for key in actual.keys() - expected.keys()}
    stale = sorted(expected.keys() - actual.keys())
    changed = {
        key: (expected[key], actual[key])
        for key in actual.keys() & expected.keys()
        if actual[key] != expected[key]
    }
    assert not unrecorded, f"known_differences에 없는 차이: {unrecorded}"
    assert not stale, f"실제로는 일치하는 낡은 기록: {stale}"
    assert not changed, f"기록과 값이 다른 차이 (기록, 실제): {changed}"


def test_fixtures_cover_same_cases() -> None:
    case_ids = list(_cases())
    assert len(case_ids) == 30
    for app in APPS:
        assert list(_app_results(app)) == case_ids


def test_known_differences_use_valid_keys() -> None:
    for case_id, field in _known_differences():
        assert case_id in _cases()
        assert field in (*PILLAR_FIELDS, DAEUN_FIELD)
        assert not (field == "hour" and _time_unknown(case_id))


def test_reference_apps_zi_hour_default_matches_d6() -> None:
    """두 앱의 자시 기본 동작이 자시 통합(D6, 엔진 setSect(1))과 같다는 수집 결과."""
    apps = _load("reference_results.json")["apps"]
    assert isinstance(apps, dict)
    for app in APPS:
        assert apps[app]["zi_hour_default"]["mode"] == "ZI_INTEGRATED"


def test_time_unknown_cases_have_no_hour_pillar() -> None:
    for case_id in _cases():
        if _time_unknown(case_id):
            assert _engine_value(case_id, "hour") is None
            assert all(_app_results(app)[case_id]["hour"] is None for app in APPS)


def test_pillars_match_reference_apps() -> None:
    _assert_matches_known(PILLAR_FIELDS)


def test_daeun_start_age_matches() -> None:
    _assert_matches_known((DAEUN_FIELD,))

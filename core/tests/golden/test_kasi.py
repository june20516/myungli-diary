"""천문 골든 테스트 (spec 1.2-1, 13.2): 절기 입절 시각과 양력↔음력 대응을 KASI 데이터와 대조한다.

fixture는 tools/fetch_kasi.py로 받은 KASI 응답이며, 이 테스트는 네트워크를 쓰지 않는다.
KASI가 제공하지 않는 구간과 해결하지 못한 불일치는 kasi_known_differences.json에 사유와 함께 둔다.
테스트는 그 목록과 실제 불일치가 정확히 같을 때만 통과한다(새 불일치도, 낡은 기록도 허용하지 않는다).
"""

import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from functools import cache
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from myungli_engine.calendar_core.lunar_adapter import DayInfo, lunar_to_solar, month_days
from myungli_engine.domain.errors import InvalidInputError

# 음력 검사가 1,800여 개월의 month_days를 계산해 30초 남짓 걸린다.
pytestmark = [pytest.mark.slow, pytest.mark.kasi]

FIXTURES = Path(__file__).parent / "fixtures"
SEOUL = "Asia/Seoul"
SEOUL_ZONE = ZoneInfo(SEOUL)
# KASI 시각은 분 단위다. 엔진 시각(초 포함)과의 차이를 ±1분까지 허용한다 (spec 13.2).
SOLAR_TERM_TOLERANCE = timedelta(minutes=1)

# KASI 한글 절기명 → lunar-python JIE_QI 원문 한자(간체 포함).
JIE_QI_BY_KOREAN_NAME = {
    "소한": "小寒",
    "대한": "大寒",
    "입춘": "立春",
    "우수": "雨水",
    "경칩": "惊蛰",
    "춘분": "春分",
    "청명": "清明",
    "곡우": "谷雨",
    "입하": "立夏",
    "소만": "小满",
    "망종": "芒种",
    "하지": "夏至",
    "소서": "小暑",
    "대서": "大暑",
    "입추": "立秋",
    "처서": "处暑",
    "백로": "白露",
    "추분": "秋分",
    "한로": "寒露",
    "상강": "霜降",
    "입동": "立冬",
    "소설": "小雪",
    "대설": "大雪",
    "동지": "冬至",
}
TERMS_PER_YEAR = 24


@dataclass(frozen=True)
class KasiSolarTerm:
    date: date
    name: str
    kst: datetime


@dataclass(frozen=True)
class KasiLunarDate:
    solar_date: date
    lunar_year: int
    lunar_month: int
    lunar_day: int
    is_leap_month: bool


def _load(name: str) -> dict[str, object]:
    data = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
    assert isinstance(data, dict)
    return data


def _records(fixture: dict[str, object], key: str) -> list[dict[str, object]]:
    records = fixture[key]
    assert isinstance(records, list)
    return records


def _solar_terms() -> list[KasiSolarTerm]:
    terms = []
    for record in _records(_load("kasi_solar_terms.json"), "terms"):
        term_date = date.fromisoformat(str(record["date"]))
        hour, minute = (int(part) for part in str(record["kst"]).split(":"))
        # KASI 원자료에는 "1760"(2019-01-20 대한) 같은 60분 표기가 있다. 반올림 결과로 보고 다음 시 정각으로 읽는다.
        midnight = datetime(term_date.year, term_date.month, term_date.day, tzinfo=SEOUL_ZONE)
        kst = midnight + timedelta(hours=hour, minutes=minute)
        terms.append(KasiSolarTerm(date=term_date, name=str(record["name"]), kst=kst))
    return terms


def _lunar_dates() -> list[KasiLunarDate]:
    return [
        KasiLunarDate(
            solar_date=date.fromisoformat(str(record["solar_date"])),
            lunar_year=int(str(record["lunar_year"])),
            lunar_month=int(str(record["lunar_month"])),
            lunar_day=int(str(record["lunar_day"])),
            is_leap_month=record["is_leap_month"] is True,
        )
        for record in _records(_load("kasi_lunar.json"), "dates")
    ]


def _known_differences(key: str) -> set[str]:
    return {str(record["key"]) for record in _records(_load("kasi_known_differences.json"), key)}


@cache
def _seoul_month(year: int, month: int) -> dict[date, DayInfo]:
    return {day.date: day for day in month_days(year, month, SEOUL)}


def _solar_term_mismatch(term: KasiSolarTerm) -> str | None:
    """불일치 사유를 돌려준다. 일치하면 None."""
    engine_term = _seoul_month(term.date.year, term.date.month)[term.date].solar_term
    if engine_term is None:
        return "엔진은 이 날짜에 절기가 없음"
    engine_name, engine_time = engine_term.name, engine_term.at
    if engine_name != JIE_QI_BY_KOREAN_NAME[term.name]:
        return f"절기 이름 다름: 엔진 {engine_name}"
    difference = abs(engine_time - term.kst)
    if difference > SOLAR_TERM_TOLERANCE:
        return f"시각 차이 {difference}: 엔진 {engine_time.isoformat()}"
    return None


def test_solar_term_fixture_covers_kasi_range() -> None:
    terms = _solar_terms()
    years = {term.date.year for term in terms}
    assert years == set(range(2000, 2029))
    for year in years:
        assert sum(term.date.year == year for term in terms) == TERMS_PER_YEAR
    assert {term.name for term in terms} == set(JIE_QI_BY_KOREAN_NAME)


def test_engine_has_24_solar_terms_per_year() -> None:
    for year in range(2000, 2029):
        engine_terms = [
            day.solar_term
            for month in range(1, 13)
            for day in _seoul_month(year, month).values()
            if day.solar_term is not None
        ]
        assert len(engine_terms) == TERMS_PER_YEAR, year
        assert {term.name for term in engine_terms} == set(JIE_QI_BY_KOREAN_NAME.values()), year


def test_solar_terms_match_kasi() -> None:
    mismatches = {
        f"{term.date.isoformat()} {term.name}": reason
        for term in _solar_terms()
        if (reason := _solar_term_mismatch(term)) is not None
    }
    assert set(mismatches) == _known_differences("solar_terms"), mismatches


def test_lunar_fixture_covers_kasi_range() -> None:
    lunar_dates = _lunar_dates()
    expected = {
        date(year, month, day)
        for year in range(1900, 2051)
        for month in range(1, 13)
        for day in (1, 15)
        if date(year, month, day) >= date(1900, 2, 1)
    }
    assert {entry.solar_date for entry in lunar_dates} == expected


def test_solar_to_lunar_matches_kasi() -> None:
    """양력 → 음력: 그 날짜 DayInfo의 음력 월·일·윤달 여부. DayInfo에 음력 연도는 없다."""
    mismatches = {}
    for entry in _lunar_dates():
        day = _seoul_month(entry.solar_date.year, entry.solar_date.month)[entry.solar_date]
        engine = (day.lunar_month, day.lunar_day, day.is_leap_month)
        kasi = (entry.lunar_month, entry.lunar_day, entry.is_leap_month)
        if engine != kasi:
            mismatches[entry.solar_date.isoformat()] = f"엔진 {engine} / KASI {kasi}"
    assert set(mismatches) == _known_differences("solar_to_lunar"), mismatches


def test_lunar_to_solar_matches_kasi() -> None:
    """음력 → 양력: KASI 음력(연도 포함)을 엔진으로 되돌리면 원래 양력 날짜가 나와야 한다."""
    mismatches = {}
    for entry in _lunar_dates():
        try:
            engine_date = lunar_to_solar(
                entry.lunar_year, entry.lunar_month, entry.lunar_day, entry.is_leap_month
            )
        except InvalidInputError as error:
            # 한국과 중국 음력의 달 길이·윤달이 다르면 KASI 날짜가 엔진 역법에 없을 수 있다.
            mismatches[entry.solar_date.isoformat()] = f"엔진에 없는 음력 날짜: {error}"
            continue
        if engine_date != entry.solar_date:
            mismatches[entry.solar_date.isoformat()] = f"엔진 {engine_date.isoformat()}"
    assert set(mismatches) == _known_differences("lunar_to_solar"), mismatches

"""lunar-python 어댑터. 엔진에서 lunar_python을 import하는 유일한 모듈이다 (D9).

lunar-python은 타입 정보가 없으므로, 반환값은 이 모듈 경계에서 즉시 str/int로 바꾸고 enum으로 매핑한다.
lunar-python의 절기 시각은 UTC+8 벽시계 기준이다 (spec 4.1-2).
"""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from enum import Enum, auto
from functools import cache
from typing import TYPE_CHECKING, Final
from zoneinfo import ZoneInfo

from lunar_python import EightChar, Lunar, Solar
from lunar_python.util import LunarUtil

from myungri_engine.calendar_core import korean_lunar
from myungri_engine.calendar_core.time_basis import (
    SOLAR_TERM_TIMEZONE,
    load_zone,
    longitude_correction,
    standard_offset_hours,
)
from myungri_engine.constants.longitudes import representative_longitude
from myungri_engine.domain.enums import Branch, Direction8, Gender, Stem, TwelveStage
from myungri_engine.domain.models import FourPillars, Pillar

if TYPE_CHECKING:
    # birth가 이 모듈을 import하므로, BirthMoment는 타입 검사에서만 import한다.
    from myungri_engine.calendar_core.birth import BirthMoment

LUCK_CYCLE_COUNT = 10
LUCK_SECT = 1  # 3일 = 1년, 1일 = 4개월, 1시진 = 10일 (spec 5.3)
ZI_HOUR_UNIFIED_SECT = 1  # 자시 통합: 23시 이후는 다음 날 일주 (D6)
SLOT_HOURS = 2
HUANGDAO_LUCKY = "吉"

_TWELVE_STAGE_BY_HANJA: Final[dict[str, TwelveStage]] = {
    "长生": TwelveStage.JANGSAENG,
    "沐浴": TwelveStage.MOKYOK,
    "冠带": TwelveStage.GWANDAE,
    "临官": TwelveStage.GEONROK,
    "帝旺": TwelveStage.JEWANG,
    "衰": TwelveStage.SOE,
    "病": TwelveStage.BYEONG,
    "死": TwelveStage.SA,
    "墓": TwelveStage.MYO,
    "绝": TwelveStage.JEOL,
    "胎": TwelveStage.TAE,
    "养": TwelveStage.YANG,
}

_DIRECTION_BY_DESC: Final[dict[str, Direction8]] = {
    "正北": Direction8.N,
    "东北": Direction8.NE,
    "正东": Direction8.E,
    "东南": Direction8.SE,
    "正南": Direction8.S,
    "西南": Direction8.SW,
    "正西": Direction8.W,
    "西北": Direction8.NW,
}

# lunar-python 절기표는 이웃 해의 절기를 병음 키로 담는다. JIE_QI 원문 한자로 되돌린다.
_PINYIN_TERM_NAMES: Final[dict[str, str]] = {
    "DONG_ZHI": "冬至",
    "XIAO_HAN": "小寒",
    "DA_HAN": "大寒",
    "LI_CHUN": "立春",
    "YU_SHUI": "雨水",
    "JING_ZHE": "惊蛰",
    "DA_XUE": "大雪",
}


class DeityKind(Enum):
    """길신 방위의 종류: 희신·복신·재신·양귀·음귀 (spec 7.3)."""

    XI = auto()
    FU = auto()
    CAI = auto()
    YANG_GUI = auto()
    YIN_GUI = auto()


@dataclass(frozen=True, slots=True)
class HourSlot:
    """그날의 한 시진. start/end는 시간대가 붙은 현지 시각이며 end는 포함하지 않는다."""

    branch: Branch
    pillar: Pillar
    start: datetime
    end: datetime
    huangdao_lucky: bool


@dataclass(frozen=True, slots=True)
class DayInfo:
    """월간 캘린더의 하루. solar_term은 (JIE_QI 원문 한자, 현재 시간대의 입절 시각)."""

    date: date
    pillar: Pillar
    lunar_month: int
    lunar_day: int
    is_leap_month: bool
    solar_term: tuple[str, datetime] | None


# --- 음력 변환 ---


def lunar_to_solar(year: int, month: int, day: int, is_leap_month: bool) -> date:
    """한국 음력(KASI 기준) 날짜를 양력으로 바꾼다. 그해에 없는 윤달이나 없는 날짜면 InvalidInputError."""
    return korean_lunar.lunar_to_solar(year, month, day, is_leap_month)


# --- 사주팔자 ---


def pillars_for(moment: BirthMoment) -> FourPillars:
    """연주·월주는 절기 비교용 시각, 일주·시주는 보정 시각 + 자시 통합으로 정한다 (spec 5.1)."""
    term_lunar = _lunar_at(moment.solar_term_wallclock)
    year = _pillar(str(term_lunar.getYearGanExact()), str(term_lunar.getYearZhiExact()))
    month = _pillar(str(term_lunar.getMonthGanExact()), str(term_lunar.getMonthZhiExact()))

    if not moment.time_known:
        return FourPillars(year=year, month=month, day=day_pillar(moment.solar_date), hour=None)

    eight_char = _lunar_at(moment.corrected_local).getEightChar()
    eight_char.setSect(ZI_HOUR_UNIFIED_SECT)
    day = _pillar(str(eight_char.getDayGan()), str(eight_char.getDayZhi()))
    hour = _pillar(str(eight_char.getTimeGan()), str(eight_char.getTimeZhi()))
    return FourPillars(year=year, month=month, day=day, hour=hour)


def hidden_stems(branch: Branch) -> tuple[Stem, ...]:
    """지장간. 첫 항목이 정기다 (spec 5.2)."""
    return tuple(Stem.from_hanja(str(hanja)) for hanja in LunarUtil.ZHI_HIDE_GAN[branch.hanja])


def twelve_stage(day_stem: Stem, branch: Branch) -> TwelveStage:
    return _twelve_stage_table()[(day_stem, branch)]


def day_gongmang(day: Pillar) -> frozenset[Branch]:
    """일주가 속한 순(旬)의 공망 두 지지 (spec 5.4)."""
    xun_kong = str(LunarUtil.getXunKong(day.stem.hanja + day.branch.hanja))
    return frozenset(Branch.from_hanja(hanja) for hanja in xun_kong)


# --- 일진·길신 방위 ---


def day_pillar(civil_date: date) -> Pillar:
    """그 날짜 현지 정오 기준의 일진 (spec 4.4)."""
    lunar = _lunar_at_noon(civil_date)
    return _pillar(str(lunar.getDayGan()), str(lunar.getDayZhi()))


def deity_directions(civil_date: date) -> tuple[tuple[DeityKind, Direction8], ...]:
    """그날의 길신 방위를 희신·복신·재신·양귀·음귀 순서로 돌려준다 (spec 7.3)."""
    lunar = _lunar_at_noon(civil_date)
    descriptions = (
        (DeityKind.XI, str(lunar.getDayPositionXiDesc())),
        (DeityKind.FU, str(lunar.getDayPositionFuDesc())),
        (DeityKind.CAI, str(lunar.getDayPositionCaiDesc())),
        (DeityKind.YANG_GUI, str(lunar.getDayPositionYangGuiDesc())),
        (DeityKind.YIN_GUI, str(lunar.getDayPositionYinGuiDesc())),
    )
    return tuple((kind, _DIRECTION_BY_DESC[desc]) for kind, desc in descriptions)


# --- 시진 ---


def hour_slots(civil_date: date, current_timezone: str) -> tuple[HourSlot, ...]:
    """그날 일진의 12시진(자시~해시).

    자시 통합(D6)에 따라 그날 일진의 자시는 보정 시각으로 전날 23:00에 시작한다. 그래서 12시진은
    보정 시각 [전날 23:00, 그날 23:00)을 덮는다. 경계는 그 시간대 대표 경도의 지방평균시를
    거꾸로 적용해 현지 시각으로 바꾼다 (spec 7.5-1). 서울 진시는 07:30~09:30이다.
    """
    zone = load_zone(current_timezone)
    correction = _longitude_correction(civil_date, current_timezone, zone)
    zi_start = datetime.combine(civil_date, time(0)) - timedelta(hours=SLOT_HOURS // 2)

    slots: list[HourSlot] = []
    for branch in Branch:
        corrected_start = zi_start + timedelta(hours=branch.index * SLOT_HOURS)
        corrected_end = corrected_start + timedelta(hours=SLOT_HOURS)
        # 자시는 그날 00시(자시 통합에서 그날 일주)로, 나머지는 각 시진의 시작 시각으로 lunar-python에 묻는다.
        lookup_hour = 0 if branch is Branch.JA else corrected_start.hour
        lunar = _lunar_at(datetime.combine(civil_date, time(lookup_hour)))
        pillar = _pillar(str(lunar.getTimeGan()), str(lunar.getTimeZhi()))
        if pillar.branch is not branch:
            raise AssertionError(f"시진 지지가 어긋났습니다: {branch} != {pillar.branch}")
        slots.append(
            HourSlot(
                branch=branch,
                pillar=pillar,
                start=_corrected_to_local(corrected_start, correction, zone),
                end=_corrected_to_local(corrected_end, correction, zone),
                huangdao_lucky=str(lunar.getTimeTianShenLuck()) == HUANGDAO_LUCKY,
            )
        )
    return tuple(slots)


# --- 월간 정보 ---


def month_days(year: int, month: int, current_timezone: str) -> tuple[DayInfo, ...]:
    """한 달의 날짜별 일진·음력 날짜·절기(현재 시간대 기준 그 날짜에 든 것만) (spec 8).

    음력 날짜는 한국 음력(korean_lunar)이다. lunar-python의 중국 음력은 쓰지 않는다.
    """
    zone = load_zone(current_timezone)
    last_day = calendar.monthrange(year, month)[1]
    terms_by_date = _solar_terms_by_local_date(date(year, month, 1), date(year, month, last_day), zone)

    days: list[DayInfo] = []
    for day_number in range(1, last_day + 1):
        civil_date = date(year, month, day_number)
        lunar_date = korean_lunar.solar_to_lunar(civil_date)
        days.append(
            DayInfo(
                date=civil_date,
                pillar=day_pillar(civil_date),
                lunar_month=lunar_date.month,
                lunar_day=lunar_date.day,
                is_leap_month=lunar_date.is_leap_month,
                solar_term=terms_by_date.get(civil_date),
            )
        )
    return tuple(days)


# --- 절입 ---


def jie_times_around(utc: datetime) -> tuple[datetime, datetime]:
    """주어진 절대 시각 직전과 직후의 절입(節) 시각을 UTC로 돌려준다."""
    lunar = _lunar_at(_to_solar_term_wallclock(utc))
    previous_jie = _solar_term_to_utc(lunar.getPrevJie().getSolar())
    next_jie = _solar_term_to_utc(lunar.getNextJie().getSolar())
    return previous_jie, next_jie


def nearest_solar_term_minutes(utc: datetime) -> float:
    """가장 가까운 절입(節, 월주가 바뀌는 12절기)과의 차이를 분 단위 절댓값으로 돌려준다.

    中氣는 월주를 바꾸지 않으므로 절입 안내(spec 4.3) 대상에서 뺀다.
    """
    return min(abs((jie - utc).total_seconds()) / 60 for jie in jie_times_around(utc))


# --- 대운 ---


def luck_cycles_raw(moment: BirthMoment, gender: Gender) -> tuple[int, int, tuple[Pillar, ...]]:
    """대운 시작 연수·개월과 대운 간지 10개 (spec 5.3). 시작 전 구간(간지 없음)은 뺀다."""
    eight_char = EightChar.fromLunar(_lunar_at(moment.solar_term_wallclock))
    lunar_gender = 1 if gender is Gender.MALE else 0  # lunar-python 규약: 1 = 남, 0 = 여
    yun = eight_char.getYun(lunar_gender, LUCK_SECT)
    da_yun = yun.getDaYun(LUCK_CYCLE_COUNT + 1)[1:]
    cycles = tuple(_pillar_from_ganzhi(str(cycle.getGanZhi())) for cycle in da_yun)
    return int(yun.getStartYear()), int(yun.getStartMonth()), cycles


# --- 내부 도우미 ---


def _pillar(stem_hanja: str, branch_hanja: str) -> Pillar:
    return Pillar(Stem.from_hanja(stem_hanja), Branch.from_hanja(branch_hanja))


def _pillar_from_ganzhi(ganzhi: str) -> Pillar:
    if len(ganzhi) != 2:
        raise ValueError(f"간지 형식이 아닙니다: {ganzhi!r}")
    return _pillar(ganzhi[0], ganzhi[1])


def _lunar_at(wallclock: datetime) -> Lunar:
    solar = Solar.fromYmdHms(
        wallclock.year, wallclock.month, wallclock.day, wallclock.hour, wallclock.minute, wallclock.second
    )
    return solar.getLunar()


def _lunar_at_noon(civil_date: date) -> Lunar:
    return _lunar_at(datetime.combine(civil_date, time(12)))


@cache
def _twelve_stage_table() -> dict[tuple[Stem, Branch], TwelveStage]:
    """lunar-python EightChar의 12운성(시주 기준)으로 10천간 x 12지지 표를 만든다.

    일간이 원하는 천간인 날을 찾고, 원하는 지지의 시각으로 시주 12운성(getTimeDiShi)을 묻는다.
    """
    base = date(2000, 1, 1)
    table: dict[tuple[Stem, Branch], TwelveStage] = {}
    for offset in range(len(Stem)):
        civil_date = base + timedelta(days=offset)
        day_stem = day_pillar(civil_date).stem
        for branch in Branch:
            hour = 0 if branch is Branch.JA else branch.index * SLOT_HOURS - 1
            eight_char = _lunar_at(datetime.combine(civil_date, time(hour))).getEightChar()
            eight_char.setSect(ZI_HOUR_UNIFIED_SECT)
            if Branch.from_hanja(str(eight_char.getTimeZhi())) is not branch:
                raise AssertionError(f"12운성 표 생성 중 시지가 어긋났습니다: {branch}")
            table[(day_stem, branch)] = _TWELVE_STAGE_BY_HANJA[str(eight_char.getTimeDiShi())]
    return table


def _longitude_correction(civil_date: date, timezone_name: str, zone: ZoneInfo) -> timedelta:
    """그 날짜 정오의 표준 오프셋으로 대표 경도를 정하고, 보정 시각 = UTC + 이 값이다."""
    noon_utc = datetime.combine(civil_date, time(12), tzinfo=zone).astimezone(UTC)
    longitude = representative_longitude(timezone_name, standard_offset_hours(noon_utc, zone))
    return longitude_correction(longitude)


def _corrected_to_local(corrected: datetime, correction: timedelta, zone: ZoneInfo) -> datetime:
    return (corrected - correction).replace(tzinfo=UTC).astimezone(zone)


def _to_solar_term_wallclock(utc: datetime) -> datetime:
    return utc.astimezone(SOLAR_TERM_TIMEZONE).replace(tzinfo=None)


def _solar_term_to_utc(solar: Solar) -> datetime:
    wallclock = datetime(
        int(solar.getYear()),
        int(solar.getMonth()),
        int(solar.getDay()),
        int(solar.getHour()),
        int(solar.getMinute()),
        int(solar.getSecond()),
        tzinfo=SOLAR_TERM_TIMEZONE,
    )
    return wallclock.astimezone(UTC)


def _term_name(key: str) -> str:
    name = _PINYIN_TERM_NAMES.get(key, key)
    if name not in Lunar.JIE_QI:
        raise ValueError(f"알 수 없는 절기 이름: {key!r}")
    return name


def _solar_terms_by_local_date(first: date, last: date, zone: ZoneInfo) -> dict[date, tuple[str, datetime]]:
    """first~last 사이 현지 날짜에 든 절기. 시간대 변환으로 날짜가 넘어가는 경우를 위해 양 끝 절기표를 합친다."""
    terms: dict[date, tuple[str, datetime]] = {}
    for anchor in (first, last):
        table = _lunar_at_noon(anchor).getJieQiTable()
        for key, solar in table.items():
            local_time = _solar_term_to_utc(solar).astimezone(zone)
            if first <= local_time.date() <= last:
                terms[local_time.date()] = (_term_name(str(key)), local_time)
    return terms

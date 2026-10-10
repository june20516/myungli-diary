"""신강·신약 임계값과 조후 기준값 산출 (spec 6.1, 6.2, 13.6).

사용: uv run python tools/calibrate_strength.py --write | --check

표본: random.Random(SAMPLE_SEED)로 1900-01-31 ~ 2099-12-31 날짜와 00:00~23:59 시각을 균등하게 뽑고,
출생지는 Asia/Seoul로 한다.
백분위: statistics.quantiles(data, n=100, method="inclusive")의 p번째 절단점(p = 1..99).
        정렬된 값 사이를 선형 보간하므로 같은 표본이면 결과가 결정적이다.
조후 기준: 월지가 巳·午·未인 표본의 화 비중, 亥·子·丑인 표본의 수 비중에서 상위 40% 경계 = 60 백분위.
반올림: 소수점 아래 ROUND_DIGITS 자리. --check도 같은 반올림으로 비교한다.
"""

from __future__ import annotations

import argparse
import random
import statistics
import sys
import time
from datetime import date, timedelta
from datetime import time as day_time
from pathlib import Path

from myungri_engine.calendar_core.birth import BirthInput, resolve_birth_moment
from myungri_engine.calendar_core.lunar_adapter import pillars_for
from myungri_engine.constants import calibration
from myungri_engine.domain.enums import Branch, CalendarType, Element, Gender
from myungri_engine.rules.strength import element_weights, strength_score

ROUND_DIGITS = 4
FIRST_DATE = date(1900, 1, 31)
LAST_DATE = date(2099, 12, 31)
MINUTES_PER_DAY = 24 * 60
STRENGTH_PERCENTILES = (15, 40, 60, 85)
JOHU_PERCENTILE = 60
SUMMER_BRANCHES = frozenset({Branch.SA, Branch.O, Branch.MI})
WINTER_BRANCHES = frozenset({Branch.HAE, Branch.JA, Branch.CHUK})
CALIBRATION_PATH = (
    Path(__file__).resolve().parents[1] / "src" / "myungri_engine" / "constants" / "calibration.py"
)

Constants = tuple[tuple[float, float, float, float], float, float]


def percentile(values: list[float], p: int) -> float:
    """p번째 백분위 (1~99). statistics.quantiles(n=100, method="inclusive")의 절단점."""
    return statistics.quantiles(values, n=100, method="inclusive")[p - 1]


def sample_births(seed: int, size: int) -> list[BirthInput]:
    rng = random.Random(seed)
    day_count = (LAST_DATE - FIRST_DATE).days + 1
    births: list[BirthInput] = []
    for _ in range(size):
        birth_date = FIRST_DATE + timedelta(days=rng.randrange(day_count))
        minute = rng.randrange(MINUTES_PER_DAY)
        births.append(
            BirthInput(
                calendar=CalendarType.SOLAR,
                is_leap_month=False,
                date=birth_date,
                time=day_time(minute // 60, minute % 60),
                gender=Gender.MALE,
                timezone="Asia/Seoul",
                longitude=None,
            )
        )
    return births


def compute_constants(seed: int, size: int) -> Constants:
    scores: list[float] = []
    summer_fire: list[float] = []
    winter_water: list[float] = []
    for birth in sample_births(seed, size):
        pillars = pillars_for(resolve_birth_moment(birth))
        weights = element_weights(pillars)
        scores.append(strength_score(pillars, weights))
        total = sum(weights.values())
        if pillars.month.branch in SUMMER_BRANCHES:
            summer_fire.append(weights[Element.FIRE] / total)
        elif pillars.month.branch in WINTER_BRANCHES:
            winter_water.append(weights[Element.WATER] / total)
    t1, t2, t3, t4 = (round(percentile(scores, p), ROUND_DIGITS) for p in STRENGTH_PERCENTILES)
    return (
        (t1, t2, t3, t4),
        round(percentile(summer_fire, JOHU_PERCENTILE), ROUND_DIGITS),
        round(percentile(winter_water, JOHU_PERCENTILE), ROUND_DIGITS),
    )


def current_constants() -> Constants:
    thresholds = tuple(round(v, ROUND_DIGITS) for v in calibration.STRENGTH_THRESHOLDS)
    assert len(thresholds) == 4
    return (
        (thresholds[0], thresholds[1], thresholds[2], thresholds[3]),
        round(calibration.JOHU_SUMMER_FIRE_SHARE, ROUND_DIGITS),
        round(calibration.JOHU_WINTER_WATER_SHARE, ROUND_DIGITS),
    )


def render_module(constants: Constants) -> str:
    thresholds, summer_fire, winter_water = constants
    return (
        '"""분포 보정 상수. tools/calibrate_strength.py --write 가 생성한다. 직접 고치지 않는다."""\n'
        "\n"
        f"SAMPLE_SEED = {calibration.SAMPLE_SEED}\n"
        f"SAMPLE_SIZE = {calibration.SAMPLE_SIZE}\n"
        f"STRENGTH_THRESHOLDS: tuple[float, float, float, float] = {thresholds!r}\n"
        f"JOHU_SUMMER_FIRE_SHARE = {summer_fire!r}\n"
        f"JOHU_WINTER_WATER_SHARE = {winter_water!r}\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="상수 파일을 갱신한다")
    mode.add_argument("--check", action="store_true", help="상수가 산출값과 다르면 exit 1")
    args = parser.parse_args()

    started = time.monotonic()
    computed = compute_constants(calibration.SAMPLE_SEED, calibration.SAMPLE_SIZE)
    elapsed = time.monotonic() - started
    print(f"thresholds={computed[0]} johu_summer_fire={computed[1]} johu_winter_water={computed[2]}")
    print(f"elapsed={elapsed:.1f}s")

    if args.write:
        CALIBRATION_PATH.write_text(render_module(computed), encoding="utf-8")
        print(f"wrote {CALIBRATION_PATH}")
        return 0
    if current_constants() != computed:
        print(f"MISMATCH: 현재 상수 {current_constants()} != 산출값 {computed}", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

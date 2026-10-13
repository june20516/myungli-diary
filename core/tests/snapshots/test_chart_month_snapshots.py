"""회귀 스냅샷 (spec 13.7): 샘플 원국 4개의 원국·대운·세운(as_of 고정)과 2026년 10월 월간 결과.

데일리 스냅샷이 덮지 않는 대운·세운·월간 출력의 변경도 RULESET_VERSION 신호를 주게 한다.
"""

from datetime import date

import pytest
from snapshot_samples import SAMPLE_BIRTHS, SEOUL, to_plain
from syrupy.assertion import SnapshotAssertion

from myungli_engine.composers.chart import compose_chart
from myungli_engine.composers.month import compose_month

AS_OF = date(2026, 10, 10)
MONTH_YEAR, MONTH = 2026, 10
SNAPSHOT_BIRTHS = ("time_unknown", "lunar_leap_month", "general_male_1", "general_female_2")


@pytest.mark.parametrize("name", SNAPSHOT_BIRTHS)
def test_chart_regression(name: str, snapshot: SnapshotAssertion) -> None:
    assert to_plain(compose_chart(SAMPLE_BIRTHS[name], AS_OF)) == snapshot


@pytest.mark.parametrize("name", SNAPSHOT_BIRTHS)
def test_month_regression(name: str, snapshot: SnapshotAssertion) -> None:
    assert to_plain(compose_month(SAMPLE_BIRTHS[name], MONTH_YEAR, MONTH, SEOUL)) == snapshot

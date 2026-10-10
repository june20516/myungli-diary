"""회귀 스냅샷 (spec 13.7): 고정 원국 10개 x 2026-10-01부터 30일의 데일리 결과."""

from datetime import date, timedelta

import pytest
from snapshot_samples import SAMPLE_BIRTHS, SEOUL, to_plain
from syrupy.assertion import SnapshotAssertion

from myungri_engine.composers.daily import compose_daily
from myungri_engine.domain.enums import Gender

START = date(2026, 10, 1)
DAY_COUNT = 30


@pytest.mark.parametrize("name", list(SAMPLE_BIRTHS))
def test_daily_regression(name: str, snapshot: SnapshotAssertion) -> None:
    birth = SAMPLE_BIRTHS[name]
    thirty_days = {
        (START + timedelta(days=offset)).isoformat(): to_plain(
            compose_daily(birth, START + timedelta(days=offset), SEOUL)
        )
        for offset in range(DAY_COUNT)
    }
    assert thirty_days == snapshot


def test_to_plain_is_deterministic_and_sorted() -> None:
    plain = to_plain({"b": Gender.MALE, "a": (date(2026, 10, 1), None)})
    assert plain == {"a": ["2026-10-01", None], "b": "MALE"}
    assert list(plain) == ["a", "b"]


def test_to_plain_rejects_unknown_type() -> None:
    with pytest.raises(TypeError):
        to_plain(object())

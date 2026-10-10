from datetime import date

import pytest

from myungri_engine.calendar_core.birth import BirthInput
from myungri_engine.composers.chart import compose_chart
from myungri_engine.domain.enums import NoticeCode
from myungri_engine.domain.errors import OutOfRangeError


def test_chart_notices_propagated(zi_hour_birth: BirthInput) -> None:
    view = compose_chart(zi_hour_birth, date(2026, 10, 10))
    assert NoticeCode.ZI_HOUR_NEXT_DAY in {notice.code for notice in view.notices}


def test_chart_notices_merge_luck_notices_without_duplicates(unknown_time_birth: BirthInput) -> None:
    view = compose_chart(unknown_time_birth, date(2026, 10, 10))
    codes = [notice.code for notice in view.notices]
    assert NoticeCode.TIME_UNKNOWN in codes
    assert NoticeCode.DAYUN_START_APPROXIMATE in codes
    assert len(codes) == len(set(view.notices))


def test_yongsin_judgment_key_follows_method(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    assert view.yongsin_judgment.message_key == f"yongsin.method.{view.yongsin.method.name.lower()}"
    assert view.yongsin_judgment.params["yongsin"] == view.yongsin.yongsin.name
    assert view.yongsin_judgment.evidence == view.yongsin.evidence


def test_chart_as_of_out_of_range(spring_birth: BirthInput) -> None:
    with pytest.raises(OutOfRangeError):
        compose_chart(spring_birth, date(2100, 1, 1))

# 샘플 원국으로 엔진이 내는 근거가 선언 목록과 같은지 검사한다 (#130)
from collections import defaultdict
from collections.abc import Iterator
from datetime import date, timedelta

import pytest
from snapshot_samples import SAMPLE_BIRTHS, SEOUL

from myungli_engine.composers.chart import compose_chart
from myungli_engine.composers.daily import compose_daily
from myungli_engine.composers.month import compose_month
from myungli_engine.constants.evidence_rules import RULE_DETAIL_KEYS, RULES_WITHOUT_SOURCE
from myungli_engine.domain.models import Evidence
from myungli_engine.references.sources import source_catalog

pytestmark = pytest.mark.contract

# tags/gwiin_day: 귀인의 날은 천을귀인 신살 태그가 늘 함께 붙어 보조 태그가 나오지 않는다. tests/unit/rules/test_tags.py가 다룬다.
RULES_NOT_IN_SAMPLES = frozenset({"tags/gwiin_day"})
AS_OF = date(2026, 10, 10)
DAILY_START = date(2026, 1, 1)
DAILY_DAYS = 20  # 데일리 규칙은 15일 안에 모두 나온다(tags/ten_god_rush가 마지막, 2026-11-05 측정). 여유를 둔다
MONTH = (2026, 10)  # 월간 근거는 calendar/score 하나라 한 달로 충분하다


def _sample_evidence() -> Iterator[Evidence]:
    for birth in SAMPLE_BIRTHS.values():
        chart = compose_chart(birth, AS_OF)
        yield from chart.yongsin_judgment.evidence
        for reading in chart.personal_readings:
            yield from reading.judgment.evidence
        for offset in range(DAILY_DAYS):
            daily = compose_daily(birth, DAILY_START + timedelta(days=offset), SEOUL)
            yield from daily.tags.evidence
            yield from daily.direction[0].evidence
            for judgment in (
                *(judgment for _, judgment in daily.colors),
                daily.direction[1],
                daily.number[1],
                *(judgment for _, judgment in daily.focus),
                *daily.fortune,
                daily.guide,
                *daily.guide_candidates,
            ):
                yield from judgment.evidence
        for day in compose_month(birth, *MONTH, SEOUL).days:
            yield from day.judgment.evidence


def test_sample_evidence_matches_declared_rules_and_sources() -> None:
    detail_keys: dict[str, set[str]] = defaultdict(set)
    catalog = source_catalog()
    for evidence in _sample_evidence():
        if evidence.source_ref:
            assert evidence.source_ref in catalog, evidence.rule_id
        else:
            assert evidence.rule_id in RULES_WITHOUT_SOURCE, evidence.rule_id
        detail_keys[evidence.rule_id].update(evidence.detail)

    assert set(detail_keys) == set(RULE_DETAIL_KEYS) - RULES_NOT_IN_SAMPLES
    for rule_id, keys in detail_keys.items():
        assert sorted(keys) == list(RULE_DETAIL_KEYS[rule_id]), rule_id

"""원국 십성 묶음 개수. 해시태그 쏠림과 개인 해석이 같은 기준을 쓴다."""

from __future__ import annotations

from myungri_engine.calendar_core.lunar_adapter import hidden_stems
from myungri_engine.domain.enums import TenGodGroup
from myungri_engine.domain.models import FourPillars
from myungri_engine.domain.ten_gods import ten_god


def natal_group_count(natal: FourPillars, group: TenGodGroup) -> int:
    """일간을 뺀 천간과 각 지지 정기 중 해당 묶음의 개수. 시주를 모르면 제외한다."""
    day_stem = natal.day.stem
    pillars = [natal.year, natal.month, natal.day] + ([natal.hour] if natal.hour else [])
    stems = [natal.year.stem, natal.month.stem] + ([natal.hour.stem] if natal.hour else [])
    stems += [hidden_stems(pillar.branch)[0] for pillar in pillars]
    return sum(ten_god(day_stem, stem).group is group for stem in stems)

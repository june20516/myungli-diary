"""택일 덕일 (D124 ⑤). 그날이 속한 달(월건) 기준의 천덕일, 월덕일이다. 모두에게 같다(D13의 예외).

원전은 『欽定協紀辨方書』 卷五 「天徳」(堪輿經 "天徳者正月丁二月坤…十二月庚"), 「月徳」(歴例 "月徳者正五九月在丙…")이다.
2, 5, 8, 11월(子午卯酉月)의 천덕은 괘(坤乾艮巽, 방위)로 적혀 있어 날이 없다(원문대로, 지지로 바꿔 읽지 않음).
천덕합, 월덕합은 넣지 않는다.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungli_engine.constants.evidence_rules import require_rule
from myungli_engine.constants.message_keys import require
from myungli_engine.constants.shinsal import WOLDEOK
from myungli_engine.domain.enums import Branch, DayVirtue, Stem
from myungli_engine.domain.models import Evidence, Judgment, Pillar
from myungli_engine.references.loader import DAY_VIRTUE_REF

# 월건 → 천덕 천간. 子午卯酉月은 괘라 없다.
CHEONDEOK_DAY_STEM: Final[Mapping[Branch, Stem]] = {
    Branch.from_hanja(month): Stem.from_hanja(stem)
    for month, stem in zip("寅辰巳未申戌亥丑", "丁壬辛甲癸丙乙庚", strict=True)
}


def day_virtues(month_branch: Branch, day: Pillar) -> tuple[DayVirtue, ...]:
    """그날의 덕일. 천덕일 먼저."""
    found: list[DayVirtue] = []
    if CHEONDEOK_DAY_STEM.get(month_branch) is day.stem:
        found.append(DayVirtue.CHEONDEOK_DAY)
    if WOLDEOK[month_branch] is day.stem:
        found.append(DayVirtue.WOLDEOK_DAY)
    return tuple(found)


def day_virtue_judgment(kind: DayVirtue, month_branch: Branch, day: Pillar) -> Judgment:
    name = kind.name.lower().removesuffix("_day")
    params = {"month_branch": month_branch.name, "day_stem": day.stem.name}
    evidence = Evidence(
        rule_id=require_rule(f"day_virtue/{name}", params), source_ref=DAY_VIRTUE_REF[name], detail=params
    )
    return Judgment(message_key=require(f"day_virtue.{name}", params), params=params, evidence=(evidence,))

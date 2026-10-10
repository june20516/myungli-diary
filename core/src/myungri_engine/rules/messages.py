"""총운·가이드 질문 메시지 키 (spec 7.8). 문장은 콘텐츠 모듈이 갖는다(D27)."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Final

from myungri_engine.constants.message_keys import require
from myungri_engine.domain.enums import DayKind, Stem
from myungri_engine.domain.models import Evidence, Judgment, Pillar
from myungri_engine.domain.ten_gods import ten_god
from myungri_engine.references.loader import FIVE_ELEMENTS_REF
from myungri_engine.rules.yongsin import YongsinResult

EMPHASIS_POSITIVE: Final = "POSITIVE"
EMPHASIS_NONE: Final = "NONE"


def _evidence(rule_id: str, detail: Mapping[str, str]) -> Evidence:
    return Evidence(rule_id=rule_id, source_ref=FIVE_ELEMENTS_REF["balance_principle"], detail=detail)


def _tag_suffix(tag_key: str) -> str:
    return tag_key.removeprefix("tag.")


def fortune(
    kind: DayKind,
    day: Pillar,
    natal_day_stem: Stem,
    featured: Sequence[str],
    yongsin: YongsinResult,
) -> tuple[Judgment, ...]:
    """첫 항목이 헤드라인이다. 대표 태그가 있으면 둘째로 보조 문장 키를 붙인다."""
    god = ten_god(natal_day_stem, day.stem)
    params: dict[str, str | int | float | bool] = {
        "day_kind": kind.name,
        "ten_god": god.name,
        "element": day.stem.element.name,
        "emphasis": EMPHASIS_POSITIVE if kind is DayKind.YONGSIN_DAY else EMPHASIS_NONE,
    }
    detail = {"day_kind": kind.name, "ten_god": god.name, "group": god.group.name}
    head = Judgment(
        message_key=require(f"fortune.{kind.name.lower()}.{god.group.name.lower()}"),
        params=params,
        evidence=(_evidence("fortune/day_kind", detail), *yongsin.evidence),
    )
    if not featured:
        return (head,)
    tag_detail = {**detail, "featured": featured[0]}
    tag_sentence = Judgment(
        message_key=require(f"fortune.tag.{_tag_suffix(featured[0])}"),
        params=params,
        evidence=(_evidence("fortune/tag", tag_detail), *yongsin.evidence),
    )
    return (head, tag_sentence)


def guide_question(day: Pillar, natal_day_stem: Stem, featured: Sequence[str]) -> Judgment:
    god = ten_god(natal_day_stem, day.stem)
    if featured:
        key = f"guide.{_tag_suffix(featured[0])}"
        basis = featured[0]
    else:
        key = f"guide.ten_god.{god.group.name.lower()}"
        basis = god.group.name
    return Judgment(
        message_key=require(key),
        params={"ten_god": god.name, "element": day.stem.element.name},
        evidence=(_evidence("guide/question", {"basis": basis, "ten_god": god.name}),),
    )

"""총운·가이드 질문 메시지 키 (spec 7.8). 문장은 콘텐츠 모듈이 갖는다(D27)."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Final

from myungli_engine.constants.message_keys import require
from myungli_engine.domain.enums import DayKind, Stem
from myungli_engine.domain.models import Evidence, Judgment, Pillar
from myungli_engine.domain.ten_gods import ten_god
from myungli_engine.references.loader import ten_god_group_ref
from myungli_engine.rules.yongsin import YongsinResult

EMPHASIS_POSITIVE: Final = "POSITIVE"
EMPHASIS_NONE: Final = "NONE"


def _evidence(rule_id: str, detail: Mapping[str, str], source_ref: str) -> Evidence:
    return Evidence(rule_id=rule_id, source_ref=source_ref, detail=detail)


def _tag_suffix(tag_key: str) -> str:
    return tag_key.removeprefix("tag.")


def fortune(
    kind: DayKind,
    day: Pillar,
    natal_day_stem: Stem,
    featured: Sequence[str],
    yongsin: YongsinResult,
    *,
    tag_sources: Mapping[str, str],
) -> tuple[Judgment, ...]:
    """첫 항목이 헤드라인이다. 대표 태그가 있으면 둘째로 보조 문장 키를 붙인다.

    헤드라인의 근거는 오늘 천간의 십성 묶음을 다룬 조목(#998), 보조 문장은 그 태그의 원전이다(`tag_sources`, C28).
    """
    god = ten_god(natal_day_stem, day.stem)
    params: dict[str, str | int | float | bool] = {
        "day_kind": kind.name,
        "ten_god": god.name,
        "element": day.stem.element.name,
        "emphasis": EMPHASIS_POSITIVE if kind is DayKind.YONGSIN_DAY else EMPHASIS_NONE,
    }
    detail = {"day_kind": kind.name, "ten_god": god.name, "group": god.group.name}
    head = Judgment(
        message_key=require(f"fortune.{kind.name.lower()}.{god.group.name.lower()}", params),
        params=params,
        evidence=(_evidence("fortune/day_kind", detail, ten_god_group_ref(god.group)), *yongsin.evidence),
    )
    if not featured:
        return (head,)
    tag_detail = {**detail, "featured": featured[0]}
    tag_sentence = Judgment(
        message_key=require(f"fortune.tag.{_tag_suffix(featured[0])}", params),
        params=params,
        evidence=(_evidence("fortune/tag", tag_detail, tag_sources[featured[0]]), *yongsin.evidence),
    )
    return (head, tag_sentence)


def guide_question(
    day: Pillar, natal_day_stem: Stem, featured: Sequence[str], *, tag_sources: Mapping[str, str]
) -> Judgment:
    """오늘의 기본 질문: 대표 태그 1순위의 질문, 없으면 일진 십성 묶음의 질문."""
    return guide_candidates(day, natal_day_stem, featured, tag_sources=tag_sources)[0]


def guide_candidates(
    day: Pillar, natal_day_stem: Stem, featured: Sequence[str], *, tag_sources: Mapping[str, str]
) -> tuple[Judgment, ...]:
    """그날 근거가 있는 질문 후보(C30). 순서는 대표 태그 1순위, 2순위, 일진 십성 묶음이고 키는 겹치지 않는다.

    첫 항목이 기본 질문이다. 같은 키의 원고 변주는 콘텐츠 쪽이 펼친다.
    태그 질문의 근거는 그 태그의 원전, 십성 묶음 질문은 그 묶음을 다룬 조목(#998)이다.
    """
    god = ten_god(natal_day_stem, day.stem)
    params = {"ten_god": god.name, "element": day.stem.element.name}
    bases = [(f"guide.{_tag_suffix(tag)}", tag, tag_sources[tag]) for tag in featured]
    bases.append((f"guide.ten_god.{god.group.name.lower()}", god.group.name, ten_god_group_ref(god.group)))
    candidates: list[Judgment] = []
    seen: set[str] = set()
    for key, basis, source_ref in bases:
        if key in seen:
            continue
        seen.add(key)
        candidates.append(
            Judgment(
                message_key=require(key, params),
                params=params,
                evidence=(_evidence("guide/question", {"basis": basis, "ten_god": god.name}, source_ref),),
            )
        )
    return tuple(candidates)

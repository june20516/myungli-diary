"""해시태그 선택 (spec 7.7). 태그 키만 내고 문장은 만들지 않는다."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Final

from myungri_engine.calendar_core.lunar_adapter import hidden_stems
from myungri_engine.chart.positions import Position
from myungri_engine.constants.message_keys import require
from myungri_engine.domain.enums import DayKind, Shinsal, TenGodGroup
from myungri_engine.domain.models import Evidence, FourPillars, Pillar
from myungri_engine.domain.ten_gods import ten_god
from myungri_engine.references.loader import FIVE_ELEMENTS_REF
from myungri_engine.rules.group_count import natal_group_count
from myungri_engine.rules.relations import Relation, RelationKind, active

MAX_FEATURED: Final = 2
RUSH_MIN_NATAL_COUNT: Final = 2
CLASH_BIG_CHANGE_POSITIONS: Final = frozenset({Position.DAY_BRANCH, Position.MONTH_BRANCH})

TAG_BIG_CHANGE: Final = "tag.big_change"
TAG_CLASH: Final = "tag.clash"
TAG_HARMONY: Final = "tag.harmony"

_SHINSAL_TAGS: Final[tuple[tuple[Shinsal, str], ...]] = (
    (Shinsal.GONGMANG, "tag.gongmang"),
    (Shinsal.YEOKMA, "tag.yeokma"),
    (Shinsal.HWAGAE, "tag.hwagae"),
    (Shinsal.DOHWA, "tag.dohwa"),
    (Shinsal.CHEONEUL_GWIIN, "tag.cheoneul_gwiin"),
)
_AUXILIARY_TAGS: Final[dict[DayKind, str]] = {
    DayKind.GWIIN_DAY: "tag.gwiin_day",
    DayKind.YONGSIN_DAY: "tag.yongsin_day",
}


def rush_tag_key(group: TenGodGroup) -> str:
    return f"tag.ten_god_rush.{group.name.lower()}"


@dataclass(frozen=True, slots=True)
class TagResult:
    all_keys: tuple[str, ...]
    featured: tuple[str, ...]
    evidence: tuple[Evidence, ...]


def select_tags(
    natal: FourPillars,
    day: Pillar,
    relations: Sequence[Relation],
    activated: Sequence[Shinsal],
    kind: DayKind,
) -> TagResult:
    """그룹 우선(합충 > 십성 쏠림 > 신살), 그룹 안은 흉 우선 순서로 정렬한다."""
    ordered = (*_relation_tags(relations), *_rush_tags(natal, day), *_shinsal_tags(activated))
    if not ordered and kind in _AUXILIARY_TAGS:
        ordered = (_AUXILIARY_TAGS[kind],)
    all_keys = tuple(require(key) for key in ordered)
    featured = all_keys[:MAX_FEATURED]
    evidence = Evidence(
        rule_id="tags/select",
        source_ref=FIVE_ELEMENTS_REF["balance_principle"],
        detail={"all": ",".join(all_keys), "featured": ",".join(featured), "day_kind": kind.name},
    )
    return TagResult(all_keys=all_keys, featured=featured, evidence=(evidence,))


def _relation_tags(relations: Sequence[Relation]) -> tuple[str, ...]:
    live = active(relations)
    chungs = [rel for rel in live if rel.kind is RelationKind.CHUNG]
    tags: list[str] = []
    if any(rel.natal_position in CLASH_BIG_CHANGE_POSITIONS for rel in chungs):
        tags.append(TAG_BIG_CHANGE)
    if any(rel.natal_position not in CLASH_BIG_CHANGE_POSITIONS for rel in chungs):
        tags.append(TAG_CLASH)
    # 합은 탐합망충에서 무효가 되지 않으므로, 충이 무효가 된 날에도 활성 합으로 남는다.
    if any(rel.kind in (RelationKind.STEM_HAP, RelationKind.BRANCH_HAP) for rel in live):
        tags.append(TAG_HARMONY)
    return tuple(tags)


def _rush_tags(natal: FourPillars, day: Pillar) -> tuple[str, ...]:
    day_stem = natal.day.stem
    stem_group = ten_god(day_stem, day.stem).group
    branch_group = ten_god(day_stem, hidden_stems(day.branch)[0]).group
    if stem_group is not branch_group:
        return ()
    if natal_group_count(natal, stem_group) < RUSH_MIN_NATAL_COUNT:
        return ()
    return (rush_tag_key(stem_group),)


def _shinsal_tags(activated: Sequence[Shinsal]) -> tuple[str, ...]:
    return tuple(tag for shinsal, tag in _SHINSAL_TAGS if shinsal in activated)

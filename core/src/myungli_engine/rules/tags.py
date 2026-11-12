"""해시태그 선택 (spec 7.7). 태그 키만 내고 문장은 만들지 않는다."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from types import MappingProxyType
from typing import Final

from myungli_engine.calendar_core.lunar_adapter import hidden_stems
from myungli_engine.chart.positions import Position
from myungli_engine.constants.evidence_rules import require_rule
from myungli_engine.constants.message_keys import require
from myungli_engine.domain.enums import DayKind, Shinsal, TenGodGroup
from myungli_engine.domain.models import Evidence, FourPillars, Pillar
from myungli_engine.domain.ten_gods import ten_god
from myungli_engine.references.loader import TAG_SOURCE_REF
from myungli_engine.rules.group_count import natal_group_count
from myungli_engine.rules.relations import Relation, RelationKind, active

MAX_FEATURED: Final = 2
RUSH_MIN_NATAL_COUNT: Final = 2

TAG_CLASH_DAY_BRANCH: Final = "tag.clash_day_branch"
TAG_CLASH_MONTH_BRANCH: Final = "tag.clash_month_branch"
TAG_CLASH: Final = "tag.clash"
TAG_HARMONY: Final = "tag.harmony"
# 자리별 충 태그. 여기 없는 자리(연지·시지)의 충은 TAG_CLASH다. 순서가 태그 순서다.
_POSITION_CLASH_TAGS: Final[tuple[tuple[Position, str], ...]] = (
    (Position.DAY_BRANCH, TAG_CLASH_DAY_BRANCH),
    (Position.MONTH_BRANCH, TAG_CLASH_MONTH_BRANCH),
)
_HAP_KINDS: Final = (RelationKind.STEM_HAP, RelationKind.BRANCH_HAP)

_SHINSAL_TAGS: Final[tuple[tuple[Shinsal, str], ...]] = (
    (Shinsal.GONGMANG, "tag.gongmang"),
    (Shinsal.YEOKMA, "tag.yeokma"),
    (Shinsal.HWAGAE, "tag.hwagae"),
    (Shinsal.DOHWA, "tag.dohwa"),
    (Shinsal.CHEONEUL_GWIIN, "tag.cheoneul_gwiin"),
    # D124 ② 새 셋. 원전에 하루 근거가 있는 기존 신살보다 늘 뒤에 둔다(D125 ②).
    (Shinsal.GOSIN, "tag.gosin"),
    (Shinsal.GWASUK, "tag.gwasuk"),
    (Shinsal.WONJIN, "tag.wonjin"),
)
_AUXILIARY_TAGS: Final[dict[DayKind, str]] = {
    DayKind.GWIIN_DAY: "tag.gwiin_day",
    DayKind.YONGSIN_DAY: "tag.yongsin_day",
}
# 길 태그(D125 ①). 목록에 하나라도 있으면 그 가운데 맨 앞의 것을 목록 맨 앞으로 옮긴다.
GOOD_TAGS: Final = frozenset(
    {
        TAG_HARMONY,
        "tag.ten_god_rush.jaeseong",
        "tag.ten_god_rush.inseong",
        "tag.ten_god_rush.siksang",
        "tag.dohwa",
        "tag.cheoneul_gwiin",
        *_AUXILIARY_TAGS.values(),
    }
)
# 원전이 없는 근거의 source_ref (C28).
NO_SOURCE: Final = ""


def rush_tag_key(group: TenGodGroup) -> str:
    return f"tag.ten_god_rush.{group.name.lower()}"


def tag_name(tag_key: str) -> str:
    """태그 키에서 `tag.`을 뗀 이름. 십성 몰림은 묶음을 떼고 `ten_god_rush`."""
    name = tag_key.removeprefix("tag.")
    return name.split(".")[0]


_HAP_SOURCE_KEYS: Final[dict[RelationKind, str]] = {
    RelationKind.STEM_HAP: "stem_hap",
    RelationKind.BRANCH_HAP: "branch_hap",
}


def tag_source_ref(name: str, hap_kind: RelationKind | None = None) -> str:
    """태그 이름(합은 합 종류까지)의 원전 source_ref. 원전이 없으면 NO_SOURCE."""
    key = _HAP_SOURCE_KEYS[hap_kind] if hap_kind is not None else name
    return TAG_SOURCE_REF.get(key, NO_SOURCE)


@dataclass(frozen=True, slots=True)
class TagResult:
    all_keys: tuple[str, ...]
    featured: tuple[str, ...]
    evidence: tuple[Evidence, ...]
    # 태그 키 → 그 태그 첫 근거의 source_ref. 총운 보조 문장과 가이드 질문이 근거로 쓴다.
    # 천간합과 지지합이 함께인 합 태그는 첫 근거(천간합)다. 두 근거는 모두 evidence에 있다(C28)
    source_refs: Mapping[str, str]


@dataclass(frozen=True, slots=True)
class _Tag:
    key: str
    evidence: tuple[Evidence, ...]


def select_tags(
    natal: FourPillars,
    day: Pillar,
    relations: Sequence[Relation],
    activated: Sequence[Shinsal],
    kind: DayKind,
    *,
    yongsin_ref: str,
) -> TagResult:
    """그룹 우선(합충 > 십성 쏠림 > 신살), 그룹 안은 C9 순서로 세운 뒤 첫 길 태그를 맨 앞으로 옮긴다(D125).

    근거는 첫째가 선택 결과(`tags/select`), 그 뒤로 태그마다 하나(합은 종류마다 하나)다(C28).
    """
    tags = (*_relation_tags(day, relations), *_rush_tags(natal, day), *_shinsal_tags(day, activated))
    if not tags and kind in _AUXILIARY_TAGS:
        tags = (_auxiliary_tag(kind, yongsin_ref),)
    tags = _good_first(tags)
    all_keys = tuple(require(tag.key) for tag in tags)
    featured = all_keys[:MAX_FEATURED]
    selection = _evidence(
        "tags/select", NO_SOURCE, {"all": ",".join(all_keys), "featured": ",".join(featured), "day_kind": kind.name}
    )
    per_tag = tuple(evidence for tag in tags for evidence in tag.evidence)
    source_refs = MappingProxyType({tag.key: tag.evidence[0].source_ref for tag in tags})
    return TagResult(all_keys=all_keys, featured=featured, evidence=(selection, *per_tag), source_refs=source_refs)


def _good_first(tags: tuple[_Tag, ...]) -> tuple[_Tag, ...]:
    """길 태그가 있으면 그 가운데 맨 앞의 것 하나만 맨 앞으로. 나머지는 순서 그대로라 큰 흉이 둘째에 남는다."""
    first_good = next((index for index, tag in enumerate(tags) if tag.key in GOOD_TAGS), None)
    if first_good is None:
        return tags
    return (tags[first_good], *tags[:first_good], *tags[first_good + 1 :])


def _evidence(rule_id: str, source_ref: str, detail: Mapping[str, str]) -> Evidence:
    return Evidence(rule_id=require_rule(rule_id, detail), source_ref=source_ref, detail=detail)


def _positions(relations: Sequence[Relation]) -> str:
    return ",".join(rel.natal_position.name for rel in relations)


def _relation_tags(day: Pillar, relations: Sequence[Relation]) -> tuple[_Tag, ...]:
    live = active(relations)
    chungs = [rel for rel in live if rel.kind is RelationKind.CHUNG]
    tags: list[_Tag] = []
    by_position = dict(_POSITION_CLASH_TAGS)
    for position, key in _POSITION_CLASH_TAGS:
        hits = [rel for rel in chungs if rel.natal_position is position]
        if hits:
            tags.append(_clash_tag(key, hits, day))
    others = [rel for rel in chungs if rel.natal_position not in by_position]
    if others:
        tags.append(_clash_tag(TAG_CLASH, others, day))
    # 합은 탐합망충에서 무효가 되지 않으므로, 충이 무효가 된 날에도 활성 합으로 남는다.
    haps = [
        _evidence(
            "tags/harmony",
            tag_source_ref("harmony", hap_kind),
            {"relation_kind": hap_kind.name, "natal_positions": _positions([r for r in live if r.kind is hap_kind])},
        )
        for hap_kind in _HAP_KINDS
        if any(rel.kind is hap_kind for rel in live)
    ]
    if haps:
        tags.append(_Tag(TAG_HARMONY, tuple(haps)))
    return tuple(tags)


def _clash_tag(key: str, hits: Sequence[Relation], day: Pillar) -> _Tag:
    name = tag_name(key)
    detail = {"natal_positions": _positions(hits), "day_branch": day.branch.name}
    return _Tag(key, (_evidence(f"tags/{name}", tag_source_ref(name), detail),))


def _rush_tags(natal: FourPillars, day: Pillar) -> tuple[_Tag, ...]:
    day_stem = natal.day.stem
    stem_god = ten_god(day_stem, day.stem)
    branch_god = ten_god(day_stem, hidden_stems(day.branch)[0])
    if stem_god.group is not branch_god.group:
        return ()
    natal_count = natal_group_count(natal, stem_god.group)
    if natal_count < RUSH_MIN_NATAL_COUNT:
        return ()
    detail = {
        "group": stem_god.group.name,
        "natal_count": str(natal_count),
        "stem_ten_god": stem_god.name,
        "branch_ten_god": branch_god.name,
    }
    return (_Tag(rush_tag_key(stem_god.group), (_evidence("tags/ten_god_rush", NO_SOURCE, detail),)),)


def _shinsal_tags(day: Pillar, activated: Sequence[Shinsal]) -> tuple[_Tag, ...]:
    tags: list[_Tag] = []
    for shinsal, key in _SHINSAL_TAGS:
        if shinsal in activated:
            name = tag_name(key)
            detail = {"shinsal": shinsal.name, "day_branch": day.branch.name}
            tags.append(_Tag(key, (_evidence(f"tags/{name}", tag_source_ref(name), detail),)))
    return tuple(tags)


def _auxiliary_tag(kind: DayKind, yongsin_ref: str) -> _Tag:
    key = _AUXILIARY_TAGS[kind]
    name = tag_name(key)
    source_ref = yongsin_ref if kind is DayKind.YONGSIN_DAY else tag_source_ref("cheoneul_gwiin")
    return _Tag(key, (_evidence(f"tags/{name}", source_ref, {"day_kind": kind.name}),))

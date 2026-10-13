import random
from collections.abc import Callable

from myungli_engine.chart.shinsal import activated, shinsal_branches
from myungli_engine.constants.message_keys import ALL_KEYS, TAG_KEYS
from myungli_engine.domain.enums import Branch, DayKind, Element, Stem, TenGodGroup
from myungli_engine.domain.models import FourPillars, Judgment, Pillar
from myungli_engine.rules.messages import fortune, guide_question
from myungli_engine.rules.relations import find_relations
from myungli_engine.rules.tags import select_tags
from myungli_engine.rules.yongsin import YongsinResult

PillarOf = Callable[[str], Pillar]


def test_fortune_key(pillar_of: PillarOf, winter_gap: YongsinResult) -> None:
    judgments = fortune(DayKind.YONGSIN_DAY, pillar_of("癸卯"), Stem.GAP, (), winter_gap)
    assert len(judgments) == 1
    head = judgments[0]
    assert head.message_key == "fortune.yongsin_day.inseong"
    assert head.params["emphasis"] == "POSITIVE"
    assert head.params["day_kind"] == "YONGSIN_DAY"
    assert head.params["ten_god"] == "JEONGIN"
    assert head.params["element"] == Element.WATER.name


def test_fortune_adds_tag_sentence(pillar_of: PillarOf, winter_gap: YongsinResult) -> None:
    judgments = fortune(
        DayKind.ORDINARY_DAY, pillar_of("癸卯"), Stem.GAP, ("tag.clash", "tag.dohwa"), winter_gap
    )
    assert [j.message_key for j in judgments] == ["fortune.ordinary_day.inseong", "fortune.tag.clash"]
    assert judgments[0].params["emphasis"] == "NONE"


def test_guide_key_uses_featured_tag(pillar_of: PillarOf) -> None:
    judgment = guide_question(pillar_of("癸卯"), Stem.GAP, ("tag.big_change", "tag.clash"))
    assert judgment.message_key == "guide.big_change"


def test_guide_key_fallback(pillar_of: PillarOf) -> None:
    judgment = guide_question(pillar_of("癸卯"), Stem.GAP, ())
    assert judgment.message_key == "guide.ten_god.inseong"
    assert judgment.params["ten_god"] == "JEONGIN"


def test_guide_rush_tag_key(pillar_of: PillarOf) -> None:
    judgment = guide_question(pillar_of("戊辰"), Stem.GAP, ("tag.ten_god_rush.jaeseong",))
    assert judgment.message_key == "guide.ten_god_rush.jaeseong"


def _assert_has_evidence(judgments: tuple[Judgment, ...]) -> None:
    for judgment in judgments:
        assert judgment.evidence
        assert all(item.source_ref and item.rule_id for item in judgment.evidence)


def test_all_emitted_keys_registered(winter_gap: YongsinResult) -> None:
    rng = random.Random(20261010)
    stems, branches, kinds = tuple(Stem), tuple(Branch), tuple(DayKind)

    def random_pillar() -> Pillar:
        return Pillar(rng.choice(stems), rng.choice(branches))

    emitted: set[str] = set()
    for _ in range(200):
        hour = random_pillar() if rng.random() < 0.7 else None
        natal = FourPillars(random_pillar(), random_pillar(), random_pillar(), hour)
        day = random_pillar()
        kind = rng.choice(kinds)
        hits = activated(shinsal_branches(natal), day.branch)
        tags = select_tags(natal, day, find_relations(natal, day), hits, kind)
        judgments = (
            *fortune(kind, day, natal.day.stem, tags.featured, winter_gap),
            guide_question(day, natal.day.stem, tags.featured),
        )
        _assert_has_evidence(judgments)
        emitted.update(tags.all_keys)
        emitted.update(j.message_key for j in judgments)
    assert emitted <= ALL_KEYS


def test_all_fortune_keys_registered() -> None:
    for kind in DayKind:
        for group in TenGodGroup:
            assert f"fortune.{kind.name.lower()}.{group.name.lower()}" in ALL_KEYS


def test_all_tag_derived_keys_registered() -> None:
    for tag in TAG_KEYS:
        suffix = tag.removeprefix("tag.")
        assert tag in ALL_KEYS
        assert f"fortune.tag.{suffix}" in ALL_KEYS
        assert f"guide.{suffix}" in ALL_KEYS
    for group in TenGodGroup:
        assert f"guide.ten_god.{group.name.lower()}" in ALL_KEYS

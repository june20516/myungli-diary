from collections.abc import Callable

from myungri_engine.chart.positions import Position
from myungri_engine.domain.enums import DayKind, Shinsal
from myungri_engine.domain.models import FourPillars, Pillar
from myungri_engine.rules.relations import Relation, RelationKind, find_relations
from myungri_engine.rules.tags import select_tags

PillarOf = Callable[[str], Pillar]


def _natal(pillar_of: PillarOf, year: str, month: str, day: str) -> FourPillars:
    return FourPillars(year=pillar_of(year), month=pillar_of(month), day=pillar_of(day), hour=None)


def _rush_natal(pillar_of: PillarOf) -> FourPillars:
    """甲 일간, 재성 戊·己·未(己) 등 원국 재성 3개 이상, 오늘 戊辰과 충·합 없음."""
    return _natal(pillar_of, "戊午", "己未", "甲子")


def test_big_change_on_day_or_month_branch_chung(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    result = select_tags(natal, day, find_relations(natal, day), (), DayKind.ORDINARY_DAY)
    assert "tag.big_change" in result.featured
    assert "tag.clash" not in result.all_keys


def test_clash_on_other_position(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬午", "乙巳", "己卯")
    day = pillar_of("丙子")
    result = select_tags(natal, day, find_relations(natal, day), (), DayKind.ORDINARY_DAY)
    assert "tag.clash" in result.featured
    assert "tag.big_change" not in result.all_keys


def test_suppressed_chung_not_tagged(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "乙丑", "戊寅", "己午")
    day = pillar_of("丙子")
    rels = find_relations(natal, day)
    assert any(rel.kind is RelationKind.CHUNG and rel.suppressed_by is not None for rel in rels)
    result = select_tags(natal, day, rels, (), DayKind.ORDINARY_DAY)
    assert "tag.harmony" in result.all_keys
    assert "tag.big_change" not in result.all_keys
    assert "tag.clash" not in result.all_keys


def test_ten_god_rush(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    result = select_tags(natal, day, find_relations(natal, day), (), DayKind.ORDINARY_DAY)
    assert result.featured == ("tag.ten_god_rush.jaeseong",)


def test_no_rush_when_natal_group_is_scarce(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "乙亥", "丙寅", "甲子")
    day = pillar_of("戊辰")
    result = select_tags(natal, day, find_relations(natal, day), (), DayKind.ORDINARY_DAY)
    assert "tag.ten_god_rush.jaeseong" not in result.all_keys


def test_priority_order(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    rels = (Relation(RelationKind.CHUNG, Position.DAY_BRANCH, None),)
    result = select_tags(natal, day, rels, (Shinsal.DOHWA,), DayKind.ORDINARY_DAY)
    assert result.all_keys == ("tag.big_change", "tag.ten_god_rush.jaeseong", "tag.dohwa")
    assert result.featured == ("tag.big_change", "tag.ten_god_rush.jaeseong")


def test_tie_bad_first(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    rels = (
        Relation(RelationKind.BRANCH_HAP, Position.YEAR_BRANCH, None),
        Relation(RelationKind.CHUNG, Position.YEAR_BRANCH, None),
    )
    shinsal = (Shinsal.DOHWA, Shinsal.GONGMANG)
    result = select_tags(natal, day, rels, shinsal, DayKind.ORDINARY_DAY)
    assert result.all_keys == ("tag.clash", "tag.harmony", "tag.gongmang", "tag.dohwa")
    assert result.featured == ("tag.clash", "tag.harmony")


def test_yangin_has_no_tag(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    result = select_tags(natal, pillar_of("丙子"), (), (Shinsal.YANGIN,), DayKind.ORDINARY_DAY)
    assert result.all_keys == ()
    assert result.featured == ()


def test_auxiliary_only_when_empty(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    empty = select_tags(natal, day, (), (), DayKind.YONGSIN_DAY)
    assert empty.all_keys == empty.featured == ("tag.yongsin_day",)
    gwiin = select_tags(natal, day, (), (), DayKind.GWIIN_DAY)
    assert gwiin.featured == ("tag.gwiin_day",)
    with_tag = select_tags(natal, day, (), (Shinsal.DOHWA,), DayKind.YONGSIN_DAY)
    assert with_tag.all_keys == ("tag.dohwa",)
    plain = select_tags(natal, day, (), (), DayKind.ORDINARY_DAY)
    assert plain.all_keys == ()


def test_all_keys_superset_of_featured(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    rels = (Relation(RelationKind.CHUNG, Position.MONTH_BRANCH, None),)
    result = select_tags(natal, day, rels, (Shinsal.YEOKMA, Shinsal.HWAGAE), DayKind.GISIN_DAY)
    assert set(result.featured) <= set(result.all_keys)
    assert len(result.featured) <= 2
    assert result.evidence


def test_suppressed_hap_not_harmony(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    rels = (Relation(RelationKind.BRANCH_HAP, Position.YEAR_BRANCH, RelationKind.CHUNG),)
    result = select_tags(natal, pillar_of("丙子"), rels, (), DayKind.ORDINARY_DAY)
    assert "tag.harmony" not in result.all_keys

from collections.abc import Callable, Sequence

from myungli_engine.chart.positions import Position
from myungli_engine.domain.enums import DayKind, Shinsal
from myungli_engine.domain.models import FourPillars, Pillar
from myungli_engine.rules.relations import Relation, RelationKind, find_relations
from myungli_engine.rules.tags import TagResult, select_tags

YONGSIN_REF = "gungtong-bogam/johu_evidence#甲.寅"

PillarOf = Callable[[str], Pillar]


def _natal(pillar_of: PillarOf, year: str, month: str, day: str) -> FourPillars:
    return FourPillars(year=pillar_of(year), month=pillar_of(month), day=pillar_of(day), hour=None)


def _rush_natal(pillar_of: PillarOf) -> FourPillars:
    """甲 일간, 재성 戊·己·未(己) 등 원국 재성 3개 이상, 오늘 戊辰과 충·합 없음."""
    return _natal(pillar_of, "戊午", "己未", "甲子")


def _select(natal: FourPillars, day: Pillar, rels: Sequence[Relation], shinsal: Sequence[Shinsal] = (),
            kind: DayKind = DayKind.ORDINARY_DAY) -> TagResult:
    return select_tags(natal, day, rels, shinsal, kind, yongsin_ref=YONGSIN_REF)


def test_day_branch_clash_tags_clash_day_branch(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    result = _select(natal, day, find_relations(natal, day))
    assert "tag.clash_day_branch" in result.featured
    assert "tag.clash_month_branch" not in result.all_keys
    assert "tag.clash" not in result.all_keys


def test_month_branch_clash_tags_clash_month_branch(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "戊午", "己卯")
    day = pillar_of("丙子")
    result = _select(natal, day, find_relations(natal, day))
    assert "tag.clash_month_branch" in result.featured
    assert "tag.clash_day_branch" not in result.all_keys
    assert "tag.clash" not in result.all_keys


def test_day_and_month_clash_both_tags_day_first(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "甲午", "丙午")
    day = pillar_of("丙子")
    result = _select(natal, day, find_relations(natal, day))
    assert result.featured == ("tag.clash_day_branch", "tag.clash_month_branch")
    rule_ids = [ev.rule_id for ev in result.evidence]
    assert "tags/clash_day_branch" in rule_ids
    assert "tags/clash_month_branch" in rule_ids


def test_each_tag_has_own_evidence(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    rels = (
        Relation(RelationKind.STEM_HAP, Position.YEAR_STEM, None),
        Relation(RelationKind.BRANCH_HAP, Position.YEAR_BRANCH, None),
        Relation(RelationKind.CHUNG, Position.HOUR_BRANCH, None),
    )
    result = _select(natal, day, rels, (Shinsal.DOHWA,))
    assert [ev.rule_id for ev in result.evidence] == [
        "tags/select", "tags/clash", "tags/harmony", "tags/harmony", "tags/dohwa",
    ]
    harmony = [ev.detail["relation_kind"] for ev in result.evidence if ev.rule_id == "tags/harmony"]
    assert harmony == ["STEM_HAP", "BRANCH_HAP"]
    clash = next(ev for ev in result.evidence if ev.rule_id == "tags/clash")
    assert clash.detail == {"natal_positions": "HOUR_BRANCH", "day_branch": day.branch.name}


def test_rush_evidence_has_empty_source_ref(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    result = _select(natal, day, find_relations(natal, day))
    rush = next(ev for ev in result.evidence if ev.rule_id == "tags/ten_god_rush")
    assert rush.source_ref == ""
    assert rush.detail["group"] == "JAESEONG"


def test_select_evidence_has_no_common_source(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    result = _select(natal, day, find_relations(natal, day))
    assert result.evidence[0].rule_id == "tags/select"
    assert result.evidence[0].source_ref == ""


def test_yongsin_day_uses_yongsin_ref(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "乙亥", "丙寅", "甲子")
    day = pillar_of("戊辰")
    result = _select(natal, day, (), kind=DayKind.YONGSIN_DAY)
    assert result.all_keys == ("tag.yongsin_day",)
    assert result.evidence[-1].rule_id == "tags/yongsin_day"
    assert result.evidence[-1].source_ref == YONGSIN_REF


def test_clash_on_other_position(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬午", "乙巳", "己卯")
    day = pillar_of("丙子")
    result = _select(natal, day, find_relations(natal, day))
    assert "tag.clash" in result.featured
    assert "tag.clash_day_branch" not in result.all_keys
    assert "tag.clash_month_branch" not in result.all_keys


def test_suppressed_chung_not_tagged(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "乙丑", "戊寅", "己午")
    day = pillar_of("丙子")
    rels = find_relations(natal, day)
    assert any(rel.kind is RelationKind.CHUNG and rel.suppressed_by is not None for rel in rels)
    result = _select(natal, day, rels)
    assert "tag.harmony" in result.all_keys
    assert "tag.clash_day_branch" not in result.all_keys
    assert "tag.clash_month_branch" not in result.all_keys
    assert "tag.clash" not in result.all_keys


def test_ten_god_rush(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    result = _select(natal, day, find_relations(natal, day))
    assert result.featured == ("tag.ten_god_rush.jaeseong",)


def test_no_rush_when_natal_group_is_scarce(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "乙亥", "丙寅", "甲子")
    day = pillar_of("戊辰")
    result = _select(natal, day, find_relations(natal, day))
    assert "tag.ten_god_rush.jaeseong" not in result.all_keys


def test_priority_order(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    rels = (Relation(RelationKind.CHUNG, Position.DAY_BRANCH, None),)
    result = _select(natal, day, rels, (Shinsal.DOHWA,))
    assert result.all_keys == ("tag.clash_day_branch", "tag.ten_god_rush.jaeseong", "tag.dohwa")
    assert result.featured == ("tag.clash_day_branch", "tag.ten_god_rush.jaeseong")


def test_tie_bad_first(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    rels = (
        Relation(RelationKind.BRANCH_HAP, Position.YEAR_BRANCH, None),
        Relation(RelationKind.CHUNG, Position.YEAR_BRANCH, None),
    )
    shinsal = (Shinsal.DOHWA, Shinsal.GONGMANG)
    result = _select(natal, day, rels, shinsal)
    assert result.all_keys == ("tag.clash", "tag.harmony", "tag.gongmang", "tag.dohwa")
    assert result.featured == ("tag.clash", "tag.harmony")


def test_yangin_has_no_tag(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    result = select_tags(natal, pillar_of("丙子"), (), (Shinsal.YANGIN,), DayKind.ORDINARY_DAY, yongsin_ref=YONGSIN_REF)
    assert result.all_keys == ()
    assert result.featured == ()


def test_auxiliary_only_when_empty(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    day = pillar_of("丙子")
    empty = select_tags(natal, day, (), (), DayKind.YONGSIN_DAY, yongsin_ref=YONGSIN_REF)
    assert empty.all_keys == empty.featured == ("tag.yongsin_day",)
    gwiin = select_tags(natal, day, (), (), DayKind.GWIIN_DAY, yongsin_ref=YONGSIN_REF)
    assert gwiin.featured == ("tag.gwiin_day",)
    with_tag = select_tags(natal, day, (), (Shinsal.DOHWA,), DayKind.YONGSIN_DAY, yongsin_ref=YONGSIN_REF)
    assert with_tag.all_keys == ("tag.dohwa",)
    plain = select_tags(natal, day, (), (), DayKind.ORDINARY_DAY, yongsin_ref=YONGSIN_REF)
    assert plain.all_keys == ()


def test_all_keys_superset_of_featured(pillar_of: PillarOf) -> None:
    natal = _rush_natal(pillar_of)
    day = pillar_of("戊辰")
    rels = (Relation(RelationKind.CHUNG, Position.MONTH_BRANCH, None),)
    result = select_tags(natal, day, rels, (Shinsal.YEOKMA, Shinsal.HWAGAE), DayKind.GISIN_DAY, yongsin_ref=YONGSIN_REF)
    assert set(result.featured) <= set(result.all_keys)
    assert len(result.featured) <= 2
    assert result.evidence


def test_suppressed_hap_not_harmony(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, "壬申", "乙巳", "己午")
    rels = (Relation(RelationKind.BRANCH_HAP, Position.YEAR_BRANCH, RelationKind.CHUNG),)
    result = select_tags(natal, pillar_of("丙子"), rels, (), DayKind.ORDINARY_DAY, yongsin_ref=YONGSIN_REF)
    assert "tag.harmony" not in result.all_keys

from myungli_engine.chart.positions import Position
from myungli_engine.domain.enums import DayKind, LuckLevel
from myungli_engine.rules.calendar_luck import score_day
from myungli_engine.rules.relations import Relation, RelationKind


def rel(kind: RelationKind, position: Position, suppressed_by: RelationKind | None = None) -> Relation:
    return Relation(kind, position, suppressed_by)


def test_gwiin_day_scores_plus_two() -> None:
    result = score_day(DayKind.GWIIN_DAY, [])
    assert result.score == 2
    assert result.breakdown == (("gwiin_day", 2),)
    assert result.level == LuckLevel.GOOD


def test_yongsin_day_scores_plus_two() -> None:
    result = score_day(DayKind.YONGSIN_DAY, [])
    assert result.breakdown == (("yongsin_day", 2),)
    assert result.level == LuckLevel.GOOD


def test_gisin_day_scores_minus_one() -> None:
    result = score_day(DayKind.GISIN_DAY, [])
    assert result.breakdown == (("gisin_day", -1),)
    assert result.level == LuckLevel.NEUTRAL


def test_ordinary_day_has_no_entries() -> None:
    result = score_day(DayKind.ORDINARY_DAY, [])
    assert result.score == 0
    assert result.breakdown == ()
    assert result.level == LuckLevel.NEUTRAL


def test_hap_scores_plus_one_once() -> None:
    relations = [
        rel(RelationKind.STEM_HAP, Position.DAY_STEM),
        rel(RelationKind.BRANCH_HAP, Position.DAY_BRANCH),
    ]
    result = score_day(DayKind.ORDINARY_DAY, relations)
    assert result.breakdown == (("hap", 1),)
    assert result.level == LuckLevel.NEUTRAL


def test_chung_day_or_month_scores_minus_two() -> None:
    for position in (Position.DAY_BRANCH, Position.MONTH_BRANCH):
        result = score_day(DayKind.ORDINARY_DAY, [rel(RelationKind.CHUNG, position)])
        assert result.breakdown == (("chung_day_or_month", -2),)
        assert result.level == LuckLevel.CAUTION


def test_chung_other_scores_minus_one() -> None:
    result = score_day(DayKind.ORDINARY_DAY, [rel(RelationKind.CHUNG, Position.YEAR_BRANCH)])
    assert result.breakdown == (("chung_other", -1),)


def test_hyeong_scores_minus_one_once() -> None:
    relations = [
        rel(RelationKind.HYEONG, Position.YEAR_BRANCH),
        rel(RelationKind.HYEONG, Position.HOUR_BRANCH),
    ]
    result = score_day(DayKind.ORDINARY_DAY, relations)
    assert result.breakdown == (("hyeong", -1),)


def test_both_chung_kinds_each_counted_once() -> None:
    relations = [
        rel(RelationKind.CHUNG, Position.DAY_BRANCH),
        rel(RelationKind.CHUNG, Position.MONTH_BRANCH),
        rel(RelationKind.CHUNG, Position.YEAR_BRANCH),
    ]
    result = score_day(DayKind.ORDINARY_DAY, relations)
    assert result.breakdown == (("chung_day_or_month", -2), ("chung_other", -1))
    assert result.score == -3


def test_level_boundaries() -> None:
    hap = [rel(RelationKind.BRANCH_HAP, Position.DAY_BRANCH)]
    assert score_day(DayKind.GWIIN_DAY, []).level == LuckLevel.GOOD  # +2
    assert score_day(DayKind.ORDINARY_DAY, hap).level == LuckLevel.NEUTRAL  # +1
    assert score_day(DayKind.GISIN_DAY, [rel(RelationKind.HYEONG, Position.YEAR_BRANCH)]).level == LuckLevel.CAUTION  # -2
    assert score_day(DayKind.ORDINARY_DAY, [rel(RelationKind.CHUNG, Position.DAY_BRANCH)]).level == LuckLevel.CAUTION  # -2
    assert score_day(DayKind.GISIN_DAY, []).level == LuckLevel.NEUTRAL  # -1


def test_suppressed_chung_not_scored() -> None:
    relations = [
        rel(RelationKind.BRANCH_HAP, Position.MONTH_BRANCH),
        rel(RelationKind.CHUNG, Position.DAY_BRANCH, RelationKind.BRANCH_HAP),
    ]
    result = score_day(DayKind.ORDINARY_DAY, relations)
    assert result.breakdown == (("hap", 1),)


def test_breakdown_sums_to_score() -> None:
    relations = [
        rel(RelationKind.STEM_HAP, Position.YEAR_STEM),
        rel(RelationKind.CHUNG, Position.YEAR_BRANCH),
        rel(RelationKind.HYEONG, Position.HOUR_BRANCH),
    ]
    result = score_day(DayKind.YONGSIN_DAY, relations)
    assert result.score == sum(points for _, points in result.breakdown) == 1

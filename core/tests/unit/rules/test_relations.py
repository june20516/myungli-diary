from myungri_engine.chart.positions import Position
from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import Stem as S
from myungri_engine.domain.models import FourPillars, Pillar
from myungri_engine.rules.relations import Relation, RelationKind, active, find_relations


def natal_with(
    year: Pillar | None = None,
    month: Pillar | None = None,
    day: Pillar | None = None,
    hour: Pillar | None = None,
) -> FourPillars:
    filler = Pillar(S.BYEONG, B.IN)  # 테스트가 지정하지 않은 자리의 기본값
    return FourPillars(year or filler, month or filler, day or filler, hour)


def kinds(natal: FourPillars, today: Pillar) -> set[tuple[RelationKind, Position]]:
    return {(r.kind, r.natal_position) for r in find_relations(natal, today)}


def test_stem_hap() -> None:
    natal = natal_with(year=Pillar(S.GI, B.MI), month=Pillar(S.IM, B.JIN), day=Pillar(S.GYE, B.MYO))
    result = find_relations(natal, Pillar(S.GAP, B.SA))
    assert Relation(RelationKind.STEM_HAP, Position.YEAR_STEM, None) in result


def test_branch_chung() -> None:
    natal = natal_with(day=Pillar(S.GYE, B.O))
    assert (RelationKind.CHUNG, Position.DAY_BRANCH) in kinds(natal, Pillar(S.GAP, B.JA))


def test_tamhap_mangchung() -> None:
    natal = natal_with(month=Pillar(S.GI, B.CHUK), day=Pillar(S.GYE, B.O))
    result = find_relations(natal, Pillar(S.GAP, B.JA))
    chung = [r for r in result if r.kind is RelationKind.CHUNG]
    hap = [r for r in result if r.kind is RelationKind.BRANCH_HAP]
    assert [r.natal_position for r in chung] == [Position.DAY_BRANCH]
    assert chung[0].suppressed_by is RelationKind.BRANCH_HAP
    assert hap[0].natal_position is Position.MONTH_BRANCH and hap[0].suppressed_by is None
    assert RelationKind.CHUNG not in {r.kind for r in active(result)}


def test_chung_without_hap_stays_active() -> None:
    natal = natal_with(day=Pillar(S.GYE, B.O))
    chung = [r for r in find_relations(natal, Pillar(S.GAP, B.JA)) if r.kind is RelationKind.CHUNG]
    assert chung and all(r.suppressed_by is None for r in chung)


def test_hyeong_group() -> None:
    natal = natal_with(year=Pillar(S.BYEONG, B.IN))
    assert (RelationKind.HYEONG, Position.YEAR_BRANCH) in kinds(natal, Pillar(S.GAP, B.SA))


def test_hyeong_pair_ja_myo() -> None:
    natal = natal_with(day=Pillar(S.GYE, B.MYO))
    assert (RelationKind.HYEONG, Position.DAY_BRANCH) in kinds(natal, Pillar(S.GAP, B.JA))


def test_self_hyeong() -> None:
    natal = natal_with(month=Pillar(S.BYEONG, B.JIN))
    assert (RelationKind.HYEONG, Position.MONTH_BRANCH) in kinds(natal, Pillar(S.GAP, B.JIN))


def test_same_branch_without_self_hyeong_is_not_hyeong() -> None:
    natal = natal_with(month=Pillar(S.BYEONG, B.IN))
    assert RelationKind.HYEONG not in {r.kind for r in find_relations(natal, Pillar(S.GAP, B.IN))}


def test_time_unknown_skips_hour() -> None:
    natal = natal_with(day=Pillar(S.GYE, B.O), hour=None)
    positions = {r.natal_position for r in find_relations(natal, Pillar(S.GI, B.JA))}
    assert Position.HOUR_STEM not in positions and Position.HOUR_BRANCH not in positions


def test_results_are_ordered_by_position() -> None:
    natal = natal_with(year=Pillar(S.GI, B.JA), day=Pillar(S.GYE, B.O), hour=Pillar(S.BYEONG, B.SA))
    order = list(Position)
    positions = [order.index(r.natal_position) for r in find_relations(natal, Pillar(S.GAP, B.JA))]
    assert positions == sorted(positions)

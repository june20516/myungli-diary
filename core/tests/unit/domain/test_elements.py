from myungli_engine.domain.elements import controlled_by, controls, generated_by, generates, relation_to
from myungli_engine.domain.enums import Element as E
from myungli_engine.domain.enums import ElementRelation as R


def test_generation_cycle():
    assert [generates(e) for e in (E.WOOD, E.FIRE, E.EARTH, E.METAL, E.WATER)] == [
        E.FIRE,
        E.EARTH,
        E.METAL,
        E.WATER,
        E.WOOD,
    ]


def test_control_cycle():
    assert [controls(e) for e in (E.WOOD, E.EARTH, E.WATER, E.FIRE, E.METAL)] == [
        E.EARTH,
        E.WATER,
        E.FIRE,
        E.METAL,
        E.WOOD,
    ]


def test_inverse_relations():
    for e in E:
        assert generates(generated_by(e)) == e and controls(controlled_by(e)) == e


def test_relation_to_base():
    """바탕 오행(水)에서 본 결과 오행의 관계: 같음, 母(생해 줌), 子(생해 받음), 妻(극당함), 鬼(극함)."""
    assert [relation_to(E.WATER, e) for e in (E.WATER, E.METAL, E.WOOD, E.FIRE, E.EARTH)] == [
        R.SAME,
        R.MO,
        R.JA,
        R.CHEO,
        R.GWI,
    ]

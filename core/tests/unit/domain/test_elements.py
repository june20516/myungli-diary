from myungli_engine.domain.elements import controlled_by, controls, generated_by, generates
from myungli_engine.domain.enums import Element as E


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

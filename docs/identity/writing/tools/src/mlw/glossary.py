"""값 이름 사전(`glossary.value_name`)의 범주와 범주별 값 목록입니다.

값은 proto enum에서 나옵니다. 로더와 완결성 검사가 함께 쓰므로 다른 mlw 모듈에 기대지 않습니다.
"""

from functools import cache

from google.protobuf.internal.enum_type_wrapper import EnumTypeWrapper

from mlw._gen.myungri.engine.v1 import engine_pb2

# proto enum이 아니라서 여기서 직접 정하는 십성 그룹 값입니다.
TEN_GOD_GROUPS: tuple[str, ...] = ("bigyeop", "siksang", "jaeseong", "gwanseong", "inseong")
# 원국 개인 해석(core `rules/personal.py`)의 매개변수 값 중 proto enum이 아닌 것입니다.
PERSONAL_ROLES: tuple[str, ...] = ("yongsin", "huisin", "gisin", "neutral")
LUCK_KINDS: tuple[str, ...] = ("daeun", "seun")
PILLAR_PARTS: tuple[str, ...] = ("stem", "branch")
# 지장간 자리는 지지 자리 이름에 이 접미사를 붙입니다(core `_place`).
HIDDEN_SUFFIX = "_hidden"


def _enum_value_names(enum: EnumTypeWrapper) -> tuple[str, ...]:
    """`<ENUM>_UNSPECIFIED`를 빼고 접두어를 뗀 소문자 값 이름입니다."""
    names = list(enum.keys())
    prefix = names[0].removesuffix("UNSPECIFIED")
    return tuple(name.removeprefix(prefix).lower() for name in names[1:])


def _place_values() -> tuple[str, ...]:
    """원국 자리 8개 다음에 지지 자리의 지장간 4개를 둡니다."""
    positions = _enum_value_names(engine_pb2.Position)
    hidden = tuple(f"{position}{HIDDEN_SUFFIX}" for position in positions if position.endswith("_branch"))
    return positions + hidden


@cache
def glossary_values() -> dict[str, tuple[str, ...]]:
    """값 이름 사전의 범주별 값 목록입니다. `color`는 `element`와 같은 값 집합입니다."""
    elements = _enum_value_names(engine_pb2.Element)
    return {
        "element": elements,
        "color": elements,
        "stem": _enum_value_names(engine_pb2.Stem),
        "branch": _enum_value_names(engine_pb2.Branch),
        "ten_god": _enum_value_names(engine_pb2.TenGod),
        "ten_god_group": TEN_GOD_GROUPS,
        "direction8": _enum_value_names(engine_pb2.Direction8),
        "shinsal": _enum_value_names(engine_pb2.Shinsal),
        "day_kind": _enum_value_names(engine_pb2.DayKind),
        "relation": _enum_value_names(engine_pb2.RelationKind),
        "place": _place_values(),
        "role": PERSONAL_ROLES,
        "strength": _enum_value_names(engine_pb2.StrengthLevel),
        "luck": LUCK_KINDS,
        "part": PILLAR_PARTS,
    }

"""값 이름 사전(`glossary.value_name`)의 범주와 범주별 값 목록입니다.

값은 proto enum에서 나옵니다. 로더와 완결성 검사가 함께 쓰므로 다른 mlw 모듈에 기대지 않습니다.
"""

from functools import cache

from google.protobuf.internal.enum_type_wrapper import EnumTypeWrapper

from mlw._gen.myungri.engine.v1 import engine_pb2

# proto enum이 아니라서 여기서 직접 정하는 십성 그룹 값입니다.
TEN_GOD_GROUPS: tuple[str, ...] = ("bigyeop", "siksang", "jaeseong", "gwanseong", "inseong")


def _enum_value_names(enum: EnumTypeWrapper) -> tuple[str, ...]:
    """`<ENUM>_UNSPECIFIED`를 빼고 접두어를 뗀 소문자 값 이름입니다."""
    names = list(enum.keys())
    prefix = names[0].removesuffix("UNSPECIFIED")
    return tuple(name.removeprefix(prefix).lower() for name in names[1:])


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
    }

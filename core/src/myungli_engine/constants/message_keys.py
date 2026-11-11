"""엔진이 쓸 수 있는 메시지 키의 유일한 목록 (spec §10).

형식은 소문자 스네이크 케이스를 점으로 구분한다. 문장은 콘텐츠 모듈이 갖는다(D27).
키마다 엔진이 넘기는 매개변수 이름도 여기서 함께 선언한다. 값 종류(렌더 방식)는 writing이 정한다.
`python -m myungli_engine.constants.message_keys`는 정렬된 키 목록 JSON을,
`python -m myungli_engine.constants.message_keys params`는 키별 매개변수 이름 JSON을 낸다.
"""

from __future__ import annotations

import json
import sys
from collections.abc import Iterable, Mapping
from enum import Enum

from myungli_engine.domain.enums import ColorBasis, DayKind, Shinsal, Stem, TenGod, TenGodGroup, TwelveStage


def _lower(member: Enum) -> str:
    return member.name.lower()


_DAY_KINDS = tuple(_lower(kind) for kind in DayKind)
_COLOR_BASES = tuple(_lower(basis) for basis in ColorBasis)
_GROUPS = tuple(_lower(group) for group in TenGodGroup)
_STEMS = tuple(_lower(stem) for stem in Stem)
_TEN_GODS = tuple(_lower(god) for god in TenGod)
_TWELVE_STAGES = tuple(_lower(stage) for stage in TwelveStage)
_SHINSALS = tuple(_lower(kind) for kind in Shinsal)

TAG_KEYS: frozenset[str] = frozenset(
    {
        "tag.clash_day_branch",
        "tag.clash_month_branch",
        "tag.clash",
        "tag.harmony",
        *(f"tag.ten_god_rush.{group}" for group in _GROUPS),
        "tag.cheoneul_gwiin",
        "tag.dohwa",
        "tag.yeokma",
        "tag.hwagae",
        "tag.gongmang",
        "tag.yongsin_day",
        "tag.gwiin_day",
    }
)


def _strip_tag_prefix(tag_key: str) -> str:
    return tag_key.removeprefix("tag.")


_FORTUNE_PARAMS = ("day_kind", "ten_god", "element", "emphasis")
_GUIDE_PARAMS = ("ten_god", "element")


def _declare(keys: Iterable[str], params: tuple[str, ...]) -> dict[str, tuple[str, ...]]:
    return dict.fromkeys(keys, params)


_COLOR_PARAMS = ("base_element", "day_branch", "element", "role", "shift", "twelve_stage")
_DIRECTION_PARAMS = ("direction", "rule_id")

KEY_PARAMS: dict[str, tuple[str, ...]] = {
    # 색 카드가 하나인 날은 color.<날의 성격>, 둘인 날은 color.balance.*(첫째)와 color.source.*(둘째) (D119)
    **_declare((f"color.{kind}" for kind in _DAY_KINDS), _COLOR_PARAMS),
    **_declare((f"color.{basis}.{kind}" for basis in _COLOR_BASES for kind in _DAY_KINDS), _COLOR_PARAMS),
    **_declare(
        (f"number.{kind}" for kind in _DAY_KINDS), ("number", "element", "day_stem", "parity", "pair")
    ),
    "direction.day_kind.gwiin": (*_DIRECTION_PARAMS, "day_branch"),
    **_declare(
        (f"direction.day_kind.{kind}" for kind in ("yongsin", "gisin")),
        (*_DIRECTION_PARAMS, "element", "role"),
    ),
    "direction.day_kind.ordinary": (*_DIRECTION_PARAMS, "element", "role", "deity"),
    # 집중 시간은 낮과 밤 각각 하나(D122). 이유는 "오늘 일진과 태어난 해를 보고 고른 시간" 수준까지(D121)
    **_declare((f"focus_time.{period}" for period in ("day", "night")), ("hour_branch",)),
    **_declare(TAG_KEYS, ()),
    **_declare((f"fortune.{kind}.{group}" for kind in _DAY_KINDS for group in _GROUPS), _FORTUNE_PARAMS),
    **_declare((f"fortune.tag.{_strip_tag_prefix(tag)}" for tag in TAG_KEYS), _FORTUNE_PARAMS),
    **_declare((f"guide.{_strip_tag_prefix(tag)}" for tag in TAG_KEYS), _GUIDE_PARAMS),
    **_declare((f"guide.ten_god.{group}" for group in _GROUPS), _GUIDE_PARAMS),
    **_declare(
        (f"yongsin.method.{method}" for method in ("johu", "johu_neutral", "eokbu")),
        ("yongsin", "huisin", "gisin", "tonggwan"),
    ),
    **_declare((f"calendar.{level}" for level in ("very_good", "good", "neutral", "caution")), ("score",)),
    **_declare((f"personal.day_master.{stem}" for stem in _STEMS), ("strength", "yongsin", "gisin")),
    **_declare(
        (f"personal.ten_god.{god}" for god in _TEN_GODS),
        ("place", "element", "role", "group_count", "strength"),
    ),
    **_declare(
        (f"personal.twelve_stage.{stage}" for stage in _TWELVE_STAGES),
        ("place", "element", "role", "strength"),
    ),
    **_declare((f"personal.shinsal.{kind}" for kind in _SHINSALS), ("place", "element", "role")),
    **_declare(
        (f"personal.luck.ten_god.{god}" for god in _TEN_GODS),
        ("luck", "part", "element", "role", "current"),
    ),
    **_declare(
        (f"personal.luck.twelve_stage.{stage}" for stage in _TWELVE_STAGES), ("element", "role", "current")
    ),
}

ALL_KEYS: frozenset[str] = frozenset(KEY_PARAMS)


def require(key: str, params: Mapping[str, object] | None = None) -> str:
    """등록된 키만 통과시킨다. 매개변수 이름이 선언과 다르면 KeyError."""
    if key not in KEY_PARAMS:
        raise KeyError(f"등록되지 않은 메시지 키: {key!r}")
    declared = set(KEY_PARAMS[key])
    given = set(params or {})
    if given != declared:
        raise KeyError(
            f"메시지 키 {key!r}의 매개변수가 선언과 다릅니다: {sorted(given)} != {sorted(declared)}"
        )
    return key


def main() -> None:
    if sys.argv[1:] == ["params"]:
        exported: object = {key: list(KEY_PARAMS[key]) for key in sorted(KEY_PARAMS)}
    else:
        exported = sorted(ALL_KEYS)
    print(json.dumps(exported, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

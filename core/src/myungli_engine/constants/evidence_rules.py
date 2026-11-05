"""엔진이 낼 수 있는 Evidence.rule_id와 규칙별 detail 키의 유일한 목록 (#130).

detail 키는 그 규칙의 근거에 들어갈 수 있는 키 전부다. 근거 하나에는 이 가운데 일부만 들어갈 수 있다
(예: `personal/luck_ten_god`의 `part`는 대운 천간·지지 해석에만). 값은 모두 문자열이다.
`python -m myungli_engine.constants.evidence_rules`는 규칙별 detail 키 JSON을 낸다.
"""

from __future__ import annotations

import json
from collections.abc import Mapping
from typing import Final

_DIRECTION_DETAIL: Final = ("day_branch", "day_kind", "direction", "element")
_DIRECTION_DEITY_DETAIL: Final = ("day_branch", "day_kind", "deity", "direction", "element")
_CLASH_DETAIL: Final = ("day_branch", "natal_positions")
_SHINSAL_DETAIL: Final = ("day_branch", "shinsal")

RULE_DETAIL_KEYS: Final[dict[str, tuple[str, ...]]] = {
    # 월간 길흉 점수 (spec 7.9)
    "calendar/score": ("breakdown", "score"),
    # 데일리 카드 (spec 7.3~7.6)
    "color/lucky_element": ("day_kind", "element", "note", "role"),
    "direction/gwiin_branch": ("day_branch", "day_kind", "direction"),
    "direction/ordinary_deity_huisin": _DIRECTION_DEITY_DETAIL,
    "direction/ordinary_deity_yongsin": _DIRECTION_DEITY_DETAIL,
    "direction/ordinary_fallback": _DIRECTION_DETAIL,
    "direction/tonggwan": _DIRECTION_DETAIL,
    "direction/yongsin": _DIRECTION_DETAIL,
    "number/hado": ("day_stem", "element", "number", "parity"),
    "focus_time/score": ("picks",),
    "focus_time/fallback": ("picks",),
    # 태그·총운·가이드 질문 (spec 7.7~7.8)
    "tags/select": ("all", "day_kind", "featured"),
    # 태그마다 하나 (C28). 원전이 없는 태그는 source_ref가 빈 문자열이다
    "tags/clash_day_branch": _CLASH_DETAIL,
    "tags/clash_month_branch": _CLASH_DETAIL,
    "tags/clash": _CLASH_DETAIL,
    "tags/harmony": ("natal_positions", "relation_kind"),
    "tags/ten_god_rush": ("branch_ten_god", "group", "natal_count", "stem_ten_god"),
    "tags/gongmang": _SHINSAL_DETAIL,
    "tags/yeokma": _SHINSAL_DETAIL,
    "tags/hwagae": _SHINSAL_DETAIL,
    "tags/dohwa": _SHINSAL_DETAIL,
    "tags/cheoneul_gwiin": _SHINSAL_DETAIL,
    "tags/gwiin_day": ("day_kind",),
    "tags/yongsin_day": ("day_kind",),
    "fortune/day_kind": ("day_kind", "group", "ten_god"),
    "fortune/tag": ("day_kind", "featured", "group", "ten_god"),
    "guide/question": ("basis", "ten_god"),
    # 원국 개인 해석 (D60)
    "personal/day_master": ("gisin", "strength", "yongsin"),
    "personal/ten_god": ("element", "group_count", "place", "role", "strength"),
    "personal/twelve_stage": ("element", "place", "role", "strength"),
    "personal/shinsal": ("element", "place", "role"),
    "personal/luck_ten_god": ("current", "element", "luck", "part", "role"),
    "personal/luck_twelve_stage": ("current", "element", "role"),
    # 용신 (spec 6.2)
    "yongsin/johu": ("month_branch", "share", "threshold"),
    "yongsin/johu_neutral": ("strength_level",),
    "yongsin/eokbu": ("strength_level", "strength_score"),
}


# source_ref가 빈 문자열(원전 없음)일 수 있는 규칙 (C28). 그 밖의 규칙은 늘 근거 원전 목록에 있는 source_ref를 낸다.
# 태그 선택 순서와 십성 몰림은 명리일기가 정한 규칙이고, 총운 보조 문장과 가이드 질문은 근거로 삼은 태그를 따른다.
RULES_WITHOUT_SOURCE: Final[frozenset[str]] = frozenset(
    {"tags/select", "tags/ten_god_rush", "fortune/tag", "guide/question"}
)


def require_rule(rule_id: str, detail: Mapping[str, str]) -> str:
    """등록된 rule_id만 통과시킨다. detail에 선언되지 않은 키가 있으면 KeyError."""
    if rule_id not in RULE_DETAIL_KEYS:
        raise KeyError(f"등록되지 않은 rule_id: {rule_id!r}")
    undeclared = set(detail) - set(RULE_DETAIL_KEYS[rule_id])
    if undeclared:
        raise KeyError(f"rule_id {rule_id!r}에 선언되지 않은 detail 키: {sorted(undeclared)}")
    return rule_id


def main() -> None:
    exported = {rule_id: list(keys) for rule_id, keys in sorted(RULE_DETAIL_KEYS.items())}
    print(json.dumps(exported, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

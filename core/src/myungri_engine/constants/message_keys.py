"""엔진이 쓸 수 있는 메시지 키의 유일한 목록 (spec §10).

형식은 소문자 스네이크 케이스를 점으로 구분한다. 문장은 콘텐츠 모듈이 갖는다(D27).
키마다 엔진이 넘기는 매개변수 이름도 여기서 함께 선언한다. 값 종류(렌더 방식)는 writing이 정한다.
`python -m myungri_engine.constants.message_keys`는 정렬된 키 목록 JSON을,
`python -m myungri_engine.constants.message_keys params`는 키별 매개변수 이름 JSON을 낸다.
"""

from __future__ import annotations

import json
import sys
from collections.abc import Iterable, Mapping

from myungri_engine.domain.enums import DayKind, TenGodGroup


def _lower(member: DayKind | TenGodGroup) -> str:
    return member.name.lower()


_DAY_KINDS = tuple(_lower(kind) for kind in DayKind)
_GROUPS = tuple(_lower(group) for group in TenGodGroup)

TAG_KEYS: frozenset[str] = frozenset(
    {
        "tag.big_change",
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


KEY_PARAMS: dict[str, tuple[str, ...]] = {
    **_declare((f"color.{kind}" for kind in _DAY_KINDS), ("element", "role")),
    **_declare((f"number.{kind}" for kind in _DAY_KINDS), ("number", "element")),
    **_declare(
        (f"direction.day_kind.{kind}" for kind in ("gwiin", "yongsin", "gisin", "ordinary")),
        ("direction", "rule_id"),
    ),
    **_declare(
        (f"focus_time.{reason}" for reason in ("gwiin", "yongsin", "huisin", "hap", "fallback")),
        ("branches", "score"),
    ),
    **_declare(TAG_KEYS, ()),
    **_declare((f"fortune.{kind}.{group}" for kind in _DAY_KINDS for group in _GROUPS), _FORTUNE_PARAMS),
    **_declare((f"fortune.tag.{_strip_tag_prefix(tag)}" for tag in TAG_KEYS), _FORTUNE_PARAMS),
    **_declare((f"guide.{_strip_tag_prefix(tag)}" for tag in TAG_KEYS), _GUIDE_PARAMS),
    **_declare((f"guide.ten_god.{group}" for group in _GROUPS), _GUIDE_PARAMS),
    **_declare(
        (f"yongsin.method.{method}" for method in ("johu", "johu_neutral", "eokbu")),
        ("yongsin", "huisin", "gisin", "tonggwan"),
    ),
    **_declare((f"calendar.{level}" for level in ("good", "neutral", "caution")), ("score",)),
}

ALL_KEYS: frozenset[str] = frozenset(KEY_PARAMS)


def require(key: str, params: Mapping[str, object] | None = None) -> str:
    """등록된 키만 통과시킨다. 매개변수 이름이 선언과 다르면 KeyError."""
    if key not in KEY_PARAMS:
        raise KeyError(f"등록되지 않은 메시지 키: {key!r}")
    declared = set(KEY_PARAMS[key])
    given = set(params or {})
    if given != declared:
        raise KeyError(f"메시지 키 {key!r}의 매개변수가 선언과 다릅니다: {sorted(given)} != {sorted(declared)}")
    return key


def main() -> None:
    if sys.argv[1:] == ["params"]:
        exported: object = {key: list(KEY_PARAMS[key]) for key in sorted(KEY_PARAMS)}
    else:
        exported = sorted(ALL_KEYS)
    print(json.dumps(exported, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

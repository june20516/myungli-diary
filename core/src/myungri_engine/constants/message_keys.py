"""엔진이 쓸 수 있는 메시지 키의 유일한 목록 (spec §10).

형식은 소문자 스네이크 케이스를 점으로 구분한다. 문장은 콘텐츠 모듈이 갖는다(D27).
`python -m myungri_engine.constants.message_keys`는 정렬된 키 목록 JSON을 낸다.
"""

from __future__ import annotations

import json

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


ALL_KEYS: frozenset[str] = frozenset(
    {
        *(f"color.{kind}" for kind in _DAY_KINDS),
        *(f"number.{kind}" for kind in _DAY_KINDS),
        *(f"direction.day_kind.{kind}" for kind in ("gwiin", "yongsin", "gisin", "ordinary")),
        *(f"focus_time.{reason}" for reason in ("gwiin", "yongsin", "huisin", "hap", "fallback")),
        *TAG_KEYS,
        *(f"fortune.{kind}.{group}" for kind in _DAY_KINDS for group in _GROUPS),
        *(f"fortune.tag.{_strip_tag_prefix(tag)}" for tag in TAG_KEYS),
        *(f"guide.{_strip_tag_prefix(tag)}" for tag in TAG_KEYS),
        *(f"guide.ten_god.{group}" for group in _GROUPS),
        *(f"yongsin.method.{method}" for method in ("johu", "johu_neutral", "eokbu")),
        *(f"calendar.{level}" for level in ("good", "neutral", "caution")),
    }
)


def require(key: str) -> str:
    """등록된 키만 통과시킨다. 등록되지 않았으면 KeyError."""
    if key not in ALL_KEYS:
        raise KeyError(f"등록되지 않은 메시지 키: {key!r}")
    return key


def main() -> None:
    print(json.dumps(sorted(ALL_KEYS), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

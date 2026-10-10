"""원국과 판정 결과의 값 객체. 모두 불변이다."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from types import MappingProxyType

from myungri_engine.domain.enums import Branch, NoticeCode, Stem


def _frozen_mapping[K, V](source: Mapping[K, V]) -> Mapping[K, V]:
    return MappingProxyType(dict(source))


@dataclass(frozen=True, slots=True)
class Pillar:
    stem: Stem
    branch: Branch


@dataclass(frozen=True, slots=True)
class FourPillars:
    year: Pillar
    month: Pillar
    day: Pillar
    hour: Pillar | None


@dataclass(frozen=True, slots=True)
class Evidence:
    rule_id: str
    source_ref: str
    detail: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        object.__setattr__(self, "detail", _frozen_mapping(self.detail))

    def __hash__(self) -> int:
        return hash((self.rule_id, self.source_ref, frozenset(self.detail.items())))


@dataclass(frozen=True, slots=True)
class Judgment:
    message_key: str
    params: Mapping[str, str | int | float | bool]
    evidence: tuple[Evidence, ...]

    def __post_init__(self) -> None:
        object.__setattr__(self, "params", _frozen_mapping(self.params))

    def __hash__(self) -> int:
        return hash((self.message_key, frozenset(self.params.items()), self.evidence))


@dataclass(frozen=True, slots=True)
class Notice:
    code: NoticeCode
    detail: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        object.__setattr__(self, "detail", _frozen_mapping(self.detail))

    def __hash__(self) -> int:
        return hash((self.code, frozenset(self.detail.items())))

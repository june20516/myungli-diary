"""원국 개인 해석 규칙. 용어 하나에 대한 Judgment(메시지 키 + 매개변수 + 근거)를 만든다.

문장은 콘텐츠 모듈이 갖는다(D27). 여기서는 용신 기준 역할과 자리만 풀어 매개변수로 넘긴다.
"""

from __future__ import annotations

from collections.abc import Mapping
from enum import Enum, auto
from typing import Literal

from myungri_engine.chart.positions import Position
from myungri_engine.constants.message_keys import require
from myungri_engine.domain.enums import Branch, Element, Shinsal, Stem, TenGod, TwelveStage
from myungri_engine.domain.models import Evidence, FourPillars, Judgment
from myungri_engine.references.loader import FIVE_ELEMENTS_REF
from myungri_engine.rules.group_count import natal_group_count
from myungri_engine.rules.strength import StrengthResult
from myungri_engine.rules.yongsin import YongsinResult

_Params = dict[str, str | int | float | bool]

LuckKind = Literal["DAEUN", "SEUN"]
PillarPart = Literal["STEM", "BRANCH"]


class PersonalRole(Enum):
    """오행이 원국의 용신 체계에서 맡는 역할. 데일리 컬러의 ElementRole과 값 집합이 다르다."""

    YONGSIN = auto()
    HUISIN = auto()
    GISIN = auto()
    NEUTRAL = auto()


def element_role(element: Element, yongsin: YongsinResult) -> PersonalRole:
    """용신, 희신, 기신 순서로 먼저 맞는 역할. 어디에도 맞지 않으면 NEUTRAL."""
    if element is yongsin.yongsin:
        return PersonalRole.YONGSIN
    if element is yongsin.huisin:
        return PersonalRole.HUISIN
    if element is yongsin.gisin:
        return PersonalRole.GISIN
    return PersonalRole.NEUTRAL


def _place(position: Position, hidden: bool = False) -> str:
    return f"{position.name}_HIDDEN" if hidden else position.name


def _detail_text(value: str | float | bool) -> str:
    """Evidence detail은 문자열이다. bool은 소문자 "true"/"false"로 쓴다."""
    return str(value).lower() if isinstance(value, bool) else str(value)


def _judgment(bundle: str, key: str, params: _Params, yongsin: YongsinResult) -> Judgment:
    detail: Mapping[str, str] = {name: _detail_text(value) for name, value in params.items()}
    rule_evidence = Evidence(
        rule_id=f"personal/{bundle}",
        source_ref=FIVE_ELEMENTS_REF["balance_principle"],
        detail=detail,
    )
    return Judgment(
        message_key=require(key, params), params=params, evidence=(rule_evidence, *yongsin.evidence)
    )


def day_master_reading(stem: Stem, strength: StrengthResult, yongsin: YongsinResult) -> Judgment:
    params: _Params = {
        "strength": strength.level.name,
        "yongsin": yongsin.yongsin.name,
        "gisin": yongsin.gisin.name,
    }
    return _judgment("day_master", f"personal.day_master.{stem.name.lower()}", params, yongsin)


def ten_god_reading(
    god: TenGod,
    position: Position,
    hidden: bool,
    stem: Stem,
    natal: FourPillars,
    strength: StrengthResult,
    yongsin: YongsinResult,
) -> Judgment:
    """지지 자리(지장간)는 정기 천간을 stem으로 넘긴다."""
    params: _Params = {
        "place": _place(position, hidden),
        "element": stem.element.name,
        "role": element_role(stem.element, yongsin).name,
        "group_count": natal_group_count(natal, god.group),
        "strength": strength.level.name,
    }
    return _judgment("ten_god", f"personal.ten_god.{god.name.lower()}", params, yongsin)


def twelve_stage_reading(
    stage: TwelveStage,
    position: Position,
    branch: Branch,
    strength: StrengthResult,
    yongsin: YongsinResult,
) -> Judgment:
    params: _Params = {
        "place": _place(position),
        "element": branch.element.name,
        "role": element_role(branch.element, yongsin).name,
        "strength": strength.level.name,
    }
    return _judgment("twelve_stage", f"personal.twelve_stage.{stage.name.lower()}", params, yongsin)


def shinsal_reading(kind: Shinsal, position: Position, branch: Branch, yongsin: YongsinResult) -> Judgment:
    params: _Params = {
        "place": _place(position),
        "element": branch.element.name,
        "role": element_role(branch.element, yongsin).name,
    }
    return _judgment("shinsal", f"personal.shinsal.{kind.name.lower()}", params, yongsin)


def luck_ten_god_reading(
    god: TenGod,
    luck: LuckKind,
    part: PillarPart,
    stem: Stem,
    current: bool,
    yongsin: YongsinResult,
) -> Judgment:
    """luck은 "DAEUN"·"SEUN", part는 "STEM"·"BRANCH". 지지는 정기 천간을 stem으로 넘긴다."""
    params: _Params = {
        "luck": luck,
        "part": part,
        "element": stem.element.name,
        "role": element_role(stem.element, yongsin).name,
        "current": current,
    }
    return _judgment("luck_ten_god", f"personal.luck.ten_god.{god.name.lower()}", params, yongsin)


def luck_twelve_stage_reading(
    stage: TwelveStage, branch: Branch, current: bool, yongsin: YongsinResult
) -> Judgment:
    params: _Params = {
        "element": branch.element.name,
        "role": element_role(branch.element, yongsin).name,
        "current": current,
    }
    return _judgment("luck_twelve_stage", f"personal.luck.twelve_stage.{stage.name.lower()}", params, yongsin)

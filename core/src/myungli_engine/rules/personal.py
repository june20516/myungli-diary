"""원국 개인 해석 규칙. 용어 하나에 대한 Judgment(메시지 키 + 매개변수 + 근거)를 만든다.

문장은 콘텐츠 모듈이 갖는다(D27). 여기서는 용신 기준 역할과 자리만 풀어 매개변수로 넘긴다.
"""

from __future__ import annotations

from collections.abc import Mapping
from enum import Enum, auto
from typing import Literal

from myungli_engine.chart.positions import Position
from myungli_engine.constants.message_keys import require
from myungli_engine.domain.enums import Branch, Element, Shinsal, Stem, TenGod, TwelveStage
from myungli_engine.domain.models import Evidence, FourPillars, Judgment
from myungli_engine.references import loader
from myungli_engine.rules.group_count import natal_group_count
from myungli_engine.rules.strength import StrengthResult
from myungli_engine.rules.yongsin import YongsinResult

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


def shinsal_ref(kind: Shinsal) -> str:
    """신살의 뜻을 다룬 원전. 양인은 개인 해석 원전, 나머지는 태그와 같은 조목(#998)."""
    if kind is Shinsal.YANGIN:
        return loader.PERSONAL_YANGIN_REF
    name = kind.name.lower()
    return loader.SHINSAL_SOURCE_REF.get(name) or loader.TAG_SOURCE_REF[name]


def _judgment(bundle: str, key: str, params: _Params, yongsin: YongsinResult, source_ref: str) -> Judgment:
    """규칙 근거의 원전은 그 용어의 뜻을 다룬 조목이다(#998). 자리와 역할의 원전은 규칙 지도에 적는다."""
    detail: Mapping[str, str] = {name: _detail_text(value) for name, value in params.items()}
    rule_evidence = Evidence(rule_id=f"personal/{bundle}", source_ref=source_ref, detail=detail)
    return Judgment(
        message_key=require(key, params), params=params, evidence=(rule_evidence, *yongsin.evidence)
    )


def day_master_reading(stem: Stem, strength: StrengthResult, yongsin: YongsinResult) -> Judgment:
    params: _Params = {
        "strength": strength.level.name,
        "yongsin": yongsin.yongsin.name,
        "gisin": yongsin.gisin.name,
    }
    key = f"personal.day_master.{stem.name.lower()}"
    return _judgment("day_master", key, params, yongsin, loader.PERSONAL_DAY_MASTER_REF)


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
    key = f"personal.ten_god.{god.name.lower()}"
    return _judgment("ten_god", key, params, yongsin, loader.ten_god_ref(god))


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
    key = f"personal.twelve_stage.{stage.name.lower()}"
    return _judgment("twelve_stage", key, params, yongsin, loader.PERSONAL_TWELVE_STAGE_REF)


def shinsal_reading(
    kind: Shinsal, position: Position, element: Element, yongsin: YongsinResult, part: str | None = None
) -> Judgment:
    """element는 대표 자리 글자(천간 또는 지지)의 오행이다. part는 구교만(GOU, JIAO, UNKNOWN, D124 ④)."""
    params: _Params = {
        "place": _place(position),
        "element": element.name,
        "role": element_role(element, yongsin).name,
    }
    if part is not None:
        params["part"] = part
    return _judgment("shinsal", f"personal.shinsal.{kind.name.lower()}", params, yongsin, shinsal_ref(kind))


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
    key = f"personal.luck.ten_god.{god.name.lower()}"
    return _judgment("luck_ten_god", key, params, yongsin, loader.LUCK_TEN_GOD_REF)


def luck_twelve_stage_reading(
    stage: TwelveStage, branch: Branch, current: bool, yongsin: YongsinResult
) -> Judgment:
    params: _Params = {
        "element": branch.element.name,
        "role": element_role(branch.element, yongsin).name,
        "current": current,
    }
    key = f"personal.luck.twelve_stage.{stage.name.lower()}"
    return _judgment("luck_twelve_stage", key, params, yongsin, loader.LUCK_TWELVE_STAGE_REF)

"""source_ref(`<자료 디렉터리>/<파일 이름>#<키 경로>`)를 패키지 데이터에서 찾는 로더."""

from __future__ import annotations

import json
from collections.abc import Iterable, Iterator, Mapping
from functools import cache
from importlib import resources
from typing import Final

from myungli_engine.constants.evidence_rules import RULES_WITHOUT_SOURCE
from myungli_engine.domain.enums import Branch, Stem, TenGod, TenGodGroup
from myungli_engine.domain.models import Evidence

# source_ref 접두어(자료 디렉터리 이름) → 패키지 데이터 디렉터리 이름
_DATA_PACKAGES: Final[Mapping[str, str]] = {
    "gungtong-bogam": "gungtong_bogam",
    "sammyeong-tonghoe": "sammyeong_tonghoe",
    "jeokcheonsu": "jeokcheonsu",
    "xieji-bianfang": "xieji_bianfang",
}
# 파일 이름 → JSON 안에서 키 경로가 시작되는 위치
_ROOT_KEYS: Final[Mapping[str, str]] = {"johu_evidence": "cells"}

FIVE_ELEMENTS_REF: Final[Mapping[str, str]] = {
    key: f"gungtong-bogam/five_elements#{key}" for key in ("color", "direction", "number", "balance_principle")
}

# 행운 색 변역(變易) 원전 (#937, C33). 『三命通會』 四庫全書本 卷一 「論五行」
COLOR_SHIFT_REF: Final[str] = "sammyeong-tonghoe/five_elements#color_change"


# 태그 판정 원전 (#804, C28). 키는 원전 항목 이름이고, 원전이 없는 태그는 여기 없다.
# 원문 대조 기록: core/docs/references/tag-sources-survey.md
TAG_SOURCE_REF: Final[Mapping[str, str]] = {
    **{
        key: f"sammyeong-tonghoe/tags#{key}"
        for key in (
            "stem_hap",
            "branch_hap",
            "clash",
            "clash_day_branch",
            "cheoneul_gwiin",
            "dohwa",
            "yeokma",
            "hwagae",
            "gongmang",
        )
    },
    "clash_month_branch": "jeokcheonsu/tags#clash_month_branch",
}


# 원국 개인 해석과 십성 묶음 문장의 원전 (#998). 원문 대조 기록: core/docs/references/README.md
# 比肩과 劫財는 따로 다룬 조목이 없어 『三命通會』 「論建禄」을 함께 쓴다.
_GEONROK_REF: Final = "sammyeong-tonghoe/personal#ten_god.geonrok"
PERSONAL_DAY_MASTER_REF: Final = "jeokcheonsu/personal#day_master"
PERSONAL_TWELVE_STAGE_REF: Final = "sammyeong-tonghoe/personal#twelve_stage"
PERSONAL_YANGIN_REF: Final = "sammyeong-tonghoe/personal#yangin"
LUCK_TEN_GOD_REF: Final = "sammyeong-tonghoe/personal#luck.ten_god"
LUCK_TWELVE_STAGE_REF: Final = "sammyeong-tonghoe/personal#luck.twelve_stage"


# 집중 시간(시진 고르기) 원전 (#980, D122). 『欽定協紀辨方書』 四庫全書本. 원문 대조: core/docs/references/hour-sources-survey.md
FOCUS_TIME_REF: Final[Mapping[str, str]] = {
    key: f"xieji-bianfang/hours#{key}" for key in ("use_hour", "birth_year", "huangdao")
}


def ten_god_ref(god: TenGod) -> str:
    if god in (TenGod.BIGYEON, TenGod.GEOPJAE):
        return _GEONROK_REF
    return f"sammyeong-tonghoe/personal#ten_god.{god.name.lower()}"


def ten_god_group_ref(group: TenGodGroup) -> str:
    if group is TenGodGroup.BIGYEOP:
        return _GEONROK_REF
    return f"sammyeong-tonghoe/personal#ten_god_group.{group.name.lower()}"


def personal_refs() -> Iterator[str]:
    """개인 해석과 십성 묶음 문장이 낼 수 있는 원전(중복 없이)."""
    refs = {ten_god_ref(god) for god in TenGod} | {ten_god_group_ref(group) for group in TenGodGroup}
    refs |= {
        PERSONAL_DAY_MASTER_REF,
        PERSONAL_TWELVE_STAGE_REF,
        PERSONAL_YANGIN_REF,
        LUCK_TEN_GOD_REF,
        LUCK_TWELVE_STAGE_REF,
    }
    yield from sorted(refs)


def johu_ref(stem: Stem, branch: Branch) -> str:
    return f"gungtong-bogam/johu_evidence#{stem.hanja}.{branch.hanja}"


def all_refs() -> Iterator[str]:
    """엔진이 낼 수 있는 모든 source_ref: 조후 120칸, 오행 근거, 색 변역 원전, 태그 원전, 개인 해석 원전, 시진 원전 전부."""
    yield from (johu_ref(stem, branch) for stem in Stem for branch in Branch)
    yield from FIVE_ELEMENTS_REF.values()
    yield COLOR_SHIFT_REF
    yield from TAG_SOURCE_REF.values()
    yield from personal_refs()
    yield from FOCUS_TIME_REF.values()


@cache
def _load_json(directory: str, file_name: str) -> object:
    package = _DATA_PACKAGES.get(directory)
    if package is None:
        raise KeyError(f"알 수 없는 자료 디렉터리: {directory}")
    path = resources.files("myungli_engine.references").joinpath("data", package, f"{file_name}.json")
    if not path.is_file():
        raise KeyError(f"자료 파일이 없습니다: {directory}/{file_name}")
    loaded: object = json.loads(path.read_text(encoding="utf-8"))
    return loaded


def resolve(source_ref: str) -> object:
    """source_ref가 가리키는 JSON 값을 반환한다. 찾을 수 없으면 KeyError."""
    location, separator, key_path = source_ref.partition("#")
    directory, slash, file_name = location.partition("/")
    if not (separator and slash and key_path):
        raise KeyError(f"source_ref 형식이 올바르지 않습니다: {source_ref}")

    node = _load_json(directory, file_name)
    root_key = _ROOT_KEYS.get(file_name)
    keys = ([root_key] if root_key else []) + key_path.split(".")
    for key in keys:
        if not isinstance(node, dict) or key not in node:
            raise KeyError(f"source_ref를 찾을 수 없습니다: {source_ref}")
        node = node[key]
    return node


def validate_evidence_refs(evidence: Iterable[Evidence]) -> None:
    """근거의 source_ref를 확인한다. 빈 값(원전 없음)은 그럴 수 있는 규칙(C28)에서만 받는다. 어기면 KeyError."""
    for item in evidence:
        if item.source_ref:
            resolve(item.source_ref)
        elif item.rule_id not in RULES_WITHOUT_SOURCE:
            raise KeyError(f"원전이 있어야 하는 규칙의 source_ref가 비었습니다: {item.rule_id}")


def validate_refs(refs: Iterable[str]) -> None:
    """하나라도 찾을 수 없으면 KeyError."""
    for ref in refs:
        resolve(ref)

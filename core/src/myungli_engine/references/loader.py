"""source_ref(`<자료 디렉터리>/<파일 이름>#<키 경로>`)를 패키지 데이터에서 찾는 로더."""

from __future__ import annotations

import json
from collections.abc import Iterable, Iterator, Mapping
from functools import cache
from importlib import resources
from typing import Final

from myungli_engine.domain.enums import Branch, Stem

# source_ref 접두어(자료 디렉터리 이름) → 패키지 데이터 디렉터리 이름
_DATA_PACKAGES: Final[Mapping[str, str]] = {"gungtong-bogam": "gungtong_bogam"}
# 파일 이름 → JSON 안에서 키 경로가 시작되는 위치
_ROOT_KEYS: Final[Mapping[str, str]] = {"johu_evidence": "cells"}

FIVE_ELEMENTS_REF: Final[Mapping[str, str]] = {
    key: f"gungtong-bogam/five_elements#{key}" for key in ("color", "direction", "number", "balance_principle")
}


def johu_ref(stem: Stem, branch: Branch) -> str:
    return f"gungtong-bogam/johu_evidence#{stem.hanja}.{branch.hanja}"


def all_refs() -> Iterator[str]:
    """엔진이 낼 수 있는 모든 source_ref: 조후 120칸과 오행 근거 전부."""
    yield from (johu_ref(stem, branch) for stem in Stem for branch in Branch)
    yield from FIVE_ELEMENTS_REF.values()


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


def validate_refs(refs: Iterable[str]) -> None:
    """하나라도 찾을 수 없으면 KeyError."""
    for ref in refs:
        resolve(ref)

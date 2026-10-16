"""엔진이 낼 수 있는 source_ref마다 원전 이름·대목·원문을 모은 목록 (#130).

`python -m myungli_engine.references.sources`는 source_ref별 항목 JSON을 낸다.
* work: 원전 이름(한자)
* section: 대목 이름. 조후는 원문 항목 제목(예: 正月甲), 오행 근거는 五行總論
* quote: 인용할 대표 문장(조후는 첫 문장 key_sentence, 오행 근거는 인용문 전체)
* passage: 대목 원문 문단 목록
* evidence_level: 조후만. month(그 달 항목) 또는 season(계절 총론으로 대신함)
* note: 원문 근거가 아닌 점 같은 주의 사항(한국어). 없으면 null
"""

from __future__ import annotations

import json
from typing import Final

from myungli_engine.domain.enums import Branch, Stem
from myungli_engine.references import loader

WORK_GUNGTONG_BOGAM: Final = "窮通寶鑑"
SECTION_FIVE_ELEMENTS: Final = "五行總論"

type SourceEntry = dict[str, str | list[str] | None]


def source_catalog() -> dict[str, SourceEntry]:
    catalog: dict[str, SourceEntry] = {}
    for stem in Stem:
        for branch in Branch:
            ref = loader.johu_ref(stem, branch)
            catalog[ref] = _johu_entry(_as_dict(loader.resolve(ref)))
    for ref in loader.FIVE_ELEMENTS_REF.values():
        catalog[ref] = _five_elements_entry(_as_dict(loader.resolve(ref)))
    return catalog


def _johu_entry(cell: dict[str, object]) -> SourceEntry:
    return {
        "work": WORK_GUNGTONG_BOGAM,
        "section": str(cell["heading"]),
        "quote": str(cell["key_sentence"]),
        "passage": [str(paragraph) for paragraph in _as_list(cell["paragraphs"])],
        "evidence_level": str(cell["evidence_level"]),
        "note": None,
    }


def _five_elements_entry(item: dict[str, object]) -> SourceEntry:
    quote = str(item["quote"])
    note = item.get("note")
    return {
        "work": WORK_GUNGTONG_BOGAM,
        "section": SECTION_FIVE_ELEMENTS,
        "quote": quote,
        "passage": [quote],
        "evidence_level": None,
        "note": None if note is None else str(note),
    }


def _as_dict(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise TypeError(f"근거 항목이 객체가 아닙니다: {type(value).__name__}")
    return value


def _as_list(value: object) -> list[object]:
    if not isinstance(value, list):
        raise TypeError(f"근거 문단이 목록이 아닙니다: {type(value).__name__}")
    return value


def main() -> None:
    print(json.dumps(dict(sorted(source_catalog().items())), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

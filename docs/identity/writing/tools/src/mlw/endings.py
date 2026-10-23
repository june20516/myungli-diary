"""맺음 현황(W43): ko 원고의 문장 끝을 해요체·합니다체·그 밖으로 나눠 화면별로 셉니다.

검사가 아니라 보고입니다. 맺음은 쓸 때 문장마다 고르고, 화면이나 슬롯에 한 맺음을 정하지 않습니다.
"""

from collections import Counter
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Literal

import regex

from mlw.ia import Ia, placements
from mlw.model import Entry, Slot

EndingKind = Literal["haeyo", "hamnida", "other"]
ENDING_KINDS: tuple[EndingKind, ...] = ("haeyo", "hamnida", "other")
KIND_LABELS: dict[EndingKind, str] = {"haeyo": "해요체", "hamnida": "합니다체", "other": "그 밖"}
# IA 화면 슬롯에 놓이지 않는 공용 문구(오류·버튼·접근성 이름 등)를 모으는 이름입니다.
COMMON_SCREEN = "(공용)"
REPORT_LANG = "ko"

# 문장 끝 구두점 뒤 공백에서 나눕니다.
SENTENCE_BREAK = regex.compile(r"(?<=[.?!])\s+")
# 문장 끝의 닫는 따옴표·괄호는 맺음 판단에서 뺍니다.
TRAILING = regex.compile(r"[.?!\s\"'”’)\]」』]+$")
HAMNIDA_END = regex.compile(r"(니다|니까)$")
HAEYO_END = regex.compile(r"(요|죠)$")


@dataclass(frozen=True)
class EndingRow:
    screen: str
    slot: str
    key: str
    sentence: str
    kind: EndingKind


def split_sentences(text: str) -> list[str]:
    return [part for part in SENTENCE_BREAK.split(text.strip()) if part]


def classify(sentence: str) -> EndingKind:
    core = TRAILING.sub("", sentence)
    if HAMNIDA_END.search(core):
        return "hamnida"
    if HAEYO_END.search(core):
        return "haeyo"
    return "other"


def _screens(slot: Slot | None, ia: Ia) -> list[str]:
    if slot is None:
        return [COMMON_SCREEN]
    screens = list(dict.fromkeys(ia.screens[place] for place in placements(slot, ia) if place in ia.screens))
    return screens or [COMMON_SCREEN]


def ending_rows(entries: Iterable[Entry], slots: Mapping[str, Slot], ia: Ia) -> list[EndingRow]:
    """ko 원고를 문장 하나씩, 그 문장이 놓이는 화면마다 한 줄로 펼칩니다."""
    rows: list[EndingRow] = []
    for entry in entries:
        if entry.lang != REPORT_LANG:
            continue
        for screen in _screens(slots.get(entry.slot), ia):
            for sentence in split_sentences(entry.text):
                rows.append(EndingRow(screen, entry.slot, entry.key, sentence, classify(sentence)))
    return rows


def screen_counts(rows: Iterable[EndingRow]) -> dict[str, Counter[EndingKind]]:
    counts: dict[str, Counter[EndingKind]] = {}
    for row in rows:
        counts.setdefault(row.screen, Counter())[row.kind] += 1
    return counts

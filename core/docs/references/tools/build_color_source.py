"""행운 색 변역(變易) 원전 근거 JSON 생성기 (#937).

저장한 『三命通會』 四庫全書本 卷一(`sammyeong-tonghoe/skqs-vol01.wikitext`, 수정 금지)의
「論五行」에서 "推其形色"부터 "旺墓從子色"까지를 뽑아
`core/src/myungli_engine/references/data/sammyeong_tonghoe/five_elements.json`을 만든다.

* quote: 작은 주(`{{SK notes|…}}`)를 뺀 본문. 원문 글자는 바꾸지 않는다(구두점 없음).
* passage: 같은 대목에서 작은 주를 （ ） 안에 넣은 한 문단.

저장소 루트에서 실행한다.
    python3 -I core/docs/references/tools/build_color_source.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

REFERENCES = Path(__file__).resolve().parents[1]
SOURCE_FILE = "sammyeong-tonghoe/skqs-vol01.wikitext"
OUT = (
    REFERENCES.parents[1]
    / "src"
    / "myungli_engine"
    / "references"
    / "data"
    / "sammyeong_tonghoe"
    / "five_elements.json"
)

START = "推其形色"
END_AFTER = "旺墓從子色"
_NOTE = re.compile(r"\{\{SK ?notes\|([^}]*)\}\}")
_ANCHOR = re.compile(r"\{\{SK ?anchor\|([^}]+)\}\}")

NOTE = (
    "四庫全書本은 구두점이 없고 작은 주가 본문 사이에 있다. 원문은 12운성 열둘을 다 적지 않았다. "
    "명리일기는 長生, 臨官, 帝旺을 正色, 死와 絶을 母色, 胎, 養(成形), 冠帶, 衰를 妻色, 沐浴(敗)과 病을 鬼色, 墓를 子色으로 본다. "
    '臨官과 胎는 원문에 없어 명리일기가 정했고, 衰는 주의 "衰老之際"를 따랐으며, 帝旺은 生旺과 旺墓에 함께 걸려 生旺 쪽으로 읽었다. '
    "오행의 12운성은 양간(甲丙戊庚壬)으로 보고, 土는 火와 같이 본다. 같은 대목이 『五行精紀』(출처 표시 『燭神經』), 『古今圖書集成』 藝術典 595권, 『窮通寶鑑』 「五行總論」(주 없음)에도 있다."
)


def _flat(text: str) -> str:
    return re.sub(r"\s+", "", text)


def extract(raw: str) -> tuple[str, str, str]:
    """(조목 이름, 작은 주를 뺀 본문, 작은 주를 괄호에 넣은 본문)."""
    start = raw.index(START)
    end = raw.index(END_AFTER, start) + len(END_AFTER)
    following_note = _NOTE.match(raw, end)
    if following_note:
        end = following_note.end()
    block = raw[start:end]
    section = _ANCHOR.findall(raw[:start])[-1]
    quote = _flat(_NOTE.sub("", block))
    passage = _flat(_NOTE.sub(lambda m: f"（{m.group(1)}）", block))
    return section, quote, passage


def build() -> dict[str, object]:
    raw = (REFERENCES / SOURCE_FILE).read_text(encoding="utf-8")
    section, quote, passage = extract(raw)
    if not quote.endswith(END_AFTER) or "金白" not in quote:
        raise ValueError(f"대목을 잘못 뽑았습니다: {quote}")
    return {
        "color_change": {
            "work": "三命通會",
            "section": section,
            "quote": quote,
            "passage": [passage],
            "source_file": SOURCE_FILE,
            "note": NOTE,
        }
    }


def main() -> None:
    OUT.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(REFERENCES.parents[2])}")


if __name__ == "__main__":
    main()

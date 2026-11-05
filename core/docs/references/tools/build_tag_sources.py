"""태그 판정 원전 근거 JSON 생성기 (#804).

저장한 위키문헌 원문(`<자료>/*.wikitext`, 수정 금지)에서 조목 문단을 뽑아
`core/src/myungli_engine/references/data/<자료>/tags.json`을 만든다.
인용(quote)이 뽑은 문단에 글자 그대로 없으면 멈춘다. 원문 글자는 바꾸지 않는다(간체·번체 변환 없음).

문단 규칙
* 三命通會: `==제목==` 절 안에서 빈 줄로 나뉜 덩어리가 한 문단. 위키문헌 수집본이 문장 중간에서
  줄을 바꿔 두었으므로 덩어리 안의 줄은 구분자 없이 잇는다.
* 滴天髓: 원문 줄(`{{color|red|{{+|...}}}}`)과 주석 줄(`:　　...`)이 각각 한 문단. 틀과 들여쓰기만 벗긴다.

저장소 루트에서 실행한다.
    python3 -I core/docs/references/tools/build_tag_sources.py
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

REFERENCES = Path(__file__).resolve().parents[1]
DATA = REFERENCES.parents[1] / "src" / "myungli_engine" / "references" / "data"

WORK_SAMMYEONG: str = "三命通會"
WORK_JEOKCHEONSU: str = "滴天髓"

_RED_LINE = re.compile(r"^\{\{color\|red\|\{\{\+\|(?P<text>.*)\}\}\}\}$")
_COMMENT_LINE = re.compile(r"^:[　 ]*(?P<text>.+)$")


@dataclass(frozen=True)
class Entry:
    key: str
    directory: str
    file: str
    section: str
    paragraphs: tuple[int, ...]
    quote: str
    note: str | None = None


ENTRIES: tuple[Entry, ...] = (
    Entry("stem_hap", "sammyeong-tonghoe", "vol2", "论十干合", (0,),
          "唯阴见阳，阳见阴为合，亦如男女相合而成夫妇之道。"),
    Entry("branch_hap", "sammyeong-tonghoe", "vol2", "论支元六合", (0,),
          "夫合者，和也，乃阴阳相和，其气自合。",
          note="원문 표기는 巳 자리에 已가 쓰여 있다(丑卯已未, 수집본 그대로)."),
    Entry("clash", "sammyeong-tonghoe", "vol2", "论冲击", (0,),
          "相冲者，十二支战击之神，大概为凶。"),
    Entry("clash_day_branch", "sammyeong-tonghoe", "vol2", "论年月日时", (3,),
          "伤日不利己身，名折腰煞",
          note="원문은 충(冲) 대신 상함(伤)을 쓴다. 일주 자리가 상하면 나 자신에게 이롭지 않다는 자리(궁위) 원문이다. 같은 조목의 둘째 문단은 태세(年)를 두고 \"冲破为伤\"이라 하여 충과 파를 상함으로 본다."),
    Entry("cheoneul_gwiin", "sammyeong-tonghoe", "vol3", "论天乙贵人", (0,),
          "其神最尊贵，所至之处，一切凶煞隐然而避。"),
    Entry("dohwa", "sammyeong-tonghoe", "vol2", "论咸池", (0,),
          "寅午戌卯、已酉丑午、申子辰酉、亥卯未子即长生第二位沐浴之宫是也。一名败神，一名桃花煞",
          note="원문 표기는 巳 자리에 已가 쓰여 있다(수집본 그대로)."),
    Entry("yeokma", "sammyeong-tonghoe", "vol3", "论驿马", (0,),
          "所谓驿马者，乃先天三合数也",
          note="문단 안의 甲子辰은 申子辰의 오기로 보인다(수집본 그대로)."),
    Entry("hwagae", "sammyeong-tonghoe", "vol2", "论将星华盖", (0,),
          "故以三合底处得库谓之华盖。",
          note="같은 문장의 앞부분은 华盖를 化盖로 적었다(수집본 그대로)."),
    Entry("gongmang", "sammyeong-tonghoe", "vol3", "论空亡", (0,),
          "故以甲旬尽处曰空亡，盖有是位而无禄，曰空；有支而无干，曰亡。",
          note="문단 안의 《珞??录子》는 수집본에서 글자가 깨진 것으로, 같은 권의 다른 곳에는 珞琭子로 적혀 있다(수집본 그대로)."),
    Entry("clash_month_branch", "jeokcheonsu", "ch17", "月令論", (0, 1),
          "月令提綱，譬之宅也，人元用事之神，宅之向也，不可以不卜。",
          note="충을 직접 말한 조목이 아니라, 월령(월지)이 명의 가장 중요한 자리라는 원문이다."),
)

_WORKS = {"sammyeong-tonghoe": WORK_SAMMYEONG, "jeokcheonsu": WORK_JEOKCHEONSU}


def sammyeong_paragraphs(text: str, heading: str) -> list[str]:
    marker = f"=={heading}=="
    start = text.index(marker) + len(marker)
    end = text.find("\n==", start)
    body = text[start:] if end == -1 else text[start:end]
    blocks = re.split(r"\n\s*\n", body)
    return ["".join(line.strip() for line in block.splitlines()) for block in blocks if block.strip()]


def jeokcheonsu_paragraphs(text: str) -> list[str]:
    start = text.index("<onlyinclude>") + len("<onlyinclude>")
    end = text.index("</onlyinclude>")
    paragraphs: list[str] = []
    for line in text[start:end].splitlines():
        line = line.strip()
        red = _RED_LINE.match(line)
        comment = _COMMENT_LINE.match(line)
        if red:
            paragraphs.append(red.group("text"))
        elif comment:
            paragraphs.append(comment.group("text"))
    return paragraphs


def paragraphs_of(entry: Entry) -> list[str]:
    text = (REFERENCES / entry.directory / f"{entry.file}.wikitext").read_text(encoding="utf-8")
    if entry.directory == "jeokcheonsu":
        return jeokcheonsu_paragraphs(text)
    return sammyeong_paragraphs(text, entry.section)


def build_entry(entry: Entry) -> dict[str, object]:
    found = paragraphs_of(entry)
    passage = [found[index] for index in entry.paragraphs]
    if not any(entry.quote in paragraph for paragraph in passage):
        raise ValueError(f"{entry.key}: 인용이 원문 문단에 없습니다: {entry.quote}")
    return {
        "work": _WORKS[entry.directory],
        "section": entry.section,
        "quote": entry.quote,
        "passage": passage,
        "source_file": f"{entry.directory}/{entry.file}.wikitext",
        "note": entry.note,
    }


def main() -> None:
    by_directory: dict[str, dict[str, object]] = {}
    for entry in ENTRIES:
        by_directory.setdefault(entry.directory, {})[entry.key] = build_entry(entry)
    for directory, entries in by_directory.items():
        out = DATA / directory.replace("-", "_") / "tags.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{out.relative_to(REFERENCES.parents[2])}: {len(entries)}개")


if __name__ == "__main__":
    main()

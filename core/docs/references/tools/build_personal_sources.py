"""원국 개인 해석과 십성 묶음 문장의 원전 근거 JSON 생성기 (#998).

저장한 위키문헌 원문(수정 금지)에서 조목의 대표 문장을 뽑아 다음 두 파일을 만든다.
* `core/src/myungli_engine/references/data/sammyeong_tonghoe/personal.json` (『三命通會』 四庫全書本)
* `core/src/myungli_engine/references/data/jeokcheonsu/personal.json` (『滴天髓』)

* 四庫全書本: 공백을 지운 원문에서 start부터 end_after까지를 인용(quote)으로 둔다. 작은 주(`{{SKnotes|…}}`)는 뺀다.
  조목 이름(section)은 `{{SK anchor|…}}`가 없는 조목도 있어 항목마다 적고, 원문에서 인용보다 앞에 있어야 한다.
* 滴天髓: 붉은 글씨 본문 줄과 그 주석 줄을 한 문단씩 passage에 두고, 인용은 주석 줄에서 뽑는다.
원문 글자는 바꾸지 않는다(오자도 그대로 두고 note에 밝힌다).

저장소 루트에서 실행한다.
    python3 -I core/docs/references/tools/build_personal_sources.py
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

REFERENCES = Path(__file__).resolve().parents[1]
DATA = REFERENCES.parents[1] / "src" / "myungli_engine" / "references" / "data"

_NOTE = re.compile(r"\{\{SK ?notes\|[^}]*\}\}")
_RED_LINE = re.compile(r"^\{\{color\|red\|\{\{\+\|(?P<text>.*)\}\}\}\}$")
_COMMENT_LINE = re.compile(r"^:[　 ]*(?P<text>.+)$")


@dataclass(frozen=True)
class Entry:
    key: str  # JSON 안 경로(점으로 구분)
    file: str  # REFERENCES 아래 경로
    section: str
    start: str
    end_after: str
    note: str | None = None


SAMMYEONG: tuple[Entry, ...] = (
    Entry("ten_god.jeonggwan", "sammyeong-tonghoe/skqs-vol05.wikitext", "論正官",
          "正官者乃甲見辛", "成其道也"),
    Entry("ten_god.pyeongwan", "sammyeong-tonghoe/skqs-vol05.wikitext", "論偏官",
          "故有制謂之偏官", "無制謂之七煞"),
    Entry("ten_god.jeongjae", "sammyeong-tonghoe/skqs-vol05.wikitext", "論正財",
          "正財之格主人誠實", "惟有慳吝"),
    Entry("ten_god.pyeonjae", "sammyeong-tonghoe/skqs-vol05.wikitext", "論偏財",
          "偏財格主人慷慨", "與人有情而多詐"),
    Entry("ten_god.jeongin", "sammyeong-tonghoe/skqs-vol05.wikitext", "論印綬",
          "此格主聰明多智慧", "體貎豐厚"),
    Entry("ten_god.pyeonin", "sammyeong-tonghoe/skqs-vol05.wikitext", "論倒食",
          "倒食即偏印之謂", "食神最忌見之",
          note="원문은 偏印을 倒食(吞啖煞)이라는 이름으로 다룬다."),
    Entry("ten_god.sanggwan", "sammyeong-tonghoe/skqs-vol05.wikitext", "論傷官",
          "此格主多材藝", "弄巧成拙"),
    Entry("ten_god.siksin", "sammyeong-tonghoe/skqs-vol05.wikitext", "論食神",
          "主人財厚食豐", "有子息有夀考",
          note="四庫全書本 수집본은 論食神에 조목 표지(anchor)가 없고 본문 제목 글자만 있다."),
    Entry("ten_god.geonrok", "sammyeong-tonghoe/skqs-vol05.wikitext", "論建禄",
          "余按陽刃比肩敗財建禄", "實一家同氣之神",
          note="比肩과 劫財(敗財)는 따로 다룬 조목이 없고, 陽刃, 建禄과 같은 기운으로 묶어 말한다. 명리일기는 比肩, 劫財 둘에 이 조목을 쓴다."),
    Entry("ten_god_group.inseong", "sammyeong-tonghoe/skqs-vol05.wikitext", "論古人立印食官財名義",
          "生我者有父母之義", "故立名印綬"),
    Entry("ten_god_group.siksang", "sammyeong-tonghoe/skqs-vol05.wikitext", "論古人立印食官財名義",
          "我生者有子孫之義", "故立名食神"),
    Entry("ten_god_group.gwanseong", "sammyeong-tonghoe/skqs-vol05.wikitext", "論古人立印食官財名義",
          "尅我者我受制於人之義", "故立名官煞"),
    Entry("ten_god_group.jaeseong", "sammyeong-tonghoe/skqs-vol05.wikitext", "論古人立印食官財名義",
          "我尅者是人受制於我之義", "故立名妻財"),
    Entry("twelve_stage", "sammyeong-tonghoe/skqs-vol02.wikitext", "論五行旺相休囚死並寄生十二宫",
          "夫五行寄生十二官", "亦若人世輪迴也",
          note="원문은 十二宫을 이 문장에서 十二官으로 적었다(수집본 그대로). 같은 조목이 이어서 단계마다 사람의 일생에 빗댄 뜻을 적는다."),
    Entry("yangin", "sammyeong-tonghoe/skqs-vol03.wikitext", "論羊刃",
          "羊言剛也", "祿過則刃生"),
    Entry("luck.ten_god", "sammyeong-tonghoe/skqs-vol02.wikitext", "論大運",
          "官欲運生不欲運傷", "食欲運生不欲運梟絶"),
    Entry("luck.twelve_stage", "sammyeong-tonghoe/skqs-vol02.wikitext", "論大運",
          "凡行運長生主有創建", "發福進財"),
)

JEOKCHEONSU: tuple[Entry, ...] = (
    Entry("day_master", "jeokcheonsu/ch12.wikitext", "衰旺論",
          "旺則宜洩宜傷", "子平之理也",
          note="본문 줄(能知衰旺之真機…)과 그 주석 줄이 passage이고, 인용은 주석 줄의 첫 문장이다."),
)


def _flat(text: str) -> str:
    return re.sub(r"\s+", "", text)


def _skqs(entry: Entry) -> dict[str, object]:
    text = _flat(_NOTE.sub("", (REFERENCES / entry.file).read_text(encoding="utf-8")))
    start = text.index(entry.start)
    end = text.index(entry.end_after, start) + len(entry.end_after)
    quote = text[start:end]
    section_at = text.rfind(entry.section, 0, start)
    if section_at < 0:
        raise ValueError(f"{entry.key}: 인용 앞에 조목 이름 {entry.section}이 없습니다")
    return {"work": "三命通會", "section": entry.section, "quote": quote, "passage": [quote],
            "source_file": entry.file, "note": entry.note}


def _jeokcheonsu(entry: Entry) -> dict[str, object]:
    lines = (REFERENCES / entry.file).read_text(encoding="utf-8").splitlines()
    comment_index = next(i for i, line in enumerate(lines) if entry.start in line)
    red = _RED_LINE.match(lines[comment_index - 2].strip()) or _RED_LINE.match(lines[comment_index - 1].strip())
    comment = _COMMENT_LINE.match(lines[comment_index])
    if red is None or comment is None:
        raise ValueError(f"{entry.key}: 본문 줄과 주석 줄을 찾지 못했습니다")
    body = comment.group("text").strip()
    start = body.index(entry.start)
    quote = body[start: body.index(entry.end_after, start) + len(entry.end_after)]
    return {"work": "滴天髓", "section": entry.section, "quote": quote,
            "passage": [red.group("text").strip(), body], "source_file": entry.file, "note": entry.note}


def _nest(items: dict[str, dict[str, object]]) -> dict[str, object]:
    root: dict[str, object] = {}
    for key, value in items.items():
        node = root
        *parents, leaf = key.split(".")
        for part in parents:
            child = node.setdefault(part, {})
            assert isinstance(child, dict)
            node = child
        node[leaf] = value
    return root


def build() -> dict[str, dict[str, object]]:
    return {
        "sammyeong_tonghoe": _nest({entry.key: _skqs(entry) for entry in SAMMYEONG}),
        "jeokcheonsu": _nest({entry.key: _jeokcheonsu(entry) for entry in JEOKCHEONSU}),
    }


def main() -> None:
    for directory, data in build().items():
        out = DATA / directory / "personal.json"
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(out.relative_to(REFERENCES.parents[2]))


if __name__ == "__main__":
    main()

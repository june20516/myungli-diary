"""조목 인용 원전 근거 JSON 생성기: 개인 해석과 십성 묶음(#998), 집중 시간(#980, D122), 신살과 택일 덕일(D124, #1028).

저장한 위키문헌 원문(수정 금지)에서 조목의 대표 문장을 뽑아 다음 파일을 만든다.
* `core/src/myungli_engine/references/data/sammyeong_tonghoe/personal.json` (『三命通會』 四庫全書本)
* `core/src/myungli_engine/references/data/jeokcheonsu/personal.json` (『滴天髓』)
* `core/src/myungli_engine/references/data/xieji_bianfang/hours.json` (『欽定協紀辨方書』 四庫全書本)
* `core/src/myungli_engine/references/data/sammyeong_tonghoe/shinsal.json` (D124 신살과 흉한 신살 마무리 문장)
* `core/src/myungli_engine/references/data/xingxue_dacheng/shinsal.json` (『星學大成』 四庫全書本, 암록)
* `core/src/myungli_engine/references/data/xieji_bianfang/days.json` (택일 천덕일, 월덕일)

* 四庫全書本: 공백을 지운 원문에서 start부터 end_after까지를 인용(quote)으로 둔다. 작은 주(`{{SKnotes|…}}`)는 뺀다.
  조목 이름(section)은 `{{SK anchor|…}}`가 없는 조목도 있어 항목마다 적고, 원문에서 인용보다 앞에 있어야 한다.
  in_note인 항목은 작은 주 안의 글을 인용한다(작은 주를 빼지 않은 원문에서 찾음).
* 滴天髓: 붉은 글씨 본문 줄과 그 주석 줄을 한 문단씩 passage에 두고, 인용은 주석 줄에서 뽑는다.
원문 글자는 바꾸지 않는다(오자도 그대로 두고 note에 밝힌다).

저장소 루트에서 실행한다.
    python3 -I core/docs/references/tools/build_quoted_sources.py
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
    work: str = "三命通會"
    in_note: bool = False


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

XIEJI = "欽定協紀辨方書"
XIEJI_BIANFANG: tuple[Entry, ...] = (
    Entry("use_hour", "xieji-bianfang/skqs-vol34.wikitext", "用時法",
          "時者日之用也", "惟貴人禄馬為吉", work=XIEJI,
          note="같은 조목이 이어서 時破(일지와 충)를 大凶, 時刑과 五不遇를 次凶으로 둔다. 卷三十二 「日表」는 \"時由日筦選時必根扵日\"(시는 날이 맡는다)이라 한다."),
    Entry("birth_year", "xieji-bianfang/skqs-vol33.wikitext", "論相主",
          "古人皆論生年之天干", "不衝命尅命", work=XIEJI,
          note="택일에서 고른 사주를 주인의 명에 맞추는(相主) 조목이다. 같은 조목은 사람 기준을 生年으로 본다(從來皆論生年不論生日)."),
    Entry("huangdao", "xieji-bianfang/skqs-vol07.wikitext", "黄道黒道",
          "日起時則子日申時起青龍", "依次順數", work=XIEJI),
)

_V3 = "sammyeong-tonghoe/skqs-vol03.wikitext"
SHINSAL: tuple[Entry, ...] = (
    Entry(
        "cheondeok",
        _V3,
        "論天月徳",
        "此十二位宫",
        "乃曰天徳也",
        note='천덕은 태어난 달마다 정해진 천간 또는 괘다. 坤乾艮巽은 같은 조목의 "寅中有艮巳中有巽申中有坤亥中有乾"에 따라 申亥寅巳 지지로 본다. 같은 조목은 "凡命中帶㓙煞得此二徳扶化㓙不為甚"이라 한다.',
    ),
    Entry(
        "woldeok",
        _V3,
        "論天月徳",
        "月徳者乃三合所照之方",
        "謂之月徳",
        note="월덕은 태어난 달의 삼합이 정하는 양간(丙甲壬庚)이다.",
    ),
    Entry(
        "geumyeo",
        _V3,
        "論金轝",
        "金轝常居祿前二辰",
        "辰為金轝是也",
        note="원문 예(甲子人)대로 태어난 해 천간의 祿 앞 두 자리로 본다. 같은 조목의 八字金書 설(驛馬 앞 두 자리)은 쓰지 않는다.",
    ),
    Entry(
        "gosin",
        _V3,
        "論孤辰寡宿",
        "如亥子丑逐方三位",
        "見戌為寡",
        note="태어난 해 지지의 방합 다음 자리가 孤辰이다.",
    ),
    Entry(
        "gwasuk",
        _V3,
        "論孤辰寡宿",
        "如亥子丑逐方三位",
        "見戌為寡",
        note="태어난 해 지지의 방합 앞자리가 寡宿이다.",
    ),
    Entry(
        "wonjin",
        _V3,
        "論元辰",
        "是以陽男陰女在衝前一位",
        "在衝後一位支辰",
        note='원문은 남녀를 나눈다(양띠 남자와 음띠 여자는 충 자리 다음 칸, 음띠 남자와 양띠 여자는 앞 칸). 명리일기는 한국에서 널리 쓰는 쌍(子未, 丑午, 寅酉, 卯申, 辰亥, 巳戌)을 남녀 구분 없이 띠 기준으로 쓴다(D124 ③). 이 쌍은 원문의 남자 쪽과 같다. 원문은 남녀를 나누지 않는 통속 방식을 "常術鼠忌羊頭歌未分男女不足憑也"라 비판한다.',
    ),
    Entry(
        "gugyo",
        _V3,
        "論勾絞",
        "陽男陰女命前三辰為勾",
        "命後三辰為勾",
        note="태어난 해 지지의 앞뒤 세 자리이고, 어느 쪽이 勾이고 絞인지는 남녀로 갈린다.",
    ),
    Entry(
        "cheonra_jimang",
        _V3,
        "論天羅地網",
        "何以戌亥為天羅",
        "辰巳為地網",
        note="태어난 해 지지가 戌亥나 辰巳이고 원국에 짝 글자가 있으면 본다. 원문은 이어서 男怕天羅女怕地網이라 한다.",
    ),
    Entry(
        "goegang",
        "sammyeong-tonghoe/skqs-vol06.wikitext",
        "魁罡",
        "此格有四日",
        "庚戌",
        note="일주 네 개로 보는 격이다.",
    ),
    Entry(
        "sipak_daepae",
        _V3,
        "論十惡大敗",
        "六甲旬中十個日",
        "値祿入空亡",
        note='같은 조목의 첫 열거는 己丑 자리에 乙丑을 적었으나 乙丑은 祿入空亡에 맞지 않아, 元白經 문단(乙未年見己丑日)대로 己丑으로 본다(명리일기 해석). 원문은 "若内有吉神相扶貴氣相輔當為吉論"이라 덧붙인다.',
    ),
    Entry(
        "eumchak_yangcha",
        _V3,
        "總論諸神煞",
        "陰陽差錯煞",
        "十二日也",
        note='總論諸神煞 아래 여러 煞을 나열한 대목이다. 원문은 이어서 "其煞不論男女月日時兩重或三重"이라 한다.',
    ),
    Entry(
        "samgi",
        _V3,
        "論三奇",
        "三奇要順布",
        "順布為吉",
        note='乙丙丁(天上三奇)과 甲戊庚을 순서대로 놓인 것만 본다. 같은 조목이 辛壬癸(人間三奇)는 "其說無據"라 하여 쓰지 않는다.',
    ),
    Entry(
        "weighing",
        _V3,
        "總論諸神煞",
        "右十二宫神煞古人所重",
        "若專論神煞則誣矣",
        in_note=True,
        note="應天歌 뒤에 붙은 작은 주다. 흉한 신살 설명의 맨 아래에 늘 이 문장의 뜻을 넣는다(D124 ⑦).",
    ),
)
XINGXUE: tuple[Entry, ...] = (
    Entry(
        "amrok",
        "xingxue-dacheng/skqs-vol02.wikitext",
        "論拱禄交禄暗禄",
        "暗禄者甲生人逢亥",
        "戌能合卯",
        work="星學大成",
        note="원문 예(甲生人)대로 태어난 해 천간의 祿과 육합하는 지지로 본다.",
    ),
)
XIEJI_DAYS: tuple[Entry, ...] = (
    Entry(
        "tiande",
        "xieji-bianfang/skqs-vol05.wikitext",
        "天徳",
        "天徳者正月丁",
        "十二月庚",
        work=XIEJI,
        note='그날이 속한 달(월건) 기준이다. 2, 5, 8, 11월은 괘(坤乾艮巽, 방위)로 적혀 있어 천덕일이 없다. 같은 조목의 按語는 이를 지지로 읽는 설을 "聊存以傳一解可也"라 할 뿐 채택하지 않는다.',
    ),
    Entry(
        "yuede",
        "xieji-bianfang/skqs-vol05.wikitext",
        "月徳",
        "月徳者正五九月在丙",
        "四八十二月在庚",
        work=XIEJI,
        note="그날이 속한 달(월건) 기준이다. 천덕합, 월덕합은 쓰지 않는다.",
    ),
)
JEOKCHEONSU: tuple[Entry, ...] = (
    Entry("day_master", "jeokcheonsu/ch12.wikitext", "衰旺論",
          "旺則宜洩宜傷", "子平之理也",
          note="본문 줄(能知衰旺之真機…)과 그 주석 줄이 passage이고, 인용은 주석 줄의 첫 문장이다."),
)


def _flat(text: str) -> str:
    return re.sub(r"\s+", "", text)


def _skqs(entry: Entry) -> dict[str, object]:
    raw = (REFERENCES / entry.file).read_text(encoding="utf-8")
    text = _flat(raw if entry.in_note else _NOTE.sub("", raw))
    start = text.index(entry.start)
    end = text.index(entry.end_after, start) + len(entry.end_after)
    quote = text[start:end]
    section_at = text.rfind(entry.section, 0, start)
    if section_at < 0:
        raise ValueError(f"{entry.key}: 인용 앞에 조목 이름 {entry.section}이 없습니다")
    return {"work": entry.work, "section": entry.section, "quote": quote, "passage": [quote],
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
    """패키지 데이터 기준 경로(`<디렉터리>/<파일>.json`) → 내용."""
    return {
        "sammyeong_tonghoe/personal.json": _nest({entry.key: _skqs(entry) for entry in SAMMYEONG}),
        "jeokcheonsu/personal.json": _nest({entry.key: _jeokcheonsu(entry) for entry in JEOKCHEONSU}),
        "xieji_bianfang/hours.json": _nest({entry.key: _skqs(entry) for entry in XIEJI_BIANFANG}),
        "sammyeong_tonghoe/shinsal.json": _nest({entry.key: _skqs(entry) for entry in SHINSAL}),
        "xingxue_dacheng/shinsal.json": _nest({entry.key: _skqs(entry) for entry in XINGXUE}),
        "xieji_bianfang/days.json": _nest({entry.key: _skqs(entry) for entry in XIEJI_DAYS}),
    }


def main() -> None:
    for path, data in build().items():
        out = DATA / path
        out.parent.mkdir(exist_ok=True)
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(out.relative_to(REFERENCES.parents[2]))


if __name__ == "__main__":
    main()

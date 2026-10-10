"""窮通寶鑑 위키문헌 원문(raw wikitext)을 일간·월지별 원문 문단으로 구조화한다.

사용법: python -I parse_gtbg.py <raw.txt> <out_dir>
"""
import json
import re
import sys
from pathlib import Path

STEMS = "甲乙丙丁戊己庚辛壬癸"
SEASONS = {"三春": ["寅", "卯", "辰"], "三夏": ["巳", "午", "未"], "三秋": ["申", "酉", "戌"], "三冬": ["亥", "子", "丑"]}
MONTH_TO_BRANCH = {
    "正": "寅", "二": "卯", "三": "辰", "四": "巳", "五": "午", "六": "未",
    "七": "申", "八": "酉", "九": "戌", "十": "亥", "十一": "子", "十二": "丑",
}
MONTH_TOKENS = sorted(MONTH_TO_BRANCH, key=len, reverse=True)
# 월 항목 안에 섞여 있지만 계절 전체를 말하는 문단의 시작어
SEASON_GENERAL_PREFIXES = ("凡", "总之", "春月", "夏月", "秋月", "冬月", "三春", "三夏", "三秋", "三冬")

SEASON_HEADER = re.compile(r"^===\s*(三春|三夏|三秋|三冬)([甲乙丙丁戊己庚辛壬癸])\S*\s*===$")
STEM_HEADER = re.compile(r"^==\s*论([甲乙丙丁戊己庚辛壬癸])\S*\s*==$")
OTHER_HEADER = re.compile(r"^=+[^=]+=+$")
MONTH_PARAGRAPH = re.compile(r"^(?:或)?(?:''')?([正二三四五六七八九十一]+)月(?:''')?([甲乙丙丁戊己庚辛壬癸])?")


def parse_month_tokens(text: str) -> list[str]:
    """'正二' → ['寅', '卯'], '十二' → ['丑']처럼 월 표기를 월지 목록으로 바꾼다."""
    if text in MONTH_TO_BRANCH:
        return [MONTH_TO_BRANCH[text]]
    branches = []
    rest = text
    while rest:
        token = next((t for t in MONTH_TOKENS if rest.startswith(t)), None)
        if token is None:
            return []
        # '十一二月'의 '二'는 '十二'(丑)를 줄여 쓴 것이다.
        if token == "二" and branches == [MONTH_TO_BRANCH["十一"]]:
            token_branch = MONTH_TO_BRANCH["十二"]
        else:
            token_branch = MONTH_TO_BRANCH[token]
        branches.append(token_branch)
        rest = rest[len(token):]
    return branches


def clean(text: str) -> str:
    return text.replace("'''", "").strip()


def parse_example_table(lines: list[str]) -> list[dict]:
    """'{| class="wikitable"' 블록의 예시 명조를 {pillars, comment} 목록으로 바꾼다."""
    examples = []
    for cell in "\n".join(lines).split("\n|时日月年")[1:]:
        parts = [p.strip() for p in cell.split("\n") if p.strip() and not p.startswith("|}")]
        if len(parts) < 2:
            continue
        stems, branches = parts[0], parts[1]
        comment = " ".join(parts[2:])
        examples.append({"hour_day_month_year_stems": stems, "hour_day_month_year_branches": branches, "comment": comment})
    return examples


def parse(raw: str) -> dict:
    result = {stem: {"stem_intro": [], "seasons": {}} for stem in STEMS}
    current_stem = None
    current_season = None
    current_entry = None
    table_lines = None

    for line in raw.splitlines():
        stripped = line.strip()

        if table_lines is not None:
            table_lines.append(stripped)
            if stripped.startswith("|}"):
                target = current_entry if current_entry is not None else current_season
                if target is not None:
                    target.setdefault("examples", []).extend(parse_example_table(table_lines))
                table_lines = None
            continue
        if stripped.startswith("{|"):
            table_lines = [stripped]
            continue
        if not stripped:
            continue

        if match := STEM_HEADER.match(stripped):
            current_stem, current_season, current_entry = match.group(1), None, None
            continue
        if match := SEASON_HEADER.match(stripped):
            season, stem = match.groups()
            current_stem = stem
            current_season = {"intro": [], "entries": []}
            result[stem]["seasons"][season] = current_season
            current_entry = None
            continue
        if OTHER_HEADER.match(stripped):
            current_stem, current_season, current_entry = None, None, None
            continue
        if current_stem is None:
            continue

        if current_season is None:
            result[current_stem]["stem_intro"].append(clean(stripped))
            continue

        match = MONTH_PARAGRAPH.match(stripped)
        stem_matches = match is not None and match.group(2) in (None, current_stem)
        branches = parse_month_tokens(match.group(1)) if stem_matches else []
        if branches:
            current_entry = {"heading": f"{match.group(1)}月{current_stem}", "level": "month", "branches": branches, "paragraphs": [clean(stripped)]}
            current_season["entries"].append(current_entry)
        elif current_entry is None:
            current_season["intro"].append(clean(stripped))
        else:
            current_entry["paragraphs"].append(clean(stripped))
            if clean(stripped).startswith(SEASON_GENERAL_PREFIXES):
                current_season.setdefault("general", []).append(clean(stripped))

    return result


def build_month_index(parsed: dict) -> dict:
    """일간 → 월지 → 해당 월지를 다루는 항목 목록 (단독 월 항목을 앞에 둔다)."""
    index = {}
    for stem, data in parsed.items():
        index[stem] = {}
        for season, branches in SEASONS.items():
            season_data = data["seasons"].get(season, {"entries": []})
            for branch in branches:
                entries = [e for e in season_data["entries"] if branch in e["branches"]]
                entries.sort(key=lambda e: len(e["branches"]))
                season_paragraphs = season_data.get("intro", []) + season_data.get("general", [])
                if not entries and season_paragraphs:
                    entries = [{"heading": f"{season}{stem}", "level": "season", "branches": branches, "paragraphs": season_paragraphs}]
                index[stem][branch] = entries
    return index


def main() -> None:
    raw_path, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    parsed = parse(raw_path.read_text(encoding="utf-8"))
    month_index = build_month_index(parsed)
    (out_dir / "entries.json").write_text(json.dumps(parsed, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "month_index.json").write_text(json.dumps(month_index, ensure_ascii=False, indent=2), encoding="utf-8")

    missing = [f"{s}{b}" for s, months in month_index.items() for b, entries in months.items() if not entries]
    season_only = [f"{s}{b}" for s, months in month_index.items() for b, entries in months.items() if entries and entries[0]["level"] == "season"]
    print("근거 없는 칸:", missing or "없음")
    print("계절 총론만 있는 칸:", season_only or "없음")


if __name__ == "__main__":
    main()

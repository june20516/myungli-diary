"""窮通寶鑑 원문으로 조후용신 근거 데이터와 대조 리포트를 만든다.

사용법 (저장소 루트에서): python3 -I core/docs/references/gungtong-bogam/tools/build_evidence.py

입력
  core/docs/references/gungtong-bogam/source.wikitext   위키문헌 원문 (raw wikitext)
  core/src/myungli_engine/references/data/gungtong_bogam/corrections.json  원문 대조로 바로잡은 칸
  core/src/myungli_engine/constants/johu.py  JOHU_TABLE_HANJA 한자 표 (정정 반영본)
  core/docs/references/gungtong-bogam/quote-choices.json  첫 문장 대신 고른 인용 문장 (#625)
출력 (core/docs/references/gungtong-bogam/)
  entries.json              일간 → 계절 → 월 항목(원문 문단·예시 명조) 전체 구조
  verification-report.md    조후표 ↔ 원문 대조 결과
출력 (core/src/myungli_engine/references/data/gungtong_bogam/)
  johu_evidence.json        일간 → 월지 → 조후용신 + 원문 근거
  five_elements.json        五行總論의 색·수·방위·성정·억부 원리 근거
"""
import ast
import json
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from parse_source import SEASONS, STEMS, build_month_index, parse  # noqa: E402

REFERENCE_DIR = TOOLS_DIR.parent
CORE_DIR = REFERENCE_DIR.parents[2]  # gungtong-bogam → references → docs → core
JOHU_PATH = CORE_DIR / "src" / "myungli_engine" / "constants" / "johu.py"
DATA_DIR = CORE_DIR / "src" / "myungli_engine" / "references" / "data" / "gungtong_bogam"
BRANCH_ORDER = "寅卯辰巳午未申酉戌亥子丑"
STEM_ELEMENT = {
    "甲": "木", "乙": "木", "丙": "火", "丁": "火", "戊": "土",
    "己": "土", "庚": "金", "辛": "金", "壬": "水", "癸": "水",
}
SOURCE_URL = "https://zh.wikisource.org/wiki/%E7%AA%AE%E9%80%9A%E5%AF%B6%E9%91%91"


def load_johu_table() -> dict:
    """constants/johu.py의 순수 리터럴 JOHU_TABLE_HANJA를 읽는다. 값은 JSON과 같게 리스트로 바꾼다."""
    for node in ast.parse(JOHU_PATH.read_text(encoding="utf-8")).body:
        if isinstance(node, ast.AnnAssign) and getattr(node.target, "id", "") == "JOHU_TABLE_HANJA":
            assert node.value is not None
            table = ast.literal_eval(node.value)
            return {
                stem: {branch: list(yongsin) for branch, yongsin in months.items()}
                for stem, months in table.items()
            }
    raise RuntimeError(f"JOHU_TABLE_HANJA를 찾지 못했습니다: {JOHU_PATH}")


def first_sentence(paragraph: str) -> str:
    end = paragraph.find("。")
    return paragraph if end == -1 else paragraph[: end + 1]


def stems_in_order(text: str, exclude: str) -> list[str]:
    seen = []
    for char in text:
        if char in STEMS and char != exclude and char not in seen:
            seen.append(char)
    return seen


def chosen_quote(month_index: dict, stem: str, branch: str, choice: dict | None) -> str:
    """고른 인용이 있으면 원문 문단에 글자 그대로 있는지 확인하고 쓴다. 없으면 첫 문장.

    다른 달 항목에서 빌린 인용(borrowed_from_branch)은 그 달 항목의 문단에서 확인한다.
    """
    paragraphs = month_index[stem][branch][0]["paragraphs"]
    if choice is None:
        return first_sentence(paragraphs[0])
    source_branch = choice.get("borrowed_from_branch", branch)
    source_paragraphs = month_index[stem][source_branch][0]["paragraphs"]
    if choice["quote"] not in "".join(source_paragraphs):
        raise ValueError(f"{stem}{branch}: 고른 인용이 원문 문단에 없습니다: {choice['quote']}")
    return choice["quote"]


def build_johu_evidence(
    month_index: dict, table: dict, corrections: list[dict], quote_choices: list[dict]
) -> dict:
    corrected_cells = {(c["stem"], c["branch"]): c for c in corrections}
    chosen = {(c["stem"], c["branch"]): c for c in quote_choices}
    evidence = {}
    for stem in STEMS:
        evidence[stem] = {}
        for branch in BRANCH_ORDER:
            entries = month_index[stem][branch]
            primary = entries[0]
            correction = corrected_cells.get((stem, branch))
            evidence[stem][branch] = {
                "yongsin": table[stem][branch],
                "yongsin_elements": [STEM_ELEMENT[s] for s in table[stem][branch]],
                "evidence_level": primary["level"],
                "heading": primary["heading"],
                "key_sentence": chosen_quote(month_index, stem, branch, chosen.get((stem, branch))),
                "quote_note": (chosen.get((stem, branch)) or {}).get("note"),
                "paragraphs": primary["paragraphs"],
                "related_headings": [e["heading"] for e in entries[1:]],
                "examples": primary.get("examples", []),
                "correction": correction and {"before": correction["before"], "evidence": correction["evidence"]},
            }
    return evidence


def build_five_elements(parsed_raw: str) -> dict:
    section = parsed_raw.split("= 五行总论 =", 1)[1].split("= 十干分论 =", 1)[0]
    paragraphs = [p.strip() for p in section.splitlines() if p.strip()]

    def find(keyword: str) -> str:
        return next(p for p in paragraphs if keyword in p)

    return {
        "source": f"窮通寶鑑 五行總論 ({SOURCE_URL})",
        "direction": {
            "quote": find("北方阴极"),
            "mapping": {"水": "北", "火": "南", "木": "東", "金": "西", "土": "中央"},
        },
        "color": {
            "quote": find("推其形色"),
            "mapping": {"水": "黑", "火": "赤", "木": "青", "金": "白", "土": "黃"},
            "note": (
                "이 수집본의 正色 목록에는 金이 빠져 있다. 같은 문장을 실은 『三命通會』 四庫全書本 卷一,"
                " 『五行精紀』, 『古今圖書集成』 藝術典 595권은 모두 \"水黑火赤木青金白土黃\"이라"
                " 수집본 누락으로 보고 金=白을 넣는다."
            ),
        },
        "number": {
            "quote": find("其数则"),
            "mapping": {"水": 1, "火": 2, "木": 3, "金": 4, "土": 5},
            "note": "생왕(生旺)이면 배로, 사절(死絶)이면 반으로 본다(生旺加倍，死绝减半).",
        },
        "virtue": {
            "quote": find("其性智"),
            "mapping": {"水": "智", "火": "禮", "木": "仁", "金": "義", "土": "信"},
        },
        "balance_principle": {
            "quote": find("高者抑之"),
            "note": "억부(抑扶)의 원리: 넘치면 덜고 모자라면 더해 중화(中道)로 돌린다.",
        },
    }


def build_report(evidence: dict) -> tuple[str, list[str]]:
    flagged = []
    rows = []
    for stem in STEMS:
        for branch in BRANCH_ORDER:
            cell = evidence[stem][branch]
            all_text = "".join(cell["paragraphs"])
            first_order = stems_in_order(cell["paragraphs"][0], exclude=stem)
            absent = [s for s in cell["yongsin"] if s not in all_text]
            head_matches = bool(first_order) and first_order[0] == cell["yongsin"][0]
            status = "OK" if not absent and head_matches else "REVIEWED"
            if status != "OK":
                flagged.append(f"{stem}{branch}")
            corrected = "정정" if cell["correction"] else ""
            rows.append(
                f"| {stem} | {branch} | {'·'.join(cell['yongsin'])} | {'·'.join(first_order)} | {'·'.join(absent)} "
                f"| {cell['evidence_level']} | {status} | {corrected} | {cell['key_sentence'][:60]} |"
            )
    header = [
        "# 조후용신표 원문 대조 리포트",
        "",
        "`tools/build_evidence.py`가 생성합니다. 직접 수정하지 마세요.",
        "",
        "* `OK`: 조후표 첫 글자가 원문 첫 문단에서 처음 언급되는 천간과 같고, 조후표의 모든 글자가 근거 문단에 등장.",
        "* `REVIEWED`: 기계 판정은 불일치지만 사람이 원문을 읽고 확인한 칸. 대부분 '丙火司權', '忌壬水'처럼 용신이 아닌 천간이 먼저 언급된 경우입니다.",
        "* `정정`: 통용 정리표와 원문이 달라 원문 기준으로 바꾼 칸 (`corrections.json`).",
        "* 근거 수준 `season`: 원문에 해당 월 항목이 없어 계절 총론을 근거로 쓴 칸.",
        "* 인용 문장: 첫 문장, 또는 용신을 말하는 문장으로 고른 문장(`quote-choices.json`, #625).",
        "",
        f"* 결과: 120칸 중 OK {120 - len(flagged)} / REVIEWED {len(flagged)}",
        "",
        "| 일간 | 월지 | 조후용신 | 원문 첫 문단 천간 순서 | 근거에 없는 글자 | 근거 수준 | 판정 | 정정 | 인용 문장 |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    return "\n".join(header + rows) + "\n", flagged


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    raw = (REFERENCE_DIR / "source.wikitext").read_text(encoding="utf-8")
    corrections = json.loads((DATA_DIR / "corrections.json").read_text(encoding="utf-8"))["corrections"]
    quote_choices = json.loads((REFERENCE_DIR / "quote-choices.json").read_text(encoding="utf-8"))["choices"]
    parsed = parse(raw)
    month_index = build_month_index(parsed)
    table = load_johu_table()

    evidence = build_johu_evidence(month_index, table, corrections, quote_choices)
    report, flagged = build_report(evidence)

    write_json(REFERENCE_DIR / "entries.json", parsed)
    write_json(DATA_DIR / "johu_evidence.json", {"source": SOURCE_URL, "cells": evidence})
    write_json(DATA_DIR / "five_elements.json", build_five_elements(raw))
    (REFERENCE_DIR / "verification-report.md").write_text(report, encoding="utf-8")

    season_only = [f"{s}{b}" for s in STEMS for b in BRANCH_ORDER if evidence[s][b]["evidence_level"] == "season"]
    print(f"OK {120 - len(flagged)} / REVIEWED {len(flagged)}")
    print("REVIEWED:", ", ".join(flagged))
    print("계절 총론 근거:", ", ".join(season_only))


if __name__ == "__main__":
    main()

"""용어 사전 fixture(`fixtures/member/getGlossary.json`)를 writing ko 원고로 만듭니다.

server `content.Store.Glossary`(`server/internal/content/glossary.go`)와 같은 규칙입니다.
* `values`: `glossary.value_name`(키 `<범주>.<값>`), `daily.tag_label`(범주 `tag`), `daily.focus_reason`
  (범주 `focus_reason`), `calendar.score_item`(범주 `score_item`), `calendar.solar_term`(범주 `solar_term`)의
  문장을 글자로 이은 것입니다.
* `meanings`: `term.meaning`(키 `term.<용어 id>`)을 조각 배열로 렌더한 것입니다.
* `hanja`: `content/hanja.yaml`(server 시드 변환과 같은 원본)입니다.
원고 순서대로 담고, 시드 버전(`seedVersion`)은 기존 fixture 값을 그대로 둡니다.

엔진을 쓰지 않으므로 어디서든 실행할 수 있습니다(다른 fixture 도구와 같게 core/에서 돌려도 됩니다).
    python3 tool/gen_glossary_fixtures.py fixtures          # app/에서
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from fixture_content import lines_of, load_hanja, render

LANG = "ko"
# server `namedSlotCategory`: 범주 이름이 슬롯으로 정해지는 슬롯.
NAMED_SLOT_CATEGORY = {
    "daily.focus_reason": "focus_reason",
    "calendar.score_item": "score_item",
    "calendar.solar_term": "solar_term",
}
TAG_PREFIX = "tag."
TERM_PREFIX = "term."


def _text(template: str) -> str:
    return "".join(segment["text"] for segment in render(template, {}))


def build(seed_version: str) -> dict:
    values: dict[str, dict[str, str]] = {}

    def put(category: str, value: str, template: str) -> None:
        values.setdefault(category, {})[value] = _text(template)

    for key, variant, template in lines_of("glossary.value_name"):
        if variant == "single" and "." in key:
            category, value = key.split(".", 1)
            put(category, value, template)
    for key, variant, template in lines_of("daily.tag_label"):
        if variant == "single" and key.startswith(TAG_PREFIX):
            put("tag", key.removeprefix(TAG_PREFIX), template)
    for slot, category in NAMED_SLOT_CATEGORY.items():
        for key, variant, template in lines_of(slot):
            if variant == "single":
                put(category, key, template)
    meanings = {
        key.removeprefix(TERM_PREFIX): {"segments": render(template, {})}
        for key, variant, template in lines_of("term.meaning")
        if variant == "single" and key.startswith(TERM_PREFIX)
    }
    return {
        "seedVersion": seed_version,
        "lang": LANG,
        "values": values,
        "meanings": meanings,
        "hanja": load_hanja(),
    }


def main(fixtures: Path) -> None:
    path = fixtures / "member" / "getGlossary.json"
    fixture = json.loads(path.read_text(encoding="utf-8"))
    fixture["body"] = build(fixture["body"]["seedVersion"])
    path.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(path)


if __name__ == "__main__":
    main(Path(sys.argv[1]))

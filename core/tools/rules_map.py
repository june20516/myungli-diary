"""계산 규칙 지도(#988)를 TOML 원본에서 JSON으로 만든다.

원본: core/docs/rules-map/rules_map.toml (사람이 고침)
결과: core/rules_map.json (지휘 제품 지도 "계산 규칙" 탭이 읽음)

core 디렉터리에서 실행한다.
    uv run python tools/rules_map.py
"""

from __future__ import annotations

import json
import tomllib
from collections import Counter
from pathlib import Path
from typing import Any

CORE_DIR = Path(__file__).resolve().parents[1]
SOURCE = CORE_DIR / "docs" / "rules-map" / "rules_map.toml"
OUT = CORE_DIR / "rules_map.json"


def load() -> dict[str, Any]:
    with SOURCE.open("rb") as file:
        return tomllib.load(file)


def build() -> dict[str, Any]:
    """원본에 항목별 원전 상태 개수(source_status_counts)를 더한다. 개수는 규칙 줄 분류를 센 값이다."""
    data = load()
    statuses = list(data["meta"]["source_status_labels"])
    for item in data["items"]:
        counts = Counter(rule["source_status"] for rule in item["rules"])
        item["source_status_counts"] = {status: counts[status] for status in statuses if counts[status]}
    return data


def render(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main() -> None:
    OUT.write_text(render(build()), encoding="utf-8")
    print(OUT.relative_to(CORE_DIR))


if __name__ == "__main__":
    main()

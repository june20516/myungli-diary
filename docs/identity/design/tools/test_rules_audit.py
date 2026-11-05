"""규칙 전수 점검 도구 테스트 (DS1, #801)."""
import json
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from rules_audit import Measure, collect_measures, find_problems, render_markdown  # noqa: E402


def write_components(directory: pathlib.Path, parts: dict) -> pathlib.Path:
    document = {"version": "0.0.0", "components": [{"id": "x", "parts": parts}]}
    (directory / "sample.json").write_text(json.dumps(document), encoding="utf-8")
    return directory


def test_collect_measures_reads_token_and_raw_px(tmp_path):
    write_components(tmp_path, {"a": {"paddingX": "{space.16}", "height": {"value": 44, "unit": "px"}}})

    measures = collect_measures(tmp_path)

    assert Measure("x", "parts.a", "paddingX", "space.16", True) in measures
    assert Measure("x", "parts.a", "height", "44", False) in measures


def test_find_problems_flags_raw_spacing(tmp_path):
    write_components(tmp_path, {"a": {"gap": {"value": 6, "unit": "px"}, "marginBottom": {"value": 0, "unit": "px"}}})

    problems = find_problems(collect_measures(tmp_path))

    assert problems == ["x parts.a.gap: 간격에 토큰이 아닌 값 6"]


def test_find_problems_flags_asymmetric_padding(tmp_path):
    write_components(tmp_path, {"box": {"paddingTop": "{space.24}", "paddingBottom": "{space.16}"}})

    problems = find_problems(collect_measures(tmp_path))

    assert problems == ["x parts.box: 위아래 여백이 다름 (paddingTop space.24, paddingBottom space.16)"]


def test_asymmetric_padding_with_note_is_allowed(tmp_path):
    write_components(tmp_path, {"box": {"paddingTop": "{space.24}", "paddingBottom": "{space.16}", "note": "아래 버튼 줄 때문"}})

    assert find_problems(collect_measures(tmp_path)) == []


def test_render_markdown_has_tables(tmp_path):
    write_components(tmp_path, {"a": {"gap": {"value": 6, "unit": "px"}}})
    measures = collect_measures(tmp_path)

    text = render_markdown(measures, find_problems(measures))

    assert "## 간격 토큰 쓰임" in text
    assert "## 직접 쓴 값" in text
    assert "## 문제" in text

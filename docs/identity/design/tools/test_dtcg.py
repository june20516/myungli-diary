"""DTCG 토큰 검사기 테스트 (V1 spec §6·§7)."""
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from dtcg import find_problems, flatten, resolve  # noqa: E402

WHITE = {"colorSpace": "srgb", "components": [1.0, 1.0, 1.0], "hex": "#ffffff"}


def color(value):
    return {"$type": "color", "$value": value}


def clean_documents():
    return {
        "primitive.tokens.json": {
            "color": {"white": color(WHITE)},
            "space": {"16": {"$type": "dimension", "$value": {"value": 16, "unit": "px"}}},
        },
        "color.light.tokens.json": {
            "color": {"bg": {"sheet": color("{color.white}")}},
            "gradient": {"today": {"$type": "gradient", "$value": [
                {"color": "{color.white}", "position": 0},
                {"color": WHITE, "position": 1},
            ]}},
        },
        "typography.tokens.json": {
            "font": {"family": {"ui": {"$type": "fontFamily", "$value": ["Pretendard", "sans-serif"]}}},
            "type": {"title": {"$type": "typography", "$value": {
                "fontFamily": "{font.family.ui}",
                "fontSize": {"value": 20, "unit": "px"},
                "fontWeight": 600,
                "letterSpacing": {"value": -0.4, "unit": "px"},
                "lineHeight": 1.3,
            }}},
        },
    }


def test_flatten_joins_names_with_dots():
    tokens = flatten(clean_documents()["color.light.tokens.json"])
    assert set(tokens) == {"color.bg.sheet", "gradient.today"}


def test_clean_documents_have_no_problems():
    assert find_problems(clean_documents()) == []


def test_reports_missing_type():
    documents = clean_documents()
    del documents["primitive.tokens.json"]["color"]["white"]["$type"]
    problems = find_problems(documents)
    assert any("color.white" in problem for problem in problems), problems


def test_reports_unknown_type():
    documents = clean_documents()
    documents["primitive.tokens.json"]["shadow"] = {"$type": "shadow", "$value": {}}
    problems = find_problems(documents)
    assert any("shadow" in problem for problem in problems), problems


def test_reports_broken_reference():
    documents = clean_documents()
    documents["color.light.tokens.json"]["color"]["bg"]["sheet"]["$value"] = "{color.sage.705}"
    problems = find_problems(documents)
    assert any("color.bg.sheet" in problem and "color.sage.705" in problem for problem in problems), problems


def test_reports_broken_reference_inside_typography_and_gradient():
    documents = clean_documents()
    documents["typography.tokens.json"]["type"]["title"]["$value"]["fontFamily"] = "{font.family.uii}"
    documents["color.light.tokens.json"]["gradient"]["today"]["$value"][0]["color"] = "{color.whit}"
    problems = find_problems(documents)
    assert any("font.family.uii" in problem for problem in problems), problems
    assert any("color.whit" in problem for problem in problems), problems


def test_reports_name_defined_in_two_files():
    documents = clean_documents()
    documents["color.light.tokens.json"]["color"]["white"] = color(WHITE)
    problems = find_problems(documents)
    assert any(
        "color.white" in problem and "primitive.tokens.json" in problem and "color.light.tokens.json" in problem
        for problem in problems
    ), problems


def test_reports_hex_components_mismatch():
    documents = clean_documents()
    documents["primitive.tokens.json"]["color"]["white"]["$value"] = {
        "colorSpace": "srgb", "components": [0, 0, 0], "hex": "#ffffff"}
    problems = find_problems(documents)
    assert any("color.white" in problem for problem in problems), problems


def test_reports_alpha_out_of_range():
    documents = clean_documents()
    documents["primitive.tokens.json"]["color"]["white"]["$value"] = {**WHITE, "alpha": 1.5}
    problems = find_problems(documents)
    assert any("color.white" in problem for problem in problems), problems


def test_reports_non_px_dimension():
    documents = clean_documents()
    documents["primitive.tokens.json"]["space"]["16"]["$value"]["unit"] = "rem"
    problems = find_problems(documents)
    assert any("space.16" in problem for problem in problems), problems


def test_reports_token_that_is_also_group():
    documents = clean_documents()
    documents["primitive.tokens.json"]["color"]["white"]["dim"] = color(WHITE)
    problems = find_problems(documents)
    assert any("color.white" in problem for problem in problems), problems


def test_reports_token_that_is_group_in_another_file():
    documents = clean_documents()
    documents["primitive.tokens.json"]["color"]["ohaeng"] = {"wood": color(WHITE)}
    documents["color.light.tokens.json"]["color"]["ohaeng"] = {"wood": {"bg": color(WHITE)}}
    problems = find_problems(documents)
    assert any("color.ohaeng.wood" in problem and "그룹" in problem for problem in problems), problems


def test_reports_typed_node_without_value():
    documents = clean_documents()
    documents["primitive.tokens.json"]["color"]["black"] = {"$type": "color", "$valu": WHITE}
    problems = find_problems(documents)
    assert any("color.black" in problem and "$value" in problem for problem in problems), problems


def test_checks_second_definition_of_duplicate_name():
    documents = clean_documents()
    documents["color.light.tokens.json"]["color"]["white"] = color(
        {"colorSpace": "srgb", "components": [0, 0, 0], "hex": "#ffffff"})
    problems = find_problems(documents)
    assert any("정의됨" in problem for problem in problems), problems
    assert any("color.light.tokens.json: color.white: components" in problem for problem in problems), problems


def test_reports_reference_to_wrong_type():
    documents = clean_documents()
    documents["typography.tokens.json"]["type"]["title"]["$value"]["fontFamily"] = "{color.white}"
    documents["color.light.tokens.json"]["color"]["bg"]["sheet"]["$value"] = "{space.16}"
    problems = find_problems(documents)
    assert any("type.title" in problem and "color.white" in problem and "fontFamily" in problem
               for problem in problems), problems
    assert any("color.bg.sheet" in problem and "space.16" in problem and "dimension" in problem
               for problem in problems), problems


def test_resolve_follows_reference_chain():
    tokens = {"a": color("{b}"), "b": color("{c}"), "c": color(WHITE)}
    assert resolve("a", tokens) == WHITE


def test_resolve_rejects_cycle():
    tokens = {"a": color("{b}"), "b": color("{a}")}
    with pytest.raises(KeyError):
        resolve("a", tokens)


def test_duration_value():
    assert find_problems({"a": {"d": {"$type": "duration", "$value": {"value": 200, "unit": "ms"}}}}) == []
    assert find_problems({"a": {"d": {"$type": "duration", "$value": {"value": 200, "unit": "px"}}}})
    assert find_problems({"a": {"d": {"$type": "duration", "$value": {"value": -1, "unit": "ms"}}}})


def test_cubic_bezier_value():
    assert find_problems({"a": {"e": {"$type": "cubicBezier", "$value": [0.2, 0.7, 0.2, 1]}}}) == []
    assert find_problems({"a": {"e": {"$type": "cubicBezier", "$value": [1.2, 0, 0.2, 1]}}})  # x는 0~1
    assert find_problems({"a": {"e": {"$type": "cubicBezier", "$value": [0.2, 0.7, 0.2]}}})


def test_shadow_value():
    shadow = {"color": {"colorSpace": "srgb", "components": [0.1686, 0.1686, 0.1647], "hex": "#2b2b2a", "alpha": 0.14},
              "offsetX": {"value": 0, "unit": "px"}, "offsetY": {"value": 4, "unit": "px"},
              "blur": {"value": 16, "unit": "px"}, "spread": {"value": 0, "unit": "px"}}
    assert find_problems({"a": {"s": {"$type": "shadow", "$value": shadow}}}) == []
    broken = dict(shadow)
    del broken["blur"]
    assert find_problems({"a": {"s": {"$type": "shadow", "$value": broken}}})
    assert find_problems({"a": {"s": {"$type": "shadow", "$value": dict(shadow, inset="no")}}})

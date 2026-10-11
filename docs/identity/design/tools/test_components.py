"""컴포넌트 명세 검사기 테스트 (V2 spec §7)."""
import copy
import json
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
DESIGN_DIR = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import components  # noqa: E402
from components import (COMPONENTS_DIR, IA_PATH, find_problems, load_documents,  # noqa: E402
                        token_names_by_theme)
from tokens import TOKENS_DIR  # noqa: E402

IA = {
    "components": [{"id": "a"}, {"id": "b"}, {"id": "state-x"}],
    "screens": [{"id": "s", "states": [{"id": "loading"}]}, {"id": "t", "states": []}],
}
BASE_TOKENS = {"color.text.primary", "motion.duration.medium", "motion.easing.seep", "radius.md"}
TOKENS = {theme: set(BASE_TOKENS) for theme in ("light-ko", "light-ja", "dark-ko", "dark-ja")}


def valid_docs():
    return {
        "interaction": {
            "version": "1.0.0",
            "patterns": {"p": {"summary": "패턴", "duration": "{motion.duration.medium}",
                               "easing": "{motion.easing.seep}", "reduceMotion": "opacity-only",
                               "keyframes": [{"offset": 0}, {"offset": 1, "color": "{color.text.primary}"}]}},
            "haptics": {"selection": ["선택이 바뀜"]},
        },
        "elements": {"version": "1.0.0", "elements": {"el": {"summary": "요소"}}},
        "frame": {"version": "1.0.0", "group": "frame", "components": [
            {"id": "a", "summary": "가", "uses": ["el", "p"],
             "variants": [{"id": "v", "parts": {"label": {"fg": "{color.text.primary}"}}}],
             "parts": {"container": {"radius": "{radius.md}"}},
             "states": {"pressed": {"pattern": "p", "parts": {"x": {"bg": "{color.text.primary}"}}}}},
            {"id": "b", "summary": "나"},
        ]},
        "feedback": {"version": "1.0.0", "group": "feedback", "stateMap": {"loading": "state-x"},
                     "components": [{"id": "state-x", "summary": "상태"}]},
    }


def has(problems, *words):
    return any(all(word in problem for word in words) for problem in problems)


def test_valid_documents_pass():
    assert find_problems(valid_docs(), IA, TOKENS) == []


def test_missing_ia_component_is_reported():
    docs = valid_docs()
    docs["frame"]["components"].pop()
    assert has(find_problems(docs, IA, TOKENS), "b")


def test_duplicate_component_is_reported():
    docs = valid_docs()
    docs["feedback"]["components"].append({"id": "a", "summary": "겹침"})
    assert has(find_problems(docs, IA, TOKENS), "a", "두 번")


def test_unknown_component_id_is_reported():
    docs = valid_docs()
    docs["frame"]["components"].append({"id": "z", "summary": "없음"})
    assert has(find_problems(docs, IA, TOKENS), "z", "IA")


def test_unknown_field_is_reported():
    docs = valid_docs()
    docs["frame"]["components"][0]["colour"] = "x"
    assert has(find_problems(docs, IA, TOKENS), "colour")
    docs = valid_docs()
    docs["frame"]["extra"] = 1
    assert has(find_problems(docs, IA, TOKENS), "extra")


def test_state_map_outside_feedback_is_reported():
    docs = valid_docs()
    docs["frame"]["stateMap"] = {}
    assert has(find_problems(docs, IA, TOKENS), "frame", "stateMap")


def test_reference_missing_in_one_theme_is_reported():
    docs = valid_docs()
    docs["frame"]["components"][1]["parts"] = {"x": {"bg": "{color.only-light}"}}
    tokens = copy.deepcopy(TOKENS)
    tokens["light-ko"].add("color.only-light")
    tokens["light-ja"].add("color.only-light")
    problems = find_problems(docs, IA, tokens)
    assert has(problems, "color.only-light", "dark-ko") and has(problems, "color.only-light", "dark-ja")
    assert not has(problems, "color.only-light", "light-ko")


def test_nested_references_are_checked():
    docs = valid_docs()
    docs["frame"]["components"][0]["variants"][0]["parts"]["label"]["fg"] = "{missing.one}"
    docs["frame"]["components"][0]["states"]["pressed"]["parts"]["x"]["bg"] = "{missing.two}"
    docs["interaction"]["patterns"]["p"]["keyframes"][1]["color"] = "{missing.three}"
    problems = find_problems(docs, IA, TOKENS)
    for name in ("missing.one", "missing.two", "missing.three"):
        assert has(problems, name), name


def test_unknown_element_or_pattern_is_reported():
    docs = valid_docs()
    docs["frame"]["components"][0]["uses"].append("없는요소")
    docs["frame"]["components"][0]["states"]["pressed"]["pattern"] = "없는패턴"
    problems = find_problems(docs, IA, TOKENS)
    assert has(problems, "없는요소") and has(problems, "없는패턴")


def test_state_pattern_must_be_pattern_not_element():
    docs = valid_docs()
    docs["frame"]["components"][0]["states"]["pressed"]["pattern"] = "el"
    assert has(find_problems(docs, IA, TOKENS), "el")


def test_pattern_without_reduce_motion_is_reported():
    docs = valid_docs()
    del docs["interaction"]["patterns"]["p"]["reduceMotion"]
    assert has(find_problems(docs, IA, TOKENS), "p", "reduceMotion")


def test_pattern_duration_must_be_reference():
    docs = valid_docs()
    docs["interaction"]["patterns"]["p"]["duration"] = 200
    assert has(find_problems(docs, IA, TOKENS), "p", "duration")


def test_state_map_must_cover_ia_states():
    docs = valid_docs()
    docs["feedback"]["stateMap"] = {}
    assert has(find_problems(docs, IA, TOKENS), "loading")


def test_state_map_target_must_be_component():
    docs = valid_docs()
    docs["feedback"]["stateMap"] = {"loading": "없는-컴포넌트"}
    assert has(find_problems(docs, IA, TOKENS), "없는-컴포넌트")


def test_markdown_pair_and_readme(tmp_path):
    (tmp_path / "frame.md").write_text("설명", encoding="utf-8")
    (tmp_path / "README.md").write_text("frame.json", encoding="utf-8")
    problems = find_problems(valid_docs(), IA, TOKENS, tmp_path)
    assert has(problems, "feedback.md")
    assert not has(problems, "frame.md")
    assert has(problems, "README", "feedback.json")
    assert has(problems, "README", "컴포넌트 계약 1.0.0")


def test_load_documents_reads_json_by_stem(tmp_path):
    (tmp_path / "frame.json").write_text(json.dumps({"version": "1.0.0"}), encoding="utf-8")
    (tmp_path / "frame.md").write_text("설명", encoding="utf-8")
    assert load_documents(tmp_path) == {"frame": {"version": "1.0.0"}}


def test_token_names_by_theme_reads_committed_tokens():
    themes = token_names_by_theme(TOKENS_DIR)
    assert set(themes) == {"light-ko", "light-ja", "dark-ko", "dark-ja"}
    assert "motion.duration.stamp" in themes["dark-ja"] and "type.body.ui" in themes["light-ko"]
    assert "color.seal.soft" in themes["dark-ko"]


def test_paths_point_to_design_and_ia():
    assert COMPONENTS_DIR == DESIGN_DIR / "components"
    assert IA_PATH.name == "screens.json" and IA_PATH.exists()
    assert callable(components.main)


# 실제 명세 파일 (V2 spec §3·§4)
def test_common_files_define_spec_ids():
    docs = load_documents(COMPONENTS_DIR)
    assert set(docs["interaction"]["patterns"]) == {
        "press.ink", "appear.seep", "disappear.seep", "select.seep-slide", "loading.breathe", "seal.stamp",
        "seal.erase", "mark.underline-grow", "sheet.enter", "sheet.exit", "sheet.stack", "focus.ring"}
    assert set(docs["elements"]["elements"]) == {
        "seal", "ohaeng.cell", "ohaeng.swatch", "tone", "tag.status", "tag.me", "highlight.current",
        "mark.underline-grow", "mark.caution", "link.inline-nowrap", "surface.paper", "rail.timeline", "term",
        "skeleton.bone", "icon"}


def test_seal_element_matches_logo():
    seal = load_documents(COMPONENTS_DIR)["elements"]["elements"]["seal"]
    assert seal["path"] == "M1.2 1.5 q8.8 -1.3 17.6 0 q1.2 8.5 0 17 q-8.8 1.3 -17.6 0 q-1.2 -8.5 0 -17 z"
    assert seal["rotate"] == -8 and set(seal["variants"]) == {"fill", "soft", "outline"}
    assert seal["path"] in (DESIGN_DIR / "logo" / "icon-large.svg").read_text(encoding="utf-8")
    assert seal["variants"]["soft"]["color"] == "{color.seal.soft}"
    assert seal["contentAlign"] == "center"


def test_seal_stamp_pattern_values():
    patterns = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]
    stamp = patterns["seal.stamp"]
    assert stamp["duration"] == "{motion.duration.stamp}"
    assert [frame["offset"] for frame in stamp["keyframes"]] == [0, 0.35, 1]
    assert patterns["select.seep-slide"]["distance"] == 0.15
    assert all("reduceMotion" in pattern for pattern in patterns.values())


def test_common_files_pass_reference_checks():
    docs = {name: document for name, document in load_documents(COMPONENTS_DIR).items()
            if name in components.COMMON}
    ia = {"components": [], "screens": []}
    assert find_problems(docs, ia, token_names_by_theme(TOKENS_DIR)) == []


def components_by_id(groups):
    documents = load_documents(COMPONENTS_DIR)
    return {component["id"]: component for group in groups for component in documents[group]["components"]}


def variant_ids(component):
    return {variant["id"] for variant in component["variants"]}


# 범용 묶음 (V2 spec §6.1~§6.4)
def test_generic_groups_contain_spec_components():
    documents = load_documents(COMPONENTS_DIR)
    ids = {group: {c["id"] for c in documents[group]["components"]} for group in ("frame", "feedback", "input", "action")}
    assert ids["frame"] == {"tab-bar", "app-bar", "sheet"}
    assert ids["feedback"] == {"dialog", "toast", "notice-banner", "skeleton", "empty-state", "error-state"}
    assert ids["input"] == {"input-step", "text-field", "date-picker", "time-picker", "segmented", "city-search",
                            "check-row"}
    assert ids["action"] == {"primary-button", "social-login-button", "share-button", "settings-row"}


def test_generic_spec_values():
    c = components_by_id(("frame", "feedback", "input", "action"))
    assert c["primary-button"]["parts"]["container"]["radius"] == "{radius.md}"
    assert variant_ids(c["primary-button"]) == {"filled", "quiet", "destructive"}
    assert variant_ids(c["app-bar"]) == {"tab-root", "inner"}
    assert variant_ids(c["sheet"]) == {"half", "full"}
    assert variant_ids(c["date-picker"]) == {"birth", "calendar"}
    assert variant_ids(c["time-picker"]) == {"birth", "notify"}
    assert variant_ids(c["share-button"]) == {"icon", "pill"}
    assert "seal" in c["tab-bar"]["uses"] and "select.seep-slide" in c["segmented"]["uses"]
    assert c["toast"]["parts"]["container"]["bg"] == "{color.inverse.bg}"
    assert c["tab-bar"]["parts"]["container"]["bg"] == "{color.bar.bg}"
    assert "mark.caution" in json.dumps(c["dialog"])
    assert "focus.ring" in json.dumps(c["text-field"])
    assert "loading.breathe" in json.dumps(c["primary-button"]["states"]["loading"])


def test_state_map_matches_spec():
    state_map = load_documents(COMPONENTS_DIR)["feedback"]["stateMap"]
    assert state_map == {"loading": "skeleton", "empty": "empty-state", "error": "error-state",
                         "offline": "notice-banner", "draft": ["draft-indicator", "notice-banner"],
                         "time-unknown": "notice-banner", "out-of-range": "input-step"}

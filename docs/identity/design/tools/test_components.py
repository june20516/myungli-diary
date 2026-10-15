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

VERSION = components.CONTRACT_VERSION

IA = {
    "components": [{"id": "a"}, {"id": "b"}, {"id": "state-x"}],
    "screens": [{"id": "s", "states": [{"id": "loading"}]}, {"id": "t", "states": []}],
}
BASE_TOKENS = {"color.text.primary", "motion.duration.medium", "motion.easing.seep", "radius.md"}
TOKENS = {theme: set(BASE_TOKENS) for theme in ("light-ko", "light-ja", "dark-ko", "dark-ja")}


def valid_docs():
    return {
        "interaction": {
            "version": VERSION,
            "patterns": {"p": {"summary": "패턴", "duration": "{motion.duration.medium}",
                               "easing": "{motion.easing.seep}", "reduceMotion": "opacity-only",
                               "keyframes": [{"offset": 0}, {"offset": 1, "color": "{color.text.primary}"}]}},
            "haptics": {"selection": ["선택이 바뀜"]},
        },
        "elements": {"version": VERSION, "elements": {"el": {"summary": "요소"}}},
        "frame": {"version": VERSION, "group": "frame", "components": [
            {"id": "a", "summary": "가", "uses": ["el", "p"],
             "variants": [{"id": "v", "parts": {"label": {"fg": "{color.text.primary}"}}}],
             "parts": {"container": {"radius": "{radius.md}"}},
             "states": {"pressed": {"pattern": "p", "parts": {"x": {"bg": "{color.text.primary}"}}}}},
            {"id": "b", "summary": "나"},
        ]},
        "feedback": {"version": VERSION, "group": "feedback", "stateMap": {"loading": "state-x"},
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


def test_nested_pattern_duration_must_be_reference():
    docs = valid_docs()
    docs["interaction"]["patterns"]["p"]["outgoing"] = {"duration": {"value": 260, "unit": "ms"}}
    docs["frame"]["components"][0]["motion"] = {"steps": [{"easing": [0.2, 0.7, 0.2, 1]}]}
    problems = find_problems(docs, IA, TOKENS)
    assert has(problems, "outgoing.duration") and has(problems, "steps[0].easing")


def test_reference_inside_longer_string_is_reported():
    docs = valid_docs()
    docs["frame"]["components"][1]["parts"] = {"x": {"border": "1px {color.text.primary}"}}
    assert has(find_problems(docs, IA, TOKENS), "1px {color.text.primary}")


def test_malformed_shapes_are_reported_not_raised():
    docs = valid_docs()
    docs["frame"]["components"][0]["states"]["pressed"]["pattern"] = ["p"]
    docs["frame"]["components"][0]["uses"] = {"el": True}
    docs["feedback"]["stateMap"] = ["loading"]
    problems = find_problems(docs, IA, TOKENS)
    assert has(problems, "pattern") and has(problems, "uses") and has(problems, "stateMap")
    docs = valid_docs()
    docs["frame"]["components"] = {"a": {}}
    assert has(find_problems(docs, IA, TOKENS), "components")


def test_component_and_element_links_must_exist():
    docs = valid_docs()
    docs["frame"]["components"][1]["parts"] = {"x": {"component": "없는-컴포넌트"}, "y": {"element": "없는-요소"}}
    problems = find_problems(docs, IA, TOKENS)
    assert has(problems, "없는-컴포넌트") and has(problems, "없는-요소")


def test_duplicate_variant_id_is_reported():
    docs = valid_docs()
    docs["frame"]["components"][0]["variants"].append({"id": "v"})
    assert has(find_problems(docs, IA, TOKENS), "a", "v", "변형")


def test_reduce_motion_and_haptic_values_are_checked():
    docs = valid_docs()
    docs["interaction"]["patterns"]["p"]["reduceMotion"] = ""
    docs["frame"]["components"][0]["haptic"] = [{"when": "x", "strength": "heavy"}]
    problems = find_problems(docs, IA, TOKENS)
    assert has(problems, "reduceMotion") and has(problems, "heavy")


def test_markdown_pair_and_readme(tmp_path):
    (tmp_path / "frame.md").write_text("설명", encoding="utf-8")
    (tmp_path / "README.md").write_text("frame.json", encoding="utf-8")
    problems = find_problems(valid_docs(), IA, TOKENS, tmp_path)
    assert has(problems, "feedback.md")
    assert not has(problems, "frame.md")
    assert has(problems, "README", "feedback.json")
    assert has(problems, "README", f"컴포넌트 계약 {VERSION}")


def test_load_documents_reads_json_by_stem(tmp_path):
    (tmp_path / "frame.json").write_text(json.dumps({"version": VERSION}), encoding="utf-8")
    (tmp_path / "frame.md").write_text("설명", encoding="utf-8")
    assert load_documents(tmp_path) == {"frame": {"version": VERSION}}


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
        "skeleton.bone", "icon", "lock.veil"}


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
    assert ids["frame"] == {"tab-bar", "app-bar", "sheet", "ad-banner"}
    assert ids["feedback"] == {"dialog", "toast", "notice-banner", "skeleton", "empty-state", "error-state"}
    assert ids["input"] == {"input-step", "text-field", "date-picker", "time-picker", "segmented", "city-search",
                            "check-row"}
    assert ids["action"] == {"primary-button", "social-login-button", "share-button", "settings-row", "offer-card"}


# main IA 변경(D53)과 최종 리뷰 반영
def test_ad_banner_sits_above_tab_bar_with_bar_background():
    c = components_by_id(("frame", "feedback"))
    banner = c["ad-banner"]
    assert banner["parts"]["container"]["bg"] == "{color.bar.bg}"
    assert banner["parts"]["container"]["position"] == "above-tab-bar"
    assert {"adFree", "noFill"} <= set(banner["states"])
    assert "ad-banner" in " ".join(c["toast"]["rules"])


def test_offer_card_states():
    offer = components_by_id(("action",))["offer-card"]
    assert {"available", "active"} <= set(offer["states"])
    assert offer["parts"]["container"]["radius"] == "{radius.lg}"


def test_sage_text_on_soft_seal_uses_on_soft_token():
    c = components_by_id(("calendar", "today"))
    assert c["day-cell"]["states"]["selectedOnDiary"]["parts"]["number"]["fg"] == "{color.seal.on-soft}"
    assert "{color.seal.on-soft}" in json.dumps(c["guide-question-card"]["states"]["after"])


def test_generic_spec_values():
    c = components_by_id(("frame", "feedback", "input", "action"))
    assert c["primary-button"]["parts"]["container"]["radius"] == "{radius.md}"
    assert variant_ids(c["primary-button"]) == {"filled", "quiet", "destructive"}
    assert variant_ids(c["app-bar"]) == {"tab-root", "inner"}
    assert variant_ids(c["sheet"]) == {"half", "full"}
    assert variant_ids(c["date-picker"]) == {"birth", "calendar"}
    assert variant_ids(c["time-picker"]) == {"birth", "notify"}
    assert variant_ids(c["share-button"]) == {"icon", "soft"}
    assert "seal" in c["tab-bar"]["uses"] and "select.seep-slide" in c["segmented"]["uses"]
    assert c["toast"]["parts"]["container"]["bg"] == "{color.inverse.bg}"
    assert c["tab-bar"]["parts"]["container"]["bg"] == "{color.bar.bg}"
    assert "mark.caution" in json.dumps(c["dialog"])
    assert "focus.ring" in json.dumps(c["text-field"])
    assert "loading.breathe" in json.dumps(c["primary-button"]["states"]["loading"])


BRAND_GROUPS = ("sentence", "today", "calendar", "diary", "saju")


# 브랜드 묶음 (V2 spec §6.5~§6.9)
def test_brand_groups_contain_spec_components():
    documents = load_documents(COMPONENTS_DIR)
    ids = {group: {c["id"] for c in documents[group]["components"]} for group in BRAND_GROUPS}
    assert ids == {
        "sentence": {"sentence-block", "term-token", "depth-link", "reaction-button"},
        "today": {"day-character", "lucky-card", "guide-question-card", "share-image"},
        "calendar": {"calendar-month", "day-cell", "event-row"},
        "diary": {"diary-row", "diary-editor", "draft-indicator", "tag-chip"},
        "saju": {"saju-pillars", "ohaeng-bar", "manse-table", "daeun-table"},
    }


def test_brand_spec_values():
    c = components_by_id(BRAND_GROUPS)
    assert variant_ids(c["share-image"]) == {"story", "feed", "square"}
    assert variant_ids(c["term-token"]) >= {"inline", "label"}
    assert variant_ids(c["event-row"]) == {"summary", "list"}
    assert variant_ids(c["lucky-card"]) == {"color", "direction", "number", "time"}
    assert variant_ids(c["depth-link"]) == {"inline-end", "block", "navigate"}
    assert set(c["guide-question-card"]["states"]) >= {"before", "after"}
    assert set(c["draft-indicator"]["states"]) == {"local", "saving", "saved"}
    day = json.dumps(c["day-cell"])
    assert "{color.seal.soft}" in day and "outline" in day and "mark.underline-grow" in day
    assert "{color.tag.good.bg}" in json.dumps(c["tag-chip"]) and "tone" in c["tag-chip"]["uses"]
    assert "link.inline-nowrap" in json.dumps(c["depth-link"])
    assert "tag.me" in c["saju-pillars"]["uses"] and "highlight.current" in c["daeun-table"]["uses"]
    assert "surface.paper" in c["diary-editor"]["uses"] and "rail.timeline" in c["diary-row"]["uses"]
    assert "seal.stamp" in json.dumps(c["reaction-button"]) and "seal.stamp" in json.dumps(c["diary-editor"])


def test_day_cell_layer_order_and_event_rules():
    c = components_by_id(BRAND_GROUPS)
    assert c["day-cell"]["parts"]["layers"]["order"] == [
        "luck-fill", "diary-seal", "today-outline", "number", "selected-underline", "event-dot"]
    rules = " ".join(c["event-row"]["rules"])
    assert "진행 중" in rules and "다음" in rules and "하루 종일" in rules


def test_committed_component_files_pass_all_checks():
    ia = json.loads(IA_PATH.read_text(encoding="utf-8"))
    problems = find_problems(load_documents(COMPONENTS_DIR), ia, token_names_by_theme(TOKENS_DIR), COMPONENTS_DIR)
    assert problems == []


def test_all_spec_files_are_present():
    names = set(load_documents(COMPONENTS_DIR))
    assert names == set(components.GROUPS) | set(components.COMMON)


def test_cli_exit_code_is_zero(capsys):
    assert components.main() == 0
    assert "OK" in capsys.readouterr().out


def test_state_map_matches_spec():
    state_map = load_documents(COMPONENTS_DIR)["feedback"]["stateMap"]
    assert state_map == {"loading": "skeleton", "empty": "empty-state", "error": "error-state",
                         "offline": "notice-banner", "draft": ["draft-indicator", "notice-banner"],
                         "time-unknown": "notice-banner", "out-of-range": "input-step"}


# 근거 깊이 잠금과 모양 규칙 (depth-lock spec §2~§4)
def test_explain_sheet_has_no_personal_box_or_lock():
    term = components_by_id(BRAND_GROUPS)["term-token"]
    explain = term["parts"]["explainSheet"]
    assert "mine" not in explain and {"general", "todayReason", "evidenceLink"} <= set(explain)
    assert explain["evidenceLink"]["component"] == "depth-link"
    assert "locked" not in term["states"] and "lockedLabel" not in term["a11y"]


def test_evidence_sheet_lock_states():
    link = components_by_id(BRAND_GROUPS)["depth-link"]
    sheet = link["parts"]["evidenceSheet"]
    assert sheet["container"] == {"component": "sheet", "variant": "full"}
    assert {"pillars", "basis", "source", "personal"} <= set(sheet)
    assert set(link["states"]) == {"pressed", "locked", "lockedNoAd", "unlocking", "unlocked"}
    locked = link["states"]["locked"]["parts"]["evidenceSheet"]
    assert all(locked[section]["element"] == "lock.veil" for section in ("basis", "source", "personal"))
    assert locked["lockPanel"]["cta"] == {"component": "primary-button", "variant": "filled", "slot": "evidence-sheet.lock.cta"}
    assert "lock.veil" in link["uses"]
    no_ad = link["states"]["lockedNoAd"]["parts"]["evidenceSheet"]["lockPanel"]
    assert no_ad["cta"]["state"] == "disabled" and no_ad["unavailable"]["slot"] == "evidence-sheet.lock.unavailable"
    assert link["states"]["unlocking"]["parts"]["evidenceSheet"]["lockPanel"]["cta"]["state"] == "loading"
    assert link["states"]["unlocked"]["pattern"] == "appear.seep"


def test_locked_sentence_uses_veil():
    block = components_by_id(BRAND_GROUPS)["sentence-block"]
    assert block["states"]["locked"]["parts"]["text"]["element"] == "lock.veil"
    assert "lock.veil" in block["uses"]


def test_lock_veil_reuses_v2_blur_values():
    veil = load_documents(COMPONENTS_DIR)["elements"]["elements"]["lock.veil"]
    assert veil["body"]["blur"] == {"value": 6, "unit": "px"} and veil["body"]["opacity"] == 0.5
    assert veil["body"]["selectable"] is False and veil["title"]["icon"] == "lock-simple"


def test_actions_are_rounded_rectangles():
    c = components_by_id(("frame", "feedback", "input", "action"))
    soft = next(v for v in c["share-button"]["variants"] if v["id"] == "soft")
    assert soft["parts"]["container"]["radius"] == "{radius.md}"
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "`radius.md`" in readme and "`radius.full`" in readme and "`space.20`" in readme


def test_contract_version_is_2_3():
    assert VERSION == "2.3.0"


def test_icon_set_version_is_not_contract_version():
    assert load_documents(COMPONENTS_DIR)["elements"]["elements"]["icon"]["set"]["version"] == "2.1.2"


def test_readme_states_minimum_height_rule():
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "최소 높이" in readme and "| 2.3.0 | 2026-10-15 |" in readme


def ia_screens():
    return {screen["id"]: screen for screen in json.loads(IA_PATH.read_text(encoding="utf-8"))["screens"]}


def ia_slot_ids(screen_id):
    return {slot["id"] for slot in ia_screens()[screen_id]["slots"]}


# 문장 조각과 잠금 슬롯 (term-segments spec §2·§3)
def test_term_segments_draw_chip_only_where_term_token_is():
    block = components_by_id(BRAND_GROUPS)["sentence-block"]
    term = block["parts"]["segments"]["term"]
    assert term["component"] == "term-token" and term["variant"] == "inline"
    expected = {sid for sid, screen in ia_screens().items() if "term-token" in screen.get("components", [])}
    assert set(term["screens"]) == expected
    assert term["elsewhere"] == "plain"
    assert block["parts"]["segments"]["plain"] == {"style": "same-as-text"}


def test_locked_sentence_open_slot():
    block = components_by_id(BRAND_GROUPS)["sentence-block"]
    assert block["states"]["locked"]["parts"]["open"]["slot"] == "saju-chart.yongsin.open"
    assert block["a11y"]["lockedLabelSlot"] == "evidence-sheet.a11y.locked"
    assert block["a11y"]["lockedNameSlot"] == "saju-chart.yongsin.title"
    assert block["a11y"]["lockedLabel"] == "구역 이름 + '잠김', 열기는 따로 초점(link)"
    assert {"saju-chart.yongsin.open", "saju-chart.yongsin.title"} <= ia_slot_ids("saju-chart")
    assert "evidence-sheet.a11y.locked" in ia_slot_ids("evidence-sheet")


def test_evidence_sheet_section_titles_and_slots():
    link = components_by_id(BRAND_GROUPS)["depth-link"]
    sheet = link["parts"]["evidenceSheet"]
    titles = {"basisTitle": "evidence-sheet.section.basis", "sourceTitle": "evidence-sheet.section.source",
              "personalTitle": "evidence-sheet.section.personal"}
    assert {name: sheet[name]["slot"] for name in titles} == titles
    assert sheet["personalTitle"]["when"] == sheet["personal"]["when"]
    locked = link["states"]["locked"]["parts"]["evidenceSheet"]
    assert not set(titles) & set(locked)  # 제목은 잠겨도 또렷함
    toast = link["states"]["unlocking"]["parts"]["evidenceSheet"]["failedToast"]
    assert toast == {"component": "toast", "slot": "evidence-sheet.unlock.failed"}
    a11y = link["a11y"]
    assert (a11y["lockedLabelSlot"], a11y["unlockingLabelSlot"], a11y["unlockedAnnouncementSlot"]) == (
        "evidence-sheet.a11y.locked", "evidence-sheet.a11y.checking", "evidence-sheet.a11y.unlocked")
    assert a11y["lockedLabel"] == "구역 이름 + '잠김'" and a11y["unlockingLabel"] == "확인 중"
    used = set(titles.values()) | {toast["slot"], a11y["lockedLabelSlot"], a11y["unlockingLabelSlot"],
                                   a11y["unlockedAnnouncementSlot"]}
    assert used <= ia_slot_ids("evidence-sheet")


# 최종 리뷰 반영 (term-segments spec §2.1·§2.6)
SLOTS_OUTSIDE_IA = {"user-honorific", "image.footer"}  # 호칭 자리, 공유 이미지 꼬리말: IA 화면 슬롯이 아닌 공통 자리


def _slot_values(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if (key == "slot" or key.endswith("Slot")) and isinstance(value, str):
                yield value
            yield from _slot_values(value)
    elif isinstance(node, list):
        for value in node:
            yield from _slot_values(value)


def test_every_slot_exists_in_ia():
    ia_slots = {slot["id"] for screen in ia_screens().values() for slot in screen.get("slots", [])}
    used = {value for document in load_documents(COMPONENTS_DIR).values() for value in _slot_values(document)}
    assert used - ia_slots == SLOTS_OUTSIDE_IA


def test_locked_evidence_sheet_never_veils_titles():
    locked = components_by_id(BRAND_GROUPS)["depth-link"]["states"]["locked"]["parts"]["evidenceSheet"]
    assert not [key for key in locked if key == "sectionTitle" or key.endswith("Title")]


def test_other_content_text_parts_follow_segments():
    c = components_by_id(BRAND_GROUPS)
    assert c["day-character"]["parts"]["reason"]["segments"] == "sentence-block"
    assert c["lucky-card"]["parts"]["explain"]["segments"] == "sentence-block"


def test_terms_inside_pressable_containers_are_plain():
    c = components_by_id(BRAND_GROUPS)
    term = c["sentence-block"]["parts"]["segments"]["term"]
    pressable_with_sentence = {
        component["id"] for component in c.values()
        if component.get("a11y", {}).get("role") == "button"
        and any(isinstance(part, dict) and part.get("component") == "sentence-block"
                for part in component.get("parts", {}).values())}
    assert term["insidePressable"]["draw"] == "plain"
    assert set(term["insidePressable"]["containers"]) == pressable_with_sentence == {"diary-row"}
    assert "term.bg" in term["textColorChange"] and "term.fg" in term["textColorChange"]


def test_term_focus_rule_is_conditional():
    a11y = components_by_id(BRAND_GROUPS)["sentence-block"]["a11y"]
    assert a11y["terms"].startswith("term-token이 있는 화면에서는")


# 구현 대응·IA v3 (spec-followups spec §2~§4, 계약 2.3.0)
def component(group, component_id):
    return next(c for c in load_documents(COMPONENTS_DIR)[group]["components"] if c["id"] == component_id)


CHEVRON = {"icon": "caret-right", "weight": "regular", "size": "link-text-size", "color": "link-color",
           "gap": {"value": 2, "unit": "px"}, "decorative": True}


def test_text_link_chevrons_are_component_drawn_icons():
    depth_link = component("sentence", "depth-link")
    block = component("sentence", "sentence-block")
    assert depth_link["parts"]["chevron"] == CHEVRON
    assert block["states"]["locked"]["parts"]["open"]["chevron"] == CHEVRON
    assert depth_link["states"]["locked"]["parts"]["evidenceSheet"]["lockPanel"]["pass"]["chevron"] == CHEVRON
    assert any("원고에 넣지 않" in rule for rule in depth_link["rules"])


def test_depth_link_navigate_goes_to_a_page():
    depth_link = component("sentence", "depth-link")
    navigate = next(v for v in depth_link["variants"] if v["id"] == "navigate")
    assert navigate["parts"]["target"] == {"presentation": "page", "transition": "platform-default"}
    assert navigate["parts"]["label"]["slot"] == "birthplace.standard.link"
    assert any("navigate" in rule and "sheet.enter" in rule for rule in depth_link["rules"])
    assert "birthplace" in (COMPONENTS_DIR / "sentence.md").read_text(encoding="utf-8")


def test_unlocked_evidence_sheet_omits_empty_sections():
    rules = component("sentence", "depth-link")["rules"]
    assert any("unlocked" in rule and "본문이 없는 구역" in rule for rule in rules)


def test_segmented_has_unselected_state():
    segmented = component("input", "segmented")
    none = segmented["states"]["none"]
    assert none["parts"]["indicator"] == {"visible": False}
    assert none["parts"]["label"] == {"fg": "{color.text.secondary}"}
    assert none["pattern"] == "appear.seep" and "appear.seep" in segmented["uses"]


def test_input_step_omits_bottom_action_for_pick_and_go_steps():
    step = component("input", "input-step")
    assert "birthplace" in step["parts"]["bottomAction"]["omitWhen"]
    assert any("아래 버튼을 두지 않는다" in rule for rule in step["rules"])


def test_date_picker_leap_month_fallback():
    birth = next(v for v in component("input", "date-picker")["variants"] if v["id"] == "birth")
    fallback = birth["parts"]["leapMonthFallback"]
    assert (fallback["component"], fallback["variant"]) == ("check-row", "inline")
    assert fallback["replaces"] == ["leapMonth", "solarConfirm"]
    assert "leapMonth" in birth["parts"] and "solarConfirm" in birth["parts"]


def test_city_search_never_shows_country_code():
    city = component("input", "city-search")
    assert city["parts"]["region"]["whenMissing"] == "hidden"
    assert any("나라 코드" in rule for rule in city["rules"])


def test_dialog_notice_has_one_button():
    notice = next(v for v in component("feedback", "dialog")["variants"] if v["id"] == "notice")
    assert notice["parts"]["cancel"] == {"visible": False}
    assert notice["a11y"] == {"focusOnOpen": "confirm", "dismissOnScrim": True}
    assert "login.discard.notice" in notice["when"]


def test_social_login_disabled_and_apple_label():
    button = component("action", "social-login-button")
    assert button["states"]["disabled"]["parts"]["container"] == {"opacity": 0.4}
    apple = next(v for v in button["variants"] if v["id"] == "apple")
    assert apple["parts"]["label"] == {"fontFamily": "platform-system", "type": "{type.label.lg}"}

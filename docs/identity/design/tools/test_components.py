"""컴포넌트 명세 검사기 테스트 (V2 spec §7)."""
import copy
import json
import pathlib
import re
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
        "seal.erase", "mark.underline-grow", "sheet.enter", "sheet.exit", "sheet.stack", "focus.ring",
        "page.push"}  # DS1 V67
    assert set(docs["elements"]["elements"]) == {
        "seal", "ohaeng.cell", "ohaeng.swatch", "tone", "tag.status", "tag.me", "highlight.current",
        "mark.underline-grow", "mark.caution", "surface.paper", "rail.timeline", "term",  # link.inline-nowrap은 V63으로 지움
        "skeleton.bone", "icon", "lock.veil",
        "list.divider", "button.pair",  # DS1 V58·V60. section.header·explain.sheet는 컴포넌트로 옮김(V69·V71)
        "stem.chip"}  # DS1 2단계 V72


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
    assert ids["frame"] == {"tab-bar", "app-bar", "sheet", "ad-banner", "section-header", "explain-sheet"}
    assert ids["feedback"] == {"dialog", "toast", "notice-banner", "skeleton", "empty-state", "error-state"}
    assert ids["input"] == {"input-step", "text-field", "date-picker", "time-picker", "segmented", "city-search",
                            "check-row", "account-choice"}
    assert ids["action"] == {"primary-button", "social-login-button", "share-button", "settings-row", "offer-card",
                             "purchase-row"}


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
    # D88 ②: 구매 복원 버튼 대신 구매 내역으로 가는 버튼 (#494)
    assert "restore" not in offer["parts"]
    assert offer["parts"]["history"] == {"component": "primary-button", "variant": "quiet", "slot": "ad-free.history.cta"}
    assert "history" not in offer["states"]["offline"]["parts"]
    # #548: 구매 버튼과 기간 고지를 IA 슬롯에 걸음
    assert offer["parts"]["buy"]["slot"] == "ad-free.buy.cta"
    assert offer["parts"]["period"]["slot"] == "ad-free.offer.period"
    assert any("구매 내역 버튼은 상태와 관계없이 늘 보인다" in rule for rule in offer["rules"])
    assert offer["haptic"] == [{"when": "구매 완료", "strength": "light"}]


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
    assert variant_ids(c["date-picker"]) == {"birth", "solar", "calendar"}
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
        "sentence": {"sentence-block", "term-token", "depth-link", "reaction-button", "hanja-tag"},
        "today": {"day-character", "lucky-card", "guide-question-card", "share-image"},
        "calendar": {"calendar-month", "day-cell", "event-row"},
        "diary": {"diary-row", "diary-editor", "draft-indicator", "tag-chip", "diary-summary"},
        "saju": {"saju-pillars", "ohaeng-bar", "manse-table", "daeun-table", "luck-pillar"},
    }


def test_brand_spec_values():
    c = components_by_id(BRAND_GROUPS)
    assert variant_ids(c["share-image"]) == {"story", "feed", "square"}
    assert variant_ids(c["term-token"]) >= {"inline", "label"}
    assert variant_ids(c["event-row"]) == {"summary", "list"}
    assert variant_ids(c["lucky-card"]) == {"color", "direction", "number", "time", "tag"}
    assert variant_ids(c["depth-link"]) == {"inline-end", "block", "navigate"}
    assert set(c["guide-question-card"]["states"]) >= {"before", "after"}
    assert set(c["draft-indicator"]["states"]) == {"local", "saving", "saved"}
    day = json.dumps(c["day-cell"])
    assert "{color.seal.soft}" in day and "outline" in day and "mark.underline-grow" in day
    assert "{color.tag.good.bg}" in json.dumps(c["tag-chip"]) and "tone" in c["tag-chip"]["uses"]
    assert c["depth-link"]["parts"]["icon"]["icon"] == "book-open-text"  # V63: 근거 진입점은 아이콘
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
    assert state_map == {"loading": "skeleton", "empty": "empty-state", "error": ["error-state", "notice-banner"],
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


def test_contract_version_is_4_0():
    assert VERSION == "4.0.0"  # DS1(#801): 지운 이름이 있어 주 버전
    contracts = (DESIGN_DIR.parents[2] / "docs" / "contracts" / "README.md").read_text(encoding="utf-8")
    row = next(line for line in contracts.splitlines() if line.startswith("| 컴포넌트 명세 |"))
    assert f"| {VERSION} |" in row


def test_icon_set_version_is_not_contract_version():
    assert load_documents(COMPONENTS_DIR)["elements"]["elements"]["icon"]["set"]["version"] == "2.1.2"


def test_readme_states_minimum_height_rule():
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "최소 높이" in readme and "| 2.3.0 | 2026-10-15 |" in readme and "| 2.4.0 | 2026-10-16 |" in readme
    assert "| 2.5.0 | 2026-10-16 |" in readme and "| 2.6.0 | 2026-10-20 |" in readme
    assert "| 2.6.1 | 2026-10-20 |" in readme


def ia_screens():
    return {screen["id"]: screen for screen in json.loads(IA_PATH.read_text(encoding="utf-8"))["screens"]}


def ia_slot_ids(screen_id):
    return {slot["id"] for slot in ia_screens()[screen_id]["slots"]}


# DS1 2단계 spec §1 표(IA v5 새 컴포넌트 15개)와 대조하는 고정 사본입니다. 명세를 쓸 때마다
# IA_PENDING_COMPONENTS에서만 빼고 이 상수는 그대로 둡니다.
IA_V5_NEW_COMPONENTS = {
    "section-header", "hanja-tag", "explain-sheet", "date-header", "tag-sentence-list", "fortune-verdict",
    "score-row", "score-scale", "date-block", "diary-summary", "luck-pillar", "birth-info-row", "band-table",
    "stage-strip", "scroll-hint",
}


def test_pending_ia_components_are_known():
    ia_ids = {component["id"] for component in json.loads(IA_PATH.read_text(encoding="utf-8"))["components"]}
    documents = load_documents(COMPONENTS_DIR)
    specified = {component["id"] for name in components.GROUPS for component in documents[name]["components"]}
    assert components.IA_PENDING_COMPONENTS <= IA_V5_NEW_COMPONENTS  # 목록은 새 15개 안에서만 줄어듦
    assert components.IA_PENDING_COMPONENTS == ia_ids - specified  # 명세가 생기면 목록에서 빼야 통과
    assert not components.IA_PENDING_COMPONENTS & specified


def test_pending_exempts_only_missing_spec_problem(monkeypatch):
    docs = valid_docs()
    docs["frame"]["components"].pop()
    assert has(find_problems(docs, IA, TOKENS), "b", "명세가 없음")
    monkeypatch.setattr(components, "IA_PENDING_COMPONENTS", frozenset({"b", "not-in-ia"}))
    problems = find_problems(docs, IA, TOKENS)
    assert not has(problems, "명세가 없음")
    docs["frame"]["components"].append({"id": "not-in-ia", "summary": "IA에 없음"})
    assert has(find_problems(docs, IA, TOKENS), "not-in-ia", "IA에 없는 컴포넌트")  # 다른 문제는 계속 나옴


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
# IA 밖 writing ui 슬롯(D77 ②): 컴포넌트 안 낱말 (#389)
SLOTS_OUTSIDE_IA |= {"ui.account-merge.choice", "ui.account-merge.saju", "ui.login-methods.row", "ui.day-cell.lunar"}
# D88 구매 줄 낱말 (#494). 가져올 기록 상자(ui.account-merge.summary)는 컴포넌트가 아닌 화면 배치라 input.md에만 있음
SLOTS_OUTSIDE_IA |= {"ui.purchase.meta", "ui.purchase.product", "ui.purchase.status"}
# W51 사주 표 낱말과 근거 시트 빈 안내 (#710)
SLOTS_OUTSIDE_IA |= {"ui.saju.header", "ui.saju.tag", "ui.evidence.personal-empty"}
# 근거 아이콘의 스크린리더 이름 (DS1, V63). IA 자리 today.evidence.link를 담은 writing 슬롯(W33)
SLOTS_OUTSIDE_IA |= {"ui.depth.evidence_link"}
# 키보드 내리기 버튼의 스크린리더 이름 (DS1, V68). writing 새 슬롯 요청
SLOTS_OUTSIDE_IA |= {"ui.keyboard.dismiss"}


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
    assert c["lucky-card"]["parts"]["explain"]["body"]["segments"] == "sentence-block"  # V62: 설명 시트 본문


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


CHEVRON = {"icon": "caret-right", "weight": "regular", "size": "adjacent-text", "color": "link-color",
           "gap": "{space.2}", "decorative": True}  # V57·V56: 크기는 옆 글자 단계, 간격은 토큰


def test_text_link_chevrons_are_component_drawn_icons():
    depth_link = component("sentence", "depth-link")
    block = component("sentence", "sentence-block")
    assert next(v for v in depth_link["variants"] if v["id"] == "navigate")["parts"]["chevron"] == CHEVRON  # V63: 글자 링크만
    assert "chevron" not in block["states"]["locked"]["parts"]["open"]  # V73: 잠긴 것을 여는 입구는 자물쇠
    assert depth_link["states"]["locked"]["parts"]["evidenceSheet"]["lockPanel"]["pass"]["chevron"] == CHEVRON
    assert any("원고에 넣지 않" in rule for rule in depth_link["rules"])


def test_depth_link_navigate_goes_to_a_page():
    depth_link = component("sentence", "depth-link")
    navigate = next(v for v in depth_link["variants"] if v["id"] == "navigate")
    assert navigate["parts"]["target"] == {"presentation": "page", "transition": "page.push"}  # V67
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
    assert "pattern" not in none and "appear.seep" in segmented["uses"]
    assert any("none" in rule and "appear.seep" in rule for rule in segmented["rules"])


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


def test_tab_icons_cover_ia_tabs():
    icons = component("frame", "tab-bar")["parts"]["icons"]
    assert icons == {"today": "sun", "calendar": "calendar-blank", "diary": "notebook", "me": "user"}
    assert set(icons) == {screen["tab"] for screen in ia_screens().values() if screen["tab"]}


def test_app_bar_hides_back_on_flow_first_screens():
    rules = component("frame", "app-bar")["rules"]
    assert any("consent" in rule and "notify-ask" in rule and "뒤로" in rule for rule in rules)


def test_lucky_time_value_format():
    # 범위 표기는 언어별(writing W44), 구간마다 칩 하나라 구간을 잇는 글자가 없음 (#546, 결정 V52)
    time = next(v for v in component("today", "lucky-card")["variants"] if v["id"] == "time")
    assert time["parts"]["value"] == {
        "format": {"ko": "HH:mm~HH:mm", "ja": "HH:mm〜HH:mm", "en": "HH:mm to HH:mm"},
        "clock": "24h", "timeZone": "profile", "fontFeatures": ["tnum"],
    }
    assert time["repeat"] == {"each": "FocusTimeCard.picks", "max": 2}


def test_lucky_card_has_no_banned_punctuation():
    # 화면에 보이는 형식에 범위 대시와 가운뎃점을 쓰지 않음 (D93)
    time = next(v for v in component("today", "lucky-card")["variants"] if v["id"] == "time")
    text = json.dumps(time, ensure_ascii=False)
    assert "–" not in text and "·" not in text and "—" not in text
    rules = " ".join(component("today", "lucky-card")["rules"])
    assert "최대 7개" in rules and "첫 구간" in rules


def test_element_values_from_app_feedback():
    elements = load_documents(COMPONENTS_DIR)["elements"]["elements"]
    assert elements["icon"]["set"]["flutter"] == "phosphor_glyphs"
    assert elements["icon"]["set"]["flutterVersion"] == "2.1.2+1"
    assert elements["mark.caution"]["size"] == "adjacent-text"  # V57
    assert elements["lock.veil"]["lines"] == {"default": "server 길이 힌트, 없으면 2", "sentence-block locked": 1}


# app 질문 #195·#211 (계약 2.4.0)
def test_city_search_row_shows_saving_after_pick():
    city = component("input", "city-search")
    saving = city["states"]["saving"]
    assert saving["pattern"] == "loading.breathe" and "loading.breathe" in city["uses"]
    assert saving["parts"]["dots"] == {"visible": True, "position": "row-end", "fg": "{color.text.secondary}"}
    assert saving["parts"]["otherRows"] == {"pressable": False}
    assert city["a11y"]["busyAnnounced"] == "처리 중"


def test_city_search_region_joiner_per_language():
    region = component("input", "city-search")["parts"]["region"]
    assert region["join"] == {"ko": ", ", "en": ", ", "ja": "、"}


def test_input_step_preface_spacing():
    preface = component("input", "input-step")["parts"]["preface"]
    assert preface["marginTop"] == "{space.24}" and preface["marginBottom"] == "{space.24}"


def test_skeleton_text_line_follows_coming_type():
    line = component("feedback", "skeleton")["parts"]["textLine"]
    assert line["type"] == {"default": "{type.body.ui}", "rule": "실제 올 글자 스타일"}


def test_frame_md_states_prose_page_body():
    frame = (COMPONENTS_DIR / "frame.md").read_text(encoding="utf-8")
    assert "안내 글 본문" in frame and "`space.32`" in frame


# 오늘 화면 대표 태그 칩 #239 (D76, 계약 2.5.0)
def test_lucky_tag_chip_emphasises_weight_and_icon_only():
    card = component("today", "lucky-card")
    tag = next(v for v in card["variants"] if v["id"] == "tag")
    assert tag["parts"] == {"lead": {"icon": "tag", "iconColor": "{color.text.primary}"},
                            "value": {"fontWeight": 600}}
    assert "color.tag" not in json.dumps(card)


def test_lucky_tag_chip_order_and_polarity_rules():
    rules = component("today", "lucky-card")["rules"]
    assert any("tag" in rule and "맨 앞" in rule and "행운 4종(color·direction·number·time) 앞" in rule and "Daily.tags.featured" in rule for rule in rules)
    assert any("polarity" in rule and "D72" in rule for rule in rules)
    assert any("today.lucky-tag.body" in rule for rule in rules)


# app 계획 4 달력·일정 확인 #218 (계약 2.6.0)
def test_date_picker_solar_has_no_lunar_parts():
    solar = next(v for v in component("input", "date-picker")["variants"] if v["id"] == "solar")
    assert solar["parts"]["calendarType"] == {"visible": False}
    assert not {"leapMonth", "solarConfirm", "leapMonthFallback"} & set(solar["parts"])
    assert "event-edit(`solar`)" in (COMPONENTS_DIR / "input.md").read_text(encoding="utf-8")


def test_text_field_multiline_grows_to_six_lines():
    field = component("input", "text-field")
    multiline = next(v for v in field["variants"] if v["id"] == "multiline")
    assert multiline["parts"]["container"] == {"minLines": 1, "maxLines": 6, "overflow": "scroll"}
    assert multiline["parts"]["keyboard"] == {"type": "multiline", "action": "newline"}


def test_text_field_label_error_line_and_email_for_contact():
    # D102 문의 화면: 칸이 둘이라 칸 위 이름, input-step 밖 오류 줄, 메일 키보드 (#763, 결정 V55)
    field = component("input", "text-field")
    label, error_line = field["parts"]["label"], field["parts"]["errorLine"]
    assert (label["type"], label["marginBottom"], label["optional"]) == ("{type.label.md}", "{space.8}", True)
    input_step_error = component("input", "input-step")["parts"]["errorLine"]
    assert {k: error_line[k] for k in input_step_error} == input_step_error
    email = next(v for v in field["variants"] if v["id"] == "email")
    assert email["parts"]["keyboard"]["type"] == "email" and email["parts"]["keyboard"]["autocorrect"] is False
    assert any("minLines 4" in rule for rule in field["rules"])
    layout = (COMPONENTS_DIR / "input.md").read_text(encoding="utf-8").split("### contact 화면 배치", 1)[1]
    ia = json.loads((DESIGN_DIR.parents[2] / "docs" / "ia" / "screens.json").read_text(encoding="utf-8"))
    contact = next(screen for screen in ia["screens"] if screen["id"] == "contact")
    # IA 슬롯이 배치에 모두 나옴
    assert all(f"`{slot['id']}`" in layout for slot in contact["slots"])
    assert "contactEmailInvalid" in layout and "contactSendFailed" in layout


def test_event_row_has_no_duration_and_reads_more():
    row = component("calendar", "event-row")
    assert any("길이가 없다" in rule for rule in row["rules"])
    assert row["a11y"]["moreJoin"] == "a11yListSeparator"
    summary, listed = (next(v for v in row["variants"] if v["id"] == key) for key in ("summary", "list"))
    assert summary["parts"]["twoLines"]["lines"] == [["status", "time"], ["title", "more"]]
    assert listed["parts"]["timeColumn"]["overflow"]["lines"] == [["time"], ["title", "chevron"]]
    assert listed["parts"]["add"]["slot"] == listed["parts"]["failed"]["add"]["slot"] == "day-sheet.event.add"
    assert listed["parts"]["failed"]["retry"] == {"component": "primary-button", "variant": "quiet"}


def test_day_cell_leap_month_and_height_rule():
    cell = component("calendar", "day-cell")
    assert "leapNewMoon" in cell["parts"]["lunar"]
    assert cell["parts"]["lunar"]["leapNewMoon"] == {"slot": "ui.day-cell.lunar", "key": "dayCellLeapNewMoon",
                                                      "text": "윤달 표지 + M.1 (예: 윤6.1)"}
    assert "dayCellLeapMonth" in cell["a11y"]["leapMonth"]
    assert any("최소 높이" in rule and "V36" in rule for rule in cell["rules"])
    assert not any("칸 높이를 늘린다" in rule for rule in cell["rules"])


def test_delete_dialogs_are_destructive():
    dialog = component("feedback", "dialog")
    destructive = next(v for v in dialog["variants"] if v["id"] == "destructive")
    assert "일정 삭제" in destructive["when"]


def test_evidence_sheet_stacks_many_items_and_hanja_font():
    sentence = load_documents(COMPONENTS_DIR)["sentence"]
    by_id = {c["id"]: c for c in sentence["components"]}
    sheet = by_id["depth-link"]["parts"]["evidenceSheet"]
    assert sheet["basis"]["repeat"] == {"each": "paragraph", "gap": "{space.12}", "skipEmpty": True}
    assert sheet["source"]["repeat"] == {"each": "box", "gap": "{space.12}", "skipEmpty": True}
    assert sheet["source"]["fontFallback"] == "{font.family.hanja}"
    assert by_id["term-token"]["parts"]["explainSheet"]["hanja"]["fontFamily"] == "{font.family.hanja}"


def test_day_sheet_diary_entrances():
    calendar_md = (COMPONENTS_DIR / "calendar.md").read_text(encoding="utf-8")
    assert "`day-sheet.diary.write-cta`" in calendar_md and "V42" in calendar_md


# 규칙 정합성 점검 #284 (D78): MD "쓰는 화면"은 IA components와 같다


def used_on_lines():
    """MD의 컴포넌트 절(## id)마다 "쓰는 화면" 줄에서 읽은 IA 화면 id. IA 전체를 가리키는 줄은 건너뜁니다."""
    screens = set(ia_screens())
    for md in sorted(COMPONENTS_DIR.glob("*.md")):
        current = None
        for line in md.read_text(encoding="utf-8").splitlines():
            heading = re.match(r"^## `?([a-z-]+)`?\s*$", line)
            if line.startswith("## "):
                current = heading.group(1) if heading else None
            if current and line.startswith("* 쓰는 화면") and "IA `" not in line:
                outside_code = re.sub(r"`[^`]*`", "", line)
                yield md.name, current, {token for token in re.findall(r"[a-z][a-z-]+", outside_code) if token in screens}


def test_md_used_on_matches_ia_components():
    used = {}
    for screen in ia_screens().values():
        for component_id in screen["components"]:
            used.setdefault(component_id, set()).add(screen["id"])
    checked = 0
    for name, component_id, listed in used_on_lines():
        if component_id not in used:
            continue
        checked += 1
        assert listed == used[component_id], (name, component_id)
    assert checked >= 30


# 로그인 수단·계정 합치기 (#389, D82·D83, 결정 V39~V41)


def test_account_choice_starts_unselected():
    choice = component("input", "account-choice")
    assert set(choice["states"]) == {"none", "selected", "pressed", "loading", "disabled"}
    assert "합치는 중" in choice["states"]["disabled"]["note"]
    assert any("합치는 중에는 고름을 잠근다" in rule for rule in choice["rules"])
    assert choice["states"]["selected"]["parts"]["card"]["border"] == {"color": "{color.action.primary}", "width": {"value": 2, "unit": "px"}}
    assert choice["states"]["loading"]["pattern"] == "loading.breathe"
    assert any("처음부터 어느 쪽도 골라 두지 않는다" in rule for rule in choice["rules"])
    assert choice["a11y"]["role"] == "radio-group" and choice["a11y"]["labelSlot"] == "account-merge.choice.label"
    assert choice["haptic"] == [{"when": "고름이 바뀜", "strength": "selection"}]


def test_account_choice_card_lines():
    parts = component("input", "account-choice")["parts"]
    assert parts["card"]["bg"] == "{color.bg.sheet}" and parts["card"]["radius"] == "{radius.md}"
    assert parts["current"]["radius"] == "{radius.full}" and parts["current"]["slot"] == "ui.account-merge.choice"
    assert parts["saju"]["slot"] == "ui.account-merge.saju"
    assert parts["mark"]["radius"] == "{radius.full}"
    # V44: 기록은 모두 옮기고 인증 수단은 옮기지 않아 일기 수·수단 이름 줄을 지움
    assert not {"facts", "diaryCount", "providers"} & set(parts)
    shape = ("type", "fg", "border", "radius", "paddingX")
    assert {k: parts["other"][k] for k in shape} == {k: parts["current"][k] for k in shape}
    assert parts["other"]["slot"] == "ui.account-merge.choice" and parts["other"]["key"] == "accountChoiceOther"


def test_social_login_order_per_language():
    button = component("action", "social-login-button")
    assert [v["id"] for v in button["variants"]] == ["kakao", "line", "google", "apple"]
    assert button["parts"]["stack"]["order"] == {"base": ["kakao", "line", "google", "apple"],
                                                 "top": {"ko": "kakao", "ja": "line", "en": "google"}}
    assert not any("카카오 위, Apple 아래" in rule for rule in button["rules"])


def test_social_login_provider_guides():
    variants = {v["id"]: v for v in component("action", "social-login-button")["variants"]}
    line = variants["line"]["parts"]
    assert line["container"]["bg"] == "#06C755" and line["label"]["fg"] == "#FFFFFF"
    assert line["pressed"]["overlay"] == {"color": "#000000", "opacity": 0.3}
    google = variants["google"]["parts"]
    assert google["container"]["lightMode"] == {"bg": "#FFFFFF", "border": "#747775", "fg": "#1F1F1F"}
    assert google["container"]["darkMode"] == {"bg": "#131314", "border": "#8E918F", "fg": "#E3E3E3"}
    assert google["label"]["fontFamily"] == "Google Sans Medium"
    assert google["label"]["fontFallback"] == "platform-system"
    assert google["logo"]["backdrop"] == "theme-background"
    assert line["separator"]["source"] == "provider-official-asset"


def test_social_login_connected_is_neutral():
    connected = component("action", "social-login-button")["states"]["connected"]
    parts = connected["parts"]
    assert parts["container"]["bg"] == "{color.bg.sheet}"
    assert parts["container"]["border"] == {"color": "{color.line}", "width": {"value": 1, "unit": "px"}}
    assert parts["state"]["fg"] == "{color.action.primary}" and parts["state"]["icon"] == "check"
    assert parts["logo"]["badge"] == {
        "size": {"value": 20, "unit": "px"}, "symbolSize": {"value": 14, "unit": "px"},
        "kakao": {"bg": "#FEE500", "symbol": "#191919", "shape": "{radius.xs}"},
        "line": {"bg": "#06C755", "symbol": "#FFFFFF", "shape": "{radius.xs}"},
        "google": {"bg": "#FFFFFF", "symbol": "full-color", "shape": "{radius.full}"},
        "apple": {"lightMode": {"bg": "#000000", "symbol": "#FFFFFF"}, "darkMode": {"bg": "#FFFFFF", "symbol": "#000000"},
                  "shape": "{radius.xs}"},
    }
    assert parts["state"]["gap"] == "{space.4}"
    assert "loading" in connected and "disabled" in connected
    assert connected["lastOne"]["pressable"] is False and connected["lastOne"]["noticeSlot"] == "login-methods.last.notice"
    assert connected["onPress"] == {"component": "dialog", "variant": "destructive", "slot": "login-methods.unlink.confirm"}


def test_two_button_dialogs_have_no_first_focus():
    dialog = component("feedback", "dialog")
    variants = {v["id"]: v for v in dialog["variants"]}
    assert "focusOnOpen" not in dialog["a11y"]
    assert variants["destructive"]["a11y"] == {"dismissOnScrim": False, "backIs": "cancel"}
    assert variants["notice"]["a11y"] == {"focusOnOpen": "confirm", "dismissOnScrim": True}
    assert not any("처음 초점" in rule for rule in dialog["rules"])
    assert any("뒤로 가기는 취소" in rule and "V41" in rule for rule in dialog["rules"])
    assert "계정 합치기" in variants["destructive"]["when"] and "로그인 수단 떼기" in variants["destructive"]["when"]


def test_account_merge_layout_keeps_emphasis_on_confirm():
    input_md = (COMPONENTS_DIR / "input.md").read_text(encoding="utf-8")
    section = input_md.split("## account-choice", 1)[1]
    assert "`account-merge.overlap.notice`" in section and "`mark.caution`을 쓰지 않" in section
    assert "`account-merge.merge.confirm`" in section and "`destructive`" in section
    assert "`ui.account-merge.error`" in section and "`notice`" in section


# 같은 날 여러 편 (2026-10-22-diary-row-multi-design.md §2·§3, 결정 V42)
def test_diary_row_same_day_entries():
    row = component("diary", "diary-row")
    assert [variant["id"] for variant in row["variants"]] == ["day", "entries"]
    entry = row["parts"]["entry"]
    assert entry["divider"] == {"style": "dashed", "width": {"value": 1, "unit": "px"},
                                "dashLength": {"value": 4, "unit": "px"}, "dashGap": {"value": 3, "unit": "px"},
                                "color": "{color.timeline.entry}", "between": "entries-only",
                                "span": "row", "inMinHeight": True}
    assert entry["preview"]["maxLines"] == 1 and entry["preview"]["emptyKeepsLineHeight"] is True
    assert entry["time"]["fontFeatures"] == ["tnum"] and entry["time"]["source"] == "createdAt"
    assert entry["time"]["wrap"] is False
    assert entry["minHeight"] == {"value": 48, "unit": "px"}
    variants = {variant["id"]: variant for variant in row["variants"]}
    group = variants["day"]["parts"]["group"]
    assert group["pressable"] is False and group["order"] == ["badge", "entries", "tag"]
    for part in ("dateColumn", "badge", "tag"):
        assert variants["entries"]["parts"][part]["visible"] is False
    assert any("server 순서" in rule for rule in row["rules"])


def test_diary_row_single_entry_day_is_unchanged():
    row = component("diary", "diary-row")
    assert row["parts"]["card"]["padding"] == "{space.16}"
    assert row["parts"]["preview"] == {"component": "sentence-block", "variant": "preview", "marginTop": "{space.8}"}
    assert row["a11y"]["label"] == "날짜 요일, 배지, 미리보기 첫 줄, 태그"


# 상한을 채운 날의 쓰는 입구 (2026-10-22-diary-row-multi-design.md §4, 결정 V43)
def test_full_day_entrances():
    card = component("today", "guide-question-card")
    full = card["states"]["full"]
    assert full["parts"]["action"] == {"component": "primary-button", "variant": "quiet", "state": "disabled", "align": "center"}
    assert full["parts"]["seal"] == card["states"]["after"]["parts"]["seal"]
    assert full["parts"]["question"]["fg"] == "{color.text.secondary}"
    assert full["labelKey"] == "todayGuideCtaFull"
    assert "더 쓸 수 없음" in card["a11y"]["stateAnnounced"]
    calendar = next(v for v in component("input", "date-picker")["variants"] if v["id"] == "calendar")
    assert calendar["parts"]["bottomAction"]["whenFull"] == {"state": "disabled", "labelKey": "diaryListPickDateConfirmFull"}


def test_written_day_entrances_open_a_new_diary():
    assert "쓴 일기 보기" not in json.dumps(component("action", "primary-button"), ensure_ascii=False)
    assert "쓴 일기 보기" not in (COMPONENTS_DIR / "today.md").read_text(encoding="utf-8")


# writing #441 키 이름 (2.7.0 spec §7.2, writing PR #436)
def test_d82_writing_keys_are_named():
    connected = component("action", "social-login-button")["states"]["connected"]["parts"]["state"]
    assert connected["slot"] == "ui.login-methods.row" and connected["key"] == "loginMethodsRowConnected"


# 최종 리뷰 반영 (#410): 그날 시트 일기 머리, 변형 덮어쓰기, 묶음 카드 a11y
def test_day_sheet_diary_head_is_not_a_link():
    navigate = next(v for v in component("sentence", "depth-link")["variants"] if v["id"] == "navigate")
    assert "daySheetSlot" not in navigate["parts"]["label"] and "그날 일기" not in navigate["when"]
    entries = next(v for v in component("diary", "diary-row")["variants"] if v["id"] == "entries")
    assert entries["parts"]["head"] == {"screens": ["day-sheet"], "slot": "day-sheet.diary.open", "type": "{type.label.md}",
                                        "fg": "{color.text.secondary}", "marginTop": "{space.16}", "marginBottom": "{space.4}",
                                        "note": "머리는 아래 줄의 이름이라 아래 내용에 붙여야 묶여 보임(결정 V56)"}
    for name in ("calendar.md", "sentence.md"):
        text = (COMPONENTS_DIR / name).read_text(encoding="utf-8")
        assert "이날 일기 보기" not in text and "둘 중 하나만" not in text, name


def test_diary_row_variant_overrides_are_explicit():
    variants = {v["id"]: v for v in component("diary", "diary-row")["variants"]}
    entries = variants["entries"]["parts"]
    for part in ("card", "preview", "rail", "number", "seal", "weekday"):
        assert entries[part]["visible"] is False, part
    assert entries["container"] == {
        "byScreen": {"today": {"bg": "{color.bg.sheet}", "radius": "{radius.lg}", "paddingX": "{space.16}",
                               "paddingY": "{space.4}", "marginTop": "{space.12}"}, "day-sheet": "none"},
        "whenEmpty": "그리지 않음"}
    group = variants["day"]["parts"]["group"]
    assert group["preview"] == {"visible": False} and group["tag"] == {"marginTop": "{space.8}"}
    assert "tagMarginTop" not in group
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "visible: false" in readme and "덮어" in readme


def test_diary_row_group_a11y_replaces_button_role():
    row = component("diary", "diary-row")
    assert "두 편 이상" in row["a11y"]["group"]["when"] and row["a11y"]["group"]["role"] == "group"
    assert row["a11y"]["entry"]["role"] == "button" and "entries" in row["a11y"]["entry"]["when"]
    assert "시각만" in row["a11y"]["entry"]["emptyPreview"]
    assert row["parts"]["entry"]["divider"]["span"] == "row"


def test_manuscript_text_is_not_copied_into_design_docs():
    for name in ("today.md", "elements.md"):
        assert "새 일기 쓰기" not in (COMPONENTS_DIR / name).read_text(encoding="utf-8"), name


# 계정 합치기 두 단계 (#483, D85, 결정 V44)
def _md_section(name, heading):
    text = (COMPONENTS_DIR / name).read_text(encoding="utf-8")
    section = text.split(heading, 1)[1]
    return section.split("\n## ", 1)[0].split("\n### ", 1)[0]


def test_account_choice_chooses_profile_not_account():
    choice = component("input", "account-choice")
    assert "프로필" in choice["summary"] and "V44" in choice["summary"]
    first = next(rule for rule in choice["rules"] if "처음부터 어느 쪽도 골라 두지 않는다" in rule)
    assert "지워져" in first


def test_account_merge_two_steps_layout():
    section = _md_section("input.md", "### account-merge 화면 배치")
    for text in ("인증 단계", "요약·고르기 단계", "`account-merge.auth.body`", "`account-merge.not-other.body`",
                 "`ui.account-merge.summary`", "0이어도", "\"합치지 않기\" 버튼이 없습니다", "뒤로 가기는 동작하지 않습니다"):
        assert text in section, text
    # IA가 PR #511로 슬롯 account-merge.cta.cancel과 출구 "합치지 않기"를 지움(#507)
    assert "account-merge.cta.cancel" not in section


def test_login_methods_merge_entry():
    section = _md_section("action.md", "### login-methods 화면 배치")
    for text in ("`login-methods.merge.cta`", "`quiet`", "`login-methods.in-use.body`", "`notice`", "저절로 넘어가지 않습니다"):
        assert text in section, text
    assert "`account-merge`로 넘어갑니다" not in section


def test_dialog_notice_covers_d85_bodies():
    dialog = component("feedback", "dialog")
    notice = next(v for v in dialog["variants"] if v["id"] == "notice")
    assert "login-methods.in-use.body" in notice["when"] and "account-merge.not-other.body" in notice["when"]


# 구매 내역 (#494, D88 ②, #502, 결정 V45)
def test_purchase_row():
    row = component("action", "purchase-row")
    parts = row["parts"]
    assert parts["product"]["type"] == "{type.subtitle}" and parts["product"]["overflow"] == "wrap"
    assert "스토어" in parts["product"]["fallback"]
    status = parts["status"]
    assert status["active"] == {"element": "tag.status"} and status["align"] == "product-first-line"
    assert status["other"]["type"] == "{type.label.md}" and status["other"]["fg"] == "{color.text.secondary}"
    assert parts["meta"]["type"] == "{type.caption.lg}" and parts["meta"]["fontFeatures"] == ["tnum"]
    assert "기간" in parts["meta"]["periodOnlyWhen"]
    assert parts["row"]["divider"] == {"element": "list.divider", "between": "rows-only"}  # V58
    assert parts["group"]["bg"] == "{color.bg.sheet}" and parts["group"]["radius"] == "{radius.lg}"
    assert "pressed" not in row["states"] and row["states"]["loading"]["component"] == "skeleton"
    assert any("server" in rule and "순서" in rule for rule in row["rules"])
    assert any("합치기" in rule and "표시하지 않는다" in rule for rule in row["rules"])


def test_purchase_history_layout():
    section = _md_section("action.md", "### purchase-history 화면 배치")
    for text in ("`purchase-history.missing.notice`", "늘 보입니다", "`receipt`", "`empty-state`"):
        assert text in section, text


# app 구현에서 어긋난 값 넷 (#475, 결정 V46)
def test_issue_475_values():
    login = component("action", "social-login-button")
    badge = login["states"]["connected"]["parts"]["logo"]["badge"]
    assert badge["kakao"] == {"bg": "#FEE500", "symbol": "#191919", "shape": "{radius.xs}"}
    line = next(v for v in login["variants"] if v["id"] == "line")
    assert line["parts"]["label"]["width"] == {"value": 198, "unit": "px"} and "공식" in line["parts"]["label"]["widthSource"]
    entry = component("diary", "diary-row")["parts"]["entry"]
    assert entry["chevron"]["marginStart"] == "{space.8}"
    assert entry["time"]["format"] == "HH:mm" and entry["time"]["hourCycle"] == "h23"
    variants = {v["id"]: v for v in component("calendar", "event-row")["variants"]}
    for part in (variants["summary"]["parts"]["time"], variants["list"]["parts"]["timeColumn"]):
        assert part["format"] == "HH:mm" and part["hourCycle"] == "h23"
    assert "기기 locale의 짧은 시각" not in (COMPONENTS_DIR / "diary.md").read_text(encoding="utf-8")


# 최종 리뷰 반영 (#480): 구매 줄 슬롯 나눔, 색인, 요약 실패·뒤로 가기·문의 안내 범위
def test_purchase_row_slots_are_split_by_limit():
    parts = component("action", "purchase-row")["parts"]
    assert parts["status"]["slot"] == "ui.purchase.status" and parts["status"]["key"] == "purchaseStatus*"
    assert parts["status"]["maxWidth"] == {"value": 80, "unit": "px"}
    assert parts["meta"]["slot"] == "ui.purchase.meta"


def test_readme_index_lists_3_0_components():
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "check-row, account-choice |" in readme and "offer-card, purchase-row |" in readme
    # 숫자는 지금 사실과 대조 (리뷰 M5: 옛 43개를 고정하지 않음)
    documents = load_documents(COMPONENTS_DIR)
    specified = sum(len(documents[name]["components"]) for name in components.GROUPS)
    total = len(json.loads(IA_PATH.read_text(encoding="utf-8"))["components"])
    pending = len(components.IA_PENDING_COMPONENTS)
    assert f"IA v5 컴포넌트 {total}개 가운데 명세를 쓴 {specified}개" in readme
    assert f"아직 명세가 없는 {pending}개" in readme and f"지금 {specified}개이고, 대기 목록 {pending}개" in readme
    assert "IA 컴포넌트 43개" not in readme


def test_account_merge_failure_and_back_rules():
    section = _md_section("input.md", "### account-merge 화면 배치")
    assert "요약을 받지 못하면" in section and "인증 단계로 돌아갑니다" in section
    assert "스와이프" in section and "`disabled`" in section
    assert "'끝냄'" in section
    assert "값 자리 56" in section


def test_missing_notice_scope():
    section = _md_section("action.md", "### purchase-history 화면 배치")
    assert "`loading`·`error`·`offline`에서는" in section


def test_purchase_row_meta_has_no_separator():
    # W44·#564: 구매일과 사용 기간을 구분 글자로 잇지 않고 두 줄로 나눔 (결정 V47)
    meta = components_by_id(("action",))["purchase-row"]["parts"]["meta"]
    assert "join" not in meta and "purchaseMetaSeparator" not in json.dumps(meta)
    assert meta["layout"] == "lines"
    assert meta["period"]["marginTop"] == "{space.2}"


# 사주 표 십성 라벨·피드백 표시·윤달 사주 줄 (#353·#354·#587, 결정 V48~V51)
def test_luck_and_manse_tables_have_ten_god_labels():
    by_id = components_by_id(BRAND_GROUPS)
    daeun = by_id["daeun-table"]["parts"]
    pillar = daeun["daeun"]
    for part in ("stemTenGod", "branchTenGod", "twelveStage"):
        assert (pillar[part]["component"], pillar[part]["variant"]) == ("term-token", "label")
    assert pillar["order"] == ["age", "stemTenGod", "cells", "branchTenGod", "twelveStage", "startYear"]
    assert daeun["seun"]["stemTenGod"]["source"] == "SeunYear.tenGod"
    assert daeun["label"]["maxLines"] == 2
    hidden = by_id["manse-table"]["parts"]["hiddenStems"]
    assert (hidden["tenGod"]["component"], hidden["tenGod"]["variant"]) == ("term-token", "label")
    assert hidden["stack"]["direction"] == "vertical"


def test_feedback_error_banner_group_note_and_toast_position():
    by_id = components_by_id(("feedback", "action"))
    banner = by_id["notice-banner"]
    error = next(variant for variant in banner["variants"] if variant["id"] == "error")
    assert error["parts"]["icon"]["name"] == "cloud-warning"
    assert "button" not in banner["parts"]
    note = by_id["settings-row"]["parts"]["groupNote"]
    assert note["slots"] == ["profile-edit.recalc.notice"] and note["maxLines"] == 2
    assert by_id["toast"]["parts"]["container"]["position"] == "above-bottom-bar"


def test_account_choice_saju_has_leap_month_place():
    saju = components_by_id(("input",))["account-choice"]["parts"]["saju"]
    assert saju["leapMonth"]["source"] == "MergeProfileSummary.birth.isLeapMonth"
    assert saju["slot"] == "ui.account-merge.saju"


def test_saju_labels_fit_table_cells():
    # #710(결정 V53): 행 머리는 칸 폭 안 두 줄, 꼬리표는 줄에 하나라 이웃 기둥 위로 넓힘
    by_id = components_by_id(("saju",))
    row_header = by_id["manse-table"]["parts"]["rowHeader"]
    assert row_header["slot"] == "ui.saju.header"
    assert row_header["maxLines"] == 2 and "type.caption.sm" in row_header["overflow"]
    assert by_id["saju-pillars"]["parts"]["header"]["slot"] == "ui.saju.header"
    current = by_id["daeun-table"]["parts"]["currentLabel"]
    assert current["element"] == "tag.status" and current["slot"] == "ui.saju.tag"
    assert current["maxWidth"] == "기둥 둘과 그 사이 간격" and current["maxLines"] == 1
    me = by_id["saju-pillars"]["parts"]["dayMaster"]["tag"]
    assert me["slot"] == "ui.saju.tag" and me["maxWidth"] == "기둥 폭"


def test_settings_row_value_gap():
    value = components_by_id(("action",))["settings-row"]["parts"]["value"]
    assert value["marginStart"] == "{space.8}"


def test_evidence_sheet_personal_empty_notice():
    # #710(결정 V54): 표 칸에서 연 근거 시트에 해석이 없으면 빈 구역을 지우지 않고 안내 문장
    sheet = components_by_id(BRAND_GROUPS)["depth-link"]["parts"]["evidenceSheet"]
    empty = sheet["personalEmpty"]
    assert empty["slot"] == "ui.evidence.personal-empty"
    assert empty["type"] == "{type.body.ui}" and empty["fg"] == "{color.text.secondary}"
    assert empty["when"] == sheet["personal"]["when"] + ", 열렸는데 그 자리 해석이 없을 때"


# DS1 spec(2026-11-05-ds1-rules-design.md) §1·§2, 결정 V56·V57
ICON_SIZE_TOKEN = re.compile(r"^\{size\.icon\.(16|20|24|28)\}$")
ADJACENT_TEXT = "adjacent-text"


def icon_parts(node, path=""):
    """아이콘 부품을 (경로, 이름 또는 None, size 값 또는 None)으로 돌려줍니다.

    `"icon": "<이름>"`이면 같은 부품의 `size`(없으면 `iconSize`)를, `"icon": {...}`이면 그 안의 `name`과 `size`를 봅니다.
    """
    if isinstance(node, dict):
        icon = node.get("icon")
        if isinstance(icon, str):
            yield path, icon, node.get("size", node.get("iconSize"))
        elif isinstance(icon, dict) and not path.endswith("elements"):
            yield path, icon.get("name"), icon.get("size")
        elif "iconSize" in node:
            yield path, None, node["iconSize"]
        for key, value in node.items():
            if key.endswith("Icon") and isinstance(value, str):
                yield f"{path}.{key}", value, None
        if isinstance(node.get("icons"), dict):
            for key, name in node["icons"].items():
                yield f"{path}.icons.{key}", name, node.get("size")
        for key, value in node.items():
            yield from icon_parts(value, f"{path}.{key}")
    elif isinstance(node, list):
        for index, item in enumerate(node):
            label = item.get("id", index) if isinstance(item, dict) else index
            yield from icon_parts(item, f"{path}[{label}]")


def test_no_raw_spacing_values():
    import rules_audit
    problems = rules_audit.find_problems(rules_audit.collect_measures(COMPONENTS_DIR))
    assert [problem for problem in problems if "간격에 토큰이 아닌 값" in problem] == []
    assert [problem for problem in problems if "위아래 여백이 다름" in problem] == []


def test_icon_sizes_use_icon_scale():
    wrong = []
    for name, document in load_documents(COMPONENTS_DIR).items():
        for path, _, size in icon_parts(document, name):
            if size is None:
                continue
            if not (size == ADJACENT_TEXT or (isinstance(size, str) and ICON_SIZE_TOKEN.match(size))):
                wrong.append(f"{path}: {size}")
    assert wrong == []
    icon = load_documents(COMPONENTS_DIR)["elements"]["elements"]["icon"]
    steps = icon["adjacentText"]
    assert [step["size"] for step in steps] == ["{size.icon.16}", "{size.icon.20}", "{size.icon.24}", "{size.icon.28}"]
    assert [step["maxFontSize"] for step in steps] == [14, 18, 22, None]  # 리뷰 M1: 규칙으로 계산한 경계
    assert icon["scale"] == ["{size.icon.16}", "{size.icon.20}", "{size.icon.24}", "{size.icon.28}"]
    caution = load_documents(COMPONENTS_DIR)["elements"]["elements"]["mark.caution"]
    assert caution["size"] == ADJACENT_TEXT


def test_no_custom_icons():
    names = {line.strip() for line in (TOOLS_DIR / "phosphor_names.txt").read_text(encoding="utf-8").splitlines()
             if line.strip() and not line.startswith("#")}
    assert len(names) == 1512
    documents = load_documents(COMPONENTS_DIR)
    assert "custom" not in documents["elements"]["elements"]["icon"]
    unknown = [f"{path}: {name}" for document_name, document in documents.items()
               for path, name, _ in icon_parts(document, document_name) if name and name not in names]
    assert unknown == []
    markdown = "\n".join(path.read_text(encoding="utf-8") for path in COMPONENTS_DIR.glob("*.md"))
    assert "격자와 획 규칙" not in markdown


# DS1 spec §3·§4, 결정 V58·V59
NAVIGATING_CHEVRON_VARIANTS = {("settings-row", "navigate"), ("settings-row", "value")}
# list.divider를 쓰지 않는 구분선: 같은 날 일기 점선(V42)과 표 격자선
DIVIDER_EXCEPTIONS = {"diary-row parts.entry.divider", "manse-table parts.grid.divider"}


def all_components():
    for document in load_documents(COMPONENTS_DIR).values():
        yield from document.get("components", [])


def divider_parts(node, path):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "divider" and isinstance(value, dict):
                yield f"{path}.{key}", value
            yield from divider_parts(value, f"{path}.{key}")


def test_chevron_only_on_navigate():
    settings_row = next(c for c in all_components() if c["id"] == "settings-row")
    shown = {("settings-row", variant["id"]) for variant in settings_row["variants"]
             if variant.get("parts", {}).get("chevron", {}).get("visible") is True}
    assert shown == NAVIGATING_CHEVRON_VARIANTS
    select = next(v for v in settings_row["variants"] if v["id"] == "select")
    assert select["parts"]["chevron"] == {"visible": False}
    assert select["parts"]["check"] == {"icon": "check", "weight": "regular", "size": "{size.icon.20}",
                                        "color": "{color.action.primary}", "when": "고른 줄만"}
    leading = settings_row["parts"]["leading"]
    assert leading["icons"] == {
        "settingsNotifyLabel": "bell", "settingsAdFreeLabel": "prohibit", "settingsLanguageLabel": "translate",
        "profileEditBarTitle": "user-circle", "calcBasisBarTitle": "globe-hemisphere-east", "settingsLoginMethodsLabel": "key",
        "legalBarTitle": "file-text", "settingsContactLabel": "chat-circle-text", "settingsLogoutLabel": "sign-out",
        "accountDeleteBarTitle": "trash"}
    assert (leading["weight"], leading["size"], leading["color"], leading["marginEnd"]) == (
        "light", "{size.icon.20}", "{color.text.primary}", "{space.12}")
    assert leading["screens"] == ["settings"]
    destructive = next(v for v in settings_row["variants"] if v["id"] == "destructive")
    assert destructive["parts"]["leading"]["weight"] == "regular"
    assert "mark.caution" not in json.dumps(destructive, ensure_ascii=False)


def test_dividers_use_list_divider():
    element = load_documents(COMPONENTS_DIR)["elements"]["elements"]["list.divider"]
    assert element["width"] == "{border.width.hairline}" and element["color"] == "{color.line}"
    assert element["insetX"] == "{space.16}" and element["underLeading"] is True
    assert element["between"] == "rows-only"
    wrong = []
    for component in all_components():
        for path, divider in divider_parts(component.get("parts", {}), f"{component['id']} parts"):
            if path in DIVIDER_EXCEPTIONS:
                continue
            if divider.get("element") != "list.divider" or "list.divider" not in component.get("uses", []):
                wrong.append(path)
    assert wrong == []


# DS1 2단계 spec §2 Q1: 1단계 요소 section.header(V59)를 컴포넌트로 옮기고 오른쪽 자리를 더함(V69)
def test_section_header_component():
    assert "section.header" not in load_documents(COMPONENTS_DIR)["elements"]["elements"]
    header = component("frame", "section-header")
    parts = header["parts"]
    assert parts["title"] == {"type": "{type.label.lg}", "fontWeight": 600, "fg": "{color.text.primary}", "required": True}
    assert parts["description"] == {"type": "{type.caption.md}", "fg": "{color.text.secondary}",
                                    "marginTop": "{space.2}", "optional": True}
    assert parts["contentGap"] == "{space.12}" and parts["sectionGap"] == "{space.32}"
    assert parts["startLine"] == {"align": "card-outer-edge", "screen": "{space.20}", "sheet": "{space.24}"}
    variants = {variant["id"]: variant["parts"] for variant in header["variants"]}
    assert set(variants) == {"plain", "link", "action"}  # 오른쪽 자리는 꺾쇠 링크와 아이콘 동작 둘만
    assert variants["plain"] == {"trailing": {"visible": False}}
    link = variants["link"]["trailing"]
    assert link["chevron"] == {**CHEVRON, "weight": "light"}  # 옆 글자 type.label.md 500이라 Light(V57)
    assert link["label"] == {"type": "{type.label.md}", "fg": "{color.action.primary}"}
    assert link["target"] == {"presentation": "page", "transition": "page.push"}
    action = variants["action"]["trailing"]
    assert action["options"] == [
        {"component": "reaction-button", "when": "좋아요"},
        {"icon": "plus", "weight": "light", "size": "{size.icon.24}", "color": "{color.text.primary}", "when": "더하기"}]
    assert action["minTarget"] == 44 and "chevron" not in action
    assert header["a11y"]["role"] == "header" and header["states"]["pressed"]["pattern"] == "press.ink"


# DS1 spec §5·§6, 결정 V60·V61·V62
def test_single_press_pattern():
    patterns = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]
    assert [name for name in patterns if name.startswith("press.")] == ["press.ink"]
    ink = patterns["press.ink"]
    assert ink["scope"] == "own-boundary"
    assert ink["ink"]["radius"] == "farthest-corner / 0.7"
    assert ink["ink"]["solidUntil"] == 0.7
    assert ink["release"]["from"] == "grow-to-full"
    for component in all_components():
        pressed = component.get("states", {}).get("pressed")
        if pressed:
            assert pressed["pattern"] == "press.ink", component["id"]


def test_button_pair_rule():
    pair = load_documents(COMPONENTS_DIR)["elements"]["elements"]["button.pair"]
    assert pair["stack"] == {"direction": "vertical", "order": ["filled", "quiet"], "gap": "{space.8}"}
    assert pair["height"] == "same" and pair["width"] == "fill"
    assert pair["component"] == "primary-button"


def test_quiet_height_matches_filled():
    button = next(c for c in all_components() if c["id"] == "primary-button")
    quiet = next(v for v in button["variants"] if v["id"] == "quiet")
    assert "height" not in quiet["parts"]["container"]
    assert button["parts"]["container"]["height"] == {"value": 52, "unit": "px"}


def test_explain_opens_without_shift():
    # 1단계 요소 explain.sheet(V62)를 컴포넌트 explain-sheet로 옮김(V71)
    assert "explain.sheet" not in load_documents(COMPONENTS_DIR)["elements"]["elements"]
    sheet = component("frame", "explain-sheet")["parts"]
    assert sheet["container"] == {"component": "sheet", "variant": "half", "height": "content"}
    assert sheet["layout"] == "overlay"
    assert sheet["title"] == {"type": "{type.subtitle}", "fg": "{color.text.primary}", "source": "누른 항목의 이름",
                              "marginBottom": "{space.8}"}
    assert sheet["body"] == {"component": "sentence-block", "variant": "body"}
    assert sheet["stageStrip"]["component"] == "stage-strip" and sheet["stageStrip"]["marginTop"] == "{space.12}"
    by_id = {c["id"]: c for c in all_components()}
    lucky = by_id["lucky-card"]
    assert "explain.sheet" not in lucky["uses"] and lucky["parts"]["explain"]["component"] == "explain-sheet"
    assert lucky["states"]["open"]["pattern"] == "sheet.enter"
    term = by_id["term-token"]
    assert "explain.sheet" not in term["uses"] and term["parts"]["explainSheet"]["component"] == "explain-sheet"
    text = "\n".join(path.read_text(encoding="utf-8") for path in COMPONENTS_DIR.glob("*.json"))
    assert '"insert"' not in text and "칩 줄 아래 전체 폭으로 열린다" not in text


# DS1 spec §6, 결정 V63
def test_evidence_entry_is_icon():
    link = next(c for c in all_components() if c["id"] == "depth-link")
    icon = link["parts"]["icon"]
    assert {key: icon[key] for key in ("icon", "weight", "size", "color", "minTarget", "layoutWidth")} == {
        "icon": "book-open-text", "weight": "regular", "size": "{size.icon.20}", "color": "{color.action.primary}",
        "minTarget": 48, "layoutWidth": "{size.icon.20}"}  # 줄 배치 폭은 그림 20, 터치 48은 밖으로 (리뷰 I4)
    assert "label" not in link["parts"] and "chevron" not in link["parts"]
    variants = {variant["id"]: variant for variant in link["variants"]}
    for evidence in ("inline-end", "block"):
        assert "label" not in variants[evidence].get("parts", {}), evidence
    assert variants["inline-end"]["parts"]["icon"]["joinBefore"] == "U+00A0"
    navigate = variants["navigate"]["parts"]
    assert navigate["icon"] == {"visible": False}
    assert navigate["label"]["slot"] == "birthplace.standard.link" and navigate["chevron"]["icon"] == "caret-right"
    assert link["a11y"]["labelSlot"] == "ui.depth.evidence_link" and link["a11y"]["minTarget"] == 48


def test_no_inline_nowrap_link():
    texts = [path.read_text(encoding="utf-8") for path in COMPONENTS_DIR.glob("*.json")]
    texts += [path.read_text(encoding="utf-8") for path in COMPONENTS_DIR.glob("*.md") if path.name != "README.md"]  # 판 기록은 지운 이름을 적음
    assert not [text for text in texts if "link.inline-nowrap" in text]


# DS1 spec §7, 결정 V64~V68
# 서버에서 받은 내용을 그리는 컴포넌트: 각자 skeleton 모양을 가짐 (V66)
CONTENT_COMPONENTS = {
    "day-character", "lucky-card", "sentence-block", "guide-question-card", "event-row", "calendar-month",
    "diary-row", "diary-editor", "tag-chip", "saju-pillars", "manse-table", "daeun-table", "ohaeng-bar",
    "offer-card", "purchase-row", "account-choice", "city-search",
    "hanja-tag",  # 태그 이름을 받아 그림 (DS1 2단계)
    "diary-summary", "luck-pillar",  # 기록 집계, 대운과 세운 (DS1 2단계 묶음 B)
}


def test_dialog_padding_symmetric():
    dialog = next(c for c in all_components() if c["id"] == "dialog")
    parts = dialog["parts"]
    assert parts["container"]["padding"] == "{space.24}" and parts["container"]["marginX"] == "{space.24}"
    actions = {key: value for key, value in parts["actions"].items() if key != "note"}
    assert actions == {"layout": "equal-width", "count": 2, "gap": "{space.8}", "marginTop": "{space.24}",
                       "height": {"value": 44, "unit": "px"}, "buttonPaddingX": "{space.12}",
                       "overflow": "stack-vertical-confirm-top"}
    assert parts["cancel"]["bg"] == "{color.fill.soft}" and parts["cancel"]["fg"] == "{color.text.primary}"  # V74
    assert parts["confirm"]["component"] == "primary-button" and parts["confirm"]["variant"] == "filled"
    destructive = next(v for v in dialog["variants"] if v["id"] == "destructive")
    assert destructive["parts"]["confirm"] == {"variant": "destructive", "label": {"leading": None}}  # primary-button과 같은 자리


def test_dialog_icon_size():
    dialog = next(c for c in all_components() if c["id"] == "dialog")
    destructive = next(v for v in dialog["variants"] if v["id"] == "destructive")
    title = destructive["parts"]["title"]
    assert title["leading"] == "mark.caution" and title["leadingSize"] == "{size.icon.20}"
    assert title["leadingGap"] == "{space.8}"


def test_sheet_handle_area():
    sheet = next(c for c in all_components() if c["id"] == "sheet")
    parts = sheet["parts"]
    assert parts["container"]["paddingX"] == "{space.24}" and parts["container"]["paddingBottom"] == "{space.24}"
    assert parts["handleArea"] == {"height": {"value": 24, "unit": "px"}, "minTarget": 44, "drag": True}
    assert parts["handle"] == {"width": {"value": 36, "unit": "px"}, "height": {"value": 4, "unit": "px"},
                               "radius": "{radius.full}", "color": "{color.line}", "align": "center"}
    assert parts["title"]["marginTop"] == "{space.8}"
    assert parts["dragDismiss"] == {"threshold": 0.25, "fling": True, "otherwise": "제자리로 돌아옴",
                                    "withInput": "닫기 전에 쓴 내용을 잃지 않게 확인"}


# IA loading 화면에 나오지만 불러올 내용이 없는 컴포넌트(틀, 입력, 버튼, 안내, 다른 컴포넌트 안 부품)
NO_LOADING_CONTENT = {
    "app-bar", "tab-bar", "sheet", "dialog", "toast", "notice-banner", "empty-state", "skeleton", "ad-banner",
    "primary-button", "social-login-button", "share-button", "segmented", "text-field", "date-picker", "time-picker",
    "input-step", "depth-link", "reaction-button", "draft-indicator",
    "term-token",  # sentence-block 뼈 안
    "day-cell",  # calendar-month 뼈 안
    "section-header",  # 제목은 UI 슬롯이라 불러오는 중에도 그대로 (DS1 2단계)
    "explain-sheet",  # 틀. 본문은 sentence-block 뼈
}


# 대기 목록을 떠난 컴포넌트는 CONTENT_COMPONENTS나 NO_LOADING_CONTENT로 분류해야 합니다(loading 화면에 나온다면).
def test_loading_components_are_classified():
    # 리뷰 M5: IA loading 화면의 컴포넌트는 내용 컴포넌트(skeleton 뼈 필수)이거나 NO_LOADING_CONTENT
    loading_screens = [screen for screen in ia_screens().values()
                       if any(state["id"] == "loading" for state in screen.get("states", []))]
    on_loading = {component for screen in loading_screens for component in screen.get("components", [])}
    # 명세 대기 컴포넌트는 명세를 쓰는 task가 분류합니다(IA_PENDING_COMPONENTS에서 뺄 때)
    assert on_loading - NO_LOADING_CONTENT - components.IA_PENDING_COMPONENTS <= CONTENT_COMPONENTS
    assert not CONTENT_COMPONENTS & NO_LOADING_CONTENT


def test_skeleton_shapes():
    skeleton = next(c for c in all_components() if c["id"] == "skeleton")
    parts = skeleton["parts"]
    assert parts["textLine"]["radius"] == "{radius.xs}" and parts["card"]["radius"] == "{radius.lg}"
    assert parts["chip"]["radius"] == "{radius.full}"
    assert parts["screen"] == {"composition": "그 화면 컴포넌트들의 loading 모양을 화면 배치대로", "gutter": "{space.20}"}
    assert any("글줄만 쌓은" in rule for rule in skeleton["rules"])
    by_id = {c["id"]: c for c in all_components()}
    missing = [name for name in sorted(CONTENT_COMPONENTS) if "skeleton" not in by_id[name].get("states", {}).get("loading", {})]
    assert missing == []


def test_page_push_pattern():
    push = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]["page.push"]
    assert push["duration"] == "{motion.duration.page}" and push["easing"] == "{motion.easing.page}"
    assert push["enter"] == {"translateX": ["{motion.offset.page}", 0], "opacity": [0, 1]}
    assert push["below"] == "still" and push["back"] == "reverse"
    assert push["reduceMotion"] == "opacity-only"
    navigate = next(v for v in next(c for c in all_components() if c["id"] == "depth-link")["variants"] if v["id"] == "navigate")
    assert navigate["parts"]["target"]["transition"] == "page.push"


def test_keyboard_dismiss_affordance():
    field = next(c for c in all_components() if c["id"] == "text-field")
    dismiss = field["states"]["focused"]["parts"]["keyboardDismiss"]
    assert dismiss["size"] == {"value": 44, "unit": "px"} and dismiss["radius"] == "{radius.full}"
    assert dismiss["icon"] == {"icon": "caret-down", "weight": "regular", "size": "{size.icon.20}", "color": "{color.text.primary}"}
    assert dismiss["position"] == "키보드 바로 위 오른쪽" and dismiss["inset"] == "{space.12}"
    assert dismiss["a11y"]["labelSlot"] == "ui.keyboard.dismiss"



# DS1 최종 리뷰 I3·M1: 아이콘 단계표와 글자 배율
def test_icon_text_scale_rule():
    icon = load_documents(COMPONENTS_DIR)["elements"]["elements"]["icon"]
    assert [step["maxFontSize"] for step in icon["adjacentText"]] == [14, 18, 22, None]
    assert icon["textScale"] == {
        "adjacent-text": "단계는 기본 글자 크기로 고르고, 그리는 크기에 기기 글자 배율을 곱함(그 칸의 textScaleMax까지)",
        "standalone": "기기 글자 배율을 따르지 않음(탭 바, 위 막대, 목록 줄 앞, 빈 화면, 키보드 내리기)",
    }
    # 규칙 문장(그림 0.81 ≥ 한글 0.882)으로 계산한 경계와 같음
    for step in icon["adjacentText"][:-1]:
        size = int(step["size"].strip("{}").split(".")[-1])
        assert step["maxFontSize"] == int(size * 0.81 / 0.882)


# 리뷰 I5: 근거 아이콘의 스크린리더 이름은 무엇의 근거인지 말함
def test_evidence_entry_names_its_subject():
    a11y = next(c for c in all_components() if c["id"] == "depth-link")["a11y"]
    assert a11y["role"] == "button" and a11y["announce"] == "근거 시트가 열림"
    assert a11y["labelSlot"] == "ui.depth.evidence_link" and "[subject]" in a11y["labelTemplate"]
    assert set(a11y["subject"]) == {"inline-end", "block"}


# 리뷰 I6: space.20은 쓰임표가 허용한 자리만
SPACE_20_ALLOWED = {
    ("primary-button", "parts.container", "paddingX"), ("input-step", "parts.bottomAction", "paddingX"),
    ("skeleton", "parts.screen", "gutter"), ("guide-question-card", "parts.container", "padding"),
    ("offer-card", "parts.container", "padding"),
    ("section-header", "parts.startLine", "screen"),  # 화면 좌우 여백과 같은 시작선 (V69)
}


def test_space_20_only_where_usage_table_allows():
    import rules_audit
    used = {(m.component, m.path, m.key) for m in rules_audit.collect_measures(COMPONENTS_DIR) if m.value == "space.20"}
    assert used == SPACE_20_ALLOWED


# 리뷰 M3·M4
def test_explain_sheet_overrides_are_noted():
    by_id = {c["id"]: c for c in all_components()}
    title = by_id["term-token"]["parts"]["explainSheet"]["title"]
    assert title["type"] == "{type.title}" and "explain-sheet" in title["note"]
    lucky = by_id["lucky-card"]["a11y"]
    assert "expandedAnnounced" not in lucky and lucky["opensSheet"] is True


# DS1 2단계 spec §4, D108 ②, Q4·Q4-2 (결정 V70)
HANJA_GLYPHS = {
    "dayKind": {"貴", "用", "忌", "平"},
    "tenGodGroup": {"比", "食", "財", "官", "印"},
    "relation": {"合", "沖"},
    "sinsal": {"天", "桃", "驛", "華", "空"},
}


GANJI_ELEMENTS = {
    "stems": {"甲": "wood", "乙": "wood", "丙": "fire", "丁": "fire", "戊": "earth", "己": "earth",
              "庚": "metal", "辛": "metal", "壬": "water", "癸": "water"},
    "branches": {"寅": "wood", "卯": "wood", "巳": "fire", "午": "fire", "辰": "earth", "戌": "earth",
                 "丑": "earth", "未": "earth", "申": "metal", "酉": "metal", "亥": "water", "子": "water"},
}


def test_hanja_tag_component():
    tag = component("sentence", "hanja-tag")
    parts = tag["parts"]
    assert parts["pill"] == {"height": {"value": 30, "unit": "px"}, "radius": "{radius.full}",
                             "paddingStart": "{space.4}", "paddingEnd": "{space.12}", "gap": "{space.4}"}
    glyph = parts["glyph"]
    assert {key: glyph[key] for key in ("size", "shape", "bg", "fontFamily", "fontSize", "fontWeight")} == {
        "size": {"value": 22, "unit": "px"}, "shape": "circle", "bg": "{color.bg.sheet}",
        "fontFamily": "{font.family.hanja}", "fontSize": {"value": 12, "unit": "px"}, "fontWeight": 700}
    assert parts["name"]["type"] == "{type.label.md}"
    glyphs = parts["glyphs"]
    assert {group: set(names) for group, names in glyphs.items()} == HANJA_GLYPHS
    assert sum(len(names) for names in glyphs.values()) == 16 and "刑" not in json.dumps(glyphs, ensure_ascii=False)
    # 톤: 날의 성격만 길흉 톤, 그 밖의 용어는 term. 길흉 톤은 더함과 뺌을 보이는 자리에서만(Q4 ③ + ①)
    tone = parts["tone"]
    good = {"bg": "{color.tag.good.bg}", "fg": "{color.tag.good.fg}"}
    bad = {"bg": "{color.tag.bad.bg}", "fg": "{color.tag.bad.fg}"}
    neutral = {"bg": "transparent", "border": {"color": "{color.tag.neutral.border}", "width": {"value": 1, "unit": "px"}},
               "fg": "{color.tag.neutral.fg}"}
    assert tone["dayKind"] == {"GWIIN_DAY": good, "YONGSIN_DAY": good, "GISIN_DAY": bad, "ORDINARY_DAY": neutral}
    assert tone["otherTerms"] == {"bg": "{color.term.bg}", "fg": "{color.term.fg}"}
    assert tone["verdictTone"] == {"good": good, "bad": bad}
    assert tone["toneAllowedIn"] == ["fortune-verdict", "score-row"]
    variants = {variant["id"]: variant for variant in tag["variants"]}
    assert set(variants) == {"default", "emphasis", "selected", "ganji"}
    emphasis = variants["emphasis"]["parts"]["tone"]["dayKind"]  # Q4-2 ①: V8 배지 매핑 그대로
    assert emphasis == {
        "YONGSIN_DAY": {"bg": "{color.badge.good.bg}", "fg": "{color.badge.good.fg}"},
        "GWIIN_DAY": {"bg": "{color.badge.gwiin.bg}", "fg": "{color.badge.gwiin.fg}"},
        "GISIN_DAY": {"bg": "{color.badge.gisin.bg}", "fg": "{color.badge.gisin.fg}"},
        "ORDINARY_DAY": {"bg": "transparent", "border": {"color": "{color.badge.ordinary.border}",
                                                         "width": {"value": 1, "unit": "px"}}, "fg": "{color.badge.ordinary.fg}"}}
    selected = variants["selected"]["parts"]["pill"]
    assert selected["border"] == {"color": "{color.action.primary}", "width": {"value": 1.5, "unit": "px"},
                                  "placement": "inside"}
    assert "톤 테두리" in selected["note"]
    # 간지 글자는 사주 용어 16자 규칙 밖의 변형: 알약과 이름은 그 오행 색, 원은 흰 바탕에 오행 글자색 (리뷰 라운드 2)
    ganji = variants["ganji"]["parts"]
    assert ganji["glyph"] == {"bg": "{color.bg.sheet}", "fg": "same-as-name", "decorative": True}
    assert ganji["tone"]["byElement"] == {
        element: {"bg": f"{{color.ohaeng.{element}.bg}}", "fg": f"{{color.ohaeng.{element}.fg}}"}
        for element in ("wood", "fire", "earth", "metal", "water")}
    assert ganji["ganjiGlyphs"] == GANJI_ELEMENTS and len(GANJI_ELEMENTS["stems"]) + len(GANJI_ELEMENTS["branches"]) == 22
    assert "stemGlyph" not in parts and "ganjiGlyph" not in ganji and "stem.chip" not in tag["uses"]
    assert any("16자" in rule and "사주 용어" in rule and "ganji" in rule for rule in tag["rules"])
    assert set(tag["parts"]["opens"]["targets"]) == {"explain-sheet", "tag-sheet"}
    assert tag["a11y"]["role"] == "button" and tag["a11y"]["label"] == "이름 글자(한자는 읽지 않음)"
    assert tag["a11y"]["minTarget"] == 44
    assert tag["states"]["pressed"]["pattern"] == "press.ink"


def test_stem_chip_element():
    chip = load_documents(COMPONENTS_DIR)["elements"]["elements"]["stem.chip"]
    assert chip["size"] == {"value": 22, "unit": "px"} and chip["colors"] == "ohaeng.cell"
    assert chip["where"] == ["band-table 지장간 칸"]  # 리뷰 라운드 2: hanja-tag ganji는 이 칩을 쓰지 않음
    assert chip["hanja"] == {"fontFamily": "{font.family.hanja}", "fontSize": {"value": 13, "unit": "px"}, "fontWeight": 700}


# 잠김을 뜻하는 경로(states.locked, 요소 lock.veil, lockPanel). block 같은 낱말에는 걸리지 않음
LOCK_PATH = re.compile(r"locked|lock\.|lockPanel")
# 밑줄 모양이지만 누르는 표시가 아닌 것: 달력 선택 날짜의 펼침 밑줄(요소와 패턴)
UNDERLINE_NOT_LINKS = ("mark.underline-grow",)


# 자세히 보기 표시는 넷뿐: 용어 칩(뜻 시트), 근거 아이콘(근거 시트), 꺾쇠(화면 이동), 자물쇠 + 열기(잠긴 것 열기)
def test_detail_affordances_are_four():
    documents = load_documents(COMPONENTS_DIR)
    icons = [(f"{name}{path}", icon) for name, document in documents.items()
             for path, icon, _ in icon_parts(document, "") if icon]
    assert not [place for place, icon in icons if icon.startswith("info")]  # ⓘ 없음(Q2 ②)
    text = "\n".join(path.read_text(encoding="utf-8") for path in COMPONENTS_DIR.glob("*.json"))
    assert '"textDecoration"' not in text  # 밑줄 링크 없음
    underlines = [place for name, document in documents.items()
                  for place, key, value in components._walk(document, name)
                  if ((isinstance(key, str) and key.lower().startswith("underline"))
                      or (isinstance(value, str) and value.startswith("underline")))
                  and not any(allowed in place for allowed in UNDERLINE_NOT_LINKS)]
    assert underlines == []
    # "더 보기" 글자 버튼 없음: 누를 수 있는 more 부품(target·pattern·component)이나 label 글자 값의 더 보기/more.
    # event-row의 more는 '외 N개' 개수 글자라 누를 수 없음
    pressable = ("target", "pattern", "component", "minTarget")
    more = [place for name, document in documents.items() for place, key, value in components._walk(document, name)
            if (isinstance(key, str) and key.lower().startswith(("more", "showmore", "seemore"))
                and isinstance(value, dict) and any(field in value for field in pressable))
            or (key in ("label", "text") and isinstance(value, str) and re.search(r"더 보기|\bmore\b", value, re.I))]
    assert more == []
    # 꺾쇠는 잠긴 것을 여는 자리(경로에 lock)에 없고(잠금 안내 pass는 화면 이동이라 제외), 자물쇠는 잠긴 것에만
    assert not [place for place, icon in icons
                if icon == "caret-right" and LOCK_PATH.search(place) and ".pass" not in place]
    assert all(LOCK_PATH.search(place) for place, icon in icons if icon == "lock-simple")
    assert component("sentence", "depth-link")["parts"]["icon"]["icon"] == "book-open-text"
    assert component("sentence", "term-token")["parts"]["chip"]["bg"] == "{color.term.bg}"
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    rule = next(line for line in readme.splitlines() if line.startswith("* **자세히 보기 표시"))
    for word in ("용어 칩", "근거 아이콘", "꺾쇠", "자물쇠", "`info`", "밑줄"):
        assert word in rule, word


LOCK_OPEN = {"icon": "lock-simple", "weight": "regular", "size": "adjacent-text", "color": "link-color",
             "gap": "{space.4}", "placement": "before-label", "decorative": True}  # Q3 ③ (결정 V73)


def test_locked_entries_use_lock():
    block_open = component("sentence", "sentence-block")["states"]["locked"]["parts"]["open"]
    assert block_open["lock"] == {"element": "lock.veil", "part": "open"} and "chevron" not in block_open  # 원본은 요소
    assert block_open["label"] == {"type": "{type.label.lg}", "fg": "{color.action.primary}"}
    locked = component("sentence", "depth-link")["states"]["locked"]["parts"]["evidenceSheet"]
    head = locked["lockPanel"]["head"]
    assert head["icon"] == "lock-simple" and head["iconWeight"] == "regular" and "chevron" not in head
    assert locked["personal"]["element"] == "lock.veil"  # 원국 개인 해석
    veil = load_documents(COMPONENTS_DIR)["elements"]["elements"]["lock.veil"]
    assert veil["title"]["icon"] == "lock-simple" and veil["open"] == LOCK_OPEN
    # 화면 이동(광고 제거 화면)은 꺾쇠 그대로, 광고 보고 열기는 버튼 그대로
    assert locked["lockPanel"]["pass"]["chevron"] == CHEVRON
    assert locked["lockPanel"]["cta"]["component"] == "primary-button"
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert any(line.startswith("* **잠김 표시") and "lock-simple" in line for line in readme.splitlines())


def _values(node):
    if isinstance(node, dict):
        for value in node.values():
            yield from _values(value)
    elif isinstance(node, list):
        for value in node:
            yield from _values(value)
    else:
        yield node


# spec §2 1단계 버그: chip.bg(반투명 흰색)는 흰 표면(bg.sheet) 위에서 보이지 않음 (결정 V74)
def test_no_translucent_chip_on_sheet():
    documents = load_documents(COMPONENTS_DIR)
    # 값 하나인 참조와 문자열 안에 끼워 쓴 참조를 모두 잡음 (리뷰 M4)
    users = [name for name, document in documents.items() for value in _values(document)
             if isinstance(value, str) and "{color.chip.bg}" in components.EMBEDDED_REFERENCE.findall(value)]
    assert users == []
    dialog = component("feedback", "dialog")
    assert dialog["parts"]["container"]["bg"] == "{color.bg.sheet}"
    assert dialog["parts"]["cancel"]["bg"] == "{color.fill.soft}"


# Q5 ① (결정 V75)
def test_lucky_chip_outline():
    lucky = component("today", "lucky-card")
    chip = lucky["parts"]["chip"]
    assert chip["bg"] == "{color.bg.sheet}"
    assert chip["border"] == {"color": "{color.line}", "width": {"value": 1, "unit": "px"}, "placement": "inside"}
    assert chip["height"] == {"value": 34, "unit": "px"} and chip["radius"] == "{radius.full}"
    opened = lucky["states"]["open"]["parts"]["chip"]
    assert opened == {"border": {"color": "{color.action.primary}", "width": {"value": 1.5, "unit": "px"}, "placement": "inside"}}
    assert "innerBorder" not in json.dumps(lucky)


# DS1 2단계 spec §4 diary-summary (결정 V76)
DAY_KIND_ORDER = ["YONGSIN_DAY", "GWIIN_DAY", "ORDINARY_DAY", "GISIN_DAY"]


def test_diary_summary():
    summary = component("diary", "diary-summary")
    parts = summary["parts"]
    assert parts["container"] == {"bg": "{color.bg.sheet}", "radius": "{radius.lg}", "padding": "{space.16}"}
    count = parts["count"]
    assert (count["fontSize"], count["fontWeight"], count["fontFeatures"]) == ({"value": 28, "unit": "px"}, 700, ["tnum"])
    assert parts["countUnit"]["marginStart"] == "{space.4}" and parts["countUnit"]["baseline"] == "count"
    kinds = parts["dayKinds"]
    assert kinds["order"] == DAY_KIND_ORDER
    assert kinds["bar"]["height"] == {"value": 8, "unit": "px"} and kinds["bar"]["radius"] == "{radius.full}"
    assert kinds["bar"]["track"] == "{color.bg.base}"
    # 날의 성격 톤: V8 배지 매핑의 진한 쪽 색(옅은 바탕은 트랙 위에서 보이지 않음)
    assert kinds["fill"] == {"YONGSIN_DAY": "{color.badge.good.bg}", "GWIIN_DAY": "{color.badge.gwiin.fg}",
                             "ORDINARY_DAY": "{color.badge.ordinary.border}", "GISIN_DAY": "{color.badge.gisin.fg}"}
    assert kinds["count"]["align"] == "end" and kinds["count"]["fontFeatures"] == ["tnum"]
    tags = parts["tags"]
    assert tags["tag"] == {"component": "hanja-tag", "variant": "default", "max": 3, "order": "수 많은 순"}
    assert tags["count"]["position"] == "알약 안 이름 뒤" and tags["count"]["marginStart"] == "{space.4}"
    notice = parts["notice"]
    assert notice["slot"] == "my-saju.record.few" and notice["visible"] is False
    few = summary["states"]["few"]
    assert few["threshold"] == 5 and few["when"] == "쓴 편수 5편 미만"
    assert few["parts"] == {"dayKinds": {"visible": False}, "notice": {"visible": True}}
    bones = [bone["bone"] for bone in summary["states"]["loading"]["skeleton"]]
    assert bones == ["count", "dayKinds", "tags"]
    assert summary["a11y"]["role"] == "group" and summary["a11y"]["barsDecorative"] is True
    assert "my-saju.record.title" not in str(summary)  # 섹션 제목은 section-header 몫


# DS1 2단계 spec §4 luck-pillar (결정 V77)
def test_luck_pillar():
    pillar = component("saju", "luck-pillar")
    parts = pillar["parts"]
    assert parts["order"] == ["topLabel", "stemTenGod", "stem", "branch", "branchTenGod", "currentTag"]
    assert parts["stem"]["element"] == "ohaeng.cell" and parts["stem"]["size"] == "small"
    assert parts["branch"]["size"] == "small"
    cell = load_documents(COMPONENTS_DIR)["elements"]["elements"]["ohaeng.cell"]["sizes"]["small"]
    assert cell["width"] == {"value": 40, "unit": "px"} and cell["height"] == {"value": 40, "unit": "px"}
    for chip in ("stemTenGod", "branchTenGod"):
        assert (parts[chip]["component"], parts[chip]["variant"]) == ("term-token", "label")
    assert parts["currentTag"]["element"] == "tag.status" and parts["currentTag"]["slot"] == "ui.saju.tag"
    assert parts["currentTag"]["visible"] is False
    states = pillar["states"]
    for state, word in (("current", "지금"), ("thisYear", "올해")):
        emphasis = states[state]["parts"]
        assert emphasis["container"] == {"element": "highlight.current", "bg": "{color.status.bg}"}
        assert emphasis["topLabel"] == {"fg": "{color.action.primary}", "fontWeight": 700}
        assert emphasis["currentTag"] == {"visible": True, "label": word}
    assert "skeleton" in states["loading"]
    variants = {variant["id"]: variant for variant in pillar["variants"]}
    assert set(variants) == {"column", "compact"}
    compact = variants["compact"]["parts"]
    assert compact["layout"] == {"direction": "horizontal", "rows": ["daeun", "seun"], "rowGap": "{space.16}"}
    assert compact["cells"] == {"direction": "vertical", "gap": "{space.4}"}
    assert compact["head"]["tag"] == {"element": "tag.status", "slot": "ui.saju.tag"}
    assert compact["head"]["kind"]["component"] == "term-token"
    assert compact["tenGods"]["component"] == "term-token" and compact["tenGods"]["variant"] == "label"
    for hidden in ("topLabel", "stemTenGod", "branchTenGod", "currentTag"):
        assert compact[hidden] == {"visible": False}, hidden
    assert compact["highlight"] == "none"  # 두 줄 모두 지금이라 바탕 강조로 가를 것이 없음
    assert pillar["a11y"]["textScaleMax"] == 1.3
    assert any("낙관 윤곽" in rule for rule in pillar["rules"])

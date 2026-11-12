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
        "page.push",  # DS1 V67
        "tab.switch",  # V104(#900)
        "unlock.glint"}  # V112(#950)
    assert set(docs["elements"]["elements"]) == {
        "seal", "ohaeng.cell", "ohaeng.swatch", "tone", "tag.status", "tag.me", "highlight.current",
        "mark.underline-grow", "mark.caution", "surface.paper", "rail.timeline", "term",  # link.inline-nowrap은 V63으로 지움
        "skeleton.bone", "icon", "lock.veil",
        "list.divider", "button.pair",  # DS1 V58·V60. section.header·explain.sheet는 컴포넌트로 옮김(V69·V71)
        "stem.chip",  # DS1 2단계 V72
        "keyboard.dismiss",  # 5.0.0: text-field와 diary-editor에 겹친 값을 뺌(V68, V83)
        "unlock.mark"}  # V112(#950) 동작 줄이기 때 열린 구역 표시


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
    assert ids["frame"] == {"tab-bar", "app-bar", "sheet", "ad-banner", "section-header", "explain-sheet", "scroll-hint"}
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
    assert variant_ids(c["app-bar"]) == {"tab-root", "inner", "edit"}  # edit: 일기 쓰기 (V82)
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
        "today": {"day-character", "lucky-card", "guide-question-card", "share-image", "date-header", "tag-sentence-list"},
        "calendar": {"calendar-month", "day-cell", "event-row", "fortune-verdict", "score-row"},
        "diary": {"diary-row", "diary-editor", "date-block", "draft-indicator", "diary-summary"},  # tag-chip은 6.0.0에서 지움(V96)
        "saju": {"saju-pillars", "ohaeng-bar", "manse-table", "daeun-table", "luck-pillar", "birth-info-row", "band-table",
                 "stage-strip"},
    }


def test_brand_spec_values():
    c = components_by_id(BRAND_GROUPS)
    assert variant_ids(c["share-image"]) == {"story", "feed", "square"}
    assert variant_ids(c["term-token"]) >= {"inline", "label"}
    assert variant_ids(c["event-row"]) == {"summary", "list"}
    assert variant_ids(c["lucky-card"]) == {"color", "direction", "number", "time"}  # tag는 5.0.0에서 지움(V78)
    assert variant_ids(c["depth-link"]) == {"inline-end", "block", "navigate"}
    assert set(c["guide-question-card"]["states"]) >= {"before", "after"}
    assert set(c["draft-indicator"]["states"]) == {"local", "saving", "saved"}
    day = json.dumps(c["day-cell"])
    assert "{color.seal.soft}" in day and "outline" in day and "mark.underline-grow" in day
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


def test_contract_version_is_7_1_0():
    # 7.1.0은 #1020 drift(D123, V118): 행운 색, 시간 시트 근거 진입점과 시간 시트 제목 슬롯 추가라 부 버전.
    # 7.0.0은 #982, #1003(V114~V117), 6.3.0은 V110~V113, 6.2.0은 검수 회차2 묶음(V100~V109), 6.1.1은 #908(V99), 6.1.0은 #892(V98), 6.0.0은 #859 drift(V96)
    assert VERSION == "7.1.0"
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
    assert components.IA_PENDING_COMPONENTS == ia_ids - specified - components.IA_REMOVAL_REQUESTED  # 명세가 생기면 목록에서 빼야 통과
    # score-scale(관문 답 2026-11-07 Q4)과 tag-chip(V81)은 IA에서 빠져(D113) 제거 요청 목록이 빔
    assert components.IA_REMOVAL_REQUESTED == frozenset() and not {"score-scale", "tag-chip"} & (ia_ids | specified)
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
    assert block["a11y"]["lockedOpenFocus"] == "열기는 따로 초점(link)"
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
    assert a11y["unlockingLabel"] == "확인 중"
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
    # 7.0.0(D122, V115): 구간 반복(repeat) 대신 낮 하나, 밤 하나
    assert "repeat" not in time and [period["id"] for period in time["periods"]] == ["day", "night"]


def test_lucky_card_has_no_banned_punctuation():
    # 화면에 보이는 형식에 범위 대시와 가운뎃점을 쓰지 않음 (D93)
    time = next(v for v in component("today", "lucky-card")["variants"] if v["id"] == "time")
    text = json.dumps(time, ensure_ascii=False)
    assert "–" not in text and "·" not in text and "—" not in text
    rules = " ".join(component("today", "lucky-card")["rules"])
    assert "최대 5개" in rules and "낮 칩 하나만" in rules  # today 칩 줄은 행운 4종(시간 낮, 밤), 공유는 낮 칩 (V78, V116)


def test_element_values_from_app_feedback():
    elements = load_documents(COMPONENTS_DIR)["elements"]["elements"]
    assert elements["icon"]["set"]["flutter"] == "phosphor_glyphs"
    assert elements["icon"]["set"]["flutterVersion"] == "2.1.2+1"
    assert elements["mark.caution"]["size"] == "adjacent-text"  # V57
    # G1(결정 V80)이 server 길이 힌트를 구역별 고정 줄 수로 바꿈. 사주 표 용신 근거는 두 줄(2026-11-07, V92, origin)
    assert elements["lock.veil"]["lines"]["sentence-block locked"] == 2


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


# 오늘 화면 대표 태그 칩 #239(D76, 2.5.0)는 IA v5(V78)부터 hanja-tag로 옮겨 5.0.0에서 변형을 지움
def test_lucky_card_has_no_tag_variant():
    card = component("today", "lucky-card")
    assert "tag" not in {variant["id"] for variant in card["variants"]}
    assert "color.tag" not in json.dumps(card)
    rules = " ".join(card["rules"])
    assert "맨 앞" not in rules and "today.lucky-tag.body" not in rules and "polarity" not in rules
    md = _md_section("today.md", "## lucky-card")
    assert "`today.lucky-tag.body`" not in md and "`daily.tag_label`" not in md


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
    assert listed["parts"]["add"]["slot"] == "day-sheet.event.add" and "add" not in listed["parts"]["failed"]  # 추가는 섹션 머리 + (V85)
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
    assert sheet["source"]["repeat"] == {"each": "item", "gap": "{space.16}", "skipEmpty": True}  # V113 상자 없이 원전 묶음
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
    assert group["pressable"] is False and group["order"] == ["dayKind", "entries", "tag"]  # 날의 성격 위, 대표 태그 아래 (V81 개정)
    for part in ("dateColumn", "dayKind", "tag"):
        assert variants["entries"]["parts"][part]["visible"] is False
    assert any("server 순서" in rule for rule in row["rules"])


def test_diary_row_single_entry_day_is_unchanged():
    row = component("diary", "diary-row")
    assert row["parts"]["card"]["padding"] == "{space.16}"
    preview = row["parts"]["preview"]
    assert (preview["component"], preview["variant"], preview["marginTop"]) == ("sentence-block", "preview", "{space.8}")
    assert row["a11y"]["label"] == "날짜 요일, 날의 성격, 미리보기 첫 줄, 대표 태그"  # V81 개정


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
    # V85: 그날 시트의 일기 머리는 section-header(day-sheet.diary.open)로 옮김
    assert entries["parts"]["head"]["visible"] is False and "day-sheet.diary.open" in entries["parts"]["head"]["note"]
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
    removal = len(components.IA_REMOVAL_REQUESTED)
    assert not components.IA_PENDING_COMPONENTS  # DS1 2단계 묶음 E로 대기 목록이 빔
    assert f"IA v5 컴포넌트 {total}개 가운데 명세를 쓴 {specified}개" in readme and specified + removal == total
    assert "대기 목록 `IA_PENDING_COMPONENTS`는 DS1 2단계 묶음 E로 비었습니다" in readme
    assert f"지금 {specified}개이고, IA 제거 요청 {removal}개" in readme
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
    # V49(2026-11-07 개정, V89·V90): 대운, 세운 칸은 luck-pillar, 지장간은 band-table 칩 + 십성 한 줄
    by_id = components_by_id(BRAND_GROUPS)
    pillar = by_id["luck-pillar"]["parts"]
    for part in ("stemTenGod", "branchTenGod", "twelveStage"):
        assert (pillar[part]["component"], pillar[part]["variant"]) == ("term-token", "label")
    assert pillar["stemTenGod"]["source"] == "DaeunPeriod.stemTenGod, SeunYear.tenGod"
    daeun = by_id["daeun-table"]["parts"]
    assert daeun["row"]["pillar"] == {"component": "luck-pillar", "variant": "column"}
    assert daeun["label"]["maxLines"] == 2
    hidden = by_id["band-table"]["parts"]["bands"]["hiddenStems"]
    assert (hidden["item"]["tenGod"]["component"], hidden["item"]["tenGod"]["variant"]) == ("term-token", "label")
    assert hidden["stack"]["direction"] == "vertical"


def test_feedback_error_banner_group_note_and_toast_position():
    by_id = components_by_id(("feedback", "action"))
    banner = by_id["notice-banner"]
    error = next(variant for variant in banner["variants"] if variant["id"] == "error")
    assert error["parts"]["icon"]["name"] == "warning-circle"  # V105(#923): cloud-warning에서 바꿈
    states = {v["id"]: v["parts"]["icon"]["name"] for v in by_id["error-state"]["variants"]}
    assert states == {"generic": "warning-circle", "offline": "wifi-slash"}
    assert "button" not in banner["parts"]
    note = by_id["settings-row"]["parts"]["groupNote"]
    assert note["slots"] == ["profile-edit.recalc.notice"] and note["maxLines"] == 2
    assert by_id["toast"]["parts"]["container"]["position"] == "above-bottom-bar"


def test_account_choice_saju_has_leap_month_place():
    saju = components_by_id(("input",))["account-choice"]["parts"]["saju"]
    assert saju["leapMonth"]["source"] == "MergeProfileSummary.birth.isLeapMonth"
    assert saju["slot"] == "ui.account-merge.saju"


def test_saju_labels_fit_table_cells():
    # #710(결정 V53, 2026-11-07 개정 V89): 행 머리 열이 없어지고 띠 이름은 네 열에 걸친 띠 머리줄 칩. 꼬리표 넘침은 그대로
    by_id = components_by_id(("saju",))
    band = by_id["band-table"]["parts"]
    assert band["header"]["slot"] == "ui.saju.header" and band["bandHeader"]["label"]["slot"] == "ui.saju.header"
    assert "rowHeader" not in by_id["manse-table"]["parts"]
    assert by_id["saju-pillars"]["parts"]["header"]["slot"] == "ui.saju.header"
    # 꼬리표 규칙의 정본은 luck-pillar currentTag, daeun-table은 참조만 (리뷰 Minor 5)
    current = by_id["luck-pillar"]["parts"]["currentTag"]
    assert current["element"] == "tag.status" and current["slot"] == "ui.saju.tag"
    assert current["maxWidth"] == "기둥 둘과 그 사이 간격" and current["maxLines"] == 1 and "V53" in current["overflow"]
    assert by_id["daeun-table"]["parts"]["currentLabel"] == {"component": "luck-pillar", "part": "currentTag"}
    me = by_id["saju-pillars"]["parts"]["dayMaster"]["tag"]
    assert me["slot"] == "ui.saju.tag" and me["maxWidth"] == "기둥 폭"
    assert band["dayColumn"]["me"]["slot"] == "ui.saju.tag"
    # 일주 열 머리는 나 꼬리표와 한 줄, 글자 실효 폭 약 32. 넘치면 꼬리표를 아래 줄로 (리뷰 Minor 6)
    day_header = band["dayColumn"]["header"]
    assert day_header["line"] == "글자와 나 꼬리표 한 줄" and day_header["textWidth"] == {"value": 32, "unit": "px"}
    assert "아래 줄" in day_header["overflow"]
    lengths_md = (DESIGN_DIR / "lengths.md").read_text(encoding="utf-8")
    assert "지금 자리는 모두 더 넓습니다" not in lengths_md and "약 32px" in lengths_md


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
# 출생 정보 줄 칸 사이 세로선(V88)과 띠 표 열 구분선(V89)도 목록 구분선이 아님
DIVIDER_EXCEPTIONS = {"diary-row parts.entry.divider", "birth-info-row parts.divider", "band-table parts.columns.divider"}


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
    "diary-row", "diary-editor", "saju-pillars", "manse-table", "daeun-table", "ohaeng-bar",
    "offer-card", "purchase-row", "account-choice", "city-search",
    "hanja-tag",  # 태그 이름을 받아 그림 (DS1 2단계)
    "diary-summary", "luck-pillar",  # 기록 집계, 대운과 세운 (DS1 2단계 묶음 B)
    "date-header",  # 음력과 일진은 server 값 (DS1 2단계 묶음 A)
    "date-block",  # 일진은 server 값 (DS1 2단계 묶음 C)
    "fortune-verdict", "score-row",  # 길흉 내역은 server 값 (DS1 2단계 묶음 D)
    "birth-info-row", "band-table", "stage-strip",  # 프로필과 원국 값 (DS1 2단계 묶음 E)
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
    "tag-sentence-list",  # 오늘 화면에서 이미 받은 문장을 다시 보임. tag-sheet에는 loading이 없음 (DS1 2단계 묶음 A)
    "scroll-hint",  # 줄 위에 겹치는 표시. 줄 내용은 luck-pillar 뼈 (DS1 2단계 묶음 E)
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
    # 5.0.0: text-field와 diary-editor에 겹쳐 있던 값을 요소 keyboard.dismiss로 뺌
    dismiss = load_documents(COMPONENTS_DIR)["elements"]["elements"]["keyboard.dismiss"]
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
    ("input-step", "parts.secondaryAction", "paddingX"),  # V106: 두 번째 버튼도 화면 좌우 여백
    ("skeleton", "parts.screen", "gutter"), ("guide-question-card", "parts.container", "padding"),
    ("offer-card", "parts.container", "padding"),
    ("section-header", "parts.startLine", "screen"),  # 화면 좌우 여백과 같은 시작선 (V69)
    ("primary-button", "parts.floating", "marginX"),  # 떠 있는 버튼도 화면 좌우 여백 (V81)
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
    "relation": {"合", "沖", "刑"},  # 刑: 사용자 결정 2026-11-07(D108 ② 누락 보완)
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
    assert sum(len(names) for names in glyphs.values()) == 17
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
    # 간지 글자는 사주 용어 17자 규칙 밖의 변형: 알약과 이름은 그 오행 색, 원은 흰 바탕에 오행 글자색 (리뷰 라운드 2)
    ganji = variants["ganji"]["parts"]
    # V98: 한자색은 오행마다 glyph 토큰(라이트 수, 다크 금은 알약 바탕색. V78 규칙), 금과 수 알약은 테두리
    elements_order = ("wood", "fire", "earth", "metal", "water")
    assert {key: value for key, value in ganji["glyph"].items() if key != "note"} == {
        "bg": "{color.bg.sheet}", "decorative": True,
        "fg": {"byElement": {element: f"{{color.ohaeng.{element}.glyph}}" for element in elements_order}}}
    assert "V78" in ganji["glyph"]["note"]
    assert ganji["pill"]["border"]["byElement"] == {
        element: f"{{color.ohaeng.{element}.border}}" for element in ("metal", "water")}
    assert ganji["tone"]["byElement"] == {
        element: {"bg": f"{{color.ohaeng.{element}.bg}}", "fg": f"{{color.ohaeng.{element}.fg}}"}
        for element in ("wood", "fire", "earth", "metal", "water")}
    assert ganji["ganjiGlyphs"] == GANJI_ELEMENTS and len(GANJI_ELEMENTS["stems"]) + len(GANJI_ELEMENTS["branches"]) == 22
    assert "stemGlyph" not in parts and "ganjiGlyph" not in ganji and "stem.chip" not in tag["uses"]
    assert any("17자" in rule and "사주 용어" in rule and "ganji" in rule for rule in tag["rules"])
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
    assert tags["tag"] == {"component": "hanja-tag", "variant": "default", "max": 3, "order": tags["tag"]["order"]}
    assert "getDiaryStats" in tags["tag"]["order"] and "날짜 수" in tags["tag"]["order"]  # S146 세는 기준 (V97)
    assert tags["count"]["position"] == "알약 안 이름 뒤" and tags["count"]["marginStart"] == "{space.4}"
    # 회고 태그도 어디서나처럼 뜻 시트, 모아보기는 시트 안 꺾쇠 링크 (관문 답 2026-11-06 Q3 안 A 확장)
    assert tags["opens"] == {"sheet": "explain-sheet", "diaryLink": True}
    assert "page.push" not in summary["uses"] and any("explain-sheet" in rule for rule in summary["rules"])
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
    assert parts["order"] == ["topLabel", "stemTenGod", "stem", "branch", "branchTenGod", "twelveStage", "startYear", "currentTag"]
    # 묶음 E가 대운 줄을 이 컴포넌트로 그리도록 daeun-table 기둥의 12운성과 시작 연도를 옮김 (리뷰 Minor 4)
    assert (parts["twelveStage"]["component"], parts["twelveStage"]["variant"]) == ("term-token", "label")
    assert parts["twelveStage"]["source"] == "DaeunPeriod.twelveStage" and parts["twelveStage"]["marginTop"] == "{space.2}"
    assert parts["startYear"]["type"] == "{type.numeric.table}" and parts["startYear"]["source"] == "DaeunPeriod.startYear"
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
        assert emphasis["container"] == {"element": "highlight.current", "bg": "{color.highlight.bg}"}  # V93
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
    for hidden in ("topLabel", "stemTenGod", "branchTenGod", "currentTag", "twelveStage", "startYear"):
        assert compact[hidden] == {"visible": False}, hidden
    # 두 줄이 모두 지금이라 강조 바탕 없음, 흰 카드 위에서 꼬리표와 용어 칩이 구분됨(사용자 결정 2026-11-06, origin)
    assert compact["highlight"] == "none" and compact["onCard"]["bg"] == "{color.bg.sheet}"
    assert "status.bg" not in json.dumps(variants["compact"])
    assert pillar["a11y"]["textScaleMax"] == 1.3
    assert any("낙관 윤곽" in rule for rule in pillar["rules"])


# DS1 2단계 spec §4 date-header (묶음 A, 결정 V78)
def test_date_header():
    header = component("today", "date-header")
    parts = header["parts"]
    solar = parts["solar"]
    assert (solar["type"], solar["fg"]) == ("{type.subtitle}", "{color.text.primary}")
    assert (solar["slot"], solar["daySheetSlot"]) == ("today.date.solar", "day-sheet.date.solar")
    meta = parts["meta"]
    assert (meta["type"], meta["fg"], meta["marginTop"]) == ("{type.caption.lg}", "{color.text.secondary}", "{space.2}")
    # 음력과 일진은 한 줄에 놓고 글자로 잇지 않음(구분은 간격, V47·V52와 같은 이유)
    assert meta["order"] == ["lunar", "iljin"] and meta["gap"] == "{space.8}" and meta["separator"] == "none"
    lunar, iljin = parts["lunar"], parts["iljin"]
    assert (lunar["slot"], lunar["daySheetSlot"]) == ("today.date.lunar", "day-sheet.date.lunar")
    assert lunar["whenMissing"] == "hide" and "#806" in lunar["source"]  # 음력이 계약에 없으면 일진만
    assert iljin["slot"] == "today.date.iljin" and iljin["fontFallback"] == "{font.family.hanja}"
    variants = {variant["id"]: variant["parts"] for variant in header["variants"]}
    assert set(variants) == {"today", "day-sheet"}
    assert variants["day-sheet"]["iljin"] == {"visible": False}  # 그날 시트는 일진 없이
    trailing = variants["day-sheet"]["trailing"]  # V109: 날의 성격은 날짜 머리 오른쪽, 두 줄 묶음 가운데
    assert (trailing["component"], trailing["variant"], trailing["slot"]) == ("hanja-tag", "emphasis", "day-sheet.character.label")
    assert "두 줄 묶음의 세로 가운데" in trailing["verticalAlign"] and "아래" in trailing["overflow"]
    assert [bone["bone"] for bone in header["states"]["loading"]["skeleton"]] == ["meta"]
    assert header["a11y"]["role"] == "header" and header["a11y"]["readsHanja"] is False
    # 음력과 일진이 모두 없으면 줄과 위 여백을 그리지 않음 (리뷰 Minor 5)
    assert meta["whenEmpty"] == "hide-line-and-gap"
    assert any("meta" in rule and "space.2" in rule and "그리지 않는다" in rule for rule in header["rules"])
    assert "date-header" not in components.IA_PENDING_COMPONENTS and "date-header" in CONTENT_COMPONENTS


# DS1 2단계 spec §4 tag-sentence-list, IA tag-sheet (결정 V79)
def test_tag_sentence_list():
    sentences = component("today", "tag-sentence-list")
    parts = sentences["parts"]
    assert parts["head"] == {"type": "{type.label.md}", "fg": "{color.text.secondary}",
                             "slot": "tag-sheet.sentences.title", "marginBottom": "{space.8}"}
    row = parts["row"]
    assert row["sources"] == ["today.fortune.body", "today.guide.question"]  # 오늘 화면과 같은 문장
    assert row["label"]["width"] == {"value": 52, "unit": "px"}
    assert (row["label"]["type"], row["label"]["fg"]) == ("{type.caption.md}", "{color.text.secondary}")
    assert "IA 슬롯 없음" in row["label"]["copy"]  # 이름 칸 글자는 writing 새 슬롯 요청
    # 관문 답(사용자 2026-11-06): 이름 칸 52 고정, 넘치면 칸 안에서 줄바꿈(ko "오늘의 질문" 두 줄), 문장 칸 폭은 줄이지 않음
    assert row["label"]["wrap"] == {"within": "label", "maxLines": "none", "widthFixed": True, "sentenceWidthKept": True}
    assert any("52" in rule and "줄바꿈" in rule and "문장 칸 폭" in rule for rule in sentences["rules"])
    assert (row["sentence"]["component"], row["sentence"]["variant"]) == ("sentence-block", "body")
    assert row["sentence"]["marginStart"] == "{space.8}"
    assert (row["paddingTop"], row["paddingBottom"]) == ("{space.12}", "{space.12}")
    assert parts["divider"] == {"element": "list.divider"} and "list.divider" in sentences["uses"]
    # 빈 안내: 대표 태그 2순위처럼 이 기운으로 정해진 문장이 없을 때 한 줄
    empty = parts["empty"]
    assert (empty["slot"], empty["type"], empty["fg"], empty["visible"]) == (
        "tag-sheet.sentences.empty", "{type.body.ui}", "{color.text.secondary}", False)
    state = sentences["states"]["empty"]
    assert "2순위" in state["when"] and state["parts"] == {"row": {"visible": False}, "empty": {"visible": True}}
    # 출구: 그 태그가 붙은 내 일기 보기, 꺾쇠 링크(화면 이동)
    link = parts["diaryLink"]
    assert link["slot"] == "tag-sheet.diary.cta" and link["params"] == ["tag"]  # 편수 없음 (관문 답 2026-11-06)
    assert link["label"] == {"type": "{type.label.lg}", "fg": "{color.action.primary}"}
    assert link["chevron"] == CHEVRON and link["marginTop"] == "{space.16}"
    assert link["target"] == {"screen": "tag-diary", "presentation": "page", "transition": "page.push"}
    assert "hiddenWhen" not in link and "josa" in link["josa"]
    assert "빈 상태" in link["whenNoDiary"] and not any("0편" in rule for rule in sentences["rules"])
    assert "page.push" in sentences["uses"] and "lock-simple" not in json.dumps(sentences)
    assert sentences["a11y"]["role"] == "list" and sentences["a11y"]["linkRole"] == "link"
    assert "tag-sentence-list" not in components.IA_PENDING_COMPONENTS and "tag-sentence-list" in NO_LOADING_CONTENT
    # tag-sheet 배치: IA 슬롯이 모두 나오고, 머리 태그는 누를 수 없는 default
    layout = _md_section("today.md", "### tag-sheet 화면 배치")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("tag-sheet"))
    assert "`tag-sentence-list`" in layout and "`hanja-tag` `default`" in layout and "`depth-link` `inline-end`" in layout


# DS1 2단계 spec §4 lock.veil G1, D106 (결정 V80)
def test_lock_veil_g1():
    veil = load_documents(COMPONENTS_DIR)["elements"]["elements"]["lock.veil"]
    lead = veil["lead"]
    assert lead["fg"] == "{color.text.primary}" and lead["type"] == "{type.sentence.body}"
    assert "blur" not in lead and "#797" in lead["source"] and lead["words"] == "2~3"  # 앞 단어는 또렷
    placeholder = veil["placeholder"]
    assert placeholder["source"] == "app" and placeholder["matchesRealLength"] is False
    assert placeholder["flow"] == "앞부분 바로 뒤, 같은 줄에서 이어짐"
    assert veil["lines"] == {"basis": 3, "source": 2, "personal": 3, "sentence-block locked": 2}  # V92
    assert "길이 힌트" not in json.dumps(veil, ensure_ascii=False)  # 실제 길이와 맞추지 않음
    assert veil["body"]["blur"] == {"value": 6, "unit": "px"} and veil["body"]["opacity"] == 0.5
    assert "그대로" in veil["reduceMotion"]  # 동작 줄이기에서도 흐림 고정
    assert veil["a11y"]["bodyExcluded"] is True and veil["a11y"]["leadRead"] is True
    locked = component("sentence", "depth-link")["states"]["locked"]["parts"]["evidenceSheet"]
    assert (locked["basis"]["lines"], locked["source"]["lines"], locked["personal"]["lines"]) == (3, 2, 3)
    assert any("saju-chart.yongsin.basis" in place for place in veil["where"])


# DS1 2단계 spec §4 근거 시트 머리, IA evidence-sheet (결정 V80)
def test_evidence_sheet_head():
    link = component("sentence", "depth-link")
    sheet = link["parts"]["evidenceSheet"]
    assert sheet["order"][:3] == ["title", "target", "pillars"]
    assert set(sheet["order"]) <= set(sheet)
    target = sheet["target"]
    assert target["marginTop"] == "{space.12}"
    tags = target["tags"]
    assert (tags["component"], tags["variant"], tags["interactive"], tags["gap"]) == ("hanja-tag", "default", False, "{space.8}")
    sentence = target["sentence"]
    assert (sentence["slot"], sentence["type"], sentence["fg"], sentence["marginTop"]) == (
        "evidence-sheet.target.body", "{type.caption.lg}", "{color.text.secondary}", "{space.8}")
    assert sentence["segments"] == "plain"
    locked = link["states"]["locked"]["parts"]["evidenceSheet"]
    assert "target" not in locked  # 대상 문장과 태그는 잠기지 않음
    assert component("sentence", "hanja-tag")["parts"]["opens"]["notInteractiveIn"] == [
        {"screen": "evidence-sheet", "part": "head"}, {"screen": "tag-sheet", "part": "head"},
        {"screen": "color-rule-sheet", "part": "score-row rule"},  # Task 8 리뷰 I1: 색 규칙 표의 태그
        {"screen": "saju-chart", "part": "birth-info-row hour"}]  # V88: 시진 뜻 원고가 없음


# IA v5 today 구성 순서 (D108, 결정 V78)
TODAY_ORDER = [
    "today.bar.title", "today.date.solar", "today.date.lunar", "today.date.iljin", "today.fortune.title",
    "today.character.label", "today.ten-god.label", "today.fortune.head", "today.fortune.body",
    "today.featured.title", "today.featured.empty", "today.lucky.title", "today.event.title", "today.event.summary", "today.guide.title",
    "today.guide.question", "today.guide.cta",
]


def test_today_section_order():
    layout = _md_section("today.md", "### today 화면 배치")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("today"))
    positions = [layout.index(f"`{slot}`") for slot in TODAY_ORDER]
    assert positions == sorted(positions)
    lines = layout.splitlines()

    def line_of(slot):
        return next(line for line in lines if f"`{slot}`" in line)

    fortune = line_of("today.fortune.title")
    assert "`section-header` `action`" in fortune and "`reaction-button`" in fortune and "`today.reaction.label`" in fortune
    for slot in ("today.featured.title", "today.lucky.title", "today.event.title", "today.guide.title"):
        assert "`section-header` `plain`" in line_of(slot), slot
    assert "`hanja-tag` `emphasis`" in line_of("today.character.label")
    assert "`hanja-tag` `default`" in line_of("today.ten-god.label")
    assert "`list.divider`" in layout and "`depth-link` `inline-end`" in line_of("today.fortune.head")
    assert "`date-header` `today`" in line_of("today.date.solar")
    assert "첫 섹션까지 `space.32`" in line_of("today.date.solar")  # 날짜 머리와 첫 섹션 사이 (리뷰 Minor 2)
    composition = [line for line in lines if re.match(r"^(\d+\. |   \* )", line)]
    assert not [line for line in composition if "day-character" in line]  # 맨 위 날의 성격 배지와 이유 줄은 빠짐(D108)


# 시안 A에서 찾은 빈틈: 용신의 날 진한 채움은 이름이 흰 글자라, 흰 원 안 한자를 이름색으로 그리면 보이지 않음 (결정 V78)
def test_hanja_tag_emphasis_glyph_stays_visible():
    emphasis = next(v for v in component("sentence", "hanja-tag")["variants"] if v["id"] == "emphasis")
    glyph = emphasis["parts"]["glyph"]
    assert glyph["fg"] == {"YONGSIN_DAY": "{color.badge.good.bg}", "otherwise": "same-as-name"}


# 리뷰 I1: 잠김 낭독은 lock.veil G1 정의 하나를 따름. 슬롯은 상태 낱말 "잠김"뿐이고 세 조각을 순서대로 읽음
def test_locked_labels_follow_lock_veil():
    veil = load_documents(COMPONENTS_DIR)["elements"]["elements"]["lock.veil"]["a11y"]
    assert veil["label"] == "구역 제목 + 앞부분 + '잠김'"
    assert veil["order"] == ["title", "lead", "state"] and veil["stateSlot"] == "evidence-sheet.a11y.locked"
    block = component("sentence", "sentence-block")["a11y"]
    link = component("sentence", "depth-link")["a11y"]
    assert block["lockedLabel"] == veil["label"] and link["lockedLabel"] == veil["label"]
    assert block["lockedLabelSlot"] == link["lockedLabelSlot"] == veil["stateSlot"]
    md = (COMPONENTS_DIR / "sentence.md").read_text(encoding="utf-8")
    locked_line = next(line for line in md.splitlines() if line.startswith("* **잠김**(`states.locked`)"))
    assert "앞부분" in locked_line and "+ \"잠김\"" in locked_line


# 리뷰 I2: IA v5(D108, V78)부터 today 칩 줄에 대표 태그 칩이 없음. 변형은 계약 5.0.0에서 지움
def test_today_chip_row_has_no_tag():
    card = component("today", "lucky-card")
    rules = " ".join(card["rules"])
    assert "tag 칩을 두지 않는다" in rules and "hanja-tag" in rules
    assert "최대 5개(색, 방향, 숫자 3 + 시간 2)" in rules and "태그 2" not in rules
    md = _md_section("today.md", "## lucky-card")
    assert "최대 5개" in md and "최대 7개" not in md


# DS1 2단계 묶음 F 일기 목록 + C 일기 쓰기 (spec §1 date-block, §2 Q7·Q8, §4, 결정 V81~V83)
def test_date_block():
    block = component("diary", "date-block")
    parts = block["parts"]
    assert parts["container"] == {"layout": "row", "gap": "{space.12}", "align": "center"}  # 일 숫자 옆 space.12
    day = parts["day"]
    assert day["slot"] == "diary-edit.date.day"
    assert (day["fontFamily"], day["fontSize"], day["fontWeight"]) == ("{font.family.ui}", {"value": 44, "unit": "px"}, 700)
    assert day["fg"] == "{color.text.primary}" and day["fontFeatures"] == ["tnum"]
    assert parts["side"]["order"] == ["month", "iljin"]
    month, iljin = parts["month"], parts["iljin"]
    assert (month["slot"], month["type"], month["fg"]) == ("diary-edit.date.month", "{type.label.lg}", "{color.text.primary}")
    assert (iljin["slot"], iljin["type"], iljin["fg"]) == ("diary-edit.date.iljin", "{type.caption.md}", "{color.text.secondary}")
    assert iljin["marginTop"] == "{space.2}" and iljin["fontFallback"] == "{font.family.hanja}"
    assert iljin["whenMissing"] == "hide"
    assert [bone["bone"] for bone in block["states"]["loading"]["skeleton"]] == ["iljin"]  # 날짜는 기기 값, 일진은 server
    assert block["a11y"]["role"] == "header" and block["a11y"]["readsHanja"] is False
    assert "date-block" not in components.IA_PENDING_COMPONENTS and "date-block" in CONTENT_COMPONENTS
    md = _md_section("diary.md", "## date-block")
    assert "* 쓰는 화면: diary-edit" in md and "44 700" in md


def test_diary_row_hanja_tag():
    row = component("diary", "diary-row")
    parts = row["parts"]
    # Q1 ②(관문 답 2026-11-06): 카드 맨 위 날의 성격 hanja-tag(길흉 톤), 맨 아래 대표 태그(사주 용어 초록)
    kind = parts["dayKind"]
    assert (kind["component"], kind["variant"], kind["tone"]) == ("hanja-tag", "default", "dayKind")
    assert kind["source"] == "DiarySummary.dayKind (D96)" and kind["whenMissing"] == "hide"
    assert kind["position"] == "card-top" and kind["opens"] == {"sheet": "explain-sheet", "diaryLink": False}
    tag = parts["tag"]
    assert (tag["component"], tag["variant"], tag["count"]) == ("hanja-tag", "default", "all")  # D115, V103
    assert tag["marginTop"] == "{space.12}" and tag["whenMissing"] == "hide"
    assert tag["opens"] == {"sheet": "explain-sheet", "diaryLink": True}  # Q3 안 A: 시트, 모아보기는 시트 안 링크
    # Q2 ①: 모아보기 안 줄은 대표 태그만 숨김. 날의 성격은 줄마다 달라 보임 (controller Ruling)
    assert "hiddenIn" not in kind and tag["hiddenIn"] == ["tag-diary"]  # 이름은 그대로(지우면 주 버전)
    assert "모아 본 그 태그만" in tag["hiddenScope"]  # D113 ①, D115 ③: 숨김 범위는 모아 본 태그만
    # 한 편 카드: 날의 성격이 있을 때만 그 아래 space.8 (리뷰 Minor 4)
    assert parts["preview"]["marginTop"] == "{space.8}" and "날의 성격이 있을 때만" in parts["preview"]["marginTopWhen"]
    assert "badge" not in parts and "tag-chip" not in json.dumps(row, ensure_ascii=False)
    assert "tag-diary" not in json.dumps(tag["opens"]) and "page.push" not in row["uses"]
    variants = {variant["id"]: variant["parts"] for variant in row["variants"]}
    assert variants["entries"]["dayKind"] == {"visible": False}
    assert row["a11y"]["group"]["label"] == "날짜 요일, 날의 성격"
    bones = [bone["bone"] for bone in row["states"]["loading"]["skeleton"]]
    assert "dayKind" in bones and "badge" not in bones
    text = (COMPONENTS_DIR / "diary.md").read_text(encoding="utf-8")
    md = text.split("## diary-row", 1)[1].split("\n## ", 1)[0]
    assert "`hanja-tag` `default`" in md and "`DiarySummary.dayKind`" in md and "`explain-sheet`" in md


def test_hanja_tag_opens_sheet_everywhere():
    # 한자 태그는 어디서나 누르면 시트, 화면 이동 예외 없음 (관문 답 2026-11-06 Q3 안 A 확장, V73)
    opens = component("sentence", "hanja-tag")["parts"]["opens"]
    assert "pageIn" not in opens and "pageRule" not in opens
    assert "예외 없음" in opens["rule"]
    sheet = component("frame", "explain-sheet")
    link = sheet["parts"]["diaryLink"]
    assert link["params"] == ["tag"] and "count" not in json.dumps(link)
    assert link["target"] == {"screen": "tag-diary", "presentation": "page", "transition": "page.push"}
    assert link["chevron"] == CHEVRON and link["marginTop"] == "{space.16}" and link["minTarget"] == 44
    assert "날의 성격" in link["notFor"] and "대표 태그" in link["when"]
    assert "<태그>이 붙은 내 일기 보기" in link["copy"] and "josa" in link["josa"]
    assert "page.push" in sheet["uses"]
    assert sheet["a11y"]["linkRole"] == "link" and "꺾쇠는 읽지 않음" in sheet["a11y"]["linkLabel"]  # 리뷰 Minor 3
    tags = component("diary", "diary-editor")["parts"]["tags"]  # tag-chip 대신 hanja-tag (V96)
    assert tags["component"] == "hanja-tag" and tags["variant"] == "default"
    assert tags["opens"] == {"sheet": "explain-sheet", "diaryLink": True} and tags["appear"] == "appear.seep"
    for name in ("diary.md", "sentence.md"):
        assert "pageIn" not in (COMPONENTS_DIR / name).read_text(encoding="utf-8"), name


def test_primary_button_leading_icon():
    button = component("action", "primary-button")
    icon = button["parts"]["leadingIcon"]
    assert icon == {"optional": True, "size": "adjacent-text", "weight": "regular", "color": "label-color",
                    "gap": "{space.8}", "decorative": True,
                    "note": "글자 앞 아이콘. 아이콘과 글자 묶음을 버튼 가운데에 둔다. 아이콘 이름은 쓰는 자리가 정함"}
    loading = button["states"]["loading"]["parts"]
    assert loading["leadingIcon"] == {"visible": False}  # 처리 중에는 점 셋만
    md = _md_section("action.md", "## primary-button")
    assert "`leadingIcon`" in md and "`space.8`" in md


def test_diary_list_floating_button():
    floating = component("action", "primary-button")["parts"]["floating"]
    assert floating["marginX"] == "{space.20}" and floating["marginBottom"] == "{space.16}"
    assert floating["shadow"] == "{shadow.raised}" and floating["contentBehind"] is True
    assert floating["above"] == ["ad-banner", "tab-bar", "safe-area"]
    assert floating["usedIn"] == [{"screen": "diary-list", "slot": "diary-list.pick-date.cta", "leadingIcon": "pencil-simple"}]
    assert "empty-state" in floating["whenEmpty"] and "가운데" in floating["whenEmpty"]
    assert floating["listPaddingBottom"] == "버튼 높이 52 + space.16 + space.16"
    assert "다시 시도" in floating["whenError"] and "숨김" in floating["whenError"]  # 리뷰 Minor 7
    layout = _md_section("diary.md", "### diary-list 화면 배치")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("diary-list"))
    lines = layout.splitlines()
    cta = next(line for line in lines if "`diary-list.pick-date.cta`" in line and "floating" in line)
    assert "`pencil-simple`" in cta and "목록이 있을 때" in cta
    empty = next(line for line in lines if "`diary-list.empty.body`" in line)
    assert "`empty-state`" in empty and "가운데" in empty and "떠 있는 버튼은 없" in empty
    assert ("primary-button", "parts.floating", "marginX") in SPACE_20_ALLOWED


def test_app_bar_center_status():
    bar = component("frame", "app-bar")
    variants = {variant["id"]: variant for variant in bar["variants"]}
    edit = variants["edit"]["parts"]
    assert edit["back"] == {"icon": "caret-left", "visible": True}
    assert edit["center"] == {"component": "draft-indicator", "when": "본문에 초점이 있는 동안(쓰는 중)",
                              "replaces": "title", "transition": "appear.seep"}
    assert edit["title"] == {"slot": "diary-edit.bar.title", "align": "center", "type": "{type.label.lg}"}
    assert edit["textAction"] == {"slot": "diary-edit.save.cta"}
    action = bar["parts"]["textAction"]
    assert (action["type"], action["fg"], action["paddingX"]) == ("{type.label.lg}", "{color.action.primary}", "{space.8}")
    assert action["minTarget"] == 44 and action["max"] == 1
    saving = bar["states"]["textActionSaving"]
    assert saving["pattern"] == "loading.breathe" and saving["parts"]["textAction"]["label"] == {"visible": False}
    assert not [rule for rule in bar["rules"] if "동작 왼쪽" in rule]
    # 상태가 가리키는 부품은 textAction에 정의돼 있어야 함 (리뷰 Minor 3)
    for state in ("textActionDisabled", "textActionSaving"):
        for key in bar["states"][state]["parts"]["textAction"]:
            assert key in action, (state, key)
    assert action["label"] == {"type": "{type.label.lg}", "fg": "{color.action.primary}", "maxLines": 1}
    assert action["dots"]["count"] == 3
    assert bar["states"]["textActionDisabled"]["parts"]["textAction"]["label"] == {"fg": "{color.disabled.fg}"}
    # 이어 쓰기: 초점을 받으면 local, 초점 전에는 제목 (리뷰 Minor 4)
    layout = _md_section("diary.md", "### diary-edit 화면 배치")
    draft_line = next(line for line in layout.splitlines() if "(`draft`)" in line)
    assert "초점을 받으면" in draft_line and "`local`" in draft_line and "제목" in draft_line
    indicator = component("diary", "draft-indicator")
    parts = indicator["parts"]
    assert parts["container"]["position"] == "app-bar-center"
    assert parts["label"]["slot"] == "diary-edit.draft.status"
    count = parts["count"]
    assert (count["slot"], count["type"], count["fg"]) == ("diary-edit.length.count", "{type.caption.md}", "{color.text.secondary}")
    assert count["fontFeatures"] == ["tnum"] and count["marginStart"] == "{space.8}" and count["separator"] == "none"
    assert indicator["a11y"]["countAnnounced"] is False
    assert "app-bar-end" not in json.dumps(indicator, ensure_ascii=False)
    md = _md_section("frame.md", "## app-bar")
    assert "`edit`" in md and "`draft-indicator`" in md and "글자 버튼" in md


def test_quoted_question():
    editor = component("diary", "diary-editor")
    variants = {variant["id"]: variant["parts"] for variant in editor["variants"]}
    shape = editor["parts"]["question"]  # 모양만 최상위. 슬롯과 바꾸기는 edit (리뷰 I1)
    assert "slot" not in shape and "swap" not in shape
    question = {**shape, **variants["edit"]["question"]}
    assert question["slot"] == "diary-edit.guide.question" and question["optional"] is True
    assert (question["type"], question["fg"]) == ("{type.sentence.body}", "{color.text.secondary}")
    # 질문 14: 문장 글꼴 14 토큰이 없어 sentence.body에 크기만 덮어씀(미리보기 14.5 선례, 관문 답 2026-11-06)
    assert shape["fontSize"] == {"value": 14, "unit": "px"}
    # 보기는 저장된 질문을 인용 모양으로 보임, 바꾸기 없음 (관문 답 Q4 ①)
    view = variants["view"]["question"]
    assert view == {"source": "getDiary guideQuestion", "whenMissing": "hide"}
    assert "diary-edit." not in json.dumps(variants["view"], ensure_ascii=False)
    assert question["quoteLine"] == {"width": {"value": 3, "unit": "px"}, "color": "{color.action.primary}", "radius": "{radius.full}"}
    assert question["paddingStart"] == "{space.12}"
    swap = question["swap"]
    assert (swap["icon"], swap["weight"], swap["size"], swap["color"]) == (
        "arrows-clockwise", "light", "{size.icon.20}", "{color.text.secondary}")
    assert swap["minTarget"] == 44 and swap["align"] == "first-line" and swap["marginStart"] == "{space.8}"
    assert swap["visibleWhen"] == "그날 후보가 둘 이상" and swap["transition"] == "appear.seep"
    assert "#806" in swap["candidates"] and "#804" in swap["candidates"]
    assert swap["a11y"]["role"] == "button" and "writing 새 슬롯" in swap["a11y"]["label"]
    assert variants["edit"]["date"] == {"visible": False}  # 날짜는 위 date-block
    assert editor["motion"]["saveSequence"][0] == {"step": "button-breathe", "pattern": "loading.breathe",
                                                   "target": "app-bar textAction"}
    layout = _md_section("diary.md", "### diary-edit 화면 배치")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("diary-edit"))
    order = ["diary-edit.bar.title", "diary-edit.draft.status", "diary-edit.length.count", "diary-edit.save.cta",
             "diary-edit.date.day", "diary-edit.date.month", "diary-edit.date.iljin", "diary-edit.guide.question",
             "diary-edit.body.placeholder"]
    positions = [layout.index(f"`{slot}`") for slot in order]
    assert positions == sorted(positions)
    assert "`primary-button`" not in layout  # 아래 고정 버튼 없음(IA v5)


KEYBOARD_INPUTS = (("input", "text-field"), ("diary", "diary-editor"))


def test_keyboard_dismiss_everywhere():
    dismiss = load_documents(COMPONENTS_DIR)["elements"]["elements"]["keyboard.dismiss"]
    assert dismiss["anchor"] == "keyboard-inset"
    assert dismiss["anchorIncludes"] == ["OS 자동완성과 추천 줄", "플랫폼 키보드 inset"]
    assert dismiss["inset"] == "{space.12}"
    assert "붙여넣기" in dismiss["qa"] and "QA" in dismiss["qa"]
    # 일기 쓰기도 다른 입력 화면과 같은 버튼(Q8, V68 유지): 두 곳 모두 요소를 가리키기만 함(5.0.0)
    for group, component_id in KEYBOARD_INPUTS:
        spec = component(group, component_id)
        assert spec["states"]["focused"]["parts"]["keyboardDismiss"] == {"element": "keyboard.dismiss"}, component_id
        assert "keyboard.dismiss" in spec["uses"], component_id
    editor = component("diary", "diary-editor")
    assert "space.12" in editor["parts"]["body"]["scrollPaddingBottom"]
    for name in ("input.md", "diary.md"):
        text = (COMPONENTS_DIR / name).read_text(encoding="utf-8")
        assert "키보드 inset" in text and "붙여넣기" in text, name


# DS1 2단계 묶음 D: 달력 4단계, 그날 시트, 색 규칙 시트 (spec §2 Q2·Q4·Q6·刑, §3, §4, 결정 V84~V87)
LEVEL_FILL = {"great": "{color.calendar.level.great}", "good": "{color.calendar.level.good}",
              "caution": "{color.calendar.level.caution}"}


def test_day_cell_four_levels():
    cell = component("calendar", "day-cell")
    fill = cell["parts"]["luckFill"]
    assert {key: fill[key] for key in ("great", "good", "caution", "neutral")} == {**LEVEL_FILL, "neutral": "transparent"}
    assert "#806" in fill["source"] and "3 이상" in fill["rule"]  # 아주 잘 풀리는 날은 server 수준 추가 뒤
    text = json.dumps(cell, ensure_ascii=False)
    assert "calendar.good.bg" not in text and "calendar.caution.bg" not in text  # 옛 3단계 토큰은 가리키지 않음
    assert cell["a11y"]["luckLevels"] == 4 and cell["a11y"]["luckWordSlot"] == "calendar.legend.body"
    # 오늘 표시는 낙관 도장 윤곽 26 그대로 (Q6 ②, V19), 원이 아님
    today = cell["parts"]["todayOutline"]
    assert (today["element"], today["variant"], today["size"]) == ("seal", "outline", {"value": 26, "unit": "px"})
    md = _md_section("calendar.md", "## day-cell")
    assert "`calendar.level.great`" in md and "아주 잘 풀리는 날" in md


def test_calendar_legend_entry_is_term_chip():
    month = component("calendar", "calendar-month")
    legend = month["parts"]["legend"]
    assert legend["slot"] == "calendar.legend.body" and "optional" not in legend
    assert legend["items"] == ["great", "good", "caution"]  # 무난한 날은 채우지 않아 견본이 없음
    assert legend["swatch"]["colors"] == LEVEL_FILL
    assert (legend["swatch"]["size"], legend["swatch"]["radius"]) == ({"value": 10, "unit": "px"}, "{radius.xs}")
    entry = month["parts"]["ruleEntry"]
    # Q2 ②: 용어 칩 모양(term-token과 같은 바탕과 글자색), ⓘ 없음
    assert (entry["bg"], entry["fg"], entry["radius"]) == ("{color.term.bg}", "{color.term.fg}", "{radius.xs}")
    assert entry["slot"] == "calendar.legend.rule-link" and entry["minTarget"] == {"value": 44, "unit": "px"}  # 리뷰 Minor 3
    # 리뷰 Minor 6: server #806 전에도 아주 잘 풀리는 날 견본을 보이는 이유
    assert any("#806" in rule and "견본" in rule for rule in month["rules"])
    assert entry["target"] == {"screen": "color-rule-sheet", "presentation": "sheet", "variant": "half",
                               "transition": "sheet.enter"}
    assert "icon" not in json.dumps(entry) and "info" not in json.dumps(entry)
    assert "길흉" in entry["copy"]  # 문구는 '색' 대신 길흉을 가리킴(writing)
    assert month["a11y"]["ruleEntryRole"] == "button"
    layout = _md_section("calendar.md", "### calendar 화면 배치")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("calendar"))


def test_fortune_verdict():
    verdict = component("calendar", "fortune-verdict")
    parts = verdict["parts"]
    assert (parts["card"]["bg"], parts["card"]["radius"], parts["card"]["padding"]) == (
        "{color.bg.base}", "{radius.lg}", "{space.16}")
    track = parts["track"]
    assert track["height"] == {"value": 4, "unit": "px"} and track["gradient"] == "{color.verdict.track}"
    assert track["direction"] == "caution-to-great" and track["radius"] == "{radius.full}"
    marker = parts["marker"]
    assert marker["size"] == {"value": 18, "unit": "px"} and marker["bg"] == "{color.bg.sheet}"
    assert marker["border"] == {"color": "{color.action.primary}", "width": {"value": 2, "unit": "px"}}
    assert marker["position"]["clamp"] == [-3, 3] and marker["position"]["map"] == "(score + 3) / 6"
    names = parts["names"]
    assert names["order"] == ["caution", "neutral", "good"] and names["align"] == ["start", "center", "end"]
    assert (names["type"], names["fg"], names["marginTop"]) == ("{type.caption.md}", "{color.text.secondary}", "{space.8}")
    rows = parts["rows"]
    assert (rows["component"], rows["variant"]) == ("score-row", "verdict")
    assert rows["divider"] == {"element": "list.divider"} and "#806" in rows["source"]
    assert any("요약 문장" in rule and "두지 않는다" in rule for rule in verdict["rules"])  # 리뷰 Minor 1
    # 리뷰 Minor 5: 내역 0개인 날은 noBreakdown과 같은 모양
    hidden = {"rows": {"visible": False}, "toggle": {"visible": False}}  # V108: 내역이 없으면 안내 줄도 없음
    assert verdict["states"]["noItems"]["parts"] == hidden and "noBreakdown" in verdict["states"]["noItems"]["note"]
    assert "움직이지 않" in verdict["motion"]["marker"]
    assert [bone["bone"] for bone in verdict["states"]["loading"]["skeleton"]] == ["track"]  # V108: 처음엔 접힘
    assert verdict["states"]["noBreakdown"]["parts"] == hidden and verdict["states"]["noBreakdown"]["pressable"] is False
    assert verdict["a11y"]["role"] == "group" and verdict["a11y"]["readsScore"] is False
    assert "fortune-verdict" not in components.IA_PENDING_COMPONENTS and "fortune-verdict" in CONTENT_COMPONENTS


def test_score_row_dots():
    row = component("calendar", "score-row")
    parts = row["parts"]
    assert (parts["tag"]["component"], parts["tag"]["tone"]) == ("hanja-tag", "verdictTone-by-sign")
    meaning = parts["meaning"]
    assert (meaning["type"], meaning["maxLines"], meaning["marginStart"]) == ("{type.caption.lg}", 2, "{space.12}")
    dots = parts["dots"]
    assert dots["size"] == {"value": 8, "unit": "px"} and dots["gap"] == "{space.4}"  # spec 3은 토큰이 아니라 4 (V56)
    assert dots["color"] == {"plus": "{color.badge.good.bg}", "minus": "{color.text.secondary}"}
    assert dots["count"] == "abs(score)" and dots["max"] == 3 and dots["overflow"] == "plus-mark"
    sign = parts["sign"]
    assert sign["glyphs"] == {"plus": "U+002B", "minus": "U+2212"} and sign["fg"] == "{color.text.primary}"  # 리뷰 Minor 2
    assert row["a11y"]["label"] == "이름, 뜻, 더함 둘" and row["a11y"]["countWords"] is True
    variants = {variant["id"]: variant["parts"] for variant in row["variants"]}
    assert set(variants) == {"verdict", "rule"}
    assert variants["rule"]["meaning"] == {"visible": False} and variants["rule"]["tag"]["interactive"] is False
    assert variants["verdict"]["tag"]["opens"] == "explain-sheet"
    # Ruling 2: hanja-tag 길흉 톤을 쓰는 부모는 모두 명세가 있음
    allowed = component("sentence", "hanja-tag")["parts"]["tone"]["toneAllowedIn"]
    specified = {c["id"] for c in all_components()}
    assert set(allowed) <= specified
    assert "score-row" not in components.IA_PENDING_COMPONENTS and "score-row" in CONTENT_COMPONENTS


def test_color_rule_sheet_has_no_scale():
    # 관문 답 2026-11-07 Q4: 척도 그림은 합치지 않고, 색 규칙 시트는 설명 문장과 점수표만
    assert "score-scale" not in {c["id"] for c in all_components()}
    layout = _md_section("calendar.md", "### color-rule-sheet 화면 배치")
    items = [line for line in layout.splitlines() if line[:2] in ("1.", "2.", "3.", "4.", "5.")]
    assert len(items) == 3 and not any("score-scale" in line or "관계 그림" in line for line in items)  # 제목, 설명, 점수표만
    assert "합한 점으로" not in (COMPONENTS_DIR / "calendar.md").read_text(encoding="utf-8")
    assert "IA 제거 요청" in layout and "75%" not in layout
    height = re.search(r"내용 높이는 휴대폰 높이의 (\d+(?:\.\d+)?)%", layout)
    assert height and height.group(1) == "59.6" and ("`sheet` `half`" in layout) == (float(height.group(1)) <= 60.0)
    assert "ja, en" in layout and "스크롤" in layout  # 넘치는 조건: 작은 화면, 큰 글자, 긴 언어
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert "score-scale" in readme and "IA_REMOVAL_REQUESTED" in readme
    assert "score-scale" not in json.dumps(json.loads(IA_PATH.read_text(encoding="utf-8"))["components"])  # D113로 IA에서 빠짐

def test_day_sheet_opens_full():
    sheet = component("frame", "sheet")
    variants = {variant["id"]: variant for variant in sheet["variants"]}
    assert "그날" not in variants["half"]["when"]
    assert variants["full"]["screens"] == ["day-sheet"] and "처음부터" in variants["full"]["note"]
    assert "detent" not in json.dumps(sheet) and "expand" not in json.dumps(sheet)
    layout = _md_section("calendar.md", "### day-sheet 화면 배치")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("day-sheet"))
    order = ["`date-header` `day-sheet`", "`hanja-tag` `emphasis`", "`fortune-verdict`", "`event-row` `list`", "`diary-row` `entries`"]
    assert [layout.index(item) for item in order] == sorted(layout.index(item) for item in order)
    assert "day-character" not in layout and any("요약 문장" in line and "두지 않" in line for line in layout.splitlines())
    assert "`section-header` `action`(`day-sheet.event.title`" in layout  # 일정 섹션 제목 (V97, #859)
    event = next(v for v in component("calendar", "event-row")["variants"] if v["id"] == "list")["parts"]
    assert event["add"] == {"component": "section-header", "variant": "action", "slot": "day-sheet.event.add",
                            "position": "section-header-trailing"}
    entries = next(v for v in component("diary", "diary-row")["variants"] if v["id"] == "entries")["parts"]
    assert entries["head"]["visible"] is False and "section-header" in entries["head"]["note"]


def test_hyeong_glyph():
    # 사용자 결정 2026-11-07: 刑(형)도 한자 아이콘. D108 ② 한자 목록 누락 보완, 사주 용어라 기본 term 톤
    tag = component("sentence", "hanja-tag")
    assert tag["parts"]["glyphs"]["relation"]["刑"] == "형"
    assert any("17자" in rule and "刑" in rule for rule in tag["rules"])
    row = component("calendar", "score-row")
    text = json.dumps(row, ensure_ascii=False)
    assert "pendingGlyphs" not in row["parts"] and "자리값" not in text
    layout = _md_section("calendar.md", "### color-rule-sheet 화면 배치")
    assert "刑 형" in layout and "자리값" not in layout and "자리값" not in (COMPONENTS_DIR / "calendar.md").read_text(encoding="utf-8")
    assert all(f"`{slot}`" in layout for slot in ia_slot_ids("color-rule-sheet"))
    assert "`score-row` `rule`" in layout


# Task 8 리뷰 라운드 1
def test_color_rule_table_tags_are_not_interactive():
    opens = component("sentence", "hanja-tag")["parts"]["opens"]
    assert {"screen": "color-rule-sheet", "part": "score-row rule"} in opens["notInteractiveIn"]
    assert "색 규칙 시트" in opens["notInteractiveRule"]
    md = (COMPONENTS_DIR / "sentence.md").read_text(encoding="utf-8")
    assert "색 규칙 시트 점수 항목 표의 태그" in md
    # rule 줄은 누를 수 없는 표 줄이라 터치 48이 필요 없음: 시안과 같은 값 하나
    rule = next(v for v in component("calendar", "score-row")["variants"] if v["id"] == "rule")["parts"]
    assert rule["row"] == {"minHeight": "none", "paddingY": "{space.8}",
                           "note": "누를 수 없는 표 줄이라 터치 48이 필요 없고, 일곱 줄이 시트 높이를 덜 차지함"}


def test_glyph_table_has_hyeong():
    md = (COMPONENTS_DIR / "sentence.md").read_text(encoding="utf-8")
    assert "| 합충형 | 合(합) 沖(충, 일지 충, 월지 충) 刑(형) |" in md
    assert "합충형" in component("sentence", "hanja-tag")["rules"][0]


def decision_rows():
    """decisions.md 결정 표를 {ID: {열 이름: 칸}}으로. 열은 머리글(| ID | 날짜 | 분류 | 결정 | 근거 |)에서 이름으로 찾습니다.

    칸 안에 표 구분자가 섞여 칸 수가 머리글과 다르면 그 행에서 실패합니다(열을 잘못 읽지 않게).
    """
    lines = (DESIGN_DIR / "decisions.md").read_text(encoding="utf-8").splitlines()

    def cells(line):
        return [cell.strip() for cell in line.strip().strip("|").split("|")]

    header_index = next(index for index, line in enumerate(lines) if line.startswith("|") and cells(line)[0] == "ID")
    names = cells(lines[header_index])
    rows = {}
    for line in lines[header_index + 2:]:
        if not line.startswith("|"):
            break
        values = cells(line)
        assert len(values) == len(names), f"칸 수가 머리글과 다름: {values[0]}"
        rows[values[0]] = dict(zip(names, values))
    return rows


def test_revised_decisions_are_marked():
    rows = {key: row["결정"] for key, row in decision_rows().items()}
    reasons = {key: row["근거"] for key, row in decision_rows().items()}
    assert "2026-11-07 개정" in rows["V10"] and "V84" in rows["V10"]
    assert "2026-11-07 개정" in rows["V42"] and "V85" in rows["V42"]
    assert "2026-11-07 개정" in rows["V84"] and "Q1 ⑤" in rows["V84"]  # 관문 답 리뷰 I1
    assert "2026-11-07 개정" in rows["V87"] and "score-scale을 뺌" in rows["V87"]
    assert reasons["V86"].endswith("사용자 영향: #850(점수 항목 짧은 뜻), #852(IA 막대 세 이름 자리)")  # Task 10: 요청 Issue 번호로
    # 묶음 E(사주 표)가 바꾼 앞 결정 (V88~V92)
    assert "2026-11-07 개정" in rows["V49"] and "V89" in rows["V49"]
    assert "2026-11-07 개정" in rows["V53"] and "V89" in rows["V53"]
    assert "2026-11-07 개정" in rows["V72"] and "V89" in rows["V72"]
    assert "2026-11-07 개정" in rows["V77"] and "V90" in rows["V77"]
    assert "2026-11-07 개정" in rows["V80"] and "V92" in rows["V80"]


def test_tone_example_words_are_four_levels():
    md = (COMPONENTS_DIR / "elements.md").read_text(encoding="utf-8")
    section = md.split("## 길흉 톤 `tone`", 1)[1].split("\n## ", 1)[0]
    assert "좋은 날" not in section and "아주 잘 풀리는 날" in section and "무난한 날" in section


# 관문 답 리뷰: 시안과 비교 페이지에 쓰지 않는 척도 CSS나 인라인 색이 없음
def test_screen_d_has_no_scale_leftovers():
    screen = (DESIGN_DIR / "artifacts" / "2026-11-05-ds1-screen-d.html").read_text(encoding="utf-8")
    assert ".rs-head" not in screen and ".scale" not in screen and ".sc " not in screen and "score-scale" not in screen
    questions = (DESIGN_DIR / "artifacts" / "2026-11-06-ds1-d-questions.html").read_text(encoding="utf-8")
    picked = questions.split("고름(2026-11-07): 합치지 않음", 1)[1].split("</section>", 1)[0]
    assert "#" not in re.sub(r"&#\w+;", "", picked.split("<div class=\"options\">", 1)[1]).replace('href="#', "")


def test_removal_constant_follows_pending():
    source = (TOOLS_DIR / "components.py").read_text(encoding="utf-8")
    assert source.index("IA_PENDING_COMPONENTS = frozenset") < source.index("IA_REMOVAL_REQUESTED = frozenset")


# DS1 2단계 묶음 E: 사주 표 (spec §1, §4, 결정 V88~V92)
def test_pending_list_empty():
    # 묶음마다 줄여 온 IA 대기 목록이 마지막 묶음 E로 비어야 함 (spec §5)
    assert components.IA_PENDING_COMPONENTS == frozenset()
    problems = find_problems(load_documents(COMPONENTS_DIR), json.loads(IA_PATH.read_text(encoding="utf-8")),
                             token_names_by_theme(TOKENS_DIR))
    assert [problem for problem in problems if "명세가 없음" in problem] == []
    assert "IA_PENDING_COMPONENTS = frozenset()" in (TOOLS_DIR / "components.py").read_text(encoding="utf-8")


def test_birth_info_row():
    row = component("saju", "birth-info-row")
    parts = row["parts"]
    # origin과 IA 역할 문장대로 칸 셋(달력 종류 + 날짜, 시진 태그 + 시간, 성별). spec의 "칸 넷"은 V88로 정정
    assert parts["cells"]["order"] == ["date", "hour", "gender"]
    assert "칸 단위" in parts["cells"]["wrap"] and parts["cells"]["rowGap"] == "{space.8}"
    divider = parts["divider"]
    assert divider["width"] == {"value": 1, "unit": "px"} and divider["height"] == {"value": 16, "unit": "px"}
    assert divider["color"] == "{color.line}" and divider["marginX"] == "{space.12}"
    assert "줄이 바뀐 칸 앞" in divider["note"]
    date = parts["date"]
    assert date["calendarKind"]["type"] == "{type.caption.sm}" and date["calendarKind"]["radius"] == "{radius.xs}"
    assert "윤달" in date["calendarKind"]["source"]
    hour = parts["hour"]
    assert (hour["tag"]["component"], hour["tag"]["variant"]) == ("hanja-tag", "ganji") and hour["tag"]["interactive"] is False
    pill = parts["pill"]
    assert pill["bg"] == "transparent" and pill["border"]["color"] == "{color.tag.neutral.border}"
    assert pill["fg"] == "{color.tag.neutral.fg}" and pill["radius"] == "{radius.full}"
    assert parts["gender"] == {"use": "pill", "source": "프로필 성별", "copy": "writing 새 슬롯(성별 한 낱말)"}
    unknown = row["states"]["time-unknown"]["parts"]["hour"]
    assert unknown["tag"] == {"visible": False} and unknown["value"] == {"visible": False}
    assert unknown["unknown"]["use"] == "pill" and "시간 모름" in unknown["unknown"]["copy"]
    assert "skeleton" in row["states"]["loading"]
    text = json.dumps(row, ensure_ascii=False)
    assert not {"join", "separator"} & set(parts) and "쉼표" in " ".join(row["rules"])  # 칸 사이는 글자 없이 세로선
    assert "coral" in " ".join(row["rules"])  # 성별을 톤 색으로 나누지 않음(Q4)
    assert "·" not in text
    assert row["a11y"]["dividersDecorative"] is True and row["a11y"]["textScaleMax"] == 1.3


def test_band_table():
    table = component("saju", "band-table")
    parts = table["parts"]
    columns = parts["columns"]
    assert columns["order"] == ["hour", "day", "month", "year"]
    divider = columns["divider"]
    assert divider["width"] == "{border.width.hairline}" and divider["color"] == "{color.line}"
    assert "모든 띠를 관통" in divider["span"]
    day = parts["dayColumn"]
    assert day["bg"] == "{color.highlight.bg}" and "opacity" not in day  # V93: 회색이라 옅게 깔지 않음
    assert (day["header"]["fg"], day["header"]["fontWeight"]) == ("{color.action.primary}", 700) and day["me"]["element"] == "tag.me"
    band_header = parts["bandHeader"]
    assert band_header["span"] == "네 열" and band_header["bg"] == "{color.bg.sheet}"
    assert band_header["border"] == {"top": {"width": "{border.width.hairline}", "color": "{color.line}"},
                                     "bottom": {"width": "{border.width.hairline}", "color": "{color.line}"}}
    assert (band_header["label"]["component"], band_header["label"]["variant"]) == ("term-token", "label")
    assert band_header["opens"]["sheet"] == "explain-sheet"
    assert band_header["opens"]["bodySlots"] == {"hiddenStems": "saju-chart.jijanggan.desc",
                                                 "twelveStages": "saju-chart.unseong.desc", "shinsal": "saju-chart.sinsal.desc"}
    assert set(band_header["opens"]["bodySlots"].values()) <= ia_slot_ids("saju-chart")
    assert band_header["opens"]["stageStrip"] == ["twelveStages"]
    bands = parts["bands"]
    assert bands["order"] == ["hiddenStems", "twelveStages", "shinsal"]
    assert bands["hiddenStems"]["item"]["chip"] == {"element": "stem.chip"}
    assert (bands["twelveStages"]["component"], bands["twelveStages"]["variant"]) == ("term-token", "label")
    assert bands["shinsal"]["whenEmpty"] == "empty" and bands["shinsal"]["stack"]["direction"] == "vertical"
    empty = parts["empty"]  # 신살 빈 칸: "-" 글자 대신 짧은 가로선 12×1 (모양 값만 고정, 리뷰 Minor 8)
    assert (empty["shape"], empty["width"], empty["height"], empty["color"]) == (
        "line", {"value": 12, "unit": "px"}, {"value": 1, "unit": "px"}, "{color.text.secondary}")
    assert "stem.chip" in table["uses"] and "tag.me" in table["uses"] and "term" in table["uses"]
    assert table["states"]["time-unknown"]["parts"]["columns"]["hour"] == "모든 띠가 empty"
    assert "skeleton" in table["states"]["loading"] and table["a11y"]["role"] == "table"


def test_stem_chip_uses_ohaeng_cell_colors():
    elements = load_documents(COMPONENTS_DIR)["elements"]["elements"]
    chip, cell = elements["stem.chip"], elements["ohaeng.cell"]
    assert chip["colors"] == "ohaeng.cell" and chip["radius"] == cell["radius"]
    assert set(cell["byElement"]) == {"wood", "fire", "earth", "metal", "water"}
    assert all(value == {"bg": f"{{color.ohaeng.{element}.bg}}", "fg": f"{{color.ohaeng.{element}.fg}}"}
               for element, value in cell["byElement"].items())
    # 원국 칸(saju-pillars)과 대운 칸(luck-pillar)은 ohaeng.cell 자체라 stem.chip을 쓰지 않음 (결정 V89)
    assert chip["where"] == ["band-table 지장간 칸"] and "saju-pillars" in chip["notFor"] and "luck-pillar" in chip["notFor"]
    for component_id in ("saju-pillars", "luck-pillar"):
        assert "stem.chip" not in json.dumps(component("saju", component_id))
    stem_chip_users = {c["id"] for c in all_components() if "stem.chip" in c.get("uses", [])}
    assert stem_chip_users == {"band-table"}


def test_stage_strip():
    strip = component("saju", "stage-strip")
    parts = strip["parts"]
    assert parts["stages"]["order"] == ["jangsaeng", "mokyok", "gwandae", "geonrok", "jewang", "soe", "byeong", "sa",
                                        "myo", "jeol", "tae", "yang"]
    track = parts["track"]
    assert track["cellHeight"] == {"value": 6, "unit": "px"} and track["gap"] == "{space.2}"
    assert track["fill"] == "{color.line}" and track["mine"] == "{color.action.primary}"
    marker = parts["marker"]
    assert marker["shape"] == "circle" and marker["bg"] == "{color.action.primary}" and marker["fg"] == "{color.action.on-primary}"
    assert list(marker["labels"]) == ["hour", "day", "month", "year"]
    assert marker["sameStage"]["order"] == ["hour", "day", "month", "year"]
    names = parts["names"]
    assert names["type"] == "{type.caption.sm}" and names["fg"] == "{color.text.secondary}" and names["maxLines"] == 1
    assert "내 자리 칸의 이름만" in names["overflow"]
    assert strip["states"]["time-unknown"]["parts"]["marker"] == {"hour": "그리지 않음"}
    assert "skeleton" in strip["states"]["loading"]
    # 예시는 하늘님 값(월주 장생, 연주 목욕, 시주 관대, 일주 양) (리뷰 Minor 1)
    example = "장생, 월주 / 목욕, 연주 / 관대, 시주 / 양, 일주"
    assert strip["a11y"]["role"] == "img" and example in strip["a11y"]["label"] and "월주와 연주" not in strip["a11y"]["label"]
    assert example in (COMPONENTS_DIR / "saju.md").read_text(encoding="utf-8")
    v91 = decision_rows()["V91"]["결정"]
    assert example in v91 and "월주와 연주" not in v91
    spec_line = next(line for line in (DESIGN_DIR / "specs" / "2026-11-05-ds1-screens-design.md").read_text(encoding="utf-8").splitlines()
                     if line.startswith("* `stage-strip`"))
    assert "2026-11-07 정정" in spec_line
    sheet = component("frame", "explain-sheet")["parts"]["stageStrip"]
    assert sheet["component"] == "stage-strip" and sheet["marginTop"] == "{space.12}"
    assert "12운성 띠 머리" in sheet["when"]


def test_scroll_hint():
    hint = component("frame", "scroll-hint")
    parts = hint["parts"]
    fade = parts["fade"]
    assert fade["width"] == {"value": 24, "unit": "px"} and fade["to"] == "{color.bg.sheet}" and fade["side"] == "더 있는 쪽 끝만"
    arrows = parts["arrows"]
    for side, name in (("start", "caret-double-left"), ("end", "caret-double-right")):
        assert arrows[side] == {"icon": name, "weight": "light", "size": "{size.icon.16}", "color": "{color.text.secondary}"}
    assert arrows["hiddenWhenNoMore"] is True and arrows["minTarget"] == 44 and arrows["marginTop"] == "{space.4}"
    assert "label" not in arrows and "copy" not in json.dumps(hint)  # 글자 안내 없음
    states = hint["states"]
    assert states["atStart"]["parts"]["arrows"]["start"] == {"visible": False}
    assert states["atEnd"]["parts"]["arrows"]["end"] == {"visible": False}
    assert states["pressed"]["pattern"] == "press.ink"
    # 동작 줄이기: 흐림과 화살표는 바로 바뀌고, 화살표로 넘길 때 움직임 없이 그 자리
    reduce = hint["motion"]["reduceMotion"]
    assert "바로" in reduce and "움직임 없이" in reduce
    assert hint["a11y"]["scrollerRole"] == "list" and hint["a11y"]["arrowsHidden"] is True


def test_manse_and_daeun_tables_follow_ia_v5():
    # IA v5: manse-table은 band-table로 그리는 만세력 표, daeun-table은 luck-pillar 줄 + scroll-hint
    manse = component("saju", "manse-table")
    assert manse["parts"]["table"] == {"component": "band-table", "bands": ["hiddenStems", "twelveStages", "shinsal"]}
    basis = manse["parts"]["basis"]
    assert basis["slot"] == "saju-chart.manse.basis" and basis["params"] == ["stem"] and "saju-chart.manse.basis" in ia_slot_ids("saju-chart")
    assert basis["fg"] == "{color.text.secondary}" and "term" not in json.dumps(basis)  # 누르는 용어 칩과 헷갈리지 않게 글자
    for gone in ("grid", "rowHeader", "top", "hiddenStems"):
        assert gone not in manse["parts"]
    daeun = component("saju", "daeun-table")
    parts = daeun["parts"]
    assert parts["rows"]["order"] == ["daeun", "seun"]
    assert parts["row"]["hint"] == {"component": "scroll-hint"} and parts["row"]["scroll"] == "horizontal"
    assert parts["row"]["gap"] == "{space.4}"
    assert "grid" not in parts["seun"] and "5×2" in parts["seun"]["note"]
    assert "위아래로 맞음" not in parts["seun"]["note"] and "따로 넘김" in parts["seun"]["note"]  # 리뷰 Minor 3
    assert parts["rows"]["header"]["component"] == "section-header"
    slots = {slot for pair in parts["rows"]["header"]["slots"].values() for slot in pair}
    assert slots == {"saju-chart.daeun.title", "saju-chart.daeun.desc", "saju-chart.seun.title", "saju-chart.seun.desc"}
    assert slots <= ia_slot_ids("saju-chart")
    assert any("처음 열 때" in rule for rule in daeun["rules"])


def test_luck_pillar_current_tag_outside_highlight():
    # 관문 질문 Q1(권장 ①): 꼬리표(tag.status)와 강조 바탕이 같은 status.bg라 꼬리표는 바탕 밖 아래 줄 (결정 V90)
    pillar = component("saju", "luck-pillar")
    tag = pillar["parts"]["currentTag"]
    assert tag["outsideHighlight"] is True and "바탕 밖" in tag["position"]
    assert pillar["parts"]["container"]["highlightCovers"] == ["topLabel", "stemTenGod", "stem", "branch", "branchTenGod",
                                                              "twelveStage", "startYear"]
    elements = load_documents(COMPONENTS_DIR)["elements"]["elements"]
    # Q4 ③(V93): 강조 바탕은 회색이라 sage 꼬리표와 다름. 자리는 Q1 ① 그대로
    highlight = elements["highlight.current"]
    assert highlight["bg"] == "{color.highlight.bg}" and elements["tag.status"]["bg"] != highlight["bg"]
    assert "옅은 sage" not in highlight["summary"] and "회색" in highlight["summary"] and highlight["onlyOn"] == "{color.bg.sheet}"
    assert any("Q1" in rule and "꼬리표" in rule for rule in pillar["rules"])
    saju = json.dumps(load_documents(COMPONENTS_DIR)["saju"], ensure_ascii=False)
    assert "같은 sage" not in saju and "같은 status.bg" not in saju
    assert "같은 sage" not in (COMPONENTS_DIR / "saju.md").read_text(encoding="utf-8")
    assert "그리지 않음" in pillar["parts"]["branchTenGod"]["seun"]


def test_screen_e_sample():
    page = (DESIGN_DIR / "artifacts" / "2026-11-05-ds1-screen-e.html").read_text(encoding="utf-8")
    for needed in ("원국", "만세력과 대운", "시간 모름", "12운성", "caret-double-right", "stem-chip", "dark"):
        assert needed in page, needed
    assert ".arrows button { width: 44px; height: 44px;" in page  # 명세 minTarget 44 (리뷰 Minor 4)
    entries = {entry["id"]: entry for entry in json.loads((DESIGN_DIR / "artifacts" / "index.json").read_text(encoding="utf-8"))}
    # 관문 모두 끝남(Q1~Q4, 2026-11-07): 다른 확정 시안과 같은 chosen
    assert entries["design-ds1-screen-e"]["status"] == "chosen" and "사용자 확인 대기" not in entries["design-ds1-screen-e"]["note"]
    assert "--color-highlight-bg" in page and "opacity: 0.35" not in page
    # 관문 답(2026-11-07): Q1 ①, Q2 ②, Q3 ① 확정. 새 질문 Q4(강조 바탕 회색)는 답 대기
    assert entries["design-ds1-e-questions"]["kind"] == "concept" and entries["design-ds1-e-questions"]["status"] == "chosen"
    assert "Q1 ①" in entries["design-ds1-e-questions"]["note"] and "Q3 ①" in entries["design-ds1-e-questions"]["note"]
    questions = (DESIGN_DIR / "artifacts" / "2026-11-07-ds1-e-questions.html").read_text(encoding="utf-8")
    assert questions.count("고름(2026-11-07)") == 3
    q4 = entries["design-ds1-e-q4-highlight"]
    assert (q4["kind"], q4["status"], q4["file"]) == ("concept", "chosen", "2026-11-07-ds1-e-q4-highlight.html")
    q4_page = (DESIGN_DIR / "artifacts" / "2026-11-07-ds1-e-q4-highlight.html").read_text(encoding="utf-8")
    assert 'href="ds1/tokens.css"' in q4_page and 'data-theme="dark"' in q4_page and "권장" in q4_page
    assert [char for char in ("—", "–", "·") if char in q4_page] == []
    rows = decision_rows()
    for key in ("V88", "V89", "V90", "V91", "V92"):
        assert "사용자 확인 대기" not in rows[key]["근거"] and "관문 답 2026-11-07" in rows[key]["근거"], key
    assert q4_page.count("고름(2026-11-07)") == 1
    for key in ("V89", "V90"):
        assert "답 대기" not in rows[key]["근거"] and "V93" in rows[key]["결정"] and "V93" in rows[key]["근거"], key
    assert "Q4 ③" in rows["V93"]["결정"] and "color.highlight.bg" in rows["V93"]["결정"] and "1.4.0" in rows["V93"]["결정"]
    assert rows["V93"]["근거"].endswith("app 반영은 #851(토큰 1.4.0 `color.highlight.bg`). 사용자 영향: 없음")  # D87: app 구현만 바뀜(V92와 같음)


# 리뷰 Minor 2: 지운 부품(manse-table 격자선, 행 머리)을 가리키는 문장이 남지 않음
def test_removed_saju_parts_not_referenced():
    elements_md = (COMPONENTS_DIR / "elements.md").read_text(encoding="utf-8")
    assert "grid.divider" not in elements_md
    divider = elements_md.split("## 목록 구분선 `list.divider`", 1)[1].split("\n## ", 1)[0]
    assert "band-table" in divider and "birth-info-row" in divider
    for name in ("elements.md", "sentence.md", "sentence.json"):
        assert "표 행 머리" not in (COMPONENTS_DIR / name).read_text(encoding="utf-8"), name
    assert "행 머리·십성" not in (COMPONENTS_DIR / "saju.md").read_text(encoding="utf-8")
    cell_row = next(line for line in elements_md.splitlines() if line.startswith("| `ohaeng.cell`"))
    assert "만세력 표" not in cell_row


# Q4 ③(V93) 뒤 결정 본문에 "같은 sage라 묻힘" 근거가 남지 않음. 옛 근거는 개정 괄호에만 (리뷰 Important 1, 2)
def test_highlight_reasons_are_current():
    rows = {key: row["결정"] for key, row in decision_rows().items()}
    for key in ("V77", "V89", "V90"):
        body = rows[key].split(" (2026-11-07 개정:", 1)[0]
        assert "묻" not in body and "status.bg" not in body, key
        assert "V93" in rows[key].split(" (2026-11-07 개정:", 1)[1], key
    assert "V53" in rows["V90"].split(" (2026-11-07 개정:", 1)[0] and "Q1 ①" in rows["V90"]
    assert "회색이라 sage 용어 칩과 갈림" in rows["V89"]
    saju_md = (COMPONENTS_DIR / "saju.md").read_text(encoding="utf-8")
    compact_line = next(line for line in saju_md.splitlines() if line.startswith("* **`compact`"))
    assert "묻" not in compact_line and "가릴 것이 없어" in compact_line


# DS1 2단계 Task 10: 컴포넌트 계약 5.0.0 판 기록과 정리 (#801)
REMOVED_IN_5_0 = (
    "`section.header`", "`explain.sheet`", "`innerBorder`", "`explainSheet.container`", "`open.chevron`",
    "`score-scale`", "`tag`", "`mini`", "`badge`", "`currentLabel`", "`rowHeader`", "`seun.grid`",
    "`legend.optional`", "`failed.add`", "`lock.veil.lines.default`",
    # 리뷰 1회차: origin/main 대비 경로 전수 비교로 더 찾은 것
    "`seun.stemTenGod`", "`seun.year`", "`daeun-table` `a11y.cellLabel`", "`manse-table` `a11y.cellLabel`",
    "`states.time-unknown.parts.grid`", "`segments.term.screens`의 `day-sheet`", "뼈 `badge`",
)


def _readme_row(version):
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    return next(line for line in readme.splitlines() if line.startswith(f"| {version} |"))


def test_readme_records_5_0_removals_and_renames():
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    row = _readme_row("5.0.0")  # 머리의 기대 판은 6.0.0 (test_readme_records_6_0_removal)
    removed = row.split("**지움**", 1)[1].split("**더함**", 1)[0]
    for name in REMOVED_IN_5_0:
        assert name in removed, name
    assert "`innerBorder` → `border`" in row and "자물쇠" in row
    assert "`keyboard.dismiss`" in row.split("**더함**", 1)[1]
    changed = row.split("**바뀜**", 1)[1]
    assert "`manse-table` `a11y.role` `table` → `group`" in changed
    assert "`daeun-table` `a11y.role` `table` → `list`" in changed
    assert "`tag-chip` `a11y.role` `link` → `button`" in changed
    # 재리뷰 Minor: 뼈 목록과 잠금 자리값 구조
    assert "`manse-table` `states.loading.skeleton`" in changed and "`band-table` 뼈" in changed
    assert "`daeun-table` `states.loading.skeleton`" in changed and "`luck-pillar` 뼈" in changed
    assert "`lock.veil.placeholder` 문자열 → 객체" in changed
    for decision in ("V69", "V93"):
        assert decision in row
    assert "토큰 1.4.0 이상" in row and "주 버전" in row


def _token_contract_version():
    readme = (DESIGN_DIR / "tokens" / "README.md").read_text(encoding="utf-8")
    return re.search(r"^계약 버전: (\d+\.\d+\.\d+)$", readme, re.M).group(1)


def test_contract_list_rows_name_current_versions():
    # 판 문자열은 VERSION과 토큰 README에서 읽습니다. 판을 올릴 때 고칠 곳은 test_contract_version_is_* 한 곳
    contracts = (DESIGN_DIR.parents[2] / "docs" / "contracts" / "README.md").read_text(encoding="utf-8")
    component_row = next(line for line in contracts.splitlines() if line.startswith("| 컴포넌트 명세 |"))
    token_row = next(line for line in contracts.splitlines() if line.startswith("| 디자인 토큰 "))
    assert f"| {VERSION} |" in component_row and f"| {_token_contract_version()} |" in token_row
    for name in ("color.ohaeng.metal.border", "color.ohaeng.water.border", "color.ohaeng.<오행>.glyph"):
        assert name in token_row.split("1.5.0:", 1)[1], name
    documents = load_documents(COMPONENTS_DIR)
    specified = sum(len(documents[name]["components"]) for name in components.GROUPS)
    elements_count = len(documents["elements"]["elements"])
    patterns = len(documents["interaction"]["patterns"])
    tail = component_row.split(f"{VERSION}:", 1)[1]
    assert f"IA 컴포넌트 {specified}개" in tail and f"요소 {elements_count}개" in tail and f"패턴 {patterns}개" in tail
    assert "IA 컴포넌트 43개" not in tail and "57개" not in tail  # 앞 판 문장의 옛 숫자를 옮기지 않음
    for name in ("color.calendar.level", "color.fill.soft", "color.verdict.track", "color.highlight.bg"):
        assert name in token_row.split("1.4.0:", 1)[1], name


def test_unused_ohaeng_cell_mini_is_removed():
    cell = load_documents(COMPONENTS_DIR)["elements"]["elements"]["ohaeng.cell"]
    assert set(cell["sizes"]) == {"pillar", "small"}
    for name in ("elements.md", "sentence.md"):
        assert "mini" not in (COMPONENTS_DIR / name).read_text(encoding="utf-8"), name


def test_ganji_rule_names_table_path():
    tag = component("sentence", "hanja-tag")
    rule = next(rule for rule in tag["rules"] if "ganjiGlyphs" in rule)
    assert "변형 ganji의 parts.ganjiGlyphs" in rule
    ganji = next(v for v in tag["variants"] if v["id"] == "ganji")
    assert "ganjiGlyphs" in ganji["parts"]


def test_v70_body_states_current_glyph_count():
    row = decision_rows()["V70"]
    body = row["결정"].split("(2026-11-07 개정:", 1)[0]
    assert "17자" in body and "刑" in body and "16자" not in body and "넣지 않습니다" not in body
    assert "16자" in row["결정"].split("(2026-11-07 개정:", 1)[1]  # 옛 값은 개정 괄호에만
    assert "17자 규칙" in row["근거"] and "16자 규칙" not in row["근거"]


def test_keyboard_dismiss_element_is_recorded():
    elements_md = (COMPONENTS_DIR / "elements.md").read_text(encoding="utf-8")
    assert "`keyboard.dismiss`" in elements_md
    for name in ("input.md", "diary.md"):
        assert "`keyboard.dismiss`" in (COMPONENTS_DIR / name).read_text(encoding="utf-8"), name


def test_screen_b_has_no_zero_legend_leftover():
    sample = (DESIGN_DIR / "artifacts" / "2026-11-05-ds1-screen-b.html").read_text(encoding="utf-8")
    assert ".zero" not in sample and 'class="zero"' not in sample


# D112(#801 지휘 2026-11-06): 대표 태그가 없는 날. 사주 기운 섹션은 제목과 한 줄, 총운은 헤드라인만, 질문은 십성 묶음
def test_today_featured_empty_day():
    layout = _md_section("today.md", "### today 화면 배치")
    lines = layout.splitlines()
    empty_line = next(line for line in lines if "`today.featured.empty`" in line)
    # 새 값 없이 사주 기운 시트 빈 안내(tag-sentence-list empty)와 같은 글자 스타일
    empty = component("today", "tag-sentence-list")["parts"]["empty"]
    assert (empty["type"], empty["fg"]) == ("{type.body.ui}", "{color.text.secondary}")
    assert "`type.body.ui` `text.secondary`" in empty_line and "`tag-sentence-list` `empty`" in empty_line
    assert "섹션 전체를 그리지 않습니다" not in layout
    rule = next(line for line in lines if line.startswith("* 대표 태그가 없는 날(D112"))
    for words in ("헤드라인만", "`list.divider`", "보조 문장", "일진 십성 묶음 질문", "제목은 그대로"):
        assert words in rule, words
    assert "today.fortune.body" in rule and "결정 태그 줄" in rule  # 리뷰 1회차 Ruling: 근거는 IA 보조 문장 role
    row = decision_rows()["V95"]
    assert "today.fortune.body" in row["결정"] and "결정 태그 줄" in row["결정"]
    assert "D112" in row["결정"] and "today.featured.empty" in row["결정"] and row["근거"].endswith("app 반영은 #851. 사용자 영향: #850(대표 태그 없는 날 한 줄 상한)")
    assert "`today.featured.empty`" in _readme_row("5.0.0")
    sample = (DESIGN_DIR / "artifacts" / "2026-11-05-ds1-screen-a-g.html").read_text(encoding="utf-8")
    assert "대표 태그 없는 날" in sample and '<p class="tsl-empty">오늘은 두드러진 사주 기운이 없어요.</p>' in sample


# 우려 4 Ruling: 초안 상태는 상단 바 가운데 정렬이라 양쪽 같은 폭을 비운 가운데 폭으로 잼
def test_draft_indicator_is_centered():
    container = component("diary", "draft-indicator")["parts"]["container"]
    assert container["align"] == "center" and "88" in container["width"]
    rules = " ".join(component("diary", "draft-indicator")["rules"])
    assert "가운데 정렬" in rules and "뒤로와 저장 글자 버튼 사이 폭" not in rules


# 최종 리뷰 Ruling: D87 사용자 영향은 루트 기록 반영 대상(writing 원고)만. app 반영은 근거 칸에 참고로
def test_contract_rows_user_impact_is_writing_only():
    rows = decision_rows()
    for key in ("V94", "V95"):
        impact = rows[key]["근거"].split("사용자 영향: ", 1)[1]
        assert impact.startswith("#850") and "#851" not in impact, key
        assert "app 반영은 #851" in rows[key]["근거"], key


# #859 drift(D113, IA에서 tag-chip, score-scale을 뺌): 컴포넌트 계약 6.0.0 (결정 V96)
def test_tag_chip_removed_for_hanja_tag():
    assert "tag-chip" not in {c["id"] for c in all_components()}
    for name in ("diary.md", "elements.md", "sentence.md"):
        assert "tag-chip" not in (COMPONENTS_DIR / name).read_text(encoding="utf-8"), name
    for path in (COMPONENTS_DIR / "README.md", COMPONENTS_DIR / "feedback.md", COMPONENTS_DIR / "frame.md",
                 DESIGN_DIR / "visual-identity.md", DESIGN_DIR / "tokens" / "color.light.tokens.json",
                 DESIGN_DIR / "tokens" / "color.dark.tokens.json", TOOLS_DIR / "tokens.py"):
        assert "태그 칩" not in path.read_text(encoding="utf-8"), path.name  # 리뷰 M1, M2, M4
    editor = component("diary", "diary-editor")
    assert not any("칩" in rule for rule in editor["rules"])
    screens = next(line for line in _md_section("sentence.md", "## hanja-tag").splitlines() if line.startswith("* 쓰는 화면"))
    assert "diary-edit" in screens and "tag-diary" in screens


def test_readme_records_6_0_removal():
    row = _readme_row("6.0.0")
    assert "`tag-chip`" in row.split("**지움**", 1)[1] and "V96" in row and "#859" in row


def test_time_unknown_notice_shares_saju_chart_key():
    # IA DS1: 오늘, 나 탭의 시간 모름 안내 문구는 사주 표 saju-chart.time-unknown.notice와 같은 키
    banner = next(v for v in component("feedback", "notice-banner")["variants"] if v["id"] == "time-unknown")
    assert banner["parts"]["text"] == {"slot": "saju-chart.time-unknown.notice"}
    assert "saju-chart.time-unknown.notice" in _md_section("today.md", "### today 화면 배치")


# 6.1.1 (#908, 결정 V99): 공유 이미지 로고는 새 아이콘 PNG 가로 조합
def test_share_image_logo_is_raster_lockup():
    logo = component("today", "share-image")["parts"]["logo"]
    assert logo["asset"] == "logo/lockup.png"
    assert (DESIGN_DIR / logo["asset"]).exists()
    row = _readme_row("6.1.1")
    assert "V99" in row and "#908" in row and "`logo/lockup.png`" in row


def test_readme_header_names_current_versions():
    readme = (COMPONENTS_DIR / "README.md").read_text(encoding="utf-8")
    assert f"컴포넌트 계약 {VERSION} · 토큰 계약 {_token_contract_version()} 이상을 기대합니다." in readme


# 6.1.0 (#892, D114, 결정 V98): 금 흰색, 수 먹색
def test_readme_records_6_1_ohaeng_borders():
    row = _readme_row("6.1.0")
    assert "V98" in row and "#892" in row and "**지움**" not in row
    for name in ("`ohaeng.cell` `border`", "`pill.border`", "`bar.segmentBorder`", "color.ohaeng.<오행>.glyph"):
        assert name in row, name


def test_ohaeng_cell_border_only_for_metal_and_water():
    cell = load_documents(COMPONENTS_DIR)["elements"]["elements"]["ohaeng.cell"]
    assert cell["border"]["byElement"] == {
        "metal": "{color.ohaeng.metal.border}", "water": "{color.ohaeng.water.border}"}
    assert cell["border"]["width"] == {"value": 1, "unit": "px"} and cell["border"]["placement"] == "inside"
    chip = load_documents(COMPONENTS_DIR)["elements"]["elements"]["stem.chip"]
    assert "border" in chip["colorsRule"]  # 지장간 칩도 금과 수 테두리를 따름


def test_ohaeng_bar_segments_have_swatch_border():
    bar = component("saju", "ohaeng-bar")["parts"]["bar"]
    assert bar["segmentBorder"]["color"] == "{color.swatch.border}"
    assert any("swatch.border" in rule for rule in component("saju", "ohaeng-bar")["rules"])
    assert "swatch.border" in _md_section("saju.md", "## ohaeng-bar")


# 6.2.0 검수 회차2 묶음 (결정 V100~V106)
def test_v100_outside_tap_closes_one_sheet():
    rules = component("frame", "sheet")["rules"]
    assert any("바깥 누르기는 모두 맨 위 시트 하나만" in rule and "V100" in rule for rule in rules)
    assert not any("모두 닫는다" in rule for rule in rules)
    assert "쌓인 시트 모두 닫힘" not in (COMPONENTS_DIR / "frame.md").read_text(encoding="utf-8")


def test_v101_band_table_empty_line_centers_in_line_box():
    empty = component("saju", "band-table")["parts"]["empty"]
    assert (empty["width"], empty["height"]) == ({"value": 12, "unit": "px"}, {"value": 1, "unit": "px"})
    assert empty["verticalAlign"] == "box-center" and empty["box"]["offsetTop"] == "{space.8}"
    heights = empty["box"]["heightByBand"]
    assert set(heights) == {"twelveStages", "shinsal", "hiddenStems"}
    assert heights["hiddenStems"]["value"] == 22 and "label" in heights["shinsal"] and "label" in heights["twelveStages"]
    assert "V101" in empty["note"]


def test_v102_guide_question_remove_and_detached_prompt():
    editor = component("diary", "diary-editor")
    assert editor["parts"]["question"]["quoteLine"]["color"] == "{color.action.primary}"
    question = next(v for v in editor["variants"] if v["id"] == "edit")["parts"]["question"]
    remove, detached = question["remove"], question["detached"]
    assert (remove["slot"], remove["icon"], remove["weight"], remove["minTarget"]) == (
        "diary-edit.guide.remove", "x", "light", 44)
    assert detached["slot"] == "diary-edit.guide.attach" and detached["fg"] == "{color.invite.fg}"
    assert detached["quoteLine"] == {"visible": False} and detached["paddingStart"] == 0
    assert detached["trailingIcon"]["icon"] == "chat-teardrop-dots"
    assert detached["trailingIcon"]["color"] == "{color.invite.fg}" and detached["trailingIcon"]["decorative"] is True
    assert detached["fontSize"] == {"value": 14, "unit": "px"} and detached["trailingIcon"]["gap"] == "{space.4}"
    assert detached["minTarget"] == 44 and detached["transition"] == {"out": "disappear.seep", "in": "appear.seep"}
    assert (remove["size"], remove["color"]) == ("{size.icon.20}", "{color.text.secondary}")
    states = question["guideStates"]
    assert [(t["from"], t["to"]) for t in states["transitions"]] == [("attached", "detached"), ("detached", "attached")]
    assert "그리지 않는다" in states["whenNoQuestion"] and "키보드는 그대로" in states["focus"]
    # 옛 세로선 표현이 규칙 문장에 다시 들어오지 않게
    assert "term.bg 선" not in json.dumps(editor, ensure_ascii=False)
    assert "disappear.seep" in editor["uses"]
    for name in ("x", "chat-teardrop-dots", "warning-circle"):
        assert name in (TOOLS_DIR / "phosphor_names.txt").read_text(encoding="utf-8").split(), name


def test_v103_diary_row_shows_all_tags_in_one_scrolling_line():
    tag = component("diary", "diary-row")["parts"]["tag"]
    assert tag["count"] == "all" and tag["row"]["lines"] == 1 and tag["row"]["wrap"] is False
    hint = tag["row"]["hint"]
    assert (hint["component"], hint["parts"], hint["fadeTo"]) == (
        "scroll-hint", {"arrows": {"visible": False}}, "{color.bg.sheet}")
    assert "scroll-hint.parts.fade.width" in hint["note"]
    assert "#933" in tag["source"] and tag["gap"] == "{space.8}" and tag["order"] == "대표 태그 순위"
    row_text = json.dumps(component("diary", "diary-row"), ensure_ascii=False)
    assert "대표 태그 하나" not in row_text
    diary_md = (COMPONENTS_DIR / "diary.md").read_text(encoding="utf-8")
    assert "`hiddenScope`" in diary_md and "그 줄 안에서 가로로 밀고" in diary_md


def test_v104_tab_switch_is_short_cross_fade():
    pattern = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]["tab.switch"]
    assert (pattern["duration"], pattern["easing"]) == ("{motion.duration.short}", "{motion.easing.standard}")
    assert pattern["outgoing"] == {"opacity": [1, 0]} and pattern["incoming"] == {"opacity": [0, 1]}
    assert pattern["together"] is True and pattern["movement"] == "none"
    assert (pattern["reduceMotion"], pattern["lowEnd"]) == ("opacity-only", "same")
    assert "새 화면만" in pattern["inputDuring"] and "다시 200ms" in pattern["interrupt"]
    primitive = json.loads((DESIGN_DIR / "tokens" / "primitive.tokens.json").read_text(encoding="utf-8"))
    assert primitive["motion"]["duration"]["short"]["$value"] == {"value": 200, "unit": "ms"}
    tab_bar = component("frame", "tab-bar")
    assert "tab.switch" in tab_bar["uses"] and any("V104" in rule for rule in tab_bar["rules"])
    page_push = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]["page.push"]
    assert "tab.switch" in page_push["scope"]


def test_v106_bottom_buttons_sit_16_above_system_inset():
    step = component("input", "input-step")["parts"]
    assert step["bottomAction"]["paddingBottom"] == "{space.16}" and "inset" in step["bottomAction"]["paddingBottomFrom"]
    secondary = step["secondaryAction"]
    assert (secondary["component"], secondary["variant"], secondary["marginTop"]) == (
        "primary-button", "quiet", "{space.16}")
    assert any("V106" in rule for rule in component("action", "primary-button")["rules"])
    assert "secondaryAction 아래" in step["bottomAction"]["paddingBottomAppliesTo"]
    assert secondary["paddingX"] == step["bottomAction"]["paddingX"] == "{space.20}"


# #932 그날 시트 (결정 V107~V109)
def test_v107_event_row_list_bold_time_all_day_tag_and_memo():
    parts = next(v for v in component("calendar", "event-row")["variants"] if v["id"] == "list")["parts"]
    assert parts["timeColumn"]["fg"] == "{color.text.primary}" and parts["timeColumn"]["fontWeight"] == 700
    assert parts["allDay"]["element"] == "tag.status" and parts["allDay"]["slot"] == "day-sheet.event.all-day"
    memo = parts["memo"]
    assert (memo["source"], memo["maxLines"], memo["whenEmpty"], memo["fg"]) == (
        "Schedule.memo", 1, "hide", "{color.text.secondary}")
    assert parts["row"]["align"] == "first-line" and parts["row"]["paddingY"] == "{space.12}"


def test_v108_fortune_verdict_collapses_and_whole_card_toggles():
    verdict = component("calendar", "fortune-verdict")
    assert verdict["states"]["collapsed"]["initial"] is True
    assert verdict["states"]["collapsed"]["parts"]["rows"] == {"visible": False}
    assert verdict["states"]["expanded"]["parts"]["rows"] == {"visible": True}
    press = verdict["parts"]["card"]["pressable"]
    assert press["target"] == "카드 전체" and "V61" in press["innerWins"] and press["pattern"] == "press.ink"
    toggle = verdict["parts"]["toggle"]
    assert toggle["minHeight"] == 44 and toggle["icon"]["collapsed"] == "caret-down" and toggle["icon"]["expanded"] == "caret-up"
    assert "day-sheet.verdict.expand" in toggle["label"]["collapsed"] and "day-sheet.verdict.collapse" in toggle["label"]["expanded"]
    assert {"day-sheet.verdict.expand", "day-sheet.verdict.collapse"} <= ia_slot_ids("day-sheet")  # IA 반영 #946
    assert {"press.ink", "appear.seep", "disappear.seep"} <= set(verdict["uses"])


def test_v109_sheet_content_scrolls_when_taller_than_sheet():
    rules = component("frame", "sheet")["rules"]
    assert any("세로로 스크롤" in rule and "핸들 자리" in rule for rule in rules)
    assert "세로로 스크롤" in (COMPONENTS_DIR / "frame.md").read_text(encoding="utf-8")


# 결정 V110 (#958): 겹친 시트는 뒤 앱 화면을 줄이지 않고 아래 시트 머리 14px를 보임
def test_v110_sheet_stack_keeps_screen_size_and_peeks_lower_sheet():
    stack = load_documents(COMPONENTS_DIR)["interaction"]["patterns"]["sheet.stack"]
    assert stack["screenBelow"]["scale"] == 1 and stack["screenBelow"]["brightness"] == 1
    below = stack["sheetBelow"]
    assert below["translateY"] == "peek" and below["scale"] == 1 and below["brightness"] == 0.92
    assert stack["peek"]["height"] == {"value": 14, "unit": "px"} and "V100" in stack["peek"]["tap"]
    assert "transform" not in stack["properties"] and stack["duration"] == "{motion.duration.long}"
    peek = stack["peek"]
    assert "최대 2" in peek["depth"] and "진행률" in peek["drag"] and "접근성 트리에서 뺌" in peek["a11y"]
    assert "이동 없이" in peek["reduceMotion"] and "덮개를 더 깔지 않" in stack["screenBelow"]["note"]
    assert "14px" in (COMPONENTS_DIR / "interaction.md").read_text(encoding="utf-8")
    assert any("V110" in rule and "14px" in rule for rule in component("frame", "sheet")["rules"])
    for name in ("interaction.md", "frame.md"):
        text = (COMPONENTS_DIR / name).read_text(encoding="utf-8")
        assert "V110" in text and "0.92·밝기 0.9" not in text and "아래 층이 작아지며" not in text


# 결정 V111, V112 (#950, D118): 열린 근거 반짝임, 동작 줄이기 대체, 열림 꼬리표, 열린 날 근거 아이콘
def test_v112_unlocked_evidence_glints_and_marks():
    documents = load_documents(COMPONENTS_DIR)
    glint = documents["interaction"]["patterns"]["unlock.glint"]
    assert glint["duration"] == "{motion.duration.breathe}" and glint["interval"] == {"value": 15000, "unit": "ms"}
    assert glint["band"]["fill"] == "{gradient.unlocked}" and glint["reduceMotion"] == "replace"
    assert "한 번에" in glint["band"]["multiline"] and "닫을 때까지" in glint["stopWhen"]
    primitive = json.loads((DESIGN_DIR / "tokens" / "primitive.tokens.json").read_text(encoding="utf-8"))
    assert primitive["motion"]["duration"]["breathe"]["$value"] == {"value": 1800, "unit": "ms"}  # 시안 1.9초를 맞춘 값
    interaction_md = (COMPONENTS_DIR / "interaction.md").read_text(encoding="utf-8")
    assert "`breathe`(1800)" in interaction_md and "15000ms" in interaction_md and "`replace`" in interaction_md
    assert glint["reduceMotionAlternative"]["element"] == "unlock.mark"
    mark = documents["elements"]["elements"]["unlock.mark"]
    assert mark["title"]["fill"] == mark["rule"]["fill"] == "{gradient.unlocked}"
    assert mark["rule"]["width"] == {"value": 2, "unit": "px"}
    assert len(mark["where"]) == 2 and "appear.seep" in mark["appear"] and mark["a11y"] == "읽지 않음. 장식"
    link = component("sentence", "depth-link")
    assert {"unlock.glint", "unlock.mark"} <= set(link["uses"])
    assert link["parts"]["icon"]["unlocked"]["fill"] == "{gradient.unlocked}"
    assert link["parts"]["icon"]["color"] == "{color.action.primary}"  # 잠긴 날은 그대로 (V63)
    tag = link["parts"]["evidenceSheet"]["unlockTag"]
    assert tag["slot"] == "evidence-sheet.unlock.until" and tag["params"] == ["date"]
    assert tag["border"]["fill"] == "{gradient.unlocked}" and tag["icon"]["icon"] == "clock" and tag["glint"] is False
    assert "evidence-sheet.unlock.until" in ia_slot_ids("evidence-sheet")
    unlocked = link["states"]["unlocked"]["parts"]["evidenceSheet"]
    assert unlocked["unlockTag"] == {"visible": True}
    assert set(unlocked["glint"]["targets"]) == {"basisTitle", "basis", "sourceTitle", "source", "personalTitle", "personal"}
    assert {"title", "unlockTag", "target", "pillars"} <= set(unlocked["glint"]["excludes"])
    assert unlocked["reduceMotion"]["element"] == "unlock.mark"
    assert "unlockTag" not in link["states"]["locked"]["parts"]["evidenceSheet"]
    assert set(tag["copyByReason"]) == {"ad", "pass"} and "#952" in tag["reasonSource"]
    assert "whenExpires" in link["parts"]["icon"]["unlocked"] and "날짜 맥락이 없는" in link["parts"]["icon"]["unlocked"]["when"]
    # 화면 바탕 그라데이션 "하나" 규칙은 바탕으로 좁혀 씀 (V111). docs/identity/README.md는 지휘 몫(요청함)
    design_claude = (DESIGN_DIR / "CLAUDE.md").read_text(encoding="utf-8")
    assert "토큰 하나로 묶어" not in design_claude or "gradient.unlocked" in design_claude
    block = component("sentence", "sentence-block")["states"]["unlocked"]["parts"]
    assert block["text"]["glint"] == "unlock.glint" and block["reduceMotion"]["part"] == "rule"
    sentence_md = (COMPONENTS_DIR / "sentence.md").read_text(encoding="utf-8")
    assert "### 열린 근거 표시" in sentence_md and "D118 ⑤" in sentence_md


def test_v111_unlocked_gradient_stops_read_as_text():
    from palette import MIN_TEXT_CONTRAST, build_palette, contrast_ratio
    palette = build_palette()
    for mode, stops in palette["unlocked"].items():
        assert len(stops) == 3
        for stop in stops:
            for background in ("bg.base", "bg.sheet"):
                assert contrast_ratio(stop, palette["roles"][mode][background]) >= MIN_TEXT_CONTRAST, (mode, stop)


# 결정 V113 (#950, D118 ③): 원전은 상자 없이 뜻, 원문, 출처 순
def test_v113_source_reads_meaning_quote_cite():
    source = component("sentence", "depth-link")["parts"]["evidenceSheet"]["source"]
    assert source["order"] == ["meaning", "quote", "cite"]
    assert source["bg"] == "transparent" and source["padding"] == 0
    assert source["meaning"]["fg"] == "{color.text.primary}"
    assert source["quote"]["fg"] == "{color.text.secondary}" and source["quote"]["paddingStart"] == "{space.8}"
    assert source["quote"]["fontFallback"] == "{font.family.hanja}"
    assert source["cite"]["type"] == "{type.caption.md}" and source["cite"]["paddingStart"] == source["quote"]["paddingStart"]
    assert "ja 8글자" in source["meaning"]["note"] and source["radius"] == 0  # server #797 자른 값
    locked = component("sentence", "depth-link")["states"]["locked"]["parts"]["evidenceSheet"]["source"]
    assert locked["hidden"] == ["quote", "cite"] and locked["lines"] == 2


# 행운 색 둘(#982, D119, 결정 V114): 한 알약 두 칸, 이름표 없음, 어느 칸이든 같은 행운 색 시트
def test_v114_color_pair_pill_and_sheet():
    card = component("today", "lucky-card")
    color = next(v for v in card["variants"] if v["id"] == "color")
    pair = color["parts"]["pair"]
    assert pair["source"] == ["DailyResponse.color", "DailyResponse.second_color"]
    assert pair["basisLabel"] is False and pair["half"]["minTarget"] == 44
    assert pair["divider"]["color"] == "{color.line}"
    sheet = card["parts"]["colorPairSheet"]
    assert sheet["component"] == "explain-sheet" and sheet["intro"]["slot"] == "today.lucky-color.pair.intro"
    assert [section["bodySlot"] for section in sheet["sections"]] == ["today.lucky-color.body", "today.lucky-color.second.body"]
    assert sheet["section"]["head"]["basisLabel"] is False
    rules = " ".join(card["rules"])
    assert "갈렸다고 쓰지 않는다" in rules and "알약 전체" in rules
    md = _md_section("today.md", "## lucky-card")
    assert "colorPairSheet" in md and "이름표" in md


# 집중 시간 해와 달(#1003, D122, 결정 V115, 토큰 1.8.0): 채운 아이콘, 모드별 아이콘 전용 색
def test_v115_time_periods_fill_icons():
    time = next(v for v in component("today", "lucky-card")["variants"] if v["id"] == "time")
    day, night = time["periods"]
    assert (day["source"], night["source"]) == ("DailyResponse.focus_time", "DailyResponse.night_focus_time")
    assert day["lead"] == {"icon": "sun", "iconWeight": "fill", "iconColor": "{color.time.day}"}
    assert night["lead"] == {"icon": "moon", "iconWeight": "fill", "iconColor": "{color.time.night}"}
    assert all(period["lead"]["icon"] != "clock" for period in time["periods"]) and time["screens"] == ["today"]
    icon = load_documents(COMPONENTS_DIR)["elements"]["elements"]["icon"]
    assert icon["weights"]["timeOfDay"] == "fill"
    assert "fill (경고 표시와 집중 시간 해, 달 밖)" in icon["forbidden"]


# 밤 칩 때 낱말(D122 ⑦, 결정 V116): 07:30에 값과 함께 바뀜, 낮 칩에는 없음. 공유 이미지는 낮 칩 하나
def test_v116_night_word_switches_at_day_start():
    card = component("today", "lucky-card")
    time = next(v for v in card["variants"] if v["id"] == "time")
    day, night = time["periods"]
    assert "word" not in day
    assert night["word"]["slots"] == {"dawn": "today.lucky-time.night.dawn", "tonight": "today.lucky-time.night.tonight"}
    assert "07:30" in night["word"]["switch"]
    share = component("today", "share-image")
    assert any("낮 칩 하나만" in rule for rule in share["rules"])


# 시간 시트 24시간 띠(결정 V117): 시진 12칸, 07:30 전에는 밤이 앞
def test_v117_time_band():
    band = component("today", "lucky-card")["parts"]["timeBand"]
    assert band["cells"]["count"] == 12 and band["cells"]["gap"] == "{space.2}"
    assert band["order"]["beforeDayStart"][0].startswith("night") and band["order"]["fromDayStart"][0].startswith("day")
    assert band["cells"]["day"]["bg"] == "{color.ohaeng.earth.bg}" and band["cells"]["night"]["bg"] == "{color.ohaeng.water.bg}"
    assert band["now"]["tag"]["slot"] == "today.lucky-time.band.now"
    assert band["now"]["tag"]["bg"] == "{color.inverse.bg}"


def test_v118_lucky_sheets_evidence_and_time_titles():
    # #1020 drift(D123 ②): 행운 색, 시간 시트 끝 근거 진입점은 용어 풀이 시트와 같은 depth-link block(V63)
    card = component("today", "lucky-card")
    term_link = component("sentence", "term-token")["parts"]["explainSheet"]["evidenceLink"]
    for link in (card["parts"]["explain"]["evidenceLink"], card["parts"]["colorPairSheet"]["section"]["evidenceLink"]):
        assert (link["component"], link["variant"]) == (term_link["component"], term_link["variant"])
    assert "direction, number 시트에는 없음" in card["parts"]["explain"]["evidenceLink"]["when"]
    periods = {p["id"]: p for p in next(v for v in card["variants"] if v["id"] == "time")["periods"]}
    assert periods["day"]["sheetTitleSlot"] == "today.lucky-time.day.title"
    assert periods["night"]["sheetTitleSlot"] == "today.lucky-time.night.title"
    band = card["parts"]["timeBand"]
    assert band["heads"]["iconGap"] == "{space.4}" and band["ticks"]["align"] == ["start", "center", "end"]
    # 관문 답 2026-11-12 C: en 띠 칸은 지지 한자. 시간 칩 스크린리더 이름은 시트 제목 슬롯
    assert "en은" in band["cells"]["label"]["source"] and "branch.*" in band["cells"]["label"]["source"]
    assert "today.lucky-time.day.title" in card["a11y"]["timeLabel"] and "때 낱말" in card["a11y"]["timeLabel"]

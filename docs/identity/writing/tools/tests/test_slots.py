"""슬롯 명세·원고 로더 테스트."""

import json
import re
from pathlib import Path

import pytest

from mlw.completeness import check_params
from mlw.glossary import glossary_values
from mlw.loader import load_content, load_rules, load_slots
from mlw.model import UNBOUNDED, LoadError, ParamKind, RuleSet
from mlw.paths import MESSAGE_PARAMS_FILE, RULES_DIR, SLOTS_DIR

MESSAGE_KEYS_PATH = Path(__file__).resolve().parents[5] / "core" / "message_keys.json"
# 메시지 키가 아니라 식별자를 키로 갖는 슬롯입니다.
IDENTIFIER_SLOTS = {
    "daily.focus_reason",
    "calendar.score_item",
    "calendar.solar_term",
    "glossary.value_name",
    "character.reason",
    "chart.ilgan_head",
    "chart.ilgan_body",
    "chart.yongsin_summary",
    "term.meaning",
    "explain.today_reason",
    "evidence.basis",
    "evidence.source",
    "system.apple_return",
    "system.notice",
}
VALID_SLOT = """\
- id: test.slot
  where: 시험 화면
  purpose: info
  user_state: 미정
  structure: 미정
  tone: {}
  max_length: {ko: null, en: null, ja: null}
  keys:
    - params: {element: [element, color]}
      keys: [a.one, a.two]
    - b.plain
  examples: {good: [], bad: []}
"""


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


def make_slots_dir(root: Path, slot_yaml: str) -> Path:
    """실제 `_schema.yaml`을 복사하고 `content/test.yaml`에 슬롯을 둔 디렉터리를 만듭니다."""
    (root / "content").mkdir()
    (root / "_schema.yaml").write_text(
        (SLOTS_DIR / "_schema.yaml").read_text(encoding="utf-8"), encoding="utf-8"
    )
    (root / "content" / "test.yaml").write_text(slot_yaml, encoding="utf-8")
    return root


def test_content_slots_cover_message_keys(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    message_keys = set(json.loads(MESSAGE_KEYS_PATH.read_text(encoding="utf-8")))
    # ui 슬롯은 ARB 메시지 이름이라 core 메시지 키가 아닙니다.
    covered = {
        key
        for slot in slots.values()
        if slot.id not in IDENTIFIER_SLOTS and slot.file.parent.name != "ui"
        for key in slot.keys
    }
    assert len(message_keys) == 153
    assert covered == message_keys


def test_slot_params_match_core_message_params(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    message_params = json.loads(MESSAGE_PARAMS_FILE.read_text(encoding="utf-8"))
    assert set(message_params) == set(json.loads(MESSAGE_KEYS_PATH.read_text(encoding="utf-8")))
    assert check_params(slots, message_params) == []


def test_identifier_slots_do_not_collide_with_message_keys(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    message_keys = set(json.loads(MESSAGE_KEYS_PATH.read_text(encoding="utf-8")))
    for slot_id in IDENTIFIER_SLOTS:
        assert not set(slots[slot_id].keys) & message_keys


def test_glossary_covers_enums(rules: RuleSet) -> None:
    slot = load_slots(SLOTS_DIR, rules)["glossary.value_name"]
    expected = {f"{category}.{value}" for category, values in glossary_values().items() for value in values}
    assert set(slot.keys) == expected
    assert glossary_values()["color"] == glossary_values()["element"]


def test_slot_counts_match_spec(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    assert len(slots["daily.fortune.head"].keys) == 20
    assert len(slots["daily.fortune.tag"].keys) == 15
    assert len(slots["daily.guide"].keys) == 20
    assert slots["daily.guide"].variants == 2
    assert len(slots["calendar.score_item"].keys) == 7
    assert len(slots["calendar.solar_term"].keys) == 24
    assert slots["daily.fortune.head"].keys["fortune.yongsin_day.siksang"] == {
        "day_kind": ParamKind("glossary", ("day_kind",)),
        "ten_god": ParamKind("glossary", ("ten_god", "ten_god_group")),
        "element": ParamKind("glossary", ("element", "color")),
        "emphasis": ParamKind("none"),
    }
    assert "settings.calculation_basis" not in slots


def test_param_kinds_follow_engine_values(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    element = ParamKind("glossary", ("element", "color"))
    assert slots["daily.focus_time"].keys["focus_time.hap"] == {
        "branches": ParamKind("list", ("branch",)),
        "score": ParamKind("number"),
    }
    assert slots["daily.number"].keys["number.gwiin_day"] == {"number": ParamKind("number"), "element": element}
    assert slots["daily.color"].keys["color.gwiin_day"] == {"element": element, "role": ParamKind("none")}
    assert slots["daily.direction"].keys["direction.day_kind.gwiin"] == {
        "direction": ParamKind("glossary", ("direction8",)),
        "rule_id": ParamKind("none"),
    }
    assert slots["daily.guide"].keys["guide.clash"] == {
        "ten_god": ParamKind("glossary", ("ten_god", "ten_god_group")),
        "element": element,
    }
    assert slots["chart.yongsin_method"].keys["yongsin.method.eokbu"] == dict.fromkeys(
        ("yongsin", "huisin", "gisin", "tonggwan"), element
    )
    assert slots["calendar.day_level"].keys["calendar.good"] == {"score": ParamKind("number")}


def test_personal_slot_params(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    element = ParamKind("glossary", ("element", "color"))
    place = ParamKind("glossary", ("place",))
    role = ParamKind("glossary", ("role",))
    strength = ParamKind("glossary", ("strength",))
    assert len(slots["personal.day_master"].keys) == 10
    assert len(slots["personal.ten_god"].keys) == 10
    assert len(slots["personal.twelve_stage"].keys) == 12
    assert len(slots["personal.shinsal"].keys) == 6
    assert len(slots["personal.luck"].keys) == 22
    assert slots["personal.day_master"].keys["personal.day_master.gap"] == {
        "strength": strength,
        "yongsin": element,
        "gisin": element,
    }
    assert slots["personal.ten_god"].keys["personal.ten_god.siksin"] == {
        "place": place,
        "element": element,
        "role": role,
        "group_count": ParamKind("number"),
        "strength": strength,
    }
    assert slots["personal.shinsal"].keys["personal.shinsal.dohwa"] == {
        "place": place,
        "element": element,
        "role": role,
    }
    assert slots["personal.luck"].keys["personal.luck.ten_god.siksin"] == {
        "luck": ParamKind("glossary", ("luck",)),
        "part": ParamKind("glossary", ("part",)),
        "element": element,
        "role": role,
        "current": ParamKind("none"),
    }
    assert slots["personal.luck"].keys["personal.luck.twelve_stage.jewang"] == {
        "element": element,
        "role": role,
        "current": ParamKind("none"),
    }


@pytest.mark.parametrize(
    "params",
    [
        "[element]",
        "{element: [colour]}",
        "{element: []}",
        "{branches: list:nope}",
        "{score: numbr}",
        "{name: none}",
    ],
)
def test_bad_params_are_schema_errors(tmp_path: Path, rules: RuleSet, params: str) -> None:
    slot_yaml = VALID_SLOT.replace("{element: [element, color]}", params)
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, slot_yaml), rules)
    assert {finding.rule_id for finding in raised.value.findings} == {"load.schema"}


def test_fortune_slots_are_info_with_three_types(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    for slot_id in ("daily.fortune.head", "daily.fortune.tag"):
        assert slots[slot_id].purpose == "info"
        assert slots[slot_id].types == ("advice", "state", "care")
    assert slots["daily.guide"].purpose == "guide"


def test_daily_slots_co_display_each_other(rules: RuleSet) -> None:
    slots = load_slots(SLOTS_DIR, rules)
    daily = {slot_id for slot_id in slots if slot_id.startswith("daily.")}
    for slot_id in daily:
        assert set(slots[slot_id].co_display) == daily - {slot_id}


LENGTHS_FILE = SLOTS_DIR.parents[1] / "design" / "lengths.md"
# design 표의 옛 슬롯 이름 → writing 슬롯 id입니다(content 슬롯 settings.calculation_basis는 ui 슬롯으로 옮겼습니다).
LENGTH_SLOT_ALIASES = {"settings.calculation_basis": "calc-basis.longitude.body"}
# 확인 창 슬롯의 제목 자리 키입니다(#191). 나머지 키는 버튼이고, profileEditRecalcConfirmBody는 본문입니다.
DIALOG_TITLE_KEYS = {
    "diary-view.delete.confirm": "diaryViewDeleteConfirm",
    "event-edit.delete.confirm": "eventEditDeleteConfirm",
    "account-delete.delete.confirm": "accountDeleteDeleteConfirm",
    "settings.logout.confirm": "settingsLogoutConfirm",
    "preview.share.login-notice": "previewShareLoginNotice",
    "profile-edit.recalc.confirm": "profileEditRecalcConfirmTitle",
    "login-methods.unlink.confirm": "loginMethodsUnlinkConfirm",
    "account-merge.merge.confirm": "accountMergeMergeConfirm",
}
DIALOG_BODY_KEYS = {
    "profile-edit.recalc.confirm": "profileEditRecalcConfirmBody",
    "login-methods.unlink.confirm": "loginMethodsUnlinkConfirmBody",
}


def design_lengths() -> tuple[list[tuple[list[str], str, dict[str, int]]], list[str]]:
    """design `lengths.md`의 상한 행(슬롯 목록, 칸, 언어별 값)과 상한 없음 슬롯 목록을 읽습니다."""
    rows: list[tuple[list[str], str, dict[str, int]]] = []
    unbounded: list[str] = []
    section = ""
    for line in LENGTHS_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line
        if line.startswith("상한을 두지 않는 슬롯"):
            section = "unbounded"
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        slot_ids = [LENGTH_SLOT_ALIASES.get(name, name) for name in re.findall(r"`([^`]+)`", cells[0])]
        if section == "unbounded":
            unbounded.extend(slot_ids)
        elif section == "## 상한":
            ko, ja, en = (int(cell.strip("*")) for cell in cells[-3:])
            rows.append((slot_ids, cells[1], {"ko": ko, "en": en, "ja": ja}))
    return rows, unbounded


def design_key_lengths() -> list[tuple[str, str, str, int]]:
    """design `lengths.md` "키별 상한" 표의 (언어, 슬롯, 키, 상한)입니다(#446)."""
    rows: list[tuple[str, str, str, int]] = []
    in_table = False
    for line in LENGTHS_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("키별 상한"):
            in_table = True
            continue
        if in_table and line and not line.startswith("|"):
            break
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if in_table and len(cells) >= 4 and cells[0] in ("ko", "en", "ja"):
            rows.append((cells[0], cells[1].strip("`"), cells[2].strip("`"), int(cells[3].strip("*"))))
    return rows


@pytest.mark.contract
def test_key_lengths_match_design(rules: RuleSet) -> None:
    """키별 상한이 design `lengths.md` "키별 상한" 표와 같은지 봅니다(#446)."""
    slots = load_slots(SLOTS_DIR, rules)
    rows = design_key_lengths()
    assert rows
    for lang, slot_id, key, limit in rows:
        assert slots[slot_id].key_max_length[key][lang] == limit, (slot_id, key, lang)


@pytest.mark.contract
def test_lengths_match_design(rules: RuleSet) -> None:
    """슬롯 상한이 design `lengths.md` 확정값과 같은지 봅니다(#54, #131, #191)."""
    slots = load_slots(SLOTS_DIR, rules)
    rows, unbounded = design_lengths()
    assert rows and unbounded
    for slot_ids, place, limits in rows:
        for slot_id in slot_ids:
            slot = slots[slot_id]
            if slot_id not in DIALOG_TITLE_KEYS:
                assert slot.max_length == limits, slot_id
            elif place.startswith("dialog title"):
                assert slot.key_max_length[DIALOG_TITLE_KEYS[slot_id]] == limits, slot_id
            else:
                assert slot.max_length == limits, slot_id
    all_unbounded = {lang: UNBOUNDED for lang in ("ko", "en", "ja")}
    for slot_id in unbounded:
        assert slots[slot_id].max_length == all_unbounded, slot_id
    for slot_id, key in DIALOG_BODY_KEYS.items():
        assert slots[slot_id].key_max_length[key] == all_unbounded, slot_id


def test_valid_slot_is_loaded(tmp_path: Path, rules: RuleSet) -> None:
    slots = load_slots(make_slots_dir(tmp_path, VALID_SLOT), rules)
    slot = slots["test.slot"]
    element = {"element": ParamKind("glossary", ("element", "color"))}
    assert slot.keys == {"a.one": element, "a.two": element, "b.plain": {}}
    assert slot.types == ()
    assert slot.variants == 1
    assert slot.line == 1


def test_unknown_rule_reference(tmp_path: Path, rules: RuleSet) -> None:
    slots_dir = make_slots_dir(tmp_path, VALID_SLOT + "  allowed: [slop.P99]\n")
    with pytest.raises(LoadError) as raised:
        load_slots(slots_dir, rules)
    [finding] = raised.value.findings
    assert finding.rule_id == "slot.unknown_rule"
    assert finding.line == 1
    assert finding.file.name == "test.yaml"
    assert "slop.P99" in finding.message


def test_known_rule_reference_passes(tmp_path: Path, rules: RuleSet) -> None:
    slots_dir = make_slots_dir(tmp_path, VALID_SLOT + "  allowed: [slop.P1]\n  forbidden: [slop.P2]\n")
    slot = load_slots(slots_dir, rules)["test.slot"]
    assert slot.allowed == frozenset({"slop.P1"})
    assert slot.forbidden == frozenset({"slop.P2"})


def test_missing_required_field_and_unknown_field(tmp_path: Path, rules: RuleSet) -> None:
    broken = VALID_SLOT.replace("  structure: 미정\n", "") + "  colour: 파랑\n"
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, broken), rules)
    messages = [finding.message for finding in raised.value.findings]
    assert {finding.rule_id for finding in raised.value.findings} == {"load.schema"}
    assert any("structure" in message for message in messages)
    assert any("colour" in message for message in messages)


def test_invalid_purpose_and_tone_are_reported(tmp_path: Path, rules: RuleSet) -> None:
    broken = VALID_SLOT.replace("purpose: info", "purpose: joy").replace("tone: {}", "tone: {진지: 9}")
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, broken), rules)
    messages = " ".join(finding.message for finding in raised.value.findings)
    assert "purpose" in messages


def test_duplicate_slot_id_is_reported(tmp_path: Path, rules: RuleSet) -> None:
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, VALID_SLOT + "\n" + VALID_SLOT), rules)
    assert [finding.rule_id for finding in raised.value.findings] == ["load.schema"]
    assert "중복" in raised.value.findings[0].message


def test_ui_slot_keys_must_be_lower_camel_case(tmp_path: Path, rules: RuleSet) -> None:
    slots_dir = make_slots_dir(tmp_path, VALID_SLOT)
    (slots_dir / "ui").mkdir()
    (slots_dir / "ui" / "depth.yaml").write_text(
        VALID_SLOT.replace("test.slot", "ui.test").replace("a.one", "depthOne").replace("a.two", "depth.two"),
        encoding="utf-8",
    )
    with pytest.raises(LoadError) as raised:
        load_slots(slots_dir, rules)
    messages = [finding.message for finding in raised.value.findings]
    assert {finding.rule_id for finding in raised.value.findings} == {"load.schema"}
    assert any("depth.two" in message for message in messages)
    assert not any("depthOne" in message for message in messages)


def test_unknown_co_display_slot(tmp_path: Path, rules: RuleSet) -> None:
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, VALID_SLOT + "  co_display: [nowhere]\n"), rules)
    assert [finding.rule_id for finding in raised.value.findings] == ["slot.unknown_slot"]


def test_load_content_reads_entries_with_lines(tmp_path: Path) -> None:
    (tmp_path / "ko").mkdir()
    (tmp_path / "ko" / "a.yaml").write_text(
        '- slot: s\n  key: k\n  type: advice\n  variant: 2\n  text: "안녕"\n\n- slot: s\n  key: k\n  text: "둘"\n',
        encoding="utf-8",
    )
    first, second = load_content(tmp_path)
    assert (first.slot, first.key, first.type, first.variant, first.lang, first.text) == (
        "s",
        "k",
        "advice",
        2,
        "ko",
        "안녕",
    )
    assert first.line == 1
    assert (second.type, second.variant, second.line) == (None, 1, 7)


def test_load_content_without_directory_is_empty(tmp_path: Path) -> None:
    assert load_content(tmp_path / "none") == []


def test_load_content_reports_problems_together(tmp_path: Path) -> None:
    (tmp_path / "ko").mkdir()
    (tmp_path / "xx").mkdir()
    (tmp_path / "ko" / "a.yaml").write_text(
        "- slot: s\n  key: k\n  type: wish\n  text: x\n\n- slot: s\n  text: y\n  extra: 1\n", encoding="utf-8"
    )
    with pytest.raises(LoadError) as raised:
        load_content(tmp_path)
    assert len(raised.value.findings) >= 3
    assert {finding.rule_id for finding in raised.value.findings} == {"load.schema"}


V11_SLOT = """\
- id: test.slot
  where: 시험 화면
  purpose: info
  user_state: 미정
  structure: 미정
  tone: {}
  max_length: {ko: null, en: null, ja: null}
  ia: [today.guide.question]
  components: [tag-chip]
  select: "값 v -> 키 k"
  vocative: true
  keys:
    - params: {when: text}
      keys: [k]
  examples: {good: [], bad: []}
"""


def test_slot_v11_fields(tmp_path: Path, rules: RuleSet) -> None:
    slot = load_slots(make_slots_dir(tmp_path, V11_SLOT), rules)["test.slot"]
    assert slot.ia == ("today.guide.question",)
    assert slot.components == ("tag-chip",)
    assert slot.select == "값 v -> 키 k"
    assert slot.vocative is True
    assert slot.keys["k"]["when"] == ParamKind("text")


def test_slot_v11_defaults(tmp_path: Path, rules: RuleSet) -> None:
    slot = load_slots(make_slots_dir(tmp_path, VALID_SLOT), rules)["test.slot"]
    assert (slot.ia, slot.components, slot.select, slot.vocative) == ((), (), "", False)


def test_vocative_must_be_bool(tmp_path: Path, rules: RuleSet) -> None:
    with pytest.raises(LoadError) as error:
        load_slots(make_slots_dir(tmp_path, V11_SLOT.replace("vocative: true", 'vocative: "yes"')), rules)
    assert "'vocative'" in str(error.value)


def test_empty_keys_slot_loads(tmp_path: Path, rules: RuleSet) -> None:
    yaml_text = VALID_SLOT.split("  keys:")[0] + "  keys: []\n  examples: {good: [], bad: []}\n"
    assert load_slots(make_slots_dir(tmp_path, yaml_text), rules)["test.slot"].keys == {}


def test_unbounded_and_key_max_length_are_loaded(tmp_path: Path, rules: RuleSet) -> None:
    slot_yaml = VALID_SLOT.replace(
        "max_length: {ko: null, en: null, ja: null}", "max_length: {ko: 10, en: 18, ja: unbounded}"
    ) + "  key_max_length:\n    b.plain: {ko: unbounded, en: 5}\n"
    slot = load_slots(make_slots_dir(tmp_path, slot_yaml), rules)["test.slot"]
    assert slot.max_length == {"ko": 10, "en": 18, "ja": UNBOUNDED}
    assert slot.key_max_length == {"b.plain": {"ko": UNBOUNDED, "en": 5}}


def test_length_limit_prefers_key_limit(tmp_path: Path, rules: RuleSet) -> None:
    slot_yaml = VALID_SLOT.replace(
        "max_length: {ko: null, en: null, ja: null}", "max_length: {ko: 10, en: null, ja: unbounded}"
    ) + "  key_max_length:\n    b.plain: {ko: unbounded, en: 5}\n"
    slot = load_slots(make_slots_dir(tmp_path, slot_yaml), rules)["test.slot"]
    assert slot.length_limit("ko", "a.one") == 10
    assert slot.length_limit("ja", "a.one") is None
    assert slot.length_limit("en", "a.one") is None
    assert slot.length_limit("ko", "b.plain") is None
    assert slot.length_limit("en", "b.plain") == 5
    # 키 상한에 없는 언어는 슬롯 상한을 씁니다.
    assert slot.length_limit("ja", "b.plain") is None
    assert slot.length_limit("ko") == 10


@pytest.mark.parametrize(
    ("extra", "needle"),
    [
        ("  key_max_length:\n    nope.key: {ko: 3}\n", "nope.key"),
        ("  key_max_length:\n    b.plain: {fr: 3}\n", "fr"),
        ("  key_max_length:\n    b.plain: {ko: many}\n", "b.plain"),
        ("  key_max_length:\n    b.plain: 3\n", "b.plain"),
    ],
)
def test_bad_key_max_length_is_schema_error(tmp_path: Path, rules: RuleSet, extra: str, needle: str) -> None:
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, VALID_SLOT + extra), rules)
    assert any(needle in finding.message for finding in raised.value.findings)


def test_bad_max_length_word_is_schema_error(tmp_path: Path, rules: RuleSet) -> None:
    broken = VALID_SLOT.replace("max_length: {ko: null, en: null, ja: null}", "max_length: {ko: endless}")
    with pytest.raises(LoadError) as raised:
        load_slots(make_slots_dir(tmp_path, broken), rules)
    assert any("unbounded" in finding.message for finding in raised.value.findings)

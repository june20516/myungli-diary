"""원고에서 검수 행 만들기 테스트(#1283)."""

from pathlib import Path

import pytest

from mlw import paths
from mlw.loader import load_content, load_rules, load_slots
from mlw.model import LENGTH_UNIT_BYTES, UNBOUNDED, Entry, LengthLimit, ParamKind, Slot
from mlw.review.export import (
    build_rows,
    bundles_for,
    check_tier_coverage,
    example_text,
    glossary_by_category,
    place_text,
    row_id,
)
from mlw.review.sheet import TIERS


def make_slot(
    slot_id: str = "s",
    params: dict[str, ParamKind] | None = None,
    key: str = "k",
    max_length: dict[str, LengthLimit] | None = None,
    **extra: object,
) -> Slot:
    return Slot(
        id=slot_id,
        where="오늘 화면 머리",
        purpose="info",
        types=(),
        variants=1,
        keys={key: params or {}},
        co_display=(),
        max_length=max_length or {},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/ui/s.yaml"),
        **extra,  # type: ignore[arg-type]
    )


def make_entry(
    text: str,
    lang: str = "en",
    bundle: str = "ui",
    slot: str = "s",
    key: str = "k",
    type_: str | None = None,
    variant: int = 1,
) -> Entry:
    return Entry(Path(f"content/{lang}/{bundle}.yaml"), 1, slot, key, type_, variant, lang, text)


GLOSSARY = {"stem": ("Gap Wood", "Eul Wood"), "branch": ("Rat", "Ox")}


def test_row_id() -> None:
    assert row_id(make_entry("x")) == "s|k||1"
    assert row_id(make_entry("x", type_="advice", variant=2)) == "s|k|advice|2"


def test_source_matches_across_files() -> None:
    ko = make_entry("원문", lang="ko", bundle="daily", type_="advice")
    en = make_entry("Text", bundle="daily-fortune", type_="advice")
    missing = make_entry("Alone", bundle="daily-fortune", key="other")
    slots = {"s": Slot(**{**make_slot().__dict__, "keys": {"k": {}, "other": {}}})}
    rows = build_rows([ko, en, missing], slots, "en", ["daily-fortune"])
    assert [(row.source, row.current) for row in rows["daily-fortune"]] == [("원문", "Text"), ("", "Alone")]


def test_bundle_is_file_stem() -> None:
    rows = build_rows([make_entry("A", bundle="store"), make_entry("B", bundle="ui")], {"s": make_slot()}, "en", ["ui"])
    assert list(rows) == ["ui"]
    assert [row.bundle for row in rows["ui"]] == ["ui"]


def test_rows_keep_file_order() -> None:
    entries = [make_entry("A", key="b"), make_entry("B", key="a")]
    slot = Slot(**{**make_slot().__dict__, "keys": {"a": {}, "b": {}}})
    rows = build_rows(entries, {"s": slot}, "en", ["ui"])
    assert [row.current for row in rows["ui"]] == ["A", "B"]


@pytest.mark.parametrize(
    ("slot", "expected"),
    [
        (make_slot(max_length={"en": 40}), "오늘 화면 머리\nMax 40 characters (최대 40자)"),
        (make_slot(max_length={"en": 40}, length_unit=LENGTH_UNIT_BYTES), "오늘 화면 머리\nMax 40 bytes (최대 40바이트)"),
        (make_slot(max_length={"en": 40}, max_lines=2), "오늘 화면 머리\nMax 40 characters, 2 lines (최대 40자, 2줄)"),
        (make_slot(max_length={"en": UNBOUNDED}), "오늘 화면 머리\nNo limit (상한 없음)"),
        (make_slot(max_length={"en": None}), "오늘 화면 머리\nLimit not set yet (상한 미정)"),
        (make_slot(max_length={"en": 40}, key_max_length={"k": {"en": 12}}), "오늘 화면 머리\nMax 12 characters (최대 12자)"),
    ],
)
def test_place_text(slot: Slot, expected: str) -> None:
    assert place_text(slot, "en", "k") == expected


def test_place_text_ja() -> None:
    slot = make_slot(max_length={"ja": 18}, max_lines=2)
    assert place_text(slot, "ja", "k") == "오늘 화면 머리\n最大18文字、2行 (최대 18자, 2줄)"


def test_example_glossary() -> None:
    slot = make_slot(params={"stem": ParamKind("glossary", ("stem",))})
    assert example_text(make_entry("{stem} today"), slot, GLOSSARY) == "Gap Wood today"


def test_example_list() -> None:
    slot = make_slot(params={"branches": ParamKind("list", ("branch",))})
    assert example_text(make_entry("Hours: {branches}"), slot, GLOSSARY) == "Hours: Rat, Ox"


def test_example_plural() -> None:
    slot = make_slot(params={"count": ParamKind("number")})
    entry = make_entry("{count, plural, one{{count} day} other{{count} days}} left")
    assert example_text(entry, slot, GLOSSARY) == "1 day left\n3 days left"


def test_example_name_and_text() -> None:
    slot = make_slot(params={"date": ParamKind("text")})
    assert example_text(make_entry("{name}, see {date}"), slot, GLOSSARY) == "Alex, see May 12"
    assert example_text(make_entry("{date}の日記", lang="ja"), slot, GLOSSARY) == "5月12日の日記"
    assert example_text(make_entry("{name}さん", lang="ja"), slot, GLOSSARY) == "ゆきさん"


def test_example_text_sample_by_key() -> None:
    params = {"branch": ParamKind("text"), "start": ParamKind("text"), "end": ParamKind("text")}
    slot = make_slot(params=params, key="onboardTimeHourConfirm")
    entry = make_entry("The {branch} hour, from {start} to {end}.", key="onboardTimeHourConfirm")
    assert example_text(entry, slot, GLOSSARY) == "The Horse hour, from 11:30 AM to 1:29 PM."
    period = make_slot(params=params, key="purchaseMetaPeriod")
    assert example_text(make_entry("{start} to {end}", key="purchaseMetaPeriod"), period, GLOSSARY) == (
        "May 12, 2026 to June 12, 2026"
    )


def test_example_price_and_unknown_text_stay_marked() -> None:
    slot = make_slot(params={"price": ParamKind("text"), "mystery": ParamKind("text")})
    assert example_text(make_entry("{price} or {mystery}"), slot, GLOSSARY) == "‹price› or ‹mystery›"


def test_example_empty_when_same_as_current() -> None:
    assert example_text(make_entry("Get started"), make_slot(), GLOSSARY) == ""


def test_repo_text_placeholders_have_samples() -> None:
    from mlw.review.export import PRICE_PARAM, SAMPLE_TEXT

    rules = load_rules(paths.RULES_DIR)
    slots = load_slots(paths.SLOTS_DIR, rules)
    missing = set()
    for entry in load_content(paths.CONTENT_DIR):
        slot = slots.get(entry.slot)
        if entry.lang not in ("en", "ja") or slot is None:
            continue
        for name, kind in slot.keys.get(entry.key, {}).items():
            in_text = "{" + name + "}" in entry.text or "{" + name + "," in entry.text
            if kind.kind == "text" and in_text and name != PRICE_PARAM and entry.lang not in SAMPLE_TEXT.get(name, {}):
                missing.add((name, entry.lang))
    assert missing == set()


def test_example_strips_tokens() -> None:
    entry = make_entry("[[Bigyeop|ten_god_group.bigyeop]] comes")
    assert example_text(entry, make_slot(), GLOSSARY) == "Bigyeop comes"
    assert example_text(make_entry("[[Bigyeop]] comes"), make_slot(), GLOSSARY) == "Bigyeop comes"


def test_example_keeps_unknown_placeholder() -> None:
    assert example_text(make_entry("{name} sees {mystery}"), make_slot(), GLOSSARY) == "Alex sees {mystery}"


def test_glossary_by_category_keeps_order() -> None:
    entries = [
        make_entry("Gap Wood", slot="glossary.value_name", key="stem.gap"),
        make_entry("Eul Wood", slot="glossary.value_name", key="stem.eul"),
        make_entry("갑목", lang="ko", slot="glossary.value_name", key="stem.gap"),
    ]
    assert glossary_by_category(entries, "en") == {"stem": ("Gap Wood", "Eul Wood")}


def test_bundles_for() -> None:
    assert bundles_for(1, None) == TIERS[1]
    assert bundles_for(None, ["ui", "store"]) == ("ui", "store")
    for tier, bundles in ((1, ["ui"]), (None, None)):
        with pytest.raises(ValueError):
            bundles_for(tier, bundles)
    with pytest.raises(ValueError):
        bundles_for(None, ["nope"])
    with pytest.raises(ValueError):
        bundles_for(9, None)


def test_tier_coverage_reports_both_sides(tmp_path: Path) -> None:
    lang_dir = tmp_path / "en"
    lang_dir.mkdir()
    for bundle in [b for tier in TIERS.values() for b in tier if b != "web"] + ["extra"]:
        (lang_dir / f"{bundle}.yaml").write_text("[]\n", encoding="utf-8")
    assert check_tier_coverage(tmp_path, "en") == ["extra", "web"]


@pytest.mark.contract
@pytest.mark.parametrize("lang", ["en", "ja"])
def test_repo_tier_coverage(lang: str) -> None:
    assert check_tier_coverage(paths.CONTENT_DIR, lang) == []


@pytest.mark.contract
def test_repo_tier1_rows() -> None:
    rules = load_rules(paths.RULES_DIR)
    rows = build_rows(load_content(paths.CONTENT_DIR), load_slots(paths.SLOTS_DIR, rules), "en", TIERS[1])
    assert list(rows) == list(TIERS[1])
    assert all(row.current and row.place for bundle_rows in rows.values() for row in bundle_rows)

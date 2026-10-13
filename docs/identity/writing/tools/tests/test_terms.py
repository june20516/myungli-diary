"""용어 id와 토큰 검사 테스트."""

import json
from pathlib import Path

import pytest

from mlw.glossary import term_ids
from mlw.model import Entry, ParamKind, Slot
from mlw.paths import MESSAGE_KEYS_FILE
from mlw.terms import RULE_TOKEN_TERM, check_tokens

TAG_KEYS = ("tag.dohwa",)


def make_slot(slot_id: str, keys: dict[str, dict[str, ParamKind]]) -> Slot:
    return Slot(
        id=slot_id,
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys=keys,
        co_display=(),
        max_length={},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/content/test.yaml"),
    )


SLOTS = {
    "glossary.value_name": make_slot(
        "glossary.value_name", {"stem.sin": {}, "branch.shin": {}, "ten_god.pyeongwan": {}}
    ),
    "daily.tag_label": make_slot("daily.tag_label", {"tag.dohwa": {}}),
    "s.slot": make_slot("s.slot", {"k": {"element": ParamKind("glossary", ("element", "color"))}}),
}
GLOSSARY_KO = [
    Entry(Path("g.yaml"), 1, "glossary.value_name", "stem.sin", None, 1, "ko", "신"),
    Entry(Path("g.yaml"), 2, "glossary.value_name", "branch.shin", None, 1, "ko", "신"),
    Entry(Path("g.yaml"), 3, "glossary.value_name", "ten_god.pyeongwan", None, 1, "ko", "편관"),
    Entry(Path("g.yaml"), 4, "daily.tag_label", "tag.dohwa", None, 1, "ko", "도화"),
]


def entry(text: str, lang: str = "ko") -> Entry:
    return Entry(Path(f"content/{lang}/t.yaml"), 9, "s.slot", "k", None, 1, lang, text)


def token_rules(text: str, lang: str = "ko") -> list[str]:
    findings = check_tokens([*GLOSSARY_KO, entry(text, lang)], SLOTS, TAG_KEYS)
    return [finding.rule_id for finding in findings]


def test_term_ids_count() -> None:
    message_keys = json.loads(MESSAGE_KEYS_FILE.read_text(encoding="utf-8"))
    tags = [key for key in message_keys if key.startswith("tag.")]
    ids = term_ids(tags)
    assert len(ids) == 77
    assert "ten_god.pyeongwan" in ids and "tag.dohwa" in ids and "role.yongsin" in ids
    assert not any(term.startswith(("color.", "direction8.", "place.")) for term in ids)


@pytest.mark.parametrize("text", ["[[편관]]이 와요", "[[도화]]가 들어요", "[[신|branch.shin]]", "[[{element}]]"])
def test_tokens_ok(text: str) -> None:
    assert token_rules(text) == []


@pytest.mark.parametrize(
    "text", ["[[신]]이 와요", "[[없음]]", "[[신|stem.unknown]]", "[[{element:color}]]", "[[{element}가 {element}]]"]
)
def test_tokens_error(text: str) -> None:
    assert token_rules(text) == [RULE_TOKEN_TERM]


def test_tokens_skip_without_glossary_for_language() -> None:
    assert token_rules("[[Seven Killings]]", "en") == []

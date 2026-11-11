# 조후 칸의 인용 선택 (#625)
import json
from pathlib import Path

from myungli_engine.domain.enums import Branch, Stem
from myungli_engine.references import loader

CHOICES = (
    Path(__file__).resolve().parents[3] / "docs" / "references" / "gungtong-bogam" / "quote-choices.json"
)


def test_chosen_quotes_are_the_cell_quotes() -> None:
    """고른 문장이 그 칸의 인용이고 원문 문단에 있다. 바꾼 뒤에는 build_evidence.py로 다시 만든다."""
    data = json.loads(CHOICES.read_text(encoding="utf-8"))
    for choice in data["choices"]:
        cell = loader.resolve(
            loader.johu_ref(Stem.from_hanja(choice["stem"]), Branch.from_hanja(choice["branch"]))
        )
        assert isinstance(cell, dict)
        assert cell["key_sentence"] == choice["quote"]
        assert choice["quote"] in "".join(cell["paragraphs"])
    chosen = {(c["stem"], c["branch"]) for c in data["choices"]}
    assert not chosen & {(u["stem"], u["branch"]) for u in data["unresolved"]}

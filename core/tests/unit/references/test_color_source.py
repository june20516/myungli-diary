# 오행 색 근거의 金=白 (#937)
import re
from pathlib import Path

from myungli_engine.references import loader
from myungli_engine.references.loader import FIVE_ELEMENTS_REF

REFERENCES = Path(__file__).resolve().parents[3] / "docs" / "references"
SKQS_VOL01 = REFERENCES / "sammyeong-tonghoe" / "skqs-vol01.wikitext"


def _flat(text: str) -> str:
    return re.sub(r"\s+", "", text)


def test_metal_white_is_in_siku_edition() -> None:
    saved = _flat(SKQS_VOL01.read_text(encoding="utf-8"))
    assert "推其形色則水黑火赤木青金白土黃此正色也" in saved


def test_gungtong_bogam_copy_lacks_metal_and_note_says_so() -> None:
    color = loader.resolve(FIVE_ELEMENTS_REF["color"])
    assert isinstance(color, dict)
    assert "金白" not in str(color["quote"])
    assert color["mapping"] == {"水": "黑", "火": "赤", "木": "青", "金": "白", "土": "黃"}
    assert "四庫全書本" in str(color["note"])

# 오행 색 근거의 金=白 (#937)
import importlib.util
import json
import re
import sys
from pathlib import Path
from types import ModuleType

from myungli_engine.references import loader
from myungli_engine.references.loader import COLOR_SHIFT_REF, FIVE_ELEMENTS_REF

REFERENCES = Path(__file__).resolve().parents[3] / "docs" / "references"
SKQS_VOL01 = REFERENCES / "sammyeong-tonghoe" / "skqs-vol01.wikitext"
DATA = REFERENCES.parents[1] / "src" / "myungli_engine" / "references" / "data"


def _builder() -> ModuleType:
    path = REFERENCES / "tools" / "build_color_source.py"
    spec = importlib.util.spec_from_file_location("build_color_source", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


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


def test_color_shift_data_matches_builder_output() -> None:
    stored = json.loads((DATA / "sammyeong_tonghoe" / "five_elements.json").read_text(encoding="utf-8"))
    assert stored == _builder().build()


def test_color_shift_quote_is_siku_text_without_small_notes() -> None:
    entry = loader.resolve(COLOR_SHIFT_REF)
    assert isinstance(entry, dict)
    saved = _flat(re.sub(r"\{\{SK ?notes\|[^}]*\}\}", "", SKQS_VOL01.read_text(encoding="utf-8")))
    assert entry["quote"] in saved
    assert str(entry["quote"]).endswith("病敗從鬼色旺墓從子色")
    assert "（少壯之年及衰老之際仰妻之時也）" in entry["passage"][0]

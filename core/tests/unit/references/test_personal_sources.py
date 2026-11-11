# 원국 개인 해석과 십성 묶음 원전 (#998, C35)
import importlib.util
import json
import re
import sys
from pathlib import Path
from types import ModuleType

from myungli_engine.domain.enums import TenGod, TenGodGroup
from myungli_engine.references import loader, sources

REFERENCES = Path(__file__).resolve().parents[3] / "docs" / "references"
DATA = REFERENCES.parents[1] / "src" / "myungli_engine" / "references" / "data"


def _builder() -> ModuleType:
    path = REFERENCES / "tools" / "build_personal_sources.py"
    spec = importlib.util.spec_from_file_location("build_personal_sources", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _flat(text: str) -> str:
    return re.sub(r"\s+", "", text)


def test_data_matches_builder() -> None:
    """원문이나 생성기를 고친 뒤 `python3 -I core/docs/references/tools/build_personal_sources.py`로 다시 만든다."""
    for directory, data in _builder().build().items():
        stored = json.loads((DATA / directory / "personal.json").read_text(encoding="utf-8"))
        assert stored == data


def test_quotes_are_in_saved_source_files() -> None:
    catalog = sources.source_catalog()
    for ref in loader.personal_refs():
        entry = loader.resolve(ref)
        assert isinstance(entry, dict)
        text = _flat((REFERENCES / str(entry["source_file"])).read_text(encoding="utf-8"))
        assert _flat(str(entry["quote"])) in text, ref
        assert str(entry["section"]) in text, ref
        assert catalog[ref]["quote"] == entry["quote"]


def test_every_ten_god_and_group_has_a_source() -> None:
    assert loader.ten_god_ref(TenGod.BIGYEON) == loader.ten_god_ref(TenGod.GEOPJAE)
    assert len({loader.ten_god_ref(god) for god in TenGod}) == 9
    assert loader.ten_god_group_ref(TenGodGroup.BIGYEOP) == loader.ten_god_ref(TenGod.BIGYEON)
    loader.validate_refs(loader.personal_refs())

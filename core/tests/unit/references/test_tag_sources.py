# 태그 판정 원전 근거 (#804, C28)
import importlib.util
import json
import sys
from pathlib import Path
from types import ModuleType

import pytest

from myungli_engine.constants.evidence_rules import RULE_DETAIL_KEYS, RULES_WITHOUT_SOURCE
from myungli_engine.references import loader, sources
from myungli_engine.rules.relations import RelationKind
from myungli_engine.rules.tags import NO_SOURCE, tag_source_ref

CORE_DIR = Path(__file__).resolve().parents[3]
REFERENCES = CORE_DIR / "docs" / "references"
DATA = CORE_DIR / "src" / "myungli_engine" / "references" / "data"


def _builder() -> ModuleType:
    path = REFERENCES / "tools" / "build_tag_sources.py"
    spec = importlib.util.spec_from_file_location("build_tag_sources", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclass가 자기 모듈을 찾는다
    spec.loader.exec_module(module)
    return module


def _without_line_breaks(text: str) -> str:
    return "".join(line.strip() for line in text.splitlines())


@pytest.mark.parametrize("ref", sorted(loader.TAG_SOURCE_REF.values()))
def test_every_tag_quote_is_verbatim_in_saved_source(ref: str) -> None:
    entry = loader.resolve(ref)
    assert isinstance(entry, dict)
    saved = _without_line_breaks((REFERENCES / str(entry["source_file"])).read_text(encoding="utf-8"))
    assert entry["passage"]
    for paragraph in entry["passage"]:
        assert paragraph in saved
    assert any(entry["quote"] in paragraph for paragraph in entry["passage"])


def test_tag_data_files_match_builder_output() -> None:
    builder = _builder()
    for entry in builder.ENTRIES:
        data_file = DATA / entry.directory.replace("-", "_") / "tags.json"
        stored = json.loads(data_file.read_text(encoding="utf-8"))
        assert stored[entry.key] == builder.build_entry(entry), entry.key


def test_tag_source_refs_point_to_tag_data() -> None:
    assert tag_source_ref("harmony", RelationKind.STEM_HAP) == "sammyeong-tonghoe/tags#stem_hap"
    assert tag_source_ref("harmony", RelationKind.BRANCH_HAP) == "sammyeong-tonghoe/tags#branch_hap"
    assert tag_source_ref("clash_day_branch") == "sammyeong-tonghoe/tags#clash_day_branch"
    assert tag_source_ref("clash_month_branch") == "jeokcheonsu/tags#clash_month_branch"
    assert tag_source_ref("cheoneul_gwiin") == "sammyeong-tonghoe/tags#cheoneul_gwiin"


def test_untagged_rush_has_no_source() -> None:
    assert tag_source_ref("ten_god_rush") == NO_SOURCE


def test_catalog_has_tag_entries_with_work_and_quote() -> None:
    catalog = sources.source_catalog()
    entry = catalog["jeokcheonsu/tags#clash_month_branch"]
    assert entry["work"] == "滴天髓"
    assert entry["section"] == "月令論"
    assert entry["quote"] == "月令提綱，譬之宅也，人元用事之神，宅之向也，不可以不卜。"
    assert entry["evidence_level"] is None
    assert set(entry) == {"work", "section", "quote", "passage", "evidence_level", "note"}


def test_empty_source_ref_is_allowed_only_for_declared_rules() -> None:
    assert RULES_WITHOUT_SOURCE <= set(RULE_DETAIL_KEYS)
    assert "tags/ten_god_rush" in RULES_WITHOUT_SOURCE
    assert "tags/clash" not in RULES_WITHOUT_SOURCE
    assert all(
        rule.startswith(("tags/", "fortune/tag", "guide/question", "calendar/score")) for rule in RULES_WITHOUT_SOURCE
    )

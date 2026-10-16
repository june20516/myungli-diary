# source_ref별 원전 이름·대목·원문 목록 (#130)
import json
from pathlib import Path

from myungli_engine.domain.enums import Branch, Stem
from myungli_engine.references import loader, sources

CORE_DIR = Path(__file__).resolve().parents[3]


def test_catalog_covers_every_engine_ref() -> None:
    catalog = sources.source_catalog()
    assert set(catalog) == set(loader.all_refs())
    assert len(catalog) == 124  # 조후 120칸 + 오행 근거 4개


def test_johu_entry_has_heading_key_sentence_and_paragraphs() -> None:
    entry = sources.source_catalog()[loader.johu_ref(Stem.GAP, Branch.IN)]
    assert entry == {
        "work": "窮通寶鑑",
        "section": "正月甲",
        "quote": "正月甲木，初春尚有余寒，得丙癸逢，富贵双全。",
        "passage": [
            "正月甲木，初春尚有余寒，得丙癸逢，富贵双全。癸藏丙透，名寒木向阳，主大富贵。倘风水不及，亦不失儒林俊秀。如无丙癸，平常人也。"
        ],
        "evidence_level": "month",
        "note": None,
    }


def test_five_elements_entry_keeps_note() -> None:
    entry = sources.source_catalog()[loader.FIVE_ELEMENTS_REF["color"]]
    assert entry["work"] == "窮通寶鑑"
    assert entry["section"] == "五行總論"
    assert str(entry["quote"]).startswith("推其形色")
    assert entry["passage"] == [entry["quote"]]
    assert entry["evidence_level"] is None
    assert "金" in str(entry["note"])


def test_exported_source_list_up_to_date() -> None:
    exported = json.loads((CORE_DIR / "evidence_sources.json").read_text(encoding="utf-8"))
    assert exported == dict(sorted(sources.source_catalog().items()))

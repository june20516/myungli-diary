"""용어 한자 표기 원고(`content/hanja.yaml`, #226) 테스트."""

import json
from pathlib import Path

import pytest

from mlw.glossary import term_ids
from mlw.hanja import (
    HANJA_FILE_NAME,
    RULE_HANJA_DUPLICATE,
    RULE_HANJA_NOT_HAN,
    RULE_HANJA_UNKNOWN,
    check_hanja,
    load_hanja,
)
from mlw.model import LoadError
from mlw.paths import CONTENT_DIR, MESSAGE_KEYS_FILE

TERM_IDS = ("stem.gap", "ten_god.siksin", "tag.dohwa")
NO_HANJA_TAGS = {
    "tag.big_change",
    "tag.clash",
    "tag.gwiin_day",
    "tag.harmony",
    "tag.ten_god_rush.bigyeop",
    "tag.ten_god_rush.gwanseong",
    "tag.ten_god_rush.inseong",
    "tag.ten_god_rush.jaeseong",
    "tag.ten_god_rush.siksang",
    "tag.yongsin_day",
}


def write(tmp_path: Path, body: str) -> Path:
    path = tmp_path / "hanja.yaml"
    path.write_text(body, encoding="utf-8")
    return path


def test_load_reads_term_and_hanja_with_lines(tmp_path: Path) -> None:
    path = write(tmp_path, '- {term: stem.gap, hanja: "甲"}\n- {term: ten_god.siksin, hanja: "食神"}\n')
    entries = load_hanja(path)
    assert [(entry.term, entry.hanja, entry.line) for entry in entries] == [
        ("stem.gap", "甲", 1),
        ("ten_god.siksin", "食神", 2),
    ]


def test_missing_file_is_empty(tmp_path: Path) -> None:
    assert load_hanja(tmp_path / "none.yaml") == []


@pytest.mark.parametrize(
    "body", ["- {term: stem.gap}\n", "- {term: stem.gap, hanja: 1}\n", '- {hanja: "甲"}\n']
)
def test_bad_entry_is_load_error(tmp_path: Path, body: str) -> None:
    with pytest.raises(LoadError):
        load_hanja(write(tmp_path, body))


def test_valid_entries_have_no_findings(tmp_path: Path) -> None:
    path = write(tmp_path, '- {term: stem.gap, hanja: "甲"}\n- {term: tag.dohwa, hanja: "桃花"}\n')
    assert check_hanja(load_hanja(path), TERM_IDS) == []


def test_unknown_duplicate_and_non_han_are_reported(tmp_path: Path) -> None:
    path = write(
        tmp_path,
        '- {term: stem.nope, hanja: "甲"}\n'
        '- {term: stem.gap, hanja: "甲"}\n'
        '- {term: stem.gap, hanja: "甲"}\n'
        '- {term: ten_god.siksin, hanja: "食신"}\n',
    )
    findings = check_hanja(load_hanja(path), TERM_IDS)
    assert [(finding.rule_id, finding.line) for finding in findings] == [
        (RULE_HANJA_UNKNOWN, 1),
        (RULE_HANJA_DUPLICATE, 3),
        (RULE_HANJA_NOT_HAN, 4),
    ]


@pytest.mark.contract
def test_repo_hanja_covers_terms_with_hanja() -> None:
    tag_keys = [
        key for key in json.loads(MESSAGE_KEYS_FILE.read_text(encoding="utf-8")) if key.startswith("tag.")
    ]
    ids = term_ids(tag_keys)
    entries = load_hanja(CONTENT_DIR / HANJA_FILE_NAME)
    assert check_hanja(entries, ids) == []
    # 날의 성격은 제품 이름이고, 신살과 같은 이름이 아닌 태그는 한자 표기가 없습니다(#226).
    without_hanja = {term for term in ids if term.startswith("day_kind.")} | NO_HANJA_TAGS
    assert {entry.term for entry in entries} == set(ids) - without_hanja

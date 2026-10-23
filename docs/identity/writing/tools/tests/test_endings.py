"""맺음 현황 보고(W43) 테스트."""

import json
from pathlib import Path

import pytest

from mlw.cli import main
from mlw.endings import COMMON_SCREEN, classify, ending_rows, screen_counts, split_sentences
from mlw.ia import Ia, load_ia
from mlw.model import Entry, Slot

IA_DATA = {
    "version": 1,
    "components": [{"id": "toast", "role": "알림"}],
    "screens": [
        {"id": "calc-basis", "slots": [{"id": "calc-basis.daeun.body", "source": "ui", "role": "대운수"}]},
        {"id": "today", "slots": [{"id": "today.head", "source": "content", "role": "총운"}]},
    ],
}


@pytest.fixture
def ia(tmp_path: Path) -> Ia:
    path = tmp_path / "screens.json"
    path.write_text(json.dumps(IA_DATA), encoding="utf-8")
    return load_ia(path)


def make_slot(slot_id: str, group: str, ia_ids: tuple[str, ...] = ()) -> Slot:
    return Slot(
        id=slot_id,
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"k": {}},
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path(f"slots/{group}/test.yaml"),
        ia=ia_ids,
    )


def make_entry(slot: str, text: str, lang: str = "ko") -> Entry:
    return Entry(Path(f"content/{lang}/ui.yaml"), 1, slot, "k", None, 1, lang, text)


def test_split_sentences_keeps_each_ending() -> None:
    assert split_sentences("음력을 따라요. 대운수는 개월을 버리고 셉니다.") == [
        "음력을 따라요.",
        "대운수는 개월을 버리고 셉니다.",
    ]
    assert split_sentences("정말 지울까요? 되돌릴 수 없어요") == ["정말 지울까요?", "되돌릴 수 없어요"]


@pytest.mark.parametrize(
    ("sentence", "kind"),
    [
        ("되돌릴 수 없어요.", "haeyo"),
        ("다시 시도해 주세요", "haeyo"),
        ("정말 지울까요?", "haeyo"),
        ("괜찮죠?", "haeyo"),
        ("개월을 버리고 셉니다.", "hamnida"),
        ("좋습니까?", "hamnida"),
        ("계정 삭제", "other"),
        ("{date}까지 광고 없이 볼 수 있어요", "haeyo"),
        ("{start}~{end}", "other"),
    ],
)
def test_classify_reads_sentence_end(sentence: str, kind: str) -> None:
    assert classify(sentence) == kind


def test_rows_group_by_ia_screen_and_common(ia: Ia) -> None:
    slots = {
        "calc-basis.daeun.body": make_slot("calc-basis.daeun.body", "ui"),
        "today.sentence": make_slot("today.sentence", "content", ("today.head",)),
        "ui.error.code": make_slot("ui.error.code", "ui"),
    }
    entries = [
        make_entry("calc-basis.daeun.body", "대운수는 개월을 버리고 셉니다."),
        make_entry("today.sentence", "오늘은 맑아요. 쉬어 가요."),
        make_entry("ui.error.code", "다시 시도해 주세요."),
        make_entry("ui.error.code", "Please try again.", lang="en"),
    ]
    rows = ending_rows(entries, slots, ia)
    assert [(row.screen, row.kind) for row in rows] == [
        ("calc-basis", "hamnida"),
        ("today", "haeyo"),
        ("today", "haeyo"),
        (COMMON_SCREEN, "haeyo"),
    ]
    counts = screen_counts(rows)
    assert counts["today"]["haeyo"] == 2
    assert counts["calc-basis"]["hamnida"] == 1


def test_endings_command_reports_without_failing(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["endings"]) == 0
    out = capsys.readouterr().out
    assert "calc-basis" in out
    assert "합니다체" in out


def test_endings_command_lists_one_screen(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["endings", "--screen", "calc-basis"]) == 0
    out = capsys.readouterr().out
    # 원고 문구에 묶이지 않게 줄 형식과 맺음 판정만 봅니다.
    assert any(line.startswith("[합니다체] calc-basis.daeun.body calcBasisDaeunBody: ") for line in out.splitlines())
    assert "today" not in out

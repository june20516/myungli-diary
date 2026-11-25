"""원어민 검수 시트 xlsx 입출력 테스트(#1283)."""

from pathlib import Path

import openpyxl
import pytest

from mlw.review.sheet import (
    TIERS,
    ReviewRow,
    SheetError,
    SheetMeta,
    read_sheet,
    write_results,
    write_sheet,
)

META = SheetMeta(lang="en", commit="a" * 40, exported="2026-11-26", tool_version="0.16.0")
GUIDE = ("First paragraph.", "Second paragraph.")
STORE_ROW = ReviewRow(
    id="store.subtitle|subtitle||1",
    key="subtitle",
    bundle="store",
    place="스토어 부제\n최대 30자",
    source="오늘을 읽는 명리 일기",
    current='Say "hi"\nthen go',
    example='Say "hi"\nthen go',
)
UI_ROW = ReviewRow(
    id="welcome.cta.start|welcomeCtaStart||1",
    key="welcomeCtaStart",
    bundle="ui",
    place="첫 화면 버튼\n최대 12자",
    source="시작하기",
    current="Get started",
    example="Get started",
)


def write_default(path: Path) -> None:
    write_sheet(path, META, GUIDE, {"store": [STORE_ROW], "ui": [UI_ROW]})


def column_of(sheet: openpyxl.worksheet.worksheet.Worksheet, korean: str) -> int:
    for cell in sheet[1]:
        if isinstance(cell.value, str) and cell.value.endswith(f"({korean})"):
            return cell.column
    raise AssertionError(korean)


def test_tiers() -> None:
    assert TIERS == {
        1: ("store", "ui", "system", "web"),
        2: ("daily-fortune", "daily-cards", "daily-reasons", "personal", "calendar", "chart"),
        3: ("term", "glossary", "evidence", "source"),
    }


def test_round_trip(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    meta, rows = read_sheet(path)
    assert meta == META
    assert sorted(rows, key=lambda row: row.id) == sorted([STORE_ROW, UI_ROW], key=lambda row: row.id)


def test_tabs_and_hidden(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    book = openpyxl.load_workbook(path)
    assert book.sheetnames == ["Guide (안내)", "store", "ui", "_meta"]
    assert book["_meta"].sheet_state == "hidden"
    store = book["store"]
    assert store.column_dimensions["A"].hidden is True
    assert store.freeze_panes == "A2"
    assert book["Guide (안내)"]["A1"].value == "First paragraph."
    assert book["Guide (안내)"]["A2"].value == "Second paragraph."


def test_category_dropdown(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    store = openpyxl.load_workbook(path)["store"]
    formula = store.data_validations.dataValidation[0].formula1
    assert formula == '"Mistranslation (오역),Unnatural (어색함),Grammar (문법),Terminology (용어)"'


def edit(path: Path, bundle: str, korean: str, value: object, row: int = 2) -> None:
    book = openpyxl.load_workbook(path)
    sheet = book[bundle]
    sheet.cell(row=row, column=column_of(sheet, korean), value=value)
    book.save(path)


def suggestion_of(path: Path, row_id: str) -> str:
    _, rows = read_sheet(path)
    return next(row.suggestion for row in rows if row.id == row_id)


def test_read_by_header_name(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    book = openpyxl.load_workbook(path)
    sheet = book["ui"]
    suggestion, memo = column_of(sheet, "수정안"), column_of(sheet, "메모")
    for row in range(1, 3):
        a, b = sheet.cell(row=row, column=suggestion), sheet.cell(row=row, column=memo)
        a.value, b.value = b.value, a.value
    sheet.cell(row=2, column=suggestion, value="note")
    sheet.cell(row=2, column=memo, value="Start")
    book.save(path)
    _, rows = read_sheet(path)
    row = next(row for row in rows if row.id == UI_ROW.id)
    assert (row.suggestion, row.memo) == ("Start", "note")


def test_read_sorted_rows(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    second = ReviewRow(**{**UI_ROW.__dict__, "id": "x|y||1", "current": "Other"})
    write_sheet(path, META, GUIDE, {"ui": [UI_ROW, second]})
    book = openpyxl.load_workbook(path)
    sheet = book["ui"]
    for column in range(1, sheet.max_column + 1):
        top, bottom = sheet.cell(row=2, column=column), sheet.cell(row=3, column=column)
        top.value, bottom.value = bottom.value, top.value
    book.save(path)
    _, rows = read_sheet(path)
    assert {row.id: row.current for row in rows} == {UI_ROW.id: "Get started", "x|y||1": "Other"}


@pytest.mark.parametrize(("value", "expected"), [(3, "3"), (2.5, "2.5"), (10.0, "10")])
def test_numeric_suggestion(tmp_path: Path, value: object, expected: str) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    edit(path, "ui", "수정안", value)
    assert suggestion_of(path, UI_ROW.id) == expected


@pytest.mark.parametrize(("value", "expected"), [("  Hello\n", "Hello"), ("a\nb", "a\nb")])
def test_strip_suggestion(tmp_path: Path, value: str, expected: str) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    edit(path, "ui", "수정안", value)
    assert suggestion_of(path, UI_ROW.id) == expected


def test_results_column(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    edit(path, "ui", "메모", "keep me")
    result = tmp_path / "s-result.xlsx"
    write_results(path, result, {UI_ROW.id: "반영함", STORE_ROW.id: "반영 안 함: 변경 없음"})
    book = openpyxl.load_workbook(result)
    for bundle, expected in (("ui", "반영함"), ("store", "반영 안 함: 변경 없음")):
        sheet = book[bundle]
        assert sheet.cell(row=1, column=sheet.max_column).value == "Result (반영 결과)"
        assert sheet.cell(row=2, column=sheet.max_column).value == expected
    ui = book["ui"]
    assert ui.cell(row=2, column=column_of(ui, "메모")).value == "keep me"


def test_missing_meta(tmp_path: Path) -> None:
    path = tmp_path / "s.xlsx"
    write_default(path)
    book = openpyxl.load_workbook(path)
    del book["_meta"]
    book.save(path)
    with pytest.raises(SheetError):
        read_sheet(path)


def test_not_a_workbook(tmp_path: Path) -> None:
    path = tmp_path / "bad.xlsx"
    path.write_text("not a workbook", encoding="utf-8")
    with pytest.raises(SheetError):
        read_sheet(path)

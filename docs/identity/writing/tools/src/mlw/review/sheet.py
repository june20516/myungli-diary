"""원어민 검수 시트(xlsx) 입출력입니다(#1283, W84).

원고 모델에 의존하지 않습니다. 칸은 머리의 괄호 안 한국어 이름으로 찾으므로, 감수자가 Google Sheets에서
행을 정렬하거나 칸 순서를 바꿔도 읽힙니다.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, fields
from pathlib import Path
from typing import Final

import openpyxl
from openpyxl.styles import Alignment, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.worksheet import Worksheet

# 차수 -> 묶음(대상 언어 원고 파일 이름) 순서입니다(spec §3).
TIERS: Final[dict[int, tuple[str, ...]]] = {
    1: ("store", "ui", "system", "web"),
    2: ("daily-fortune", "daily-cards", "daily-reasons", "personal", "calendar", "chart"),
    3: ("term", "glossary", "evidence", "source"),
}

META_SHEET: Final = "_meta"
GUIDE_KOREAN: Final = "안내"
RESULT_KOREAN: Final = "반영 결과"


class SheetError(Exception):
    """검수 시트를 읽을 수 없습니다(탭이나 칸 머리 없음)."""


@dataclass(frozen=True)
class ReviewRow:
    """검수 시트 한 행입니다. 원고 한 줄(ICU 전개 전)에 대응합니다."""

    id: str
    key: str
    bundle: str
    place: str
    source: str
    current: str
    example: str
    suggestion: str = ""
    category: str = ""
    memo: str = ""
    verdict: str = ""


@dataclass(frozen=True)
class SheetMeta:
    lang: str
    commit: str
    exported: str
    tool_version: str


@dataclass(frozen=True)
class _Column:
    field: str
    korean: str
    width: int
    editable: bool


_COLUMNS: Final = (
    _Column("id", "id", 10, False),
    _Column("key", "키", 28, False),
    _Column("bundle", "묶음", 12, False),
    _Column("place", "자리 설명", 36, False),
    _Column("source", "한국어 원문", 48, False),
    _Column("current", "현재 번역", 48, False),
    _Column("example", "예시", 48, False),
    _Column("suggestion", "수정안", 48, True),
    _Column("category", "분류", 18, True),
    _Column("memo", "메모", 36, True),
    _Column("verdict", "writing 판정", 28, True),
)
_EDITABLE_FIELDS: Final = frozenset(column.field for column in _COLUMNS if column.editable)

# 감수자 언어 칸 머리입니다. 머리는 `감수자 언어 (한국어)` 형식이고, id 칸만 그대로 `id`입니다.
_HEADERS: Final[dict[str, dict[str, str]]] = {
    "en": {
        "키": "Key",
        "묶음": "Bundle",
        "자리 설명": "Where it appears",
        "한국어 원문": "Korean original",
        "현재 번역": "Current translation",
        "예시": "Example",
        "수정안": "Suggestion",
        "분류": "Category",
        "메모": "Note",
        "writing 판정": "Writer decision",
        GUIDE_KOREAN: "Guide",
        RESULT_KOREAN: "Result",
    },
    "ja": {
        "키": "キー",
        "묶음": "まとまり",
        "자리 설명": "表示場所",
        "한국어 원문": "韓国語原文",
        "현재 번역": "現在の訳",
        "예시": "例",
        "수정안": "修正案",
        "분류": "分類",
        "메모": "メモ",
        "writing 판정": "ライター判断",
        GUIDE_KOREAN: "ガイド",
        RESULT_KOREAN: "結果",
    },
}

# 분류 값(오역, 어색함, 문법, 용어)의 감수자 언어 표기입니다.
CATEGORIES: Final[dict[str, tuple[str, ...]]] = {
    "en": ("Mistranslation (오역)", "Unnatural (어색함)", "Grammar (문법)", "Terminology (용어)"),
    "ja": ("誤訳 (오역)", "不自然 (어색함)", "文法 (문법)", "用語 (용어)"),
}

_LOCKED_FILL: Final = PatternFill(fill_type="solid", start_color="F2F2F2", end_color="F2F2F2")
_WRAP: Final = Alignment(wrap_text=True, vertical="top")
_GUIDE_WIDTH: Final = 100
_META_FIELDS: Final = tuple(field.name for field in fields(SheetMeta))


def _header(lang: str, korean: str) -> str:
    if korean == "id":
        return "id"
    return f"{_HEADERS[lang][korean]} ({korean})"


def _korean_of(header: object) -> str | None:
    """칸 머리의 괄호 안 한국어 이름입니다. id 칸은 `id`입니다."""
    if not isinstance(header, str):
        return None
    text = header.strip()
    if text == "id":
        return "id"
    if text.endswith(")") and "(" in text:
        return text[text.rindex("(") + 1 : -1].strip()
    return None


def _guide_title(lang: str) -> str:
    return _header(lang, GUIDE_KOREAN)


def _write_guide(sheet: Worksheet, guide: Sequence[str]) -> None:
    sheet.column_dimensions["A"].width = _GUIDE_WIDTH
    for index, paragraph in enumerate(guide, start=1):
        cell = sheet.cell(row=index, column=1, value=paragraph)
        cell.alignment = _WRAP


def _write_bundle(sheet: Worksheet, lang: str, rows: Sequence[ReviewRow]) -> None:
    for index, column in enumerate(_COLUMNS, start=1):
        letter = get_column_letter(index)
        sheet.column_dimensions[letter].width = column.width
        header = sheet.cell(row=1, column=index, value=_header(lang, column.korean))
        header.alignment = _WRAP
        for row_number, row in enumerate(rows, start=2):
            cell = sheet.cell(row=row_number, column=index, value=getattr(row, column.field) or None)
            cell.alignment = _WRAP
            if not column.editable:
                cell.fill = _LOCKED_FILL
    sheet.column_dimensions["A"].hidden = True
    sheet.freeze_panes = "A2"
    category = get_column_letter(next(i for i, c in enumerate(_COLUMNS, start=1) if c.field == "category"))
    validation = DataValidation(type="list", formula1=f'"{",".join(CATEGORIES[lang])}"', allow_blank=True)
    validation.add(f"{category}2:{category}{max(len(rows) + 1, 2)}")
    sheet.add_data_validation(validation)


def _write_meta(sheet: Worksheet, meta: SheetMeta) -> None:
    for index, name in enumerate(_META_FIELDS, start=1):
        sheet.cell(row=index, column=1, value=name)
        sheet.cell(row=index, column=2, value=getattr(meta, name))
    sheet.sheet_state = "hidden"


def write_sheet(
    path: Path, meta: SheetMeta, guide: Sequence[str], rows_by_bundle: Mapping[str, Sequence[ReviewRow]]
) -> None:
    """안내 탭, 묶음 탭(주어진 순서), 숨긴 `_meta` 탭으로 시트를 씁니다."""
    book = openpyxl.Workbook()
    guide_sheet = book.active
    assert guide_sheet is not None
    guide_sheet.title = _guide_title(meta.lang)
    _write_guide(guide_sheet, guide)
    for bundle, rows in rows_by_bundle.items():
        _write_bundle(book.create_sheet(bundle), meta.lang, rows)
    _write_meta(book.create_sheet(META_SHEET), meta)
    path.parent.mkdir(parents=True, exist_ok=True)
    book.save(path)


def _cell_text(value: object) -> str:
    """셀 값을 문자열로 읽습니다. Sheets가 숫자 셀로 바꾼 값도 원래 글자로 돌립니다."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return str(value).upper()
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def _is_guide(title: str) -> bool:
    return title.endswith(f"({GUIDE_KOREAN})")


def _read_meta(book: openpyxl.Workbook) -> SheetMeta:
    if META_SHEET not in book.sheetnames:
        raise SheetError(f"`{META_SHEET}` 탭이 없습니다. writing이 내보낸 시트인지 확인하세요")
    sheet = book[META_SHEET]
    values = {_cell_text(row[0]): _cell_text(row[1]) for row in sheet.iter_rows(values_only=True) if len(row) >= 2}
    missing = [name for name in _META_FIELDS if name not in values]
    if missing:
        raise SheetError(f"`{META_SHEET}` 탭에 {', '.join(missing)} 값이 없습니다")
    return SheetMeta(**{name: values[name] for name in _META_FIELDS})


def _column_map(sheet: Worksheet) -> dict[str, int]:
    """필드 이름 -> 열 번호(1부터)입니다."""
    by_korean = {column.korean: column.field for column in _COLUMNS}
    found: dict[str, int] = {}
    for cell in sheet[1]:
        korean = _korean_of(cell.value)
        if korean in by_korean and cell.column is not None:
            found[by_korean[korean]] = cell.column
    missing = [column.korean for column in _COLUMNS if column.field not in found]
    if missing:
        raise SheetError(f"`{sheet.title}` 탭에 칸이 없습니다: {', '.join(missing)}")
    return found


def _read_bundle(sheet: Worksheet) -> list[ReviewRow]:
    columns = _column_map(sheet)
    rows: list[ReviewRow] = []
    for values in sheet.iter_rows(min_row=2, values_only=True):
        cells = {name: _cell_text(values[index - 1]) if index - 1 < len(values) else "" for name, index in columns.items()}
        if not cells["id"].strip():
            continue
        rows.append(
            ReviewRow(**{name: text.strip() if name in _EDITABLE_FIELDS else text for name, text in cells.items()})
        )
    return rows


def _bundle_sheets(book: openpyxl.Workbook) -> list[Worksheet]:
    return [book[title] for title in book.sheetnames if title != META_SHEET and not _is_guide(title)]


def read_sheet(path: Path) -> tuple[SheetMeta, list[ReviewRow]]:
    """메타와 모든 묶음 탭의 행입니다. 감수자가 고치는 칸은 앞뒤 공백을 지웁니다."""
    book = openpyxl.load_workbook(path)
    meta = _read_meta(book)
    rows = [row for sheet in _bundle_sheets(book) for row in _read_bundle(sheet)]
    return meta, rows


def write_results(src: Path, dst: Path, results: Mapping[str, str]) -> None:
    """받은 시트의 묶음 탭마다 끝에 `반영 결과` 칸을 더해 `dst`로 씁니다. 다른 칸은 건드리지 않습니다."""
    book = openpyxl.load_workbook(src)
    meta = _read_meta(book)
    for sheet in _bundle_sheets(book):
        id_column = _column_map(sheet)["id"]
        column = sheet.max_column + 1
        sheet.cell(row=1, column=column, value=_header(meta.lang, RESULT_KOREAN)).alignment = _WRAP
        sheet.column_dimensions[get_column_letter(column)].width = 36
        for row_number in range(2, sheet.max_row + 1):
            row_id = _cell_text(sheet.cell(row=row_number, column=id_column).value)
            if row_id in results:
                sheet.cell(row=row_number, column=column, value=results[row_id]).alignment = _WRAP
    dst.parent.mkdir(parents=True, exist_ok=True)
    book.save(dst)

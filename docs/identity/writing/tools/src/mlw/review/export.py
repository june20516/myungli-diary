"""원고에서 검수 시트 행을 만듭니다(#1283, spec §4.2, §4.3)."""

from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Final

from mlw.icu import parse_plural
from mlw.model import LENGTH_UNIT_BYTES, UNBOUNDED, Entry, ParamKind, Slot
from mlw.placeholders import Placeholder, strip_token_marks, substitute
from mlw.review.sheet import TIERS, ReviewRow
from mlw.terms import GLOSSARY_SLOT

SOURCE_LANG: Final = "ko"
REVIEW_LANGS: Final = ("en", "ja")
NAME_PARAM: Final = "name"
# 예시 칸의 호칭 표본입니다. 각 언어 원고 `onboardCallInputHint`의 예 이름과 같습니다.
SAMPLE_NAMES: Final[dict[str, str]] = {"en": "Alex", "ja": "ゆき"}
SAMPLE_NUMBER: Final = "3"
# ICU 복수형 `one` 형태에 넣는 숫자입니다. 다른 형태는 SAMPLE_NUMBER를 씁니다.
ONE_FORM: Final = "one"
ONE_NUMBER: Final = "1"
# `text` 자리표시자(렌더하는 쪽이 만든 문자열)의 표본입니다. 표기는 원고와 용어집 값을 따릅니다(예: 지지는 en 띠 이름,
# ja 한자). 가격은 공개 저장소에 수치를 적지 않으므로(D74) 표본을 두지 않고 `‹price›`로 남깁니다.
PRICE_PARAM: Final = "price"
SAMPLE_TEXT: Final[dict[str, dict[str, str]]] = {
    "after": {"en": "May 12, 1990, 3:30 PM", "ja": "1990年5月12日 15:30"},
    "before": {"en": "May 12, 1990, 2:30 PM", "ja": "1990年5月12日 14:30"},
    "branch": {"en": "Horse", "ja": "午"},
    "calendar": {"en": "Solar", "ja": "新暦"},
    "date": {"en": "May 12", "ja": "5月12日"},
    "day_branch": {"en": "Horse", "ja": "午"},
    "day_stem": {"en": "Gapmok", "ja": "甲"},
    "degrees": {"en": "126.98", "ja": "126.98"},
    "element": {"en": "Wood", "ja": "木"},
    "email": {"en": "help@example.com", "ja": "help@example.com"},
    "end": {"en": "June 12, 2026", "ja": "2026年6月12日"},
    "longitude": {"en": "126.98°E", "ja": "東経126.98°"},
    "minute": {"en": "30", "ja": "30"},
    "month_branch": {"en": "Horse", "ja": "午"},
    "nickname": {"en": "Alex", "ja": "ゆき"},
    "pillar": {"en": "癸未", "ja": "癸未"},
    "provider": {"en": "Google", "ja": "Google"},
    "reading": {"en": "Gye Mi", "ja": "みずのとひつじ"},
    "start": {"en": "May 12, 2026", "ja": "2026年5月12日"},
    "status": {"en": "Next", "ja": "次"},
    "stem": {"en": "Gye", "ja": "みずのと"},
    "stemName": {"en": "Gyeonggeum", "ja": "庚"},
    "subject": {"en": "today's color", "ja": "今日の色"},
    "tag": {"en": "Exercise", "ja": "運動"},
    "term": {"en": "Bigyeop", "ja": "比劫"},
    "time": {"en": "9:30 AM", "ja": "9:30"},
    "title": {"en": "Lunch with Mina", "ja": "ミナとランチ"},
    "traceId": {"en": "7F3A-21C9", "ja": "7F3A-21C9"},
    "weight": {"en": "30%", "ja": "30%"},
}
# 같은 이름이 키마다 다른 값을 받는 자리입니다(키 -> 이름 -> 언어 -> 표본).
SAMPLE_TEXT_BY_KEY: Final[dict[str, dict[str, dict[str, str]]]] = {
    "onboardTimeHourConfirm": {
        "start": {"en": "11:30 AM", "ja": "11:30"},
        "end": {"en": "1:29 PM", "ja": "13:29"},
    },
    "ganjiReading": {"branch": {"en": "Mi", "ja": "ひつじ"}},
    "sajuChartManseBasisStemSuffix": {"reading": {"en": "Gyeong", "ja": "かのえ"}},
}
LIST_SAMPLE_ITEMS: Final = 2
LIST_SEPARATOR: Final = ", "

_ContentKey = tuple[str, str, str | None, int]


def read_guide(path: Path) -> list[str]:
    """감수자 안내 원문을 빈 줄로 나눈 문단 목록으로 읽습니다. 문단 하나가 안내 탭 셀 하나입니다."""
    text = path.read_text(encoding="utf-8")
    return [paragraph.strip() for paragraph in text.split("\n\n") if paragraph.strip()]


def sheet_name(tier: int | None, bundles: Sequence[str]) -> str:
    """빈 시트 파일 이름입니다: 차수면 `tier<n>.xlsx`, 묶음 목록이면 `<묶음>-<묶음>.xlsx`."""
    return f"tier{tier}.xlsx" if tier is not None else f"{'-'.join(bundles)}.xlsx"


def row_id(entry: Entry) -> str:
    """시트 숨김 칸 `id`입니다. 다시 읽을 때 원고 줄을 이 값으로 찾습니다."""
    return f"{entry.slot}|{entry.key}|{entry.type or ''}|{entry.variant}"


def _content_key(entry: Entry) -> _ContentKey:
    return (entry.slot, entry.key, entry.type, entry.variant)


def bundle_of(entry: Entry) -> str:
    return entry.file.stem


def _all_bundles() -> tuple[str, ...]:
    return tuple(bundle for bundles in TIERS.values() for bundle in bundles)


def bundles_for(tier: int | None, bundles: Sequence[str] | None) -> tuple[str, ...]:
    """차수 또는 묶음 목록 중 하나로 내보낼 묶음을 정합니다. 둘 다 주거나 둘 다 없거나 모르는 값이면 ValueError입니다."""
    if (tier is None) == (bundles is None):
        raise ValueError("--tier와 --bundle 중 하나만 주세요")
    if tier is not None:
        if tier not in TIERS:
            raise ValueError(f"차수는 {', '.join(map(str, TIERS))} 중 하나입니다: {tier}")
        return TIERS[tier]
    assert bundles is not None
    unknown = [bundle for bundle in bundles if bundle not in _all_bundles()]
    if unknown or not bundles:
        raise ValueError(f"차수 표에 없는 묶음입니다: {', '.join(unknown) or '(빈 목록)'}")
    return tuple(bundles)


def check_tier_coverage(content_dir: Path, lang: str) -> list[str]:
    """원고 파일과 차수 표가 어긋나는 묶음 이름입니다(파일에만 있거나 표에만 있음). 비어야 정상입니다."""
    files = {path.stem for path in (content_dir / lang).glob("*.yaml")}
    return sorted(files.symmetric_difference(_all_bundles()))


def glossary_by_category(entries: Sequence[Entry], lang: str) -> dict[str, tuple[str, ...]]:
    """같은 언어 값 이름 원고를 범주(키 `<범주>.<값>`의 앞부분)별로 원고 순서대로 모읍니다."""
    by_category: dict[str, list[str]] = {}
    for entry in entries:
        if entry.slot == GLOSSARY_SLOT and entry.lang == lang:
            by_category.setdefault(entry.key.split(".")[0], []).append(entry.text)
    return {category: tuple(texts) for category, texts in by_category.items()}


def _korean_limit(value: int | str | None, bytes_unit: bool, max_lines: int | None) -> str:
    if value is None:
        return "상한 미정"
    if value == UNBOUNDED:
        return "상한 없음"
    lines = f", {max_lines}줄" if max_lines is not None else ""
    return f"최대 {value}{'바이트' if bytes_unit else '자'}{lines}"


def _local_limit(lang: str, value: int | str | None, bytes_unit: bool, max_lines: int | None) -> str:
    if lang == "ja":
        if value is None:
            return "上限未定"
        if value == UNBOUNDED:
            return "上限なし"
        lines = f"、{max_lines}行" if max_lines is not None else ""
        return f"最大{value}{'バイト' if bytes_unit else '文字'}{lines}"
    if value is None:
        return "Limit not set yet"
    if value == UNBOUNDED:
        return "No limit"
    lines = f", {max_lines} lines" if max_lines is not None else ""
    return f"Max {value} {'bytes' if bytes_unit else 'characters'}{lines}"


def _limit_text(slot: Slot, lang: str, key: str) -> str:
    """그 언어 글자 상한을 `감수자 언어 (한국어)` 형식으로 씁니다."""
    limits = slot.key_max_length.get(key, {})
    value = limits[lang] if lang in limits else slot.max_length.get(lang)
    bytes_unit = slot.length_unit == LENGTH_UNIT_BYTES
    local = _local_limit(lang, value, bytes_unit, slot.max_lines)
    return f"{local} ({_korean_limit(value, bytes_unit, slot.max_lines)})"


def place_text(slot: Slot, lang: str, key: str) -> str:
    """`자리 설명` 칸입니다: 슬롯 `where`(한국어 원문), 줄 바꾸고 그 언어 글자 상한."""
    return f"{slot.where}\n{_limit_text(slot, lang, key)}"


def _raw(placeholder: Placeholder) -> str:
    return "{" + placeholder.key + "}"


def _text_sample(name: str, key: str, lang: str) -> str:
    by_key = SAMPLE_TEXT_BY_KEY.get(key, {}).get(name, {})
    sample = by_key.get(lang) or SAMPLE_TEXT.get(name, {}).get(lang)
    return sample if sample is not None else f"‹{name}›"


def _sample_value(
    placeholder: Placeholder,
    params: Mapping[str, ParamKind],
    glossary: Mapping[str, Sequence[str]],
    lang: str,
    number: str,
    key: str,
) -> str:
    kind = params.get(placeholder.name)
    if kind is None:
        if placeholder.name == NAME_PARAM and placeholder.category is None:
            return SAMPLE_NAMES.get(lang, _raw(placeholder))
        return _raw(placeholder)
    if kind.kind == "glossary":
        values = glossary.get(placeholder.category or kind.default_category or "", ())
        return values[0] if values else _raw(placeholder)
    if kind.kind == "list":
        values = glossary.get(kind.default_category or "", ())
        return LIST_SEPARATOR.join(values[:LIST_SAMPLE_ITEMS]) if values else _raw(placeholder)
    if kind.kind == "number":
        return number
    if kind.kind == "text":
        return _text_sample(placeholder.name, key, lang)
    return _raw(placeholder)


def _filled(
    text: str, params: Mapping[str, ParamKind], glossary: Mapping[str, Sequence[str]], entry: Entry, number: str
) -> str:
    try:
        return substitute(
            text, lambda placeholder: _sample_value(placeholder, params, glossary, entry.lang, number, entry.key)
        )
    except ValueError:
        return text


def _example(entry: Entry, slot: Slot, glossary: Mapping[str, Sequence[str]]) -> str:
    params = slot.keys.get(entry.key, {})
    try:
        text = strip_token_marks(entry.text)
    except ValueError:
        return entry.text
    try:
        plural = parse_plural(text)
    except ValueError:
        plural = None
    if plural is None:
        return _filled(text, params, glossary, entry, SAMPLE_NUMBER)
    lines = []
    for form, sentence in plural.forms.items():
        number = ONE_NUMBER if form == ONE_FORM else SAMPLE_NUMBER
        lines.append(_filled(plural.prefix + sentence + plural.suffix, params, glossary, entry, number))
    return "\n".join(lines)


def example_text(entry: Entry, slot: Slot, glossary: Mapping[str, Sequence[str]]) -> str:
    """`예시` 칸입니다. 자리표시자를 표본 값으로 채우고 용어 토큰 표시를 뺍니다. 복수형은 형태마다 한 줄입니다.

    채울 것이 없어 현재 번역과 같으면 빈 값입니다. 그래야 예시가 있는 줄이 "자리표시자가 있는 줄"로 눈에 띕니다.
    """
    example = _example(entry, slot, glossary)
    return "" if example == entry.text else example


def build_rows(
    entries: Sequence[Entry], slots: Mapping[str, Slot], lang: str, bundles: Sequence[str]
) -> dict[str, list[ReviewRow]]:
    """묶음 -> 원고 순서 행입니다. 주어진 묶음 순서를 지키고, 원고가 없는 묶음은 빈 목록입니다."""
    sources = {_content_key(entry): entry.text for entry in entries if entry.lang == SOURCE_LANG}
    glossary = glossary_by_category(entries, lang)
    rows: dict[str, list[ReviewRow]] = {bundle: [] for bundle in bundles}
    for entry in entries:
        bundle = bundle_of(entry)
        if entry.lang != lang or bundle not in rows:
            continue
        slot = slots.get(entry.slot)
        rows[bundle].append(
            ReviewRow(
                id=row_id(entry),
                key=entry.key if entry.type is None else f"{entry.key} / {entry.type} #{entry.variant}",
                bundle=bundle,
                place=place_text(slot, lang, entry.key) if slot is not None else "",
                source=sources.get(_content_key(entry), ""),
                current=entry.text,
                example=example_text(entry, slot, glossary) if slot is not None else "",
            )
        )
    return rows

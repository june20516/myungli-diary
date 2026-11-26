"""숫자, 자유 글(`number`, `text`) 자리표시자의 가장 긴 렌더 값입니다(W85).

글자 수 상한 검사는 자리표시자를 가장 긴 값으로 바꿔 잽니다. 용어집 값은 원고에서 구하지만, 숫자와
app이 만드는 문자열(날짜, 시각, 경도)은 원고에 없으므로 여기 표에서 구합니다. 표에 없거나 길이를 정할 수
없는 값(사용자가 쓴 일정 제목 등)이 있는 원고는 글자 수 검사를 건너뜁니다.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

from mlw.model import Entry

GLOSSARY_SLOT = "glossary.value_name"
ALL_LANGS = "*"


@dataclass(frozen=True)
class Fixed:
    """정한 값입니다. `by_lang`은 언어 -> 값이고, `*`는 모든 언어에 같은 값입니다."""

    by_lang: Mapping[str, str]


@dataclass(frozen=True)
class FromGlossary:
    """용어집 범주들의 이름 중 가장 긴 것입니다."""

    categories: tuple[str, ...]


@dataclass(frozen=True)
class FromKeys:
    """같은 언어 원고 키들의 글 중 가장 긴 것입니다."""

    keys: tuple[str, ...]


@dataclass(frozen=True)
class Unmeasured:
    """길이를 정할 수 없어 재지 않는 값입니다. 그 원고의 글자 수 검사는 건너뜁니다."""

    reason: str


Source = Fixed | FromGlossary | FromKeys | Unmeasured


def _same(value: str) -> Fixed:
    return Fixed({ALL_LANGS: value})


# 날짜, 시각 서식별 가장 긴 값입니다.
MONTH_DAY = Fixed({"ko": "12월 31일", "en": "September 30", "ja": "12月31日"})
FULL_DATE = Fixed({"ko": "2026년 12월 31일", "en": "September 30, 2026", "ja": "2026年12月31日"})
SHORT_DATE = Fixed({"ko": "2026. 12. 31.", "en": "12/31/2026", "ja": "2026/12/31"})
CLOCK_TIME = Fixed({"ko": "오후 12:59", "en": "12:59 PM", "ja": "23:59"})
COUNT = _same("9999")
SMALL_COUNT = _same("10")
YEAR = _same("2099")
AGE = _same("100")
# 문의 번호는 32자리 hex입니다. 글자 수만 쓰므로 W3C trace-context 예시 값을 씁니다(design V138).
TRACE_ID = _same("4bf92f3577b34da6a3ce929d0e0e4736")
USER_TEXT = Unmeasured("사용자가 쓴 글이라 길이를 정할 수 없습니다")
TAG_CATEGORIES = ("day_kind", "ten_god_group", "relation", "shinsal")

# 매개변수 이름 -> 값 출처입니다. 슬롯마다 서식이 다르면 SLOT_PARAM_SOURCES가 덮어씁니다.
PARAM_SOURCES: dict[str, Source] = {
    # 숫자
    "count": COUNT,
    "days": _same("365"),
    "day": _same("31"),
    "month": _same("12"),
    "year": YEAR,
    "startYear": YEAR,
    "endYear": YEAR,
    "hour": _same("23"),
    "minutes": _same("59"),
    "dstMinutes": _same("60"),
    "age": AGE,
    "startAge": AGE,
    "endAge": AGE,
    "score": _same("100"),
    "number": SMALL_COUNT,
    "key": SMALL_COUNT,
    "index": SMALL_COUNT,
    "total": SMALL_COUNT,
    "step": SMALL_COUNT,
    "stepCount": SMALL_COUNT,
    "current": SMALL_COUNT,
    "max": SMALL_COUNT,
    "group_count": SMALL_COUNT,
    "natal_count": SMALL_COUNT,
    # app이 만드는 글
    "date": MONTH_DAY,
    "time": CLOCK_TIME,
    "start": CLOCK_TIME,
    "end": CLOCK_TIME,
    "minute": _same("59"),
    "degrees": _same("127.5"),
    "longitude": Fixed({"ko": "동경 127.5°", "en": "127.5°E", "ja": "東経127.5°"}),
    "weight": _same("10.5"),
    "calendar": FromKeys(("calendarSolar", "calendarLunar")),
    "provider": FromKeys(("loginProviderKakao", "loginProviderGoogle", "loginProviderApple")),
    "status": FromKeys(("todayEventSummaryOngoing", "todayEventSummaryNext")),
    "branch": FromGlossary(("branch",)),
    "stem": FromGlossary(("stem",)),
    "day_stem": FromGlossary(("stem",)),
    "day_branch": FromGlossary(("branch",)),
    "month_branch": FromGlossary(("branch",)),
    "stemName": FromGlossary(("stem",)),
    "reading": FromGlossary(("stem_reading", "branch_reading")),
    "element": FromGlossary(("element",)),
    "tag": FromGlossary(TAG_CATEGORIES),
    "term": FromGlossary(("ten_god", "ten_god_group", "shinsal", "twelve_stage", "element")),
    # 재지 않는 값
    "title": USER_TEXT,
    "nickname": USER_TEXT,
    "subject": Unmeasured("근거 링크의 대상 이름을 app이 여러 출처에서 만듭니다"),
    "pillar": Unmeasured("일진 표기를 app이 한자 글꼴 조각과 함께 만듭니다"),
    "before": Unmeasured("바뀐 항목 값을 app이 쉼표로 이어 만듭니다"),
    "after": Unmeasured("바뀐 항목 값을 app이 쉼표로 이어 만듭니다"),
    "email": Unmeasured("운영 메일 주소는 저장소 밖 값입니다(D98)"),
    "price": Unmeasured("스토어가 주는 가격 문자열입니다(D74)"),
    "traceId": TRACE_ID,
}

# (슬롯, 매개변수) -> 값 출처입니다. 슬롯 설명에 적힌 서식을 따릅니다.
SLOT_PARAM_SOURCES: dict[tuple[str, str], Source] = {
    ("ui.account-merge.saju", "date"): SHORT_DATE,
    ("preview.used.input", "date"): SHORT_DATE,
    ("ui.purchase.meta", "date"): SHORT_DATE,
    ("ui.purchase.meta", "start"): SHORT_DATE,
    ("ui.purchase.meta", "end"): SHORT_DATE,
    ("settings.ad-free.label", "date"): FULL_DATE,
    ("ad-free.status.remaining", "date"): FULL_DATE,
    ("evidence-sheet.unlock.until", "date"): FULL_DATE,
    ("ui.date-picker.solar-confirm", "date"): FULL_DATE,
}


@dataclass(frozen=True)
class LangValues:
    """한 언어의 용어집 범주별 이름과 원고 키별 글입니다."""

    lang: str
    by_category: Mapping[str, Sequence[str]]
    texts_by_key: Mapping[str, Sequence[str]]


def lang_values(entries: Sequence[Entry], lang: str) -> LangValues:
    by_category: dict[str, list[str]] = {}
    texts_by_key: dict[str, list[str]] = {}
    for entry in entries:
        if entry.lang != lang:
            continue
        if entry.slot == GLOSSARY_SLOT:
            by_category.setdefault(entry.key.split(".")[0], []).append(entry.text)
        texts_by_key.setdefault(entry.key, []).append(entry.text)
    return LangValues(lang, by_category, texts_by_key)


def source_for(slot_id: str, param: str) -> Source | None:
    return SLOT_PARAM_SOURCES.get((slot_id, param), PARAM_SOURCES.get(param))


def _longest(texts: Sequence[str]) -> str | None:
    return max(texts, key=len) if texts else None


def longest_param_value(slot_id: str, param: str, values: LangValues) -> str | None:
    """슬롯의 숫자, 자유 글 매개변수를 이 언어에서 가장 길게 렌더한 값입니다. 정할 수 없으면 None입니다."""
    source = source_for(slot_id, param)
    if isinstance(source, Fixed):
        return source.by_lang.get(values.lang, source.by_lang.get(ALL_LANGS))
    if isinstance(source, FromGlossary):
        return _longest([text for category in source.categories for text in values.by_category.get(category, ())])
    if isinstance(source, FromKeys):
        return _longest([text for key in source.keys for text in values.texts_by_key.get(key, ())])
    return None

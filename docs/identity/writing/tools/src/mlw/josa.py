"""조사 렌더와 호칭 정규화.

판정표(조사 쌍, 읽는 소리, 호칭 규칙)는 `rules/josa.yaml`에 있습니다. 코드는 그 표를 읽어 적용만 합니다.
server(Go) 렌더러가 같은 표와 `examples`로 같은 판정을 하도록 맞춥니다.
"""

import unicodedata
from dataclasses import dataclass
from enum import Enum
from functools import cache

import regex

from mlw.loader import load_josa
from mlw.model import JosaData, JosaPair
from mlw.paths import RULES_DIR

HANGUL_FIRST = 0xAC00
HANGUL_LAST = 0xD7A3
JONGSEONG_COUNT = 28
JONGSEONG_NONE = 0
JONGSEONG_RIEUL = 8
ASCII_DIGITS = "0123456789"

CODE_EMPTY = "name.empty"
CODE_TOO_LONG = "name.too_long"
CODE_EMOJI = "name.emoji"
CODE_CONTROL = "name.control"
CODE_SUFFIX_STRIPPED = "name.suffix_stripped"
CODE_SUFFIX_WARNING = "name.suffix_warning"

# 이모지 본체와 이모지를 만드는 보조 문자(변형 선택자, 제로폭 접합자, 국기, 키캡)
_EMOJI = regex.compile(r"[\p{Extended_Pictographic}\p{Regional_Indicator}‍️⃣]")


class Batchim(Enum):
    NONE = "none"
    RIEUL = "rieul"
    OTHER = "other"


@dataclass(frozen=True)
class NameResult:
    # 거부하면 None입니다.
    value: str | None
    findings_codes: tuple[str, ...]


@cache
def default_josa_data() -> JosaData:
    """`rules/josa.yaml`을 한 번만 읽어 둡니다."""
    return load_josa(RULES_DIR)


def _hangul_batchim(syllable: str) -> Batchim | None:
    if not HANGUL_FIRST <= ord(syllable) <= HANGUL_LAST:
        return None
    jongseong = (ord(syllable) - HANGUL_FIRST) % JONGSEONG_COUNT
    if jongseong == JONGSEONG_NONE:
        return Batchim.NONE
    if jongseong == JONGSEONG_RIEUL:
        return Batchim.RIEUL
    return Batchim.OTHER


def _number_reading(text: str, data: JosaData) -> str | None:
    """끝의 숫자 덩어리를 읽는 소리로 바꿉니다. 0이 아닌 끝자리가 있으면 그 자리를, 아니면 자릿수를 읽습니다."""
    start = len(text)
    while start > 0 and text[start - 1] in ASCII_DIGITS:
        start -= 1
    number = text[start:]
    zeros = len(number) - len(number.rstrip("0"))
    is_all_zero = zeros == len(number)
    if zeros == 0 or is_all_zero:
        return data.readings.digits.get(number[-1])
    zero_readings = data.readings.trailing_zeros
    return zero_readings.get(min(zeros, max(zero_readings, default=0)))


def _reading(text: str, data: JosaData) -> str | None:
    last = text[-1]
    if last in ASCII_DIGITS:
        return _number_reading(text, data)
    if last.upper() in data.readings.latin and last.isascii():
        return data.readings.latin[last.upper()]
    return data.readings.hanja.get(last)


def final_batchim(text: str, data: JosaData | None = None) -> Batchim | None:
    """`text`의 마지막 글자(읽는 소리 기준)의 받침을 판정합니다. 판정할 수 없으면 None입니다."""
    if not text:
        return None
    rules = data if data is not None else default_josa_data()
    direct = _hangul_batchim(text[-1])
    if direct is not None:
        return direct
    reading = _reading(text, rules)
    if reading is None:
        return None
    return _hangul_batchim(reading[-1])


def _choose(pair: JosaPair, batchim: Batchim | None) -> str:
    if batchim is None:
        return pair.fallback
    if batchim is Batchim.NONE:
        return pair.without_batchim
    if batchim is Batchim.RIEUL and pair.rieul is not None:
        return pair.rieul
    return pair.with_batchim


def render_josa(text: str, data: JosaData | None = None) -> str:
    """`X(이)가` 같은 조사 표기를 앞 글자의 받침에 맞게 바꿉니다. 판정할 수 없으면 병기형을 씁니다."""
    rules = data if data is not None else default_josa_data()
    if not rules.pairs:
        return text
    by_marker = {pair.marker: pair for pair in rules.pairs}
    pattern = regex.compile("|".join(regex.escape(marker) for marker in by_marker))

    def replace(match: regex.Match[str]) -> str:
        before = match.string[: match.start()]
        return _choose(by_marker[match.group()], final_batchim(before, rules))

    return pattern.sub(replace, text)


def normalize_name(lang: str, raw: str, data: JosaData | None = None) -> NameResult:
    """호칭 입력을 검증하고 저장할 값으로 정규화합니다. 거부하면 value는 None이고 코드는 거부 사유뿐입니다."""
    rules = (data if data is not None else default_josa_data()).name_rules
    name = raw.strip()
    if any(unicodedata.category(char) == "Cc" for char in name):
        return NameResult(None, (CODE_CONTROL,))
    if _EMOJI.search(name):
        return NameResult(None, (CODE_EMOJI,))

    codes: list[str] = []
    suffixes = rules.strip_suffix.get(lang, ())
    stripped_any = False
    while True:
        suffix = next((candidate for candidate in suffixes if name.endswith(candidate)), None)
        if suffix is None:
            break
        name = name[: -len(suffix)].rstrip()
        stripped_any = True
    if stripped_any:
        codes.append(CODE_SUFFIX_STRIPPED)

    if not name:
        return NameResult(None, (CODE_EMPTY,))
    max_length = rules.max_length.get(lang)
    if max_length is not None and len(name) > max_length:
        return NameResult(None, (CODE_TOO_LONG,))
    if any(name.endswith(suffix) for suffix in rules.warn_suffix.get(lang, ())):
        codes.append(CODE_SUFFIX_WARNING)
    return NameResult(name, tuple(codes))

"""ICU plural: ui 원고·ARB의 `{<변수>, plural, <형태>{<문장>} …}`을 읽고 형태별 문장으로 펼칩니다(#143).

* 문장 안에서는 `#` 대신 `{<변수>}`를 씁니다. 그래서 펼친 문장은 지금 자리표시자 문법 그대로 검사할 수 있습니다.
* 한 문장에 plural은 하나만 씁니다. plural 앞뒤 글자는 펼친 문장마다 붙습니다.
* 언어별 형태는 `PLURAL_FORMS`와 정확히 같아야 합니다.
"""

from dataclasses import dataclass

import regex

RULE_PLURAL = "icu.plural"
PLURAL_FORMS: dict[str, frozenset[str]] = {
    "ko": frozenset({"other"}),
    "ja": frozenset({"other"}),
    "en": frozenset({"one", "other"}),
}

_START = regex.compile(r"\{\s*(?P<variable>\w+)\s*,\s*plural\s*,")
_FORM = regex.compile(r"\s*(?P<form>[A-Za-z_=0-9]+)\s*\{")


@dataclass(frozen=True)
class Plural:
    variable: str
    # 형태 이름 -> 문장. 원고에 적은 순서를 지킵니다.
    forms: dict[str, str]
    prefix: str
    suffix: str


def _closing_brace(text: str, open_index: int) -> int:
    """`text[open_index]`의 `{`와 짝인 `}`의 위치입니다. 짝이 없으면 ValueError입니다."""
    depth = 0
    for index in range(open_index, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"plural 중괄호 짝이 맞지 않습니다: {text!r}")


def _read_forms(text: str, position: int) -> tuple[dict[str, str], int]:
    """형태 목록을 읽고, plural을 닫는 `}` 다음 위치를 함께 돌려줍니다."""
    forms: dict[str, str] = {}
    while True:
        match = _FORM.match(text, position)
        if match is None:
            break
        form = match.group("form")
        if form in forms:
            raise ValueError(f"plural 형태 '{form}'가 두 번 나옵니다: {text!r}")
        close = _closing_brace(text, match.end() - 1)
        forms[form] = text[match.end() : close]
        position = close + 1
    rest = regex.match(r"\s*\}", text[position:])
    if rest is None or not forms:
        raise ValueError(f"plural 문법이 올바르지 않습니다: {text!r}")
    return forms, position + rest.end()


def parse_plural(text: str) -> Plural | None:
    """plural을 읽습니다. 없으면 None, 문법이 틀리면 ValueError입니다."""
    start = _START.search(text)
    if start is None:
        return None
    forms, end = _read_forms(text, start.end())
    suffix = text[end:]
    if _START.search(suffix) is not None:
        raise ValueError(f"한 문장에 plural은 하나만 씁니다: {text!r}")
    return Plural(start.group("variable"), forms, text[: start.start()], suffix)


def expand_plural(text: str) -> list[str]:
    """형태마다 펼친 문장입니다. plural이 없으면 `[text]`, 문법이 틀리면 ValueError입니다."""
    plural = parse_plural(text)
    if plural is None:
        return [text]
    return [plural.prefix + sentence + plural.suffix for sentence in plural.forms.values()]


def plural_problem(text: str, lang: str) -> str | None:
    """plural 문법이 틀렸거나 형태가 그 언어의 형태와 다르면 이유를 돌려줍니다."""
    try:
        plural = parse_plural(text)
    except ValueError as error:
        return str(error)
    if plural is None:
        return None
    expected = PLURAL_FORMS.get(lang, frozenset({"other"}))
    if set(plural.forms) != expected:
        return f"{lang} plural 형태는 {', '.join(sorted(expected))}여야 합니다(현재 {', '.join(plural.forms)})"
    return None

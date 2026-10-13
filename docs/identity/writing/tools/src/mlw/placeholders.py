"""원고 문장의 자리표시자 `{param}` / `{param:category}` 파싱과 치환.

자리표시자 바로 뒤에는 조사 표기(`(이)가` 등)가 올 수 있습니다.
"""

from collections.abc import Callable
from dataclasses import dataclass

import regex

from mlw.josa import default_josa_data, render_josa


@dataclass(frozen=True)
class Placeholder:
    name: str
    category: str | None
    josa: str | None

    @property
    def key(self) -> str:
        """값 표에서 찾는 키입니다. 범주가 있으면 `name:category`입니다."""
        return self.name if self.category is None else f"{self.name}:{self.category}"


def _placeholder_pattern() -> regex.Pattern[str]:
    markers = sorted((pair.marker for pair in default_josa_data().pairs), key=len, reverse=True)
    josa = "|".join(regex.escape(marker) for marker in markers)
    # 용어 토큰의 닫는 `]]`가 자리표시자와 조사 표기 사이에 올 수 있습니다.
    suffix = f"(?:(?:\\]\\])?(?P<josa>{josa}))?" if markers else ""
    return regex.compile(rf"\{{(?P<name>[^{{}}:\s]+)(?::(?P<category>[^{{}}\s]+))?\}}{suffix}")


_PATTERN = _placeholder_pattern()


def _to_placeholder(match: regex.Match[str]) -> Placeholder:
    groups = match.groupdict()
    return Placeholder(name=groups["name"], category=groups["category"], josa=groups.get("josa"))


def parse(text: str) -> list[Placeholder]:
    """문장 속 자리표시자를 순서대로 돌려줍니다. 문법이 틀리면 ValueError입니다."""
    leftover = _PATTERN.sub("", text)
    if "{" in leftover or "}" in leftover:
        raise ValueError(f"자리표시자 문법이 올바르지 않습니다: {text!r}")
    return [_to_placeholder(match) for match in _PATTERN.finditer(text)]


@dataclass(frozen=True)
class Token:
    """용어 토큰 `[[...]]` 하나입니다.

    `text`는 대괄호 안쪽 원문(`[[글자|용어 id]]`이면 `|` 앞), `start`·`end`는 `[[`부터 `]]` 끝까지의 위치,
    `term`은 `|` 뒤에 직접 적은 용어 id입니다.
    """

    text: str
    start: int
    end: int
    term: str | None = None


TOKEN_OPEN = "[["
TOKEN_CLOSE = "]]"
TERM_SEPARATOR = "|"


def parse_tokens(text: str) -> list[Token]:
    """문장 속 용어 토큰을 순서대로 돌려줍니다. 짝이 안 맞거나 중첩되거나 비면 ValueError입니다."""
    tokens: list[Token] = []
    position = 0
    while True:
        start = text.find(TOKEN_OPEN, position)
        stray_close = text.find(TOKEN_CLOSE, position, start if start >= 0 else len(text))
        if stray_close >= 0:
            raise ValueError(f"용어 토큰 문법이 올바르지 않습니다: {text!r}")
        if start < 0:
            return tokens
        close = text.find(TOKEN_CLOSE, start + len(TOKEN_OPEN))
        if close < 0:
            raise ValueError(f"용어 토큰 문법이 올바르지 않습니다: {text!r}")
        inner = text[start + len(TOKEN_OPEN) : close]
        shown, separator, term = inner.partition(TERM_SEPARATOR)
        if TOKEN_OPEN in inner or not shown.strip() or (separator and not term.strip()):
            raise ValueError(f"용어 토큰 문법이 올바르지 않습니다: {text!r}")
        end = close + len(TOKEN_CLOSE)
        tokens.append(Token(shown, start, end, term if separator else None))
        position = end


def strip_token_marks(text: str) -> str:
    """용어 토큰의 `[[`, `]]`와 직접 적은 용어 id(`|용어 id`)를 지웁니다. 문법이 틀리면 ValueError입니다."""
    tokens = parse_tokens(text)
    for token in reversed(tokens):
        text = text[: token.start] + token.text + text[token.end :]
    return text


def substitute(text: str, value_of: Callable[[Placeholder], str]) -> str:
    """자리표시자를 값으로 바꾸고 조사 표기를 렌더합니다. 문법이 틀리면 ValueError입니다."""
    text = strip_token_marks(text)
    parse(text)

    def replace(match: regex.Match[str]) -> str:
        placeholder = _to_placeholder(match)
        return value_of(placeholder) + (placeholder.josa or "")

    return render_josa(_PATTERN.sub(replace, text))

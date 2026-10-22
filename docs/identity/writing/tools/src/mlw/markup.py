"""원고 표기 검사: 호칭 덩어리 위치(name.position)와 ui 원고의 표기(ui.markup).

호칭은 `vocative: true` 슬롯에서 문장 맨 앞 덩어리로만 씁니다. 호칭이 없으면 렌더러가 덩어리를 지웁니다
(호칭·조사 규칙 v1.1). ui 원고는 앱 ARB가 렌더하므로 호칭·용어 토큰을 쓸 수 없습니다. 조사 표기는 ko ui 원고에서만
매개변수 바로 뒤에 쓸 수 있고, ARB를 만들 때 ICU select로 펼칩니다(ui.josa_*, spec 2026-10-22-ui-josa §5).
"""

from collections.abc import Mapping

import regex

from mlw.josa import default_josa_data
from mlw.josa_select import josa_param
from mlw.model import Entry, Finding, ParamKind, Slot
from mlw.placeholders import parse, parse_tokens

RULE_NAME_POSITION = "name.position"
RULE_UI_MARKUP = "ui.markup"
RULE_UI_JOSA_POSITION = "ui.josa_position"
RULE_UI_JOSA_LITERAL = "ui.josa_literal"
RULE_UI_JOSA_NAME_CLASH = "ui.josa_name_clash"
JOSA_LANG = "ko"
JOSA_PARAM_KINDS = frozenset({"text", "number"})
NAME_PARAM = "name"
VOCATIVE_PREFIX: dict[str, str] = {"ko": "{name}님, ", "ja": "{name}さん、", "en": "{name}, "}


def strip_vocative(text: str, lang: str) -> str | None:
    """문장 맨 앞의 호칭 덩어리를 지운 텍스트입니다. 덩어리가 없으면 None입니다."""
    prefix = VOCATIVE_PREFIX.get(lang)
    if prefix is None or not text.startswith(prefix):
        return None
    return text.removeprefix(prefix)


def _name_count(text: str) -> int:
    try:
        return sum(1 for placeholder in parse(text) if placeholder.name == NAME_PARAM)
    except ValueError:
        # 문법 오류는 문장 단위 검사가 보고합니다.
        return 0


def check_name_position(entry: Entry, slot: Slot) -> list[Finding]:
    """`{name}`이 호칭 자리 슬롯의 문장 맨 앞 덩어리 하나로만 쓰였는지 봅니다."""
    count = _name_count(entry.text)
    if count == 0:
        return []
    stripped = strip_vocative(entry.text, entry.lang)
    # 덩어리 뒤에 공백이 더 있으면 호칭을 지운 문장이 공백으로 시작합니다.
    if slot.vocative and count == 1 and stripped is not None and not stripped[:1].isspace():
        return []
    prefix = VOCATIVE_PREFIX.get(entry.lang, "")
    if not slot.vocative:
        message = f"슬롯 '{slot.id}'은(는) 호칭 자리가 아니라 {{name}}을 쓸 수 없습니다"
    else:
        message = f"{{name}}은 문장 맨 앞 호칭 덩어리 '{prefix}' 하나로만 씁니다"
    return [Finding(entry.file, entry.line, RULE_NAME_POSITION, "error", message)]


def check_ui_markup(entry: Entry) -> list[Finding]:
    """ui 원고에 호칭, 조사 표기, 용어 토큰이 있으면 문제입니다. 앱 ARB는 이를 렌더하지 않습니다."""
    try:
        placeholders = parse(entry.text)
        tokens = parse_tokens(entry.text)
    except ValueError:
        return []
    problems: list[str] = []
    if any(placeholder.name == NAME_PARAM for placeholder in placeholders):
        problems.append("호칭 {name}")
    if entry.lang != JOSA_LANG and any(placeholder.josa is not None for placeholder in placeholders):
        problems.append("조사 표기")
    if tokens:
        problems.append("용어 토큰 [[...]]")
    if not problems:
        return []
    message = f"ui 원고에는 {', '.join(problems)}을(를) 쓸 수 없습니다(ARB는 렌더하지 않음)"
    return [Finding(entry.file, entry.line, RULE_UI_MARKUP, "error", message)]


def _josa_patterns() -> tuple[regex.Pattern[str], regex.Pattern[str], regex.Pattern[str]]:
    """(조사 표기, 자리표시자와 그 뒤 조사 표기, 자리표시자 뒤에 글자로 붙인 조사) 패턴입니다."""
    pairs = default_josa_data().pairs
    markers = "|".join(regex.escape(m) for m in sorted((pair.marker for pair in pairs), key=len, reverse=True))
    words = {word for pair in pairs for word in (pair.with_batchim, pair.without_batchim, pair.rieul) if word}
    literal = "|".join(regex.escape(word) for word in sorted(words, key=len, reverse=True))
    return (
        regex.compile(markers),
        regex.compile(rf"\{{[^{{}}]*\}}(?:{markers})?"),
        # 조사 글자 뒤가 공백·문장부호·닫는 중괄호·끝일 때만 조사로 봅니다(`{date}이후`는 걸리지 않음).
        regex.compile(rf"\{{(?P<name>[^{{}}:\s,]+)\}}(?P<word>{literal})(?=[\s.,!?·}}]|$)"),
    )


_MARKER, _PLACEHOLDER_WITH_JOSA, _LITERAL_JOSA = _josa_patterns()


def check_ui_josa(entry: Entry, params: Mapping[str, ParamKind]) -> list[Finding]:
    """ko ui 원고의 조사 표기 자리, 글자로 붙인 조사, 생성 매개변수 이름 충돌을 봅니다."""
    if entry.lang != JOSA_LANG:
        return []
    try:
        placeholders = parse(entry.text)
    except ValueError:
        # 문법 오류는 문장 단위 검사가 보고합니다.
        return []
    findings: list[Finding] = []

    def add(rule_id: str, message: str) -> None:
        findings.append(Finding(entry.file, entry.line, rule_id, "error", message))

    names = {placeholder.name for placeholder in placeholders}
    for placeholder in placeholders:
        if placeholder.josa is None:
            continue
        kind = params.get(placeholder.name)
        if kind is None or kind.kind not in JOSA_PARAM_KINDS:
            add(RULE_UI_JOSA_POSITION, f"조사 표기는 text·number 매개변수 바로 뒤에만 씁니다({{{placeholder.name}}})")
        generated = josa_param(placeholder.name)
        if generated in params or generated in names:
            add(RULE_UI_JOSA_NAME_CLASH, f"매개변수 '{generated}'가 조사 매개변수 이름과 겹칩니다")
    if _MARKER.search(_PLACEHOLDER_WITH_JOSA.sub("", entry.text)):
        add(RULE_UI_JOSA_POSITION, "조사 표기는 매개변수 바로 뒤에만 씁니다")
    for match in _LITERAL_JOSA.finditer(entry.text):
        kind = params.get(match.group("name"))
        if kind is not None and kind.kind in JOSA_PARAM_KINDS:
            word = match.group("word")
            add(RULE_UI_JOSA_LITERAL, f"매개변수 뒤 조사 '{word}'는 받침에 따라 바뀝니다. 조사 표기를 씁니다")
    return findings

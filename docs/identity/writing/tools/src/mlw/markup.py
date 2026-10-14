"""원고 표기 검사: 호칭 덩어리 위치(name.position)와 ui 원고의 표기(ui.markup).

호칭은 `vocative: true` 슬롯에서 문장 맨 앞 덩어리로만 씁니다. 호칭이 없으면 렌더러가 덩어리를 지웁니다
(호칭·조사 규칙 v1.1). ui 원고는 앱 ARB가 렌더하므로 호칭·조사 표기·용어 토큰을 쓸 수 없습니다.
"""

from mlw.model import Entry, Finding, Slot
from mlw.placeholders import parse, parse_tokens

RULE_NAME_POSITION = "name.position"
RULE_UI_MARKUP = "ui.markup"
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
    if any(placeholder.josa is not None for placeholder in placeholders):
        problems.append("조사 표기")
    if tokens:
        problems.append("용어 토큰 [[...]]")
    if not problems:
        return []
    message = f"ui 원고에는 {', '.join(problems)}을(를) 쓸 수 없습니다(ARB는 렌더하지 않음)"
    return [Finding(entry.file, entry.line, RULE_UI_MARKUP, "error", message)]

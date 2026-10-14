"""용어 토큰 검사(token.term): 원고의 `[[...]]`를 용어 id로 풀 수 있는지 봅니다.

용어 id는 glossary 용어 범주의 `<범주>.<값>` 또는 태그 이름 키(`tag.*`)입니다. 표기는 셋입니다.
* `[[{param}]]`·`[[{param:cat}]]`: 매개변수 값의 용어 id. 범주는 용어 범주여야 합니다.
* `[[글자]]`: 같은 언어의 glossary·태그 이름 원고에서 그 글자를 이름으로 가진 용어 id 하나.
  이름이 둘 이상이면 언제나 문제이고, 이름이 없으면 그 언어의 glossary·태그 이름 원고가 둘 다 있을 때만 문제입니다.
* `[[글자|용어 id]]`: 직접 적은 용어 id.
"""

from collections.abc import Mapping, Sequence

from mlw.glossary import TERM_CATEGORIES, term_ids
from mlw.model import Entry, Finding, Slot
from mlw.placeholders import Token, parse, parse_tokens

RULE_TOKEN_TERM = "token.term"
GLOSSARY_SLOT = "glossary.value_name"
TAG_LABEL_SLOT = "daily.tag_label"


NAME_SLOTS = (GLOSSARY_SLOT, TAG_LABEL_SLOT)


def _names_by_lang(entries: Sequence[Entry], known: frozenset[str]) -> dict[str, dict[str, set[str]]]:
    """언어 -> 이름 글자 -> 용어 id 집합입니다. glossary·태그 이름 원고에서 모읍니다."""
    names: dict[str, dict[str, set[str]]] = {}
    for entry in entries:
        if entry.slot in NAME_SLOTS and entry.key in known:
            names.setdefault(entry.lang, {}).setdefault(entry.text, set()).add(entry.key)
    return names


def _complete_langs(entries: Sequence[Entry]) -> frozenset[str]:
    """glossary와 태그 이름 원고가 둘 다 있는 언어입니다. 이 언어에서만 '이름 없음'을 문제로 봅니다."""
    sources: dict[str, set[str]] = {}
    for entry in entries:
        if entry.slot in NAME_SLOTS:
            sources.setdefault(entry.lang, set()).add(entry.slot)
    return frozenset(lang for lang, slots in sources.items() if slots == set(NAME_SLOTS))


def _token_problem(
    token: Token,
    entry: Entry,
    slot: Slot | None,
    known: frozenset[str],
    names: Mapping[str, Mapping[str, set[str]]],
    complete_langs: frozenset[str],
) -> str | None:
    """토큰을 용어 id로 풀 수 없으면 이유를 돌려줍니다."""
    if token.term is not None:
        return None if token.term in known else f"용어 id '{token.term}'가 없습니다"
    try:
        placeholders = parse(token.text)
    except ValueError:
        return None
    if len(placeholders) == 1 and token.text.strip() == f"{{{placeholders[0].key}}}":
        placeholder = placeholders[0]
        kind = slot.keys.get(entry.key, {}).get(placeholder.name) if slot is not None else None
        category = placeholder.category or (kind.default_category if kind is not None else None)
        if category in TERM_CATEGORIES:
            return None
        return f"'[[{token.text}]]'의 범주 '{category}'는 용어 범주가 아닙니다"
    matches = names.get(entry.lang, {}).get(token.text, set())
    if len(matches) == 1:
        return None
    if not matches:
        if entry.lang not in complete_langs:
            # 그 언어의 이름 원고가 아직 다 차지 않았습니다.
            return None
        return f"'{token.text}'을(를) 이름으로 가진 용어가 없습니다. [[글자|용어 id]]로 적습니다"
    return f"'{token.text}'은(는) 용어 {', '.join(sorted(matches))} 중 하나로 정할 수 없습니다. [[글자|용어 id]]로 적습니다"


def check_tokens(entries: Sequence[Entry], slots: Mapping[str, Slot], tag_keys: Sequence[str]) -> list[Finding]:
    """원고마다 용어 토큰을 용어 id로 풀 수 있는지 봅니다. 문제는 모두 error입니다."""
    known = frozenset(term_ids(tag_keys))
    names = _names_by_lang(entries, known)
    complete_langs = _complete_langs(entries)
    findings: list[Finding] = []
    for entry in entries:
        try:
            tokens = parse_tokens(entry.text)
        except ValueError:
            # 문법 오류는 문장 단위 검사가 보고합니다.
            continue
        for token in tokens:
            problem = _token_problem(token, entry, slots.get(entry.slot), known, names, complete_langs)
            if problem is not None:
                findings.append(Finding(entry.file, entry.line, RULE_TOKEN_TERM, "error", problem))
    return findings

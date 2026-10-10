"""문장 단위 검사: slop·문체 규칙, 글자 수, 자리표시자 문법."""

from collections.abc import Mapping

import regex

from mlw.model import Detect, Entry, Finding, RuleSet, Severity, SlopRule, StyleRule
from mlw.placeholders import parse, parse_tokens, strip_token_marks, substitute

# 규칙 탐지용 정규화에서 자리표시자 자리에 들어가는 값입니다.
DETECTION_VALUE = "값"
CARE = "care"
RULE_LENGTH = "style.length"
RULE_PLACEHOLDER_SYNTAX = "placeholder.syntax"
RULE_TOKEN_SYNTAX = "token.syntax"


def matches(detect: Detect, lang: str, text: str) -> bool:
    """`text`가 탐지 조건에 해당하는지 판정합니다. `text`는 정규화된 텍스트여야 합니다."""
    if detect.langs and lang not in detect.langs:
        return False
    if detect.kind == "lexicon":
        return any(word in text for word in detect.words)
    # regex와 template은 둘 다 정규식입니다. template은 의미상 문장 전체 틀을 가리킵니다.
    return detect.pattern is not None and regex.search(detect.pattern, text) is not None


def detectable_rules(rules: RuleSet) -> list[SlopRule | StyleRule]:
    """slop·문체 규칙을 모두 돌려줍니다. detect가 없는 llm 규칙도 포함합니다."""
    return [*rules.slop.values(), *rules.style.values()]


def normalize_for_detection(text: str) -> str:
    """용어 토큰 표기를 지우고 자리표시자를 값으로 바꾼 뒤 조사를 렌더합니다. 문법이 틀리면 ValueError입니다."""
    return substitute(strip_token_marks(text), lambda _placeholder: DETECTION_VALUE)


def _rendered_length(text: str, longest_values: Mapping[str, str]) -> int | None:
    """가장 긴 값으로 렌더한 글자 수입니다. 값이 없는 자리표시자가 있으면 None입니다.

    용어 토큰의 `[[`, `]]`는 글자 수에 넣지 않습니다.
    """
    text = strip_token_marks(text)
    if any(placeholder.key not in longest_values for placeholder in parse(text)):
        return None
    return len(substitute(text, lambda placeholder: longest_values[placeholder.key]))


def check_sentence(
    entry: Entry,
    purpose: str,
    rules: RuleSet,
    max_length: int | None,
    longest_values: Mapping[str, str],
) -> list[Finding]:
    def finding(rule_id: str, severity: Severity, message: str) -> Finding:
        return Finding(entry.file, entry.line, rule_id, severity, message)

    try:
        parse_tokens(entry.text)
    except ValueError as error:
        return [finding(RULE_TOKEN_SYNTAX, "error", str(error))]
    try:
        normalized = normalize_for_detection(entry.text)
    except ValueError as error:
        return [finding(RULE_PLACEHOLDER_SYNTAX, "error", str(error))]

    # 위로 문장(care)은 슬롯 목적과 관계없이 care로 예외를 판정합니다.
    effective_purpose = CARE if entry.type == CARE else purpose
    findings: list[Finding] = []
    for rule in detectable_rules(rules):
        if rule.detect is None or effective_purpose in rule.exempt_purposes:
            continue
        if matches(rule.detect, entry.lang, normalized):
            findings.append(finding(rule.id, rule.severity, rule.name))

    if max_length is not None:
        length = _rendered_length(entry.text, longest_values)
        if length is not None and length > max_length:
            findings.append(
                finding(RULE_LENGTH, "error", f"글자 수 {length}자가 상한 {max_length}자를 넘습니다")
            )
    return findings

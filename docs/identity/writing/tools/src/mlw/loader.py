"""규칙 YAML(slop·limits·style·josa)을 읽어 모델로 바꿉니다.

필수 필드와 허용 값을 검사하고, 문제를 모두 모은 뒤 `LoadError`로 한 번에 던집니다.
"""

from collections.abc import Callable
from pathlib import Path
from typing import cast

import regex
import yaml

from mlw.model import (
    DETECT_KINDS,
    JUDGES,
    LANGS,
    PURPOSES,
    SCOPES,
    SEVERITIES,
    CountSelector,
    Detect,
    DetectKind,
    Example,
    Examples,
    Finding,
    JosaData,
    Judge,
    Limit,
    LoadError,
    RuleSet,
    Scope,
    Severity,
    SlopRule,
    StyleRule,
)
from mlw.yamlio import load_with_lines

SCHEMA_RULE_ID = "load.schema"
YAML_RULE_ID = "load.yaml"

SLOP_KEYS = {"id", "name", "judge", "severity", "detect", "rubric", "exempt_purposes", "examples"}
STYLE_KEYS = {"id", "name", "severity", "detect", "exempt_purposes", "examples"}
LIMIT_KEYS = {"id", "name", "scope", "count", "max", "severity"}
DETECT_KEYS = {"kind", "pattern", "words", "langs"}
EXAMPLE_KEYS = {"lang", "slot_purpose", "text"}
COUNT_KEYS = ("placeholder", "type", "rule")


class _Problems:
    """한 파일에서 발견한 문제를 모읍니다."""

    def __init__(self, file: Path) -> None:
        self.file = file
        self.findings: list[Finding] = []

    def add(self, line: int, message: str) -> None:
        self.findings.append(Finding(self.file, line, SCHEMA_RULE_ID, "error", message))


class _Item:
    """규칙 항목 하나. 필드를 꺼내며 문제를 기록합니다."""

    def __init__(self, data: dict[str, object], line: int, problems: _Problems) -> None:
        self.data = data
        self.line = line
        self.problems = problems

    def fail(self, message: str) -> None:
        self.problems.add(self.line, message)

    def check_unknown_keys(self, allowed: set[str]) -> None:
        for key in sorted(set(self.data) - allowed, key=str):
            self.fail(f"알 수 없는 필드 '{key}'입니다")

    def text(self, key: str, *, required: bool = True) -> str | None:
        value = self.data.get(key)
        if value is None:
            if required:
                self.fail(f"필수 필드 '{key}'가 없습니다")
            return None
        if not isinstance(value, str):
            self.fail(f"'{key}'는 문자열이어야 합니다")
            return None
        return value

    def choice(self, key: str, allowed: tuple[str, ...]) -> str | None:
        value = self.text(key)
        if value is not None and value not in allowed:
            self.fail(f"'{key}' 값 '{value}'은(는) 허용되지 않습니다. 허용 값: {', '.join(allowed)}")
            return None
        return value

    def string_list(self, key: str, allowed: tuple[str, ...] | None = None) -> tuple[str, ...]:
        value = self.data.get(key)
        if value is None:
            return ()
        if not isinstance(value, list) or not all(isinstance(entry, str) for entry in value):
            self.fail(f"'{key}'는 문자열 리스트여야 합니다")
            return ()
        entries = tuple(cast(list[str], value))
        if allowed is not None:
            for entry in entries:
                if entry not in allowed:
                    self.fail(f"'{key}' 값 '{entry}'은(는) 허용되지 않습니다. 허용 값: {', '.join(allowed)}")
        return entries

    def mapping(self, key: str) -> dict[str, object] | None:
        value = self.data.get(key)
        if value is None:
            return None
        if not isinstance(value, dict):
            self.fail(f"'{key}'는 매핑이어야 합니다")
            return None
        return cast(dict[str, object], value)


def _parse_detect(item: _Item, *, required: bool) -> Detect | None:
    raw = item.mapping("detect")
    if raw is None:
        if required and "detect" not in item.data:
            item.fail("필수 필드 'detect'가 없습니다")
        return None
    sub = _Item(raw, item.line, item.problems)
    sub.check_unknown_keys(DETECT_KEYS)
    kind = sub.choice("kind", DETECT_KINDS)
    pattern = sub.text("pattern", required=False)
    words = sub.string_list("words")
    langs = sub.string_list("langs", LANGS)
    if kind in ("regex", "template"):
        if pattern is None:
            item.fail(f"detect.kind '{kind}'에는 'pattern'이 필요합니다")
        else:
            try:
                regex.compile(pattern)
            except regex.error as error:
                item.fail(f"detect.pattern 정규식이 올바르지 않습니다: {error}")
    if kind == "lexicon" and not words:
        item.fail("detect.kind 'lexicon'에는 비어 있지 않은 'words'가 필요합니다")
    if kind is None:
        return None
    return Detect(
        kind=cast(DetectKind, kind),
        pattern=pattern,
        words=words,
        langs=frozenset(langs),
    )


def _parse_example_list(item: _Item, raw: object, label: str) -> tuple[Example, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        item.fail(f"examples.{label}는 리스트여야 합니다")
        return ()
    examples: list[Example] = []
    for entry in raw:
        if not isinstance(entry, dict):
            item.fail(f"examples.{label}의 항목은 매핑이어야 합니다")
            continue
        sub = _Item(cast(dict[str, object], entry), item.line, item.problems)
        sub.check_unknown_keys(EXAMPLE_KEYS)
        lang = sub.choice("lang", LANGS)
        purpose = sub.choice("slot_purpose", PURPOSES)
        text = sub.text("text")
        if lang is not None and purpose is not None and text is not None:
            examples.append(Example(lang=lang, slot_purpose=purpose, text=text))
    return tuple(examples)


def _parse_examples(item: _Item) -> Examples:
    raw = item.mapping("examples")
    if raw is None:
        return Examples()
    for key in sorted(set(raw) - {"hit", "pass"}, key=str):
        item.fail(f"examples에 알 수 없는 키 '{key}'가 있습니다")
    return Examples(
        hit=_parse_example_list(item, raw.get("hit"), "hit"),
        pass_=_parse_example_list(item, raw.get("pass"), "pass"),
    )


def _parse_slop(data: dict[str, object], line: int, problems: _Problems) -> SlopRule | None:
    item = _Item(data, line, problems)
    item.check_unknown_keys(SLOP_KEYS)
    rule_id = item.text("id")
    name = item.text("name")
    judge = item.choice("judge", JUDGES)
    severity = item.choice("severity", SEVERITIES)
    rubric = item.text("rubric", required=False)
    detect = _parse_detect(item, required=judge == "rule")
    exempt = item.string_list("exempt_purposes", PURPOSES)
    examples = _parse_examples(item)
    if judge == "llm" and rubric is None:
        item.fail("judge 'llm'에는 'rubric'이 필요합니다")
    if rule_id is None or name is None or judge is None or severity is None:
        return None
    return SlopRule(
        id=rule_id,
        name=name,
        judge=cast(Judge, judge),
        severity=cast(Severity, severity),
        detect=detect,
        rubric=rubric,
        exempt_purposes=frozenset(exempt),
        examples=examples,
        line=line,
    )


def _parse_style(data: dict[str, object], line: int, problems: _Problems) -> StyleRule | None:
    item = _Item(data, line, problems)
    item.check_unknown_keys(STYLE_KEYS)
    rule_id = item.text("id")
    name = item.text("name")
    severity = item.choice("severity", SEVERITIES)
    detect = _parse_detect(item, required=True)
    exempt = item.string_list("exempt_purposes", PURPOSES)
    examples = _parse_examples(item)
    if rule_id is None or name is None or severity is None or detect is None:
        return None
    return StyleRule(
        id=rule_id,
        name=name,
        severity=cast(Severity, severity),
        detect=detect,
        exempt_purposes=frozenset(exempt),
        examples=examples,
        line=line,
    )


def _parse_count(item: _Item) -> CountSelector | None:
    raw = item.mapping("count")
    if raw is None:
        if "count" not in item.data:
            item.fail("필수 필드 'count'가 없습니다")
        return None
    filled = [key for key in COUNT_KEYS if raw.get(key) is not None]
    unknown = sorted(set(raw) - set(COUNT_KEYS), key=str)
    if unknown or len(filled) != 1 or not isinstance(raw[filled[0]], str):
        item.fail(f"count에는 {', '.join(COUNT_KEYS)} 중 문자열 하나만 채워야 합니다")
        return None
    return CountSelector(**{filled[0]: cast(str, raw[filled[0]])})


def _parse_max(item: _Item) -> dict[str, int | None] | None:
    if "max" not in item.data:
        item.fail("필수 필드 'max'가 없습니다")
        return None
    raw = item.data["max"]
    if raw is None or _is_int(raw):
        return {lang: cast(int | None, raw) for lang in LANGS}
    if isinstance(raw, dict):
        result: dict[str, int | None] = {}
        for lang, value in cast(dict[str, object], raw).items():
            if lang not in LANGS:
                item.fail(f"max의 언어 '{lang}'은(는) 허용되지 않습니다. 허용 값: {', '.join(LANGS)}")
            elif value is not None and not _is_int(value):
                item.fail(f"max.{lang}은(는) 정수 또는 null이어야 합니다")
            else:
                result[lang] = cast(int | None, value)
        return result
    item.fail("'max'는 정수, null, 또는 언어별 매핑이어야 합니다")
    return None


def _is_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _parse_limit(data: dict[str, object], line: int, problems: _Problems) -> Limit | None:
    item = _Item(data, line, problems)
    item.check_unknown_keys(LIMIT_KEYS)
    rule_id = item.text("id")
    name = item.text("name")
    scope = item.choice("scope", SCOPES)
    severity = item.choice("severity", SEVERITIES)
    count = _parse_count(item)
    max_by_lang = _parse_max(item)
    if rule_id is None or name is None or scope is None or severity is None:
        return None
    if count is None or max_by_lang is None:
        return None
    return Limit(
        id=rule_id,
        name=name,
        scope=cast(Scope, scope),
        count=count,
        max=max_by_lang,
        severity=cast(Severity, severity),
        line=line,
    )


def _load_list[T](
    path: Path,
    parse: Callable[[dict[str, object], int, _Problems], T | None],
    get_id: Callable[[T], str],
    problems: _Problems,
) -> dict[str, T]:
    try:
        entries = load_with_lines(path)
    except (yaml.YAMLError, OSError) as error:
        mark = getattr(error, "problem_mark", None)
        line = mark.line + 1 if mark is not None else 1
        problems.findings.append(
            Finding(path, line, YAML_RULE_ID, "error", f"YAML을 읽을 수 없습니다: {error}")
        )
        return {}
    parsed: dict[str, T] = {}
    first_lines: dict[str, int] = {}
    for data, line in entries:
        rule = parse(data, line, problems)
        if rule is None:
            continue
        rule_id = get_id(rule)
        if rule_id in parsed:
            problems.add(line, f"id '{rule_id}'가 {first_lines[rule_id]}줄과 중복됩니다")
            continue
        parsed[rule_id] = rule
        first_lines[rule_id] = line
    return parsed


def _load_josa(path: Path, problems: _Problems) -> JosaData:
    empty = JosaData(pairs=(), name_rules={}, examples=())
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (yaml.YAMLError, OSError) as error:
        mark = getattr(error, "problem_mark", None)
        line = mark.line + 1 if mark is not None else 1
        problems.findings.append(
            Finding(path, line, YAML_RULE_ID, "error", f"YAML을 읽을 수 없습니다: {error}")
        )
        return empty
    if not isinstance(raw, dict):
        problems.add(1, "josa.yaml의 최상위는 매핑이어야 합니다")
        return empty
    data = cast(dict[str, object], raw)
    pairs = data.get("pairs", [])
    name_rules = data.get("name_rules", {})
    examples = data.get("examples", [])
    if not isinstance(pairs, list) or not isinstance(name_rules, dict) or not isinstance(examples, list):
        problems.add(1, "josa.yaml의 pairs·examples는 리스트, name_rules는 매핑이어야 합니다")
        return empty
    for key in sorted(set(data) - {"pairs", "name_rules", "examples"}, key=str):
        problems.add(1, f"알 수 없는 필드 '{key}'입니다")
    return JosaData(
        pairs=tuple(cast(list[object], pairs)),
        name_rules=cast(dict[str, object], name_rules),
        examples=tuple(cast(list[object], examples)),
    )


def load_rules(rules_dir: Path) -> RuleSet:
    """`rules_dir`의 규칙 파일 4개를 읽습니다. 문제가 있으면 모두 모아 `LoadError`를 던집니다."""
    findings: list[Finding] = []

    def problems_for(name: str) -> _Problems:
        return _Problems(rules_dir / name)

    slop_problems = problems_for("slop.yaml")
    slop = _load_list(slop_problems.file, _parse_slop, lambda rule: rule.id, slop_problems)
    limits_problems = problems_for("limits.yaml")
    limits = _load_list(limits_problems.file, _parse_limit, lambda rule: rule.id, limits_problems)
    style_problems = problems_for("style.yaml")
    style = _load_list(style_problems.file, _parse_style, lambda rule: rule.id, style_problems)
    josa_problems = problems_for("josa.yaml")
    josa = _load_josa(josa_problems.file, josa_problems)

    for problems in (slop_problems, limits_problems, style_problems, josa_problems):
        findings.extend(problems.findings)
    if findings:
        raise LoadError(findings)
    return RuleSet(slop=slop, limits=limits, style=style, josa=josa)

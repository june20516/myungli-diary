"""규칙 YAML(slop·limits·style·josa)을 읽어 모델로 바꿉니다.

필수 필드와 허용 값을 검사하고, 문제를 모두 모은 뒤 `LoadError`로 한 번에 던집니다.
"""

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import cast

import regex
import yaml

from mlw.glossary import glossary_values
from mlw.model import (
    DETECT_KINDS,
    JUDGES,
    LANGS,
    PARAM_KIND_LIST_PREFIX,
    PARAM_KIND_NONE,
    PARAM_KIND_NUMBER,
    PARAM_KIND_TEXT,
    PURPOSES,
    SCOPES,
    SENTENCE_TYPES,
    SEVERITIES,
    UNBOUNDED,
    CountSelector,
    Detect,
    DetectKind,
    Entry,
    Example,
    Examples,
    Finding,
    JosaData,
    JosaExample,
    JosaPair,
    JosaReadings,
    Judge,
    LengthLimit,
    Limit,
    LoadError,
    NameExample,
    NameRules,
    ParamKind,
    RuleSet,
    Scope,
    Severity,
    SlopRule,
    Slot,
    StyleRule,
)
from mlw.yamlio import load_with_lines

SCHEMA_RULE_ID = "load.schema"
YAML_RULE_ID = "load.yaml"

SLOP_KEYS = {"id", "name", "judge", "severity", "detect", "rubric", "exempt_purposes", "examples"}
STYLE_KEYS = {"id", "name", "severity", "detect", "exempt_purposes", "examples"}
LIMIT_KEYS = {"id", "name", "scope", "count", "max", "severity", "window"}
MIN_WINDOW = 2
MAX_WINDOW = 7
DETECT_KEYS = {"kind", "pattern", "words", "langs", "raw"}
EXAMPLE_KEYS = {"lang", "slot_purpose", "text"}
COUNT_KEYS = ("placeholder", "type", "rule", "lexicon", "token", "token_entries")
COUNT_STRING_KEYS = ("placeholder", "type", "rule")
COUNT_TRUE_KEYS = ("token", "token_entries")


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
    on_raw_text = sub.data.get("raw", False)
    if not isinstance(on_raw_text, bool):
        item.fail("detect.raw는 true 또는 false여야 합니다")
        on_raw_text = False
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
        raw=on_raw_text,
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
    if unknown or len(filled) != 1 or not _valid_count_value(filled[0], raw[filled[0]]):
        item.fail(
            f"count에는 {', '.join(COUNT_KEYS)} 중 하나만 채워야 합니다 "
            "(placeholder·type·rule은 문자열, lexicon은 문자열 목록, token·token_entries는 true)"
        )
        return None
    key = filled[0]
    if key == "lexicon":
        return CountSelector(lexicon=tuple(cast(list[str], raw[key])))
    if key in COUNT_TRUE_KEYS:
        return CountSelector(token=True) if key == "token" else CountSelector(token_entries=True)
    text = cast(str, raw[key])
    return CountSelector(
        placeholder=text if key == "placeholder" else None,
        type=text if key == "type" else None,
        rule=text if key == "rule" else None,
    )


def _valid_count_value(key: str, value: object) -> bool:
    if key in COUNT_STRING_KEYS:
        return isinstance(value, str)
    if key in COUNT_TRUE_KEYS:
        return value is True
    return isinstance(value, list) and bool(value) and all(isinstance(word, str) for word in value)


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


def _parse_window(item: _Item, scope: str | None) -> int | None:
    if "window" not in item.data:
        return MAX_WINDOW
    raw = item.data["window"]
    if scope != "week":
        item.fail("'window'는 scope가 week일 때만 쓸 수 있습니다")
        return None
    if not _is_int(raw) or not MIN_WINDOW <= cast(int, raw) <= MAX_WINDOW:
        item.fail(f"'window'는 {MIN_WINDOW}~{MAX_WINDOW}의 정수여야 합니다")
        return None
    return cast(int, raw)


def _parse_limit(data: dict[str, object], line: int, problems: _Problems) -> Limit | None:
    item = _Item(data, line, problems)
    item.check_unknown_keys(LIMIT_KEYS)
    rule_id = item.text("id")
    name = item.text("name")
    scope = item.choice("scope", SCOPES)
    severity = item.choice("severity", SEVERITIES)
    count = _parse_count(item)
    max_by_lang = _parse_max(item)
    window = _parse_window(item, scope)
    if rule_id is None or name is None or scope is None or severity is None:
        return None
    if count is None or max_by_lang is None or window is None:
        return None
    return Limit(
        id=rule_id,
        name=name,
        scope=cast(Scope, scope),
        count=count,
        max=max_by_lang,
        severity=cast(Severity, severity),
        line=line,
        window=window,
    )


def _read_items(path: Path, problems: _Problems) -> list[tuple[dict[str, object], int]] | None:
    """최상위 리스트의 항목과 줄 번호를 읽습니다. 읽을 수 없으면 문제를 기록하고 None입니다."""
    try:
        return load_with_lines(path)
    except (yaml.YAMLError, OSError) as error:
        mark = getattr(error, "problem_mark", None)
        line = mark.line + 1 if mark is not None else 1
        problems.findings.append(
            Finding(path, line, YAML_RULE_ID, "error", f"YAML을 읽을 수 없습니다: {error}")
        )
        return None


def _load_list[T](
    path: Path,
    parse: Callable[[dict[str, object], int, _Problems], T | None],
    get_id: Callable[[T], str],
    problems: _Problems,
) -> dict[str, T]:
    entries = _read_items(path, problems)
    if entries is None:
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


JOSA_KEYS = {"pairs", "readings", "name_rules", "examples"}
PAIR_KEYS = {"marker", "with_batchim", "without_batchim", "rieul", "fallback"}
READINGS_KEYS = {"digits", "trailing_zeros", "latin", "hanja"}
NAME_RULES_KEYS = {"max_length", "strip_suffix", "warn_suffix", "forbidden_chars", "examples"}
NAME_EXAMPLE_KEYS = {"lang", "input", "value", "codes"}
JOSA_EXAMPLE_KEYS = {"text", "expected"}


def _required_mapping(item: _Item, key: str) -> dict[str, object]:
    raw = item.mapping(key)
    if raw is None:
        if key not in item.data:
            item.fail(f"필수 필드 '{key}'가 없습니다")
        return {}
    return raw


def _string_map(item: _Item, key: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for name, value in _required_mapping(item, key).items():
        if isinstance(value, str):
            result[str(name)] = value
        else:
            item.fail(f"{key}.{name}은(는) 문자열이어야 합니다")
    return result


def _trailing_zeros(item: _Item) -> dict[int, str]:
    result: dict[int, str] = {}
    for count, reading in _required_mapping(item, "trailing_zeros").items():
        if _is_int(count) and isinstance(reading, str):
            result[cast(int, count)] = reading
        else:
            item.fail("trailing_zeros는 '정수: 문자열' 매핑이어야 합니다")
    return result


def _int_by_lang(item: _Item, key: str) -> dict[str, int]:
    result: dict[str, int] = {}
    for lang, value in _required_mapping(item, key).items():
        if lang not in LANGS:
            item.fail(f"{key}의 언어 '{lang}'은(는) 허용되지 않습니다. 허용 값: {', '.join(LANGS)}")
        elif isinstance(value, int) and not isinstance(value, bool):
            result[lang] = value
        else:
            item.fail(f"{key}.{lang}은(는) 정수여야 합니다")
    return result


def _suffixes_by_lang(item: _Item, key: str) -> dict[str, tuple[str, ...]]:
    result: dict[str, tuple[str, ...]] = {}
    for lang, value in _required_mapping(item, key).items():
        if lang not in LANGS:
            item.fail(f"{key}의 언어 '{lang}'은(는) 허용되지 않습니다. 허용 값: {', '.join(LANGS)}")
        elif isinstance(value, list) and all(isinstance(entry, str) for entry in value):
            result[lang] = tuple(cast(list[str], value))
        else:
            item.fail(f"{key}.{lang}은(는) 문자열 리스트여야 합니다")
    return result


def _parse_pair(raw: object, item: _Item) -> JosaPair | None:
    if not isinstance(raw, dict):
        item.fail("pairs의 항목은 매핑이어야 합니다")
        return None
    sub = _Item(cast(dict[str, object], raw), item.line, item.problems)
    sub.check_unknown_keys(PAIR_KEYS)
    marker = sub.text("marker")
    with_batchim = sub.text("with_batchim")
    without_batchim = sub.text("without_batchim")
    fallback = sub.text("fallback")
    rieul = sub.text("rieul", required=False)
    if marker is None or with_batchim is None or without_batchim is None or fallback is None:
        return None
    return JosaPair(marker, with_batchim, without_batchim, fallback, rieul)


def _parse_readings(item: _Item) -> JosaReadings:
    sub = _Item(_required_mapping(item, "readings"), item.line, item.problems)
    sub.check_unknown_keys(READINGS_KEYS)
    return JosaReadings(
        digits=_string_map(sub, "digits"),
        trailing_zeros=_trailing_zeros(sub),
        latin=_string_map(sub, "latin"),
        hanja=_string_map(sub, "hanja"),
    )


def _forbidden_chars(item: _Item) -> tuple[str, ...]:
    chars = item.string_list("forbidden_chars")
    for char in chars:
        if len(char) != 1:
            item.fail(f"forbidden_chars의 항목은 한 글자여야 합니다: {char!r}")
    return tuple(char for char in chars if len(char) == 1)


def _parse_name_example(raw: object, item: _Item) -> NameExample | None:
    if not isinstance(raw, dict):
        item.fail("name_rules.examples의 항목은 매핑이어야 합니다")
        return None
    sub = _Item(cast(dict[str, object], raw), item.line, item.problems)
    sub.check_unknown_keys(NAME_EXAMPLE_KEYS)
    lang = sub.choice("lang", LANGS)
    raw_input = sub.text("input")
    value = sub.text("value", required=False)
    codes = sub.string_list("codes")
    if lang is None or raw_input is None:
        return None
    return NameExample(lang, raw_input, value, codes)


def _name_examples(item: _Item) -> tuple[NameExample, ...]:
    raw = item.data.get("examples", [])
    if not isinstance(raw, list):
        item.fail("name_rules.examples는 리스트여야 합니다")
        return ()
    return tuple(example for entry in raw if (example := _parse_name_example(entry, item)) is not None)


def _parse_name_rules(item: _Item) -> NameRules:
    sub = _Item(_required_mapping(item, "name_rules"), item.line, item.problems)
    sub.check_unknown_keys(NAME_RULES_KEYS)
    return NameRules(
        max_length=_int_by_lang(sub, "max_length"),
        strip_suffix=_suffixes_by_lang(sub, "strip_suffix"),
        warn_suffix=_suffixes_by_lang(sub, "warn_suffix"),
        forbidden_chars=_forbidden_chars(sub),
        examples=_name_examples(sub),
    )


def _parse_josa_examples(item: _Item) -> tuple[JosaExample, ...]:
    raw = item.data.get("examples")
    if not isinstance(raw, list):
        item.fail("'examples'는 리스트여야 합니다")
        return ()
    examples: list[JosaExample] = []
    for entry in raw:
        if not isinstance(entry, dict):
            item.fail("examples의 항목은 매핑이어야 합니다")
            continue
        sub = _Item(cast(dict[str, object], entry), item.line, item.problems)
        sub.check_unknown_keys(JOSA_EXAMPLE_KEYS)
        text = sub.text("text")
        expected = sub.text("expected")
        if text is not None and expected is not None:
            examples.append(JosaExample(text, expected))
    return tuple(examples)


def _load_josa(path: Path, problems: _Problems) -> JosaData:
    empty = JosaData(
        pairs=(),
        readings=JosaReadings({}, {}, {}, {}),
        name_rules=NameRules({}, {}, {}),
        examples=(),
    )
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
    item = _Item(cast(dict[str, object], raw), 1, problems)
    item.check_unknown_keys(JOSA_KEYS)
    raw_pairs = item.data.get("pairs")
    if not isinstance(raw_pairs, list):
        item.fail("'pairs'는 리스트여야 합니다")
        raw_pairs = []
    pairs = [pair for entry in raw_pairs if (pair := _parse_pair(entry, item)) is not None]
    return JosaData(
        pairs=tuple(pairs),
        readings=_parse_readings(item),
        name_rules=_parse_name_rules(item),
        examples=_parse_josa_examples(item),
    )


def load_josa(rules_dir: Path) -> JosaData:
    """`rules_dir/josa.yaml`만 읽습니다. 문제가 있으면 `LoadError`를 던집니다."""
    problems = _Problems(rules_dir / "josa.yaml")
    josa = _load_josa(problems.file, problems)
    if problems.findings:
        raise LoadError(problems.findings)
    return josa


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


# --- 슬롯 명세 ---------------------------------------------------------------------------------------

UNKNOWN_RULE_ID = "slot.unknown_rule"
UNKNOWN_SLOT_ID = "slot.unknown_slot"
SCHEMA_FILE = "_schema.yaml"
SCHEMA_FIELD_KEYS = {"name", "required", "type", "description"}
TONE_AXES: tuple[str, ...] = ("진지", "격식", "존중", "담백")
VARIANTS_KEYS = {"count", "rotation"}
KEY_GROUP_KEYS = {"params", "keys"}
# 어느 슬롯에서나 쓰는 호칭 매개변수입니다.
NAME_PARAM = "name"
EXAMPLE_SIDES = ("good", "bad")
ENUM_PATTERN = regex.compile(r"enum\[([^\]]*)\]")


@dataclass(frozen=True)
class _FieldSpec:
    """`_schema.yaml`의 필드 하나."""

    name: str
    required: bool
    type: str


def _load_schema(path: Path, problems: _Problems) -> dict[str, _FieldSpec]:
    entries = _read_items(path, problems)
    fields: dict[str, _FieldSpec] = {}
    for data, line in entries or []:
        item = _Item(data, line, problems)
        item.check_unknown_keys(SCHEMA_FIELD_KEYS)
        name = item.text("name")
        type_text = item.text("type")
        required = data.get("required")
        if not isinstance(required, bool):
            item.fail("'required'는 true 또는 false여야 합니다")
        if name is None or type_text is None or not isinstance(required, bool):
            continue
        fields[name] = _FieldSpec(name, required, type_text)
    return fields


def _enum_values(type_text: str) -> tuple[str, ...]:
    match = ENUM_PATTERN.search(type_text)
    if match is None:
        return ()
    return tuple(part.strip() for part in match.group(1).split(","))


def _type_error(type_text: str, value: object) -> str | None:
    """값이 스키마의 타입 표기에 맞지 않으면 이유를 돌려줍니다. 알 수 없는 표기는 통과시킵니다."""
    if type_text == "string":
        return None if isinstance(value, str) else "문자열이어야 합니다"
    if type_text == "bool":
        return None if isinstance(value, bool) else "true 또는 false여야 합니다"
    if type_text.startswith("enum["):
        allowed = _enum_values(type_text)
        return None if value in allowed else f"허용 값은 {', '.join(allowed)}입니다"
    if type_text == "map" or type_text.startswith("map["):
        return None if isinstance(value, dict) else "매핑이어야 합니다"
    if type_text.startswith("list["):
        if not isinstance(value, list):
            return "리스트여야 합니다"
        if type_text == "list[string]" and not all(isinstance(entry, str) for entry in value):
            return "문자열 리스트여야 합니다"
        if type_text.startswith("list[enum["):
            allowed = _enum_values(type_text)
            if any(entry not in allowed for entry in value):
                return f"각 항목의 허용 값은 {', '.join(allowed)}입니다"
    return None


def _check_schema_fields(item: _Item, schema: dict[str, _FieldSpec]) -> None:
    """스키마 기준으로 알 수 없는 필드, 필수 필드 누락, 타입 오류를 기록합니다."""
    item.check_unknown_keys(set(schema))
    for spec in schema.values():
        value = item.data.get(spec.name)
        if value is None:
            if spec.required:
                item.fail(f"필수 필드 '{spec.name}'가 없습니다")
            continue
        error = _type_error(spec.type, value)
        if error is not None:
            item.fail(f"'{spec.name}': {error}")


def _field_is_valid(item: _Item, schema: dict[str, _FieldSpec], name: str) -> bool:
    """값이 있고 스키마의 타입 검사를 통과한 필드인지 확인합니다."""
    value = item.data.get(name)
    spec = schema.get(name)
    return value is not None and (spec is None or _type_error(spec.type, value) is None)


def _plain_text(data: dict[str, object], name: str) -> str | None:
    """문자열이면 돌려줍니다. 타입 오류는 스키마 검사가 이미 기록했습니다."""
    value = data.get(name)
    return value if isinstance(value, str) else None


def _parse_param_kind(item: _Item, param: str, raw: object) -> ParamKind | None:
    """`params` 맵의 값 하나를 읽습니다. 범주 목록, `list:<범주>`, `number`, `none`, `text` 중 하나입니다."""
    categories = glossary_values()
    allowed_text = ", ".join(sorted(categories))
    if isinstance(raw, list) and raw and all(isinstance(entry, str) for entry in raw):
        names = tuple(cast(list[str], raw))
        unknown = [name for name in names if name not in categories]
        if unknown:
            item.fail(f"params.{param}의 범주 {', '.join(unknown)}이(가) 없습니다. 허용 값: {allowed_text}")
            return None
        return ParamKind("glossary", names)
    if raw == PARAM_KIND_NUMBER:
        return ParamKind("number")
    if raw == PARAM_KIND_NONE:
        return ParamKind("none")
    if raw == PARAM_KIND_TEXT:
        return ParamKind("text")
    if isinstance(raw, str) and raw.startswith(PARAM_KIND_LIST_PREFIX):
        category = raw.removeprefix(PARAM_KIND_LIST_PREFIX)
        if category not in categories:
            item.fail(f"params.{param}의 목록 범주 '{category}'가 없습니다. 허용 값: {allowed_text}")
            return None
        return ParamKind("list", (category,))
    item.fail(
        f"params.{param}의 값 종류 {raw!r}을(를) 알 수 없습니다. "
        "범주 목록, 'list:<범주>', 'number', 'none', 'text' 중 하나여야 합니다"
    )
    return None


def _parse_params(group: _Item) -> dict[str, ParamKind]:
    raw = group.data.get("params")
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        group.fail("'params'는 매개변수 이름 -> 값 종류 매핑이어야 합니다")
        return {}
    params: dict[str, ParamKind] = {}
    for param, raw_kind in cast(dict[object, object], raw).items():
        if not isinstance(param, str):
            group.fail(f"params의 매개변수 이름은 문자열이어야 합니다: {param!r}")
            continue
        if param == NAME_PARAM:
            group.fail("'name'은 모든 슬롯에서 쓸 수 있으므로 params에 적지 않습니다")
            continue
        kind = _parse_param_kind(group, param, raw_kind)
        if kind is not None:
            params[param] = kind
    return params


def _parse_key_groups(item: _Item) -> dict[str, dict[str, ParamKind]]:
    keys: dict[str, dict[str, ParamKind]] = {}

    def add(key: str, params: dict[str, ParamKind]) -> None:
        if key in keys:
            item.fail(f"keys에 '{key}'가 중복됩니다")
        keys[key] = params

    for entry in cast(list[object], item.data["keys"]):
        if isinstance(entry, str):
            add(entry, {})
            continue
        if not isinstance(entry, dict):
            item.fail("keys의 항목은 문자열 또는 매핑이어야 합니다")
            continue
        group = _Item(cast(dict[str, object], entry), item.line, item.problems)
        group.check_unknown_keys(KEY_GROUP_KEYS)
        params = _parse_params(group)
        names = group.string_list("keys")
        if not names:
            item.fail("keys 묶음에는 비어 있지 않은 'keys'가 필요합니다")
        for name in names:
            add(name, params)
    return keys


def _length_limit(item: _Item, field_name: str, value: object) -> LengthLimit:
    """상한 값 하나를 읽습니다. 양의 정수, `unbounded`(상한 없음), null(미정) 가운데 하나입니다."""
    if value is None or value == UNBOUNDED:
        return cast(LengthLimit, value)
    if _is_int(value) and cast(int, value) > 0:
        return cast(int, value)
    item.fail(f"{field_name}은(는) 양의 정수, {UNBOUNDED}, null 가운데 하나여야 합니다")
    return None


def _length_limits(item: _Item, field_name: str, raw: object) -> dict[str, LengthLimit]:
    limits: dict[str, LengthLimit] = {}
    for lang, value in cast(dict[str, object], raw).items():
        if lang not in LANGS:
            item.fail(f"{field_name}의 언어 '{lang}'은(는) 허용되지 않습니다. 허용 값: {', '.join(LANGS)}")
            continue
        limits[lang] = _length_limit(item, f"{field_name}.{lang}", value)
    return limits


def _parse_slot_max_length(item: _Item) -> dict[str, LengthLimit]:
    result: dict[str, LengthLimit] = dict.fromkeys(LANGS)
    result.update(_length_limits(item, "max_length", item.data["max_length"]))
    return result


def _parse_key_max_length(item: _Item, keys: Mapping[str, object]) -> dict[str, dict[str, LengthLimit]]:
    """키별 상한(`key_max_length`)을 읽습니다. 키는 이 슬롯의 `keys`에 있어야 합니다."""
    raw = item.data.get("key_max_length")
    if not isinstance(raw, dict):
        return {}
    result: dict[str, dict[str, LengthLimit]] = {}
    for key, limits in raw.items():
        field_name = f"key_max_length.{key}"
        if key not in keys:
            item.fail(f"{field_name}: 이 슬롯의 keys에 없는 키입니다")
        elif not isinstance(limits, dict):
            item.fail(f"{field_name}은(는) 언어 → 상한인 매핑이어야 합니다")
        else:
            result[str(key)] = _length_limits(item, field_name, limits)
    return result


def _parse_pending(item: _Item, keys: Mapping[str, object]) -> dict[str, dict[str, str]]:
    """일부러 비워 둔 원고(`pending`)를 읽습니다. 키 → 언어 → 이유이고, 키는 이 슬롯의 `keys`에 있어야 합니다."""
    raw = item.data.get("pending")
    if not isinstance(raw, dict):
        return {}
    result: dict[str, dict[str, str]] = {}
    for key, reasons in raw.items():
        field_name = f"pending.{key}"
        if key not in keys:
            item.fail(f"{field_name}: 이 슬롯의 keys에 없는 키입니다")
            continue
        if not isinstance(reasons, dict):
            item.fail(f"{field_name}은(는) 언어 → 이유인 매핑이어야 합니다")
            continue
        for lang, reason in reasons.items():
            if lang not in LANGS:
                item.fail(f"{field_name}의 언어 '{lang}'은(는) 허용되지 않습니다. 허용 값: {', '.join(LANGS)}")
            elif not isinstance(reason, str) or not reason.strip():
                item.fail(f"{field_name}.{lang}: 비워 둔 이유를 문자열로 적어야 합니다")
            else:
                result.setdefault(str(key), {})[str(lang)] = reason
    return result


def _parse_tone(item: _Item) -> dict[str, int]:
    tone: dict[str, int] = {}
    for axis, value in cast(dict[str, object], item.data["tone"]).items():
        if axis not in TONE_AXES:
            item.fail(f"tone의 축 '{axis}'은(는) 허용되지 않습니다. 허용 값: {', '.join(TONE_AXES)}")
        elif _is_int(value) and 1 <= cast(int, value) <= 5:
            tone[axis] = cast(int, value)
        else:
            item.fail(f"tone.{axis}은(는) 1~5 정수여야 합니다")
    return tone


def _parse_variant_count(item: _Item) -> int:
    raw = item.mapping("variants")
    if raw is None:
        return 1
    sub = _Item(raw, item.line, item.problems)
    sub.check_unknown_keys(VARIANTS_KEYS)
    sub.text("rotation", required=False)
    count = raw.get("count", 1)
    if not _is_int(count) or cast(int, count) < 1:
        item.fail("variants.count는 1 이상의 정수여야 합니다")
        return 1
    return cast(int, count)


def _parse_slot_examples(item: _Item) -> dict[str, list[dict[str, object]]]:
    result: dict[str, list[dict[str, object]]] = {side: [] for side in EXAMPLE_SIDES}
    raw = item.mapping("examples")
    if raw is None:
        return result
    for side, entries in raw.items():
        if side not in EXAMPLE_SIDES:
            item.fail(f"examples에 알 수 없는 키 '{side}'가 있습니다. 허용 값: {', '.join(EXAMPLE_SIDES)}")
        elif not isinstance(entries, list) or not all(isinstance(entry, dict) for entry in entries):
            item.fail(f"examples.{side}는 매핑 리스트여야 합니다")
        else:
            result[side] = cast(list[dict[str, object]], entries)
    return result


def _parse_slot(
    data: dict[str, object],
    line: int,
    file: Path,
    schema: dict[str, _FieldSpec],
    problems: _Problems,
) -> Slot | None:
    item = _Item(data, line, problems)
    _check_schema_fields(item, schema)
    slot_id = _plain_text(data, "id")
    where = _plain_text(data, "where")
    purpose = _plain_text(data, "purpose")
    structured = ("keys", "max_length", "tone", "examples")
    if slot_id is None or where is None or purpose is None:
        return None
    if not all(_field_is_valid(item, schema, name) for name in structured):
        return None
    keys = _parse_key_groups(item)
    return Slot(
        id=slot_id,
        where=where,
        purpose=purpose,
        types=item.string_list("types"),
        variants=_parse_variant_count(item),
        keys=keys,
        co_display=item.string_list("co_display"),
        max_length=_parse_slot_max_length(item),
        key_max_length=_parse_key_max_length(item, keys),
        pending=_parse_pending(item, keys),
        allowed=frozenset(item.string_list("allowed")),
        forbidden=frozenset(item.string_list("forbidden")),
        examples=_parse_slot_examples(item),
        line=line,
        file=file,
        user_state=_plain_text(data, "user_state") or "",
        structure=_plain_text(data, "structure") or "",
        tone=_parse_tone(item),
        endings=item.string_list("endings"),
        ia=item.string_list("ia"),
        components=item.string_list("components"),
        select=_plain_text(data, "select") or "",
        vocative=data.get("vocative") is True,
    )


def _check_references(slots: dict[str, Slot], rules: RuleSet, findings: list[Finding]) -> None:
    known_rules = set(rules.slop) | set(rules.style)
    for slot in slots.values():
        for field_name, ids in (("allowed", slot.allowed), ("forbidden", slot.forbidden)):
            for rule_id in sorted(ids - known_rules):
                message = f"{field_name}의 규칙 ID '{rule_id}'를 slop.yaml·style.yaml에서 찾을 수 없습니다"
                findings.append(Finding(slot.file, slot.line, UNKNOWN_RULE_ID, "error", message))
        for other in slot.co_display:
            if other not in slots:
                message = f"co_display의 슬롯 '{other}'가 없습니다"
                findings.append(Finding(slot.file, slot.line, UNKNOWN_SLOT_ID, "error", message))


# 콘텐츠 슬롯(content)과 ARB 화면 문구 슬롯(ui)의 하위 디렉터리입니다.
UI_GROUP = "ui"
SLOT_GROUPS = ("content", UI_GROUP)
# ui 슬롯의 keys는 Flutter gen-l10n이 getter 이름으로 쓰는 Dart 식별자(lowerCamelCase)입니다.
ARB_KEY_PATTERN = regex.compile(r"[a-z][A-Za-z0-9]*")


def _check_ui_keys(slot: Slot, problems: _Problems) -> bool:
    """ui 슬롯의 키가 모두 lowerCamelCase인지 확인합니다. 어긋난 키마다 문제를 모읍니다."""
    bad_keys = [key for key in slot.keys if ARB_KEY_PATTERN.fullmatch(key) is None]
    for key in bad_keys:
        problems.add(slot.line, f"ui 슬롯 '{slot.id}'의 키 '{key}'는 lowerCamelCase 식별자여야 합니다")
    return not bad_keys


def load_slots(slots_dir: Path, rules: RuleSet) -> dict[str, Slot]:
    """`slots_dir/content/*.yaml`과 `slots_dir/ui/*.yaml`의 슬롯을 읽습니다. `_schema.yaml`이 검증 기준입니다.

    문제가 있으면 모두 모아 `LoadError`를 던집니다.
    """
    schema_problems = _Problems(slots_dir / SCHEMA_FILE)
    schema = _load_schema(schema_problems.file, schema_problems)
    findings = list(schema_problems.findings)
    slots: dict[str, Slot] = {}
    paths = [path for group in SLOT_GROUPS for path in sorted((slots_dir / group).glob("*.yaml"))]
    for path in paths:
        problems = _Problems(path)
        for data, line in _read_items(path, problems) or []:
            slot = _parse_slot(data, line, path, schema, problems)
            if slot is None:
                continue
            if path.parent.name == UI_GROUP and not _check_ui_keys(slot, problems):
                continue
            if slot.id in slots:
                first = slots[slot.id]
                problems.add(line, f"슬롯 id '{slot.id}'가 {first.file.name}:{first.line}과 중복됩니다")
                continue
            slots[slot.id] = slot
        findings.extend(problems.findings)
    _check_references(slots, rules, findings)
    if findings:
        raise LoadError(findings)
    return slots


# --- 원고 -------------------------------------------------------------------------------------------

ENTRY_KEYS = {"slot", "key", "type", "variant", "text"}


def _parse_entry(
    data: dict[str, object], line: int, file: Path, lang: str, problems: _Problems
) -> Entry | None:
    item = _Item(data, line, problems)
    item.check_unknown_keys(ENTRY_KEYS)
    slot = item.text("slot")
    key = item.text("key")
    text = item.text("text")
    entry_type = item.text("type", required=False)
    if entry_type is not None and entry_type not in SENTENCE_TYPES:
        item.fail(f"'type' 값 '{entry_type}'은(는) 허용되지 않습니다. 허용 값: {', '.join(SENTENCE_TYPES)}")
        return None
    variant = data.get("variant", 1)
    if not _is_int(variant) or cast(int, variant) < 1:
        item.fail("'variant'는 1 이상의 정수여야 합니다")
        return None
    if slot is None or key is None or text is None:
        return None
    return Entry(file, line, slot, key, entry_type, cast(int, variant), lang, text)


def load_content(content_dir: Path) -> list[Entry]:
    """`content_dir/<lang>/*.yaml` 원고를 모두 읽습니다. 디렉터리가 없으면 빈 목록입니다.

    문제가 있으면 모두 모아 `LoadError`를 던집니다.
    """
    entries: list[Entry] = []
    findings: list[Finding] = []
    if not content_dir.is_dir():
        return entries
    for lang_dir in sorted(path for path in content_dir.iterdir() if path.is_dir()):
        if lang_dir.name not in LANGS:
            message = f"언어 디렉터리 '{lang_dir.name}'은(는) 허용되지 않습니다. 허용 값: {', '.join(LANGS)}"
            findings.append(Finding(lang_dir, 1, SCHEMA_RULE_ID, "error", message))
            continue
        for path in sorted(lang_dir.glob("*.yaml")):
            problems = _Problems(path)
            for data, line in _read_items(path, problems) or []:
                entry = _parse_entry(data, line, path, lang_dir.name, problems)
                if entry is not None:
                    entries.append(entry)
            findings.extend(problems.findings)
    if findings:
        raise LoadError(findings)
    return entries

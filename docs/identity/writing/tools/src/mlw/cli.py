"""`mlw` 명령: 앞선 검사를 하나로 묶습니다.

종료 코드: error가 있으면 1, YAML 로드·구조 오류면 2, 그 밖에는 0.
"""

import argparse
import json
import sys
from collections.abc import Mapping, Sequence
from datetime import date
from pathlib import Path
from typing import cast

from mlw import paths
from mlw.arb import check_arb
from mlw.bundles import check_days, check_weeks
from mlw.completeness import RULE_MISSING, check_completeness
from mlw.docs import RULE_STALE, render_docs, stale_docs, write_docs
from mlw.ia import check_ia, load_ia
from mlw.loader import UI_GROUP, load_content, load_rules, load_slots
from mlw.model import LANGS, Entry, Finding, LoadError, ParamKind, RuleSet, Slot
from mlw.placeholders import Placeholder, parse
from mlw.sentence import check_sentence

GLOSSARY_SLOT = "glossary.value_name"
NAME_PARAM = "name"
# 호칭 최대 길이를 채우는 글자입니다. 글자 수만 세므로 무엇이든 됩니다.
NAME_FILLER = "가"
RULE_JSON = "load.json"
RULE_LENGTH_UNKNOWN = "style.length_unknown"
# 목록 값(`list:<범주>`)을 잇는 구분자입니다.
LIST_SEPARATOR = ", "
# 목록 값의 최대 원소 수입니다. 유일한 목록 매개변수인 집중 시간 branches의 엔진 상한(MAX_PICKS)과 같습니다.
LIST_MAX_ITEMS = 2
# 고정 자료 하루 항목(DayKeys)의 필드입니다.
REQUIRED_DAY_FIELDS = ("head", "guide", "color", "direction", "number", "focus")
OPTIONAL_DAY_FIELDS = ("tag_sentence", "tag_label")
EXIT_ERROR = 1
EXIT_LOAD_ERROR = 2


def longest_by_category(entries: Sequence[Entry], lang: str) -> dict[str, tuple[str, ...]]:
    """같은 언어의 값 이름 원고를 범주별로 긴 순서대로 모읍니다. 범주는 키 `<범주>.<값>`의 앞부분입니다."""
    by_category: dict[str, list[str]] = {}
    for entry in entries:
        if entry.slot == GLOSSARY_SLOT and entry.lang == lang:
            by_category.setdefault(entry.key.split(".")[0], []).append(entry.text)
    return {category: tuple(sorted(texts, key=len, reverse=True)) for category, texts in by_category.items()}


def _longest_value(placeholder: Placeholder, kind: ParamKind, by_category: Mapping[str, Sequence[str]]) -> str | None:
    """값 종류 규칙으로 가장 긴 렌더 값을 구합니다. 범주를 해석할 수 없으면 ValueError, 값이 없으면 None입니다."""
    if kind.kind == "glossary":
        category = placeholder.category or kind.default_category
        if category is None or category not in kind.categories:
            raise ValueError(placeholder.key)
        values = by_category.get(category, ())
        return values[0] if values else None
    if placeholder.category is not None or kind.kind == "none":
        raise ValueError(placeholder.key)
    if kind.kind == "list":
        values = by_category.get(kind.categories[0], ())
        return LIST_SEPARATOR.join(values[:LIST_MAX_ITEMS]) if values else None
    # number: 값 범위를 모르므로 값을 두지 않습니다.
    return None


def longest_values_for(
    entry: Entry,
    params: Mapping[str, ParamKind],
    by_category: Mapping[str, Sequence[str]],
    name_max: int | None,
) -> tuple[dict[str, str], list[str]]:
    """원고 하나의 글자 수 검사에 쓸 값과, 범주를 해석할 수 없는 자리표시자 목록입니다.

    값은 자리표시자 키(`name` 또는 `name:category`) -> 가장 긴 렌더 값입니다. 값이 없는 범주, 숫자,
    상한이 없는 호칭은 넣지 않습니다. 그러면 그 원고의 글자 수 검사는 건너뜁니다(Ruling 2).
    """
    try:
        placeholders = parse(entry.text)
    except ValueError:
        # 문법 오류는 문장 단위 검사가 보고합니다.
        return {}, []
    values: dict[str, str] = {}
    unresolved: list[str] = []
    for placeholder in placeholders:
        if placeholder.name == NAME_PARAM and placeholder.category is None:
            if name_max is not None:
                values[NAME_PARAM] = NAME_FILLER * name_max
            continue
        kind = params.get(placeholder.name)
        if kind is None:
            unresolved.append(placeholder.key)
            continue
        try:
            value = _longest_value(placeholder, kind, by_category)
        except ValueError:
            unresolved.append(placeholder.key)
            continue
        if value is not None:
            values[placeholder.key] = value
    return values, unresolved


def _sentence_findings(slots: Mapping[str, Slot], entries: Sequence[Entry], rules: RuleSet) -> list[Finding]:
    by_lang = {lang: longest_by_category(entries, lang) for lang in LANGS}
    findings: list[Finding] = []
    for entry in entries:
        slot = slots.get(entry.slot)
        if slot is None:
            continue
        max_length = slot.max_length.get(entry.lang)
        name_max = rules.josa.name_rules.max_length.get(entry.lang)
        params = slot.keys.get(entry.key, {})
        values, unresolved = longest_values_for(entry, params, by_lang.get(entry.lang, {}), name_max)
        if max_length is not None and unresolved:
            message = f"자리표시자 {', '.join(unresolved)}의 범주를 해석할 수 없어 글자 수를 계산하지 못했습니다"
            findings.append(Finding(entry.file, entry.line, RULE_LENGTH_UNKNOWN, "warn", message))
        findings.extend(
            check_sentence(
                entry,
                slot.purpose,
                rules,
                max_length,
                values,
                allowed=slot.allowed,
                forbidden=slot.forbidden,
            )
        )
    return findings


def _sorted(findings: Sequence[Finding]) -> list[Finding]:
    return sorted(findings, key=lambda finding: (str(finding.file), finding.line))


def _print_findings(findings: Sequence[Finding]) -> int:
    for finding in _sorted(findings):
        print(finding.format())
    return EXIT_ERROR if any(finding.severity == "error" for finding in findings) else 0


def _json_error(path: Path, line: int, message: str) -> LoadError:
    return LoadError([Finding(path, line, RULE_JSON, "error", message)])


def _read_json(path: Path) -> object:
    """JSON 파일을 읽습니다. 없거나 깨졌으면 `LoadError`입니다."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except UnicodeDecodeError as error:
        raise _json_error(path, 1, "UTF-8 파일이 아닙니다") from error
    except OSError as error:
        raise _json_error(path, 1, f"파일을 읽을 수 없습니다: {error.strerror or error}") from error
    except json.JSONDecodeError as error:
        raise _json_error(path, error.lineno, f"JSON 오류입니다: {error.msg}") from error


def _read_message_keys(path: Path) -> list[str]:
    data = _read_json(path)
    if not isinstance(data, list) or not all(isinstance(key, str) for key in data):
        raise _json_error(path, 1, "메시지 키 파일은 문자열 목록이어야 합니다")
    return [str(key) for key in data]


def _read_message_params(path: Path) -> dict[str, list[str]]:
    data = _read_json(path)
    if not isinstance(data, dict) or not all(
        isinstance(params, list) and all(isinstance(param, str) for param in params) for params in data.values()
    ):
        raise _json_error(path, 1, "매개변수 파일은 키 → 문자열 목록인 객체여야 합니다")
    return {str(key): [str(param) for param in params] for key, params in data.items()}


def _fixture_problem(data: object) -> str | None:
    """고정 자료 구조가 `check_weeks`의 기대와 어긋나면 이유를, 맞으면 None을 돌려줍니다."""
    if not isinstance(data, dict):
        return "고정 자료는 JSON 객체여야 합니다"
    start = data.get("start")
    try:
        date.fromisoformat(start if isinstance(start, str) else "")
    except ValueError:
        return f"'start'는 ISO 날짜(YYYY-MM-DD) 문자열이어야 합니다: {start!r}"
    samples = data.get("samples")
    if not isinstance(samples, list):
        return "'samples'는 목록이어야 합니다"
    for index, sample in enumerate(samples):
        where = f"samples[{index}]"
        if not isinstance(sample, dict):
            return f"{where}는 객체여야 합니다"
        if not isinstance(sample.get("birth_id"), str):
            return f"{where}.birth_id는 문자열이어야 합니다"
        days = sample.get("days")
        if not isinstance(days, list):
            return f"{where}.days는 목록이어야 합니다"
        for day_index, day in enumerate(days):
            problem = _day_problem(day, f"{where}.days[{day_index}]")
            if problem is not None:
                return problem
    return None


def _day_problem(day: object, where: str) -> str | None:
    if not isinstance(day, dict):
        return f"{where}는 객체여야 합니다"
    for name in REQUIRED_DAY_FIELDS:
        if not isinstance(day.get(name), str):
            return f"{where}.{name}은(는) 문자열이어야 합니다"
    for name in OPTIONAL_DAY_FIELDS:
        if name not in day or not (day[name] is None or isinstance(day[name], str)):
            return f"{where}.{name}은(는) 문자열 또는 null이어야 합니다"
    return None


def _read_fixture(path: Path) -> dict[str, object]:
    data = _read_json(path)
    problem = _fixture_problem(data)
    if problem is not None:
        raise _json_error(path, 1, problem)
    return cast(dict[str, object], data)


def _check(args: argparse.Namespace) -> int:
    rules = load_rules(args.rules_dir)
    all_slots = load_slots(args.slots_dir, rules)
    # ARB 화면 문구 슬롯은 원고(content/)가 없으므로 원고 검사에서 뺍니다.
    slots = {slot_id: slot for slot_id, slot in all_slots.items() if slot.file.parent.name != UI_GROUP}
    entries = load_content(args.content)
    message_keys = _read_message_keys(args.message_keys)
    message_params = _read_message_params(args.message_params)
    fixture = _read_fixture(args.fixture)
    ia = load_ia(args.ia)

    completeness = check_completeness(slots, entries, message_keys, LANGS, message_params)
    if args.partial:
        completeness = [finding for finding in completeness if finding.rule_id != RULE_MISSING]
    findings = [
        *check_ia(all_slots, ia),
        *completeness,
        *_sentence_findings(slots, entries, rules),
        *check_days(slots, entries, rules.limits.values(), LANGS, rules),
        *check_weeks(
            slots, entries, rules.limits.values(), LANGS, rules, fixture, message_keys, fixture_path=args.fixture
        ),
    ]
    return _print_findings(findings)


def _check_arb(args: argparse.Namespace) -> int:
    rules = load_rules(args.rules_dir)
    slots = load_slots(args.slots_dir, rules)
    return _print_findings(check_arb(args.arb_files, slots, rules))


def _gen_docs(args: argparse.Namespace) -> int:
    rules = load_rules(args.rules_dir)
    docs = render_docs(rules, load_slots(args.slots_dir, rules))
    if not args.check:
        write_docs(args.out_dir, docs)
        return 0
    stale = stale_docs(args.out_dir, docs)
    findings = [
        Finding(Path(args.out_dir.name) / name, 1, RULE_STALE, "error", "생성 문서가 오래됐습니다. `mlw gen-docs`를 실행하세요")
        for name in stale
    ]
    return _print_findings(findings)


def _gen_week_fixture(args: argparse.Namespace) -> int:
    # grpc 의존 모듈은 이 하위 명령에서만 불러옵니다.
    from mlw import week_fixture

    return week_fixture.main(["--engine", args.engine])


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="mlw", description="명리일기 라이팅 검사기")
    commands = parser.add_subparsers(dest="command", required=True)

    def add_dirs(command: argparse.ArgumentParser) -> None:
        command.add_argument("--rules-dir", type=Path, default=paths.RULES_DIR, help="규칙 디렉터리")
        command.add_argument("--slots-dir", type=Path, default=paths.SLOTS_DIR, help="슬롯 명세 디렉터리")

    def add_ia(command: argparse.ArgumentParser) -> None:
        command.add_argument("--ia", type=Path, default=paths.IA_FILE, help="IA 계약 파일(screens.json)")

    check = commands.add_parser("check", help="원고를 검사합니다")
    check.add_argument("content", nargs="?", type=Path, default=paths.CONTENT_DIR, help="원고 디렉터리")
    check.add_argument("--partial", action="store_true", help="없는 원고(complete.missing)를 보고하지 않습니다")
    check.add_argument("--message-keys", type=Path, default=paths.MESSAGE_KEYS_FILE, help="메시지 키 파일")
    check.add_argument(
        "--message-params", type=Path, default=paths.MESSAGE_PARAMS_FILE, help="메시지 키별 매개변수 파일"
    )
    check.add_argument("--fixture", type=Path, default=paths.FIXTURE_FILE, help="한 주 검사 고정 자료")
    add_dirs(check)
    add_ia(check)
    check.set_defaults(handler=_check)

    check_arb_command = commands.add_parser("check-arb", help="ARB 파일을 검사합니다")
    check_arb_command.add_argument("arb_files", nargs="+", type=Path, metavar="arb", help="ARB 파일")
    add_dirs(check_arb_command)
    check_arb_command.set_defaults(handler=_check_arb)

    gen_docs = commands.add_parser("gen-docs", help="규칙·슬롯 YAML에서 문서를 생성합니다")
    gen_docs.add_argument("--check", action="store_true", help="쓰지 않고 오래된 문서가 있으면 종료 코드 1입니다")
    gen_docs.add_argument("--out-dir", type=Path, default=paths.GENERATED_DIR, help="생성 문서 디렉터리")
    add_dirs(gen_docs)
    add_ia(gen_docs)
    gen_docs.set_defaults(handler=_gen_docs)

    fixture = commands.add_parser("gen-week-fixture", help="엔진으로 한 주 검사 고정 자료를 만듭니다")
    fixture.add_argument("--engine", required=True, help="엔진 주소, 예: localhost:50051")
    fixture.set_defaults(handler=_gen_week_fixture)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        return int(args.handler(args))
    except LoadError as error:
        for finding in _sorted(error.findings):
            print(finding.format())
        return EXIT_LOAD_ERROR


if __name__ == "__main__":
    sys.exit(main())

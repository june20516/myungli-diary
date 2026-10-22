"""ARB 검사: 앱 화면 문구(ARB 파일)에 문장 단위 규칙을 적용합니다. ICU plural과 조사 select는 가지마다 펼쳐 검사합니다."""

import json
import re
from collections.abc import Mapping, Sequence
from pathlib import Path

from mlw.icu import RULE_PLURAL, expand_entry, plural_problem
from mlw.josa_select import JOSA_SUFFIX
from mlw.model import DEFAULT_REGISTER, LANGS, Entry, Finding, LoadError, RuleSet, Slot
from mlw.sentence import check_sentence

RULE_ARB = "arb.format"
RULE_ARB_JOSA_ORPHAN = "arb.josa_orphan"
# 조사 select 변수(`titleJosa`)입니다. 같은 메시지에 원래 매개변수(`{title}`)가 있어야 합니다.
_JOSA_SELECT_VAR = re.compile(r"\{(\w+)" + JOSA_SUFFIX + r", select,")
LOCALE_KEY = "@@locale"
# ARB에서 슬롯에 없는 키는 정보 문구로 봅니다.
DEFAULT_PURPOSE = "info"


def _read_arb(path: Path) -> dict[str, object]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise LoadError([Finding(path, 1, RULE_ARB, "error", f"ARB 파일을 읽을 수 없습니다: {error}")]) from error
    if not isinstance(data, dict):
        raise LoadError([Finding(path, 1, RULE_ARB, "error", "ARB 최상위는 객체여야 합니다")])
    return data


def _locale(path: Path, data: Mapping[str, object]) -> str:
    locale = data.get(LOCALE_KEY)
    language = locale.replace("-", "_").split("_")[0] if isinstance(locale, str) else None
    if language not in LANGS:
        message = f"'{LOCALE_KEY}'가 없거나 허용되지 않습니다. 허용: {', '.join(LANGS)}"
        raise LoadError([Finding(path, 1, RULE_ARB, "error", message)])
    return language


def _key_lines(path: Path) -> dict[str, int]:
    """원문에서 `"<키>":` 가 처음 나오는 1부터 센 줄 번호입니다."""
    pattern = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:')
    lines: dict[str, int] = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        match = pattern.match(line)
        if match is not None:
            lines.setdefault(json.loads(f'"{match.group(1)}"'), number)
    return lines


def _slots_by_key(slots: Mapping[str, Slot]) -> dict[str, Slot]:
    return {key: slot for slot in slots.values() for key in slot.keys}


def check_arb(arb_paths: Sequence[Path], slots: Mapping[str, Slot], rules: RuleSet) -> list[Finding]:
    """ARB 파일의 메시지마다 문장 단위 규칙을 적용합니다. 읽을 수 없으면 `LoadError`입니다."""
    slot_of = _slots_by_key(slots)
    findings: list[Finding] = []
    for path in arb_paths:
        data = _read_arb(path)
        lang = _locale(path, data)
        lines = _key_lines(path)
        for key, value in data.items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            slot = slot_of.get(key)
            entry = Entry(path, lines.get(key, 1), slot.id if slot else "", key, None, 1, lang, value)
            problem = plural_problem(value, lang)
            if problem is not None:
                findings.append(Finding(path, entry.line, RULE_PLURAL, "error", problem))
                continue
            # select는 원래 매개변수 바로 뒤에 붙어 있어야 합니다(`{p}{pJosa, select, …}`).
            orphans = [
                name
                for name in dict.fromkeys(_JOSA_SELECT_VAR.findall(value))
                if value.count("{" + name + JOSA_SUFFIX + ", select,")
                != value.count("{" + name + "}{" + name + JOSA_SUFFIX + ", select,")
            ]
            if orphans:
                message = f"조사 매개변수의 원래 매개변수가 없습니다: {', '.join(orphans)}"
                findings.append(Finding(path, entry.line, RULE_ARB_JOSA_ORPHAN, "error", message))
                continue
            purpose = slot.purpose if slot else DEFAULT_PURPOSE
            max_length = slot.length_limit(lang, key) if slot else None
            allowed = slot.allowed if slot else frozenset()
            forbidden = slot.forbidden if slot else frozenset()
            register = slot.register if slot else DEFAULT_REGISTER
            # plural은 형태마다 펼친 문장을 검사하고, 같은 문제는 한 번만 냅니다.
            seen: set[tuple[str, str]] = set()
            for form in expand_entry(entry):
                for finding in check_sentence(
                    form, purpose, rules, max_length, {}, allowed=allowed, forbidden=forbidden, register=register
                ):
                    if (finding.rule_id, finding.message) not in seen:
                        seen.add((finding.rule_id, finding.message))
                        findings.append(finding)
    return findings

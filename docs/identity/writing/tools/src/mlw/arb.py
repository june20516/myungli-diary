"""ARB 검사: 앱 화면 문구(ARB 파일)에 문장 단위 규칙을 적용합니다."""

import json
import re
from collections.abc import Mapping, Sequence
from pathlib import Path

from mlw.model import LANGS, Entry, Finding, LoadError, RuleSet, Slot
from mlw.sentence import check_sentence

RULE_ARB = "arb.format"
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
            purpose = slot.purpose if slot else DEFAULT_PURPOSE
            max_length = slot.max_length.get(lang) if slot else None
            findings.extend(check_sentence(entry, purpose, rules, max_length, {}))
    return findings

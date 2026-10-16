"""근거 슬롯 검사: 근거 슬롯의 키를 core 근거 목록과 대조합니다(#130).

* `evidence.basis`는 `core/evidence_rules.json`의 규칙마다 키 `basis.<rule_id>`가 있고,
  그 매개변수 이름이 규칙의 `detail` 키와 같아야 합니다.
* `explain.today_reason`은 오늘 화면의 판정을 내는 규칙만 담으므로 일부만 있어도 됩니다(`reason.<rule_id>`).
* `evidence.source`는 `core/evidence_sources.json`의 원전마다 키 `source.<source_ref>`가 있어야 합니다.
"""

from collections.abc import Mapping, Sequence

from mlw.model import Finding, Slot

RULE_EVIDENCE_UNKNOWN = "evidence.unknown_ref"
RULE_EVIDENCE_MISSING = "evidence.missing_ref"
RULE_EVIDENCE_PARAM_MISMATCH = "evidence.param_mismatch"

REASON_SLOT = "explain.today_reason"
BASIS_SLOT = "evidence.basis"
SOURCE_SLOT = "evidence.source"


def _refs(slot: Slot, prefix: str, known: Sequence[str], what: str) -> tuple[dict[str, str], list[Finding]]:
    """슬롯 키에서 접두사를 뗀 참조 → 키를 돌려주고, core 목록에 없는 키를 보고합니다."""
    refs: dict[str, str] = {}
    findings: list[Finding] = []
    for key in slot.keys:
        ref = key.removeprefix(prefix)
        if key == ref or ref not in known:
            message = f"슬롯 '{slot.id}'의 키 '{key}'가 core {what}에 없습니다(키는 '{prefix}<{what}>')"
            findings.append(Finding(slot.file, slot.line, RULE_EVIDENCE_UNKNOWN, "error", message))
            continue
        refs[ref] = key
    return refs, findings


def _missing(
    slot: Slot, prefix: str, known: Sequence[str], refs: Mapping[str, str], what: str
) -> list[Finding]:
    return [
        Finding(
            slot.file,
            slot.line,
            RULE_EVIDENCE_MISSING,
            "error",
            f"슬롯 '{slot.id}'에 {what} '{ref}'의 키 '{prefix}{ref}'가 없습니다",
        )
        for ref in known
        if ref not in refs
    ]


def _param_mismatches(
    slot: Slot, refs: Mapping[str, str], rules: Mapping[str, Sequence[str]]
) -> list[Finding]:
    findings: list[Finding] = []
    for rule_id, key in refs.items():
        core_only = sorted(set(rules[rule_id]) - set(slot.keys[key]))
        spec_only = sorted(set(slot.keys[key]) - set(rules[rule_id]))
        if core_only or spec_only:
            message = (
                f"키 '{key}'의 매개변수가 core detail 키와 다릅니다: "
                f"core에만 {core_only or '없음'}, 명세에만 {spec_only or '없음'}"
            )
            findings.append(Finding(slot.file, slot.line, RULE_EVIDENCE_PARAM_MISMATCH, "error", message))
    return findings


def check_evidence(
    slots: Mapping[str, Slot], rules: Mapping[str, Sequence[str]], sources: Sequence[str]
) -> list[Finding]:
    """근거 슬롯의 키·매개변수가 core 근거 목록과 맞는지 봅니다. 슬롯이 없으면 건너뜁니다."""
    rule_ids = sorted(rules)
    findings: list[Finding] = []
    if (reason := slots.get(REASON_SLOT)) is not None:
        findings.extend(_refs(reason, "reason.", rule_ids, "rule_id")[1])
    if (basis := slots.get(BASIS_SLOT)) is not None:
        refs, unknown = _refs(basis, "basis.", rule_ids, "rule_id")
        findings.extend(unknown)
        findings.extend(_missing(basis, "basis.", rule_ids, refs, "rule_id"))
        findings.extend(_param_mismatches(basis, refs, rules))
    if (source := slots.get(SOURCE_SLOT)) is not None:
        refs, unknown = _refs(source, "source.", sources, "source_ref")
        findings.extend(unknown)
        findings.extend(_missing(source, "source.", sources, refs, "source_ref"))
    return findings

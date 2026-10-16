"""LLM 판정 명령(결정 W1): `judge: llm` slop 규칙을 루브릭으로 모델에 물어 의심 문장을 표시합니다.

로컬 1차 거르기라 막지 않습니다. 의심은 모두 `warn`이고, 모델 호출이나 응답이 잘못돼도 예외 대신 경고를 남깁니다.
모델 호출은 `Caller`(프롬프트, JSON Schema → 구조화 응답)로 받아, 테스트는 가짜 함수로 바꿉니다.
기본 호출은 Claude Code headless(`claude -p`)입니다. 사용자 설정·hook·도구를 모두 빼고 부릅니다.
"""

import json
import subprocess
from collections.abc import Callable, Mapping, Sequence
from itertools import groupby
from typing import Any

from mlw.icu import expand_entry
from mlw.model import Entry, Finding, RuleSet, SlopRule, Slot

RULE_BAD_RESPONSE = "judge.bad_response"
RULE_CALL_FAILED = "judge.call_failed"
DEFAULT_MODEL = "sonnet"
DEFAULT_BATCH_SIZE = 40
CALL_TIMEOUT_SECONDS = 300

Caller = Callable[[str, dict[str, Any]], object]


class JudgeError(Exception):
    """모델을 부르지 못했거나 응답을 받지 못했습니다."""


def judge_rules_for(slot: Slot, rules: RuleSet) -> list[SlopRule]:
    """이 슬롯에 물을 `judge: llm` 규칙입니다. 목적 예외는 빼고, `allowed`는 빼고, `forbidden`은 예외와 상관없이 넣습니다."""
    return [
        rule
        for rule in rules.slop.values()
        if rule.judge == "llm"
        and rule.id not in slot.allowed
        and (slot.purpose not in rule.exempt_purposes or rule.id in slot.forbidden)
    ]


def response_schema(rule_ids: Sequence[str]) -> dict[str, Any]:
    """모델 응답의 JSON Schema입니다. 규칙 id는 물은 규칙으로만 고를 수 있습니다."""
    flag = {
        "type": "object",
        "properties": {
            "index": {"type": "integer"},
            "rule": {"type": "string", "enum": list(rule_ids)},
            "reason": {"type": "string"},
        },
        "required": ["index", "rule", "reason"],
    }
    return {
        "type": "object",
        "properties": {"flags": {"type": "array", "items": flag}},
        "required": ["flags"],
    }


def _rule_text(rule: SlopRule) -> str:
    lines = [f"## {rule.id} {rule.name}", f"판정 기준: {rule.rubric}"]
    lines.extend(f"- 해당하는 예({example.slot_purpose}): {example.text}" for example in rule.examples.hit)
    lines.extend(
        f"- 해당하지 않는 예({example.slot_purpose}): {example.text}" for example in rule.examples.pass_
    )
    return "\n".join(lines)


def build_prompt(slot: Slot, lang: str, judge_rules: Sequence[SlopRule], sentences: Sequence[str]) -> str:
    numbered = "\n".join(f"{index}. {text}" for index, text in enumerate(sentences, start=1))
    rule_texts = "\n\n".join(_rule_text(rule) for rule in judge_rules)
    return (
        "명리일기 앱의 문장을 slop 규칙으로 판정합니다. 규칙의 판정 기준에 해당한다고 볼 만한 문장만 표시하고,"
        " 확실하지 않으면 표시하지 않습니다. 표시마다 문장 번호(index), 규칙 id(rule), 이유 한 문장(reason, 한국어)을 답합니다."
        " 해당하는 문장이 없으면 flags를 빈 목록으로 답합니다.\n"
        "{이름} 같은 중괄호는 앱이 값을 넣는 자리이고, [[글자|용어 id]]는 명리 용어 표시입니다.\n\n"
        f"# 슬롯\n{slot.id}: {slot.where}\n목적: {slot.purpose} (info 정보, guide 안내, care 위로·공감)\n언어: {lang}\n\n"
        f"# 규칙\n{rule_texts}\n\n# 문장\n{numbered}\n"
    )


def _flags(response: object, count: int, rule_ids: set[str]) -> list[tuple[int, str, str]] | str:
    """응답에서 (index, rule, reason) 목록을 꺼냅니다. 잘못된 응답이면 이유 문자열입니다."""
    if not isinstance(response, dict) or not isinstance(response.get("flags"), list):
        return "응답에 flags 목록이 없습니다"
    flags: list[tuple[int, str, str]] = []
    for flag in response["flags"]:
        if not isinstance(flag, dict):
            return "flags 항목이 객체가 아닙니다"
        index, rule, reason = flag.get("index"), flag.get("rule"), flag.get("reason")
        if not isinstance(index, int) or not 1 <= index <= count:
            return f"문장 번호 {index!r}가 범위(1~{count}) 밖입니다"
        if rule not in rule_ids or not isinstance(rule, str):
            return f"물은 규칙이 아닌 {rule!r}입니다"
        if not isinstance(reason, str):
            return "이유(reason)가 없습니다"
        flags.append((index, rule, reason))
    return flags


def _batch_failed(batch: Sequence[Entry], rule_id: str, message: str) -> list[Finding]:
    """판정하지 못한 묶음은 문장마다 남깁니다. shadow 비교가 판정 못 한 문장을 '표시 안 함'과 가려냅니다."""
    return [Finding(entry.file, entry.line, rule_id, "warn", message) for entry in batch]


def _judge_batch(
    slot: Slot, lang: str, judge_rules: Sequence[SlopRule], batch: Sequence[Entry], call: Caller
) -> list[Finding]:
    rule_ids = [rule.id for rule in judge_rules]
    try:
        response = call(
            build_prompt(slot, lang, judge_rules, [entry.text for entry in batch]), response_schema(rule_ids)
        )
    except JudgeError as error:
        message = f"슬롯 {slot.id}({lang}) 문장 {len(batch)}개를 판정하지 못했습니다: {error}"
        return _batch_failed(batch, RULE_CALL_FAILED, message)
    flags = _flags(response, len(batch), set(rule_ids))
    if isinstance(flags, str):
        message = f"슬롯 {slot.id}({lang})의 모델 응답을 읽지 못했습니다: {flags}"
        return _batch_failed(batch, RULE_BAD_RESPONSE, message)
    findings: list[Finding] = []
    for index, rule_id, reason in flags:
        entry = batch[index - 1]
        message = f"LLM 의심({entry.key}): {reason}"
        findings.append(Finding(entry.file, entry.line, rule_id, "warn", message))
    return findings


def judge_entries(
    slots: Mapping[str, Slot],
    entries: Sequence[Entry],
    rules: RuleSet,
    call: Caller,
    *,
    lang: str | None = None,
    slot_id: str | None = None,
    batch_size: int = DEFAULT_BATCH_SIZE,
) -> list[Finding]:
    """원고를 슬롯·언어별로 묶어 `batch_size`개씩 모델에 묻습니다. plural은 형태마다 한 문장으로 봅니다."""
    selected = [
        form
        for entry in entries
        if entry.slot in slots
        and (lang is None or entry.lang == lang)
        and (slot_id is None or entry.slot == slot_id)
        for form in expand_entry(entry)
    ]
    findings: list[Finding] = []
    group_key: Callable[[Entry], tuple[str, str]] = lambda entry: (entry.slot, entry.lang)
    for (group_slot, group_lang), group in groupby(sorted(selected, key=group_key), key=group_key):
        slot = slots[group_slot]
        judge_rules = judge_rules_for(slot, rules)
        if not judge_rules:
            continue
        items = list(group)
        for start in range(0, len(items), batch_size):
            findings.extend(
                _judge_batch(slot, group_lang, judge_rules, items[start : start + batch_size], call)
            )
    return findings


def claude_cli_caller(model: str = DEFAULT_MODEL) -> Caller:
    """Claude Code headless(`claude -p`)로 부르는 함수입니다. 설정·hook·도구를 모두 빼고 구조화 출력만 받습니다."""

    def call(prompt: str, schema: dict[str, Any]) -> object:
        args = [
            "claude",
            "-p",
            "--output-format",
            "json",
            "--tools",
            "",
            "--setting-sources",
            "",
            "--no-session-persistence",
            "--model",
            model,
            "--json-schema",
            json.dumps(schema, ensure_ascii=False),
        ]
        try:
            completed = subprocess.run(
                args, input=prompt, capture_output=True, text=True, timeout=CALL_TIMEOUT_SECONDS, check=False
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise JudgeError(f"claude를 실행하지 못했습니다: {error}") from error
        if completed.returncode != 0:
            raise JudgeError(
                f"claude가 {completed.returncode}로 끝났습니다: {completed.stderr.strip()[:200]}"
            )
        try:
            body = json.loads(completed.stdout)
        except json.JSONDecodeError as error:
            raise JudgeError("claude 출력이 JSON이 아닙니다") from error
        if not isinstance(body, dict) or body.get("is_error") or "structured_output" not in body:
            result = body.get("result") if isinstance(body, dict) else None
            raise JudgeError(f"구조화 응답이 없습니다: {str(result)[:200]}")
        return body["structured_output"]

    return call

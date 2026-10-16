"""LLM 판정 명령(`mlw judge`, 결정 W1) 테스트. 모델 호출은 가짜 함수로 바꿉니다."""

import json
import subprocess
from pathlib import Path
from typing import Any

import pytest

from mlw.judge import (
    RULE_BAD_RESPONSE,
    RULE_CALL_FAILED,
    JudgeError,
    claude_cli_caller,
    judge_entries,
    judge_rules_for,
    response_schema,
)
from mlw.loader import load_rules
from mlw.model import Entry, RuleSet, Slot
from mlw.paths import RULES_DIR

CONTENT = Path("content/ko/ui.yaml")


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


def make_slot(slot_id: str = "s.info", purpose: str = "info", **overrides: Any) -> Slot:
    fields: dict[str, Any] = {
        "id": slot_id,
        "where": "시험",
        "purpose": purpose,
        "types": (),
        "variants": 1,
        "keys": {"k1": {}, "k2": {}, "k3": {}},
        "co_display": (),
        "max_length": {"ko": None, "en": None, "ja": None},
        "allowed": frozenset(),
        "forbidden": frozenset(),
        "examples": {},
        "line": 1,
        "file": Path("slots/ui/test.yaml"),
    }
    return Slot(**(fields | overrides))


def entry(line: int, text: str, slot: str = "s.info", lang: str = "ko", key: str = "k1") -> Entry:
    return Entry(CONTENT, line, slot, key, None, 1, lang, text)


class FakeCaller:
    """받은 프롬프트·스키마를 기록하고, 정해 둔 응답을 차례로 돌려줍니다."""

    def __init__(self, *responses: object) -> None:
        self.responses = list(responses)
        self.calls: list[tuple[str, dict[str, Any]]] = []

    def __call__(self, prompt: str, schema: dict[str, Any]) -> object:
        self.calls.append((prompt, schema))
        response = self.responses.pop(0)
        if isinstance(response, JudgeError):
            raise response
        return response


def llm_rule_ids(rules: RuleSet) -> set[str]:
    return {rule.id for rule in rules.slop.values() if rule.judge == "llm"}


def test_rules_follow_purpose_allowed_and_forbidden(rules: RuleSet) -> None:
    every = llm_rule_ids(rules)
    assert "slop.P1" in every
    assert {rule.id for rule in judge_rules_for(make_slot(), rules)} == every
    # 위로·공감 슬롯은 P1에서 예외입니다.
    assert "slop.P1" not in {rule.id for rule in judge_rules_for(make_slot(purpose="care"), rules)}
    allowed = make_slot(allowed=frozenset({"slop.P3"}))
    assert "slop.P3" not in {rule.id for rule in judge_rules_for(allowed, rules)}
    forced = make_slot(purpose="care", forbidden=frozenset({"slop.P1"}))
    assert "slop.P1" in {rule.id for rule in judge_rules_for(forced, rules)}


def test_schema_limits_rule_ids(rules: RuleSet) -> None:
    schema = response_schema(["slop.P1", "slop.P3"])
    item = schema["properties"]["flags"]["items"]
    assert item["properties"]["rule"]["enum"] == ["slop.P1", "slop.P3"]
    assert set(item["required"]) == {"index", "rule", "reason"}


def test_prompt_has_rubric_purpose_and_numbered_sentences(rules: RuleSet) -> None:
    caller = FakeCaller({"flags": []})
    entries = [entry(3, "흐름이 보여요."), entry(4, "오늘은 남색이 잘 맞아요.", key="k2")]
    assert judge_entries({"s.info": make_slot()}, entries, rules, caller) == []
    prompt, schema = caller.calls[0]
    assert rules.slop["slop.P1"].rubric is not None
    assert rules.slop["slop.P1"].rubric in prompt
    assert "info" in prompt
    assert "1. 흐름이 보여요." in prompt
    assert "2. 오늘은 남색이 잘 맞아요." in prompt
    assert set(schema["properties"]["flags"]["items"]["properties"]["rule"]["enum"]) == llm_rule_ids(rules)


def test_flags_become_warn_findings_at_entry_line(rules: RuleSet) -> None:
    caller = FakeCaller({"flags": [{"index": 2, "rule": "slop.P1", "reason": "무엇을 말하는지 없음"}]})
    entries = [entry(3, "오늘은 남색이 잘 맞아요."), entry(4, "흐름이 보여요.", key="k2")]
    [finding] = judge_entries({"s.info": make_slot()}, entries, rules, caller)
    assert (finding.file, finding.line, finding.rule_id, finding.severity) == (CONTENT, 4, "slop.P1", "warn")
    assert "무엇을 말하는지 없음" in finding.message


@pytest.mark.parametrize(
    "response",
    [
        {"flags": [{"index": 9, "rule": "slop.P1", "reason": "x"}]},
        {"flags": [{"index": 1, "rule": "slop.P2", "reason": "x"}]},
        {"flags": [{"index": 1, "rule": "slop.P1"}]},
        {"nope": []},
        "not json",
    ],
)
def test_bad_response_is_reported_not_raised(rules: RuleSet, response: object) -> None:
    findings = judge_entries(
        {"s.info": make_slot()}, [entry(3, "흐름이 보여요.")], rules, FakeCaller(response)
    )
    assert [finding.rule_id for finding in findings] == [RULE_BAD_RESPONSE]
    assert findings[0].severity == "warn"


def test_call_failure_is_reported_and_other_batches_continue(rules: RuleSet) -> None:
    caller = FakeCaller(JudgeError("시간 초과"), {"flags": [{"index": 1, "rule": "slop.P1", "reason": "x"}]})
    entries = [entry(3, "가"), entry(4, "나", key="k2"), entry(5, "다", key="k3")]
    findings = judge_entries({"s.info": make_slot()}, entries, rules, caller, batch_size=2)
    assert len(caller.calls) == 2
    assert [(finding.rule_id, finding.line) for finding in findings] == [
        (RULE_CALL_FAILED, 3),
        ("slop.P1", 5),
    ]
    assert "시간 초과" in findings[0].message


def test_batches_are_split_by_slot_and_language(rules: RuleSet) -> None:
    slots = {"s.info": make_slot(), "s.guide": make_slot("s.guide", "guide")}
    entries = [entry(1, "가"), entry(2, "Hello.", lang="en"), entry(3, "나", slot="s.guide")]
    caller = FakeCaller({"flags": []}, {"flags": []}, {"flags": []})
    judge_entries(slots, entries, rules, caller)
    assert len(caller.calls) == 3


def test_filters_by_language_and_slot(rules: RuleSet) -> None:
    slots = {"s.info": make_slot(), "s.guide": make_slot("s.guide", "guide")}
    entries = [entry(1, "가"), entry(2, "Hello.", lang="en"), entry(3, "나", slot="s.guide")]
    caller = FakeCaller({"flags": []})
    judge_entries(slots, entries, rules, caller, lang="ko", slot_id="s.guide")
    assert len(caller.calls) == 1
    assert "1. 나" in caller.calls[0][0]


def test_slot_without_applicable_rule_is_skipped(rules: RuleSet) -> None:
    every = frozenset(llm_rule_ids(rules))
    caller = FakeCaller()
    assert judge_entries({"s.info": make_slot(allowed=every)}, [entry(1, "가")], rules, caller) == []
    assert caller.calls == []


def test_plural_forms_are_judged_as_sentences(rules: RuleSet) -> None:
    caller = FakeCaller({"flags": []})
    text = "{count, plural, one{{count} city} other{{count} cities}}"
    judge_entries({"s.info": make_slot()}, [entry(1, text, lang="en")], rules, caller)
    prompt = caller.calls[0][0]
    assert "1. {count} city" in prompt
    assert "2. {count} cities" in prompt


def test_claude_cli_caller_runs_headless_without_tools_or_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: dict[str, Any] = {}

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        seen["args"], seen["input"] = args, kwargs["input"]
        body = {"is_error": False, "structured_output": {"flags": []}}
        return subprocess.CompletedProcess(args, 0, stdout=json.dumps(body), stderr="")

    monkeypatch.setattr(subprocess, "run", fake_run)
    schema = response_schema(["slop.P1"])
    assert claude_cli_caller("sonnet")("프롬프트", schema) == {"flags": []}
    args = seen["args"]
    assert args[:2] == ["claude", "-p"]
    for flag, value in (
        ("--output-format", "json"),
        ("--tools", ""),
        ("--setting-sources", ""),
        ("--model", "sonnet"),
    ):
        assert args[args.index(flag) + 1] == value
    assert json.loads(args[args.index("--json-schema") + 1]) == schema
    assert "--no-session-persistence" in args
    assert seen["input"] == "프롬프트"


@pytest.mark.parametrize(
    ("returncode", "stdout"),
    [
        (1, ""),
        (0, "not json"),
        (0, json.dumps({"is_error": True, "result": "막힘"})),
        (0, json.dumps({"is_error": False})),
    ],
)
def test_claude_cli_caller_errors(monkeypatch: pytest.MonkeyPatch, returncode: int, stdout: str) -> None:
    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, returncode, stdout=stdout, stderr="오류")

    monkeypatch.setattr(subprocess, "run", fake_run)
    with pytest.raises(JudgeError):
        claude_cli_caller("sonnet")("프롬프트", response_schema(["slop.P1"]))


def test_claude_cli_caller_missing_binary(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        raise FileNotFoundError("claude")

    monkeypatch.setattr(subprocess, "run", fake_run)
    with pytest.raises(JudgeError):
        claude_cli_caller("sonnet")("프롬프트", response_schema(["slop.P1"]))

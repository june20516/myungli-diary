"""jev shadow 판정(W1 spec §6.2): `judge: llm` 규칙을 TypeSafe jev에 따로 물어 `claude -p` 판정과 짝지어 기록합니다.

본 판정은 바꾸지 않습니다. 결과는 jev 대체 가능성 과제(`plans/2026-10-16-jev-judge-evaluation.md`)의 비교 자료입니다.
문장 하나에 요청 하나를 보내고, 규칙마다 `noul`(예일 확률) 질문 하나를 붙입니다.
API 키는 환경 변수 `TYPESAFE_API_KEY`로만 받고 기록에 남기지 않습니다.
"""

import json
import time
import urllib.error
import urllib.request
from collections.abc import Callable, Mapping, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Final, Literal

from mlw.icu import expand_entry
from mlw.judge import judge_rules_for
from mlw.model import Entry, Finding, RuleSet, SlopRule, Slot

API_KEY_ENV: Final = "TYPESAFE_API_KEY"
JEV_URL: Final = "https://api.typesafe.ai/v1/systemone"
JEV_MODEL: Final = "jev-latest"
FLAG_THRESHOLD: Final = 0.5
MAX_RETRIES: Final = 5
REQUEST_TIMEOUT_SECONDS: Final = 60
RETRY_STATUSES: Final = frozenset({429, 529})
LIMIT_STATUSES: Final = frozenset({401, 402, 403})

Poster = Callable[[dict[str, Any]], dict[str, Any]]
Status = Literal["ok", "limit", "error"]


class JevLimitReached(Exception):
    """한도에 도달했습니다(재시도 뒤에도 429·529, 또는 401·402·403). 이 실행에서는 더 부르지 않습니다."""


class JevError(Exception):
    """이 요청 하나가 실패했습니다. 다음 문장은 계속 묻습니다."""


def http_poster(
    api_key: str,
    *,
    sleep: Callable[[float], None] = time.sleep,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> Poster:
    """TypeSafe API에 POST하는 함수입니다. 429·529는 `retry-after`(없으면 2·4·8·16·32초)만큼 기다려 다시 보냅니다."""

    def post(body: dict[str, Any]) -> dict[str, Any]:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        for attempt in range(MAX_RETRIES + 1):
            request = urllib.request.Request(JEV_URL, data=data, headers=headers, method="POST")
            try:
                with opener(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                    payload = json.loads(response.read())
            except urllib.error.HTTPError as error:
                if error.code in LIMIT_STATUSES:
                    raise JevLimitReached(f"HTTP {error.code}") from error
                if error.code in RETRY_STATUSES and attempt < MAX_RETRIES:
                    sleep(_retry_delay(error.headers.get("retry-after"), attempt))
                    continue
                if error.code in RETRY_STATUSES:
                    raise JevLimitReached(f"HTTP {error.code}, 재시도 {MAX_RETRIES}회") from error
                raise JevError(f"HTTP {error.code}") from error
            except (OSError, ValueError) as error:
                raise JevError(f"요청 실패: {type(error).__name__}") from error
            if not isinstance(payload, dict):
                raise JevError("응답이 객체가 아닙니다")
            return payload
        raise AssertionError("재시도 반복은 위에서 끝납니다")

    return post


def _retry_delay(retry_after: str | None, attempt: int) -> float:
    if retry_after is not None:
        try:
            return float(retry_after)
        except ValueError:
            pass
    return float(2 ** (attempt + 1))


def build_request(slot: Slot, lang: str, judge_rules: Sequence[SlopRule], sentence: str) -> dict[str, Any]:
    questions = {
        rule.id: {
            "type": "noul",
            "instructions": {
                "rule": rule.name,
                "rubric": rule.rubric,
                "question": "Does `sentence` match `rubric`?",
            },
            "criteria": {
                "true": [example.text for example in rule.examples.hit],
                "false": [example.text for example in rule.examples.pass_],
            },
        }
        for rule in judge_rules
    }
    state = {"sentence": sentence, "slot": slot.where, "purpose": slot.purpose, "language": lang}
    return {"model": JEV_MODEL, "state": state, "questions": questions}


@dataclass(frozen=True)
class JevAnswer:
    entry: Entry
    rule_id: str
    noul: float | None
    model: str | None
    status: Status


def _answers_for(entry: Entry, rule_ids: Sequence[str], response: dict[str, Any]) -> list[JevAnswer]:
    model = response.get("model") if isinstance(response.get("model"), str) else None
    raw = response.get("answers")
    by_rule = raw if isinstance(raw, dict) else {}
    answers: list[JevAnswer] = []
    for rule_id in rule_ids:
        answer = by_rule.get(rule_id)
        noul = answer.get("noul") if isinstance(answer, dict) else None
        if isinstance(noul, int | float) and not isinstance(noul, bool):
            answers.append(JevAnswer(entry, rule_id, float(noul), model, "ok"))
        else:
            answers.append(JevAnswer(entry, rule_id, None, model, "error"))
    return answers


def jev_answers(
    slots: Mapping[str, Slot],
    entries: Sequence[Entry],
    rules: RuleSet,
    post: Poster,
    *,
    lang: str | None = None,
    slot_id: str | None = None,
) -> list[JevAnswer]:
    """문장 고르기는 `judge_entries`와 같습니다. 한도에 도달하면 남은 문장은 묻지 않고 `limit`으로 채웁니다."""
    selected = [
        form
        for entry in entries
        if entry.slot in slots
        and (lang is None or entry.lang == lang)
        and (slot_id is None or entry.slot == slot_id)
        for form in expand_entry(entry)
    ]
    answers: list[JevAnswer] = []
    limit_reached = False
    for entry in selected:
        slot = slots[entry.slot]
        judge_rules = judge_rules_for(slot, rules)
        if not judge_rules:
            continue
        rule_ids = [rule.id for rule in judge_rules]
        if not limit_reached:
            try:
                response = post(build_request(slot, entry.lang, judge_rules, entry.text))
            except JevLimitReached:
                limit_reached = True
            except JevError:
                answers.extend(JevAnswer(entry, rule_id, None, None, "error") for rule_id in rule_ids)
                continue
            else:
                answers.extend(_answers_for(entry, rule_ids, response))
                continue
        answers.extend(JevAnswer(entry, rule_id, None, None, "limit") for rule_id in rule_ids)
    return answers


@dataclass(frozen=True)
class ShadowRecord:
    file: str
    line: int
    slot: str
    key: str
    lang: str
    text: str
    rule_id: str
    claude_flag: bool
    claude_reason: str | None
    jev_noul: float | None
    jev_flag: bool | None
    jev_model: str | None
    status: Status


def pair_records(answers: Sequence[JevAnswer], claude: Sequence[Finding]) -> list[ShadowRecord]:
    """jev 답과 `claude -p` 표시를 `(file, line, rule_id)`로 짝짓습니다.

    `claude -p` 표시에는 plural 형태 구분이 없어, 한 줄의 plural 형태가 여럿이면 표시가 모든 형태에 붙습니다.
    """
    reasons = {
        (str(finding.file), finding.line, finding.rule_id): finding.message
        for finding in claude
        if finding.rule_id.startswith("slop.")
    }
    records: list[ShadowRecord] = []
    for answer in answers:
        entry = answer.entry
        reason = reasons.get((str(entry.file), entry.line, answer.rule_id))
        jev_flag = None if answer.noul is None else answer.noul >= FLAG_THRESHOLD
        records.append(
            ShadowRecord(
                str(entry.file),
                entry.line,
                entry.slot,
                entry.key,
                entry.lang,
                entry.text,
                answer.rule_id,
                reason is not None,
                reason,
                answer.noul,
                jev_flag,
                answer.model,
                answer.status,
            )
        )
    return records


def write_shadow(records: Sequence[ShadowRecord], path: Path) -> None:
    """기록을 JSONL로 씁니다. 라운드 기록을 지키려고 이미 있는 파일은 덮어쓰지 않습니다."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as file:
        for record in records:
            file.write(json.dumps(asdict(record), ensure_ascii=False) + "\n")

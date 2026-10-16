"""jev shadow 판정(`mlw judge --shadow jev`) 테스트. 네트워크는 가짜 Poster·opener로 바꿉니다."""

import io
import json
import urllib.error
from pathlib import Path
from typing import Any

import pytest

from mlw.jev import (
    FLAG_THRESHOLD,
    JEV_MODEL,
    JevError,
    JevLimitReached,
    build_request,
    http_poster,
    jev_answers,
    pair_records,
    write_shadow,
)
from mlw.judge import judge_rules_for
from mlw.loader import load_rules
from mlw.model import Entry, Finding, RuleSet, Slot
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
        "keys": {"k1": {}, "k2": {}},
        "co_display": (),
        "max_length": {"ko": None, "en": None, "ja": None},
        "allowed": frozenset(),
        "forbidden": frozenset(),
        "examples": {},
        "line": 1,
        "file": Path("slots/ui/test.yaml"),
    }
    return Slot(**(fields | overrides))


def entry(line: int, text: str, lang: str = "ko", key: str = "k1") -> Entry:
    return Entry(CONTENT, line, "s.info", key, None, 1, lang, text)


def rule_ids(rules: RuleSet) -> list[str]:
    return [rule.id for rule in judge_rules_for(make_slot(), rules)]


class FakePoster:
    """받은 요청을 기록하고 정해 둔 응답(또는 예외)을 차례로 돌려줍니다."""

    def __init__(self, *responses: object) -> None:
        self.responses = list(responses)
        self.bodies: list[dict[str, Any]] = []

    def __call__(self, body: dict[str, Any]) -> dict[str, Any]:
        self.bodies.append(body)
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        assert isinstance(response, dict)
        return response


def answer_all(ids: list[str], noul: float = 0.1) -> dict[str, Any]:
    return {"model": "jev-1.13.0", "answers": {i: {"type": "noul", "noul": noul} for i in ids}}


def test_request_asks_one_noul_per_rule_with_rubric_and_examples(rules: RuleSet) -> None:
    judge_rules = judge_rules_for(make_slot(), rules)
    body = build_request(make_slot(), "ko", judge_rules, "흐름이 보여요.")
    assert body["model"] == JEV_MODEL
    assert body["state"]["sentence"] == "흐름이 보여요."
    assert body["state"]["purpose"] == "info"
    assert set(body["questions"]) == {rule.id for rule in judge_rules}
    p1 = rules.slop["slop.P1"]
    question = body["questions"]["slop.P1"]
    assert question["type"] == "noul"
    assert question["instructions"]["rubric"] == p1.rubric
    assert question["criteria"]["true"] == [example.text for example in p1.examples.hit]
    assert question["criteria"]["false"] == [example.text for example in p1.examples.pass_]


def test_answers_one_request_per_sentence(rules: RuleSet) -> None:
    ids = rule_ids(rules)
    poster = FakePoster(answer_all(ids, 0.9), answer_all(ids, 0.2))
    answers = jev_answers({"s.info": make_slot()}, [entry(1, "가"), entry(2, "나", key="k2")], rules, poster)
    assert len(poster.bodies) == 2
    assert len(answers) == 2 * len(ids)
    assert {answer.status for answer in answers} == {"ok"}
    assert {answer.noul for answer in answers if answer.entry.line == 1} == {0.9}
    assert {answer.model for answer in answers} == {"jev-1.13.0"}


def test_limit_stops_calling_and_marks_rest(rules: RuleSet) -> None:
    poster = FakePoster(JevLimitReached("429"))
    entries = [entry(1, "가"), entry(2, "나", key="k2")]
    answers = jev_answers({"s.info": make_slot()}, entries, rules, poster)
    assert len(poster.bodies) == 1
    assert len(answers) == 2 * len(rule_ids(rules))
    assert {answer.status for answer in answers} == {"limit"}
    assert {answer.noul for answer in answers} == {None}


def test_missing_or_bad_answer_is_error_for_that_rule_only(rules: RuleSet) -> None:
    ids = rule_ids(rules)
    first = answer_all(ids)
    del first["answers"][ids[0]]
    first["answers"][ids[1]]["noul"] = "x"
    poster = FakePoster(first, JevError("500"), answer_all(ids))
    entries = [entry(1, "가"), entry(2, "나", key="k2"), entry(3, "다")]
    answers = jev_answers({"s.info": make_slot()}, entries, rules, poster)
    status = {(answer.entry.line, answer.rule_id): answer.status for answer in answers}
    assert status[(1, ids[0])] == status[(1, ids[1])] == "error"
    assert {status[(1, rule_id)] for rule_id in ids[2:]} == {"ok"}
    assert {status[(2, rule_id)] for rule_id in ids} == {"error"}
    assert {status[(3, rule_id)] for rule_id in ids} == {"ok"}


def test_plural_forms_are_asked_separately(rules: RuleSet) -> None:
    ids = rule_ids(rules)
    poster = FakePoster(answer_all(ids), answer_all(ids))
    text = "{count, plural, one{{count} city} other{{count} cities}}"
    jev_answers({"s.info": make_slot()}, [entry(1, text, lang="en")], rules, poster)
    assert [body["state"]["sentence"] for body in poster.bodies] == ["{count} city", "{count} cities"]


def http_error(code: int, headers: dict[str, str] | None = None) -> urllib.error.HTTPError:
    return urllib.error.HTTPError("u", code, "x", headers or {}, io.BytesIO(b"{}"))  # type: ignore[arg-type]


class FakeOpener:
    def __init__(self, *outcomes: object) -> None:
        self.outcomes = list(outcomes)
        self.requests: list[Any] = []

    def __call__(self, request: Any, timeout: float) -> io.BytesIO:
        self.requests.append(request)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return io.BytesIO(json.dumps(outcome).encode())


def test_http_poster_retries_429_then_succeeds() -> None:
    sleeps: list[float] = []
    opener = FakeOpener(http_error(429, {"retry-after": "3"}), {"answers": {}})
    post = http_poster("key-1", sleep=sleeps.append, opener=opener)
    assert post({"model": JEV_MODEL}) == {"answers": {}}
    assert sleeps == [3.0]
    assert opener.requests[0].get_header("Authorization") == "Bearer key-1"


def test_http_poster_limit_after_retries_and_on_auth_errors() -> None:
    sleeps: list[float] = []
    post = http_poster("k", sleep=sleeps.append, opener=FakeOpener(*[http_error(429)] * 6))
    with pytest.raises(JevLimitReached):
        post({})
    assert sleeps == [2.0, 4.0, 8.0, 16.0, 32.0]
    with pytest.raises(JevLimitReached):
        http_poster("k", sleep=sleeps.append, opener=FakeOpener(http_error(402)))({})
    with pytest.raises(JevError):
        http_poster("k", sleep=sleeps.append, opener=FakeOpener(http_error(400)))({})


def test_pair_records_joins_claude_flags_by_file_line_rule(rules: RuleSet) -> None:
    ids = rule_ids(rules)
    poster = FakePoster(answer_all(ids, 0.9), JevLimitReached("429"))
    answers = jev_answers({"s.info": make_slot()}, [entry(4, "가"), entry(5, "나", key="k2")], rules, poster)
    claude = [Finding(CONTENT, 4, "slop.P1", "warn", "LLM 의심(k1): 내용 없음")]
    records = pair_records(answers, claude)
    by_key = {(record.line, record.rule_id): record for record in records}
    assert by_key[(4, "slop.P1")].claude_flag is True
    assert by_key[(4, "slop.P1")].claude_reason == "LLM 의심(k1): 내용 없음"
    assert by_key[(4, ids[1])].claude_flag is False
    assert by_key[(4, "slop.P1")].jev_flag is (0.9 >= FLAG_THRESHOLD)
    assert by_key[(5, "slop.P1")].jev_flag is None
    assert by_key[(5, "slop.P1")].status == "limit"


def test_write_shadow_creates_dirs_and_refuses_overwrite(rules: RuleSet, tmp_path: Path) -> None:
    ids = rule_ids(rules)
    answers = jev_answers({"s.info": make_slot()}, [entry(1, "가")], rules, FakePoster(answer_all(ids)))
    records = pair_records(answers, [])
    path = tmp_path / "a" / "b" / "x.jsonl"
    write_shadow(records, path)
    lines = path.read_text(encoding="utf-8").splitlines()
    assert len(lines) == len(records)
    assert json.loads(lines[0])["text"] == "가"
    with pytest.raises(FileExistsError):
        write_shadow(records, path)

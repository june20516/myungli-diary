import pytest

from mlw.loader import load_rules
from mlw.model import Detect, Example
from mlw.paths import RULES_DIR
from mlw.sentence import detectable_rules, matches, normalize_for_detection

_RULES = load_rules(RULES_DIR)

# (규칙 ID, 탐지 조건, 예문, 기대 결과). llm 규칙은 detect가 없어 대상이 아닙니다.
_CASES: list[tuple[str, Detect, Example, bool]] = []
for _rule in detectable_rules(_RULES):
    if _rule.detect is None:
        continue
    _CASES += [(_rule.id, _rule.detect, example, True) for example in _rule.examples.hit]
    _CASES += [(_rule.id, _rule.detect, example, False) for example in _rule.examples.pass_]

_IDS = [f"{case[0]}-{'hit' if case[3] else 'pass'}-{index}" for index, case in enumerate(_CASES)]


@pytest.mark.parametrize(("rule_id", "detect", "example", "expected"), _CASES, ids=_IDS)
def test_rule_example(rule_id: str, detect: Detect, example: Example, expected: bool) -> None:
    text = example.text if detect.raw else normalize_for_detection(example.text)
    assert matches(detect, example.lang, text) is expected

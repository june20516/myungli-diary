# Evidence.rule_id 목록과 규칙별 detail 키 선언 (#130)
import json
from pathlib import Path

import pytest

from myungli_engine.constants import evidence_rules
from myungli_engine.domain.models import Evidence
from myungli_engine.grpc_api import mapping

CORE_DIR = Path(__file__).resolve().parents[3]


def test_rule_detail_keys_declared_per_rule() -> None:
    assert evidence_rules.RULE_DETAIL_KEYS["yongsin/johu"] == ("month_branch", "share", "threshold")
    assert evidence_rules.RULE_DETAIL_KEYS["focus_time/fallback"] == ("picks",)
    assert evidence_rules.RULE_DETAIL_KEYS["personal/luck_ten_god"] == (
        "current",
        "element",
        "luck",
        "part",
        "role",
    )
    assert len(evidence_rules.RULE_DETAIL_KEYS) == 24


def test_require_rule_accepts_declared_detail_subset() -> None:
    assert evidence_rules.require_rule("yongsin/johu_neutral", {"strength_level": "NEUTRAL"}) == (
        "yongsin/johu_neutral"
    )
    assert (
        evidence_rules.require_rule("personal/luck_ten_god", {"current": "true"}) == "personal/luck_ten_god"
    )


def test_require_rule_rejects_unknown_rule() -> None:
    with pytest.raises(KeyError, match="등록되지 않은 rule_id"):
        evidence_rules.require_rule("yongsin/unknown", {})


def test_require_rule_rejects_undeclared_detail_key() -> None:
    with pytest.raises(KeyError, match="선언되지 않은 detail 키"):
        evidence_rules.require_rule("yongsin/eokbu", {"strength_level": "STRONG", "extra": "x"})


def test_evidence_to_proto_rejects_unregistered_rule() -> None:
    with pytest.raises(KeyError):
        mapping.evidence_to_proto(Evidence("yongsin/unknown", "gungtong-bogam/five_elements#color"))


def test_exported_rule_list_up_to_date() -> None:
    exported = json.loads((CORE_DIR / "evidence_rules.json").read_text(encoding="utf-8"))
    assert exported == {rule: list(keys) for rule, keys in sorted(evidence_rules.RULE_DETAIL_KEYS.items())}

import ast
import json
from pathlib import Path

import pytest

from myungri_engine.constants import message_keys
from myungri_engine.constants.directions import BAGUA_ELEMENT, BRANCH_DIRECTION, ELEMENT_DIRECTION
from myungri_engine.constants.gwiin import CHEONEUL_GWIIN
from myungri_engine.constants.johu import JOHU_YONGSIN
from myungri_engine.constants.longitudes import representative_longitude
from myungri_engine.constants.numbers import HADO
from myungri_engine.constants.relations import (
    BRANCH_CHUNG,
    BRANCH_HAP,
    BRANCH_HYEONG_GROUPS,
    SELF_HYEONG,
    STEM_HAP,
)
from myungri_engine.constants.shinsal import DOHWA, HWAGAE, YANGIN, YEOKMA
from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import Direction8
from myungri_engine.domain.enums import Element as E
from myungri_engine.domain.enums import Stem as S

CORE_DIR = Path(__file__).resolve().parents[3]
CORRECTIONS = CORE_DIR / "src/myungri_engine/references/data/gungtong_bogam/corrections.json"


def test_johu_has_120_cells_and_matches_corrections():
    assert sum(len(m) for m in JOHU_YONGSIN.values()) == 120
    for c in json.loads(CORRECTIONS.read_text(encoding="utf-8"))["corrections"]:
        cell = JOHU_YONGSIN[S.from_hanja(c["stem"])][B.from_hanja(c["branch"])]
        assert [s.hanja for s in cell] == c["after"]


def test_johu_hanja_table_is_pure_literal():
    source = (CORE_DIR / "src/myungri_engine/constants/johu.py").read_text(encoding="utf-8")
    for node in ast.parse(source).body:
        if isinstance(node, ast.AnnAssign) and getattr(node.target, "id", "") == "JOHU_TABLE_HANJA":
            assert node.value is not None
            table = ast.literal_eval(node.value)
            assert len(table) == 10 and all(len(row) == 12 for row in table.values())
            return
    pytest.fail("JOHU_TABLE_HANJA를 찾지 못했습니다")


def test_spot_values():
    assert JOHU_YONGSIN[S.GAP][B.IN] == (S.BYEONG, S.GYE)
    assert CHEONEUL_GWIIN[S.SIN] == frozenset({B.IN, B.O})
    assert STEM_HAP[frozenset({S.GI, S.GAP})] == E.EARTH  # 순서 무관
    assert BRANCH_HAP[frozenset({B.MI, B.O})] == E.FIRE
    assert frozenset({B.HAE, B.SA}) in BRANCH_CHUNG
    assert DOHWA[B.SHIN] == B.YU and YEOKMA[B.IN] == B.SHIN and HWAGAE[B.HAE] == B.MI
    assert YANGIN == {S.GAP: B.MYO, S.BYEONG: B.O, S.MU: B.O, S.GYEONG: B.YU, S.IM: B.JA}
    assert HADO[E.METAL] == (4, 9)


def test_structure_counts():
    assert len(CHEONEUL_GWIIN) == 10 and all(len(v) == 2 for v in CHEONEUL_GWIIN.values())
    assert len(STEM_HAP) == 5 and len(BRANCH_HAP) == 6 and len(BRANCH_CHUNG) == 6
    assert len(BRANCH_HYEONG_GROUPS) == 2 and len(SELF_HYEONG) == 4
    for table in (DOHWA, YEOKMA, HWAGAE):
        assert set(table) == set(B)


def test_directions():
    assert ELEMENT_DIRECTION == {
        E.WATER: Direction8.N,
        E.FIRE: Direction8.S,
        E.WOOD: Direction8.E,
        E.METAL: Direction8.W,
    }
    assert set(BAGUA_ELEMENT) == set(Direction8)
    assert set(BRANCH_DIRECTION) == set(B)
    assert BRANCH_DIRECTION[B.SUL] == Direction8.NW


def test_representative_longitude():
    assert representative_longitude("Asia/Seoul", 9) == 127.5
    assert representative_longitude("Asia/Tokyo", 9) == 135.0
    assert representative_longitude("America/New_York", -5) == -75.0


def test_message_keys_registry():
    params = {"day_kind": "GWIIN_DAY", "ten_god": "SIKSIN", "element": "WOOD", "emphasis": "NONE"}
    assert message_keys.require("fortune.gwiin_day.siksang", params) == "fortune.gwiin_day.siksang"
    assert "fortune.tag.big_change" in message_keys.ALL_KEYS
    assert "guide.ten_god_rush.jaeseong" in message_keys.ALL_KEYS
    assert "tag.ten_god_rush.inseong" in message_keys.ALL_KEYS
    assert (
        sum(k.startswith("fortune.") and not k.startswith("fortune.tag.") for k in message_keys.ALL_KEYS)
        == 20
    )


def test_unknown_message_key_rejected():
    with pytest.raises(KeyError):
        message_keys.require("no.such.key")


def test_exported_key_list_up_to_date():
    exported = json.loads((CORE_DIR / "message_keys.json").read_text(encoding="utf-8"))
    assert exported == sorted(message_keys.ALL_KEYS)


def test_message_params_declared_per_key():
    assert message_keys.KEY_PARAMS["focus_time.hap"] == ("branches", "score")
    assert message_keys.KEY_PARAMS["calendar.good"] == ("score",)
    assert message_keys.KEY_PARAMS["tag.clash"] == ()
    assert frozenset(message_keys.KEY_PARAMS) == message_keys.ALL_KEYS


def test_require_accepts_declared_params():
    assert message_keys.require("calendar.good", {"score": 3}) == "calendar.good"
    assert message_keys.require("tag.clash") == "tag.clash"


@pytest.mark.parametrize(
    "params",
    [{}, {"score": 3, "extra": 1}, {"level": 3}],
)
def test_require_rejects_mismatched_params(params):
    with pytest.raises(KeyError):
        message_keys.require("calendar.good", params)


def test_exported_param_list_up_to_date():
    exported = json.loads((CORE_DIR / "message_params.json").read_text(encoding="utf-8"))
    assert exported == {key: list(message_keys.KEY_PARAMS[key]) for key in sorted(message_keys.KEY_PARAMS)}


def test_exported_param_keys_match_key_list():
    keys = json.loads((CORE_DIR / "message_keys.json").read_text(encoding="utf-8"))
    params = json.loads((CORE_DIR / "message_params.json").read_text(encoding="utf-8"))
    assert sorted(params) == keys

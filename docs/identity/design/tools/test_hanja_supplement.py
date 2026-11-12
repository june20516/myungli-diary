"""한자 대체 글꼴(#1029, 결정 V121): Pretendard JP에 없는 원고 한자를 부분 글꼴이 모두 담는지."""
import json

from fontTools.ttLib import TTFont

import hanja_supplement as hs


def test_supplement_covers_every_missing_hanja(font_dir):
    # writing이 Pretendard JP에 없는 한자를 새로 쓰면 여기서 걸림: hanja_supplement.py로 다시 만듦
    assert hs.check(font_dir) == []


def test_manifest_names_family_files_and_license():
    manifest = json.loads(hs.MANIFEST.read_text(encoding="utf-8"))
    assert manifest["family"] == "Myungli Hanja Supplement" and "罡" in manifest["chars"]  # 괴강 魁罡
    assert {info["weight"] for info in manifest["files"].values()} == {400, 500, 600, 700}
    assert (hs.OUT_DIR / "OFL.txt").read_text(encoding="utf-8").startswith("Copyright 2014-2021 Adobe")
    for name in manifest["files"]:
        font = TTFont(hs.OUT_DIR / name)
        assert font["name"].getDebugName(16) == "Myungli Hanja Supplement"
        assert "Source" not in font["name"].getDebugName(1)  # OFL 예약 이름을 쓰지 않음
        assert set(font.getBestCmap()) == {ord(char) for char in manifest["chars"]}


def test_glyph_table_is_part_of_wanted_chars():
    assert {"德", "孤", "寡", "元", "刑"} <= hs.glyph_table_chars()

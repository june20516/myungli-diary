"""스토어 스크린샷과 Play 그래픽 이미지 명세 검사 (#1202, D133, 결정 V133).

spec: docs/identity/design/specs/2026-11-16-store-screenshots-design.md
"""
import copy
import pathlib
import shutil
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import store  # noqa: E402

SPEC_SCENES = [  # spec §4 (A안)
    ("today", "default", "member"),
    ("evidence-sheet", "unlocked", "evidence-unlocked"),
    ("calendar", "default", "member"),
    ("day-sheet", "default", "member"),
    ("my-saju", "default", "member"),
    ("share-preview", "default", "member"),
]


def edited(change) -> dict:
    doc = copy.deepcopy(store.load())
    change(doc)
    return doc


def test_store_json_is_valid():
    assert store.validate(store.load()) == []


def test_scenes_follow_spec_order():
    scenes = store.load()["scenes"]
    assert [(s["screen"], s["state"], s["scenario"]) for s in scenes] == SPEC_SCENES
    assert [s["order"] for s in scenes] == [1, 2, 3, 4, 5, 6]
    assert [s["id"] for s in scenes] == ["today", "evidence", "calendar", "daySheet", "mySaju", "share"]


def test_app_shots_parsed():
    shots = store.app_shots()
    assert ("evidence-sheet", "unlocked", "evidence-unlocked") in shots  # 여러 줄에 걸친 _Shot(
    assert ("today", "default", "member") in shots


def test_unknown_state_is_named():
    doc = edited(lambda d: d["scenes"][1].update(state="unlocked-still"))
    errors = store.validate(doc)
    assert any("evidence-sheet" in e and "unlocked-still" in e for e in errors), errors


def test_unknown_screen_fails():
    doc = edited(lambda d: d["scenes"][0].update(screen="today-v2"))
    assert any("today-v2" in e for e in store.validate(doc))


def test_missing_scenario_fails(tmp_path):
    for relative in ("docs/ia/screens.json", "app/test/screenshots/screens_test.dart"):
        target = tmp_path / relative
        target.parent.mkdir(parents=True)
        shutil.copy(store.REPO_ROOT / relative, target)
    (tmp_path / "app" / "fixtures").mkdir()
    errors = store.validate(store.load(), repo_root=tmp_path)
    assert any("member" in e and "fixtures" in e for e in errors), errors


def test_play_aspect_limit():
    doc = edited(lambda d: d["frames"]["play"].update(size=[1080, 2340]))
    assert any("play" in e for e in store.validate(doc))


def test_app_store_size_is_fixed():
    doc = edited(lambda d: d["frames"]["appStore"].update(size=[1290, 2796]))
    assert any("appStore" in e for e in store.validate(doc))


def test_caption_must_end_above_screen():
    doc = edited(lambda d: d["frames"]["appStore"]["caption"].update(size=200))
    assert any("appStore" in e and "화면 판" in e for e in store.validate(doc))


def test_screen_panel_fits_width():
    doc = edited(lambda d: d["frames"]["play"]["screen"].update(width=1200))
    assert any("play" in e for e in store.validate(doc))


def test_feature_graphic_size():
    doc = edited(lambda d: d["featureGraphic"].update(size=[1024, 512]))
    assert any("featureGraphic" in e for e in store.validate(doc))


def test_feature_graphic_logo_exists():
    doc = edited(lambda d: d["featureGraphic"].update(logo="logo/missing.png"))
    assert any("logo/missing.png" in e for e in store.validate(doc))


def test_scene_count_bounds():
    doc = edited(lambda d: d.update(scenes=d["scenes"][:1]))
    assert any("장면" in e for e in store.validate(doc))


def test_scene_order_has_no_gaps():
    doc = edited(lambda d: d["scenes"][2].update(order=7))
    assert any("순서" in e for e in store.validate(doc))


def test_main_reports_ok(capsys):
    assert store.main([]) == 0
    assert "OK: 장면 6개" in capsys.readouterr().out


# Task 2: 글자 수 상한 (spec §7). 글꼴이 없으면 skip, CI(DESIGN_FONTS_REQUIRED=1)는 실패
README = store.DESIGN_DIR / "store" / "README.md"


def test_caption_limits_measured(font_dir):
    import lengths

    limits = store.caption_limits(lengths.Fonts(font_dir), store.load())
    assert limits == {"ko": 14, "ja": 11, "en": 24}


def test_readme_table_matches_tool(font_dir):
    import lengths

    doc = store.load()
    table = store.render_limits_table(store.caption_limits(lengths.Fonts(font_dir), doc), doc["caption"]["maxLines"])
    assert table in README.read_text(encoding="utf-8")


def test_render_limits_table_shape():
    table = store.render_limits_table({"ko": 14, "ja": 11, "en": 24}, 2)
    assert table.splitlines() == [
        "| 언어 | 한 줄 | 두 줄 |",
        "| --- | --- | --- |",
        "| ko | 14 | 28 |",
        "| ja | 11 | 22 |",
        "| en | 24 | 48 |",
    ]


def test_readme_has_no_banned_dashes():
    text = README.read_text(encoding="utf-8")
    assert not {"—", "–", "·"} & set(text)


# Task 3: 관문 질문 시안 기록과 결정 (spec §2, §10)
def test_question_pages_recorded():
    import json

    artifacts = store.DESIGN_DIR / "artifacts"
    entries = {e["id"]: e for e in json.loads((artifacts / "index.json").read_text(encoding="utf-8"))}
    for entry_id in ("design-store-scenes-questions", "design-store-frame-questions",
                     "design-store-feature-graphic-questions"):
        entry = entries[entry_id]
        assert (entry["kind"], entry["status"]) == ("concept", "chosen"), entry_id
        assert "V133" in entry["decisions"], entry_id
        assert (artifacts / entry["file"]).is_file(), entry_id


def test_decision_v133_recorded():
    decisions = (store.DESIGN_DIR / "decisions.md").read_text(encoding="utf-8")
    row = next(line for line in decisions.splitlines() if line.startswith("| V133 |"))
    assert "#1202" in row and "store/" in row and "사용자 영향: #1201" in row

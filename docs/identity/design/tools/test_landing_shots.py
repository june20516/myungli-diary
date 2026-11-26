"""WB1 랜딩 화면 사진 검사 (#1330, 결정 V137)."""
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import landing_shots  # noqa: E402
import store  # noqa: E402

APP_STORE = store.load()["frames"]["appStore"]


def test_crop_box_is_screen_plate_down_to_bottom_edge():
    # store.json App Store 틀: 1320×2868, 화면 판 위 560, 폭 1080(가운데)
    assert landing_shots.crop_box(APP_STORE) == (120, 560, 1200, 2868)


def test_output_keeps_plate_ratio_at_width_600():
    assert landing_shots.output_size(APP_STORE) == (600, 1282)


def test_source_name_follows_store_scene_order():
    scenes = store.load()["scenes"]
    assert [landing_shots.source_name(scene, scenes) for scene in landing_shots.SCENES] == [
        "1-today.png", "2-evidence.png", "3-calendar.png",
    ]


def test_committed_shots_cover_every_locale_and_scene_at_output_size():
    expected = {landing_shots.output_name(locale, scene)
                for locale in landing_shots.LOCALES for scene in landing_shots.SCENES}
    present = {path.name for path in landing_shots.OUT_DIR.glob("*.webp")}
    assert present == expected
    for name in expected:
        assert landing_shots.webp_size(landing_shots.OUT_DIR / name) == landing_shots.output_size(APP_STORE)

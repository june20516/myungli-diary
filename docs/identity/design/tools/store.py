"""스토어 스크린샷과 Play 그래픽 이미지 명세(store/store.json)를 검사합니다 (#1202, D133, 결정 V133).

spec: docs/identity/design/specs/2026-11-16-store-screenshots-design.md §9

사용법 (저장소 루트에서):
    python3 docs/identity/design/tools/store.py
    uv run --with fonttools==4.54.1 python docs/identity/design/tools/store.py --font-dir .suberpowers/fonts
    # 글꼴을 주면 글 자리 한 줄 상한(spec §7)을 재어 store/README.md 표와 대조합니다.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

DESIGN_DIR = pathlib.Path(__file__).resolve().parent.parent
REPO_ROOT = DESIGN_DIR.parents[2]
STORE_JSON = DESIGN_DIR / "store" / "store.json"
STORE_README = DESIGN_DIR / "store" / "README.md"
IA_PATH = pathlib.Path("docs/ia/screens.json")
APP_SHOTS_PATH = pathlib.Path("app/test/screenshots/screens_test.dart")
FIXTURES_DIR = pathlib.Path("app/fixtures")

APP_STORE_SIZE = (1320, 2868)  # iPhone 6.9인치 세로 (D133)
PLAY_MIN_SHORT_SIDE = 1080  # 9:16 1080×1920 이상 권장
FEATURE_GRAPHIC_SIZE = (1024, 500)
MIN_SCENES, MAX_SCENES = 2, 8  # Play 2~8장(App Store 10장 이하)

# app 화면 렌더 사례: _Shot('화면', '상태', '시나리오', ...) — 인자가 여러 줄에 걸쳐도 읽음
SHOT_PATTERN = re.compile(r"_Shot\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)'")


def load(path: pathlib.Path = STORE_JSON) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def app_shots(repo_root: pathlib.Path = REPO_ROOT) -> set[tuple[str, str, str]]:
    """app 화면 렌더 사례의 (화면, 상태, 시나리오) 조합."""
    return set(SHOT_PATTERN.findall((repo_root / APP_SHOTS_PATH).read_text(encoding="utf-8")))


def ia_screen_ids(repo_root: pathlib.Path) -> set[str]:
    ia = json.loads((repo_root / IA_PATH).read_text(encoding="utf-8"))
    return {screen["id"] for screen in ia["screens"]}


def scene_errors(scenes: list[dict], repo_root: pathlib.Path) -> list[str]:
    errors: list[str] = []
    if not MIN_SCENES <= len(scenes) <= MAX_SCENES:
        errors.append(f"장면 수 {len(scenes)}: {MIN_SCENES}~{MAX_SCENES}장이어야 합니다(Play 2~8)")
    orders = [scene["order"] for scene in scenes]
    if orders != list(range(1, len(scenes) + 1)):
        errors.append(f"장면 순서 {orders}: 1부터 빈틈없이 이어져야 합니다")
    screens = ia_screen_ids(repo_root)
    shots = app_shots(repo_root)
    for scene in scenes:
        screen, state, scenario = scene["screen"], scene["state"], scene["scenario"]
        if screen not in screens:
            errors.append(f"장면 {scene['order']}: IA에 없는 화면 {screen}")
        if (screen, state, scenario) not in shots:
            errors.append(f"장면 {scene['order']}: app 렌더 사례에 없는 조합 {screen} {state} {scenario} ({APP_SHOTS_PATH})")
        if not (repo_root / FIXTURES_DIR / scenario).is_dir():
            errors.append(f"장면 {scene['order']}: fixture 시나리오 {scenario}가 {FIXTURES_DIR}에 없습니다")
    return errors


def frame_errors(name: str, frame: dict, caption: dict) -> list[str]:
    errors: list[str] = []
    width, height = frame["size"]
    if name == "appStore" and (width, height) != APP_STORE_SIZE:
        errors.append(f"appStore 크기 {width}×{height}: {APP_STORE_SIZE[0]}×{APP_STORE_SIZE[1]}이어야 합니다")
    if name == "play" and (max(width, height) > 2 * min(width, height) or min(width, height) < PLAY_MIN_SHORT_SIDE):
        errors.append(f"play 크기 {width}×{height}: 긴 변이 짧은 변의 2배 이하, 짧은 변 {PLAY_MIN_SHORT_SIDE} 이상이어야 합니다")
    text, screen = frame["caption"], frame["screen"]
    if 2 * text["side"] >= width:
        errors.append(f"{name} 글 자리 좌우 {text['side']}: 그림 폭 {width} 안에 들어가지 않습니다")
    if screen["width"] > width:
        errors.append(f"{name} 화면 판 폭 {screen['width']}: 그림 폭 {width}보다 넓습니다")
    caption_bottom = text["top"] + caption["maxLines"] * text["size"] * caption["lineHeight"]
    if caption_bottom > screen["top"]:
        errors.append(f"{name} 글 {caption['maxLines']}줄 끝 {caption_bottom:g}: 화면 판 위 {screen['top']}보다 아래입니다")
    return errors


def feature_graphic_errors(graphic: dict) -> list[str]:
    errors: list[str] = []
    if tuple(graphic["size"]) != FEATURE_GRAPHIC_SIZE:
        errors.append(f"featureGraphic 크기 {graphic['size']}: {FEATURE_GRAPHIC_SIZE[0]}×{FEATURE_GRAPHIC_SIZE[1]}이어야 합니다")
    if graphic["logoWidth"] >= graphic["size"][0]:
        errors.append(f"featureGraphic 로고 폭 {graphic['logoWidth']}: 그림 폭보다 좁아야 합니다")
    if not (DESIGN_DIR / graphic["logo"]).is_file():
        errors.append(f"featureGraphic 로고 {graphic['logo']}: design 디렉터리에 없습니다")
    return errors


def validate(doc: dict, repo_root: pathlib.Path = REPO_ROOT) -> list[str]:
    """명세 오류 목록. 비어 있으면 통과입니다."""
    errors = scene_errors(doc["scenes"], repo_root)
    for name, frame in doc["frames"].items():
        errors += frame_errors(name, frame, doc["caption"])
    errors += feature_graphic_errors(doc["featureGraphic"])
    return errors


CAPTION_FONT = "ui-600"  # Pretendard SemiBold. ja는 lengths 규칙대로 전각 1em
LANGUAGE_ORDER = ("ko", "ja", "en")


def caption_limits(fonts, doc: dict) -> dict[str, int]:
    """글 자리 한 줄 상한. 두 틀(App Store, Play) 가운데 작은 값입니다. 재는 법은 lengths.py와 같습니다."""
    import lengths

    tracking_em = doc["caption"]["tracking"]
    limits: dict[str, int] = {}
    for frame in doc["frames"].values():
        text = frame["caption"]
        size, width = text["size"], frame["size"][0] - 2 * text["side"]
        tracking = tracking_em * size
        measured = {
            "ko": lengths.ko_name_chars(fonts.ko(CAPTION_FONT), size, tracking, width),
            "ja": lengths.ja_line_chars(fonts.ja(CAPTION_FONT), size, width),
            "en": lengths.en_line_chars(fonts.ko(CAPTION_FONT), size, tracking, width),
        }
        for language, value in measured.items():
            limits[language] = min(limits.get(language, value), value)
    return {language: limits[language] for language in LANGUAGE_ORDER}


def render_limits_table(limits: dict[str, int], max_lines: int) -> str:
    rows = ["| 언어 | 한 줄 | 두 줄 |", "| --- | --- | --- |"]
    rows += [f"| {language} | {limits[language]} | {limits[language] * max_lines} |" for language in LANGUAGE_ORDER]
    return "\n".join(rows)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font-dir", type=pathlib.Path, help="측정 글꼴 디렉터리(주면 상한 표를 README와 대조)")
    args = parser.parse_args(argv)
    doc = load()
    errors = validate(doc)
    if args.font_dir:
        import lengths

        table = render_limits_table(caption_limits(lengths.Fonts(args.font_dir), doc), doc["caption"]["maxLines"])
        if table not in STORE_README.read_text(encoding="utf-8"):
            errors.append(f"{STORE_README.name} 상한 표가 실측과 다릅니다. 아래 표로 바꾸세요:\n{table}")
    for error in errors:
        print(error)
    if errors:
        return 1
    print(f"OK: 장면 {len(doc['scenes'])}개")
    return 0


if __name__ == "__main__":
    sys.exit(main())

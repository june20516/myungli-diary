"""WB1 랜딩 화면 사진을 스토어 스크린샷에서 잘라 만듭니다 (#1330, 결정 V137).

app이 만든 App Store 스크린샷(`store/store.json` frames.appStore 틀)에서 화면 판만 잘라
폭 600 webp로 줄입니다. 위 두 모서리는 판 모서리 그대로 투명하게 두고, 아래는 그림 끝에서 잘린 채입니다.

실행(저장소 루트, Pillow 필요):
  uv run --with pillow==11.0.0 python docs/identity/design/tools/landing_shots.py <스토어 이미지 폴더>
<스토어 이미지 폴더>는 app 생성 명령의 출력(`<언어>/appStore/<순서>-<장면>.png`)입니다.
"""
from __future__ import annotations

import argparse
import pathlib
import struct
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import store  # noqa: E402

OUT_DIR = TOOLS_DIR.parent / "web" / "landing" / "shots"
SCENES = ("today", "evidence", "calendar")  # A안 화면 세 장(V137)
LOCALES = ("ko", "en", "ja")
WIDTH = 600
QUALITY = 84


def crop_box(frame: dict) -> tuple[int, int, int, int]:
    """틀에서 화면 판이 차지하는 영역(왼쪽, 위, 오른쪽, 아래)입니다. 판은 그림 아래 끝까지 넘칩니다."""
    canvas_width, canvas_height = frame["size"]
    screen = frame["screen"]
    left = (canvas_width - screen["width"]) // 2
    return left, screen["top"], left + screen["width"], canvas_height


def output_size(frame: dict) -> tuple[int, int]:
    left, top, right, bottom = crop_box(frame)
    return WIDTH, round((bottom - top) * WIDTH / (right - left))


def source_name(scene_id: str, scenes: list[dict]) -> str:
    order = next(scene["order"] for scene in scenes if scene["id"] == scene_id)
    return f"{order}-{scene_id}.png"


def output_name(locale: str, scene_id: str) -> str:
    return f"{locale}-{scene_id}.webp"


def webp_size(path: pathlib.Path) -> tuple[int, int]:
    """webp 캔버스 크기를 머리에서 읽습니다(VP8X, VP8L, VP8)."""
    data = path.read_bytes()[:30]
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError(f"webp가 아님: {path}")
    chunk = data[12:16]
    if chunk == b"VP8X":
        width = int.from_bytes(data[24:27], "little") + 1
        height = int.from_bytes(data[27:30], "little") + 1
        return width, height
    if chunk == b"VP8L":
        bits = struct.unpack("<I", data[21:25])[0]
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if chunk == b"VP8 ":
        width, height = struct.unpack("<HH", data[26:30])
        return width & 0x3FFF, height & 0x3FFF
    raise ValueError(f"모르는 webp 형식: {chunk!r}")


def make(source_dir: pathlib.Path, out_dir: pathlib.Path = OUT_DIR) -> list[pathlib.Path]:
    from PIL import Image, ImageDraw

    doc = store.load()
    frame = doc["frames"]["appStore"]
    box = crop_box(frame)
    radius = frame["screen"]["radius"]
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for locale in LOCALES:
        for scene_id in SCENES:
            source = source_dir / locale / "appStore" / source_name(scene_id, doc["scenes"])
            image = Image.open(source).convert("RGB")
            if image.size != tuple(frame["size"]):
                raise ValueError(f"{source}: 크기 {image.size}, 틀은 {tuple(frame['size'])}")
            plate = image.crop(box)
            mask = Image.new("L", plate.size, 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, plate.width, plate.height + radius), radius, fill=255)
            plate.putalpha(mask)
            plate = plate.resize(output_size(frame), Image.LANCZOS)
            target = out_dir / output_name(locale, scene_id)
            plate.save(target, quality=QUALITY, method=6)
            written.append(target)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source_dir", type=pathlib.Path, help="app이 만든 스토어 이미지 폴더")
    args = parser.parse_args()
    for path in make(args.source_dir):
        print(path.relative_to(TOOLS_DIR.parents[3]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

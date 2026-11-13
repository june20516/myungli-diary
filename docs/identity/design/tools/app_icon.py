"""앱 아이콘 래스터 원본(logo/icon-*.png)을 떼어 낸 책 그림(logo/source/)에서 만듭니다 (결정 V99, #908).

원본 그림은 사용자가 이미지 생성 도구로 만든 것을 배경과 워터마크 없이 책과 그림자만 알파로 떼어 낸 것입니다.
* book-detailed.png: 표지 결, 책등, 책갈피 리본, 그림자가 있는 질감판 → 큰 원형(60px 이상), Android 전경
* book-flat.png: 같은 구성의 평면판 → 작은 원형(48px 이하)

배치는 V7 SVG 비율을 따릅니다: 책 몸통(리본 뺀) 높이가 큰 원형 72%, 작은 원형 76%, 가운데.
Android 전경은 100 단위 큰 원형 배치를 0.66배로 줄여 108 캔버스 가운데에 둡니다(옛 SVG의 translate(21 21) scale(0.66)과
같고, 책 몸통 높이는 108 캔버스의 0.72 x 0.66 x 100/108 = 44%). 안전 영역은 가운데 66dp 원입니다.
배경은 대각선 그라데이션 + 옅은 종이 결.
작은 원형은 낙관을 SMALL_SEAL_SCALE배로 키워 20~48px에서 日이 읽히게 합니다(V7 작은 원형과 같은 생각).

가로 조합(logo/lockup.png, lockup-dark.png)은 큰 원형 마스터와 워드마크 SVG를 spec §6.2 비율(옛 lockup.svg와 같음)로
붙인 PNG입니다(공유 이미지 로고, V99 관문 Q2 ②). 워드마크는 resvg로 그립니다.

같은 원본과 같은 도구 버전(아래 pillow, numpy, scipy 고정, resvg는 app-icon.json에 기록)이면 같은 파일입니다
(종이 결 난수 고정, PNG 시각 정보 없음). 만든 뒤 logo/app-icon.json에 파일 sha256과 안전 영역 측정값을 적고,
test_logo.py가 그 기록과 파일을 대조하고 Android 전경 안전 영역은 PNG 픽셀로 다시 잽니다.

필요: resvg(`brew install resvg`). 사용법 (저장소 루트에서):
    uv run --with pillow==11.0.0 --with numpy==2.1.3 --with scipy==1.14.1 \\
        python docs/identity/design/tools/app_icon.py
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

DESIGN_DIR = pathlib.Path(__file__).resolve().parent.parent
LOGO_DIR = DESIGN_DIR / "logo"
SOURCE_DIR = LOGO_DIR / "source"
MANIFEST = LOGO_DIR / "app-icon.json"

MASTER_PX = 1024
WORK_PX = 2048  # 합성은 크게 하고 마스터 크기로 줄임
GRADIENT_FROM = (0xE8, 0xF2, 0xE9)  # V7 SVG 배경과 같은 대각선 그라데이션
GRADIENT_TO = (0xFF, 0xE9, 0xE5)
GRAIN_SIGMA = 1.2
GRAIN_SEED = 7

LARGE_BODY_RATIO = 0.72
SMALL_BODY_RATIO = 0.76
ANDROID_CANVAS_DP = 108
ANDROID_SCALE = 0.66  # 100 단위 큰 원형 배치를 줄이는 배율(108 캔버스에서 66 단위 정사각)
ANDROID_SAFE_DIAMETER_DP = 66
SMALL_SEAL_SCALE = 1.45
SEAL_OVERHANG_PX = 12  # 키운 낙관 bbox 오른쪽 아래가 원래 낙관 bbox보다 바깥으로 나가는 거리 (원본 2048 기준)
SEAL_WIDTH_RATIO = (0.25, 0.50)  # 낙관 덩어리 bbox 폭 / 책 몸통 폭이 이 범위여야 낙관으로 봄(원본은 0.38)
BODY_ALPHA = 200  # 책 몸통으로 보는 알파 (255 기준)

# 가로 조합: spec §6.2 비율(아이콘 150, 간격 37.5, 워드마크 높이 100, 모서리 22%). 옛 도형판 lockup.svg와 같은 비율
LOCKUP_ICON_PX = 288  # 1080 공유 캔버스에 넉넉한 높이
LOCKUP_ICON_UNITS = 150.0
LOCKUP_GAP_UNITS = 37.5
LOCKUP_WORDMARK_UNITS = 100.0
LOCKUP_CORNER_RATIO = 0.22  # 플랫폼이 깎는 모서리와 비슷하게 보여줍니다
LOCKUPS = {"lockup.png": "wordmark.svg", "lockup-dark.png": "wordmark-dark.svg"}


def gradient(size: int) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1)
    t = ((xx + yy) / 2)[..., None]
    rgb = np.array(GRADIENT_FROM, float) * (1 - t) + np.array(GRADIENT_TO, float) * t
    grain = np.random.default_rng(GRAIN_SEED).normal(0, GRAIN_SIGMA, (size, size, 1))
    return Image.fromarray(np.clip(rgb + grain, 0, 255).astype(np.uint8), "RGB")


def body_box(cut: Image.Image) -> tuple[int, int, int, int]:
    """리본을 뺀 책 몸통: 행 폭이 최대 폭의 절반 이상인 범위."""
    alpha = np.asarray(cut)[..., 3] > BODY_ALPHA
    rows = alpha.sum(axis=1)
    ys = np.nonzero(rows > rows.max() * 0.5)[0]
    cols = np.nonzero(alpha[ys[0]:ys[-1] + 1].any(axis=0))[0]
    return int(cols[0]), int(ys[0]), int(cols[-1]) + 1, int(ys[-1]) + 1


def _find_seal(cut: Image.Image) -> np.ndarray:
    """낙관 마스크: coral(R이 G보다 40 넘게 큼)인 가장 큰 덩어리와 그 안 日.
    평면판에는 리본이 없지만, 다른 덩어리를 잘못 잡지 않게 위치와 크기를 확인합니다:
    덩어리 가운데가 책 몸통 오른쪽 아래 사분면에 있고, bbox 폭이 책 몸통 폭의 25~50%."""
    pixels = np.asarray(cut).astype(int)
    red = (pixels[..., 0] - pixels[..., 1] > 40) & (pixels[..., 3] > BODY_ALPHA)
    labels, count = ndimage.label(red)
    sizes = ndimage.sum(red, labels, range(1, count + 1))
    seal = ndimage.binary_fill_holes(labels == (np.argmax(sizes) + 1))
    ys, xs = np.nonzero(seal)
    bx0, by0, bx1, by1 = body_box(cut)
    center_x, center_y = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    if not (center_x > (bx0 + bx1) / 2 and center_y > (by0 + by1) / 2):
        raise ValueError(f"낙관 덩어리가 앞표지 오른쪽 아래에 없음: 가운데 ({center_x}, {center_y})")
    width_ratio = (xs.max() - xs.min()) / (bx1 - bx0)
    if not SEAL_WIDTH_RATIO[0] <= width_ratio <= SEAL_WIDTH_RATIO[1]:
        raise ValueError(f"낙관 덩어리 폭이 책 몸통 폭의 {width_ratio:.2f}배")
    return seal


def enlarge_seal(cut: Image.Image, scale: float) -> Image.Image:
    """낙관(coral 덩어리와 그 안 日)을 키워 다시 찍습니다. 원래 낙관은 표지 색으로 지웁니다."""
    seal = ndimage.binary_dilation(_find_seal(cut), iterations=2)
    ys, xs = np.nonzero(seal)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    patch = np.asarray(cut)[y0:y1, x0:x1].copy()
    soft = ndimage.gaussian_filter(seal[y0:y1, x0:x1].astype(float), 1.0)
    patch[..., 3] = (patch[..., 3] * soft).astype(np.uint8)
    width, height = round((x1 - x0) * scale), round((y1 - y0) * scale)
    big = Image.fromarray(patch, "RGBA").resize((width, height), Image.LANCZOS)
    # 원래 낙관은 표지 색으로 지웁니다. 기울어진 낙관이라 키운 낙관 밖으로 원래 가장자리가 비어져 나오기 때문
    erase = ndimage.binary_dilation(seal, iterations=6)
    _, (near_y, near_x) = ndimage.distance_transform_edt(erase, return_indices=True)
    cleared = np.asarray(cut).copy()
    filled = ndimage.uniform_filter(cleared[near_y, near_x].astype(float), size=(9, 9, 1))
    cleared[erase] = filled[erase].astype(np.uint8)
    out = Image.fromarray(cleared, "RGBA")
    # 키운 낙관 bbox의 오른쪽 아래를 원래 낙관 bbox 오른쪽 아래보다 SEAL_OVERHANG_PX 바깥에 맞춰 왼쪽 위로 키웁니다.
    # 원본 평면판에서 이 자리는 앞표지 안이고, 결과는 관문 페이지(design-app-icon-questions)에서 눈으로 확인했습니다.
    right, bottom = x1 + SEAL_OVERHANG_PX, y1 + SEAL_OVERHANG_PX
    out.alpha_composite(big, (right - width, bottom - height))
    return out


def place(cut: Image.Image, canvas: int, body_ratio: float) -> Image.Image:
    """책 몸통 높이를 캔버스의 body_ratio로 맞춰 가운데 놓은 투명 레이어."""
    x0, y0, x1, y1 = body_box(cut)
    k = canvas * body_ratio / (y1 - y0)
    resized = cut.resize((round(cut.width * k), round(cut.height * k)), Image.LANCZOS)
    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    layer.alpha_composite(resized, (round(canvas / 2 - (x0 + x1) / 2 * k), round(canvas / 2 - (y0 + y1) / 2 * k)))
    return layer


def flatten(layer: Image.Image) -> Image.Image:
    base = gradient(layer.width).convert("RGBA")
    base.alpha_composite(layer)
    return base.convert("RGB")


def safe_zone(foreground: Image.Image) -> dict[str, float]:
    """Android 전경에서 캔버스 가운데로부터 가장 먼 불투명 픽셀 거리(dp). 책 몸통과 그림자를 따로 잽니다."""
    alpha = np.asarray(foreground)[..., 3]
    size = foreground.width
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    distance_dp = np.hypot(xx - size / 2, yy - size / 2) * ANDROID_CANVAS_DP / size
    return {
        "bodyMaxRadiusDp": round(float(distance_dp[alpha > BODY_ALPHA].max()), 2),
        "anyMaxRadiusDp": round(float(distance_dp[alpha > 4].max()), 2),
    }


def rounded(image: Image.Image, ratio: float) -> Image.Image:
    """모서리를 ratio만큼 둥글게 깎은 RGBA (4배로 그려 줄여 가장자리를 매끄럽게)."""
    size = image.width
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=size * 4 * ratio, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def resvg_version() -> str:
    return subprocess.run(["resvg", "--version"], check=True, capture_output=True, text=True).stdout.strip()


def render_svg(path: pathlib.Path, height: int) -> Image.Image:
    with tempfile.TemporaryDirectory() as folder:
        target = pathlib.Path(folder) / "out.png"
        subprocess.run(["resvg", "-h", str(height), str(path), str(target)], check=True, capture_output=True)
        return Image.open(target).convert("RGBA").copy()


def lockup(icon: Image.Image, wordmark_svg: pathlib.Path) -> Image.Image:
    unit = LOCKUP_ICON_PX / LOCKUP_ICON_UNITS
    word = render_svg(wordmark_svg, round(LOCKUP_WORDMARK_UNITS * unit))
    left = round((LOCKUP_ICON_UNITS + LOCKUP_GAP_UNITS) * unit)
    canvas = Image.new("RGBA", (left + word.width, LOCKUP_ICON_PX), (0, 0, 0, 0))
    canvas.alpha_composite(rounded(icon.resize((LOCKUP_ICON_PX, LOCKUP_ICON_PX), Image.LANCZOS), LOCKUP_CORNER_RATIO))
    canvas.alpha_composite(word, (left, (LOCKUP_ICON_PX - word.height) // 2))
    return canvas


def build(seal_scale: float = SMALL_SEAL_SCALE) -> dict[str, Image.Image]:
    detailed = Image.open(SOURCE_DIR / "book-detailed.png").convert("RGBA")
    flat = Image.open(SOURCE_DIR / "book-flat.png").convert("RGBA")
    if seal_scale != 1:
        flat = enlarge_seal(flat, seal_scale)
    android_ratio = LARGE_BODY_RATIO * ANDROID_SCALE * 100 / ANDROID_CANVAS_DP
    masters = {
        "icon-large.png": flatten(place(detailed, WORK_PX, LARGE_BODY_RATIO)),
        "icon-small.png": flatten(place(flat, WORK_PX, SMALL_BODY_RATIO)),
        "icon-android-foreground.png": place(detailed, WORK_PX, android_ratio),
        "icon-android-background.png": gradient(WORK_PX),
    }
    return {name: image.resize((MASTER_PX, MASTER_PX), Image.LANCZOS) for name, image in masters.items()}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="앱 아이콘 래스터 원본과 가로 조합 PNG를 만듭니다.")
    parser.add_argument("--seal-scale", type=float, default=SMALL_SEAL_SCALE, help="작은 원형 낙관 배율(비교용)")
    parser.add_argument("--out-dir", type=pathlib.Path, default=LOGO_DIR, help="출력 폴더(비교용, 기본 logo/)")
    arguments = parser.parse_args(argv)
    seal_scale, out_dir = arguments.seal_scale, arguments.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    masters = build(seal_scale)
    for name, wordmark_name in LOCKUPS.items():
        masters[name] = lockup(masters["icon-large.png"], LOGO_DIR / wordmark_name)
    manifest = {"masterPx": MASTER_PX, "smallSealScale": seal_scale, "lockupHeightPx": LOCKUP_ICON_PX,
                "resvg": resvg_version(), "files": {}}
    for name, image in masters.items():
        path = out_dir / name
        image.save(path, optimize=True)
        manifest["files"][name] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "mode": image.mode,
                                   "size": list(image.size)}
    manifest["sources"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                           for path in sorted(SOURCE_DIR.glob("*.png"))}
    manifest["androidForeground"] = {"safeDiameterDp": ANDROID_SAFE_DIAMETER_DP,
                                     **safe_zone(masters["icon-android-foreground.png"])}
    (out_dir / MANIFEST.name).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest["androidForeground"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

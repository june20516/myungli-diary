"""한자 대체 글꼴: 앱 한자 글꼴(Pretendard JP)에 없는 글자만 Noto Sans JP에서 떼어 냅니다 (#1029, 결정 V121).

font.family.hanja는 ["Pretendard JP", "Myungli Hanja Supplement", ...]입니다. 이 도구가 만드는 부분 글꼴이 둘째 이름이고,
app은 fonts/hanja-supplement/의 파일을 그대로 묶습니다. 대상 글자는 writing 용어 한자(hanja.yaml)와 원전 원고(*/source.yaml)의
한자, 그리고 hanja-tag 글자 표입니다. writing이 Pretendard JP에 없는 글자를 새로 쓰면 --check가 실패하고, 다시 만들면 됩니다.

    uv run --with fonttools python docs/identity/design/tools/hanja_supplement.py --font-dir .suberpowers/fonts
    uv run --with fonttools python docs/identity/design/tools/hanja_supplement.py --font-dir .suberpowers/fonts --check
"""
import argparse
import hashlib
import json
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

DESIGN_DIR = pathlib.Path(__file__).resolve().parent.parent
CONTENT_DIR = DESIGN_DIR.parent / "writing" / "content"
OUT_DIR = DESIGN_DIR / "fonts" / "hanja-supplement"
MANIFEST = OUT_DIR / "manifest.json"
BASE_FONT = "PretendardJP-Regular.otf"
SOURCE_FONT = "NotoSansJP-wght.ttf"
FAMILY = "Myungli Hanja Supplement"
FILE_STEM = "MyungliHanjaSupplement"
# Pretendard JP 굵기 넷과 같은 이름과 값 (app pubspec의 Pretendard JP 묶음)
WEIGHTS = {"Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700}
# 재현을 위한 고정 시각(head.created, head.modified, 1904 기준 초). 원본 글꼴 판과 상관없음
FIXED_TIMESTAMP = 3_850_000_000


def is_hanja(char: str) -> bool:
    code = ord(char)
    return (0x3400 <= code <= 0x4DBF or 0x4E00 <= code <= 0x9FFF or 0xF900 <= code <= 0xFAFF
            or 0x20000 <= code <= 0x3134F)


def hanja_files() -> list[pathlib.Path]:
    return [CONTENT_DIR / "hanja.yaml", *sorted(CONTENT_DIR.glob("*/source.yaml"))]


def glyph_table_chars() -> set[str]:
    sentence = json.loads((DESIGN_DIR / "components" / "sentence.json").read_text(encoding="utf-8"))
    tag = next(c for c in sentence["components"] if c["id"] == "hanja-tag")
    return {char for group in tag["parts"]["glyphs"].values() for char in group}


def wanted_chars() -> set[str]:
    chars = {char for path in hanja_files() for char in path.read_text(encoding="utf-8") if is_hanja(char)}
    return chars | glyph_table_chars()


def missing_chars(font_dir: pathlib.Path) -> list[str]:
    """한자 글꼴에 없는 대상 글자입니다(코드 포인트 순)."""
    cmap = TTFont(font_dir / BASE_FONT).getBestCmap()
    return sorted((char for char in wanted_chars() if ord(char) not in cmap), key=ord)


def _rename(font: TTFont, style: str) -> None:
    names = {1: FAMILY if style in ("Regular", "Bold") else f"{FAMILY} {style}",
             2: style if style in ("Regular", "Bold") else "Regular",
             4: f"{FAMILY} {style}", 6: f"{FILE_STEM}-{style}", 16: FAMILY, 17: style}
    table = font["name"]
    table.names = [record for record in table.names if record.nameID not in (*names, 3, 25)]
    for name_id, value in names.items():
        table.setName(value, name_id, 3, 1, 0x409)
    table.setName(f"{FAMILY} {style}; subset of Noto Sans JP", 3, 3, 1, 0x409)


def build_one(font_dir: pathlib.Path, chars: list[str], style: str, weight: int) -> bytes:
    font = TTFont(font_dir / SOURCE_FONT)
    font = instancer.instantiateVariableFont(font, {"wght": weight})
    options = subset.Options()
    options.layout_features = []
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(char) for char in chars])
    subsetter.subset(font)
    _rename(font, style)
    font["OS/2"].usWeightClass = weight
    font["head"].created = font["head"].modified = FIXED_TIMESTAMP
    font.recalcTimestamp = False
    out = OUT_DIR / f"{FILE_STEM}-{style}.ttf"
    font.save(out)
    return out.read_bytes()


def build(font_dir: pathlib.Path) -> dict:
    chars = missing_chars(font_dir)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    files = {}
    for style, weight in WEIGHTS.items():
        data = build_one(font_dir, chars, style, weight)
        files[f"{FILE_STEM}-{style}.ttf"] = {"weight": weight, "sha256": hashlib.sha256(data).hexdigest()}
    manifest = {
        "family": FAMILY,
        "chars": "".join(chars),
        "base": BASE_FONT,
        "source": SOURCE_FONT,
        "license": "SIL Open Font License 1.1 (OFL.txt). Noto Sans JP의 부분 글꼴이고 예약 이름(Source)을 쓰지 않음",
        "files": files,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def check(font_dir: pathlib.Path) -> list[str]:
    """문제 목록입니다. 비면 대체 글꼴이 지금 원고의 빠진 글자를 모두 담고 있습니다."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    problems = []
    need = missing_chars(font_dir)
    if "".join(need) != manifest["chars"]:
        problems.append(f"빠진 글자가 바뀜: 지금 {''.join(need)!r}, 목록 {manifest['chars']!r} (다시 만들기)")
    for name, info in manifest["files"].items():
        path = OUT_DIR / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != info["sha256"]:
            problems.append(f"{name}: 없거나 sha256이 목록과 다름")
            continue
        cmap = TTFont(path).getBestCmap()
        lacking = [char for char in need if ord(char) not in cmap]
        if lacking:
            problems.append(f"{name}: {''.join(lacking)} 없음")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font-dir", type=pathlib.Path, required=True)
    parser.add_argument("--check", action="store_true", help="만들지 않고 확인만 합니다")
    args = parser.parse_args(argv)
    if args.check:
        problems = check(args.font_dir)
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1 if problems else 0
    manifest = build(args.font_dir)
    print(f"{FAMILY}: {manifest['chars']} ({len(manifest['files'])}개 굵기) → {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

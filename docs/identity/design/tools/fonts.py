"""측정 글꼴을 고정 주소에서 받아 sha256을 확인합니다 (#362, D81).

글자 수 상한 표(lengths.py)와 워드마크(wordmark.py)가 쓰는 글꼴입니다. 글꼴은 모두 SIL OFL 1.1이고 저장소에는 넣지 않습니다.
이미 있고 checksum이 맞는 파일은 받지 않으므로, CI 캐시에서 일부만 복원돼도 결과는 같습니다.

    uv run python docs/identity/design/tools/fonts.py --font-dir .suberpowers/fonts
"""
import argparse
import hashlib
import pathlib
import sys
import urllib.request
from dataclasses import dataclass

GOOGLE_FONTS = "https://raw.githubusercontent.com/google/fonts"
PRETENDARD = "https://cdn.jsdelivr.net/npm/pretendard@1.3.9/dist/public/static"


@dataclass(frozen=True)
class Font:
    name: str
    url: str
    sha256: str


# 주소는 commit·버전으로 고정합니다. 글꼴을 바꾸면 sha256도 바꾸고, CI 캐시 키(이 파일의 해시)도 함께 바뀝니다.
FONTS = (
    Font("GowunDodum-Regular.ttf",
         f"{GOOGLE_FONTS}/16a2143d6f6d3a722f4c1bd96a76a637b952c412/ofl/gowundodum/GowunDodum-Regular.ttf",
         "a6e457933227483a11758fd0947bc74422a106d46f0bf057fdaa5af94a30067d"),
    Font("ZenMaruGothic-Regular.ttf",
         f"{GOOGLE_FONTS}/633bf7f8bd80897a8c2680385c53fb0ac4399f6e/ofl/zenmarugothic/ZenMaruGothic-Regular.ttf",
         "a0c0b53543e0993ae2225e629c833f3d51495ad31720694ff112ce4ce11111ef"),
    Font("Pretendard-Regular.otf", f"{PRETENDARD}/Pretendard-Regular.otf",
         "3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93"),
    Font("Pretendard-Medium.otf", f"{PRETENDARD}/Pretendard-Medium.otf",
         "d39e50e4bb52b4993b6a4eeb821a171254745bd824446af01e1f616b89fface0"),
    Font("Pretendard-SemiBold.otf", f"{PRETENDARD}/Pretendard-SemiBold.otf",
         "c89bc43027dc7cde5726e96223376f8eec09302b2fc1f8147fd5b57cfc376118"),
    Font("Pretendard-Bold.otf", f"{PRETENDARD}/Pretendard-Bold.otf",
         "2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7"),
)


def sha256_of(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invalid_fonts(font_dir: pathlib.Path) -> list[str]:
    """없거나 checksum이 다른 글꼴 이름입니다."""
    return [font.name for font in FONTS
            if not (font_dir / font.name).is_file() or sha256_of(font_dir / font.name) != font.sha256]


def fetch(font_dir: pathlib.Path) -> list[str]:
    """맞지 않는 글꼴만 받아 checksum을 확인하고, 받은 이름을 돌려줍니다. 받은 파일도 다르면 ValueError입니다."""
    font_dir.mkdir(parents=True, exist_ok=True)
    wanted = set(invalid_fonts(font_dir))
    for font in FONTS:
        if font.name not in wanted:
            continue
        with urllib.request.urlopen(font.url, timeout=60) as response:
            data = response.read()
        actual = hashlib.sha256(data).hexdigest()
        if actual != font.sha256:
            raise ValueError(f"{font.name}: sha256 {actual} != {font.sha256} ({font.url})")
        (font_dir / font.name).write_bytes(data)
    return [font.name for font in FONTS if font.name in wanted]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font-dir", type=pathlib.Path, required=True)
    parser.add_argument("--check", action="store_true", help="받지 않고 확인만 합니다")
    args = parser.parse_args(argv)
    if args.check:
        invalid = invalid_fonts(args.font_dir)
        for name in invalid:
            print(f"없거나 다름: {args.font_dir / name}", file=sys.stderr)
        return 1 if invalid else 0
    fetched = fetch(args.font_dir)
    print(f"받음 {len(fetched)}개, 있던 것 {len(FONTS) - len(fetched)}개: {args.font_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""측정 글꼴 받기 테스트 (#362). 네트워크 없이 urlopen을 바꿔 끼웁니다."""
import hashlib
import io
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import fonts  # noqa: E402
from fonts import Font, fetch, invalid_fonts  # noqa: E402

GOOD = b"font-a"
ONE = (Font("a.ttf", "https://example.invalid/a.ttf", hashlib.sha256(GOOD).hexdigest()),)


def serve(monkeypatch, body: bytes) -> list[str]:
    requested: list[str] = []

    def urlopen(url, timeout):
        requested.append(url)
        return io.BytesIO(body)

    monkeypatch.setattr(fonts.urllib.request, "urlopen", urlopen)
    monkeypatch.setattr(fonts, "FONTS", ONE)
    return requested


def test_fetch_downloads_missing_and_skips_valid(tmp_path, monkeypatch):
    requested = serve(monkeypatch, GOOD)
    assert fetch(tmp_path) == ["a.ttf"]
    assert (tmp_path / "a.ttf").read_bytes() == GOOD
    assert fetch(tmp_path) == [] and len(requested) == 1


def test_fetch_replaces_file_with_wrong_checksum(tmp_path, monkeypatch):
    serve(monkeypatch, GOOD)
    (tmp_path / "a.ttf").write_bytes(b"stale")
    assert invalid_fonts(tmp_path) == ["a.ttf"]
    assert fetch(tmp_path) == ["a.ttf"] and invalid_fonts(tmp_path) == []


def test_fetch_rejects_wrong_download_without_writing(tmp_path, monkeypatch):
    serve(monkeypatch, b"tampered")
    with pytest.raises(ValueError):
        fetch(tmp_path)
    assert not (tmp_path / "a.ttf").exists()


def test_fonts_are_pinned():
    assert len({font.name for font in fonts.FONTS}) == len(fonts.FONTS)
    for font in fonts.FONTS:
        assert "/main/" not in font.url and "@latest" not in font.url
        assert len(font.sha256) == 64

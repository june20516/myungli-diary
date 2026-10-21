"""design 도구 테스트 공용 fixture."""
import os
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[3]
sys.path.insert(0, str(TOOLS_DIR))

import fonts  # noqa: E402

FONT_DIR = REPO_ROOT / ".suberpowers" / "fonts"


@pytest.fixture(scope="session")
def font_dir() -> pathlib.Path:
    """측정 글꼴 디렉터리입니다. 로컬에서는 글꼴이 없으면 skip하고, CI(DESIGN_FONTS_REQUIRED=1)에서는 실패합니다(#362)."""
    invalid = fonts.invalid_fonts(FONT_DIR)
    if invalid:
        message = f"측정 글꼴이 없거나 다름: {', '.join(invalid)} (tools/fonts.py로 받음)"
        if os.environ.get("DESIGN_FONTS_REQUIRED") == "1":
            pytest.fail(message)
        pytest.skip(message)
    return FONT_DIR

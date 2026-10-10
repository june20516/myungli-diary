# lunar_python은 calendar_core 안에서만 import
from pathlib import Path

SRC = Path(__file__).resolve().parents[2] / "src" / "myungri_engine"


def test_lunar_python_imported_only_in_calendar_core():
    offenders = [
        p
        for p in SRC.rglob("*.py")
        if "lunar_python" in p.read_text(encoding="utf-8") and "calendar_core" not in p.parts
    ]
    assert offenders == []

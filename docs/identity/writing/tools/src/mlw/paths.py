"""패키지 위치에서 계산하는 기준 경로."""

from pathlib import Path

# tools/src/mlw/paths.py -> docs/identity/writing/
WRITING_DIR = Path(__file__).resolve().parents[3]
RULES_DIR = WRITING_DIR / "rules"
SLOTS_DIR = WRITING_DIR / "slots"
CONTENT_DIR = WRITING_DIR / "content"

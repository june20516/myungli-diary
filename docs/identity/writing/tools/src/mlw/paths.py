"""패키지 위치에서 계산하는 기준 경로."""

from pathlib import Path

# tools/src/mlw/paths.py -> docs/identity/writing/
WRITING_DIR = Path(__file__).resolve().parents[3]
RULES_DIR = WRITING_DIR / "rules"
SLOTS_DIR = WRITING_DIR / "slots"
CONTENT_DIR = WRITING_DIR / "content"
GENERATED_DIR = WRITING_DIR / "generated"
# docs/identity/writing/ -> 저장소 루트
MESSAGE_KEYS_FILE = WRITING_DIR.parents[2] / "core" / "message_keys.json"
MESSAGE_PARAMS_FILE = WRITING_DIR.parents[2] / "core" / "message_params.json"
IA_FILE = WRITING_DIR.parents[2] / "docs" / "ia" / "screens.json"
FIXTURE_FILE = WRITING_DIR / "tools" / "fixtures" / "week_samples.json"

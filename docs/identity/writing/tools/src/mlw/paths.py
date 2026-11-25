"""패키지 위치에서 계산하는 기준 경로."""

from pathlib import Path

# tools/src/mlw/paths.py -> docs/identity/writing/
WRITING_DIR = Path(__file__).resolve().parents[3]
RULES_DIR = WRITING_DIR / "rules"
SLOTS_DIR = WRITING_DIR / "slots"
CONTENT_DIR = WRITING_DIR / "content"
GENERATED_DIR = WRITING_DIR / "generated"
# 원어민 검수 시트와 감수자 안내 원문(#1283)
REVIEW_DIR = WRITING_DIR / "review"
# docs/identity/writing/ -> 저장소 루트
MESSAGE_KEYS_FILE = WRITING_DIR.parents[2] / "core" / "message_keys.json"
MESSAGE_PARAMS_FILE = WRITING_DIR.parents[2] / "core" / "message_params.json"
EVIDENCE_RULES_FILE = WRITING_DIR.parents[2] / "core" / "evidence_rules.json"
EVIDENCE_SOURCES_FILE = WRITING_DIR.parents[2] / "core" / "evidence_sources.json"
IA_DIR = WRITING_DIR.parents[2] / "docs" / "ia"
# writing이 읽는 표면별 IA 파일(D146): 앱과 server 페이지, 랜딩. admin.json은 web만 읽습니다.
IA_FILES = (IA_DIR / "screens.json", IA_DIR / "site.json")
FIXTURE_FILE = WRITING_DIR / "tools" / "fixtures" / "week_samples.json"

"""바뀐 경로에 맞는 slow 테스트 묶음만 고른다 (D81).

core.yml의 core-paths job이 바뀐 파일 목록(저장소 루트 기준, 한 줄에 하나)을 표준 입력으로 넘기면,
돌릴 묶음의 pytest 표지 식(예: `kasi or calibration`)을 한 줄로 출력합니다. 고를 묶음이 없으면 빈 줄입니다.
core-paths job은 uv 없이 시스템 Python으로 돌리므로 표준 라이브러리만 씁니다.

묶음의 엔진 의존 패키지가 실제 import와 맞는지, slow 테스트가 모두 어느 묶음에 들어 있는지는
tests/unit/test_slow_scope.py가 검사합니다.
"""

from __future__ import annotations

import sys
from collections.abc import Iterable
from dataclasses import dataclass

ENGINE_DIR = "core/src/myungli_engine"

# 모든 묶음에 영향을 주는 경로: 의존성, pytest 설정, 이 workflow, 이 파일
SHARED_PATHS = (
    "core/uv.lock",
    "core/pyproject.toml",
    ".github/workflows/core.yml",
    "core/tools/slow_scope.py",
)


@dataclass(frozen=True)
class SlowSuite:
    marker: str
    # 묶음이 import하는 엔진 하위 패키지(ENGINE_DIR 아래 디렉터리 이름)
    engine_packages: tuple[str, ...]
    # 묶음만의 파일. 저장소 루트 기준 경로 또는 경로 접두사
    files: tuple[str, ...]

    def is_affected_by(self, path: str) -> bool:
        engine_dirs = tuple(f"{ENGINE_DIR}/{package}/" for package in self.engine_packages)
        return path.startswith(engine_dirs) or path.startswith(self.files)


SLOW_SUITES = (
    SlowSuite(
        marker="kasi",
        engine_packages=("calendar_core", "constants", "domain"),
        files=("core/tests/golden/test_kasi.py", "core/tests/golden/fixtures/kasi_"),
    ),
    SlowSuite(
        marker="calibration",
        engine_packages=("calendar_core", "constants", "domain", "rules"),
        files=("core/tools/calibrate_strength.py", "core/tests/unit/rules/test_calibration.py"),
    ),
)


def affected_markers(changed_paths: Iterable[str]) -> list[str]:
    paths = [path.strip() for path in changed_paths if path.strip()]
    if any(path in SHARED_PATHS for path in paths):
        return [suite.marker for suite in SLOW_SUITES]
    return [suite.marker for suite in SLOW_SUITES if any(suite.is_affected_by(path) for path in paths)]


def main() -> None:
    print(" or ".join(affected_markers(sys.stdin)))


if __name__ == "__main__":
    main()

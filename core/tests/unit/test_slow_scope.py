# slow 테스트 묶음 고르기(tools/slow_scope.py)가 실제 의존 범위·표지와 맞는지 검사한다 (D81)
import ast
import re
from pathlib import Path

import pytest
from slow_scope import ENGINE_DIR, SHARED_PATHS, SLOW_SUITES, affected_markers

REPO_DIR = Path(__file__).resolve().parents[3]
SRC_DIR = REPO_DIR / "core" / "src"
TESTS_DIR = REPO_DIR / "core" / "tests"
ENGINE_PACKAGE = "myungli_engine"


def _module_file(module: str) -> Path | None:
    path = SRC_DIR.joinpath(*module.split("."))
    if (path / "__init__.py").exists():
        return path / "__init__.py"
    if path.with_suffix(".py").exists():
        return path.with_suffix(".py")
    return None


def _engine_imports(path: Path, package: str) -> set[str]:
    """파일이 import하는 엔진 모듈 이름. `from a import b`는 b가 모듈일 때를 위해 `a.b`도 넣는다."""
    found: set[str] = set()
    for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
        if isinstance(node, ast.Import):
            found |= {alias.name for alias in node.names}
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                parts = package.split(".")[: len(package.split(".")) - node.level + 1]
                module = ".".join(parts + ([node.module] if node.module else []))
            else:
                module = node.module or ""
            found.add(module)
            found |= {f"{module}.{alias.name}" for alias in node.names}
    return {name for name in found if name.startswith(ENGINE_PACKAGE) and _module_file(name)}


def _engine_packages_used_by(start: Path) -> set[str]:
    """start에서 엔진 import를 따라가 닿는 하위 패키지 이름(calendar_core 등)."""
    seen: set[str] = set()
    pending = list(_engine_imports(start, ""))
    while pending:
        module = pending.pop()
        if module in seen:
            continue
        seen.add(module)
        file = _module_file(module)
        assert file is not None
        package = module if file.name == "__init__.py" else module.rsplit(".", 1)[0]
        pending.extend(_engine_imports(file, package))
    return {name.split(".")[1] for name in seen if name.count(".") >= 1}


@pytest.mark.parametrize("suite", SLOW_SUITES, ids=lambda suite: suite.marker)
def test_suite_declares_every_engine_package_it_imports(suite) -> None:
    python_files = [REPO_DIR / path for path in suite.files if path.endswith(".py")]
    assert python_files, "묶음에 의존 범위를 따라갈 Python 파일이 없습니다"
    used: set[str] = set()
    for file in python_files:
        assert file.exists(), file
        used |= _engine_packages_used_by(file)
    assert used <= set(suite.engine_packages), (
        f"선언에 없는 엔진 패키지: {sorted(used - set(suite.engine_packages))}"
    )


@pytest.mark.parametrize("suite", SLOW_SUITES, ids=lambda suite: suite.marker)
def test_declared_engine_packages_exist(suite) -> None:
    for package in suite.engine_packages:
        assert (REPO_DIR / ENGINE_DIR / package).is_dir(), package


def test_every_slow_test_file_belongs_to_one_suite_with_its_marker() -> None:
    slow_files = {
        path.relative_to(REPO_DIR).as_posix()
        for path in TESTS_DIR.rglob("test_*.py")
        if re.search(r"pytest\.mark\.slow\b", path.read_text(encoding="utf-8"))
    }
    suite_test_files = {
        path: suite
        for suite in SLOW_SUITES
        for path in suite.files
        if path.startswith("core/tests/") and path.endswith(".py")
    }
    assert slow_files == set(suite_test_files)
    for path, suite in suite_test_files.items():
        text = (REPO_DIR / path).read_text(encoding="utf-8")
        assert re.search(rf"pytest\.mark\.{suite.marker}\b", text), f"{path}에 {suite.marker} 표지가 없습니다"


def test_markers_are_registered_in_pytest_config() -> None:
    config = (REPO_DIR / "core" / "pyproject.toml").read_text(encoding="utf-8")
    for suite in SLOW_SUITES:
        assert f'"{suite.marker}:' in config, suite.marker


@pytest.mark.parametrize(
    ("changed", "expected"),
    [
        (["core/src/myungli_engine/rules/strength.py"], ["calibration"]),
        (["core/src/myungli_engine/calendar_core/solar_terms.py"], ["kasi", "calibration"]),
        (["core/tests/golden/fixtures/kasi_lunar.json"], ["kasi"]),
        (["core/tests/golden/fixtures/reference_cases.json"], []),
        (["core/tools/calibrate_strength.py"], ["calibration"]),
        (["core/src/myungli_engine/composers/daily.py", "core/README.md"], []),
        (["core/uv.lock"], ["kasi", "calibration"]),
        ([".github/workflows/core.yml", ""], ["kasi", "calibration"]),
        ([], []),
    ],
)
def test_affected_markers(changed: list[str], expected: list[str]) -> None:
    assert affected_markers(changed) == expected


def test_shared_paths_select_every_suite() -> None:
    for path in SHARED_PATHS:
        assert affected_markers([path]) == [suite.marker for suite in SLOW_SUITES]

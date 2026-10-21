import subprocess
import sys
from pathlib import Path

import pytest

CORE_DIR = Path(__file__).resolve().parents[3]


@pytest.mark.slow
@pytest.mark.calibration
def test_calibration_constants_up_to_date() -> None:
    result = subprocess.run(
        [sys.executable, "tools/calibrate_strength.py", "--check"],
        cwd=CORE_DIR,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

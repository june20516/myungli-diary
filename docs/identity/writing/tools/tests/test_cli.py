"""mlw 명령 테스트."""

import re
import shutil
from pathlib import Path

import pytest

from mlw.cli import main
from mlw.paths import CONTENT_DIR

FINDING_LINE = re.compile(r"^\S+:\d+ \S+ (error|warn) .+$")
BAD_CONTENT = """\
- {slot: daily.color, key: color.gisin_day, text: "{element:color}(이)가 좋아요!"}
- {slot: daily.color, key: color.gwiin_day, text: "{element:color}(이)가 잘 맞아요."}
- {slot: daily.color, key: color.ordinary_day, text: "{element:color}(이)가 잘 맞아요."}
- {slot: daily.color, key: color.yongsin_day, text: "{element:color}(이)가 잘 맞아요."}
"""


def test_cli_check_example_content_is_clean(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["check", str(CONTENT_DIR), "--partial"]) == 0
    assert capsys.readouterr().out == ""


def test_cli_check_exit_codes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    clean = tmp_path / "clean"
    shutil.copytree(CONTENT_DIR, clean)
    assert main(["check", str(clean), "--partial"]) == 0

    bad = tmp_path / "bad"
    (bad / "ko").mkdir(parents=True)
    (bad / "ko" / "color.yaml").write_text(BAD_CONTENT, encoding="utf-8")
    capsys.readouterr()
    assert main(["check", str(bad), "--partial"]) == 1
    lines = capsys.readouterr().out.splitlines()
    assert FINDING_LINE.match(lines[0])
    assert "slop.P8" in lines[0]


def test_cli_without_partial_reports_missing(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["check", str(CONTENT_DIR)]) == 1
    assert "complete.missing" in capsys.readouterr().out


def test_cli_output_sorted_by_file_and_line(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["check", str(CONTENT_DIR)]) == 1
    parsed = [line.split(" ")[0].rsplit(":", 1) for line in capsys.readouterr().out.splitlines()]
    keys = [(file, int(line)) for file, line in parsed]
    assert keys == sorted(keys)


def test_cli_load_error_exit_code(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "slop.yaml").write_text("- {id: slop.X}\n", encoding="utf-8")
    assert main(["check", str(CONTENT_DIR), "--rules-dir", str(rules_dir)]) == 2
    captured = capsys.readouterr()
    assert "Traceback" not in captured.out + captured.err
    assert FINDING_LINE.match(captured.out.splitlines()[0])


def test_cli_check_arb_exit_codes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    arb = tmp_path / "app_ko.arb"
    arb.write_text('{\n  "@@locale": "ko",\n  "hello": "반가워요!"\n}\n', encoding="utf-8")
    assert main(["check-arb", str(arb)]) == 1
    assert f"{arb}:3 slop.P8 error" in capsys.readouterr().out
    arb.write_text('{\n  "@@locale": "ko",\n  "hello": "반가워요"\n}\n', encoding="utf-8")
    assert main(["check-arb", str(arb)]) == 0


def test_cli_missing_json_file_is_load_error(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    missing = tmp_path / "nothing.json"
    for option in ("--message-keys", "--fixture"):
        assert main(["check", str(CONTENT_DIR), "--partial", option, str(missing)]) == 2
        captured = capsys.readouterr()
        assert "Traceback" not in captured.out + captured.err
        assert FINDING_LINE.match(captured.out.splitlines()[0])
        assert "load.json" in captured.out


def test_cli_broken_json_file_is_load_error(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    broken = tmp_path / "broken.json"
    broken.write_text("[\n  1,\n  oops\n]\n", encoding="utf-8")
    wrong_shape = tmp_path / "shape.json"
    wrong_shape.write_text('{"a": 1}', encoding="utf-8")
    for option, path in (("--message-keys", broken), ("--fixture", broken), ("--message-keys", wrong_shape)):
        assert main(["check", str(CONTENT_DIR), "--partial", option, str(path)]) == 2
        captured = capsys.readouterr()
        assert "Traceback" not in captured.out + captured.err
        assert FINDING_LINE.match(captured.out.splitlines()[0])
        assert "load.json" in captured.out

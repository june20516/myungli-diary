"""mlw 명령 테스트."""

import json
import re
import shutil
from pathlib import Path

import pytest

from mlw.cli import main
from mlw.paths import CONTENT_DIR, RULES_DIR, SLOTS_DIR

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


DAY = {
    "head": "fortune.yongsin_day.inseong",
    "tag_sentence": None,
    "guide": "guide.clash",
    "color": "color.yongsin_day",
    "direction": "direction.day_kind.yongsin",
    "number": "number.yongsin_day",
    "focus": "focus_time.gwiin",
    "tag_label": None,
}


def fixture_json(**changes: object) -> str:
    fixture: dict[str, object] = {"start": "2026-11-02", "samples": [{"birth_id": "b01", "days": [DAY]}]}
    return json.dumps(fixture | changes)


def sample_json(days: object, birth_id: object = "b01") -> str:
    return fixture_json(samples=[{"birth_id": birth_id, "days": days}])


def assert_json_load_error(path: Path, option: str, capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["check", str(CONTENT_DIR), "--partial", option, str(path)]) == 2
    captured = capsys.readouterr()
    assert "Traceback" not in captured.out + captured.err
    assert FINDING_LINE.match(captured.out.splitlines()[0])
    assert captured.out.splitlines()[0].startswith(f"{path}:1 load.json error")


def test_cli_non_utf8_file_is_load_error(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    path = tmp_path / "latin.json"
    path.write_bytes(b"[\xff\xfe]")
    assert_json_load_error(path, "--message-keys", capsys)
    assert_json_load_error(path, "--fixture", capsys)


@pytest.mark.parametrize(
    "body",
    [
        fixture_json(start="내일"),
        fixture_json(samples={"b01": 1}),
        fixture_json(samples=[1]),
        sample_json([DAY], birth_id=1),
        sample_json("x"),
        sample_json([1]),
        sample_json([{k: v for k, v in DAY.items() if k != "guide"}]),
        sample_json([DAY | {"head": None}]),
        sample_json([DAY | {"tag_label": 3}]),
    ],
)
def test_cli_bad_fixture_structure_is_load_error(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], body: str
) -> None:
    path = tmp_path / "fixture.json"
    path.write_text(body, encoding="utf-8")
    assert_json_load_error(path, "--fixture", capsys)


def copy_slots_with(tmp_path: Path, slot_id: str, extra_line: str) -> Path:
    """슬롯 명세를 복사하고 `slot_id` 슬롯에 필드 한 줄을 덧붙입니다."""
    slots_dir = tmp_path / "slots"
    shutil.copytree(SLOTS_DIR, slots_dir)
    daily = slots_dir / "content" / "daily.yaml"
    marker = f"- id: {slot_id}\n"
    text = daily.read_text(encoding="utf-8")
    assert marker in text
    daily.write_text(text.replace(marker, f"{marker}  {extra_line}\n"), encoding="utf-8")
    return slots_dir


def write_bad_content(tmp_path: Path) -> Path:
    content = tmp_path / "content"
    (content / "ko").mkdir(parents=True)
    (content / "ko" / "color.yaml").write_text(BAD_CONTENT, encoding="utf-8")
    return content


def test_cli_check_applies_slot_allowed(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    slots_dir = copy_slots_with(tmp_path, "daily.color", "allowed: [slop.P8]")
    content = write_bad_content(tmp_path)
    assert main(["check", str(content), "--partial", "--slots-dir", str(slots_dir)]) == 0
    assert "slop.P8" not in capsys.readouterr().out


def test_cli_check_applies_slot_forbidden(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # 규칙 사본에서 slop.P8이 info 목적을 예외로 두게 바꿉니다. info 슬롯이 forbidden에 적으면 그래도 적용합니다.
    rules_dir = tmp_path / "rules"
    shutil.copytree(RULES_DIR, rules_dir)
    slop = rules_dir / "slop.yaml"
    text = slop.read_text(encoding="utf-8")
    p8 = text.index("- id: slop.P8")
    exempt_at = text.index("exempt_purposes: []", p8)
    slop.write_text(text[:exempt_at] + "exempt_purposes: [info]" + text[exempt_at + len("exempt_purposes: []") :], encoding="utf-8")
    content = write_bad_content(tmp_path)
    base = ["check", str(content), "--partial", "--rules-dir", str(rules_dir)]

    assert main([*base, "--slots-dir", str(SLOTS_DIR)]) == 0
    assert "slop.P8" not in capsys.readouterr().out
    slots_dir = copy_slots_with(tmp_path, "daily.color", "forbidden: [slop.P8]")
    assert main([*base, "--slots-dir", str(slots_dir)]) == 1
    assert "slop.P8" in capsys.readouterr().out

"""mlw 명령 테스트."""

import json
import re
import shutil
from collections.abc import Callable
from pathlib import Path

import pytest

from mlw.cli import (
    longest_by_category,
    longest_values_for,
    main,
    markup_findings,
    plural_findings,
    sentence_findings,
)
from mlw.jev import JevLimitReached
from mlw.loader import load_rules
from mlw.model import UNBOUNDED, Entry, ParamKind, ParamKindName, Slot
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
    # 근거 슬롯 키를 core 목록으로 채워 경고도 남지 않습니다(#130).
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
    assert all(FINDING_LINE.match(line) for line in lines)
    assert any("slop.P8" in line for line in lines)


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
    for option in ("--message-keys", "--message-params", "--evidence-rules", "--evidence-sources", "--fixture"):
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
    params_list = tmp_path / "params_list.json"
    params_list.write_text('["score"]', encoding="utf-8")
    params_values = tmp_path / "params_values.json"
    params_values.write_text('{"calendar.good": "score"}', encoding="utf-8")
    cases = (
        ("--message-keys", broken),
        ("--message-params", broken),
        ("--fixture", broken),
        ("--message-keys", wrong_shape),
        ("--message-params", params_list),
        ("--message-params", params_values),
        ("--evidence-rules", params_list),
        ("--evidence-rules", params_values),
        ("--evidence-sources", params_list),
    )
    for option, path in cases:
        assert main(["check", str(CONTENT_DIR), "--partial", option, str(path)]) == 2
        captured = capsys.readouterr()
        assert "Traceback" not in captured.out + captured.err
        assert FINDING_LINE.match(captured.out.splitlines()[0])
        assert "load.json" in captured.out


def test_cli_check_compares_evidence_slots_with_core(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    rules = tmp_path / "rules.json"
    rules.write_text('{"only/rule": ["value"]}', encoding="utf-8")
    assert main(["check", str(CONTENT_DIR), "--partial", "--evidence-rules", str(rules)]) == 1
    out = capsys.readouterr().out
    assert "evidence.missing_ref" in out
    assert "evidence.unknown_ref" in out


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


def glossary(key: str, text: str) -> Entry:
    return Entry(Path("g.yaml"), 1, "glossary.value_name", key, None, 1, "ko", text)


GLOSSARY = [
    glossary("element.wood", "나무"),
    glossary("element.water", "물"),
    glossary("color.wood", "초록색"),
    glossary("branch.zi", "자시"),
    glossary("branch.chou", "축시"),
    glossary("branch.yin", "인시예요"),
]
PARAMS = {
    "element": ParamKind("glossary", ("element", "color")),
    "branches": ParamKind("list", ("branch",)),
    "score": ParamKind("number"),
    "role": ParamKind("none"),
}


def values_of(text: str) -> tuple[dict[str, str], list[str]]:
    entry = Entry(Path("a.yaml"), 1, "daily.color", "color.gwiin_day", None, 1, "ko", text)
    return longest_values_for(entry, PARAMS, longest_by_category(GLOSSARY, "ko"), name_max=3)


def test_longest_value_uses_default_category() -> None:
    assert values_of("{element}(이)가 좋아요.") == ({"element": "나무"}, [])


def test_longest_value_uses_chosen_category() -> None:
    assert values_of("{element:color}(이)가 좋아요.") == ({"element:color": "초록색"}, [])


def test_longest_value_for_list_joins_longest_items() -> None:
    assert values_of("{branches}에 집중해 보세요.") == ({"branches": "인시예요, 자시"}, [])


def test_longest_value_for_name_and_number() -> None:
    # 숫자는 값 범위를 모르므로 값을 두지 않습니다. 글자 수 검사는 건너뜁니다(Ruling 2).
    assert values_of("{name}님 {score}점") == ({"name": "가가가"}, [])


@pytest.mark.parametrize("text", ["{role} 좋아요.", "{nowhere} 좋아요.", "{element:stem} 좋아요."])
def test_unresolvable_placeholder_is_reported(text: str) -> None:
    values, unresolved = values_of(text)
    assert values == {}
    assert len(unresolved) == 1


def test_cli_check_warns_length_unknown(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # daily.color에는 design 상한(ko 36)이 있습니다.
    content = tmp_path / "content"
    (content / "ko").mkdir(parents=True)
    (content / "ko" / "color.yaml").write_text(
        '- {slot: daily.color, key: color.gwiin_day, text: "{role} 색이 잘 맞아요."}\n', encoding="utf-8"
    )
    assert main(["check", str(content), "--partial"]) == 1
    out = capsys.readouterr().out
    assert "complete.unrenderable_param error" in out
    assert "style.length_unknown warn" in out


def test_cli_check_includes_ui_manuscripts(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    content = tmp_path / "content" / "ko"
    content.mkdir(parents=True)
    (content / "ui.yaml").write_text(
        '- {slot: ui.depth.explain, key: depthExplain, text: "[[풀이]]"}\n', encoding="utf-8"
    )
    main(["check", str(tmp_path / "content"), "--partial"])
    assert "ui.markup" in capsys.readouterr().out


def test_vocative_sentence_findings_are_not_duplicated() -> None:
    slot = Slot(
        id="s.slot",
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"k": {}},
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/content/test.yaml"),
        vocative=True,
    )
    entry = Entry(Path("content/ko/t.yaml"), 2, "s.slot", "k", None, 1, "ko", "{name}님, 오늘은 맑습니다.")
    findings = sentence_findings({"s.slot": slot}, [entry], load_rules(RULES_DIR))
    assert [finding.rule_id for finding in findings].count("style.S3") == 1


def test_slot_register_reaches_sentence_check() -> None:
    slot = Slot(
        id="s.slot",
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"k": {}},
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/content/test.yaml"),
        register="hamnida",
    )
    entry = Entry(Path("content/ko/t.yaml"), 2, "s.slot", "k", None, 1, "ko", "되돌릴 수 없어요.")
    findings = sentence_findings({"s.slot": slot}, [entry], load_rules(RULES_DIR))
    assert [finding.rule_id for finding in findings] == ["style.S8"]


def test_vocative_stripped_text_is_checked_for_length() -> None:
    slot = Slot(
        id="s.slot",
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"k": {}},
        co_display=(),
        max_length={"ko": 5, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/content/test.yaml"),
        vocative=True,
    )
    entry = Entry(Path("content/ko/t.yaml"), 2, "s.slot", "k", None, 1, "ko", "{name}님, 가나다라마바.")
    findings = sentence_findings({"s.slot": slot}, [entry], load_rules(RULES_DIR))
    messages = [finding.message for finding in findings if finding.rule_id == "style.length"]
    assert any("호칭 없이" in message for message in messages)


def test_cli_check_reports_unknown_term(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    content = tmp_path / "content" / "ko"
    content.mkdir(parents=True)
    (content / "t.yaml").write_text(
        '- {slot: daily.color, key: color.gisin_day, text: "[[색|nope.id]]이 잘 맞아요."}\n', encoding="utf-8"
    )
    main(["check", str(tmp_path / "content"), "--partial"])
    assert "token.term" in capsys.readouterr().out


def plural_slot(group: str = "ui", count_kind: ParamKindName = "number") -> Slot:
    return Slot(
        id="ui.a11y.label",
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"citySearchResults": {"count": ParamKind(count_kind)}},
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots") / group / "t.yaml",
    )


def plural_entry(text: str, lang: str = "ko") -> Entry:
    return Entry(Path(f"content/{lang}/ui.yaml"), 2, "ui.a11y.label", "citySearchResults", None, 1, lang, text)


def check_plural(slot: Slot, entry: Entry) -> list[str]:
    slots = {slot.id: slot}
    findings = [
        *plural_findings(slots, [entry]),
        *sentence_findings(slots, [entry], load_rules(RULES_DIR)),
        *markup_findings(slots, [entry]),
    ]
    return [finding.rule_id for finding in findings]


def test_plural_manuscript_passes() -> None:
    assert check_plural(plural_slot(), plural_entry("결과 {count, plural, other{{count}개}}")) == []
    en = plural_entry("{count, plural, one{{count} result} other{{count} results}}", "en")
    assert check_plural(plural_slot(), en) == []


def test_plural_forms_must_match_language() -> None:
    entry = plural_entry("{count, plural, one{{count}개} other{{count}개}}")
    assert check_plural(plural_slot(), entry) == ["icu.plural"]


def test_plural_syntax_error_is_reported_once() -> None:
    entry = plural_entry("결과 {count, plural, other{{count}개}")
    assert check_plural(plural_slot(), entry).count("icu.plural") == 1


def test_plural_variable_must_be_number() -> None:
    entry = plural_entry("{count, plural, other{{count}개}}")
    assert check_plural(plural_slot(count_kind="text"), entry) == ["icu.plural"]


def test_plural_is_ui_only() -> None:
    entry = plural_entry("{count, plural, other{{count}개}}")
    assert check_plural(plural_slot(group="content"), entry) == ["icu.plural"]


def test_plural_forms_are_checked_as_sentences() -> None:
    entry = plural_entry("{count, plural, other{{count}개 찾았어요!}}")
    assert "slop.P8" in check_plural(plural_slot(), entry)


def test_cli_judge_prints_llm_flags_and_never_blocks(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    content = tmp_path / "content" / "ko"
    content.mkdir(parents=True)
    (content / "ui.yaml").write_text(
        '- {slot: calc-basis.lunar.body, key: calcBasisLunarBody, text: "흐름이 보여요."}\n', encoding="utf-8"
    )
    models: list[str] = []

    def fake_caller(model: str) -> Callable[[str, dict[str, object]], object]:
        models.append(model)
        return lambda prompt, schema: {"flags": [{"index": 1, "rule": "slop.P1", "reason": "무엇을 말하는지 없음"}]}

    monkeypatch.setattr("mlw.cli.claude_cli_caller", fake_caller)
    assert main(["judge", str(tmp_path / "content"), "--lang", "ko", "--model", "haiku"]) == 0
    out = capsys.readouterr().out
    assert models == ["haiku"]
    assert f"{content / 'ui.yaml'}:1 slop.P1 warn LLM 의심(calcBasisLunarBody): 무엇을 말하는지 없음" in out


def test_cli_judge_rejects_non_positive_batch_size() -> None:
    with pytest.raises(SystemExit):
        main(["judge", "--batch-size", "0"])


def test_key_max_length_applies_to_that_key_only() -> None:
    slot = Slot(
        id="s.slot",
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"title": {}, "body": {}},
        co_display=(),
        max_length={"ko": 5, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/ui/test.yaml"),
        key_max_length={"body": {"ko": UNBOUNDED}},
    )
    long_text = "가나다라마바사아자차."
    entries = [
        Entry(Path("content/ko/ui.yaml"), 1, "s.slot", "title", None, 1, "ko", long_text),
        Entry(Path("content/ko/ui.yaml"), 2, "s.slot", "body", None, 1, "ko", long_text),
    ]
    findings = sentence_findings({"s.slot": slot}, entries, load_rules(RULES_DIR))
    assert [finding.line for finding in findings if finding.rule_id == "style.length"] == [1]


def test_cli_check_reads_hanja_beside_language_dirs(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    content = tmp_path / "content"
    (content / "ko").mkdir(parents=True)
    (content / "hanja.yaml").write_text('- {term: stem.nope, hanja: "甲"}\n', encoding="utf-8")
    assert main(["check", str(content), "--partial"]) == 1
    assert "hanja.unknown_term" in capsys.readouterr().out


def _judge_content(tmp_path: Path) -> Path:
    content = tmp_path / "content" / "ko"
    content.mkdir(parents=True)
    (content / "ui.yaml").write_text(
        '- {slot: calc-basis.lunar.body, key: calcBasisLunarBody, text: "흐름이 보여요."}\n', encoding="utf-8"
    )
    return tmp_path / "content"


def test_cli_judge_shadow_requires_api_key(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.delenv("TYPESAFE_API_KEY", raising=False)
    called: list[str] = []
    monkeypatch.setattr("mlw.cli.claude_cli_caller", lambda model: called.append("claude"))
    monkeypatch.setattr("mlw.cli.http_poster", lambda key: called.append("jev"))
    out_path = tmp_path / "shadow.jsonl"
    args = ["judge", str(_judge_content(tmp_path)), "--shadow", "jev", "--shadow-out", str(out_path)]
    assert main(args) == 2
    assert called == []
    assert "TYPESAFE_API_KEY" in capsys.readouterr().err
    assert not out_path.exists()


def test_cli_judge_shadow_writes_pairs_and_keeps_exit_code(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("TYPESAFE_API_KEY", "test-key")
    flag = {"flags": [{"index": 1, "rule": "slop.P1", "reason": "무엇을 말하는지 없음"}]}
    monkeypatch.setattr("mlw.cli.claude_cli_caller", lambda model: lambda prompt, schema: flag)

    def fake_poster(key: str) -> Callable[[dict[str, object]], dict[str, object]]:
        assert key == "test-key"

        def post(body: dict[str, object]) -> dict[str, object]:
            questions = body["questions"]
            assert isinstance(questions, dict)
            return {"model": "jev-1.13.0", "answers": {q: {"type": "noul", "noul": 0.9} for q in questions}}

        return post

    monkeypatch.setattr("mlw.cli.http_poster", fake_poster)
    out_path = tmp_path / "shadow" / "ko.jsonl"
    args = ["judge", str(_judge_content(tmp_path)), "--lang", "ko", "--shadow", "jev", "--shadow-out", str(out_path)]
    assert main(args) == 0
    out = capsys.readouterr().out
    assert "slop.P1 warn LLM 의심(calcBasisLunarBody): 무엇을 말하는지 없음" in out
    assert out.strip().splitlines()[-1].startswith("jev shadow:")
    records = [json.loads(line) for line in out_path.read_text(encoding="utf-8").splitlines()]
    p1 = next(record for record in records if record["rule_id"] == "slop.P1")
    assert (p1["claude_flag"], p1["jev_noul"], p1["jev_flag"]) == (True, 0.9, True)
    assert "test-key" not in out_path.read_text(encoding="utf-8")


def test_cli_judge_shadow_out_is_required_with_shadow() -> None:
    with pytest.raises(SystemExit):
        main(["judge", "--shadow", "jev"])


def test_cli_judge_shadow_out_existing_stops_before_calls(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("TYPESAFE_API_KEY", "test-key")
    called: list[str] = []
    monkeypatch.setattr("mlw.cli.claude_cli_caller", lambda model: called.append("claude"))
    monkeypatch.setattr("mlw.cli.http_poster", lambda key: called.append("jev"))
    out_path = tmp_path / "shadow.jsonl"
    out_path.write_text("old\n", encoding="utf-8")
    args = ["judge", str(_judge_content(tmp_path)), "--shadow", "jev", "--shadow-out", str(out_path)]
    assert main(args) == 2
    assert called == []
    assert "이미 있습니다" in capsys.readouterr().err
    assert out_path.read_text(encoding="utf-8") == "old\n"


def test_cli_judge_shadow_failure_keeps_main_output(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("TYPESAFE_API_KEY", "test-key")
    flag = {"flags": [{"index": 1, "rule": "slop.P1", "reason": "무엇을 말하는지 없음"}]}
    monkeypatch.setattr("mlw.cli.claude_cli_caller", lambda model: lambda prompt, schema: flag)

    def broken_poster(key: str) -> Callable[[dict[str, object]], dict[str, object]]:
        def post(body: dict[str, object]) -> dict[str, object]:
            raise RuntimeError("뜻밖의 오류")

        return post

    monkeypatch.setattr("mlw.cli.http_poster", broken_poster)
    out_path = tmp_path / "shadow.jsonl"
    args = ["judge", str(_judge_content(tmp_path)), "--shadow", "jev", "--shadow-out", str(out_path)]
    assert main(args) == 0
    captured = capsys.readouterr()
    assert "slop.P1 warn LLM 의심" in captured.out
    assert "jev shadow" in captured.err
    assert not out_path.exists()


def test_cli_judge_summary_shows_limit_reason(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("TYPESAFE_API_KEY", "test-key")
    monkeypatch.setattr("mlw.cli.claude_cli_caller", lambda model: lambda prompt, schema: {"flags": []})

    def limited_poster(key: str) -> Callable[[dict[str, object]], dict[str, object]]:
        def post(body: dict[str, object]) -> dict[str, object]:
            raise JevLimitReached("HTTP 401")

        return post

    monkeypatch.setattr("mlw.cli.http_poster", limited_poster)
    args = ["judge", str(_judge_content(tmp_path)), "--shadow", "jev", "--shadow-out", str(tmp_path / "s.jsonl")]
    assert main(args) == 0
    assert "한도 사유 HTTP 401" in capsys.readouterr().out.strip().splitlines()[-1]


def test_cli_judge_shadow_out_without_shadow_is_error(monkeypatch: pytest.MonkeyPatch) -> None:
    # 구현이 빠져도 실제 모델을 부르지 않게 막습니다.
    def no_call(model: str) -> Callable[[str, dict[str, object]], object]:
        raise AssertionError("모델을 부르면 안 됩니다")

    monkeypatch.setattr("mlw.cli.claude_cli_caller", no_call)
    with pytest.raises(SystemExit):
        main(["judge", "--shadow-out", "x.jsonl"])

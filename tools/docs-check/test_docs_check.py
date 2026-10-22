"""docs_check의 테스트. 실행: python3 -I -m unittest -q (이 디렉터리에서)"""

import json
import os
import tempfile
import unittest
from pathlib import Path

import docs_check


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def artifact_entry(**overrides: object) -> dict[str, object]:
    entry: dict[str, object] = {
        "id": "a1",
        "title": "시안",
        "kind": "mockup",
        "file": "a1.png",
        "date": "2026-10-10",
        "milestone": "V0",
        "screens": [],
        "decisions": [],
        "status": "draft",
        "note": "메모",
    }
    entry.update(overrides)
    return entry


class RepoTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()


class LinkTests(RepoTestCase):
    def test_reports_missing_relative_target(self) -> None:
        write(self.root, "a.md", "[x](missing.md)")
        self.assertEqual(docs_check.check_links(self.root), ["a.md: missing.md"])

    def test_ignores_urls_and_anchors(self) -> None:
        write(self.root, "b.md", "# b")
        write(self.root, "a.md", "[x](https://e.com) [y](b.md#sec) [z](mailto:a@b.c)")
        self.assertEqual(docs_check.check_links(self.root), [])

    def test_ignores_links_inside_code(self) -> None:
        write(self.root, "a.md", "```python\n# [x](missing.md)\n```\n`[y](gone.md)` 본문\n")
        self.assertEqual(docs_check.check_links(self.root), [])

    def test_link_with_title_is_checked(self) -> None:
        write(self.root, "a.md", '[x](missing.md "제목")')
        self.assertEqual(docs_check.check_links(self.root), ["a.md: missing.md"])

    def test_percent_encoded_link_resolves(self) -> None:
        write(self.root, "my file.md", "# f")
        write(self.root, "a.md", "[x](my%20file.md)")
        self.assertEqual(docs_check.check_links(self.root), [])

    def test_root_relative_link_resolves_from_repo_root(self) -> None:
        write(self.root, "docs/b.md", "# b")
        write(self.root, "sub/a.md", "[x](/docs/b.md)")
        self.assertEqual(docs_check.check_links(self.root), [])

    def test_indented_fence_is_ignored(self) -> None:
        write(self.root, "a.md", "1. 단계\n   ```\n   [x](missing.md)\n   ```\n")
        self.assertEqual(docs_check.check_links(self.root), [])

    def test_skips_suberpowers_dir(self) -> None:
        write(self.root, ".suberpowers/x.md", "[x](missing.md)")
        self.assertEqual(docs_check.check_links(self.root), [])


class ArtifactTests(RepoTestCase):
    def write_index(self, entries: list[dict[str, object]]) -> None:
        write(self.root, "docs/artifacts/index.json", json.dumps(entries))

    def test_valid_index_passes(self) -> None:
        write(self.root, "docs/artifacts/a1.png", "png")
        self.write_index([artifact_entry()])
        self.assertEqual(docs_check.check_artifacts(self.root), [])

    def test_missing_file_reported(self) -> None:
        self.write_index([artifact_entry()])
        problems = docs_check.check_artifacts(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("[a1]", problems[0])
        self.assertIn("파일 없음", problems[0])

    def test_bad_status_reported(self) -> None:
        write(self.root, "docs/artifacts/a1.png", "png")
        self.write_index([artifact_entry(status="final")])
        problems = docs_check.check_artifacts(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("status", problems[0])

    def test_missing_field_reported(self) -> None:
        write(self.root, "docs/artifacts/a1.png", "png")
        entry = artifact_entry()
        del entry["note"]
        self.write_index([entry])
        problems = docs_check.check_artifacts(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("note", problems[0])

    def test_empty_file_value_reported(self) -> None:
        self.write_index([artifact_entry(file="")])
        problems = docs_check.check_artifacts(self.root)
        self.assertTrue(problems)
        self.assertIn("file", problems[0])

    def test_non_string_file_reported(self) -> None:
        self.write_index([artifact_entry(file=5)])
        problems = docs_check.check_artifacts(self.root)
        self.assertTrue(problems)
        self.assertIn("file", problems[0])

    def test_file_pointing_to_directory_reported(self) -> None:
        (self.root / "docs/artifacts/sub").mkdir(parents=True)
        self.write_index([artifact_entry(file="sub")])
        problems = docs_check.check_artifacts(self.root)
        self.assertTrue(problems)
        self.assertIn("파일 없음", problems[0])

    def test_screens_must_be_list(self) -> None:
        write(self.root, "docs/artifacts/a1.png", "png")
        self.write_index([artifact_entry(screens="daily")])
        problems = docs_check.check_artifacts(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("screens", problems[0])

    def test_non_string_id_and_kind_reported_without_crash(self) -> None:
        write(self.root, "docs/artifacts/a1.png", "png")
        self.write_index([artifact_entry(id=["a"], kind={"x": 1})])
        problems = docs_check.check_artifacts(self.root)
        self.assertTrue(any("kind" in p for p in problems))
        self.assertTrue(any("id" in p for p in problems))

    def test_duplicate_id_reported(self) -> None:
        write(self.root, "docs/artifacts/a1.png", "png")
        self.write_index([artifact_entry(), artifact_entry()])
        problems = docs_check.check_artifacts(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("중복", problems[0])


class DecisionTests(RepoTestCase):
    def test_duplicate_number_reported(self) -> None:
        write(self.root, "docs/decisions.md", "| D41 | a |\n| D42 | b |\n| D41 | c |\n")
        self.assertEqual(
            docs_check.check_decision_ids(self.root), ["docs/decisions.md: D41 중복"]
        )

    def test_same_number_other_prefix_ok(self) -> None:
        write(self.root, "docs/decisions.md", "| D1 | a |\n")
        write(self.root, "core/docs/decisions.md", "| C1 | a |\n")
        self.assertEqual(docs_check.check_decision_ids(self.root), [])


class UserImpactTests(RepoTestCase):
    def check(self, row: str, path: str = "server/docs/decisions.md") -> list[str]:
        write(self.root, path, f"| ID | 날짜 | 분류 | 결정 | 근거 |\n| --- | --- | --- | --- | --- |\n{row}\n")
        return docs_check.check_user_impact(self.root)

    def test_new_row_without_marker_reported(self) -> None:
        problems = self.check("| S105 | 2026-10-24 | 계정 | 무엇 | spec |")
        self.assertEqual(len(problems), 1)
        self.assertIn("S105", problems[0])

    def test_markers_accepted(self) -> None:
        for marker in ("사용자 영향: 없음", "사용자 영향: D85", "사용자 영향: #481"):
            with self.subTest(marker=marker):
                self.assertEqual(self.check(f"| A73 | 2026-10-25 | 화면 | 무엇 | 계획, {marker} |", "app/docs/decisions.md"), [])

    def test_rows_before_start_date_ignored(self) -> None:
        self.assertEqual(self.check("| S104 | 2026-10-23 | API | 무엇 | spec |"), [])

    def test_root_decisions_ignored(self) -> None:
        self.assertEqual(self.check("| D88 | 2026-10-24 | 계정 | 무엇 | 사용자 결정 |", "docs/decisions.md"), [])

    def test_bare_word_is_not_a_marker(self) -> None:
        self.assertEqual(len(self.check("| W40 | 2026-10-24 | 어휘 | 사용자 영향이 큼 | 라운드 |")), 1)


def ia_screen(**overrides: object) -> dict[str, object]:
    screen: dict[str, object] = {
        "id": "today",
        "title": "오늘",
        "tab": "today",
        "presentation": "page",
        "auth": "member",
        "purpose": "오늘 일진을 풀어 보여줍니다",
        "depths": ["surface", "explain", "evidence"],
        "states": [{"id": "loading", "note": "스켈레톤"}],
        "slots": [{"id": "today.fortune.head", "source": "content", "role": "총운 첫 문장, 호칭 자리"}],
        "components": ["day-character"],
        "exits": [],
        "decisions": ["D13"],
    }
    screen.update(overrides)
    return screen


def ia_doc(**overrides: object) -> dict[str, object]:
    doc: dict[str, object] = {
        "version": 1,
        "tabs": [{"id": "today", "title": "오늘", "root": "today"}],
        "components": [{"id": "day-character", "role": "날의 성격"}],
        "screens": [ia_screen()],
    }
    doc.update(overrides)
    return doc


class IaTests(RepoTestCase):
    def write_ia(self, doc: object) -> None:
        write(self.root, "docs/decisions.md", "| D13 | 2026-10-10 | x | x | x |\n")
        text = doc if isinstance(doc, str) else json.dumps(doc, ensure_ascii=False)
        write(self.root, docs_check.IA_PATH, text)

    def problems_for(self, doc: object) -> list[str]:
        self.write_ia(doc)
        return docs_check.check_ia(self.root)

    def assert_reported(self, doc: object, *needles: str) -> None:
        problems = self.problems_for(doc)
        joined = "\n".join(problems)
        for needle in needles:
            self.assertIn(needle, joined, problems)

    def test_absent_file_is_ok(self) -> None:
        self.assertEqual(docs_check.check_ia(self.root), [])

    def test_valid_doc_is_ok(self) -> None:
        self.assertEqual(self.problems_for(ia_doc()), [])

    def test_invalid_json(self) -> None:
        problems = self.problems_for("{")
        self.assertEqual(len(problems), 1)
        self.assertIn("JSON 형식 오류", problems[0])

    def test_top_level_must_be_object(self) -> None:
        self.assert_reported([], "최상위는 객체")

    def test_version_must_be_positive_int(self) -> None:
        for bad in (True, 0, "1"):
            with self.subTest(version=bad):
                self.assert_reported(ia_doc(version=bad), "version")

    def test_missing_screen_key_reported(self) -> None:
        screen = ia_screen()
        del screen["purpose"]
        self.assert_reported(ia_doc(screens=[screen]), "[today]", "purpose")

    def test_wrong_field_type_reported(self) -> None:
        self.assert_reported(ia_doc(screens=[ia_screen(slots="x")]), "[today]", "slots")

    def test_non_object_items_reported(self) -> None:
        self.assert_reported(ia_doc(screens=["x"], tabs=[1], components=[None]), "객체")

    def test_bad_enum_values(self) -> None:
        cases = {
            "modal": ia_screen(presentation="modal"),
            "user": ia_screen(auth="user"),
            "deep": ia_screen(depths=["deep"]),
            "busy": ia_screen(states=[{"id": "busy"}]),
            "server": ia_screen(slots=[{"id": "today.a.b", "source": "server", "role": "r"}]),
        }
        for value, screen in cases.items():
            with self.subTest(value=value):
                self.assert_reported(ia_doc(screens=[screen]), value)

    def test_duplicate_screen_id(self) -> None:
        self.assert_reported(ia_doc(screens=[ia_screen(), ia_screen()]), "화면 id 중복")

    def test_duplicate_slot_id_across_screens(self) -> None:
        other = ia_screen(id="today-x", tab=None, slots=[{"id": "today.fortune.head", "source": "ui", "role": "r"}])
        self.assert_reported(ia_doc(screens=[ia_screen(), other]), "슬롯 id 중복")

    def test_slot_prefix_must_match_screen(self) -> None:
        slots = [{"id": "today-x.a.b", "source": "ui", "role": "r"}]
        self.assert_reported(ia_doc(screens=[ia_screen(slots=slots)]), "화면 id로 시작")

    def test_slot_needs_three_parts(self) -> None:
        slots = [{"id": "today.head", "source": "ui", "role": "r"}]
        self.assert_reported(ia_doc(screens=[ia_screen(slots=slots)]), "슬롯 id 형식")

    def test_unknown_references(self) -> None:
        cases = {
            "nowhere": ia_doc(screens=[ia_screen(exits=[{"to": "nowhere", "trigger": "누름"}])]),
            "nope": ia_doc(screens=[ia_screen(tab="nope")]),
            "lost": ia_doc(tabs=[{"id": "today", "title": "오늘", "root": "lost"}]),
            "ghost": ia_doc(screens=[ia_screen(components=["ghost"])]),
        }
        for value, doc in cases.items():
            with self.subTest(value=value):
                self.assert_reported(doc, value)

    def test_unknown_decision_id(self) -> None:
        self.assert_reported(ia_doc(screens=[ia_screen(decisions=["D999"])]), "D999")

    def test_two_address_slots_reported(self) -> None:
        slots = [
            {"id": "today.fortune.head", "source": "content", "role": "호칭 자리"},
            {"id": "today.fortune.body", "source": "content", "role": "호칭 자리"},
        ]
        self.assert_reported(ia_doc(screens=[ia_screen(slots=slots)]), "호칭 자리")

    def test_unhashable_values_reported_without_crash(self) -> None:
        cases = {
            "depths": ia_doc(screens=[ia_screen(depths=[["x"]])]),
            "states": ia_doc(screens=[ia_screen(states=[{"id": ["x"]}])]),
            "없는 컴포넌트": ia_doc(screens=[ia_screen(components=[{"a": 1}])]),
            "결정 로그에 없는 ID": ia_doc(screens=[ia_screen(decisions=[["D1"]])]),
            "exits": ia_doc(screens=[ia_screen(exits=[{"to": ["x"], "trigger": "누름"}])]),
            "source": ia_doc(screens=[ia_screen(slots=[{"id": "today.a.b", "source": ["ui"], "role": "r"}])]),
            "root": ia_doc(tabs=[{"id": "today", "title": "오늘", "root": ["today"]}]),
        }
        for needle, doc in cases.items():
            with self.subTest(needle=needle):
                self.assert_reported(doc, needle)

    def test_non_utf8_file_reported(self) -> None:
        path = self.root / docs_check.IA_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\xff\xfe{")
        problems = docs_check.check_ia(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("형식 오류", problems[0])

    def test_main_reports_ia_problem(self) -> None:
        self.write_ia("{")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)


IDEAS_HEADER = "| id | 날짜 | 아이디어 | 출처 | 범위 | 수익 | 상태 | 메모 |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n"
IDEAS_NO_TABLE = (
    "docs/ideas.md: 아이디어 표가 없습니다 "
    "(머리: id | 날짜 | 아이디어 | 출처 | 범위 | 수익 | 상태 | 메모)"
)


def idea_row(
    idea_id: str = "I1", source: str = "사용자", scope: str = "Phase 2",
    revenue: str = "유료 후보", status: str = "대기", memo: str = "",
) -> str:
    return f"| {idea_id} | 2026-10-11 | 주간 리포트 | {source} | {scope} | {revenue} | {status} | {memo} |"


def idea_doc(*rows: str) -> str:
    return "# 아이디어 함\n\n" + IDEAS_HEADER + "".join(row + "\n" for row in rows)


class IdeaTests(RepoTestCase):
    def write_ideas(self, *rows: str) -> None:
        write(self.root, "docs/ideas.md", idea_doc(*rows))

    def test_missing_file_is_ok(self) -> None:
        self.assertEqual(docs_check.check_ideas(self.root), [])

    def test_header_only_is_ok(self) -> None:
        self.write_ideas()
        self.assertEqual(docs_check.check_ideas(self.root), [])

    def test_valid_rows_pass(self) -> None:
        write(self.root, "docs/decisions.md", "| D23 | 2026-10-10 | 수익 | x | y |\n")
        write(self.root, "docs/business/cycles/c.md", "# c\n")
        self.write_ideas(
            idea_row("I1"),
            idea_row("I2", status="채택 D23"),
            idea_row("I3", status="검토 docs/business/cycles/c.md", scope="MVP"),
            idea_row("I4", status="보류", revenue="무관", memo="다음 사이클"),
            idea_row("I5", status="기각", revenue="무료", scope="미정", memo="범위 밖"),
            idea_row("I6", source="Issue #4", revenue="미정"),
            idea_row("I7", source="조사"),
        )
        self.assertEqual(docs_check.check_ideas(self.root), [])

    def test_reports_missing_table(self) -> None:
        write(self.root, "docs/ideas.md", "| id | 아이디어 |\n| --- | --- |\n| I1 | x |\n")
        self.assertEqual(docs_check.check_ideas(self.root), [IDEAS_NO_TABLE])

    def test_reports_cell_count(self) -> None:
        self.write_ideas("| I1 | 2026-10-11 | x | 사용자 | MVP | 무관 | 대기 |")
        self.assertEqual(
            docs_check.check_ideas(self.root), ["docs/ideas.md [I1]: 칸 수가 8이 아닙니다 (7)"]
        )

    def test_escaped_pipe_is_one_cell(self) -> None:
        self.write_ideas(idea_row(memo="a \\| b"))
        self.assertEqual(docs_check.check_ideas(self.root), [])

    def test_reports_bad_and_duplicate_id(self) -> None:
        self.write_ideas(idea_row("x1"), idea_row("I1"), idea_row("I1"))
        self.assertEqual(docs_check.check_ideas(self.root), [
            "docs/ideas.md [x1]: id 형식은 I<숫자>입니다",
            "docs/ideas.md [I1]: id 중복",
        ])

    def test_reports_unknown_values(self) -> None:
        self.write_ideas(
            idea_row("I1", source="친구"),
            idea_row("I2", scope="Phase 3"),
            idea_row("I3", revenue="유료"),
        )
        self.assertEqual(docs_check.check_ideas(self.root), [
            "docs/ideas.md [I1]: 출처 값이 아닙니다: 친구",
            "docs/ideas.md [I2]: 범위 값이 아닙니다: Phase 3",
            "docs/ideas.md [I3]: 수익 값이 아닙니다: 유료",
        ])

    def test_reports_malformed_status(self) -> None:
        write(self.root, "docs/decisions.md", "| D23 | 2026-10-10 | 수익 | x | y |\n")
        self.write_ideas(idea_row("I1", status="채택  D23"), idea_row("I2", status="**대기**"))
        self.assertEqual(docs_check.check_ideas(self.root), [
            "docs/ideas.md [I1]: 상태 값이 아닙니다: 채택  D23",
            "docs/ideas.md [I2]: 상태 값이 아닙니다: **대기**",
        ])

    def test_reports_unknown_decision(self) -> None:
        self.write_ideas(idea_row(status="채택 D99"))
        self.assertEqual(docs_check.check_ideas(self.root), ["docs/ideas.md [I1]: 없는 결정: D99"])

    def test_reports_missing_review_doc(self) -> None:
        self.write_ideas(idea_row(status="검토 docs/none.md"))
        self.assertEqual(
            docs_check.check_ideas(self.root), ["docs/ideas.md [I1]: 검토 문서가 없습니다: docs/none.md"]
        )

    def test_rejects_review_path_outside_repo(self) -> None:
        with tempfile.TemporaryDirectory() as outside:
            target = write(Path(outside), "x.md", "# x")
            relative = os.path.relpath(target, self.root)
            self.write_ideas(idea_row("I1", status=f"검토 {relative}"), idea_row("I2", status=f"검토 {target}"))
            self.assertEqual(docs_check.check_ideas(self.root), [
                f"docs/ideas.md [I1]: 검토 문서가 없습니다: {relative}",
                f"docs/ideas.md [I2]: 검토 문서가 없습니다: {target}",
            ])

    def test_empty_last_cell_is_counted(self) -> None:
        self.write_ideas("| I1 | 2026-10-11 | x | 사용자 | MVP | 무관 | 대기 ||")
        self.assertEqual(docs_check.check_ideas(self.root), [])

    def test_header_without_separator_is_not_a_table(self) -> None:
        write(self.root, "docs/ideas.md", IDEAS_HEADER.splitlines()[0] + "\n" + idea_row() + "\n")
        self.assertEqual(docs_check.check_ideas(self.root), [IDEAS_NO_TABLE])

    def test_held_or_rejected_needs_memo(self) -> None:
        self.write_ideas(idea_row("I1", status="보류"), idea_row("I2", status="기각", memo="  "))
        self.assertEqual(docs_check.check_ideas(self.root), [
            "docs/ideas.md [I1]: 보류·기각은 메모에 이유를 적습니다",
            "docs/ideas.md [I2]: 보류·기각은 메모에 이유를 적습니다",
        ])

    def test_reports_bad_date(self) -> None:
        self.write_ideas(idea_row().replace("2026-10-11", "10월 11일"))
        self.assertEqual(
            docs_check.check_ideas(self.root), ["docs/ideas.md [I1]: 날짜 형식은 YYYY-MM-DD입니다: 10월 11일"]
        )

    def test_main_reports_idea_problem(self) -> None:
        self.write_ideas(idea_row(source="친구"))
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)


def ja_source(**overrides: object) -> dict[str, object]:
    source: dict[str, object] = {
        "id": "kotobank-nipponica",
        "kind": "dictionary",
        "publisher": "小学館",
        "title": "日本大百科全書 四柱推命",
        "url": "https://kotobank.jp/word/四柱推命",
        "accessed": "2026-10-15",
    }
    source.update(overrides)
    return source


def ja_term(**overrides: object) -> dict[str, object]:
    term: dict[str, object] = {
        "id": "ten_god.jeongin",
        "ko": "정인",
        "hanja": "正印",
        "glossary_key": None,
        "ja": "印綬",
        "reading": "いんじゅ",
        "aliases": ["正印"],
        "coined": False,
        "evidence": [],
        "confidence": "하",
        "note": "",
    }
    term.update(overrides)
    return term


def evidence(source: str, form: str = "印綬") -> dict[str, str]:
    return {"source": source, "form": form, "quote": f"{form}（いんじゅ）"}


class JaTermTests(RepoTestCase):
    def write_terms(self, sources: list, terms: list, name: str = "ten_gods.json") -> None:
        write(self.root, f"docs/research/ja-terms/{name}", json.dumps({"sources": sources, "terms": terms}))

    def test_two_publishers_with_dictionary_is_high(self) -> None:
        sources = [ja_source(), ja_source(id="app-meishiki", kind="app", publisher="命式表 개발자")]
        term = ja_term(evidence=[evidence("kotobank-nipponica"), evidence("app-meishiki")], confidence="상")
        self.write_terms(sources, [term])
        self.assertEqual(docs_check.check_ja_terms(self.root), [])

    def test_same_publisher_twice_counts_once(self) -> None:
        sources = [ja_source(), ja_source(id="kotobank-daijirin", title="大辞林")]
        term = ja_term(evidence=[evidence("kotobank-nipponica"), evidence("kotobank-daijirin")], confidence="상")
        self.write_terms(sources, [term])
        self.assertEqual(
            docs_check.check_ja_terms(self.root),
            ["docs/research/ja-terms/ten_gods.json: 용어 ten_god.jeongin: confidence는 근거로 계산하면 중입니다 (적힌 값: 상)"],
        )

    def test_two_media_sources_are_medium_and_one_is_low(self) -> None:
        sources = [ja_source(id="m1", kind="media", publisher="A"), ja_source(id="m2", kind="wiki", publisher="B")]
        two = ja_term(evidence=[evidence("m1"), evidence("m2")], confidence="중")
        one = ja_term(id="ten_god.pyeonin", evidence=[evidence("m1")], confidence="하")
        self.write_terms(sources, [two, one])
        self.assertEqual(docs_check.check_ja_terms(self.root), [])

    def test_alias_evidence_does_not_raise_confidence(self) -> None:
        self.write_terms([ja_source()], [ja_term(evidence=[evidence("kotobank-nipponica", "正印")], confidence="하")])
        self.assertEqual(docs_check.check_ja_terms(self.root), [])

    def test_unlisted_form_and_unknown_source_are_reported(self) -> None:
        term = ja_term(evidence=[evidence("kotobank-nipponica", "正官"), evidence("missing")], confidence="하")
        self.write_terms([ja_source()], [term])
        problems = docs_check.check_ja_terms(self.root)
        self.assertIn("docs/research/ja-terms/ten_gods.json: 용어 ten_god.jeongin: 근거 표기 正官이(가) ja나 aliases에 없습니다", problems)
        self.assertIn("docs/research/ja-terms/ten_gods.json: 용어 ten_god.jeongin: 근거 출처 missing가 출처 목록에 없습니다", problems)

    def test_pending_and_coined_terms(self) -> None:
        pending = ja_term(id="ten_god.pyeonin", ja=None, confidence="미정")
        coined = ja_term(id="day_kind.gwiin_day", ja="貴人の日", coined=True, confidence="자체", note="제품 개념")
        no_note = ja_term(id="day_kind.gisin_day", ja="忌神の日", coined=True, confidence="자체", note="")
        self.write_terms([], [pending, coined, no_note])
        self.assertEqual(
            docs_check.check_ja_terms(self.root),
            ["docs/research/ja-terms/ten_gods.json: 용어 day_kind.gisin_day: 자체 용어(coined)는 ja와 note(만든 이유)가 필요합니다"],
        )

    def test_sources_are_shared_across_files_and_ids_unique(self) -> None:
        self.write_terms([ja_source()], [], name="a.json")
        self.write_terms([ja_source()], [ja_term(evidence=[evidence("kotobank-nipponica")], confidence="중")], name="b.json")
        self.assertEqual(
            docs_check.check_ja_terms(self.root),
            ["docs/research/ja-terms/b.json: 출처 kotobank-nipponica: id가 중복입니다"],
        )

    def test_source_fields_are_checked(self) -> None:
        self.write_terms([ja_source(kind="rumor", url="kotobank.jp", accessed="10/15")], [])
        self.assertEqual(
            docs_check.check_ja_terms(self.root),
            [
                "docs/research/ja-terms/ten_gods.json: 출처 kotobank-nipponica: kind는 academic, app, blog, book, dictionary, media, school, software, wiki 중 하나여야 합니다",
                "docs/research/ja-terms/ten_gods.json: 출처 kotobank-nipponica: url이 주소가 아닙니다",
                "docs/research/ja-terms/ten_gods.json: 출처 kotobank-nipponica: accessed는 YYYY-MM-DD입니다",
            ],
        )

    def test_glossary_key_must_exist(self) -> None:
        write(self.root, "docs/identity/writing/slots/content/glossary.yaml", "  keys:\n    - ten_god.jeongin\n")
        self.write_terms([], [ja_term(glossary_key="ten_god.jeongin"), ja_term(id="ten_god.x", glossary_key="ten_god.x")])
        self.assertEqual(
            docs_check.check_ja_terms(self.root),
            ["docs/research/ja-terms/ten_gods.json: 용어 ten_god.x: glossary_key ten_god.x가 docs/identity/writing/slots/content/glossary.yaml에 없습니다"],
        )

    def test_broken_json_is_reported(self) -> None:
        write(self.root, "docs/research/ja-terms/bad.json", "{")
        self.assertEqual(len(docs_check.check_ja_terms(self.root)), 1)


class MainTests(RepoTestCase):
    def test_main_returns_zero_on_clean_repo(self) -> None:
        write(self.root, "a.md", "# a")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 0)

    def test_main_returns_one_on_problem(self) -> None:
        write(self.root, "a.md", "[x](missing.md)")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)


if __name__ == "__main__":
    unittest.main()

"""docs_check의 테스트. 실행: python3 -I -m unittest -q (이 디렉터리에서)"""

import json
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

    def test_main_reports_ia_problem(self) -> None:
        self.write_ia("{")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)


class MainTests(RepoTestCase):
    def test_main_returns_zero_on_clean_repo(self) -> None:
        write(self.root, "a.md", "# a")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 0)

    def test_main_returns_one_on_problem(self) -> None:
        write(self.root, "a.md", "[x](missing.md)")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)


if __name__ == "__main__":
    unittest.main()

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


class MainTests(RepoTestCase):
    def test_main_returns_zero_on_clean_repo(self) -> None:
        write(self.root, "a.md", "# a")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 0)

    def test_main_returns_one_on_problem(self) -> None:
        write(self.root, "a.md", "[x](missing.md)")
        self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)


if __name__ == "__main__":
    unittest.main()

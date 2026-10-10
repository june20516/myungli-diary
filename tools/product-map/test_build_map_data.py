"""build_map_data의 테스트. 실행: python3 -I -m unittest -q (이 디렉터리에서)"""

import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import build_map_data

ROADMAP = """# 통합 로드맵

## 마일스톤

| ID | 마일스톤 | 담당 | 선행 조건 | 끝나면 열리는 것 | 상태 |
| --- | --- | --- | --- | --- | --- |
| R0 | 제품 결정 | 지휘 | - | C1 | **완료** (D1~D34) |
| C1 | 엔진 기반 | core | R0 | C2 | **완료** |
| IA | 화면 목록 | 지휘 | B0 | V2 | 시작 전 |

## 현재 진행 순서 (2026-10-10 기준)

| 순서 | 담당 | 할 일 | 막는 것 |
| --- | --- | --- | --- |
| 1 | 지휘 | 미결 결정 | S1 범위 |
| 병행 | server | S1 설계 | S2 |

## 외부 준비물
"""

DECISIONS = """| ID | 날짜 | 분류 | 결정 | 근거 |
| --- | --- | --- | --- | --- |
| D1 | 2026-10-10 | 목적 | **포트폴리오** 우선 | 사용자 |
| D2 | 2026-10-10 | 엔진 | 자체 구현 | 사용자 |
"""


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


class ParseTests(unittest.TestCase):
    def test_parse_roadmap_milestones(self) -> None:
        milestones = build_map_data.parse_roadmap(ROADMAP)
        self.assertEqual([m["id"] for m in milestones], ["R0", "C1", "IA"])
        self.assertEqual(milestones[1]["owner"], "core")
        self.assertEqual(milestones[1]["requires"], "R0")
        self.assertEqual(milestones[0]["status"], "완료 (D1~D34)")
        self.assertEqual(milestones[2]["state"], "todo")
        self.assertEqual(milestones[0]["state"], "done")

    def test_parse_current_order(self) -> None:
        order = build_map_data.parse_current_order(ROADMAP)
        self.assertEqual(len(order), 2)
        self.assertEqual(order[0], {"step": "1", "owner": "지휘", "task": "미결 결정", "blocks": "S1 범위"})

    def test_parse_decisions(self) -> None:
        decisions = build_map_data.parse_decisions(DECISIONS, "docs/decisions.md")
        self.assertEqual(len(decisions), 2)
        self.assertEqual(decisions[0]["id"], "D1")
        self.assertEqual(decisions[0]["area"], "목적")
        self.assertEqual(decisions[0]["text"], "포트폴리오 우선")
        self.assertEqual(decisions[0]["source"], "docs/decisions.md")


class RepoTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        write(self.root, "docs/roadmap.md", ROADMAP)
        write(self.root, "docs/decisions.md", DECISIONS)
        write(self.root, "core/docs/decisions.md", "| C1 | 2026-10-10 | 시각 | 경도 127.5 | 근거 |\n")
        write(self.root, "docs/identity/README.md", "# 기준\n\n## 컨셉과 포지셔닝\n\n> 오늘 일진을 풀어주는 앱\n\n## 원칙\n\n0. 맥락\n")
        write(self.root, "docs/artifacts/a.png", "png")
        write(self.root, "docs/artifacts/index.json", json.dumps([{"id": "a", "file": "a.png", "status": "chosen"}]))
        write(self.root, "docs/identity/design/artifacts/b.png", "png")
        write(self.root, "docs/identity/design/artifacts/index.json", json.dumps([{"id": "b", "file": "b.png", "status": "draft"}]))

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_collect_artifacts_adds_unit_and_path(self) -> None:
        artifacts = build_map_data.collect_artifacts(self.root)
        by_id = {a["id"]: a for a in artifacts}
        self.assertEqual(by_id["a"]["unit"], "root")
        self.assertEqual(by_id["b"]["unit"], "design")
        self.assertEqual(by_id["b"]["path"], "docs/identity/design/artifacts/b.png")

    def test_collect_issues_without_gh_returns_empty(self) -> None:
        with mock.patch.dict(os.environ, {"PATH": ""}):
            self.assertIsNone(build_map_data.collect_issues(self.root))

    def test_build_uses_provisional_screens_without_ia(self) -> None:
        with mock.patch.object(build_map_data, "collect_issues", return_value=[]):
            data = build_map_data.build(self.root)
        self.assertTrue(data["screens"][0]["provisional"])
        self.assertEqual({d["id"] for d in data["decisions"]}, {"D1", "D2", "C1"})
        self.assertEqual(data["identity"]["concept"], "오늘 일진을 풀어주는 앱")
        self.assertIn("원칙", data["identity"]["sections"])

    def test_collect_screens_reads_object_format(self) -> None:
        doc = {"version": 1, "tabs": [], "components": [], "screens": [{"id": "today", "title": "오늘"}]}
        write(self.root, "docs/ia/screens.json", json.dumps(doc))
        self.assertEqual([s["id"] for s in build_map_data.collect_screens(self.root)], ["today"])

    def test_collect_screens_falls_back_on_malformed(self) -> None:
        write(self.root, "docs/ia/screens.json", "{")
        with contextlib.redirect_stderr(io.StringIO()):
            screens = build_map_data.collect_screens(self.root)
        self.assertTrue(screens[0]["provisional"])

    def test_collect_screens_falls_back_on_non_utf8(self) -> None:
        path = self.root / "docs/ia/screens.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\xff\xfe{")
        with contextlib.redirect_stderr(io.StringIO()):
            screens = build_map_data.collect_screens(self.root)
        self.assertTrue(screens[0]["provisional"])

    def test_build_includes_ia_tabs(self) -> None:
        doc = {"version": 1, "tabs": [{"id": "today", "title": "오늘", "root": "today"}], "components": [], "screens": []}
        write(self.root, "docs/ia/screens.json", json.dumps(doc))
        with mock.patch.object(build_map_data, "collect_issues", return_value=[]):
            data = build_map_data.build(self.root)
        self.assertEqual(data["screen_tabs"], [{"id": "today", "title": "오늘", "root": "today"}])

    def test_build_has_no_ia_tabs_without_ia(self) -> None:
        with mock.patch.object(build_map_data, "collect_issues", return_value=[]):
            data = build_map_data.build(self.root)
        self.assertEqual(data["screen_tabs"], [])

    def test_malformed_index_is_skipped(self) -> None:
        write(self.root, "docs/identity/writing/artifacts/index.json", "{not json")
        write(self.root, "app/docs/artifacts/index.json", json.dumps([{"id": "nofile"}]))
        artifacts = build_map_data.collect_artifacts(self.root)
        self.assertEqual({a["id"] for a in artifacts}, {"a", "b"})

    def test_issues_availability_is_reported(self) -> None:
        with mock.patch.dict(os.environ, {"PATH": ""}), contextlib.redirect_stdout(io.StringIO()):
            data = build_map_data.build(self.root)
        self.assertFalse(data["issues_available"])

    def test_cli_writes_data_and_copies_images(self) -> None:
        out = self.root / "out"
        with mock.patch.object(build_map_data, "collect_issues", return_value=[]):
            with contextlib.redirect_stdout(io.StringIO()):
                code = build_map_data.main(["build", str(self.root), str(out)])
        self.assertEqual(code, 0)
        data = json.loads((out / "data.json").read_text(encoding="utf-8"))
        self.assertEqual(len(data["artifacts"]), 2)
        self.assertTrue((out / "images" / "docs/identity/design/artifacts/b.png").exists())


if __name__ == "__main__":
    unittest.main()

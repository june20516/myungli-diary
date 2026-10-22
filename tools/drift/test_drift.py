"""drift.sh의 테스트. 실행: python3 -I -m unittest -q (이 디렉터리에서)

PATH 앞에 가짜 gh를 두고, 저장소 상태(Issue·PR·커밋 비교)를 JSON 파일로 흉내 냅니다.
"""

import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
DRIFT = HERE / "drift.sh"

# 가짜 gh: drift.sh가 부르는 명령만 흉내 내고, 상태 파일(FAKE_GH_STATE)을 읽고 고칩니다.
FAKE_GH = textwrap.dedent(
    r'''
    #!/usr/bin/env python3
    import json, os, sys

    path = os.environ["FAKE_GH_STATE"]
    state = json.load(open(path, encoding="utf-8"))
    args = sys.argv[1:]

    def opt(name, many=False):
        values = [args[i + 1] for i, a in enumerate(args) if a == name]
        return values if many else (values[0] if values else None)

    def issue(number):
        return next(i for i in state["issues"] if i["number"] == int(number))

    def save():
        json.dump(state, open(path, "w", encoding="utf-8"), ensure_ascii=False)

    if args[:2] == ["label", "create"]:
        pass
    elif args[0] == "api" and "/issues?" in args[1]:
        query = dict(part.split("=", 1) for part in args[1].split("?", 1)[1].split("&"))
        labels = query["labels"].split(",")
        found = [i for i in state["issues"] if i["state"] == "open" and all(l in i["labels"] for l in labels)]
        items = [{"number": i["number"], "title": i["title"], "body": i["body"]} for i in found]
        items += [{"number": p["number"], "title": p["title"], "body": "", "pull_request": {}} for p in state.get("open_prs", [])]
        print(json.dumps(items, ensure_ascii=False))
    elif args[:2] == ["issue", "create"]:
        number = max([i["number"] for i in state["issues"]] + [100]) + 1
        state["issues"].append({"number": number, "title": opt("--title"), "labels": opt("--label").split(","),
                                "body": open(opt("--body-file"), encoding="utf-8").read(), "state": "open", "comments": []})
        save()
    elif args[:2] == ["issue", "edit"]:
        target = issue(args[2])
        if opt("--body-file"):
            target["body"] = open(opt("--body-file"), encoding="utf-8").read()
        for label in opt("--add-label", many=True):
            target["labels"] += [l for l in label.split(",") if l not in target["labels"]]
        save()
    elif args[:2] == ["issue", "comment"]:
        issue(args[2])["comments"].append(opt("--body"))
        save()
    elif args[:2] == ["issue", "close"]:
        target = issue(args[2])
        target["state"] = "closed"
        target["reason"] = opt("--reason") or "completed"
        target["comments"].append(opt("--comment"))
        save()
    elif args[:2] == ["pr", "view"]:
        pr = state["prs"][args[2]]
        print(json.dumps({"state": pr["state"], "mergeCommit": {"oid": pr["merge"]} if pr.get("merge") else None}))
    elif args[0] == "api":
        base_head = args[1].rsplit("/", 1)[1]
        print(json.dumps({"status": state["compare"].get(base_head, "behind")}))
    else:
        sys.exit("모르는 gh 호출: " + " ".join(args))
    '''
).lstrip()

SHA = "main1234567"


def drift_issue(number, unit, pr, body="## 무엇이 필요한가\n본문\n"):
    return {"number": number, "title": f"[drift] {unit}: PR #{pr} 계약 변경 따라잡기", "body": body,
            "labels": ["drift", "kind:request", f"to:{unit}"], "state": "open", "comments": []}


class DriftTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        bin_dir = self.dir / "bin"
        bin_dir.mkdir()
        gh = bin_dir / "gh"
        gh.write_text(FAKE_GH, encoding="utf-8")
        gh.chmod(0o755)
        self.state_path = self.dir / "state.json"
        self.env = {"PATH": f"{bin_dir}:{os.environ['PATH']}", "FAKE_GH_STATE": str(self.state_path),
                    "GH_REPO": "owner/repo", "RUN_URL": "https://run/1"}

    def tearDown(self):
        self.tmp.cleanup()

    def run_drift(self, command, state, **env):
        self.state_path.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
        result = subprocess.run(["bash", str(DRIFT), command], cwd=self.dir, env={**self.env, **env},
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.state_path.read_text(encoding="utf-8"))

    def report(self, state, pr, app="none:skipped", design="none:skipped", contracts="docs/ia/screens.json "):
        return self.run_drift("report", state, PR=str(pr), PR_TITLE=f"제목 {pr}", CONTRACTS=contracts,
                              SERVER="none:skipped", APP=app, WRITING="none:skipped", DESIGN=design)

    def close(self, state, app="success"):
        return self.run_drift("close", state, SHA=SHA, SERVER="skipped", APP=app, WRITING="skipped", DESIGN="skipped")

    @staticmethod
    def by_number(state, number):
        return next(i for i in state["issues"] if i["number"] == number)

    # report

    def test_report_opens_issue_when_unit_has_no_open_drift(self):
        after = self.report({"issues": []}, 411, app="drift:failure")
        self.assertEqual(len(after["issues"]), 1)
        created = after["issues"][0]
        self.assertEqual(created["title"], "[drift] app: PR #411 계약 변경 따라잡기")
        self.assertEqual(created["labels"], ["drift", "kind:request", "to:app", "from:root"])

    def test_report_adds_cause_to_existing_drift_instead_of_opening(self):
        after = self.report({"issues": [drift_issue(412, "app", 411)]}, 419, app="drift:failure",
                            contracts="docs/identity/writing/slots/ui/today.yaml ")
        self.assertEqual(len(after["issues"]), 1)
        existing = self.by_number(after, 412)
        self.assertIn("* 더해진 원인: PR #419(제목 419).", existing["body"])
        self.assertIn("from:writing", existing["labels"])
        self.assertEqual(len(existing["comments"]), 1)
        self.assertIn("PR #419", existing["comments"][0])

    def test_report_adds_to_oldest_when_several_are_open(self):
        state = {"issues": [drift_issue(420, "design", 419), drift_issue(395, "design", 390)]}
        after = self.report(state, 423, design="drift:failure")
        self.assertIn("PR #423(", self.by_number(after, 395)["body"])
        self.assertNotIn("PR #423(", self.by_number(after, 420)["body"])

    def test_report_rerun_of_same_pr_changes_nothing(self):
        body = "본문\n\n* 더해진 원인: PR #419(제목 419). 바뀐 계약 파일: x 실패한 검사: y\n"
        state = {"issues": [drift_issue(412, "app", 411, body), drift_issue(500, "design", 419)]}
        after = self.report(state, 419, app="drift:failure", design="drift:failure")
        self.assertEqual(after["issues"], state["issues"])

    def test_report_ignores_pull_requests_in_issue_list(self):
        state = {"issues": [drift_issue(412, "app", 411)],
                 "open_prs": [{"number": 300, "title": "[drift] app: PR #1 계약 변경 따라잡기"}]}
        after = self.report(state, 419, app="drift:failure")
        self.assertEqual(len(after["issues"]), 1)
        self.assertIn("PR #419(", self.by_number(after, 412)["body"])

    def test_report_success_closes_own_issue(self):
        after = self.report({"issues": [drift_issue(412, "app", 411)]}, 411, app="drift:success")
        self.assertEqual(self.by_number(after, 412)["state"], "closed")

    def test_report_success_keeps_issue_with_added_causes(self):
        body = "본문\n\n* 더해진 원인: PR #419(제목 419). 바뀐 계약 파일: x 실패한 검사: y\n"
        after = self.report({"issues": [drift_issue(412, "app", 411, body)]}, 411, app="drift:success")
        self.assertEqual(self.by_number(after, 412)["state"], "open")

    # close

    def test_close_when_all_causes_are_in_commit(self):
        body = "본문\n\n* 더해진 원인: PR #419(제목). 바뀐 계약 파일: x 실패한 검사: y\n"
        state = {"issues": [drift_issue(412, "app", 411, body)],
                 "prs": {"411": {"state": "MERGED", "merge": "m411"}, "419": {"state": "MERGED", "merge": "m419"}},
                 "compare": {f"m411...{SHA}": "ahead", f"m419...{SHA}": "identical"}}
        closed = self.by_number(self.close(state), 412)
        self.assertEqual(closed["state"], "closed")
        self.assertIn("원인 PR #411 #419 포함", closed["comments"][0])

    def test_close_keeps_issue_while_added_cause_is_open(self):
        body = "본문\n\n* 더해진 원인: PR #419(제목). 바뀐 계약 파일: x 실패한 검사: y\n"
        state = {"issues": [drift_issue(412, "app", 411, body)],
                 "prs": {"411": {"state": "MERGED", "merge": "m411"}, "419": {"state": "OPEN"}},
                 "compare": {f"m411...{SHA}": "ahead"}}
        self.assertEqual(self.by_number(self.close(state), 412)["state"], "open")

    def test_close_keeps_issue_when_cause_merged_after_commit(self):
        state = {"issues": [drift_issue(412, "app", 411)],
                 "prs": {"411": {"state": "MERGED", "merge": "m411"}}, "compare": {f"m411...{SHA}": "behind"}}
        self.assertEqual(self.by_number(self.close(state), 412)["state"], "open")

    def test_close_ignores_added_cause_closed_without_merge(self):
        body = "본문\n\n* 더해진 원인: PR #419(제목). 바뀐 계약 파일: x 실패한 검사: y\n"
        state = {"issues": [drift_issue(412, "app", 411, body)],
                 "prs": {"411": {"state": "MERGED", "merge": "m411"}, "419": {"state": "CLOSED"}},
                 "compare": {f"m411...{SHA}": "ahead"}}
        closed = self.by_number(self.close(state), 412)
        self.assertEqual((closed["state"], closed["reason"]), ("closed", "completed"))
        self.assertIn("원인 PR #411 포함", closed["comments"][0])

    def test_close_not_planned_when_every_cause_closed_without_merge(self):
        state = {"issues": [drift_issue(412, "app", 411)], "prs": {"411": {"state": "CLOSED"}}, "compare": {}}
        closed = self.by_number(self.close(state), 412)
        self.assertEqual((closed["state"], closed["reason"]), ("closed", "not planned"))

    def test_close_does_nothing_when_unit_failed(self):
        state = {"issues": [drift_issue(412, "app", 411)],
                 "prs": {"411": {"state": "MERGED", "merge": "m411"}}, "compare": {f"m411...{SHA}": "ahead"}}
        self.assertEqual(self.by_number(self.close(state, app="failure"), 412)["state"], "open")


if __name__ == "__main__":
    unittest.main()

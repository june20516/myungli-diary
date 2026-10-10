"""제품 지도 데이터 생성: 저장소를 읽어 data.json과 이미지 사본을 만듭니다.

실행: python3 -I tools/product-map/build_map_data.py <저장소 루트> <출력 디렉터리>
설계: docs/specs/2026-10-10-collab-workflow-design.md §7 (D45)
"""

import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SKIPPED_DIRS = {".git", ".suberpowers", ".venv", "node_modules"}
DECISION_LOGS = (
    "docs/decisions.md",
    "core/docs/decisions.md",
    "server/docs/decisions.md",
    "app/docs/decisions.md",
    "docs/identity/writing/decisions.md",
    "docs/identity/design/decisions.md",
)
IA_PATH = "docs/ia/screens.json"
ARTIFACT_UNITS = (
    ("docs/identity/design/", "design"),
    ("docs/identity/writing/", "writing"),
    ("app/", "app"),
    ("docs/", "root"),
)
# IA 파일이 없거나 깨졌을 때 쓰는 MVP 임시 화면 목록 (04 MVP 명세, D16·D18·D22·D36)
PROVISIONAL_SCREENS = (
    ("onboarding", "온보딩", "생년월일시·음력·시간 모름·성별·호칭 입력, 소셜 로그인"),
    ("daily", "데일리", "날의 성격, 총운 문장, 행운 색·방향·숫자·집중 시간, 해시태그"),
    ("my-saju", "나의 사주", "일간 소개·용신(surface), 원국표·대운·세운(evidence)"),
    ("calendar", "캘린더", "월간 길흉 점, 음력 날짜, 절기"),
    ("diary", "일기", "가이드 질문, 작성, 해시태그 칩"),
    ("settings", "설정", "기본 깊이, 알림, 언어, 계산 기준 안내"),
)


def _table_rows(text: str) -> list[list[str]]:
    rows = []
    for line in text.splitlines():
        if not line.startswith("|") or set(line.replace("|", "").strip()) <= {"-", " "}:
            continue
        rows.append([cell.strip() for cell in line.strip().strip("|").split("|")])
    return rows


def _plain(text: str) -> str:
    return re.sub(r"\*\*(.+?)\*\*", r"\1", text).strip()


def _section(text: str, heading_prefix: str) -> str:
    match = re.search(rf"^## {re.escape(heading_prefix)}.*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return match.group(1) if match else ""


def _state(status: str) -> str:
    if "완료" in status:
        return "done"
    if "진행" in status:
        return "doing"
    return "todo"


def parse_roadmap(text: str) -> list[dict[str, str]]:
    milestones = []
    for row in _table_rows(_section(text, "마일스톤"))[1:]:
        if len(row) < 6:
            continue
        status = _plain(row[5])
        milestones.append({
            "id": row[0], "title": _plain(row[1]), "owner": row[2],
            "requires": row[3], "unlocks": row[4], "status": status, "state": _state(status),
        })
    return milestones


def parse_current_order(text: str) -> list[dict[str, str]]:
    order = []
    for row in _table_rows(_section(text, "현재 진행 순서"))[1:]:
        if len(row) >= 4:
            order.append({"step": row[0], "owner": row[1], "task": _plain(row[2]), "blocks": row[3]})
    return order


def parse_decisions(text: str, source: str) -> list[dict[str, str]]:
    decisions = []
    for row in _table_rows(text):
        if len(row) >= 4 and re.fullmatch(r"[DCSAWV]\d+", row[0]):
            decisions.append({
                "id": row[0], "date": row[1], "area": row[2],
                "text": _plain(row[3]), "source": source,
            })
    return decisions


def parse_identity(text: str) -> dict[str, object]:
    sections = {
        match.group(1).strip(): match.group(2).strip()
        for match in re.finditer(r"^## (.+?)$(.*?)(?=^## |\Z)", text, re.M | re.S)
    }
    concept = re.search(r"^> (.+)$", sections.get("컨셉과 포지셔닝", ""), re.M)
    return {"concept": concept.group(1).strip() if concept else "", "sections": sections}


def _unit_of(relative: str) -> str:
    return next((unit for prefix, unit in ARTIFACT_UNITS if relative.startswith(prefix)), "root")


def collect_artifacts(root: Path) -> list[dict[str, object]]:
    artifacts = []
    for index in sorted(root.rglob("artifacts/index.json")):
        if SKIPPED_DIRS.intersection(index.relative_to(root).parts):
            continue
        directory = index.parent.relative_to(root).as_posix()
        try:
            entries = json.loads(index.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            print(f"건너뜀: {directory}/index.json JSON 형식 오류", file=sys.stderr)
            continue
        for entry in entries if isinstance(entries, list) else []:
            if not isinstance(entry, dict) or not isinstance(entry.get("file"), str):
                print(f"건너뜀: {directory}/index.json의 file 없는 항목", file=sys.stderr)
                continue
            item = dict(entry)
            item["unit"] = _unit_of(directory + "/")
            item["path"] = f"{directory}/{entry['file']}"
            artifacts.append(item)
    return artifacts


def collect_issues(root: Path) -> list[dict[str, object]] | None:
    """열린 Issue 목록. gh가 없거나 실패하면 None(0건과 구분)."""
    command = ["gh", "issue", "list", "--state", "open", "--limit", "200",
               "--json", "number,title,labels,milestone,url"]
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    return [
        {
            "number": issue["number"], "title": issue["title"], "url": issue.get("url", ""),
            "labels": [label["name"] for label in issue.get("labels", [])],
            "milestone": (issue.get("milestone") or {}).get("title", ""),
        }
        for issue in json.loads(result.stdout or "[]")
    ]


def collect_screens(root: Path) -> list[dict[str, object]]:
    ia = root / IA_PATH
    if ia.exists():
        try:
            doc = json.loads(ia.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            doc = None
        if isinstance(doc, dict) and isinstance(doc.get("screens"), list):
            return doc["screens"]
        print(f"건너뜀: {IA_PATH} 형식 오류, 임시 화면 목록을 씁니다", file=sys.stderr)
    return [
        {"id": sid, "title": title, "summary": summary, "provisional": True}
        for sid, title, summary in PROVISIONAL_SCREENS
    ]


def _read(root: Path, relative: str) -> str:
    path = root / relative
    return path.read_text(encoding="utf-8") if path.exists() else ""


def build(root: Path) -> dict[str, object]:
    roadmap = _read(root, "docs/roadmap.md")
    issues = collect_issues(root)
    decisions = [
        decision
        for log in DECISION_LOGS
        for decision in parse_decisions(_read(root, log), log)
    ]
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "milestones": parse_roadmap(roadmap),
        "current_order": parse_current_order(roadmap),
        "identity": parse_identity(_read(root, "docs/identity/README.md")),
        "screens": collect_screens(root),
        "artifacts": collect_artifacts(root),
        "decisions": decisions,
        "issues": issues or [],
        "issues_available": issues is not None,
    }


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("사용법: build_map_data.py <저장소 루트> <출력 디렉터리>")
        return 2
    root, out = Path(argv[1]), Path(argv[2])
    data = build(root)
    out.mkdir(parents=True, exist_ok=True)
    (out / "data.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for artifact in data["artifacts"]:
        source = root / str(artifact["path"])
        if source.exists():
            target = out / "images" / str(artifact["path"])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    print(f"data.json: 마일스톤 {len(data['milestones'])}, 산출물 {len(data['artifacts'])}, "
          f"결정 {len(data['decisions'])}, Issue {len(data['issues'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

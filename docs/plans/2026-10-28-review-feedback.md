# 검수 피드백 워크플로 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 검수 피드백을 원요청 → 피드백 항목 → 단위 작업 Issue로 나르는 절차를 문서, 대장, 라벨, 자동 검사로 갖춥니다.

**Architecture:** 원요청과 스크린샷은 비공개 내부 저장소 `review/`, 피드백 항목은 공개 저장소 `docs/review/items.md` 대장 하나, 작업은 단위 `kind:request` Issue입니다. 루트 docs 검사(`tools/docs-check/docs_check.py`)에 대장 검사 `check_review_items`를 더해 CI(`ci-gate` docs 단계)가 지킵니다.

**Tech Stack:** Python 3 표준 라이브러리(`unittest`), GitHub CLI(`gh`), 마크다운

**Spec:** `docs/specs/2026-10-28-review-feedback-design.md`

## Global Constraints

* 공개 저장소(D74): 대장과 Issue에 개인 정보(생년월일, 사주 값, 일기 본문, 실명)와 가격 같은 내부 정보를 적지 않습니다. 내부 저장소는 링크하지 않고 "비공개 기록 `review/inbox/<파일>` #<n>"으로만 적습니다.
* 대장 표 머리(정확히 이 순서): `번호 | 화면 | 문제 | 바라는 것 | 심각도 | 상태 | 원요청 | 작업`
* 번호 형식 `F-<세 자리 숫자>`(예 `F-001`), 심각도 `S1`, `S2`, `S3`
* 상태 값 일곱: `받음`, `확인 중`, `보냄`, `끝남`, `보류`, `합침`, `버림`
* 라벨: `review`, `sev:1`, `sev:2`, `sev:3`
* 작업 문서와 커밋은 한국어 경어체, 사용자에게 보이는 글이 아니라 D93 금지 글자 규칙 밖이지만 새 문서도 긴 대시와 가운뎃점을 쓰지 않습니다.
* 검사 실행: `python3 -I tools/docs-check/docs_check.py .`, 테스트: `cd tools/docs-check && python3 -I -m unittest -q`

## Review Focus

1. `합침` 항목이 자기 자신이나 대장에 없는 번호를 가리킬 때: 오류로 알려야 합니다(자기 자신은 "합침 대상이 자기 자신입니다").
2. `합침`이 뒤에 나오는 번호를 가리킬 때: 표 전체 번호를 먼저 모은 뒤 대조하므로 통과해야 합니다.
3. 문제 칸에 `\|`(이스케이프한 파이프)가 들어 있을 때: 칸 수를 잘못 세지 않아야 합니다.
4. `보냄`, `끝남`인데 작업 칸에 `#<숫자>`가 없을 때(예 "Issue 열 예정"): 오류여야 합니다. `받음`, `확인 중`, `보류`, `버림`은 작업 칸이 비어도 됩니다.
5. `docs/review/items.md` 파일이 없을 때: 검사는 빈 목록을 돌려줘야 합니다(아이디어 함과 같음). 파일은 있는데 표 머리가 다르면 "피드백 항목 표가 없습니다"를 알립니다.

---

### Task 1: docs 검사에 피드백 항목 대장 검사

**Files:**
- Modify: `tools/docs-check/docs_check.py` (표 읽기 공용화, 상수, `check_review_items`, `main`)
- Test: `tools/docs-check/test_docs_check.py` (새 `ReviewItemTests(RepoTestCase)`)

**Interfaces:**
- Produces:
  - `_table_rows(text: str, columns: tuple[str, ...]) -> list[list[str]] | None`: 머리가 `columns`이고 바로 다음 줄이 구분선(`TABLE_SEPARATOR`)인 첫 표의 데이터 행. 기존 `_idea_rows(text)`는 `_table_rows(text, IDEA_COLUMNS)`를 부르도록 바꿉니다(아이디어 테스트는 그대로 통과).
  - 상수 `REVIEW_ITEMS_PATH = "docs/review/items.md"`, `REVIEW_COLUMNS`(Global Constraints의 여덟 칸 튜플), `REVIEW_STATUSES`(일곱 값 집합), `REVIEW_SEVERITIES = {"S1", "S2", "S3"}`, `REVIEW_ID_PATTERN = re.compile(r"F-\d{3}")`, `REVIEW_ISSUE_PATTERN = re.compile(r"#\d+")`, `REVIEW_MERGE_PATTERN = re.compile(r"→ (F-\d{3})")`
  - `check_review_items(root: Path) -> list[str]`: 오류 문구 형식 `docs/review/items.md [<번호 칸 값>]: <이유>`. 파일이 없으면 `[]`, 표가 없으면 `["docs/review/items.md: 피드백 항목 표가 없습니다 (머리: <REVIEW_COLUMNS를 ' | '로 이은 것>)"]`.
  - `main`이 `check_review_items(root)`를 더합니다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test_docs_check.py`에 `REVIEW_HEADER`(머리와 구분선 두 줄), 행을 만드는 `review_row(item_id="F-001", screen="today", problem="잘림", want="", severity="S2", status="받음", source="비공개 기록 `review/inbox/2026-11-02.md` #1", tasks="")`, `write_items(*rows)`를 두고 `ReviewItemTests`에 다음을 씁니다.

```python
def test_missing_file_is_ok(self):
    self.assertEqual(docs_check.check_review_items(self.root), [])

def test_valid_rows_pass(self):
    self.write_items(review_row(), review_row("F-002", status="보냄", tasks="#701, #702"),
                     review_row("F-003", status="합침", tasks="→ F-004"), review_row("F-004"))
    self.assertEqual(docs_check.check_review_items(self.root), [])

def test_bad_id_and_duplicate(self):
    self.write_items(review_row("F-1"), review_row("F-002"), review_row("F-002"))
    self.assertEqual(docs_check.check_review_items(self.root), [
        "docs/review/items.md [F-1]: 번호 형식은 F-<세 자리>입니다",
        "docs/review/items.md [F-002]: 번호 중복",
    ])

def test_bad_status_and_severity(self):
    self.write_items(review_row(status="진행"), review_row("F-002", severity="높음"))
    self.assertEqual(docs_check.check_review_items(self.root), [
        "docs/review/items.md [F-001]: 상태 값이 아닙니다: 진행",
        "docs/review/items.md [F-002]: 심각도 값이 아닙니다: 높음",
    ])

def test_sent_or_done_needs_issue(self):
    self.write_items(review_row(status="보냄", tasks="Issue 열 예정"), review_row("F-002", status="끝남"))
    self.assertEqual(docs_check.check_review_items(self.root), [
        "docs/review/items.md [F-001]: 보냄과 끝남은 작업 칸에 Issue 번호가 있어야 합니다",
        "docs/review/items.md [F-002]: 보냄과 끝남은 작업 칸에 Issue 번호가 있어야 합니다",
    ])

def test_merged_target(self):
    self.write_items(review_row(status="합침", tasks="→ F-009"), review_row("F-002", status="합침", tasks="→ F-002"),
                     review_row("F-003", status="합침", tasks="F-001"))
    self.assertEqual(docs_check.check_review_items(self.root), [
        "docs/review/items.md [F-001]: 합침 대상이 대장에 없습니다: F-009",
        "docs/review/items.md [F-002]: 합침 대상이 자기 자신입니다",
        "docs/review/items.md [F-003]: 합침은 작업 칸에 → F-<번호>를 적습니다",
    ])

def test_escaped_pipe_in_problem(self):
    self.write_items(review_row(problem="a \\| b"))
    self.assertEqual(docs_check.check_review_items(self.root), [])

def test_wrong_header_is_reported(self):
    write(self.root, "docs/review/items.md", "| 번호 | 화면 |\n| --- | --- |\n")
    self.assertEqual(len(docs_check.check_review_items(self.root)), 1)
    self.assertIn("피드백 항목 표가 없습니다", docs_check.check_review_items(self.root)[0])

def test_wrong_cell_count(self):
    self.write_items("| F-001 | today | 잘림 |")
    self.assertEqual(docs_check.check_review_items(self.root),
                     ["docs/review/items.md [F-001]: 칸 수가 8이 아닙니다 (3)"])

def test_main_reports_review_problem(self):
    self.write_items(review_row(status="진행"))
    self.assertEqual(docs_check.main(["docs_check", str(self.root)]), 1)
```

- [ ] **Step 2: 테스트를 실행하여 실패를 확인**

Run: `cd tools/docs-check && python3 -I -m unittest -q test_docs_check.ReviewItemTests`
Expected: FAIL (`AttributeError: module 'docs_check' has no attribute 'check_review_items'`)

- [ ] **Step 3: `docs_check.py`에 위 Interfaces 구현**

`check_review_items`는 두 번 훑습니다. 첫 번째로 형식이 맞는 번호를 모두 모으고, 두 번째로 행마다 검사합니다(합침 대상 대조에 첫 번째 결과를 씀). 한 행에 여러 문제가 있으면 위 테스트 순서(칸 수 → 번호 → 심각도 → 상태 → 작업 칸)대로 모두 알립니다. 칸 수가 틀리면 그 행은 그것만 알립니다.

- [ ] **Step 4: 테스트를 실행하여 통과를 확인**

Run: `cd tools/docs-check && python3 -I -m unittest -q`
Expected: 전체 통과(기존 아이디어 테스트 포함)

- [ ] **Step 5: Commit**

```bash
git add tools/docs-check/docs_check.py tools/docs-check/test_docs_check.py
git commit -m "feat(docs-check): 검수 피드백 항목 대장 검사"
```

### Task 2: 공개 저장소 문서와 대장

**Files:**
- Create: `docs/review/README.md`, `docs/review/items.md`
- Modify: `docs/workflow.md`(§5.3 뒤에 §5.4), 루트 `CLAUDE.md`(지휘 세션 정기 일과 1번 목록), `docs/specs/2026-10-28-review-feedback-design.md`(상태 줄)

**Interfaces:**
- Consumes: Task 1의 `check_review_items`(대장 형식이 이것을 통과해야 함)

- [ ] **Step 1: `docs/review/items.md` 작성**: 제목 `# 검수 피드백 항목 대장`, 한 줄 설명(절차는 `README.md`), 상태 값과 심각도 뜻 한 줄씩, 그리고 Global Constraints의 머리와 구분선만 있는 빈 표.
- [ ] **Step 2: `docs/review/README.md` 작성**: spec §2 용어 표, §3 흐름 여섯 단계, §4 저장 위치 표, §5.1 확인 대상 넷, §6.1 단위 배정 표, §6.2 작업 Issue 라벨, 제목, 본문, §6.3 처리 순서를 요약하고 spec 경로를 적습니다. 원요청 위치는 "비공개 내부 저장소 `review/`"로만 적습니다.
- [ ] **Step 3: `docs/workflow.md`에 `### 5.4. 검수 피드백` 추가**: 세 줄. ① 검수와 폴리싱 피드백은 지휘가 받아 `docs/review/items.md`의 항목으로 정리하고 단위 작업 Issue(`review`, `sev:<n>`)로 보낸다(절차 `docs/review/README.md`) ② 단위의 할 일 순서는 drift → `sev:1` → 로드맵 일 → `sev:2` → `sev:3` ③ 단위가 동의하지 않으면 고치지 않고 작업 Issue에 이유를 코멘트한다.
- [ ] **Step 4: 루트 `CLAUDE.md` 정기 일과 1번에 한 줄 추가**: "열린 검수 피드백 항목(`docs/review/items.md`의 `보냄`)의 작업 Issue가 모두 닫혔으면 `끝남`으로 바꿉니다(`docs/review/README.md`)."
- [ ] **Step 5: spec 상태 줄을 `* 상태: 승인 (2026-10-28)`으로 바꿈**
- [ ] **Step 6: 검사**

Run: `python3 -I tools/docs-check/docs_check.py .`
Expected: `OK: docs 검사 통과`

- [ ] **Step 7: Commit**

```bash
git add docs/review docs/workflow.md CLAUDE.md docs/specs/2026-10-28-review-feedback-design.md
git commit -m "docs(review): 검수 피드백 대장과 절차, workflow §5.4"
```

### Task 3: GitHub 라벨

- [ ] **Step 1: 라벨 만들기**

```bash
gh label create review --description "검수 피드백 작업 (docs/review)" --color 5319E7
gh label create sev:1 --description "검수 심각도 S1 막힘" --color B60205
gh label create sev:2 --description "검수 심각도 S2 불편" --color D93F0B
gh label create sev:3 --description "검수 심각도 S3 다듬기" --color FBCA04
```

- [ ] **Step 2: 확인**

Run: `gh label list --search sev; gh label list --search review`
Expected: 네 라벨이 모두 보임

### Task 4: 내부 저장소 `review/`

**Files (저장소 `../myungli-diary-internal`):**
- Create: `review/README.md`, `review/inbox/.gitkeep`, `review/shots/.gitkeep`

- [ ] **Step 1: 브랜치**: `git -C ../myungli-diary-internal switch --no-track -c root/review-inbox origin/main` 뒤 `git status -sb`로 upstream이 없는지 확인
- [ ] **Step 2: `review/README.md` 작성**: 원요청 파일 이름(수시 `<날짜>.md`, 회차 `<날짜>-회차<n>.md`), 파일 안 `## #<n>` 머리 아래 원문 그대로와 스크린샷 경로, 스크린샷은 `shots/<날짜>/`, 공개 대장은 공개 저장소 `docs/review/items.md`라는 것과 개인 정보는 공개 쪽에 옮기지 않는다는 규칙
- [ ] **Step 3: Commit, push, PR, 병합**

```bash
git -C ../myungli-diary-internal add review
git -C ../myungli-diary-internal commit -m "docs: 검수 원요청 보관소 review/"
git -C ../myungli-diary-internal push -u origin root/review-inbox
gh pr create -R june20516/myungli-diary-internal --base main --head root/review-inbox --title "docs: 검수 원요청 보관소 review/" --body "공개 저장소 spec docs/specs/2026-10-28-review-feedback-design.md §4의 비공개 보관소"
gh pr merge -R june20516/myungli-diary-internal --merge --delete-branch
```

### Task 5: 공개 저장소 PR과 병합

- [ ] **Step 1: 전체 검사**: `cd tools/docs-check && python3 -I -m unittest -q`와 `python3 -I tools/docs-check/docs_check.py .` 둘 다 통과
- [ ] **Step 2: push와 PR**: 브랜치 `root/review-feedback`, 본문에 spec 경로와 바뀐 것(Task 1~4), `처리한 Issue: 없음`
- [ ] **Step 3: `ci-gate` 통과 뒤 지휘가 병합**(루트 `CLAUDE.md` 병합 규칙)

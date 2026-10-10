# 협업 워크플로·CI 기반·제품 지도 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** `ci-gate`·docs 검사·PR/Issue 양식·라벨·마일스톤을 갖추고, 요청함을 GitHub Issues로 옮기고, 규약 문서를 고치고, 제품 지도 첫 판을 publish합니다.

**Architecture:** docs 검사와 지도 생성은 Python 표준 라이브러리 스크립트(`tools/`)이고 `unittest`로 TDD합니다. `ci-gate`는 경로 판별 job과 docs job, 그리고 판정 job으로 이루어진 workflow 하나입니다. 저장소 설정(라벨·마일스톤·Issue)은 `gh`로 만듭니다. 지도는 생성 스크립트가 만든 `data.json`을 읽는 HTML 한 장을 Artifact로 publish합니다.

**Tech Stack:** Python 3.13 표준 라이브러리, GitHub Actions, `gh` CLI, claude.ai Artifact

**Spec:** `docs/specs/2026-10-10-collab-workflow-design.md` (D43~D45)

## Global Constraints

* 작업 위치: worktree `/Users/bran/personal/myungli-diary-root`, 브랜치 `root/collab-workflow`. 원래 checkout과 writing·design worktree는 건드리지 않습니다.
* 고치는 곳은 지휘 소유 경로와 이 spec §8이 지휘에게 맡긴 각 `CLAUDE.md`뿐입니다. `core/` 코드와 `.github/workflows/core.yml`은 고치지 않습니다.
* `tools/` 스크립트는 외부 패키지 없이 Python 표준 라이브러리만 씁니다. 실행은 `python3 -I`.
* 필수 검사 이름은 정확히 `ci-gate`입니다(workflow 이름과 판정 job 이름).
* 라벨 이름: `from:root`·`from:core`·`from:server`·`from:app`·`from:writing`·`from:design`, 같은 여섯 개의 `to:`, `kind:request`·`kind:report`·`kind:notice`·`kind:task`, `blocking`, `accepted`, `rejected`.
* 마일스톤 제목: `B0`, `IA`, `W0`, `V0`, `V1`, `V2`, `S1`, `S2`, `S3`, `A1`, `A2`, `W1`, `I1`, `I2`, `I3`, `I4`. B0는 만든 뒤 닫습니다(완료).
* `artifacts/index.json` 필드와 값은 `docs/workflow.md` §7 그대로입니다. `kind` ∈ {concept, mockup, component, screenshot, token-sheet, copy-sample}, `status` ∈ {draft, chosen, rejected, superseded}.
* 결정 번호 형식: `| <접두어><숫자> |`로 시작하는 표 행. 접두어 D(루트), C·S·A(서브 프로젝트), W·V(작업 단위).
* commit 범위 `docs(root):`·`ci(root):`·`feat(root):`, 끝에 세션 attribution 두 줄.
* 저장소 설정 변경(라벨·마일스톤·Issue 생성)은 이 plan 승인으로 허용된 범위만 합니다. 병합은 PR로 하며, 병합 전에 사용자에게 확인합니다.

## Review Focus

1. 경로 필터 때문에 `ci-gate`가 아예 실행되지 않거나 "대기"에 멈추는 경우 → 어떤 PR이든 `ci-gate` 판정 job은 항상 돌아 성공·실패 중 하나를 내야 합니다(Task 2 검증 PR 두 종류).
2. 이미 진행 중인 writing·design 세션이 안내받은 `docs/coordination/` 파일 경로가 사라지는 경우 → 열린 문서는 옮기지 않고 맨 위에 Issue 링크만 답니다(Task 4).
3. `index.json`이 가리키는 이미지가 없거나 필드 값이 틀린 경우 → docs 검사가 파일 이름과 필드를 짚어 실패해야 합니다(Task 1).
4. 결정 표에서 같은 번호가 두 번 나오는 경우(예: D41 두 행) → docs 검사가 실패해야 합니다. 다른 접두어끼리 같은 숫자(C1과 D1)는 정상입니다(Task 1).
5. 지도 생성 시 IA가 아직 없거나 `gh` 인증이 없을 때 → 생성이 실패하지 않고 해당 영역을 "없음"으로 채워야 합니다(Task 6).

---

### Task 1: docs 검사 스크립트

**Files:**
- Create: `tools/docs-check/docs_check.py`
- Create: `tools/docs-check/test_docs_check.py`

**Interfaces:**
- Produces:
  - `check_links(root: Path) -> list[str]` — 상대 링크가 가리키는 파일이 없으면 `"<md 경로>: <대상>"`. `.git`, `.suberpowers`, `.venv`, `node_modules` 아래는 건너뜁니다.
  - `check_artifacts(root: Path) -> list[str]` — 모든 `**/artifacts/index.json`. 필수 필드 누락, `kind`·`status` 값 오류, `file`(과 있으면 `source`) 파일 없음, 같은 index 안 `id` 중복을 `"<index 경로> [<id>]: <사유>"`로.
  - `check_decision_ids(root: Path) -> list[str]` — `docs/decisions.md`와 모든 `**/decisions.md`에서 `^\| ([DCSAWV]\d+) \|` 행의 같은 번호 중복을 `"<파일>: <번호> 중복"`으로.
  - `main(argv: list[str]) -> int` — 세 검사를 저장소 루트(`argv[1]`, 없으면 cwd)에 돌려 문제를 출력하고 하나라도 있으면 1, 없으면 `OK: docs 검사 통과`를 출력하고 0.

- [ ] **Step 1: 실패하는 테스트 작성** (`unittest`, 각 테스트가 `tempfile.TemporaryDirectory`에 최소 저장소를 만듦)

```python
class LinkTests(unittest.TestCase):
    def test_reports_missing_relative_target(self): ...  # a.md에 [x](missing.md) → ["a.md: missing.md"]
    def test_ignores_urls_and_anchors(self): ...         # [x](https://e.com), [y](b.md#sec) with b.md 존재 → []
    def test_skips_suberpowers_dir(self): ...            # .suberpowers/x.md의 깨진 링크 → []

class ArtifactTests(unittest.TestCase):
    def test_valid_index_passes(self): ...               # 필드 완비, file 존재 → []
    def test_missing_file_reported(self): ...            # file 없음 → 메시지에 id와 "파일 없음"
    def test_bad_status_reported(self): ...              # status "final" → 메시지에 "status"
    def test_duplicate_id_reported(self): ...

class DecisionTests(unittest.TestCase):
    def test_duplicate_number_reported(self): ...        # "| D41 |" 두 행 → ["docs/decisions.md: D41 중복"]
    def test_same_number_other_prefix_ok(self): ...      # D1과 C1 → []

class MainTests(unittest.TestCase):
    def test_main_returns_zero_on_clean_repo(self): ...
```

- [ ] **Step 2: 실패 확인** — Run: `cd tools/docs-check && python3 -I -m unittest -q` → Expected: `ModuleNotFoundError: docs_check` 또는 FAIL

- [ ] **Step 3: `docs_check.py` 구현** — 링크 정규식은 `\]\(([^)#\s]+)(?:#[^)]*)?\)`, `[a-z]+://`와 `mailto:`는 건너뜀.

- [ ] **Step 4: 통과 확인** — Run: `cd tools/docs-check && python3 -I -m unittest -q` → Expected: `OK`

- [ ] **Step 5: 실제 저장소에 실행** — Run: `python3 -I tools/docs-check/docs_check.py .` → Expected: `OK: docs 검사 통과`. 실패하면 저장소 문서를 고칩니다(스크립트를 느슨하게 만들지 않음).

- [ ] **Step 6: Commit** — `feat(root): docs 검사 스크립트(링크·artifacts·결정 번호)`

### Task 2: `ci-gate` workflow와 PR 템플릿

**Files:**
- Create: `.github/workflows/ci-gate.yml`
- Create: `.github/pull_request_template.md`

**Interfaces:**
- Consumes: Task 1의 `tools/docs-check/docs_check.py`
- Produces: 필수 검사 이름 `ci-gate`

- [ ] **Step 1: `ci-gate.yml` 작성**
  * 트리거: `pull_request`(모든 경로), `push` to `main`, `workflow_dispatch`. `concurrency: { group: ci-gate-${{ github.ref }}, cancel-in-progress: true }`. `permissions: contents: read`.
  * job `changes`: `actions/checkout@v4`(`fetch-depth: 0`) 후 `git diff --name-only <base>...HEAD`(PR은 `github.event.pull_request.base.sha`, push는 `github.event.before`)로 출력 `docs`(`.md`, `artifacts/`, `decisions.md`, `tools/docs-check/` 중 하나라도) 계산. 외부 action 대신 셸로 판별합니다.
  * job `docs`: `needs: changes`, `if: needs.changes.outputs.docs == 'true'`. `actions/setup-python@v5`(3.13) → `python3 -I -m unittest -q`(tools/docs-check) → `python3 -I tools/docs-check/docs_check.py .`
  * job `ci-gate`: `needs: [changes, docs]`, `if: always()`. 각 needs의 `result`가 `success` 또는 `skipped`면 성공, 그 밖(`failure`·`cancelled`)이면 `exit 1`.
  * 파일 맨 위 주석: 새 단위 검사를 붙이는 방법(spec §4.1-3 전환 규칙)과 "필수 검사 이름은 ci-gate".
- [ ] **Step 2: PR 템플릿 작성** — 절: 단위, 관련 Issue·결정, 바꾼 계약(계약 PR 여부), 스크린샷(`artifacts/` id), 확인 방법, 세션 마무리 체크리스트(spec §6 다섯 항목) 체크박스.
- [ ] **Step 3: YAML 문법 확인** — Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-gate.yml"); puts "yaml OK"'` → Expected: `yaml OK`
- [ ] **Step 4: Commit 후 push, 검증 PR** — `ci(root): ci-gate workflow와 PR 템플릿`. `git push -u origin root/collab-workflow` 후 `gh pr create --draft`(본문은 템플릿). Run: `gh pr checks --watch` → Expected: `ci-gate` pass, `docs` pass.
- [ ] **Step 5: 경로 필터 회귀 확인 (Review Focus 1)** — 같은 PR에 문서가 아닌 파일만 바꾸는 임시 commit을 올리지 않고, 대신 `workflow_dispatch`로 `ci-gate`를 실행해 `docs`가 `skipped`일 때도 `ci-gate`가 pass인지 확인: `gh workflow run ci-gate.yml --ref root/collab-workflow` → Expected: `ci-gate` success, `docs` skipped(dispatch에는 diff 기준이 없으므로 `changes`가 `docs=false`를 내도록 구현).

### Task 3: 라벨·마일스톤·Issue 양식

**Files:**
- Create: `.github/ISSUE_TEMPLATE/request.yml`, `report.yml`, `notice.yml`, `task.yml`, `config.yml`
- Create: `tools/github-setup/setup_repo.sh`

**Interfaces:**
- Produces: 라벨·마일스톤(Global Constraints 이름), Issue 양식 4종

- [ ] **Step 1: 양식 작성** — 각 양식 필드: 보내는 쪽·받는 쪽(dropdown 6개 단위), 무엇이 필요한가/무엇을 했는가, 왜, 영향, 관련(결정·계약·마일스톤). 양식마다 `labels: ["kind:<종류>"]`. `config.yml`에 `blank_issues_enabled: true`.
- [ ] **Step 2: `setup_repo.sh` 작성** — `gh label create ... --force`로 라벨을 만들고(색: from 계열 회색, to 계열 파랑, kind 계열 초록, `blocking` 빨강, `accepted`·`rejected` 보라·검정), `gh api repos/{owner}/{repo}/milestones`로 없는 마일스톤만 만듭니다(다시 실행해도 같은 결과). B0는 `state=closed`.
- [ ] **Step 3: 실행과 확인** — Run: `bash tools/github-setup/setup_repo.sh && gh label list --limit 100 | wc -l && gh api 'repos/june20516/myungli-diary/milestones?state=all' -q 'length'` → Expected: 라벨 17 이상(GitHub 기본 라벨 포함 가능), 마일스톤 `16`. 한 번 더 실행해도 마일스톤 수 `16` 유지.
- [ ] **Step 4: Commit** — `ci(root): Issue 양식과 라벨·마일스톤 설정 스크립트`

### Task 4: 요청함을 Issues로 옮기기

**Files:**
- Modify: `docs/coordination/` 열린 문서 6개(맨 위에 이관 줄 추가), `docs/coordination/README.md`
- Move: `done` 문서 2개 → `docs/coordination/archive/`

**Interfaces:**
- Consumes: Task 3의 라벨·마일스톤
- Produces: Issue 6건(번호는 실행 결과를 ledger에 기록)

- [ ] **Step 1: Issue 생성** — 열린 문서마다 `gh issue create`. 제목은 문서 제목, 본문은 문서 본문 + "원문: `docs/coordination/<파일>`", 라벨은 frontmatter의 from·to·kind, 마일스톤은 아래.
  | 문서 | 마일스톤 | 추가 라벨 |
  | --- | --- | --- |
  | core-to-server-engine-proto-v1 | S1 | |
  | root-to-core-depth-terminology | (없음) | |
  | root-to-core-engine-mvp-feedback | (없음) | `accepted` |
  | root-to-design-artifacts | V0 | |
  | root-to-server-identity-impact | S1 | |
  | root-to-writing-engine-keys-scale | W0 | |
  추가로 core에 `kind:request` Issue 하나: "core.yml을 workflow_call로 전환(spec §4.1-3)", 라벨 `from:root`·`to:core`.
- [ ] **Step 2: 열린 문서는 옮기지 않고 표시** (Review Focus 2) — 각 문서 frontmatter 다음 줄에 `> 이관됨: GitHub Issue #<번호>. 이후 진행은 Issue에서 합니다.`
- [ ] **Step 3: done 문서 보관** — `git mv`로 `core-to-root-engine-mvp-done.md`, `core-to-root-zi-hour-confirmed.md`를 `archive/`로. 이 두 파일을 가리키는 지휘 소유 문서의 경로 문자열을 고칩니다(`grep -rn` 확인). `core/CLAUDE.md`의 언급은 경로 문자열이므로 Task 5에서 함께 고칩니다.
- [ ] **Step 4: README 수정** — 요청함은 GitHub Issues로 옮겼고 이 디렉터리는 보관소라는 안내, Issue 쓰는 법(`gh issue create --template`), 라벨 뜻.
- [ ] **Step 5: 확인** — Run: `gh issue list --state open --json number -q length` → Expected: `7`. `python3 -I tools/docs-check/docs_check.py .` → `OK`.
- [ ] **Step 6: Commit** — `docs(root): 요청함을 GitHub Issues로 이관`

### Task 5: 규약 문서 개정

**Files:**
- Modify: `docs/workflow.md`(§2 소유권 표, §3, §5.2, §6, 새 §8), 루트 `CLAUDE.md`, `core/CLAUDE.md`, `server/CLAUDE.md`, `app/CLAUDE.md`, `docs/identity/writing/CLAUDE.md`, `docs/identity/design/CLAUDE.md`, `docs/roadmap.md`

- [ ] **Step 1: `docs/workflow.md`**
  * §2: `.github/workflows/ci-gate.yml`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/`, `tools/` → 지휘.
  * §3 마무리: spec §6 체크리스트 다섯 항목으로 바꿈. "완료 보고"는 `kind:report` Issue.
  * §5.2 제목을 "요청함: GitHub Issues"로, 내용은 spec §5(라벨, 상태, 마일스톤, 결정은 git에).
  * §6: 브랜치 수명, 세션 시작 `git fetch origin && git merge origin/main`, 계약 먼저 병합, 모든 변경 PR·merge commit, `ci-gate`, `main` 직접 push 금지(D43·D44).
  * 새 §8 "운영 확장 메모": spec §4.2 표 그대로.
- [ ] **Step 2: 루트 `CLAUDE.md`** — 공통 규칙의 요청함 → Issues. 지휘 세션 절에 정기 일과 세 항목(spec §6).
- [ ] **Step 3: 각 단위 `CLAUDE.md`** — "다음 할 일"과 "현재 상태"의 요청함 안내를 Issues로(`gh issue list --label to:<단위>`), 마무리는 `docs/workflow.md` §3 체크리스트 참조. `core/CLAUDE.md`는 Task 4의 archive 경로와 Issue 번호(후속 요청·core.yml 전환)를 반영하고, 이 변경을 core에 알리는 문장을 core.yml 전환 Issue에 댓글로 남깁니다.
- [ ] **Step 4: 로드맵** — "현재 진행 순서"의 core 행 참조를 Issue 번호로. 외부 준비물 표에 변화 없음.
- [ ] **Step 5: 확인** — Run: `grep -rn "docs/coordination/" CLAUDE.md docs/workflow.md core/CLAUDE.md server/CLAUDE.md app/CLAUDE.md docs/identity/*/CLAUDE.md | grep -v archive | grep -v "보관"` → Expected: 출력 없음. `python3 -I tools/docs-check/docs_check.py .` → `OK`.
- [ ] **Step 6: Commit** — `docs(root): 규약을 Issues·ci-gate·세션 마무리 체크리스트로 개정 (D43~D45)`

### Task 6: 제품 지도 생성 스크립트

**Files:**
- Create: `tools/product-map/build_map_data.py`
- Create: `tools/product-map/test_build_map_data.py`

**Interfaces:**
- Produces:
  - `parse_roadmap(text: str) -> list[dict]` — 마일스톤 표 행 → `{"id","title","owner","requires","status"}`
  - `parse_decisions(text: str, prefix_source: str) -> list[dict]` — `{"id","date","area","text","source"}`
  - `collect_artifacts(root: Path) -> list[dict]` — 모든 `artifacts/index.json` 항목에 `"unit"`(지휘·design·writing·app)과 저장소 기준 `"path"`를 더함
  - `collect_issues() -> list[dict]` — `gh issue list --state open --json number,title,labels,milestone`. `gh` 실패 시 `[]`(Review Focus 5)
  - `build(root: Path) -> dict` — `{"generated_at","milestones","current_order","identity","screens","artifacts","decisions","issues"}`. `screens`는 IA 문서(`docs/ia/` 등)가 없으면 MVP 임시 화면 목록 상수(온보딩, 데일리, 나의 사주, 캘린더, 일기, 설정)와 `"provisional": true`.
  - CLI: `python3 -I build_map_data.py <저장소 루트> <출력 디렉터리>` → `<출력>/data.json` 쓰고, 참조된 이미지를 `<출력>/images/`로 복사.
- [ ] **Step 1: 실패하는 테스트** — 표본 로드맵 표 → 마일스톤 3개 파싱, 결정 표 두 행 파싱, artifacts가 unit을 붙여 모임, `gh`가 없을 때(`PATH` 비움) issues가 `[]`, IA 없을 때 `screens[0]["provisional"] is True`.
- [ ] **Step 2: 실패 확인** — `cd tools/product-map && python3 -I -m unittest -q` → FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — → `OK`
- [ ] **Step 5: 실제 실행** — Run: `python3 -I tools/product-map/build_map_data.py . "$SCRATCH/product-map"` 후 `python3 -I -c "import json;d=json.load(open('$SCRATCH/product-map/data.json'));print(len(d['milestones']),len(d['artifacts']),len(d['decisions']))"` → Expected: 마일스톤 20 이상, artifacts 3, 결정 45 이상.
- [ ] **Step 6: Commit** — `feat(root): 제품 지도 데이터 생성 스크립트`

### Task 7: 제품 지도 페이지와 첫 publish

**Files:**
- Create: `tools/product-map/page/index.html`(페이지 틀, `data.json`과 `images/`를 상대 경로로 읽음)

- [ ] **Step 1: `artifact-design` skill load**(Artifact 페이지 규약), 레이아웃 시안 2~3개를 visual companion으로 보여주고 사용자가 고름. 고른 결과를 ledger와 `docs/artifacts/index.json`(kind `mockup`)에 기록.
- [ ] **Step 2: 고른 레이아웃으로 `index.html` 작성** — spec §7의 일곱 영역. 데이터가 빈 영역은 "아직 없음"으로 표시. 다크 모드, 휴대폰 폭.
- [ ] **Step 3: 로컬 확인** — 생성 디렉터리에 페이지를 복사해 헤드리스 Chrome으로 스크린샷(데스크톱 1440, 휴대폰 390) → 영역 일곱 개가 모두 보이는지 이미지로 확인.
- [ ] **Step 4: publish** — Artifact publish(`file_path`: 페이지, `files`: `data.json`·`images/*`, `icon`: `map`). 받은 URL을 루트 `CLAUDE.md` 문서 위치 표와 `docs/roadmap.md` 위에 "제품 지도" 링크로 기록.
- [ ] **Step 5: 갱신 절차 문서화** — `tools/product-map/README.md`: 생성 → 복사 → 같은 URL로 다시 publish하는 명령 순서. 지휘 세션 정기 일과(루트 `CLAUDE.md`)에서 이 README를 가리킴.
- [ ] **Step 6: Commit** — `feat(root): 제품 지도 페이지와 갱신 절차`

### Task 8: 마무리

- [ ] **Step 1:** `python3 -I tools/docs-check/docs_check.py .`, 두 `unittest` 모음 → 모두 통과
- [ ] **Step 2:** draft PR을 ready로 바꾸고 `gh pr checks --watch` → `ci-gate` pass
- [ ] **Step 3:** 사용자에게 병합 확인을 받은 뒤 `gh pr merge --merge`
- [ ] **Step 4:** writing·design 세션에 전할 문장(“`git merge origin/main` 후 `gh issue list --label to:<단위>`”)을 사용자에게 전달

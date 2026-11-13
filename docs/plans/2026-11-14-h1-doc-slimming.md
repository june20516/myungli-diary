# H1 기준 문서 정리 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 세션이 처음 읽는 루트 문서를 지금 사실만 남게 줄이고, 크기 상한 검사를 넣고, 단위 문서 정리를 요청합니다.

**Architecture:** 루트 문서마다 "지금" 파일과 history 파일로 나눕니다. `tools/docs-check`에 상한표와 면제 목록을 둔 크기 검사를 더해 `ci-gate` docs 검사로 지킵니다. 단위 `CLAUDE.md`와 단위 결정 로그는 각 단위가 고치고, 지휘는 병합될 때마다 면제를 지웁니다.

**Tech Stack:** Markdown, Python 3 표준 라이브러리(`tools/docs-check`, `unittest`), `gh`

**Spec:** [`docs/specs/2026-11-13-h1-doc-slimming-design.md`](../specs/2026-11-13-h1-doc-slimming-design.md)

## Global Constraints

* 내용은 바꾸지 않고 옮기거나 지웁니다. 옮기다 모순을 찾으면 고치지 않고 `to:root` Issue로 올립니다(spec §4).
* D, C, S, A, W, V, E, K 번호와 Issue 링크는 그대로 둡니다.
* 상한(바이트): 루트 `CLAUDE.md` 10240, 단위 `CLAUDE.md` 각 16384, `docs/workflow.md` 28672(실행 중 22528에서 올림), `docs/roadmap.md` 10240, `docs/contracts/README.md` 12288(spec §5).
* 결정 로그와 history 파일에는 상한을 두지 않습니다.
* 지휘는 루트 소유 경로만 고칩니다. 단위 `CLAUDE.md`와 `<단위>/docs/decisions.md`는 요청으로 보냅니다(`docs/workflow.md` §2).
* 사용자에게 보이는 글 규칙(D93)은 이 문서들에 해당하지 않습니다(작업 문서).
* 브랜치 `root/h1-doc-slimming`(이미 있음, spec 커밋 77d43c19). root PR은 `ci-gate` 통과 뒤 지휘가 병합합니다.

## Review Focus

1. 옮긴 절을 가리키던 다른 문서의 링크(파일 이름과 `#앵커`)가 끊김. 기대: 링크 검사가 잡거나, 옮긴 자리에 새 링크.
2. 상한표에 적은 경로가 나중에 바뀌거나 지워짐. 기대: 검사가 "상한표의 파일이 없습니다" 오류.
3. 면제 중인 파일이 정리돼 상한 아래로 내려왔는데 면제가 남음. 기대: "면제를 지우세요" 오류.
4. 일부 항목만 대체된 결정(①은 대체, ②는 유효)을 통째로 history로 보내 유효한 규칙이 앞에서 사라짐. 기대: 행은 남고 대체된 항목만 "→ <번호>".
5. 단위가 기능 PR에서 계약 목록 자기 행에 긴 변경 이력을 다시 적음. 기대: 크기 검사가 막고, workflow 규칙이 "행은 한 줄, 내용은 CHANGELOG"라고 알려 줌.

---

### Task 1: 크기 상한 검사

**Files:**
- Modify: `tools/docs-check/docs_check.py` (모듈 상수, 새 함수, `main`의 검사 목록, 맨 위 docstring 한 줄)
- Test: `tools/docs-check/test_docs_check.py`

**Interfaces:**
- Produces: `SIZE_LIMITS: dict[str, int]`(저장소 상대 경로 → 상한 바이트, Global Constraints 값 그대로, 단위 `CLAUDE.md` 5개 포함), `SIZE_EXEMPT: frozenset[str]`(단위 `CLAUDE.md` 5개 경로), `check_size_limits(root: Path) -> list[str]`

- [ ] **Step 1: 실패하는 테스트 작성** — `class SizeLimitTest(RepoTestCase)`에 다섯 사례. 상한표와 면제는 `unittest.mock.patch.object(docs_check, "SIZE_LIMITS", {...})`로 바꿔 작은 값으로 씁니다.
  * `test_over_limit_reports_path_and_sizes`: 상한 10, 11바이트 파일 → 오류 한 줄에 경로, `11`, `10`, "경과" 포함
  * `test_within_limit_passes`: 10바이트 → `[]`
  * `test_exempt_over_limit_passes`: 면제 경로, 11바이트 → `[]`
  * `test_exempt_within_limit_asks_to_remove_exemption`: 면제 경로, 10바이트 → 오류에 "면제를 지우세요"
  * `test_missing_listed_file_reports`: 상한표 경로에 파일 없음 → 오류에 "상한표의 파일이 없습니다"

- [ ] **Step 2: 실패 확인** — Run: `cd tools/docs-check && python3 -I -m unittest -q test_docs_check.SizeLimitTest` / Expected: `AttributeError`(함수 없음)

- [ ] **Step 3: 구현** — 크기는 `path.stat().st_size`(바이트). 오류 문구는 "`<경로>`: <크기>바이트, 상한 <상한>바이트. 경과를 history 파일로 옮기거나 병합된 현재 상태를 지우세요(H1, D131)". `main`의 `problems`에 `check_size_limits(root)`를 더합니다.

- [ ] **Step 4: 통과 확인** — Run: `cd tools/docs-check && python3 -I -m unittest -q` / Expected: OK. 이 시점 `python3 -I tools/docs-check/docs_check.py .`는 루트 문서 넷이 상한을 넘어 실패합니다(Task 2~5에서 해소).

- [ ] **Step 5: Commit** — `git add tools/docs-check && git commit -m "feat(root): docs-check 처음 읽는 문서 크기 상한 (H1)"`

### Task 2: 계약 목록과 CHANGELOG

**Files:**
- Create: `docs/contracts/CHANGELOG.md`
- Modify: `docs/contracts/README.md`

- [ ] **Step 1:** README 표의 각 행에서 "상태" 칸을 지금 버전과 상태 한 줄(예: "**v1.13.1 구현 완료**, 받는 쪽 app 대응 완료")로 줄이고, 그 밖의 변경 이력 문장을 `CHANGELOG.md`의 `## <계약 이름>` 절로 그대로 옮깁니다. 절 안에서는 최신이 위입니다. README 맨 위에 변경 이력은 `CHANGELOG.md`에 있다는 링크 한 줄.
- [ ] **Step 2:** "생성 코드" 절은 지금 규칙만 남기고 경과는 CHANGELOG 맨 아래 `## 생성 코드` 절로.
- [ ] **Step 3: 검증** — Run: `wc -c < docs/contracts/README.md` / Expected: 12288 이하. Run: `python3 -I tools/docs-check/docs_check.py . | grep -E "contracts/(README|CHANGELOG)"` / Expected: 출력 없음.
- [ ] **Step 4: Commit** — `docs(root): 계약 목록은 지금 버전만, 이력은 CHANGELOG (H1)`

### Task 3: workflow와 history, 새 규칙

**Files:**
- Create: `docs/workflow-history.md`
- Modify: `docs/workflow.md`

- [ ] **Step 1:** 각 절에서 도입 경위와 "처음엔", "PR #n으로 바뀜" 같은 경과 문장을 `workflow-history.md`의 같은 절 번호 아래로 옮깁니다. 규칙 문장 끝 결정 번호(Dnn)는 남깁니다.
- [ ] **Step 2:** §3 5단계 마무리 2번을 바꿉니다: "현재 상태에는 진행 중인 일(브랜치, 열린 PR, 막힌 것)만 둡니다. 병합된 일은 지웁니다. 계약을 바꿨으면 `docs/contracts/README.md` 자기 행의 버전과 상태 한 줄을 고치고, 바뀐 내용은 `docs/contracts/CHANGELOG.md` 자기 절 맨 위에 적습니다(D131)."
- [ ] **Step 3:** §4 결정 로그에 "대체된 결정은 번호, 날짜, '→ <새 번호>로 대체' 한 줄만 남기고 원문 행은 같은 폴더 `decisions-history.md`로 옮깁니다. 일부 항목만 대체되면 행을 남기고 그 항목만 줄입니다(D131)."를 더합니다.
- [ ] **Step 4: 검증** — `wc -c < docs/workflow.md` ≤ 28672, docs-check에 workflow 관련 오류 없음.
- [ ] **Step 5: Commit** — `docs(root): workflow 지금 규칙만, 경과는 workflow-history (H1)`

### Task 4: 로드맵과 history

**Files:**
- Create: `docs/roadmap-history.md`
- Modify: `docs/roadmap.md`

- [ ] **Step 1:** 마일스톤 표에서 "완료" 행은 이름, 한 줄 요약, "완료"만 남기고 상세는 history의 `## <마일스톤 id>`로. 진행 중 행의 상태 칸은 한 줄.
- [ ] **Step 2:** "현재 진행 순서"는 지금 순서와 다음 관문만 남기고 경과 문단은 history `## 진행 경과`에 날짜 제목으로. 절 제목 날짜를 2026-11-14로.
- [ ] **Step 3:** H1 행 상태를 "진행 중(spec, plan 링크)"으로.
- [ ] **Step 4: 검증** — `wc -c < docs/roadmap.md` ≤ 10240, docs-check 로드맵 오류 없음.
- [ ] **Step 5: Commit** — `docs(root): 로드맵 지금 순서만, 경과는 roadmap-history (H1)`

### Task 5: 루트 결정 로그와 D131

**Files:**
- Create: `docs/decisions-history.md`
- Modify: `docs/decisions.md`

- [ ] **Step 1:** 뒤 결정이 통째로 바꾼 행(근거 칸이나 본문에 "Dnn로 개정/대체"가 있는 행, 지금 14곳 안팎)을 찾아, 원문 행을 history 표로 그대로 옮기고 본문에는 `| Dn | 날짜 | 영역 | → Dm로 대체 | |`만 남깁니다. 일부 항목만 대체된 행은 그 항목만 "→ Dm"으로 줄이고 원문 행을 history에 둡니다(Review Focus 4).
- [ ] **Step 2:** D131 행을 더합니다(2026-11-14, 영역 "워크플로, 문서"): 처음 읽는 문서는 지금 사실만(spec §4), 기계 검사 세 조건(spec §3), 크기 상한과 면제(spec §5), 현재 상태와 계약 행 규칙(Task 3). 근거: 사용자 결정(2026-11-13 대화, 설계 승인), spec 링크.
- [ ] **Step 3: 검증** — docs-check 통과. `check_decision_ids`는 이름이 `decisions.md`인 파일만 보므로 history의 같은 번호와 겹치지 않고, 본문에 한 줄 행이 남아 번호 조회(`_decision_ids`)도 그대로입니다.
- [ ] **Step 4: Commit** — `docs(root): D131, 대체된 결정 원문은 decisions-history (H1)`

### Task 6: 루트 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1:** "공통 규칙" 맨 위에 "자주 놓치는 판단 규칙" 짧은 목록(번호 요약, 질문을 결정으로 받지 않기 등 지금 공통 규칙에 이미 있는 것만, 새 규칙 없음)으로 순서만 바꿉니다.
- [ ] **Step 2:** "문서 위치" 표에 `docs/contracts/CHANGELOG.md`, `docs/workflow-history.md`, `docs/roadmap-history.md`, `decisions-history.md` 행.
- [ ] **Step 3: 검증** — `wc -c < CLAUDE.md` ≤ 10240. 이제 `python3 -I tools/docs-check/docs_check.py .` 전체 통과.
- [ ] **Step 4: Commit** — `docs(root): CLAUDE.md 판단 규칙 앞으로, 경과 문서 위치 (H1)`

### Task 7: root PR과 병합

- [ ] **Step 1:** `git merge origin/main` 뒤 docs-check와 `cd tools/docs-check && python3 -I -m unittest -q` 통과 확인.
- [ ] **Step 1b:** 옮긴 절을 가리키던 앵커 링크 확인(Review Focus 1): `git grep -n -E "(workflow|roadmap|contracts/README)\.md#" -- "*.md"`로 나온 앵커가 지금 파일에 있는지 보고, history로 간 절이면 링크를 history 파일로 고칩니다.
- [ ] **Step 2:** push, PR(제목 `docs(root): H1 기준 문서 정리 루트 몫과 크기 상한 검사`, 본문에 줄어든 크기 표, "처리한 Issue: 없음"), `gh pr merge --auto --merge`.
- [ ] **Step 3:** 병합 뒤 main CI 통과 확인.

### Task 8: 단위 요청 다섯 개

- [ ] **Step 1:** `kind:request` Issue 다섯 개(to:core, to:server, to:app, to:writing, to:design, `accepted`). 본문: spec §4 단위 행과 결정 로그 행, 상한 16384, 지금 크기, "면제는 지휘가 지움", "모순은 고치지 말고 Issue", "진행 중 작업 PR에 묶어도 됨(D100 ①)", 계약 행 한 줄 규칙(Task 3 Step 2).
- [ ] **Step 2:** 로드맵 H1 행에 Issue 번호(다음 root PR에 묶음).

### Task 9: 면제 지우기 (단위 PR 병합마다)

- [ ] **Step 1:** 단위 PR이 병합되면 `wc -c`로 그 `CLAUDE.md`가 16384 이하인지 보고, `SIZE_EXEMPT`에서 그 경로를 지우는 root PR(여럿이 가까이 병합되면 한 PR에 묶음).
- [ ] **Step 2:** docs-check 통과 확인 뒤 auto-merge.

### Task 10: 재측정과 마무리

- [ ] **Step 1:** `SIZE_EXEMPT`가 비면 spec §2 표와 같은 문서를 `wc -c`로 다시 재서 spec §7에 표로 적습니다(앞뒤 비교, app 세션 시작 때 읽는 합계).
- [ ] **Step 2:** 로드맵 H1을 완료로, 다음 순서(bootstrap 묶음 apply → Q1)로 갱신.
- [ ] **Step 3:** root PR, auto-merge.

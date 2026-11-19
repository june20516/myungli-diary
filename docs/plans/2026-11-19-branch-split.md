# main과 staging 브랜치 분리 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 모든 PR은 `staging`으로, prod는 `staging → main` 승격으로만 나가게 브랜치, 검사, 배포, 권한을 나눕니다.

**Architecture:** 소유 경로(docs/workflow.md §2)대로 나눕니다. 지휘는 `ci-gate.yml`, `tools/`, 루트 문서를 고치고, server는 배포 workflow와 bootstrap과 계약 관문을, app과 design은 자기 workflow와 스크립트를 고칩니다. 지휘 PR과 server PR이 병합된 뒤 `staging` 브랜치를 만들고, 사용자가 저장소와 GCP 설정을 바꿔 전환합니다.

**Tech Stack:** GitHub Actions, GitHub rulesets와 environments(`gh api`), Terraform(GCP Workload Identity), bash, Python(`tools/drift` 테스트)

**Spec:** `docs/specs/2026-11-19-branch-split-design.md`

## Global Constraints
* 브랜치 이름은 `staging`과 `main` 둘뿐입니다. 승격 PR은 head `staging`, base `main`.
* 외부 Action은 commit SHA로 고정합니다(D136 ③). 새 Action을 더하지 않습니다.
* 지휘는 단위 소유 경로를 고치지 않습니다. 단위 몫은 요청 Issue로 보냅니다.
* 지난 `plans/` 문서의 `origin/main`은 기록이라 고치지 않습니다.
* 저장소 설정(기본 브랜치, ruleset, environment)과 bootstrap apply는 사용자가 하거나, 지휘가 명령과 바뀌기 전 값을 보여 드리고 명시적 승인을 받은 뒤 합니다.
* 비밀 값은 경로로만 다룹니다. ruleset id, environment 이름은 공개 식별자라 적어도 됩니다.

## Review Focus
1. 전환 사이(staging 브랜치는 있고 environment 제한은 아직 main): staging push의 배포 job이 environment 제한에 막혀 실패할 수 있음. 사람이 기대하는 동작은 "실패해도 prod는 건드리지 않음" → Task 6 순서(제한 변경을 브랜치 생성 직후)와 Task 7 확인으로 고정.
2. head가 fork나 `staging` 아닌 브랜치인 main 대상 PR: `promotion-source`가 실패해야 함 → Task 1 테스트.
3. 대상이 staging인 일반 PR: `promotion-source`는 바로 통과해야 함(지금 PR이 막히면 안 됨) → Task 1 테스트.
4. `workflow_dispatch`로 main에서 수동 실행한 `deploy-server`(staging-prod 대상): staging job은 돌지 않고 prod job만 돌아야 함 → Task 4 조건.
5. drift Issue가 staging push에서 닫히지 않아 열린 채 남음 → Task 2 조건과 `test_drift.py`.

---

### Task 1: `ci-gate` 브랜치 트리거와 `promotion-source` (지휘)

**Files:**
- Modify: `.github/workflows/ci-gate.yml`
- Create: `tools/promotion/check.sh`, `tools/promotion/test_check.sh`

**Interfaces:**
- Produces: job 이름 `promotion-source`(필수 검사 context 이름). `tools/promotion/check.sh <base_ref> <head_ref>` → 종료 코드 0(통과) 또는 1(실패), 실패 때 한국어 한 줄.

- [ ] **Step 1: 실패하는 테스트 작성** `tools/promotion/test_check.sh`: 세 경우를 단언합니다.
  * `check.sh main staging` → 0
  * `check.sh main core/foo` → 1, 출력에 "main에는 staging에서만"
  * `check.sh staging core/foo` → 0
- [ ] **Step 2: 실행해 실패 확인** Run: `bash tools/promotion/test_check.sh` Expected: check.sh 없음으로 실패
- [ ] **Step 3: `check.sh` 구현** 인자 둘을 받아 base가 `main`이고 head가 `staging`이 아니면 실패.
- [ ] **Step 4: 테스트 통과 확인** Run: `bash tools/promotion/test_check.sh` Expected: 세 경우 모두 기대값
- [ ] **Step 5: `ci-gate.yml` 고치기**
  * `on.push.branches: [staging, main]`
  * job `promotion-source` 추가: `pull_request`에서만 돌고(push와 수동은 건너뜀, 통과로 표시), `tools/promotion/check.sh "${{ github.base_ref }}" "${{ github.head_ref }}"`. checkout은 기존과 같은 SHA, `sparse-checkout: tools/promotion`.
  * `changes` job의 비교 기준과 주석의 "main"을 "PR 대상 브랜치"로. push는 지금처럼 `before`와 비교.
  * 머리 주석 1행 "모든 PR과 main push" → "모든 PR과 staging, main push".
  * `ci-gate` 판정 job에 `promotion-source`를 넣지 않습니다(따로 필수 검사로 걸기 때문).
- [ ] **Step 6: 로컬 검사** Run: `actionlint .github/workflows/ci-gate.yml`(없으면 `python3 -c "import yaml,sys;yaml.safe_load(open(sys.argv[1]))" .github/workflows/ci-gate.yml`) Expected: 오류 없음
- [ ] **Step 7: Commit** `ci(root): ci-gate를 staging과 main push에, main 대상 PR은 staging에서만(promotion-source)`

### Task 2: drift 닫힘을 staging push로 (지휘)

**Files:**
- Modify: `.github/workflows/ci-gate.yml`(job `drift-close`), `tools/drift/drift.sh` 주석
- Test: `tools/drift/test_drift.py`

**Interfaces:**
- Consumes: Task 1의 push 트리거.

- [ ] **Step 1: 조건 바꾸기** `drift-close.if`: `always() && github.event_name == 'push' && github.ref == 'refs/heads/staging'`. 위 주석의 "main에서"를 "staging에서"로.
- [ ] **Step 2: `drift.sh` 주석** "main push에서" → "staging push에서". 동작 코드는 커밋 sha 기준이라 바꾸지 않습니다.
- [ ] **Step 3: 기존 테스트 통과 확인** Run: `cd tools/drift && python3 -I -m unittest -q` Expected: OK
- [ ] **Step 4: Commit** `ci(root): drift Issue는 staging push에서 닫음`

### Task 3: 지휘 도구와 루트 문서 (지휘)

**Files:**
- Modify: `tools/repo-watch/watch.sh`, `tools/repo-watch/README.md`, `CLAUDE.md`(루트), `docs/workflow.md`, `.github/pull_request_template.md`, `docs/workflow-history.md`

- [ ] **Step 1: `watch.sh`** `main_ci`를 브랜치 인자를 받는 `branch_ci <branch>`로 바꾸고 `snapshot`에서 `branch_ci staging && branch_ci main`. 출력 줄 머리를 `<branch>-ci <sha> <verdict>`로. 캐시 파일 이름에 브랜치를 넣지 않습니다(실행 id가 고유).
- [ ] **Step 2: 감시 한 바퀴 확인** Run: `STATE=$(mktemp -d) && timeout 100 tools/repo-watch/watch.sh "$STATE" | head -3`(macOS는 `perl -e 'alarm 100; exec @ARGV'`로 감쌈) Expected: 오류 줄 없음, 첫 실행은 출력 없거나 `staging-ci`/`main-ci` 줄
- [ ] **Step 3: 문서** 세 곳의 세션 시작과 브랜치 만들기를 `origin/staging`으로: 루트 `CLAUDE.md` "세션을 열면", `docs/workflow.md` §6(42, 48, 109, 112, 121행 근처), PR 템플릿 체크 줄. `docs/workflow.md`에 "승격" 절을 더합니다: 누가(지휘, 필요할 때), 병합 방식(merge commit), 본문(지난 승격 뒤 PR 번호와 prod에 미치는 것 한 줄, `처리한 Issue: 없음`), 급한 수정도 같은 길. 루트 `CLAUDE.md` "병합" 줄에 "prod는 지휘의 승격 PR로만" 한 줄.
- [ ] **Step 4: 경과** `docs/workflow-history.md`에 "2026-11-19 기준 브랜치를 staging으로(D141)" 한 줄.
- [ ] **Step 5: 문서 검사** Run: `python3 -I tools/docs-check/docs_check.py` Expected: `OK: docs 검사 통과`
- [ ] **Step 6: Commit** `docs(root): 기준 브랜치 staging과 승격 절차, repo-watch 두 브랜치`

### Task 4: 배포 workflow, bootstrap, 계약 관문 (server 요청, 전환 전 필수)

**Files (server 소유, 요청 Issue로):**
- `.github/workflows/deploy-server.yml`, `.github/workflows/deploy-engine.yml`, `.github/workflows/server.yml`
- `server/deploy/terraform/bootstrap/main.tf`(+ README 절차)
- `server/cmd/contractgate/main.go`, `server/CLAUDE.md`

요청 Issue에 적을 바뀔 동작(정확한 값):
- [ ] **`deploy-server`:** `on.push.branches: [staging, main]`. job `staging.if`: `github.event_name != 'pull_request' && github.ref == 'refs/heads/staging' && vars.DEPLOY_ENABLED == 'true' && inputs.target != 'load' && inputs.target != 'load-teardown'`. job `prod`: `needs: checks`(staging 아님), `if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main' && vars.DEPLOY_ENABLED == 'true' && inputs.target != 'load' && inputs.target != 'load-teardown'`. `load`, `load-teardown`의 `refs/heads/main` → `refs/heads/staging`. dispatch 선택지 `staging-prod`는 "실행한 브랜치의 환경"으로 설명을 바꿈.
- [ ] **`deploy-engine`:** 같은 규칙. `staging` job은 `refs/heads/staging`, `prod` job은 `needs` 없이 `refs/heads/main`, `load`는 `refs/heads/staging`.
- [ ] **`server.yml`:** 캐시 저장 조건 `refs/heads/main` → `refs/heads/staging`.
- [ ] **bootstrap:** deployer 연결 member를 `attribute.env_ref/${each.value}@refs/heads/${local.deploy_branch}`로, `local.deploy_branch = var.environment == "prod" ? "main" : "staging"`. README에 apply 순서(staging, load, prod)와 되돌리기(같은 값 `main`).
- [ ] **`contractgate`:** `-base` 기본값 `origin/staging`, 주석 예시도. `server/CLAUDE.md`의 `origin/main` 두 곳 → `origin/staging`.
- [ ] **검사:** `terraform fmt -check`, `terraform validate`(bootstrap), `actionlint` 두 workflow, `go test ./cmd/contractgate/...`.
- [ ] **완료 조건:** server PR 병합(아직 main 대상), Issue에 "bootstrap apply 대기" 남김.

### Task 5: app, design, core 몫 (요청 Issue, 전환을 막지 않음)

- [ ] **app (`app.yml`, 업로드 스크립트, README 대장):** `app.yml` push branches `[staging]`(기기 E2E는 staging 병합 뒤). `tool/upload_play.sh`와 iOS 업로드 스크립트가 `prod` 설정으로 빌드할 때 `git rev-parse --abbrev-ref HEAD`가 `main`이 아니면 멈춤. `README.md` 스토어 빌드 대장에 칸 `브랜치`, `설정`. `app/CLAUDE.md`의 `origin/main` → `origin/staging`.
- [ ] **design (`design.yml`):** 캐시 저장 조건 `refs/heads/main` → `refs/heads/staging`. `tools/test_components.py`의 main 언급 확인.
- [ ] **core (`core/CLAUDE.md`):** `origin/main` 두 곳 → `origin/staging`.
- [ ] **writing:** `CLAUDE.md`에 `origin/main`이 있으면 같은 변경.
- [ ] 각 Issue는 "다음 작업 PR에 묶어도 됨(D100 ①), 대상은 staging".

### Task 6: 전환 (지휘 + 사용자)

**선행:** Task 1~3 지휘 PR과 Task 4 server PR이 main에 병합됨.

- [ ] **Step 1: 되돌리기 값 기록** 지휘가 지금 값을 비공개 기록 `security/branch-split-before.md`에 남깁니다: 기본 브랜치, ruleset 25140518 JSON(`gh api repos/june20516/myungli-diary/rulesets/25140518`), environment 세 개의 배포 브랜치 정책, bootstrap의 member 값.
- [ ] **Step 2: `staging` 브랜치 만들기** `gh api repos/june20516/myungli-diary/git/refs -f ref=refs/heads/staging -f sha=$(git rev-parse origin/main)`
- [ ] **Step 3: environment 배포 브랜치 정책(사용자 승인 뒤)** staging과 load: 정책 `main` 삭제, `staging` 추가. prod: `main` 그대로. 명령은 `gh api -X POST repos/.../environments/<env>/deployment-branch-policies -f name=staging -f type=branch`와 해당 정책 id `DELETE`.
- [ ] **Step 4: bootstrap apply(사용자)** server README 순서대로 staging, load, prod.
- [ ] **Step 5: ruleset(사용자 승인 뒤)**
  * 25140518: `conditions.ref_name.include` → `["refs/heads/main"]`, `bypass_actors` → `[]`, 필수 검사에 `promotion-source` 추가.
  * 새 ruleset "staging 보호": 대상 `refs/heads/staging`, 규칙은 지금 25140518과 같음(삭제 금지, force push 금지, PR 필수 리뷰 0, 필수 검사 `ci-gate`, `pr-body`), 우회 저장소 관리자 역할(actor_id 5, always).
- [ ] **Step 6: 기본 브랜치(사용자 승인 뒤)** `gh api -X PATCH repos/june20516/myungli-diary -f default_branch=staging`

### Task 7: 확인과 기록 (지휘)

- [ ] **Step 1: staging 경로** 작은 지휘 PR(로드맵 한 줄)을 staging에 병합 → `ci-gate`, `deploy-server` staging job이 돌고 prod job은 건너뜀. Expected: staging 배포 성공, prod 승인 요청 없음.
- [ ] **Step 2: 막힘 확인** 임시 브랜치에서 main 대상 PR을 열어 `promotion-source` 실패 확인 뒤 PR 닫고 브랜치 삭제.
- [ ] **Step 3: 승격** `gh pr create --base main --head staging` 승격 PR → `ci-gate`, `promotion-source` 통과, 병합 뒤 `deploy-server` prod job이 승인 대기. Expected: 사용자 승인 뒤 prod 배포 성공(바뀐 것이 없으면 지휘가 run을 취소해도 됨).
- [ ] **Step 4: 결정과 로드맵** `docs/decisions.md`에 D141(브랜치 분리 시행, spec 링크, 사용자 결정 2026-11-19), 로드맵 I4 준비물 "브랜치 분리" 지움, 단위 Issue(Task 5) 링크. 대상 staging, 병합 뒤 승격.
- [ ] **Step 5: 메모리** 지휘 메모리의 "origin/main" 관련 항목(브랜치 규칙, prod 승인 취소)을 새 흐름에 맞게 고침.

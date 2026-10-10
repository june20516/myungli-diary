# 작업 규약 (Workflow)

명리일기 모노레포에서 여러 Claude 세션이 함께 일하는 방식입니다. 모든 세션은 이 문서를 따릅니다.

## 1. 역할

| 세션 | 시작 위치 | 맡는 일 | 하지 않는 일 |
| --- | --- | --- | --- |
| **지휘 세션** | 저장소 루트 | 통합 로드맵, 서브 프로젝트 사이의 계약 연결, 요청함 검토·배분, 둘 이상에 걸친 결정, 통합 시점 판단 | 서브 프로젝트 코드 구현 |
| **core 세션** | `core/` | 명리 엔진(Python)의 설계 → 계획 → 구현 → 마무리 | 다른 서브 프로젝트 코드, 루트 문서 수정 |
| **server 세션** | `server/` | 메인 API 서버(Go)의 설계 → 계획 → 구현 → 마무리 | 위와 같음 |
| **app 세션** | `app/` | 모바일 앱(Flutter)의 설계 → 계획 → 구현 → 마무리 | 위와 같음 |

**원칙:** 각 서브 프로젝트는 자기 작업을 **스스로 열고 스스로 닫습니다.** 서브 프로젝트끼리는 상대 코드를 직접 고치지 않고, **계약 파일**과 **요청함**으로만 주고받습니다.

## 2. 소유권 (누가 어디를 고칠 수 있나)

| 경로 | 소유 | 비고 |
| --- | --- | --- |
| `core/` | core | |
| `server/` | server | |
| `app/` | app | |
| `proto/myungri/engine/`, `proto/buf.yaml` | core | 엔진 gRPC 계약의 제공자 |
| `.github/workflows/<서브 프로젝트>.yml` | 해당 서브 프로젝트 | |
| `docs/coordination/` | 모두 | 요청·보고 문서 **작성**은 누구나, 상태 변경 규칙은 §5 |
| `README.md`, `CLAUDE.md`(루트), `docs/background/`, `docs/decisions.md`, `docs/roadmap.md`, `docs/contracts/`, `docs/workflow.md` | 지휘 | 서브 프로젝트는 읽기만 하고, 바꿀 일이 있으면 요청함으로 |

## 3. 서브 프로젝트의 작업 주기

1. **시작:** 아래를 읽습니다.
   - 자기 `CLAUDE.md`(현재 상태와 다음 할 일)
   - `docs/roadmap.md`(자기 마일스톤)
   - `docs/contracts/README.md`(쓰고 제공하는 계약)
   - `docs/coordination/`에서 **자기 앞으로 온 열린 요청**
2. **설계:** brainstorming → spec 작성 → 사용자 승인. spec은 `<서브 프로젝트>/docs/specs/YYYY-MM-DD-<주제>-design.md`에 둡니다.
3. **계획:** writing-plans. 계획은 `<서브 프로젝트>/docs/plans/YYYY-MM-DD-<주제>.md`에 둡니다.
4. **구현:** 계획을 실행합니다(subagent-driven 또는 executing-plans).
5. **마무리:**
   - 자기 `CLAUDE.md`의 "현재 상태"를 고칩니다.
   - 제공 계약이 바뀌었으면 버전을 올립니다.
   - `docs/coordination/`에 **완료 보고**를 남깁니다.

suberpowers skill이 기본으로 쓰는 `docs/suberpowers/specs/`, `docs/suberpowers/plans/` 경로는 쓰지 않습니다. 서브 프로젝트는 위 경로를, 지휘 세션은 `docs/specs/`, `docs/plans/`를 씁니다.

## 4. 결정 로그
* **둘 이상의 서브 프로젝트나 제품 전체에 걸친 결정:** `docs/decisions.md` (번호 `D<n>`, 지휘 세션만 기록)
* **한 서브 프로젝트 안의 결정:** `<서브 프로젝트>/docs/decisions.md` (번호 core `C<n>`, server `S<n>`, app `A<n>`)
* 서브 프로젝트 결정이 루트 결정과 부딪히면 구현을 멈추고 요청함으로 올립니다.

## 5. 계약과 요청함

### 5.1. 계약
* 목록과 상태는 `docs/contracts/README.md`에 있습니다.
* 계약은 **제공하는 쪽만** 바꿉니다. 사용하는 쪽은 요청합니다.
* 하위 호환이 깨지는 변경은 다음 절차를 따릅니다: ① 요청함에 공지 ② 계약 버전 올림 ③ 사용하는 쪽이 대응을 마쳤다고 보고한 뒤 이전 버전 제거.

### 5.2. 요청함 `docs/coordination/`
* 파일 이름: `YYYY-MM-DD-<보내는 쪽>-to-<받는 쪽>-<짧은 주제>.md`. `<보내는 쪽>`/`<받는 쪽>`은 `root`, `core`, `server`, `app` 중 하나입니다.
* 형식은 `docs/coordination/TEMPLATE.md`를 따릅니다.
* 상태 흐름: `open` → (지휘 세션 검토) → `accepted` 또는 `rejected` → (받는 쪽 처리) → `done`.
  * `accepted`/`rejected`는 지휘 세션만 바꿉니다.
  * `done`은 받는 쪽이 바꿉니다.
  * 완료 보고(`<서브 프로젝트>-to-root`)는 처음부터 `done`으로 써도 됩니다.
* 끝난 문서는 지우지 않고 `docs/coordination/archive/`로 옮깁니다(지휘 세션).

## 6. Git
* 저장소: `june20516/myungli-diary` (모노레포, D33).
* 브랜치 이름: `<서브 프로젝트>/<주제>` (예: `core/engine-mvp`). 지휘 세션은 `root/<주제>`.
* 브랜치를 만들 때 공용 원격 브랜치를 upstream으로 걸지 않습니다. 예: `git switch -c core/engine-mvp --no-track main`. 만든 직후 `git status -sb`로 확인합니다.
* push는 대상 브랜치를 명시합니다: `git push -u origin <브랜치>`.
* commit 메시지의 범위 표기: `feat(core): …`, `fix(server): …`, `docs(root): …`.
* **같은 작업 디렉터리에서 세션 두 개를 동시에 돌리지 않습니다.** 서브 프로젝트를 동시에 진행하려면 서브 프로젝트마다 `git worktree`를 따로 만듭니다(using-git-worktrees skill).
* 릴리스 태그에는 접두어를 붙입니다: `core/v1.0.0`.

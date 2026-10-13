# 작업 규약 (Workflow)

명리일기 모노레포에서 여러 Claude 세션이 함께 일하는 방식입니다. 모든 세션은 이 문서를 따릅니다.

## 1. 역할

| 세션 | 시작 위치 | 맡는 일 | 하지 않는 일 |
| --- | --- | --- | --- |
| **지휘 세션** | 저장소 루트 | 통합 로드맵, 서브 프로젝트 사이의 계약 연결, 요청함 검토·배분, 둘 이상에 걸친 결정, 통합 시점 판단 | 서브 프로젝트 코드 구현 |
| **core 세션** | `core/` | 명리 엔진(Python)의 설계 → 계획 → 구현 → 마무리 | 다른 서브 프로젝트 코드, 루트 문서 수정 |
| **server 세션** | `server/` | 메인 API 서버(Go)의 설계 → 계획 → 구현 → 마무리 | 위와 같음 |
| **app 세션** | `app/` | 모바일 앱(Flutter)의 설계 → 계획 → 구현 → 마무리 | 위와 같음 |
| **writing 세션** | `docs/identity/writing/` | 라이팅 시스템과 콘텐츠 문장의 설계 → 계획 → 실행 → 마무리 | 위와 같음 |
| **design 세션** | `docs/identity/design/` | 시각 정체성·디자인 토큰·컴포넌트 명세의 설계 → 계획 → 실행 → 마무리 | 위와 같음 |

**원칙:** 각 서브 프로젝트와 작업 단위(writing, design)는 자기 작업을 **스스로 열고 스스로 닫습니다.** 서브 프로젝트끼리는 상대 코드를 직접 고치지 않고, **계약 파일**과 **요청함(GitHub Issues)**으로만 주고받습니다.

## 2. 소유권 (누가 어디를 고칠 수 있나)

| 경로 | 소유 | 비고 |
| --- | --- | --- |
| `core/` | core | |
| `server/` | server | |
| `app/` | app | |
| `proto/myungli/engine/`, `proto/buf.yaml` | core | 엔진 gRPC 계약의 제공자 |
| `.github/workflows/<서브 프로젝트 또는 작업 단위>.yml` | 해당 서브 프로젝트·작업 단위 | 예: `writing.yml`(검사기 자체의 CI). server·app이 자기 CI에서 검사기를 실행하는 단계는 server·app 소유 |
| `docs/identity/writing/` | writing | |
| `docs/identity/design/` | design | |
| GitHub Issues | 모두 | 작성은 누구나, 라벨·상태 규칙은 §5.2 |
| `docs/coordination/` | 지휘 | 이관 전 문서 보관소 |
| `README.md`, `CLAUDE.md`(루트), `docs/background/`, `docs/identity/README.md`, `docs/artifacts/`, `docs/decisions.md`, `docs/ideas.md`, `docs/business/`, `docs/roadmap.md`, `docs/contracts/`, `docs/workflow.md`, `.github/workflows/ci-gate.yml`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/`, `tools/` | 지휘 | 서브 프로젝트는 읽기만 하고, 바꿀 일이 있으면 요청함으로 |

## 3. 서브 프로젝트의 작업 주기

1. **시작:** 아래를 읽습니다.
   - 자기 `CLAUDE.md`(현재 상태와 다음 할 일)
   - `docs/roadmap.md`(자기 마일스톤)
   - `docs/contracts/README.md`(쓰고 제공하는 계약)
   - 자기 앞으로 온 열린 Issue: `gh issue list --label to:<단위>`
   - `git fetch origin && git merge origin/main` (§6)
2. **설계:** brainstorming → spec 작성 → 사용자 승인. spec은 `<서브 프로젝트>/docs/specs/YYYY-MM-DD-<주제>-design.md`에 둡니다.
3. **계획:** writing-plans. 계획은 `<서브 프로젝트>/docs/plans/YYYY-MM-DD-<주제>.md`에 둡니다.
4. **구현:** 계획을 실행합니다(subagent-driven 또는 executing-plans).
5. **마무리 (세션이 끝날 때마다, 결론이 나지 않은 작업도):**
   1. `git merge origin/main`
   2. 자기 `CLAUDE.md`의 "현재 상태" 갱신. 제공 계약이 바뀌었으면 버전을 올립니다.
   3. 산출물을 `artifacts/index.json`에 등록(§7)
   4. 관련 Issue 닫기(닫는 조건은 §5.2). 마일스톤을 끝냈으면 `kind:report` Issue로 완료 보고
   5. PR → `ci-gate` 통과 → 병합(§6)

suberpowers skill이 기본으로 쓰는 `docs/suberpowers/specs/`, `docs/suberpowers/plans/` 경로는 쓰지 않습니다. 서브 프로젝트는 위 경로를, 지휘 세션은 `docs/specs/`, `docs/plans/`를 씁니다. 작업 단위는 이미 `docs/` 안에 있으므로 `docs/identity/<writing|design>/specs/`, `plans/`를 씁니다.

## 4. 결정 로그
* **둘 이상의 서브 프로젝트나 제품 전체에 걸친 결정:** `docs/decisions.md` (번호 `D<n>`, 지휘 세션만 기록)
* **한 서브 프로젝트 안의 결정:** `<서브 프로젝트>/docs/decisions.md` (번호 core `C<n>`, server `S<n>`, app `A<n>`). 작업 단위는 `docs/identity/<writing|design>/decisions.md` (번호 writing `W<n>`, design `V<n>`)
* 서브 프로젝트 결정이 루트 결정과 부딪히면 구현을 멈추고 요청함으로 올립니다.
* **번호가 마일스톤 ID와 겹칠 때(D46):** 결정 C1과 마일스톤 C1처럼 글자가 같을 수 있습니다. 문장에서는 "결정 V1", "마일스톤 V1"처럼 종류를 앞에 붙여 씁니다. 표 안에서는 열 이름이 종류를 정하므로 붙이지 않아도 됩니다.

## 5. 계약과 요청함

### 5.1. 계약
* 목록과 상태는 `docs/contracts/README.md`에 있습니다.
* 계약은 **제공하는 쪽만** 바꿉니다. 사용하는 쪽은 요청합니다.
* 하위 호환이 깨지는 변경은 다음 절차를 따릅니다: ① `kind:notice` Issue로 공지 ② 계약 버전 올림 ③ 사용하는 쪽이 대응을 마쳤다고 보고한 뒤 이전 버전 제거.

### 5.2. 요청함: GitHub Issues (D44)
* 브랜치와 상관없이 모든 세션이 같은 목록을 봅니다.
* **여는 법:** 세션(CLI)은 `gh issue create --title "<제목>" --label from:<단위>,to:<단위>,kind:<종류> --milestone <로드맵 ID> --body-file <본문 파일>`. 라벨이 받는 쪽 목록(`gh issue list --label to:<단위>`)을 정하므로 `from`·`to`·`kind`를 빠짐없이 붙입니다. 본문 항목은 무엇이 필요한가(또는 무엇을 했는가)·왜·영향·관련입니다. `.github/ISSUE_TEMPLATE/`의 양식은 웹 화면용입니다(양식의 선택 값은 라벨이 되지 않으므로 웹에서도 라벨을 직접 붙입니다).
* **닫기:** 열린 Issue는 남은 일만 보여야 합니다. 처리했다는 코멘트만 남기고 열어 두지 않습니다. 종류마다 닫는 조건이 있습니다.
  | 종류 | 닫는 때 | 닫는 쪽 |
  | --- | --- | --- |
  | `kind:request` | 요청을 처리한 PR이 병합될 때. PR 본문의 `Closes #<번호>`로 자동으로 닫힙니다 | 받는 쪽 |
  | `kind:notice` | 받는 쪽이 읽고 자기 `CLAUDE.md`(현재 상태·다음 할 일)에 반영했을 때. 반영한 위치를 코멘트로 남깁니다. 지휘 세션이 착수 안내로 받는 쪽 `CLAUDE.md`를 이미 고쳤다면 지휘 세션이 닫습니다. 진행 추적은 로드맵이 맡습니다 | 받는 쪽 |
  | `kind:report` | 지휘 세션이 확인했을 때 | 지휘 |
  | `kind:task` | 작업이 끝났을 때 | 받는 쪽 |
* **받는 쪽에 일을 시키는 공지는 `kind:request`로 엽니다.** 공지(`kind:notice`)는 알리기만 합니다. 수령으로 닫혀도 남은 일이 목록에서 사라지지 않게 하려는 것입니다.
* **일부만 처리했으면** 처리한 부분으로 닫고, 남은 부분은 새 Issue로 엽니다. 새 Issue 번호를 닫는 코멘트에 남깁니다.
* **PR 본문:** 처리한 Issue마다 `Closes #<번호>`를 한 줄씩 적습니다. 처리한 Issue가 없으면 `처리한 Issue: 없음`이라고 적습니다. `ci-gate`의 `pr-body` 검사가 둘 중 하나가 있는지 확인합니다. 일부만 처리한 Issue는 `Closes`가 아니라 `참고 #<번호>`로 적고 위 규칙대로 나눕니다.
* **라벨:** `from:<단위>`, `to:<단위>`(단위: `root`, `core`, `server`, `app`, `writing`, `design`), `kind:request`·`kind:report`·`kind:notice`·`kind:task`, `blocking`(다른 작업을 막음)
* **상태:** 열림 → 지휘 세션이 `accepted` 또는 `rejected` 라벨(거절은 닫음) → 받는 쪽이 처리하고 닫음. 완료 보고(`kind:report`)는 지휘 세션이 확인하고 닫습니다.
* **마일스톤 = 로드맵 ID**(`docs/roadmap.md`). 진행 중인 Issue는 해당 마일스톤에 붙입니다.
* **코드가 아닌 지속 작업**(검수 라운드, 콘텐츠, 시안 반복)도 `kind:task` Issue로 엽니다.
* **결정은 git에:** Issue에서 정한 결정은 결정 로그(§4)에 적고, 그 번호를 Issue에 남깁니다.
* `docs/coordination/`은 이관 전(2026-10-10) 문서의 보관소입니다. 새 문서는 만들지 않습니다.

## 6. Git
* 저장소: `june20516/myungli-diary` (모노레포, D33).
* **`main` 중심, 짧은 브랜치 (D44):** 브랜치는 마일스톤 하나나 task 몇 개 단위로 짧게 씁니다. 이름은 `<단위>/<주제>`(예: `core/engine-mvp`, `writing/rounds-2026-10-11`). 지휘 세션은 `root/<주제>`.
* **세션 시작:** `git fetch origin && git merge origin/main`.
* **계약 먼저 병합:** 다른 단위가 기대는 계약(proto, `message_keys.json`, 디자인 토큰, IA, 슬롯 명세, 호칭·조사 규칙, REST API 명세)이 확정되면, 구현 브랜치 전체를 기다리지 않고 **계약 파일만 담은 작은 PR**로 먼저 `main`에 넣습니다.
* **병합:** 모든 변경은 PR → `ci-gate` 통과 → merge commit으로 합칩니다. 지휘 세션 문서도 같습니다. **`main`에 직접 push하지 않습니다**(D43: 무료 비공개 플랜이라 보호 규칙이 강제되지 않으므로 규약으로 지키고, `ci-gate`가 `main` push에서도 돌아 사후에 잡습니다).
* 브랜치를 만들 때 공용 원격 브랜치를 upstream으로 걸지 않습니다. 예: `git worktree add ../myungli-diary-core -b core/<주제> --no-track origin/main`. 만든 직후 `git status -sb`로 확인합니다.
* push는 대상 브랜치를 명시합니다: `git push -u origin <브랜치>`.
* commit 메시지의 범위 표기: `feat(core): …`, `fix(server): …`, `docs(root): …`.
* **같은 작업 디렉터리에서 세션 두 개를 동시에 돌리지 않습니다.** 그래서 디렉터리를 단위마다 하나씩 고정해 둡니다.
  | 디렉터리 | 쓰는 세션 |
  | --- | --- |
  | `myungli-diary` (본 저장소) | 지휘 |
  | `../myungli-diary-<단위>` (`git worktree`) | core, server, app, writing, design |
* **단위의 worktree는 한 번 만들고 재사용합니다.** 브랜치가 병합되면 디렉터리를 새로 만들지 않고 그 안에서 브랜치만 바꿉니다: `git fetch origin && git switch -c <단위>/<주제> --no-track origin/main && git push -u origin <단위>/<주제>`. 단위의 worktree가 아직 없을 때만 `git worktree add ../myungli-diary-<단위> -b <브랜치> --no-track origin/main`으로 만듭니다.
* **착수 안내는 한 덩어리 명령으로 적습니다.** 그 디렉터리가 지금 어느 브랜치에 있든 따라 할 수 있게, `cd ../myungli-diary-<단위>` → 위의 브랜치 바꾸기(없으면 worktree 만들기) → `cd <시작 디렉터리> && claude` 순서로 씁니다. 다른 단위 브랜치 위에 쌓아야 하면 `origin/main`에서 딴 뒤 그 브랜치를 `git merge`합니다.
* 릴리스 태그에는 접두어를 붙입니다: `core/v1.0.0`.

## 7. 시각 산출물 (`artifacts/`)
지휘 세션이 만드는 **제품 지도**(비공개 claude.ai 페이지)는 각 `artifacts/index.json`을 읽어 그립니다. 시안·컨셉·스크린샷 같은 시각 산출물은 다음 규칙으로 저장소에 쌓습니다. (2026-10-10 임시 확정. 지도 화면과 갱신 절차는 협업 워크플로 spec에서 정합니다.)

* **위치:** 자기 소유 경로 안의 `artifacts/`
  | 소유 | 위치 |
  | --- | --- |
  | 지휘 | `docs/artifacts/` |
  | design | `docs/identity/design/artifacts/` |
  | writing | `docs/identity/writing/artifacts/` |
  | app | `app/docs/artifacts/` (화면 스크린샷) |
* **파일 이름:** `YYYY-MM-DD-<짧은 이름>.<png|svg|webp|html|pdf>`. HTML 시안에는 같은 이름의 PNG를 함께 둡니다(GitHub에서 보이도록).
* **목록:** 같은 디렉터리의 `index.json`(JSON 배열). 예시는 `docs/artifacts/index.json`입니다.
  * 필드: `id`, `title`, `kind`(`concept`·`mockup`·`component`·`screenshot`·`token-sheet`·`copy-sample`), `file`, `source`(선택), `date`, `milestone`, `screens`(IA 화면 id, IA 전에는 빈 배열), `decisions`, `status`(`draft`·`chosen`·`rejected`·`superseded`), `note`(한 줄)
* **탈락한 시안도 지우지 않고** `status: rejected`로 남깁니다.
* **용량:** 이미지 한 장 2MB 이하. Git LFS는 쓰지 않습니다.

## 8. 운영 확장 메모
지금은 도입하지 않고, 아래 시점에 도입합니다(협업 워크플로 spec §4.2).

| 항목 | 도입 기준 |
| --- | --- |
| merge queue | 동시에 열린 PR끼리 병합 순서 충돌이 잦아질 때 |
| 서비스 간 통합 테스트(docker compose로 server ↔ core gRPC 실호출) | I1 시점에 `ci-gate`에 추가 |
| 배포 파이프라인(환경별 시크릿, 접두어 태그 릴리스) | 배포 플랫폼 결정 뒤(S1) |
| iOS 빌드 | A1·I4. 로컬 Mac 또는 자체 러너. 호스티드 macOS는 분 단위 비용 10배 |
| 의존성 자동 갱신(Dependabot) | MVP 안정화 뒤 |
| slow 테스트 경로 조건 | core에 요청됨(Issue #5) |
| 단위 workflow를 `ci-gate`에 연결 | 각 단위가 `workflow_call`을 지원할 때(core는 Issue #9) |
| `main` 보호 규칙 강제 | Pro 전환 또는 공개 전환 시 `ci-gate`를 필수 검사로 지정 |


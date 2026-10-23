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
| `.github/workflows/deploy-*.yml` | server | 엔진 배포(`deploy-engine.yml`)도 server 소유. 엔진 이미지와 실행 조건은 core 소유(D65) |
| `docs/identity/writing/` | writing | |
| `docs/identity/design/` | design | |
| GitHub Issues | 모두 | 작성은 누구나, 라벨·상태 규칙은 §5.2 |
| `docs/coordination/` | 지휘 | 이관 전 문서 보관소 |
| `README.md`, `CLAUDE.md`(루트), `docs/identity/README.md`, `docs/artifacts/`, `docs/decisions.md`, `docs/research/`, `docs/roadmap.md`, `docs/contracts/`, `docs/ia/`, `docs/legal/`, `docs/specs/`, `docs/plans/`, `docs/workflow.md`, `.github/workflows/ci-gate.yml`, `.github/workflows/pr-body.yml`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/`, `tools/` | 지휘 | 서브 프로젝트는 읽기만 하고, 바꿀 일이 있으면 요청함으로. 예외: `docs/contracts/README.md` 표에서 **자기가 제공하는 계약의 행**은 주는 쪽이 계약 PR에서 직접 고치거나 새로 넣습니다. 새 계약 파일이 받는 쪽 검사와 맞물리면 `ci-gate`의 drift 경로에 넣어 달라고 지휘에게 요청합니다. 표의 열 구성과 표 밖 내용은 지휘가 합니다 |
| 단위의 `CLAUDE.md` | 해당 단위 | 지휘는 착수 안내나 공통 규약 정리 때만 고치고 PR 본문에 적습니다 |

## 3. 서브 프로젝트의 작업 주기

1. **시작:** 아래를 읽습니다.
   - 자기 `CLAUDE.md`(현재 상태와 다음 할 일)
   - `docs/roadmap.md`(자기 마일스톤)
   - `docs/contracts/README.md`(쓰고 제공하는 계약)
   - `git fetch origin && git merge origin/main` (§6)
   - 자기 앞으로 온 열린 Issue: `gh issue list --label to:<단위>`. `drift` 라벨이 있으면 다른 일보다 먼저 합니다(§6.1)
2. **설계:** brainstorming → spec 작성 → 사용자 승인. spec은 `<서브 프로젝트>/docs/specs/YYYY-MM-DD-<주제>-design.md`에 둡니다.
3. **계획:** writing-plans. 계획은 `<서브 프로젝트>/docs/plans/YYYY-MM-DD-<주제>.md`에 둡니다.
4. **구현:** 계획을 실행합니다(subagent-driven 또는 executing-plans).
5. **마무리 (세션이 끝날 때마다, 결론이 나지 않은 작업도):**
   1. `git merge origin/main`
   2. 자기 `CLAUDE.md`의 "현재 상태"·"다음 할 일" 갱신. 제공 계약이 바뀌었으면 `docs/contracts/README.md`의 자기 행 버전·상태를 같은 PR에서 고칩니다(지휘에게 따로 요청하지 않습니다).
   3. 산출물을 `artifacts/index.json`에 등록(§7)
   4. 관련 Issue 닫기(닫는 조건은 §5.2). 마일스톤을 끝냈으면 `kind:report` Issue로 완료 보고
   5. 공개 저장소 확인(D74): 바뀐 파일·PR 본문·Issue에 가격·수익 수치나 비공개 저장소 경로 링크가 없는지
   6. PR → `ci-gate` 통과 → 사용자가 병합(§6)

suberpowers skill이 기본으로 쓰는 `docs/suberpowers/specs/`, `docs/suberpowers/plans/` 경로는 쓰지 않습니다. 서브 프로젝트는 위 경로를, 지휘 세션은 `docs/specs/`, `docs/plans/`를 씁니다. 작업 단위는 이미 `docs/` 안에 있으므로 `docs/identity/<writing|design>/specs/`, `plans/`를 씁니다.

## 4. 결정 로그
* **둘 이상의 서브 프로젝트나 제품 전체에 걸친 결정:** `docs/decisions.md` (번호 `D<n>`, 지휘 세션만 기록)
* **한 서브 프로젝트 안의 결정:** `<서브 프로젝트>/docs/decisions.md` (번호 core `C<n>`, server `S<n>`, app `A<n>`). 작업 단위는 `docs/identity/<writing|design>/decisions.md` (번호 writing `W<n>`, design `V<n>`)
* 서브 프로젝트 결정이 루트 결정과 부딪히면 구현을 멈추고 요청함으로 올립니다.
* **사용자에게 보이는 동작은 루트를 거칩니다(D87).** 단위 결정이 보관·복구·한도·자동 상태 변화·사용자 선택·안내가 필요한 상태·개인정보 수집이나 보관을 새로 정하면, 부딪히지 않아도 `to:root` Issue로 올립니다. 지휘가 루트 결정·IA·원고 요청·수집·보관 대장(`docs/legal/data-inventory.md`)에 반영합니다.
* **`사용자 영향` 표시(D87):** 2026-10-24 이후 단위 결정 표에 쓰는 행은 근거 칸에 `사용자 영향: 없음`, `사용자 영향: D<n>`(이미 반영된 루트 결정), `사용자 영향: #<n>`(올린 Issue) 중 하나를 적습니다. 없으면 `docs-check`가 실패합니다.
* **번호가 마일스톤 ID와 겹칠 때(D46):** 결정 C1과 마일스톤 C1처럼 글자가 같을 수 있습니다. 문장에서는 "결정 V1", "마일스톤 V1"처럼 종류를 앞에 붙여 씁니다. 표 안에서는 열 이름이 종류를 정하므로 붙이지 않아도 됩니다.

## 5. 계약과 요청함

### 5.1. 계약
* 목록과 상태는 `docs/contracts/README.md`에 있고, 버전의 기준은 이 표 하나입니다. 단위 `CLAUDE.md`의 계약 표는 역할(제공·사용)과 상대만 적습니다.
* 계약은 **제공하는 쪽만** 바꿉니다. 사용하는 쪽은 요청합니다. 제공하는 쪽은 계약 PR에서 위 표의 자기 행도 함께 고칩니다(§2).
* 하위 호환이 깨지는 변경은 다음 절차를 따릅니다: ① 사용하는 쪽마다 `kind:request` Issue로 알림(대응해야 하는 일이라 request, D78) ② 계약 버전 올림 ③ 사용하는 쪽이 대응을 마쳤다고 보고한 뒤 이전 버전 제거. 대응이 필요 없는 고지만 `kind:notice`입니다.

### 5.2. 요청함: GitHub Issues (D44)
* 브랜치와 상관없이 모든 세션이 같은 목록을 봅니다.
* **여는 법:** 세션(CLI)은 `gh issue create --title "<제목>" --label from:<단위>,to:<단위>,kind:<종류> --milestone <로드맵 ID> --body-file <본문 파일>`. 라벨이 받는 쪽 목록(`gh issue list --label to:<단위>`)을 정하므로 `from`·`to`·`kind`를 빠짐없이 붙입니다. 본문 항목은 무엇이 필요한가(또는 무엇을 했는가)·왜·영향·관련입니다. `.github/ISSUE_TEMPLATE/`의 양식은 웹 화면용입니다(양식의 선택 값은 라벨이 되지 않으므로 웹에서도 라벨을 직접 붙입니다).
* **닫기:** 열린 Issue는 남은 일만 보여야 합니다. 처리했다는 코멘트만 남기고 열어 두지 않습니다. 종류마다 닫는 조건이 있습니다.
  | 종류 | 닫는 때 | 닫는 쪽 |
  | --- | --- | --- |
  | `kind:request` | 요청을 처리한 PR이 병합될 때. PR 본문의 `Closes #<번호>`로 자동으로 닫힙니다 | 받는 쪽 |
  | `kind:notice` | 받는 쪽이 읽고 자기 `CLAUDE.md`(현재 상태·다음 할 일)에 반영했을 때. 반영한 위치를 코멘트로 남깁니다. 지휘 세션이 착수 안내로 받는 쪽 `CLAUDE.md`를 이미 고쳤다면 지휘 세션이 닫습니다. 진행 추적은 로드맵이 맡습니다 | 받는 쪽 |
  | `kind:report` | 지휘 세션이 확인했을 때 | 지휘 |
  | (모든 종류) | 처리했다는 코멘트만 남고 열려 있을 때 | 지휘가 대신 닫을 수 있음(D78). 받는 쪽에 닫아 달라고 남겨도 됩니다 |
  | `kind:task` | 작업이 끝났을 때 | 받는 쪽 |
* **받는 쪽에 일을 시키는 공지는 `kind:request`로 엽니다.** 공지(`kind:notice`)는 알리기만 합니다. 수령으로 닫혀도 남은 일이 목록에서 사라지지 않게 하려는 것입니다.
* **일부만 처리했으면** 처리한 부분으로 닫고, 남은 부분은 새 Issue로 엽니다. 새 Issue 번호를 닫는 코멘트에 남깁니다.
* **PR 본문:** 처리한 Issue마다 `Closes #<번호>`를 한 줄씩 적습니다(문장 안에 있어도 GitHub과 검사 모두 인정합니다). 처리한 Issue가 없으면 `처리한 Issue: 없음`이라고 적습니다. `pr-body` 검사(`ci-gate`와 나란한 필수 검사, D81)가 둘 중 하나가 있는지 확인합니다. 본문만 고치면 `pr-body`만 다시 돕니다. 일부만 처리한 Issue는 `Closes`가 아니라 `참고 #<번호>`로 적고 위 규칙대로 나눕니다. `pr-body` 검사는 `Closes`, `참고 #`, `처리한 Issue: 없음` 가운데 하나를 요구합니다(D78 ③).
* **라벨:** `from:<단위>`, `to:<단위>`(단위: `root`, `core`, `server`, `app`, `writing`, `design`), `kind:request`·`kind:report`·`kind:notice`·`kind:task`, `blocking`(다른 작업을 막음)
* **상태:** 열림 → 지휘 세션이 `accepted` 또는 `rejected` 라벨(거절은 닫음) → 받는 쪽이 처리하고 닫음. 완료 보고(`kind:report`)는 지휘 세션이 확인하고 닫습니다.
* **마일스톤 = 로드맵 ID**(`docs/roadmap.md`). 진행 중인 Issue는 해당 마일스톤에 붙입니다. `ci-gate`가 자동으로 여는 `drift` Issue는 마일스톤 없이 열리고, `accepted`는 지휘가 정기 일과에서 붙입니다.
* **코드가 아닌 지속 작업**(검수 라운드, 콘텐츠, 시안 반복)도 `kind:task` Issue로 엽니다.
* **결정은 git에:** Issue에서 정한 결정은 결정 로그(§4)에 적고, 그 번호를 Issue에 남깁니다.
* `docs/coordination/`은 이관 전(2026-10-10) 문서의 보관소입니다. 새 문서는 만들지 않습니다.

### 5.3. 외부 준비물 (D91 ②)
* 사용자만 할 수 있는 외부 계정·설정·서류는 대장 [`docs/external-prep.md`](external-prep.md) 하나로 관리합니다. 고치는 쪽은 지휘입니다.
* 단위가 외부 값이나 계정이 필요해지면 `to:root`·`kind:prep` Issue로 올립니다. 사용자에게 직접 묻지 않습니다.
* 지휘는 때가 된 항목마다 `to:user`·`kind:prep` Issue를 열어 절차(공식 문서 출처 포함)와 넘길 값을 적습니다. 공개 값은 그 Issue 코멘트로 받고, 비밀 값은 사용자가 Issue에 적힌 곳에 직접 넣습니다. 비밀 값은 저장소·Issue·대화에 붙이지 않습니다.
* 받은 값은 지휘가 쓰는 단위의 Issue로 전달하고, 대장의 상태를 고친 뒤 `kind:prep` Issue를 닫습니다.

## 6. Git
* 저장소: `june20516/myungli-diary` (모노레포, D33).
* **`main` 중심, 짧은 브랜치 (D44):** 브랜치는 마일스톤 하나나 task 몇 개 단위로 짧게 씁니다. 이름은 `<단위>/<주제>`(예: `core/engine-mvp`, `writing/rounds-2026-10-11`). 지휘 세션은 `root/<주제>`.
* **세션 시작:** `git fetch origin && git merge origin/main`.
* **계약 먼저 병합:** 다른 단위가 기대는 계약(proto, `message_keys.json`, 디자인 토큰, IA, 슬롯 명세, 호칭·조사 규칙, REST API 명세)이 확정되면, 구현 브랜치 전체를 기다리지 않고 **계약 파일만 담은 작은 PR**로 먼저 `main`에 넣습니다. 받는 쪽 검사는 이 PR에서 경고만 내고(§6.1), 받는 쪽이 다음 PR에서 따라잡습니다. **예외(D78):** 설명·주석만 바뀌고 동작이 같은 계약 변경은 구현 PR에 함께 담아도 됩니다(예: REST draft.7, S64).
* **병합:** 모든 변경은 PR → `ci-gate` 통과 → merge commit으로 합칩니다. 단위 PR은 사용자가, 지휘의 `root/` PR은 지휘가 병합합니다. **`main`에 직접 push하지 않습니다**(D43). 보호 규칙은 아직 걸지 않아 규약으로 지키고, `ci-gate`가 `main` push에서도 돌아 사후에 잡습니다(공개 전환 뒤 보호 규칙은 §8).
* 브랜치를 만들 때 공용 원격 브랜치를 upstream으로 걸지 않습니다. 예: `git worktree add ../myungli-diary-core -b core/<주제> --no-track origin/main`. 만든 직후 `git push -u origin <브랜치>`로 같은 이름의 원격을 추적하게 하고 `git status -sb`로 확인합니다.
* push는 대상 브랜치를 명시합니다: `git push -u origin <브랜치>`.
* commit 메시지의 범위 표기: `feat(core): …`, `fix(server): …`, `docs(root): …`.
* **같은 작업 디렉터리에서 세션 두 개를 동시에 돌리지 않습니다.** 그래서 디렉터리를 단위마다 하나씩 고정해 둡니다.
  | 디렉터리 | 쓰는 세션 |
  | --- | --- |
  | `myungli-diary` (본 저장소) | 지휘 |
  | `../myungli-diary-<단위>` (`git worktree`) | core, server, app, writing, design |
  | `../myungli-diary-internal` (**별도 비공개 저장소**, worktree 아님) | 지휘만. 수익화 기록·아이디어 함·제품 배경 원문(D74). 공개 저장소는 이곳을 링크하거나 CI에서 읽지 않습니다 |
* **단위의 worktree는 한 번 만들고 재사용합니다.** 브랜치가 병합되면 디렉터리를 새로 만들지 않고 그 안에서 브랜치만 바꿉니다: `git fetch origin && git switch -c <단위>/<주제> --no-track origin/main && git push -u origin <단위>/<주제> && git status -sb`. 단위의 worktree가 아직 없을 때만 `git worktree add ../myungli-diary-<단위> -b <브랜치> --no-track origin/main && cd ../myungli-diary-<단위> && git push -u origin <브랜치> && git status -sb`로 만듭니다.
* **착수 안내는 한 덩어리 명령으로 적습니다.** 그 디렉터리가 지금 어느 브랜치에 있든 따라 할 수 있게, `cd ../myungli-diary-<단위>` → 위의 브랜치 바꾸기(없으면 worktree 만들기) → `cd <시작 디렉터리> && claude` 순서로 씁니다. 다른 단위 브랜치 위에 쌓아야 하면 `origin/main`에서 딴 뒤 그 브랜치를 `git merge`합니다.
* 릴리스 태그에는 접두어를 붙입니다: `core/v1.0.0`.

### 6.1 단위 간 맞물림 (drift)
계약을 주는 쪽과 받는 쪽이 맞물리는지는 **통합 수준의 검사**입니다. 주는 쪽 PR에서 받는 쪽이 이미 맞춰져 있기를 요구하면, 주는 쪽은 자기 소유가 아닌 코드 때문에 병합하지 못합니다. 그래서 `ci-gate`는 검사를 셋으로 나눠 언제 막을지 다르게 둡니다.

| 검사 | 예 | 주는 쪽 PR | 받는 쪽 PR | `main` |
| --- | --- | --- | --- | --- |
| 자기 코드 | 각 단위의 테스트·린트 | 막음 | 막음 | 막음 |
| 계약 자체의 유효성 | REST 생성·계약 테스트(server), `buf breaking`(core, PR에서만 비교), docs 검사(IA·근거 용어집) | 막음 | - | 막음 |
| 단위 간 맞물림 | app 생성 코드 차이·ARB, writing의 IA 대조, server의 슬롯 대조, design의 IA 대조·라운드 원고 글자 수 | **경고** | 막음 | 돌지 않음 |

* **판별:** PR이 그 단위의 소유 경로(또는 그 단위 workflow)를 바꿨으면 그 단위 검사는 `own`이라 실패하면 막습니다. 그 단위가 쓰는 계약 파일만 바뀌었으면 `drift`라 실패해도 판정에서 빼고 경고로 남깁니다. 그 단위의 소유·계약 경로는 바뀌지 않았고 `ci-gate.yml`이 바뀌었으면 `gate`입니다. 실패하면 막지만, 그 단위 앞으로 열린 `drift` Issue가 있으면 알려진 실패로 보고 경고만 남깁니다. 단위들이 병렬로 일하는 동안 drift가 0이 되는 때는 드물어, workflow 수정이 그때를 기다리지 않게 하려는 것입니다.
* **과정 문서:** writing·design의 `CLAUDE.md`·`decisions.md`·`specs/`·`plans/`·`artifacts/`는 자기 검사기가 읽지 않아 그 단위 검사를 고르지 않습니다(writing `artifacts/`의 라운드 원고는 design 검사가 읽으므로 design에는 계약입니다)(core·server·app은 `.md`만 바뀌면 고르지 않습니다). 그래서 지휘가 단위 `CLAUDE.md`를 고쳐도 그 단위의 열린 drift에 막히지 않습니다.
* **따라잡기:** `drift`가 실패하면 `ci-gate`가 받는 쪽 앞으로 `drift` 라벨 Issue(`[drift] <단위>: PR #N 계약 변경 따라잡기`)를 엽니다. 그 단위 앞으로 열린 `drift` Issue가 이미 있으면 새로 열지 않고, 가장 오래된 Issue 본문에 `* 더해진 원인: PR #M(…)` 줄을 더하고 코멘트로 알립니다(단위마다 열린 drift는 하나, 로직은 `tools/drift/drift.sh`). 받는 쪽은 **다음 PR에서** 맞춥니다. 맞추지 않으면 그 단위의 PR은 `own`으로 막히므로 다른 일보다 먼저 합니다. 맞춘 PR 본문에는 `Closes`가 아니라 `참고 #<drift Issue>`를 적습니다. drift Issue는 아래처럼 `drift-close`가 닫습니다. `Closes`로 닫으면 아직 따라잡지 않은 더해진 원인이 함께 사라집니다(PR #512가 원인 PR #511 몫을 남긴 채 #480을 닫은 일, 2026-10-23). 주는 쪽이 같은 PR 안에서 고쳐 다음 실행의 drift가 통과하면 `drift-report`가 그 Issue를 닫습니다. `main` push에서는 drift를 돌리지 않습니다(결과를 판정에도 Issue에도 쓰지 않으므로). `main` push에서 그 단위 검사가 통과하면 `ci-gate`(`drift-close` job)가 그 단위 앞 drift Issue를 닫습니다. 그 커밋에서 통과했다는 것이 곧 그 커밋의 계약을 모두 따라잡았다는 뜻이기 때문입니다. 단, 원인 PR(제목과 더해진 원인 모두)이 그 커밋에 들어 있는 Issue만 닫습니다(원인 PR이 열린 채 다른 PR이 먼저 병합되거나, 예전 실행을 다시 돌린 경우를 거릅니다). 병합 없이 닫힌 원인 PR은 따라잡을 것이 없으므로 셈에서 빼고, 원인 PR이 모두 병합 없이 닫혔으면 이후 `main`에서 그 단위 검사가 통과할 때 not planned로 닫습니다(그 단위 검사가 돌지 않으면 남습니다). 주는 쪽이 같은 PR 안에서 고친 경우 `drift-report`는 그 PR이 연 Issue를 닫되, 다른 원인이 더해진 Issue는 남깁니다.
* **통합 시점:** 통합 마일스톤(I1~I4)은 열린 `drift` Issue가 0이어야 시작합니다. 지휘는 정기 일과에서 `drift` Issue를 확인합니다.
* **계약 변경의 조건:** 주는 쪽은 계약만 먼저 병합할 수 있지만, 하위 호환을 깨는 변경은 §5.1대로 사용하는 쪽마다 `kind:request`로 알립니다(D78). REST는 S3 freeze 뒤에는 추가 변경만 합니다.
* **쌓아서 함께 병합하기**(예: IA v2 #133 → #138 → #149)는 더 이상 기본이 아닙니다. 각 단위 PR을 순서대로 병합하고 받는 쪽이 drift를 따라잡습니다. 계약과 받는 쪽 구현이 한 번에 바뀌어야 의미가 맞는 경우(하위 호환을 깨는 변경 등)에만 쌓습니다.

### 6.2 검사 범위와 시점 (D81)
검사가 쌓일수록 바뀐 것과 상관없는 검사가 자원과 시간을 씁니다. 검사는 **변경에 맞는 범위**만, **작업 단계에 맞는 시점**에 돌립니다.

* **범위:** `ci-gate`는 단위 workflow에 `mode` 입력(`own`·`drift`·`gate`)을 넘깁니다. `own`은 그 단위의 빠른 검사 전체, `drift`·`gate`는 계약을 읽는 검사(생성 코드 대조, 계약 테스트, IA·원고 대조)만 돕니다. 어느 단계가 계약 검사인지는 각 단위가 자기 workflow에서 정합니다. app의 Android 디버그 빌드는 `own`에서만 돕니다.
* **캐시·건너뛰기:** 캐시와 "이번엔 안 돌린다"는 판단(경로로 고르기, 테스트 결과 재사용, 메모리 fixture)은 세 가지를 함께 정합니다.
  1. **키:** 결과를 바꾸는 입력(도구·언어 버전, lockfile, 설정, 생성기, runner OS, 검사가 읽는 파일)을 모두 넣습니다.
  2. **쓰지 않는 때:** 정기·수동 실행은 캐시와 건너뛰기 없이 새로 돌립니다. 추적되지 않는 외부 입력(Docker 이미지, DB, 네트워크)에 기대는 검사는 결과를 재사용하지 않습니다.
  3. **깨졌을 때:** 복원이 실패하거나 일부만 복원돼도 결과가 같아야 합니다(캐시는 속도만 바꿈). 저장은 `main` 실행에서 하는 것이 기본입니다.
* **비교 기준:** PR은 merge ref의 first parent(검사 시점의 `main`)와 비교합니다. PR을 연 뒤 `main`에 들어온 다른 PR의 파일을 바뀐 것으로 잡지 않기 위해서입니다.
* **시점:**

  | 단계 | 무엇을 | 어디서 |
  | --- | --- | --- |
  | 반복 중 | 바뀐 범위의 테스트(단위가 빠른 경로 명령을 둠). 기기 E2E는 바꾼 흐름의 테스트 파일만 | 로컬 |
  | PR | `own`·`drift`·`gate` 범위, `pr-body`(본문만 고치면 이것만) | `ci-gate`·`pr-body` |
  | `main` push | `own`·`gate`만 한 번. 단위 workflow의 push 트리거로 같은 검사를 다시 돌리지 않습니다. `main`에서만 의미 있는 검사(기기 E2E 등)는 예외입니다 | `ci-gate`, 단위 workflow |
  | 정기 | 느린 검사(외부 API 대조·보정·property 전체·기기 E2E 전체) | 단위 workflow `schedule` |
  | 전체 확인 | 모든 단위 `own` | `ci-gate` 수동 실행 |

## 7. 시각 산출물 (`artifacts/`)
지휘 세션이 만드는 **제품 지도**(비공개 claude.ai 페이지, 갱신 절차는 `tools/product-map/README.md`)는 각 `artifacts/index.json`을 읽어 그립니다. 시안·컨셉·스크린샷 같은 시각 산출물은 다음 규칙으로 저장소에 쌓습니다.

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
| `main` 보호 규칙 강제 | 공개 전환(D74)으로 조건이 됐습니다. `ci-gate`를 필수 검사로 지정할지 사용자가 정합니다 |


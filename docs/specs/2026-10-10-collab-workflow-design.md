# 협업 워크플로·브랜치 전략·제품 지도 — 설계

* 작성: 지휘 세션, 2026-10-10
* 상태: 승인 (2026-10-10)
* 관련 결정: D33, D35, D38, D43~D45 (이 spec에서 정함)
* 먼저 확정해 반영한 것: 시각 산출물 규칙(`docs/workflow.md` §7, 2026-10-10)

## 1. 목적

1. **기다림과 전달 누락을 없앱니다.** 이번 엔진 작업에서 실제로 겪은 문제입니다.
   * 동결된 계약(proto v1)이 core 브랜치에 갇혀 server가 쓸 수 없었습니다.
   * 요청함 문서가 브랜치를 따라다녀 상대 세션에 보이지 않았습니다.
   * 오래 산 브랜치가 `main`보다 뒤처졌습니다.
   * 병합 방식이 세션마다 달랐고, CI 검증 범위도 일정하지 않았습니다.
2. **운영 시점의 CI 문제를 미리 다집니다.** 지금 다질 것과, 나중에 도입할 시점을 기록해 둘 것을 나눕니다.
3. **코드가 아닌 작업도 같은 흐름으로 굴립니다.** 검수 라운드, 콘텐츠, 시안, 결정 관리가 대상입니다.
4. **제품 지도를 만듭니다.** 바이브코딩 중에 제품과의 감각적 연결이 흐려질 때, 시각적인 지도로 위치를 다시 잡고 몰입을 이어 가게 합니다. 나중에는 포트폴리오로 이어집니다.

## 2. 저장소 공개 범위 (D43)

* 저장소는 **비공개**입니다(2026-10-10 전환, 무료 플랜). 필요하면 언제든 공개로 돌립니다.
* 전환 전 공개 기간에 commit된 내용(기획·설계·코드)은 이미 노출됐을 수 있습니다. 시크릿은 commit된 적이 없습니다.
* 무료 비공개 플랜의 제약과 대응:
  | 제약 | 대응 |
  | --- | --- |
  | `main` 보호 규칙을 강제할 수 없음 | 규약으로 PR만 씁니다. `ci-gate`를 `main` push에서도 돌려 직접 push를 사후에 잡습니다. 필수 검사 이름을 `ci-gate` 하나로 고정해, Pro나 공개 전환 시 보호 규칙만 켜면 되게 합니다 |
  | Actions 월 2,000분, macOS 러너는 10배로 계산 | Linux CI는 충분합니다. iOS 빌드는 로컬 Mac이나 자체 러너로 합니다(§4.3) |

## 3. 브랜치 전략 (D44)

**`main` 중심, 짧은 브랜치, 계약 먼저 병합.**

* **브랜치 수명:** 마일스톤 하나나 task 몇 개 단위로 짧게 씁니다. 이름은 `<단위>/<주제>`이고, 단위는 `root`, `core`, `server`, `app`, `writing`, `design`입니다. 반복 작업은 날짜를 붙입니다(예: `writing/rounds-2026-10-11`).
* **분기와 추적:** `origin/main`에서 `--no-track`으로 만들고, worktree 안에서 시작합니다(§6 기존 규칙).
* **세션 시작 시:** `git fetch origin && git merge origin/main`.
* **계약 먼저 병합:** 다른 단위가 기대는 계약이 확정되면, 구현 브랜치 전체를 기다리지 않습니다. **계약 파일만 담은 작은 PR**로 먼저 `main`에 넣습니다.
  * 대상: proto, `message_keys.json`, 디자인 토큰, IA, 슬롯 명세, 호칭·조사 규칙, REST API 명세.
  * 쓰는 쪽은 `main`에서 받아 갑니다.
* **병합:** 모든 변경은 PR로 합칩니다. 지휘 세션 문서도 같습니다. 병합 방식은 merge commit입니다(브랜치 이력 보존).
* **쓰지 않는 방식:** 통합 브랜치(`develop`)와 다른 단위의 브랜치에서 분기하는 방식(stacked)은 쓰지 않습니다.

## 4. CI 기반

### 4.1. 지금 만드는 것
1. **`ci-gate` workflow (지휘 소유, `.github/workflows/ci-gate.yml`)**
   * 모든 PR과 `main` push에서 항상 돕니다.
   * 바뀐 경로를 판별한 뒤, 해당하는 단위의 검사를 호출하고 결과를 모아 하나의 판정을 냅니다.
   * 경로 필터 때문에 필수 검사가 "대기"에 멈추는 문제를 막습니다.
   * 필수 검사는 이것 하나입니다.
2. **경로와 검사의 대응 (계약 경로는 양쪽 모두)**
   | 바뀐 경로 | 도는 검사 |
   | --- | --- |
   | `core/**` | core |
   | `proto/**` | core, server (생성 코드 일치 검사 포함) |
   | `server/**` | server |
   | `app/**` | app |
   | `docs/identity/design/tokens/**` | design 검사, app |
   | `docs/identity/writing/**`(슬롯 명세·검사기) | writing 검사, server, app |
   | `**/*.md`, `**/artifacts/**` | docs |
   * 아직 없는 단위(server·app·writing·design 검사)는 해당 단위가 자기 workflow를 만들 때 연결합니다. 그때까지 `ci-gate`는 그 경로를 통과로 처리합니다.
3. **서비스 workflow의 호출 방식:** 각 단위 workflow는 `workflow_call`로 호출할 수 있게 둡니다. job 이름은 `<단위>-<검사>` 규칙을 따릅니다(예: `core-check`, `core-proto`). `core.yml`의 전환은 core에 요청합니다.
   * **전환 규칙 (3단계, 검사가 비는 구간이 없게):** ① 단위가 `workflow_call`만 더합니다(기존 트리거를 유지). ② 지휘가 `ci-gate`에 그 단위의 경로와 `uses:` job을 연결합니다. ③ 단위가 `pull_request`·`push` 트리거를 지웁니다(`schedule`·`workflow_dispatch`는 유지). ①~② 사이에는 검사가 두 번 돌 수 있지만, 검사가 하나도 돌지 않는 구간은 생기지 않습니다. 전환 전까지 `ci-gate`는 그 단위를 판정에 넣지 않습니다.
4. **docs 검사 (`ci-gate` 안, 지휘 소유)**
   * 상대 경로 링크 검사
   * 모든 `artifacts/index.json`의 형식 검사: 필수 필드, `kind`·`status` 값, 가리키는 파일 존재
   * 결정 번호 중복 검사(D·C·S·A·W·V)
   * 스크립트는 `tools/docs-check/`에 둡니다.
5. **이전 실행 자동 취소:** 같은 PR의 앞선 실행을 취소합니다(`concurrency`).
6. **PR 템플릿 (`.github/pull_request_template.md`):** 단위, 관련 Issue·결정, 바꾼 계약(있으면 계약 PR인지), 스크린샷(`artifacts/` 항목), 확인 방법.

### 4.2. 운영 확장 메모 (지금은 기록만, `docs/workflow.md`에 둠)
| 항목 | 도입 기준 |
| --- | --- |
| merge queue | 동시에 열린 PR끼리 병합 순서 충돌이 잦아질 때 |
| 서비스 간 통합 테스트(docker compose로 server ↔ core gRPC 실호출) | I1 시점에 `ci-gate`에 추가 |
| 배포 파이프라인(환경별 시크릿, 접두어 태그 릴리스) | 배포 플랫폼 결정 뒤(S1) |
| iOS 빌드 | A1·I4. 로컬 Mac 또는 자체 러너. 호스티드 macOS는 분 단위 비용 10배 |
| 의존성 자동 갱신(Dependabot) | MVP 안정화 뒤 |
| slow 테스트 경로 조건 | core에 요청됨(`2026-10-10-root-to-core-engine-mvp-feedback.md`) |
| `main` 보호 규칙 강제 | Pro 전환 또는 공개 전환 시 `ci-gate`를 필수로 지정 |

## 5. 요청함과 지속 작업 추적: GitHub Issues + Milestones (D44)

* **요청함을 Issues로 옮깁니다.** 브랜치와 상관없이 모든 세션이 `gh issue list`로 보고, 사용자에게 알림이 갑니다.
* **라벨**
  * `from:<단위>`, `to:<단위>` (단위: root, core, server, app, writing, design)
  * `kind:request`·`kind:report`·`kind:notice`·`kind:task`
  * `blocking`: 다른 작업을 막는 것
* **상태:** 열림 = open, 지휘 세션이 수락하면 `accepted` 라벨을 붙이고, 받는 쪽이 처리하면 닫습니다. 거절은 `rejected` 라벨을 붙이고 닫습니다.
* **Milestones = 로드맵 ID:** B0, IA, W0, V0, V1, V2, S1~S3, A1, A2, W1, I1~I4. 진행 중인 Issue는 해당 마일스톤에 붙입니다.
* **Issue 양식 (`.github/ISSUE_TEMPLATE/`):** request, report, notice, task 네 가지. 본문 항목은 기존 `docs/coordination/TEMPLATE.md`와 같습니다.
* **코드가 아닌 지속 작업도 `kind:task` Issue로 엽니다.** 예: "W0 친숙도 라운드: 문장 맺음".
* **기존 `docs/coordination/`:** 지금 열려 있는 문서는 Issue로 옮기고 원문 링크를 남깁니다. 디렉터리는 보관소로 둡니다(`archive/`). 이후 새 요청은 Issue로만 씁니다.
* **결정은 여전히 git에 남깁니다.** Issue에서 정해진 결정은 해당 결정 로그(D·C·S·A·W·V)에 기록하고, Issue에 그 번호를 남깁니다.

## 6. 코드가 아닌 지속 작업의 운영

* **세션 단위로 닫습니다.** 문서 작업도 세션이 끝날 때 PR로 합칩니다. 결론이 나지 않은 라운드라도 중간 기록을 남겨 합칩니다.
* **세션 마무리 체크리스트** (모든 세션, `docs/workflow.md`에 둠)
  1. `git merge origin/main`
  2. 자기 `CLAUDE.md`의 "현재 상태" 갱신
  3. 산출물을 `artifacts/index.json`에 등록
  4. 관련 Issue 갱신·닫기
  5. PR → `ci-gate` 통과 → 병합
* **지휘 세션의 정기 일과** (지휘 세션을 열 때마다)
  1. 열린 Issue 분류
  2. 로드맵 "현재 진행 순서" 갱신
  3. 제품 지도 갱신(§7)

## 7. 제품 지도 (D45)

* **형태:** claude.ai 비공개 Artifact 페이지 하나. 휴대폰에서도 보고, 필요할 때 링크로 공유합니다.
* **원본:** 모두 git입니다. 지휘 세션이 `tools/product-map/`의 생성 스크립트로 저장소를 읽어 데이터 파일(JSON) 하나를 만들고, 페이지와 이미지를 함께 publish합니다. 페이지는 화면 틀만 담고 내용은 데이터 파일에서 읽습니다.
* **읽는 원본:** `docs/roadmap.md`, 모든 결정 로그, 모든 `artifacts/index.json`과 이미지, `docs/identity/README.md`, IA(나오면), 열린 Issue(`gh`로 스냅샷).
* **내용 (위에서 아래로)**
  1. **지금 위치:** 마일스톤 진행 상태 지도, "현재 진행 순서", 막고 있는 것
  2. **화면 지도:** IA를 뼈대로, 화면 카드마다 문장 슬롯·컴포넌트·시안과 스크린샷·엔진 데이터·관련 결정·진행 상태. IA 전까지는 MVP 범위(04, D16·D18)로 만든 임시 화면 목록을 씁니다.
  3. **정체성:** 컨셉 문장, 원칙, 시각 방향, 브랜드 시안
  4. **산출물 갤러리:** 모든 `artifacts/`를 단위·마일스톤·상태로 거르고, 고른 것과 탈락한 것을 나란히 봅니다.
  5. **로직:** 일진 × 원국 → 날의 성격 4단계 → 행운 정보의 흐름도와 근거 결정
  6. **결정 타임라인:** D·C·S·A·W·V 검색
  7. **열린 Issue:** 갱신 시점 스냅샷
* **갱신:** 지휘 세션 정기 일과, 마일스톤 완료 시, 사용자 요청 시. CI에서 자동으로 publish하지 않습니다(claude.ai를 CI에서 호출할 수 없음).
* **레이아웃:** 구현 단계에서 시안을 보여주고 사용자가 고릅니다.
* **나중:** 공개 포트폴리오가 필요해지면 같은 데이터 파일로 공개 정적 사이트를 만들고, 공개할 범위를 골라냅니다.

## 8. 바뀌는 문서와 소유

| 대상 | 변경 | 소유 |
| --- | --- | --- |
| `docs/workflow.md` | §5.2 요청함 → Issues, §6 브랜치·병합·세션 시작/마무리, §8 운영 확장 메모, 소유권 표에 `.github/workflows/ci-gate.yml`·템플릿·`tools/` 추가 | 지휘 |
| 루트 `CLAUDE.md` | 공통 규칙의 요청함 → Issues, 지휘 세션 정기 일과 | 지휘 |
| 각 `CLAUDE.md`(core·server·app·writing·design) | "다음 할 일"의 요청함 안내 → Issues, 마무리 체크리스트 참조 | 지휘가 착수 안내로 고침. core는 진행 중이 아니므로 지휘가 고치고 Issue로 알림 |
| `.github/workflows/ci-gate.yml`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/` | 새로 만듦 | 지휘 |
| `tools/docs-check/`, `tools/product-map/` | 새로 만듦 | 지휘 |
| `.github/workflows/core.yml` | `workflow_call` 지원, job 이름 규칙 | core (Issue로 요청) |
| GitHub 저장소 설정 | 라벨, 마일스톤 생성 | 지휘 |
| `docs/coordination/` | 열린 문서를 Issue로 옮기고 `archive/`로 이동 | 지휘 |

## 9. 범위 밖

* IA 내용 자체 (다음 지휘 작업)
* 서비스별 workflow 내용 (각 단위)
* 공개 포트폴리오 사이트

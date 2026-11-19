# main과 staging 브랜치 분리 설계

* 작성: 지휘 세션, 2026-11-19
* 상태: 검토 중
* 근거 결정: D136 ①②(브랜치 분리와 위험 수용), D135(T1은 staging, prod는 최소 구성), D138(server → app 관문), A104(빌드 번호)
* 로드맵: I4 준비물 "브랜치 분리"

## 1. 목적
prod는 단단하게, staging은 빠르게 둡니다. 쓰기 권한 계정이나 이 Mac의 `gh` 토큰이 털려도 영향이 staging에서 멈추게 하는 것이 핵심입니다(D136 ②). 지금은 `main` 하나에 관리자 우회가 열려 있고, main 병합 한 번이 staging 배포와 prod 배포 승인 요청으로 함께 이어집니다.

**성공 기준**
* `main`에 들어가는 길은 `staging → main` 승격 PR 하나이고, 관리자도 우회할 수 없습니다.
* prod 배포(server, 엔진)는 `main` push에서만, environment 승인을 거쳐 일어납니다. prod 배포 자격 증명은 `main`에서 도는 job만 받습니다.
* 단위 세션의 일상 작업은 기준 브랜치 이름만 바뀝니다. "Closes #n" 자동 닫힘, Dependabot, drift 검사는 지금처럼 동작합니다.
* 전환 직전 상태로 되돌리는 절차가 있습니다.

## 2. 지금 구조 (2026-11-19 확인)
* 브랜치 `main` 하나. ruleset "main 보호 (ci-gate 필수)"는 대상이 기본 브랜치, PR 필수, 필수 검사 `ci-gate`와 `pr-body`, 리뷰 0명, 저장소 관리자 역할 우회 허용, force push와 삭제 금지.
* `deploy-server`: main push에서 staging 배포 뒤 prod 배포(prod environment 승인자 있음), load는 수동. `deploy-engine`과 `app`도 main push.
* GitHub environment staging, prod, load의 배포 브랜치 제한은 모두 `main`.
* GCP Workload Identity: deployer 서비스 계정을 `attribute.env_ref`가 `<environment>@refs/heads/main`인 job에만 허용(server Terraform bootstrap, #644). environment 제한과 이중 장치.
* 앱 스토어 빌드는 로컬 스크립트로 만들고 설정은 `app/config/env/staging.json`, `prod.json` 중 고름. 빌드 번호는 A104.

## 3. 브랜치와 보호 규칙
| | `staging` (새 기본 브랜치) | `main` (prod 전용) |
| --- | --- | --- |
| 들어오는 길 | 단위와 지휘의 모든 PR, Dependabot | `staging → main` 승격 PR만 |
| 필수 검사 | `ci-gate`, `pr-body` | `ci-gate`, `pr-body`, `promotion-source` |
| 관리자 우회 | 허용 | 없음 |
| 리뷰 | 0명 | 0명(사람 확인은 prod 배포 승인) |
| force push, 삭제 | 금지 | 금지 |

* GitHub 기본 브랜치를 `staging`으로 바꿉니다. PR 기본 대상, "Closes #n"(기본 브랜치에 병합될 때 닫힘), Dependabot 대상이 따라옵니다.
* ruleset "main 보호"의 대상을 `~DEFAULT_BRANCH`에서 `refs/heads/main`으로 바꾸고 우회 목록을 비웁니다. staging용 ruleset을 새로 만듭니다(지금 main 보호와 같은 내용).
* `promotion-source`는 PR의 출발 브랜치가 `staging`이고 대상이 `main`일 때만 통과하는 검사입니다. `ci-gate.yml` 안의 job으로 두고, 대상이 main이 아닌 PR에서는 바로 통과합니다.

## 4. 승격
* **누가, 언제:** 지휘가 필요할 때 엽니다. prod에 의미 있는 변경(server와 엔진 배포, 법적 문서와 지원 페이지, 출시 빌드에 들어갈 앱 코드)이 staging에서 확인되면 `staging → main` 승격 PR을 열고 auto-merge를 겁니다. 사용자는 prod 배포 승인만 합니다(사용자 결정 2026-11-19).
* **병합 방식:** merge commit. 승격 커밋의 파일 내용은 그 시점 staging 끝과 같습니다.
* **본문:** 지난 승격 뒤 staging에 들어간 PR 번호 목록과 "prod에 미치는 것" 한 줄. `pr-body` 규칙을 따르고 `처리한 Issue: 없음`.
* **급한 prod 수정:** 같은 길입니다. staging에 병합해 확인하고 바로 승격합니다. main으로 바로 가는 길은 두지 않습니다.

## 5. 배포
| 무엇 | `staging` push | `main` push(승격) |
| --- | --- | --- |
| `deploy-server` | staging 배포(승인 없음), load는 지금처럼 수동 | prod 배포(environment 승인) |
| `deploy-engine` | staging 엔진 | prod 엔진 |
| `app`, `ci-gate` | 돎 | 돎 |

* environment 배포 브랜치 제한: `staging`과 `load`는 `staging` 브랜치, `prod`는 `main`.
* Workload Identity 조건: staging과 load 프로젝트의 deployer는 `<env>@refs/heads/staging`, prod 프로젝트는 `prod@refs/heads/main`. bootstrap은 사용자가 apply합니다(S136과 같은 방식).
* 지금의 "main push 한 번에 staging 뒤 prod" job 사슬은 둘로 나뉩니다. 그래서 prod 승인 요청은 승격 때만 옵니다. 지휘가 의미 없는 prod 승인을 취소하던 일은 없어집니다.

## 6. 앱 스토어 빌드
| 빌드 | 설정 | 만드는 브랜치 | 올리는 곳 |
| --- | --- | --- | --- |
| 테스트 빌드(T1, 내부 확인) | `staging.json` | `staging` | Play 비공개 테스트, TestFlight |
| 출시 빌드(I3 prod 리허설, I4와 그 뒤 업데이트) | `prod.json` | `main`(승격 커밋) | Play 내부 테스트와 production, TestFlight와 App Store |

* 빌드 번호는 A104 그대로입니다. 출시 빌드는 staging에서 `+N`을 올린 커밋을 승격하고 main의 승격 커밋에서 만듭니다. 승격 커밋은 staging 끝과 파일 내용이 같으므로 "N은 소스 시점 하나"가 지켜집니다.
* 스토어 빌드 대장(`app/README.md`)에 칸 둘을 더합니다: 브랜치, 설정.
* 업로드 스크립트는 prod 설정 빌드를 만들 때 현재 브랜치가 `main`이 아니면 멈춥니다. 고치는 쪽은 app입니다.

## 7. 단위 작업과 검사
* **단위 세션:** 기준 브랜치만 바뀝니다. 세션을 열 때 `git merge origin/staging`, 브랜치는 `--no-track origin/staging`으로 만듭니다. 고치는 문서: 루트와 단위 `CLAUDE.md`, `docs/workflow.md`, `.github/pull_request_template.md`. 지난 `plans/`는 기록이라 두고, 처음 읽는 문서의 경과는 `docs/workflow-history.md`에 남깁니다(D131).
* **`ci-gate`:** PR은 지금처럼 merge ref의 first parent와 비교합니다. push 트리거를 `staging`, `main` 둘로 둡니다. `promotion-source` job을 더합니다.
* **drift:** PR 기준이라 그대로입니다. drift Issue를 닫는 동작(`tools/drift/drift.sh close`)은 staging push에서 돕니다. drift가 생기고 풀리는 곳이 staging이기 때문입니다.
* **server 계약 관문(D138):** `contractgate`의 `-base` 기본값을 `origin/staging`으로 바꿉니다. CI는 이미 `-base HEAD^1`이라 동작은 같습니다. 이미 나간 앱은 staging 테스트 빌드와 main 출시 빌드 둘 다라서 PR마다 막는 지금 방식이 맞습니다.
* **지휘 도구:** `tools/repo-watch/watch.sh`는 staging과 main의 `ci-gate` 결과를 함께 봅니다(줄 머리에 브랜치). 환경 승인 대기 알림은 그대로입니다.
* **Dependabot:** 기본 브랜치를 따르므로 설정 변경 없음.

## 8. 전환 절차
지금 열린 단위 작업이 없어 설계 승인 뒤 바로 전환합니다(사용자 2026-11-19).

1. **지휘 PR(대상 main, 아직 main이 기본):** workflow 트리거와 `promotion-source`, 문서, `repo-watch`, `drift.sh`, `contractgate` 기본값, bootstrap Workload Identity 조건. 병합해도 깨지지 않게 둡니다(staging 브랜치가 없으면 그 트리거가 돌지 않을 뿐이고, bootstrap 변경은 apply 전까지 효과가 없음). app의 업로드 스크립트 확인 줄과 대장 칸은 app 요청 Issue로 보냅니다.
2. **`staging` 브랜치 만들기:** 1의 병합 직후 main에서.
3. **사용자(저장소와 GCP 설정):** 지휘가 명령과 바뀌기 전 값을 정리해 드리고, 사용자가 직접 하거나 확인 뒤 승인합니다.
   1. bootstrap apply: staging, load, prod 프로젝트
   2. environment 배포 브랜치 제한
   3. ruleset: main 대상 고정과 우회 제거와 `promotion-source`, staging ruleset 새로 만들기
   4. 기본 브랜치를 `staging`으로
4. **확인:** 작은 지휘 PR 하나를 staging에 병합해 staging 배포가 되는지, 승격 PR 하나로 prod 배포 승인이 오는지, main으로 바로 여는 PR이 `promotion-source`에서 막히는지 봅니다.
5. **공지:** 단위가 다음 세션을 열 때 기준이 바뀐다는 것을 각 단위 `CLAUDE.md`와 로드맵에 적습니다.
6. **되돌리기:** 기본 브랜치를 main으로, environment 제한과 Workload Identity 조건과 ruleset을 3 전의 값으로 돌립니다. 3을 하기 전에 그 값을 비공개 기록 `security/`에 남깁니다.

## 9. 범위 밖
* 리뷰 필수, staging 배포 승인: D136 ②대로 두지 않습니다.
* load 환경의 브랜치 정책 재검토: staging에 묶고 그대로 수동 실행.
* 승격 PR 자동 생성: 필요해지면 따로 정합니다.

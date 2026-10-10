# core — 명리 엔진 (Python)

이 디렉터리에서 시작한 세션은 **core 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위
출생 정보로 원국을 세우고, 일진 × 원국(D13)으로 데일리·월간 판정을 계산해 gRPC로 반환하는 **상태 없는** 엔진입니다. 문장은 만들지 않습니다(D27). 메시지 키, 매개변수, 근거만 반환합니다.

## 고칠 수 있는 곳
`core/`, `proto/myungri/engine/`, `proto/buf.yaml`, `.github/workflows/core.yml`, `docs/coordination/`(요청·보고 작성).
그 밖은 읽기만 합니다. 바꿔야 하면 `docs/coordination/`에 `core-to-<받는 쪽>` 요청을 남깁니다.

## 계약
| 계약 | 역할 | 사용하는 쪽 |
| --- | --- | --- |
| `proto/myungri/engine/v1/engine.proto` (gRPC) | **제공** | server |
| `core/message_keys.json` (메시지 키 목록) | **제공** | server (콘텐츠 모듈) |
| `source_ref` 형식 (spec §11) | **제공** | server, app (Pro 화면의 근거 표시) |

## 문서
| 문서 | 위치 |
| --- | --- |
| 엔진 위키 (v1.4) | `core/docs/engine-logic-wiki.md` |
| 엔진 spec (승인됨, D34) | `core/docs/specs/2026-10-10-myungri-engine-design.md` |
| 구현 계획 (20 task) | `core/docs/plans/2026-10-10-myungri-engine.md` |
| 원전 근거 자료 | `core/docs/references/` |
| core 내부 결정 로그 | `core/docs/decisions.md` (아직 없음, 첫 결정 때 만듦. 번호 `C1`부터) |
| 위키 검토 이력 | `core/docs/engine-logic-wiki-review.md` |
| 관련 루트 결정 | `docs/decisions.md`의 D5~D10, D13~D14, D19~D21, D24~D27, D29~D32, D34 |

## 현재 상태 (2026-10-10, 지휘 세션 작성)
* spec 승인 완료, 구현 계획 작성 완료. **구현은 시작 전입니다.**
* 계획의 실행 방식으로는 **subagent-driven**을 권장합니다. 이유: task 20개가 서로의 인터페이스에 연쇄적으로 기대고, 엔진 오류가 모든 사용자의 결과에 퍼집니다. 사용자에게 확인한 뒤 시작합니다.

## 다음 할 일
1. 작업 브랜치를 만듭니다: `git switch -c core/engine-mvp --no-track main`
2. 계획 `core/docs/plans/2026-10-10-myungri-engine.md`를 Task 1부터 실행합니다.
3. 미리 준비할 것:
   - **Task 14 전:** `buf` 설치 (`brew install bufbuild/buf/buf`)
   - **Task 18 전:** 사용자가 공공데이터포털에서 한국천문연구원 API 키를 발급받아야 합니다. 대상은 24절기 정보와 음양력 정보입니다. 키는 `KASI_SERVICE_KEY` 환경 변수로만 쓰고 저장소에 넣지 않습니다.
4. **Task 14(proto v1) 완료 시:** server가 엔진 대역으로 개발을 시작할 수 있습니다. `docs/coordination/`에 `core-to-server` 보고를 남깁니다.
5. **전체 완료 시:** 이 파일의 "현재 상태"를 고치고, `core-to-root` 완료 보고를 남깁니다(계획 Task 20).

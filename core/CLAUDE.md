# core — 명리 엔진 (Python)

이 디렉터리에서 시작한 세션은 **core 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위
출생 정보로 원국을 세우고, 일진 × 원국(D13)으로 데일리·월간 판정을 계산해 gRPC로 반환하는 **상태 없는** 엔진입니다. 문장은 만들지 않습니다(D27). 메시지 키, 매개변수, 근거만 반환합니다.

## 고칠 수 있는 곳
`core/`, `proto/myungri/engine/`, `proto/buf.yaml`, `.github/workflows/core.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:core`).
그 밖은 읽기만 합니다. 바꿔야 하면 `from:core` Issue로 요청합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 사용하는 쪽 |
| --- | --- | --- |
| `proto/myungri/engine/v1/engine.proto` (gRPC) | **제공** | server |
| `core/message_keys.json` (메시지 키 목록) | **제공** | server (콘텐츠 모듈) |
| `source_ref` 형식 (spec §11) | **제공** | server, app (Pro 화면의 근거 표시) |

## 문서
| 문서 | 위치 |
| --- | --- |
| 엔진 위키 (v1.6) | `core/docs/engine-logic-wiki.md` |
| 엔진 spec (승인됨, D34) | `core/docs/specs/2026-10-10-myungri-engine-design.md` |
| 구현 계획 (20 task) | `core/docs/plans/2026-10-10-myungri-engine.md` |
| 원전 근거 자료 | `core/docs/references/` |
| core 내부 결정 로그 | `core/docs/decisions.md` (현재 C1~C21, 번호 `C1`부터) |
| 위키 검토 이력 | `core/docs/engine-logic-wiki-review.md` |
| 관련 루트 결정 | `docs/decisions.md`의 D5~D10, D13~D14, D19~D21, D24~D27, D29~D32, D34 |

## 현재 상태 (엔진 MVP 완료, 2026-10-10)
* **구현 범위:** 달력 계산(`calendar_core`, 한국 음력 KST 계산 포함), 원국(사주팔자·십성·지장간·12운성·대운·세운·신살), 신강·신약과 용신, 데일리 규칙(날의 성격·컬러·방향·숫자·집중 시간·합충형·태그·총운·가이드), 월간 캘린더, gRPC 서버(`uv run python -m myungri_engine --port 50051`).
* **테스트 층:** 단위, 통합(gRPC), 불변 조건, 회귀 스냅샷(원국 10개 x 데일리 30일, 원국 4개의 원국·대운·세운과 월간), KASI 천문 골든, 기준 앱 만세력 골든, 분포 보정 확인. 기본은 `uv run pytest -q -m "not slow"`이고 slow는 보정 확인과 KASI 골든입니다. CI는 `.github/workflows/core.yml`.
* **제공 계약:** `proto/myungri/engine/v1`(v1), `core/message_keys.json`(93개 키), `source_ref` 형식, `ruleset_version` `2026.10.1`.
* **알려진 한계:**
  * KASI 대조 범위 밖은 미검증입니다: 절기 2000~2028년, 음력 1900~2050년. 그 밖의 지원 범위(1900-01-31 ~ 2099-12-31)는 같은 알고리즘으로 계산합니다.
  * 대운 시작 나이는 `sect=1`(시진 단위)이라 정밀값보다 최대 약 10일 크게 나와 정수 경계를 넘을 수 있습니다(C5).
  * 1900년 1월 월간 요청은 `OUT_OF_RANGE`입니다(지원 범위가 1900-01-31부터).
  * 전용 근거 자료가 없는 판정(집중 시간·태그·총운·월간)은 `five_elements#balance_principle`을 근거로 씁니다(C8).
  * Phase 2로 미룬 것: spec §15(합화, 통관·병약·격국 용신, 목적별 택일, 야자시 옵션, 대운 시각화 데이터, 일기 감성 코멘트).

## 다음 할 일
1. 엔진 MVP는 main에 병합됐습니다(PR #1). 새 작업은 `docs/workflow.md` §6대로 `origin/main`에서 새 브랜치로 시작합니다.
2. 완료 보고(`docs/coordination/archive/2026-10-10-core-to-root-engine-mvp-done.md`)는 지휘 세션이 처리했습니다(PR #1 병합). 남은 일은 `gh issue list --label to:core`: 후속 요청 #5, 용어 정리 #4, core.yml 전환 #9.
3. server가 실제 엔진을 호출하며 발견하는 계약 문제는 `to:core` Issue로 받아 처리합니다. 출력이 달라지는 변경은 `ruleset_version`을 올립니다(`README.md`의 절차).
4. Phase 2 항목은 지휘 세션과 우선순위를 정한 뒤 별도 spec으로 진행합니다.

# core — 명리 엔진 (Python)

이 디렉터리에서 시작한 세션은 **core 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위
출생 정보로 원국을 세우고, 일진 × 원국(D13)으로 데일리·월간 판정을 계산해 gRPC로 반환하는 **상태 없는** 엔진입니다. 문장은 만들지 않습니다(D27). 메시지 키, 매개변수, 근거만 반환합니다.

## 고칠 수 있는 곳
`core/`, `proto/myungli/engine/`, `proto/buf.yaml`, `.github/workflows/core.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:core`).
그 밖은 읽기만 합니다. 바꿔야 하면 `from:core` Issue로 요청합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 공개 저장소와 맞물림 규칙
* **공개 저장소(D74):** 이 저장소는 공개입니다. Issue·PR·커밋·문서에 가격·수익 수치 같은 내부 정보를 적지 않습니다. 제품 배경 원문·수익화 기록은 비공개 저장소에 있고 링크하지 않습니다. 근거가 필요하면 지휘에게 Issue로 묻습니다.
* **맞물림(D73, `docs/workflow.md` §6.1):** core는 계약을 **주는 쪽**입니다(`ci-gate`의 core 검사는 받는 계약 없이 `own`만 돕니다). proto·`message_keys.json`·`message_params.json`만 바꾼 PR은 받는 쪽(server·writing) 검사가 실패해도 경고로 병합되고, `ci-gate`가 받는 쪽 앞으로 `drift` Issue를 엽니다. 하위 호환을 깨는 변경은 `kind:notice`로 따로 알립니다. 내 앞 drift는 `gh issue list --label drift --label to:core`로 확인하고 있으면 다음 PR에서 먼저 맞춥니다.

## 계약
| 계약 | 역할 | 사용하는 쪽 |
| --- | --- | --- |
| `proto/myungli/engine/v1/engine.proto` (gRPC, RPC 5개: GetChart, GetDaily, GetMonthCalendar, GetBirthHour, GetInfo) | **제공** | server |
| `core/message_keys.json` (메시지 키 목록, 153개) | **제공** | server (콘텐츠 모듈), writing |
| `core/message_params.json` (메시지 키별 매개변수 이름) | **제공** | server, writing |
| `source_ref` 형식 (spec §11) | **제공** | server, app (`evidence` 깊이의 근거 표시) |

## 문서
| 문서 | 위치 |
| --- | --- |
| 엔진 위키 (v1.7) | `core/docs/engine-logic-wiki.md` |
| 엔진 spec (승인됨, D34) | `core/docs/specs/2026-10-10-myungli-engine-design.md` |
| 구현 계획 (20 task) | `core/docs/plans/2026-10-10-myungli-engine.md` |
| 원국 개인 해석·출생 시진·엔진 정보 spec | `core/docs/specs/2026-10-11-personal-reading-design.md` |
| 원국 개인 해석 구현 계획 | `core/docs/plans/2026-10-11-personal-reading.md` |
| 원전 근거 자료 | `core/docs/references/` |
| core 내부 결정 로그 | `core/docs/decisions.md` (현재 C1~C27, 번호 `C1`부터) |
| 위키 검토 이력 | `core/docs/engine-logic-wiki-review.md` |
| 관련 루트 결정 | `docs/decisions.md`의 D5~D10, D13~D14, D19~D21, D24~D27, D29~D32, D34 |

## 현재 상태 (엔진 MVP 완료, 원국 개인 해석 추가, 2026-10-11)
* **구현 범위:** 달력 계산(`calendar_core`, 한국 음력 KST 계산 포함), 원국(사주팔자·십성·지장간·12운성·대운·세운·신살), 신강·신약과 용신, 데일리 규칙(날의 성격·컬러·방향·숫자·집중 시간·합충형·태그·총운·가이드), 월간 캘린더, 원국 개인 해석(`personal_readings`, D60), 출생 시진 RPC(`GetBirthHour`, D58), 엔진 정보 RPC(`GetInfo`), gRPC 서버(`uv run python -m myungli_engine`, 포트는 `--port` → `PORT` → 50051, gRPC health checking 포함), 컨테이너 이미지(`core/Dockerfile`, #34).
* **테스트 층:** 단위, 통합(gRPC), 불변 조건, 회귀 스냅샷(원국 10개 x 데일리 30일, 원국 4개의 원국·대운·세운과 월간), KASI 천문 골든, 기준 앱 만세력 골든, 분포 보정 확인. 기본은 `uv run pytest -q -m "not slow"`이고 slow는 보정 확인과 KASI 골든입니다. CI는 `.github/workflows/core.yml`.
* **제공 계약:** `proto/myungli/engine/v1`(v1), `core/message_keys.json`(153개 키), `core/message_params.json`(키별 매개변수 이름, #38), `source_ref` 형식, `ruleset_version` `2026.10.2`.
* **알려진 한계:**
  * KASI 대조 범위 밖은 미검증입니다: 절기 2000~2028년, 음력 1900~2050년. 그 밖의 지원 범위(1900-01-31 ~ 2099-12-31)는 같은 알고리즘으로 계산합니다.
  * 대운 시작 나이는 `sect=1`(시진 단위)이라 정밀값보다 최대 약 10일 크게 나와 정수 경계를 넘을 수 있습니다(C5).
  * 1900년 1월 월간 요청은 `OUT_OF_RANGE`입니다(지원 범위가 1900-01-31부터).
  * 전용 근거 자료가 없는 판정(집중 시간·태그·총운·월간)과 원국 개인 해석은 `five_elements#balance_principle`을 근거로 씁니다(C8). 개인 해석은 궁위 원전이 없어 `balance_principle`을 공통 근거로 쓴다(spec §2.4).
  * Phase 2로 미룬 것: spec §15(합화, 통관·병약·격국 용신, 목적별 택일, 야자시 옵션, 대운 시각화 데이터, 일기 감성 코멘트).

## 다음 할 일
1. 엔진 MVP는 main에 병합됐습니다(PR #1). 새 작업은 `docs/workflow.md` §6대로 `origin/main`에서 새 브랜치로 시작합니다.
2. 남은 요청은 `gh issue list --label to:core`로 봅니다. 2026-10-15 기준:
   * **#164:** 음력 → 양력 변환과 윤달 유무 RPC(`ConvertLunarDate`). server REST `1.0.0-draft.3`의 `convertLunarDate`가 이 RPC를 기다리며 501입니다. 하위 호환 추가 RPC라 계약 먼저 병합(§6.1)이 가능합니다.
   * **#130:** writing 근거 문장용 `rule_id` 목록과 `source_ref`별 원전 원문 내보내기.
   * **#120:** `core.yml`의 GitHub Actions를 Node 24 최신 메이저로.
   * **#59-2:** 회귀 스냅샷 분할 검토는 다음 규칙 변경 때 봅니다.
   * 엔진 배포 workflow(`deploy-engine.yml`)는 server가 맡습니다(D65). core는 이미지(`core/Dockerfile`)와 실행 조건(`README.md` "컨테이너" 절, #79)을 맡고, 바꿀 때는 `to:server` Issue로 알립니다.
3. server가 실제 엔진을 호출하며 발견하는 계약 문제는 `to:core` Issue로 받아 처리합니다. 출력이 달라지는 변경은 `ruleset_version`을 올립니다(`README.md`의 절차).
4. Phase 2 항목은 지휘 세션과 우선순위를 정한 뒤 별도 spec으로 진행합니다.

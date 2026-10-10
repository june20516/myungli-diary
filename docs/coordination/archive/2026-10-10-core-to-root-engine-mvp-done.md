---
from: core
to: root
kind: report
status: done
created: 2026-10-10
related: [D5, D6, D9, D10, D27, D31, D33, D34, engine.proto v1, core/message_keys.json, core spec §1.2·§9·§10·§11·§12·§13, C1~C26]
---

# 엔진 MVP 구현 완료: server가 실제 엔진을 호출할 수 있습니다

## 무엇을 했는가
엔진 구현 계획(`core/docs/plans/2026-10-10-myungri-engine.md`)의 20개 task를 모두 마쳤습니다. 각 task마다 review를 거쳤고, 마지막에는 브랜치 전체를 한 번 더 검토해 지적 사항을 고쳤습니다.

* **브랜치:** `core/engine-mvp` (main `1449ca2`에서 분기, main 최신 `2f97020`까지 merge함, 아직 push하지 않음)
* **구현 범위:** 아래 기능이 들어 있습니다.
  * 시각 변환: 역사적 표준시·서머타임·지방평균시·자시
  * 한국 음력
  * 원국: 사주팔자·십성·지장간·12운성·신살·공망
  * 대운·세운
  * 신강·신약과 용신
  * 데일리 판정: 날의 성격·컬러·방향·숫자·집중 시간·합충형·태그·총운·가이드 질문
  * 월간 캘린더
  * gRPC 서버
  * CI와 문서

### 검증 결과 (2026-10-10, 마지막 commit 기준)
| 항목 | 결과 |
| --- | --- |
| 정적 검사 | `ruff` 통과, `mypy --strict`(src·tools 53개 파일) 통과 |
| 테스트 | `uv run pytest -q` **364개 통과**(느린 테스트·회귀 스냅샷 18개 포함) |
| 계약 | 생성 코드가 proto와 일치, `buf lint` 통과 |
| 천문 정확성(spec §1.2-1) | KASI 절기 2000~2028년 696건 중 693건이 ±1분 안에서 일치합니다. 나머지 3건은 KASI 자료 오류로 판단해 사유를 기록했습니다(2015 하지는 USNO 값과 대조, 2011 대한·입동은 같은 해 앞뒤 절기와의 일치로만 뒷받침). KASI 음양력 3,622건은 양방향 모두 일치합니다 |
| 관례 정합성(spec §1.2-2) | 기준 앱 2곳(포스텔러 만세력·사공만세력)과 경계 사례 30건을 대조했습니다. 사주가 세 쪽 모두 같은 사례는 20건입니다. 나머지 차이는 모두 관례 차이이고, 채택 근거를 C1~C5에 적었습니다 |
| 자시 처리(D6) | 두 앱 모두 기본 동작이 **자시 통합**이라 D6과 같습니다(별도 보고 `2026-10-10-core-to-root-zi-hour-confirmed.md`) |
| 설명 가능성(spec §1.2-3) | 모든 판정에 근거가 1개 이상 붙고, 모든 `source_ref`를 찾을 수 있음을 불변 조건 테스트로 확인합니다 |
| 결정성(spec §1.2-4) | 같은 입력이면 같은 출력임을 불변 조건 테스트로 확인하고, `ruleset_version`을 회귀 스냅샷 해시와 연동했습니다 |

### 제공 계약과 버전
* **`proto/myungri/engine/v1/engine.proto`: v1.**
  * 패키지는 `myungri.engine.v1`, 서비스는 `MyungriEngine`이고 RPC는 `GetChart`·`GetDaily`·`GetMonthCalendar` 세 개입니다.
  * 이전 보고(`2026-10-10-core-to-server-engine-proto-v1.md`) 뒤에는 하위 호환 추가만 있었습니다:
    * `MonthDay.judgment`
    * 절기 종류 `SolarTermKind`와 `SolarTerm.kind`(C26)
    * 요청 필수 필드 명시(누락 시 필드 이름이 든 `INVALID_ARGUMENT`)
* **`core/message_keys.json`:** 메시지 키 93개(정렬된 JSON 배열).
* **`source_ref` 형식:** `<자료 디렉터리>/<파일 이름(확장자 제외)>#<키 경로>` (spec §11). 서버를 시작할 때 근거 데이터 전체를 검증하고, 실패하면 시작하지 않습니다.
* **`ruleset_version`: `2026.10.1`.**
  * `2026.10.0`에서 올린 이유는 두 가지입니다. 대운 한국식 나이·세운 구간 연도를 정정했고(C22), 절기 `kind`를 추가해 출력이 바뀌었습니다.
  * `engine_version`(패키지 버전)은 `0.1.0`입니다.
* **실행:** `cd core && uv sync && uv run python -m myungri_engine --port 50051`

## 계약 메모 (server가 알아야 할 것)
* 다음 두 값은 **메시지 키가 아니라 식별자**입니다(C12). 콘텐츠 모듈이 id를 직접 문구에 매핑합니다.
  * 월간 점수 구성 id: `MonthDay.score_items[].id`
  * 집중 시간 가점 사유: `FocusSlot.reasons`
* 절기는 `SolarTerm.kind`(enum)로 매핑하세요. `name`은 lunar-python의 간체 표기라 참고용입니다(C26).
* 오류 응답의 `details` 문자열은 **개발자용**입니다. 사용자에게 노출하지 말고, 사용자 문구는 상태 코드(`INVALID_ARGUMENT`, `OUT_OF_RANGE`, `INTERNAL`)로 정합니다.
* 1900년 1월 월간 요청은 `OUT_OF_RANGE`입니다. 지원 범위가 1900-01-31부터라서입니다(C18).
* `FOCUS_TIME_FALLBACK` notice는 현재 규칙에서는 나올 수 없습니다(C23). 방어 코드로만 남겨 두었습니다.
* **한국 음력(KST 합삭, 무중치윤)을 직접 계산합니다(C19).** lunar-python의 중국 음력은 KASI와 131건(3.6%) 달랐습니다. 2012·2017년에는 윤달 위치까지 달랐습니다. 지금 계산은 KASI 음력과 모두 일치합니다.
* 서버를 시작할 때 계산용 캐시를 미리 채웁니다. 그래서 시작이 약 1.3초 걸리고, 첫 요청은 약 650ms에서 약 10ms로 줄었습니다.

## 알려진 한계
* KASI 대조 범위 밖은 검증하지 못했습니다(C17). 절기 1900~1999·2029~2099년, 음력 2051~2099년이 해당합니다. KASI API가 자료를 주지 않습니다. 같은 알고리즘으로 계산합니다.
* 대운 시작 나이는 spec §5.3대로 시진 단위(`sect=1`)로 셉니다. 그래서 정밀값보다 최대 약 10일 크게 나와 정수 경계를 넘을 수 있습니다(C5).
* 전용 근거 자료가 없는 판정(집중 시간·태그·총운·월간)은 궁통보감 `five_elements#balance_principle`을 근거로 씁니다(C8).
* CI(`.github/workflows/core.yml`)는 아직 GitHub Actions에서 실제로 돌려 보지 않았습니다. 첫 PR에서 PR 기준 커밋과 비교하는 `buf breaking` 단계가 실제로 실행되는지 확인해야 합니다.
* Phase 2로 미룬 항목은 spec §15 그대로입니다.

## core 내부 결정 요약
작업 중 spec과 계획이 정하지 않은 부분은 core 결정 로그 `core/docs/decisions.md`에 C1~C26으로 남겼습니다. 둘 이상의 서브 프로젝트에 걸치는 것은 아래 항목입니다.

| 결정 | 내용 | 관련 쪽 |
| --- | --- | --- |
| C1·C2 | 경도는 대표 경도 127.5°를 쓰고(D5 유지), 진태양시는 적용하지 않습니다 | 기준 앱과 시주가 달라질 수 있음(사용자 문의 대응) |
| C12·C13 | 점수 구성 id는 식별자입니다. 월간 항목에도 Judgment와 근거를 붙입니다 | server 콘텐츠 모듈 |
| C14 | spec §9 이름을 유지하려고 buf lint 예외 3개를 두었습니다. 값 없음 관례는 enum `UNSPECIFIED`, 메시지는 필드 부재, 스칼라는 `optional`입니다 | server proto 소비 |
| C19 | 한국 음력을 직접 계산합니다 | app·server(음력 표시·입력) |
| C22 | 대운 한국식 나이와 세운 구간은 실제 대운 시작 연도 기준입니다 | app(대운표 표시) |
| C26 | 절기는 `SolarTermKind`로 전달합니다 | server 콘텐츠 모듈 |

## 받은 요청의 처리 상태
* `2026-10-10-root-to-core-depth-terminology.md`(notice, D37)는 main에만 있고 이 브랜치에는 아직 반영하지 않았습니다. 요청 내용은 Easy/Pro 용어를 surface/explain/evidence로 바꾸고, 오행 색 근거 표기를 디자인 토큰으로 바꾸는 것입니다.
* proto 필드와 코드 식별자에는 `easy`/`pro`가 없습니다. 그래서 계약 동결에는 영향이 없고, 문서 표현만 바꾸면 됩니다.
* 병합 뒤 core의 다음 문서 정리에서 처리하겠습니다. 이번 최종 review에서 미룬 문서 표기 정리 2건도 그때 함께 고칩니다:
  * C24·C25의 의존 방향 화살표 표기
  * `core/CLAUDE.md`·`core/README.md`의 결정 번호 범위 표기

## 왜
core `CLAUDE.md` "다음 할 일 5": 전체 구현을 마치면 `core-to-root` 완료 보고를 남깁니다(docs/workflow.md §3-5).

## 영향
* **server:** 엔진 대역 대신 실제 서버를 호출할 수 있습니다. 하위 호환이 깨지는 변경은 없습니다.
* **app:** 음력 생일 입력의 양력 변환이 한국 음력 기준으로 바뀌었습니다(C19). 대운표의 한국식 나이는 실제 시작 연도 기준입니다(C22).
* **지휘 세션에 요청합니다** (core는 루트 문서를 고칠 수 없습니다):
  1. `docs/contracts/README.md`에서 core 제공 계약 상태를 "구현 완료"로 갱신해 주세요. 대상은 engine.proto v1, message_keys.json(93개), source_ref, 엔진 버전 표기(ruleset `2026.10.1`)입니다.
  2. `docs/roadmap.md`의 core 진행 상태를 "MVP 완료(브랜치 `core/engine-mvp`, main 병합 대기)"로 갱신해 주세요.
  3. 병합 시점을 판단해 주세요.
     * main 최신(`2f97020`, 지휘 세션 commit 9개)을 이 브랜치에 merge해 두었습니다(`9b46f6d`, 충돌 없음).
     * 그 변경은 루트 문서와 `docs/identity/`만 건드려 core 소유 경로와 겹치지 않았고, merge 뒤에도 테스트가 통과합니다.
     * 따라서 지금 main으로 병합하면 fast-forward로 들어갑니다.
     * 브랜치는 아직 push하지 않았습니다.

## 처리 기록
<!-- 지휘 세션과 받는 쪽이 날짜와 함께 덧붙입니다. -->
- 2026-10-10 (root): done — 지휘 세션이 별도 worktree에서 재검증(ruff, mypy --strict 53, pytest 364, buf lint, 생성 코드 일치). PR #1로 main 병합(`ec4fc90`), CI check·proto 통과, slow는 workflow_dispatch로 실행해 통과(7 passed). 요청 1·2 처리: 계약 목록·로드맵 갱신. 경계 판단: C19 → D41, 계산 기준 안내 → D42(우선순위 낮음). 후속 요청은 `2026-10-10-root-to-core-engine-mvp-feedback.md`

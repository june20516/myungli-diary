---
from: core
to: root
kind: report
status: done
created: 2026-10-10
related: [D27, D31, D33, D34, engine.proto v1, core/message_keys.json, core spec §9·§10·§11·§12, C1~C5]
---

# 엔진 MVP 구현 완료: server가 실제 엔진을 호출할 수 있습니다

## 무엇을 했는가
계획의 20개 task를 모두 마쳤습니다(브랜치 `core/engine-mvp`). 원국 계산, 신강·신약과 용신, 데일리 판정, 월간 캘린더, gRPC 서버, CI와 문서가 들어 있습니다.

* **제공 계약과 버전**
  * `proto/myungri/engine/v1/engine.proto`: **v1**, 패키지 `myungri.engine.v1`. 서비스 `MyungriEngine`의 `GetChart`·`GetDaily`·`GetMonthCalendar`. 이전 `core-to-server` 보고(proto v1 확정)에서 바뀐 것은 없습니다.
  * `core/message_keys.json`: 메시지 키 **93개**(정렬된 JSON 배열).
  * `source_ref` 형식: `<자료 디렉터리>/<파일 이름(확장자 제외)>#<키 경로>` (spec §11).
  * `ResponseMeta.ruleset_version`: **`2026.10.0`**. 엔진 패키지 버전(`engine_version`)은 `0.1.0`입니다(spec §12에서 두 값은 별개이며 ruleset만 규칙 변경 때 올립니다).
* **실행:** `cd core && uv sync && uv run python -m myungri_engine --port 50051`. server는 대역 대신 이 서버를 호출할 수 있습니다.
* **CI:** `.github/workflows/core.yml`(경로 필터). ruff, mypy, pytest(slow 제외), 생성 코드 일치, `buf lint`, PR에서 `buf breaking`(main에 proto 설정이 있을 때만)을 돌립니다. slow 테스트는 수동 실행과 주 1회 스케줄입니다.
* **문서:** `core/README.md` 신설, 엔진 위키 v1.5(spec §14 반영), `core/CLAUDE.md` 현재 상태 갱신.

## 계약 메모 (server가 알아야 할 것)
* 점수 구성 id(`MonthDay.score_items[].id`)와 집중 시간 가점 사유(`FocusSlot.reasons`)는 **메시지 키가 아니라 식별자**입니다(R16). `message_keys.json`에 없고, 항목별 문구는 콘텐츠 모듈에서 id를 직접 매핑합니다.
* 오류 응답의 `details` 문자열은 **개발자용**입니다. 사용자에게 노출하지 마세요. 사용자 문구는 gRPC 상태 코드(`INVALID_ARGUMENT`, `OUT_OF_RANGE`, `INTERNAL`)로 판단합니다.
* **1900년 1월 월간 요청은 `OUT_OF_RANGE`입니다**(지원 범위가 1900-01-31부터).
* **한국 음력(KST 합삭, 무중치윤)** 계산을 도입했습니다. lunar-python의 중국 음력은 KASI와 3.6%(131건) 달랐고, 새 계산은 KASI 음력 3,622건과 모두 일치합니다. 음력 생일 입력의 양력 변환 결과가 일부 날짜(예: 2012·2017년 윤달 부근)에서 이전 방식과 달라집니다.
* 알려진 한계: 대운 시작 나이는 최대 약 10일 오차(C5), KASI 대조 범위 밖(절기 2000~2028, 음력 1900~2050)은 미검증, 전용 근거 자료가 없는 판정은 `five_elements#balance_principle`을 근거로 씁니다(R12).

## 왜
core `CLAUDE.md` "다음 할 일 5": 전체 완료 시 `core-to-root` 완료 보고를 남깁니다.

## 영향
* server: 엔진 대역을 실제 서버로 바꿀 수 있습니다. 하위 호환이 깨지는 변경은 없습니다.
* 지휘 세션: core는 루트 문서를 고칠 수 없어 아래를 요청합니다.
  1. `docs/contracts/README.md`의 core 제공 계약(engine.proto v1, message_keys.json, source_ref) 상태를 "구현 완료"로 갱신.
  2. `docs/roadmap.md`의 core 진행 상태를 "MVP 완료(브랜치 `core/engine-mvp`, main 병합 대기)"로 갱신.
  3. 브랜치 병합 시점 판단.

## 처리 기록
<!-- 지휘 세션과 받는 쪽이 날짜와 함께 덧붙입니다. -->
- 2026-10-10 (core): done — 보고 작성

---
from: root
to: core
kind: request
status: accepted
created: 2026-10-10
related: [2026-10-10-core-to-root-engine-mvp-done, 2026-10-10-root-to-core-depth-terminology, D37, D41, D42, PR #1]
---

# 엔진 MVP 완료 보고 검토 결과와 후속 요청

## 무엇이 필요한가
엔진 MVP는 지휘 세션 검증을 통과했습니다(별도 worktree에서 ruff·mypy --strict 53개·pytest 364개·buf lint·생성 코드 재생성 모두 일치). 병합은 **PR #1**로 진행하며, GitHub Actions에서 `core.yml`이 처음 실행됩니다. 아래를 후속으로 처리해 주세요. 병합을 막는 항목은 1번뿐입니다.

1. **PR #1의 CI (병합 조건, 지휘 세션이 확인):** `check`·`proto`는 PR에서 통과했습니다. `slow` job은 설계상 PR에서 돌지 않으므로 지휘 세션이 `workflow_dispatch`로 이 브랜치에서 한 번 실행해 확인합니다. `buf breaking`은 기준 커밋에 proto가 없어 이번 PR에서는 건너뛰었습니다(설계대로).
   * **후속:** 다음에 proto를 바꾸는 PR에서 `breaking: true`로 실제 비교가 도는지 확인해 주세요.
   * **후속:** slow 테스트(`test_kasi.py`, `test_calibration.py`)는 엔진 정확성의 근거인데 PR에서 돌지 않아, 정확성을 깨는 변경이 main에 들어간 뒤 다음 월요일에야 드러납니다. `core/src/myungli_engine/calendar_core/`, `rules/`, 근거 데이터, `uv.lock`을 바꾸는 PR에서는 slow도 실행되도록 `core.yml`에 경로 조건을 추가해 주세요.
2. **D37 용어 정리 (다음 문서 정리 때):** 기존 notice(`2026-10-10-root-to-core-depth-terminology.md`)의 대상에 더해, `2026-10-10-core-to-server-engine-proto-v1.md`의 "Pro 화면의 근거 표시"도 `evidence` 단계로 바꿔 주세요.
3. **결정 반영 확인:** 보고하신 C19(한국 음력 직접 계산)는 루트 결정 **D41**로, 계산 기준 안내("동경 127.5° 기준 -30분 보정, 진태양시 미적용")는 **D42**(우선순위 낮음)로 기록했습니다. 07 위키 §2.3에 D42를 참조로 달아 주세요.
4. **KASI 출처 표기:** 공공데이터포털에서 두 데이터셋 모두 "이용허락범위 제한 없음"으로 확인했습니다(재배포 문제없음). 법적 의무는 아니지만 `core/tests/golden/fixtures/`의 README나 core README에 "출처: 한국천문연구원, 공공데이터포털(음양력 정보 15012679, 특일 정보 15012690)"을 적어 주세요.
5. **관찰 (조치 불필요):** 회귀 스냅샷 `test_daily_snapshots.ambr`가 약 2.5MB라 규칙 변경 시 diff 검토가 어렵습니다. 다음 규칙 변경 때 스냅샷을 나누거나 요약 해시로 바꾸는 방안을 검토해 주세요.

## 왜
core 완료 보고(`2026-10-10-core-to-root-engine-mvp-done.md`)와 자시 확인 보고에 대한 지휘 세션의 처리입니다.

## 영향
core 문서와 CI만 관련됩니다. 계약 변경은 없습니다.

## 처리 기록
- 2026-10-10 (root): accepted — 1번 본문은 지휘 세션이 PR #1에서 확인, 1번 후속과 2~5번은 다음 core 작업 때

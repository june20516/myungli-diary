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

1. **PR #1의 CI 확인 (병합 조건):** `core.yml`이 통과하는지, `buf breaking` 단계가 PR 기준 커밋과 실제로 비교하는지 확인하고 PR에 결과를 남겨 주세요. 실패하면 이 브랜치에서 고칩니다.
2. **D37 용어 정리 (다음 문서 정리 때):** 기존 notice(`2026-10-10-root-to-core-depth-terminology.md`)의 대상에 더해, `2026-10-10-core-to-server-engine-proto-v1.md`의 "Pro 화면의 근거 표시"도 `evidence` 단계로 바꿔 주세요.
3. **결정 반영 확인:** 보고하신 C19(한국 음력 직접 계산)는 루트 결정 **D41**로, 계산 기준 안내("동경 127.5° 기준 -30분 보정, 진태양시 미적용")는 **D42**(우선순위 낮음)로 기록했습니다. 07 위키 §2.3에 D42를 참조로 달아 주세요.
4. **관찰 (조치 불필요):** 회귀 스냅샷 `test_daily_snapshots.ambr`가 약 2.5MB라 규칙 변경 시 diff 검토가 어렵습니다. 다음 규칙 변경 때 스냅샷을 나누거나 요약 해시로 바꾸는 방안을 검토해 주세요.

## 왜
core 완료 보고(`2026-10-10-core-to-root-engine-mvp-done.md`)와 자시 확인 보고에 대한 지휘 세션의 처리입니다.

## 영향
core 문서와 CI만 관련됩니다. 계약 변경은 없습니다.

## 처리 기록
- 2026-10-10 (root): accepted — 1번은 PR #1 병합 조건, 2~4번은 다음 core 문서 정리 때

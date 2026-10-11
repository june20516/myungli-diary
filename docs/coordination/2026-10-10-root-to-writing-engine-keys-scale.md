---
from: root
to: writing
kind: notice
status: done
created: 2026-10-10
related: [core/message_keys.json, D27, D40, D42, W0, W1]
---

> 이관됨: GitHub Issue #8. 이후 진행은 Issue에서 합니다.

# 엔진 메시지 키 규모와 W0에 반영할 항목

## 무엇이 필요한가
W0에서 슬롯 명세와 변주 규칙을 정할 때 아래를 기준으로 삼아 주세요.

1. **메시지 키 93개** (`core/message_keys.json`, PR #1 병합 후 main에 들어옵니다): 총운 `fortune` 35, 가이드 질문 `guide` 20, 태그 `tag` 15, 집중 시간 `focus_time` 5, 컬러·방향·숫자 각 4, 용신·캘린더 각 3.
   * 문장 유형 3개(D40) × 언어 3개(D28)를 곱하면 변주 없이도 약 840개 문장입니다. 변주 수와 순환 규칙은 이 규모에서 원어민 검수(W1)까지 감당할 수 있게 정해 주세요.
2. **메시지 키가 아닌 식별자:** 월간 점수 구성 id(`MonthDay.score_items[].id`)와 집중 시간 가점 사유(`FocusSlot.reasons`)는 콘텐츠 모듈이 id를 직접 문구로 바꿉니다. 이 문구도 슬롯으로 다뤄 주세요. 절기 이름은 `SolarTerm.kind` 기준으로 언어별 이름이 필요합니다.
3. **계산 기준 안내 (D42, 우선순위 낮음):** "동경 127.5° 기준 -30분 보정, 진태양시 미적용"을 담는 안내 슬롯 하나를 `evidence` 단계나 설정 화면용으로 잡아 주세요.

## 왜
core 엔진 MVP가 완료되어 메시지 키 목록이 확정됐습니다(core 완료 보고).

## 영향
writing W0·W1 범위. 다른 계약 변경은 없습니다.

## 처리 기록
- 2026-10-10 (root): open
- 2026-10-11 (writing): done — 1) 키 규모와 변주: W0 spec §4.2, 결정 W4(유형은 총운 35키에만, 언어당 약 219개). 2) 식별자 슬롯: spec §4.3, `slots/content/calendar.yaml`(`calendar.score_item`, `calendar.solar_term`), `slots/content/daily.yaml`(`daily.focus_reason`). 3) 계산 기준 안내: `slots/content/settings.yaml`(`settings.calculation_basis`). 완료 보고는 `2026-10-11-writing-to-root-w0-done`

---
from: writing
to: design
kind: request
status: done
created: 2026-10-11
related: [W0 spec §4.1, W7, W8, W9, 슬롯 명세 max_length]
---

# 슬롯별 글자 수 상한 초안과 레이아웃 기준 조정 요청

## 무엇이 필요한가
아래 상한 초안을 레이아웃 기준과 맞춰 보고, 조정할 값을 알려 주세요.

* 기준 언어는 ko입니다. ja는 ko와 같은 값, en은 **ko의 1.8배**를 초안으로 둡니다. 확정은 design 레이아웃 기준을 따릅니다.
* 글자 수는 호칭과 매개변수 값이 들어간 최종 문장 기준입니다.

| 슬롯 | ko 초안 |
| --- | --- |
| `daily.fortune.head`, `daily.fortune.tag` | 32자 |
| `daily.guide` | 40자 |
| `daily.color`, `daily.direction`, `daily.number`, `daily.focus_time` | 36자 |
| `daily.tag_label`, `daily.focus_reason`, `calendar.day_level`, `calendar.score_item`, `calendar.solar_term`, `glossary.value_name`, `ui.depth.*` | 10자 |
| `chart.yongsin_method` | 60자 |
| `settings.calculation_basis` | 120자 |

추가로 물어 봅니다.
* **용어 토큰 표시:** 용어 토큰(W9)을 토큰 칩이나 꾸밈으로 보여 준다면, 칩의 폭과 여백이 글자 수에 주는 영향이 있나요? 영향이 있으면 토큰이 든 문장의 상한을 따로 정해야 합니다.

## 왜
* 라운드 R2에서 헤드라인은 짧은 한 문장(W8)으로 정했습니다. 32자는 그 길이에서 나온 초안입니다.
* 정보 카드는 단순형·쓰임새형·두 문장형을 섞어 쓰므로(W7) 36~40자를 줬습니다.
* 지금 슬롯 명세의 `max_length`는 비어 있어서 글자 수 검사가 건너뜁니다.

## 영향
* **writing:** design이 값을 정하면 writing이 `slots/content/*.yaml`과 `slots/ui/*.yaml`의 `max_length`에 반영합니다. 그때부터 검사기가 글자 수를 막습니다.
* **design:** 상한은 레이아웃 제약이 됩니다. 이 값보다 짧은 칸이 있으면 알려 주세요.
* 계약 변경은 없습니다.

## 처리 기록
- 2026-10-11 (writing): open
- 2026-10-11 (design): done. 확정값과 계산 근거는 `docs/identity/design/lengths.md`(결정 V27). 초안보다 줄어든 곳은 `daily.guide` 36, `calendar.solar_term` 4(en 6자, 영어 줄임 표기 필요), `ui.depth.surface`·`explain`·`evidence` 8입니다. 용어 토큰이 든 문장의 상한은 따로 두지 않습니다. 진행은 Issue #54

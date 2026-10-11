---
from: root
to: core
kind: notice
status: open
created: 2026-10-10
related: [D37, D11, D16, 엔진 spec §2·§5·§8, source_ref 계약]
---

> 이관됨: GitHub Issue #4. 이후 진행은 Issue에서 합니다.

# 정보 깊이 용어 개정: Easy/Pro → surface / explain / evidence (D37)

## 무엇이 필요한가
문서에서 "Pro 화면"처럼 쓰던 표현을 D37 용어로 바꿔 주세요. 엔진 동작과 계약 형식은 바뀌지 않습니다.

| 기존 | 새 이름 |
| --- | --- |
| Easy | `surface` (표면) |
| (괄호 속 풀이) | `explain` (풀이) |
| Pro | `evidence` (근거) |

현재 core 소유 문서에서 찾은 곳:
* `core/CLAUDE.md:17` — "Pro 화면의 근거 표시"
* `core/docs/specs/2026-10-10-myungri-engine-design.md:48, 165, 283` — "Pro 원본 데이터", "Pro 화면"

proto 필드 이름이나 코드 식별자에 `easy`/`pro`를 쓰려던 곳이 있다면, Task 14(계약 동결) 전에 이 이름으로 맞춰 주세요. 급하지 않으며 다음 문서 정리 때 반영하면 됩니다.

**함께 알림:** 엔진 spec(`core/docs/specs/2026-10-10-myungri-engine-design.md:208`)이 오행 색 이름의 근거를 `06 §2`로 적고 있습니다. 색 이름과 값은 앞으로 design 작업 단위의 디자인 토큰(V1)이 정합니다(D38). 엔진은 오행 코드만 반환하면 되므로 동작 변경은 없습니다. 근거 표기만 바꿔 주세요.

## 왜
"Pro"가 유료 등급으로 읽힐 수 있어(D11), 깊이 축을 내용의 역할로 부르기로 했습니다(D37, 브랜드 기반 라운드 4).

## 영향
core 문서 표현만 바뀝니다. 하위 호환이 깨지지 않습니다.

## 처리 기록
- 2026-10-10 (root): open — 낮은 우선순위, C2(계약 동결) 전까지

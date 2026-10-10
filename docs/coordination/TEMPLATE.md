---
from: core | server | app | writing | design | root
to: core | server | app | writing | design | root
kind: request | report | notice      # 요청 / 완료 보고 / 하위 호환이 깨지는 변경 공지
status: open                          # open → accepted | rejected → done
created: YYYY-MM-DD
related: [D<n>, 계약 이름, spec 절 등]
---

# <한 줄 제목>

## 무엇이 필요한가 / 무엇을 했는가
<구체적으로. 요청이면 원하는 결과를, 보고면 바뀐 것과 그 버전을 적습니다.>

## 왜
<근거가 되는 결정·spec·버그.>

## 영향
<영향받는 서브 프로젝트와 계약. 하위 호환이 깨지는지 여부.>

## 처리 기록
<!-- 지휘 세션과 받는 쪽이 날짜와 함께 덧붙입니다. -->
- YYYY-MM-DD (root): accepted — <우선순위·마일스톤>
- YYYY-MM-DD (<받는 쪽>): done — <commit / PR>

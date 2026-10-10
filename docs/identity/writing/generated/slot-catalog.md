<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->

# 슬롯 목록

원본은 `slots/`의 YAML입니다. 글자 수 상한의 `-`는 아직 정하지 않음입니다. 값 종류는 범주 목록(첫째가 기본), `list:<범주>`, `number`, `none`이고 `name`은 어느 슬롯에서나 씁니다.

| ID | 목적 | 유형 | 변주 | 키 수 | 매개변수: 값 종류 | 글자 수 상한 |
| --- | --- | --- | --- | --- | --- | --- |
| calendar.day_level | info | - | 1 | 3 | `score`: number | ko -, en -, ja - |
| calendar.score_item | info | - | 1 | 7 | - | ko -, en -, ja - |
| calendar.solar_term | info | - | 1 | 24 | - | ko -, en -, ja - |
| chart.yongsin_method | info | - | 1 | 3 | `yongsin`: element, color<br>`huisin`: element, color<br>`gisin`: element, color<br>`tonggwan`: element, color | ko -, en -, ja - |
| daily.color | info | - | 1 | 4 | `element`: element, color<br>`role`: none | ko -, en -, ja - |
| daily.direction | info | - | 1 | 4 | `direction`: direction8<br>`rule_id`: none | ko -, en -, ja - |
| daily.focus_reason | info | - | 1 | 4 | - | ko -, en -, ja - |
| daily.focus_time | info | - | 1 | 5 | `branches`: list:branch<br>`score`: number | ko -, en -, ja - |
| daily.fortune.head | info | advice, state, care | 1 | 20 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko -, en -, ja - |
| daily.fortune.tag | info | advice, state, care | 1 | 15 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko -, en -, ja - |
| daily.guide | guide | - | 2 | 20 | `ten_god`: ten_god, ten_god_group<br>`element`: element, color | ko -, en -, ja - |
| daily.number | info | - | 1 | 4 | `number`: number<br>`element`: element, color | ko -, en -, ja - |
| daily.tag_label | info | - | 1 | 15 | - | ko -, en -, ja - |
| glossary.value_name | info | - | 1 | 69 | - | ko -, en -, ja - |
| settings.calculation_basis | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.default_label | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.evidence | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.explain | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.surface | info | - | 1 | 1 | - | ko -, en -, ja - |

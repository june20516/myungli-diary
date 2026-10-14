<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->

# 슬롯 목록

원본은 `slots/`의 YAML입니다. 글자 수 상한의 `-`는 아직 정하지 않음입니다. 값 종류는 범주 목록(첫째가 기본), `list:<범주>`, `number`, `none`이고 `name`은 어느 슬롯에서나 씁니다.

| ID | 자리 | 목적 | 유형 | 변주 | 키 수 | 매개변수: 값 종류 | 글자 수 상한 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| calendar.day_level | 컴포넌트 day-character<br>컴포넌트 day-cell | info | - | 1 | 3 | `score`: number | ko 10, en 18, ja 10 |
| calendar.score_item | 컴포넌트 term-token | info | - | 1 | 7 | - | ko 10, en 18, ja 10 |
| calendar.solar_term | 컴포넌트 day-cell | info | - | 1 | 24 | - | ko 4, en 6, ja 3 |
| character.reason | today.character.reason<br>day-sheet.character.reason<br>event-edit.character.hint | info | - | 1 | 4 | - | ko -, en -, ja - |
| chart.ilgan_body | my-saju.ilgan.body | info | - | 1 | 10 | - | ko -, en -, ja - |
| chart.ilgan_head | my-saju.ilgan.head | info | - | 1 | 10 | - | ko -, en -, ja - |
| chart.yongsin_method | saju-chart.yongsin.basis | info | - | 1 | 3 | `yongsin`: element, color<br>`huisin`: element, color<br>`gisin`: element, color<br>`tonggwan`: element, color | ko 60, en 108, ja 60 |
| chart.yongsin_summary | my-saju.yongsin.body | info | - | 1 | 1 | `yongsin`: element, color | ko -, en -, ja - |
| daily.color | today.lucky-color.body | info | - | 1 | 4 | `element`: element, color<br>`role`: none | ko 36, en 64, ja 36 |
| daily.direction | today.lucky-direction.body | info | - | 1 | 4 | `direction`: direction8<br>`rule_id`: none | ko 36, en 64, ja 36 |
| daily.focus_reason | 컴포넌트 lucky-card | info | - | 1 | 4 | - | ko 10, en 18, ja 10 |
| daily.focus_time | today.lucky-time.body | info | - | 1 | 5 | `branches`: list:branch<br>`score`: number | ko 36, en 64, ja 36 |
| daily.fortune.head | today.fortune.head<br>preview.fortune.head<br>system-push.morning.body | info | advice, state, care | 1 | 20 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko 32, en 57, ja 32 |
| daily.fortune.tag | today.fortune.body<br>preview.fortune.body | info | advice, state, care | 1 | 15 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko 32, en 57, ja 32 |
| daily.guide | today.guide.question<br>diary-edit.guide.question | guide | - | 2 | 20 | `ten_god`: ten_god, ten_god_group<br>`element`: element, color | ko 36, en 70, ja 30 |
| daily.number | today.lucky-number.body | info | - | 1 | 4 | `number`: number<br>`element`: element, color | ko 36, en 64, ja 36 |
| daily.tag_label | 컴포넌트 tag-chip | info | - | 1 | 15 | - | ko 10, en 18, ja 10 |
| evidence.basis | evidence-sheet.basis.body | info | - | 1 | 0 | - | ko -, en -, ja - |
| evidence.source | evidence-sheet.source.quote | info | - | 1 | 0 | - | ko -, en -, ja - |
| explain.today_reason | explain-sheet.today.reason | info | - | 1 | 0 | - | ko -, en -, ja - |
| glossary.value_name | today.character.label<br>preview.character.label<br>day-sheet.character.label<br>diary-view.character.label<br>컴포넌트 lucky-card<br>컴포넌트 saju-pillars<br>컴포넌트 manse-table<br>컴포넌트 daeun-table<br>컴포넌트 ohaeng-bar | info | - | 1 | 94 | - | ko 10, en 18, ja 10 |
| onboard.hour_confirm | onboard-time.hour.confirm | info | - | 1 | 1 | `branch`: branch<br>`start`: text<br>`end`: text | ko -, en -, ja - |
| personal.day_master | evidence-sheet.personal.body | info | - | 1 | 10 | `strength`: strength<br>`yongsin`: element, color<br>`gisin`: element, color | ko -, en -, ja - |
| personal.luck | evidence-sheet.personal.body | info | - | 1 | 22 | `luck`: luck<br>`part`: part<br>`element`: element, color<br>`role`: role<br>`current`: none | ko -, en -, ja - |
| personal.shinsal | evidence-sheet.personal.body | info | - | 1 | 6 | `place`: place<br>`element`: element, color<br>`role`: role | ko -, en -, ja - |
| personal.ten_god | evidence-sheet.personal.body | info | - | 1 | 10 | `place`: place<br>`element`: element, color<br>`role`: role<br>`group_count`: number<br>`strength`: strength | ko -, en -, ja - |
| personal.twelve_stage | evidence-sheet.personal.body | info | - | 1 | 12 | `place`: place<br>`element`: element, color<br>`role`: role<br>`strength`: strength | ko -, en -, ja - |
| system.apple_return | system-apple-return.page.title<br>system-apple-return.page.body<br>system-apple-return.page.open<br>system-apple-return.page.install | guide | - | 1 | 4 | - | ko -, en -, ja - |
| term.meaning | explain-sheet.term.meaning<br>tag-diary.tag.meaning | info | - | 1 | 77 | - | ko -, en -, ja - |
| ui.depth.default_label | - | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.evidence | - | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.explain | - | info | - | 1 | 1 | - | ko -, en -, ja - |
| ui.depth.surface | - | info | - | 1 | 1 | - | ko -, en -, ja - |

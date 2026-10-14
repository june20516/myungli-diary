<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->

# 슬롯 목록

원본은 `slots/`의 YAML입니다. 글자 수 상한의 `-`는 아직 정하지 않음입니다. 값 종류는 범주 목록(첫째가 기본), `list:<범주>`, `number`, `none`이고 `name`은 어느 슬롯에서나 씁니다.

| ID | 자리 | 목적 | 유형 | 변주 | 키 수 | 매개변수: 값 종류 | 글자 수 상한 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| account-delete.cta.delete | account-delete.cta.delete | guide | - | 1 | 1 | - | ko -, en -, ja - |
| account-delete.data.body | account-delete.data.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| account-delete.delete.confirm | account-delete.delete.confirm | guide | - | 1 | 3 | - | ko -, en -, ja - |
| account-delete.title.head | account-delete.title.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.legal.notice | ad-free.legal.notice | guide | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.offer.head | ad-free.offer.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.offer.price | ad-free.offer.price | info | - | 1 | 1 | `price`: text | ko -, en -, ja - |
| ad-free.restore.cta | ad-free.restore.cta | guide | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.status.remaining | ad-free.status.remaining | info | - | 1 | 1 | `date`: text | ko -, en -, ja - |
| birthplace.empty.body | birthplace.empty.body | guide | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.question.head | birthplace.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.search.hint | birthplace.search.hint | guide | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.why.body | birthplace.why.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calc-basis.convention.body | calc-basis.convention.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calc-basis.longitude.body | calc-basis.longitude.body | info | - | 1 | 1 | - | ko 120, en 216, ja 120 |
| calc-basis.lunar.body | calc-basis.lunar.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calendar.day_level | 컴포넌트 day-character<br>컴포넌트 day-cell | info | - | 1 | 3 | `score`: number | ko 10, en 18, ja 10 |
| calendar.legend.body | calendar.legend.body | info | - | 1 | 2 | - | ko -, en -, ja - |
| calendar.score_item | 컴포넌트 term-token | info | - | 1 | 7 | - | ko 10, en 18, ja 10 |
| calendar.solar_term | 컴포넌트 day-cell | info | - | 1 | 24 | - | ko 4, en 6, ja 3 |
| character.reason | today.character.reason<br>day-sheet.character.reason<br>event-edit.character.hint | info | - | 1 | 4 | - | ko -, en -, ja - |
| chart.ilgan_body | my-saju.ilgan.body | info | - | 1 | 10 | - | ko -, en -, ja - |
| chart.ilgan_head | my-saju.ilgan.head | info | - | 1 | 10 | - | ko -, en -, ja - |
| chart.yongsin_method | saju-chart.yongsin.basis | info | - | 1 | 3 | `yongsin`: element, color<br>`huisin`: element, color<br>`gisin`: element, color<br>`tonggwan`: element, color | ko 60, en 108, ja 60 |
| chart.yongsin_summary | my-saju.yongsin.body | info | - | 1 | 1 | `yongsin`: element, color | ko -, en -, ja - |
| consent.cta.agree | consent.cta.agree | guide | - | 1 | 1 | - | ko -, en -, ja - |
| consent.required.label | consent.required.label | info | - | 1 | 2 | - | ko -, en -, ja - |
| consent.title.head | consent.title.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| daily.color | today.lucky-color.body | info | - | 1 | 4 | `element`: element, color<br>`role`: none | ko 36, en 64, ja 36 |
| daily.direction | today.lucky-direction.body | info | - | 1 | 4 | `direction`: direction8<br>`rule_id`: none | ko 36, en 64, ja 36 |
| daily.focus_reason | 컴포넌트 lucky-card | info | - | 1 | 4 | - | ko 10, en 18, ja 10 |
| daily.focus_time | today.lucky-time.body | info | - | 1 | 5 | `branches`: list:branch<br>`score`: number | ko 36, en 64, ja 36 |
| daily.fortune.head | today.fortune.head<br>preview.fortune.head<br>system-push.morning.body | info | advice, state, care | 1 | 20 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko 32, en 57, ja 32 |
| daily.fortune.tag | today.fortune.body<br>preview.fortune.body | info | advice, state, care | 1 | 15 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko 32, en 57, ja 32 |
| daily.guide | today.guide.question<br>diary-edit.guide.question | guide | - | 2 | 20 | `ten_god`: ten_god, ten_god_group<br>`element`: element, color | ko 36, en 70, ja 30 |
| daily.number | today.lucky-number.body | info | - | 1 | 4 | `number`: number<br>`element`: element, color | ko 36, en 64, ja 36 |
| daily.tag_label | 컴포넌트 tag-chip | info | - | 1 | 15 | - | ko 10, en 18, ja 10 |
| day-sheet.diary.open | day-sheet.diary.open | guide | - | 1 | 1 | - | ko -, en -, ja - |
| day-sheet.diary.write-cta | day-sheet.diary.write-cta | guide | - | 1 | 1 | - | ko -, en -, ja - |
| day-sheet.event.add | day-sheet.event.add | guide | - | 1 | 1 | - | ko -, en -, ja - |
| day-sheet.event.empty | day-sheet.event.empty | info | - | 1 | 1 | - | ko -, en -, ja - |
| diary-edit.body.placeholder | diary-edit.body.placeholder | guide | - | 1 | 1 | - | ko -, en -, ja - |
| diary-edit.draft.status | diary-edit.draft.status | info | - | 1 | 3 | - | ko -, en -, ja - |
| diary-edit.offline.notice | diary-edit.offline.notice | info | - | 1 | 1 | - | ko -, en -, ja - |
| diary-edit.saved.tags | diary-edit.saved.tags | info | - | 1 | 1 | - | ko -, en -, ja - |
| diary-list.empty.body | diary-list.empty.body | guide | - | 1 | 1 | - | ko -, en -, ja - |
| diary-list.pick-date.cta | diary-list.pick-date.cta | guide | - | 1 | 1 | - | ko -, en -, ja - |
| diary-view.delete.confirm | diary-view.delete.confirm | guide | - | 1 | 3 | - | ko -, en -, ja - |
| event-edit.delete.confirm | event-edit.delete.confirm | guide | - | 1 | 3 | - | ko -, en -, ja - |
| event-edit.memo.hint | event-edit.memo.hint | guide | - | 1 | 1 | - | ko -, en -, ja - |
| event-edit.title.hint | event-edit.title.hint | guide | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.a11y.checking | evidence-sheet.a11y.checking | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.a11y.locked | evidence-sheet.a11y.locked | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.a11y.unlocked | evidence-sheet.a11y.unlocked | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.lock.cta | evidence-sheet.lock.cta | guide | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.lock.head | evidence-sheet.lock.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.lock.pass | evidence-sheet.lock.pass | info | - | 1 | 2 | - | ko -, en -, ja - |
| evidence-sheet.lock.reward | evidence-sheet.lock.reward | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.lock.unavailable | evidence-sheet.lock.unavailable | guide | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.section.basis | evidence-sheet.section.basis | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.section.personal | evidence-sheet.section.personal | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.section.source | evidence-sheet.section.source | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.unlock.failed | evidence-sheet.unlock.failed | guide | - | 1 | 1 | - | ko -, en -, ja - |
| evidence.basis | evidence-sheet.basis.body | info | - | 1 | 0 | - | ko -, en -, ja - |
| evidence.source | evidence-sheet.source.quote | info | - | 1 | 0 | - | ko -, en -, ja - |
| explain.today_reason | explain-sheet.today.reason | info | - | 1 | 0 | - | ko -, en -, ja - |
| force-update.cta.store | force-update.cta.store | guide | - | 1 | 1 | - | ko -, en -, ja - |
| force-update.notice.body | force-update.notice.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| force-update.notice.head | force-update.notice.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| glossary.value_name | today.character.label<br>preview.character.label<br>day-sheet.character.label<br>diary-view.character.label<br>컴포넌트 lucky-card<br>컴포넌트 saju-pillars<br>컴포넌트 manse-table<br>컴포넌트 daeun-table<br>컴포넌트 ohaeng-bar | info | - | 1 | 94 | - | ko 10, en 18, ja 10 |
| login.discard.notice | login.discard.notice | info | - | 1 | 1 | - | ko -, en -, ja - |
| login.title.body | login.title.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| login.title.head | login.title.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| notify-ask.cta.skip | notify-ask.cta.skip | guide | - | 1 | 1 | - | ko -, en -, ja - |
| notify-ask.question.head | notify-ask.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| notify-ask.why.body | notify-ask.why.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.basis.note | onboard-birth.basis.note | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.calendar.hint | onboard-birth.calendar.hint | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.error.range | onboard-birth.error.range | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.question.head | onboard-birth.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-call.input.hint | onboard-call.input.hint | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-call.note.body | onboard-call.note.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-call.question.head | onboard-call.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-gender.question.head | onboard-gender.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-gender.why.body | onboard-gender.why.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-time.question.head | onboard-time.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-time.unknown.note | onboard-time.unknown.note | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard.hour_confirm | onboard-time.hour.confirm | info | - | 1 | 1 | `branch`: branch<br>`start`: text<br>`end`: text | ko -, en -, ja - |
| personal.day_master | evidence-sheet.personal.body | info | - | 1 | 10 | `strength`: strength<br>`yongsin`: element, color<br>`gisin`: element, color | ko -, en -, ja - |
| personal.luck | evidence-sheet.personal.body | info | - | 1 | 22 | `luck`: luck<br>`part`: part<br>`element`: element, color<br>`role`: role<br>`current`: none | ko -, en -, ja - |
| personal.shinsal | evidence-sheet.personal.body | info | - | 1 | 6 | `place`: place<br>`element`: element, color<br>`role`: role | ko -, en -, ja - |
| personal.ten_god | evidence-sheet.personal.body | info | - | 1 | 10 | `place`: place<br>`element`: element, color<br>`role`: role<br>`group_count`: number<br>`strength`: strength | ko -, en -, ja - |
| personal.twelve_stage | evidence-sheet.personal.body | info | - | 1 | 12 | `place`: place<br>`element`: element, color<br>`role`: role<br>`strength`: strength | ko -, en -, ja - |
| preview.cta.restart | preview.cta.restart | guide | - | 1 | 1 | - | ko -, en -, ja - |
| preview.cta.save | preview.cta.save | guide | - | 1 | 1 | - | ko -, en -, ja - |
| preview.share.login-notice | preview.share.login-notice | guide | - | 1 | 3 | - | ko -, en -, ja - |
| profile-edit.recalc.confirm | profile-edit.recalc.confirm | guide | - | 1 | 4 | `before`: text<br>`after`: text | ko -, en -, ja - |
| profile-edit.recalc.notice | profile-edit.recalc.notice | info | - | 1 | 1 | - | ko -, en -, ja - |
| saju-chart.time-unknown.notice | saju-chart.time-unknown.notice | info | - | 1 | 1 | - | ko -, en -, ja - |
| saju-chart.yongsin.open | saju-chart.yongsin.open | guide | - | 1 | 1 | - | ko -, en -, ja - |
| saju-chart.yongsin.title | saju-chart.yongsin.title | info | - | 1 | 1 | - | ko -, en -, ja - |
| settings.ad-free.label | settings.ad-free.label | info | - | 1 | 2 | `date`: text | ko -, en -, ja - |
| settings.depth.desc | settings.depth.desc | info | - | 1 | 1 | - | ko -, en -, ja - |
| settings.language.birthplace-notice | settings.language.birthplace-notice | guide | - | 1 | 2 | - | ko -, en -, ja - |
| settings.logout.confirm | settings.logout.confirm | guide | - | 1 | 3 | - | ko -, en -, ja - |
| share-preview.cta.share | share-preview.cta.share | guide | - | 1 | 1 | - | ko -, en -, ja - |
| share-preview.image.footer | share-preview.image.footer | info | - | 1 | 1 | - | ko -, en -, ja - |
| share-preview.image.tagline | share-preview.image.tagline | info | - | 1 | 1 | - | ko -, en -, ja - |
| share-preview.ratio.label | share-preview.ratio.label | info | - | 1 | 3 | - | ko -, en -, ja - |
| system.apple_return | system-apple-return.page.title<br>system-apple-return.page.body<br>system-apple-return.page.open<br>system-apple-return.page.install | guide | - | 1 | 4 | - | ko -, en -, ja - |
| tag-diary.empty.body | tag-diary.empty.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| term.meaning | explain-sheet.term.meaning<br>tag-diary.tag.meaning | info | - | 1 | 77 | - | ko -, en -, ja - |
| today.event.summary | today.event.summary | info | - | 1 | 4 | `count`: number<br>`title`: text | ko -, en -, ja - |
| today.guide.cta | today.guide.cta | guide | - | 1 | 2 | - | ko -, en -, ja - |
| today.reaction.label | today.reaction.label | info | - | 1 | 2 | - | ko -, en -, ja - |
| ui.depth.default_label | 컴포넌트 settings-row | info | - | 1 | 1 | - | ko 10, en 18, ja 10 |
| ui.depth.evidence | 컴포넌트 segmented | info | - | 1 | 1 | - | ko 8, en 13, ja 6 |
| ui.depth.explain | 컴포넌트 segmented | info | - | 1 | 1 | - | ko 8, en 13, ja 6 |
| ui.depth.surface | 컴포넌트 segmented | info | - | 1 | 1 | - | ko 8, en 13, ja 6 |
| welcome.concept.body | welcome.concept.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| welcome.concept.head | welcome.concept.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| welcome.cta.signin | welcome.cta.signin | guide | - | 1 | 1 | - | ko -, en -, ja - |
| welcome.cta.start | welcome.cta.start | guide | - | 1 | 1 | - | ko -, en -, ja - |

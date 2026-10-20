<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->

# 슬롯 목록

원본은 `slots/`의 YAML입니다. 글자 수 상한의 `-`는 아직 정하지 않음입니다. 값 종류는 범주 목록(첫째가 기본), `list:<범주>`, `number`, `none`, `text`이고 `name`은 어느 슬롯에서나 씁니다.

| ID | 자리 | 목적 | 유형 | 변주 | 키 수 | 매개변수: 값 종류 | 글자 수 상한 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| account-delete.bar.title | account-delete.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| account-delete.cta.delete | account-delete.cta.delete | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| account-delete.data.body | account-delete.data.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| account-delete.delete.confirm | account-delete.delete.confirm | guide | - | 1 | 3 | - | ko 10, en 16, ja 7<br>`accountDeleteDeleteConfirm` ko 34, en 60, ja 28 |
| account-delete.title.head | account-delete.title.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.bar.title | ad-free.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.legal.notice | ad-free.legal.notice | guide | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.offer.head | ad-free.offer.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| ad-free.offer.price | ad-free.offer.price | info | - | 1 | 1 | `price`: text | ko -, en -, ja - |
| ad-free.restore.cta | ad-free.restore.cta | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| ad-free.status.remaining | ad-free.status.remaining | info | - | 1 | 1 | `date`: text | ko -, en -, ja - |
| birthplace.bar.title | birthplace.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.empty.body | birthplace.empty.body | guide | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.question.head | birthplace.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.search.hint | birthplace.search.hint | guide | - | 1 | 1 | - | ko 15, en 27, ja 12 |
| birthplace.standard.link | birthplace.standard.link | guide | - | 1 | 1 | - | ko 25, en 45, ja 20 |
| birthplace.standard.note | birthplace.standard.note | info | - | 1 | 1 | - | ko -, en -, ja - |
| birthplace.why.body | birthplace.why.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calc-basis.bar.title | calc-basis.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| calc-basis.convention.body | calc-basis.convention.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calc-basis.longitude.body | calc-basis.longitude.body | info | - | 1 | 8 | `longitude`: text<br>`minutes`: number<br>`dstMinutes`: number<br>`degrees`: text | ko 120, en 216, ja 120 |
| calc-basis.lunar.body | calc-basis.lunar.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calc-basis.schools.body | calc-basis.schools.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| calendar.bar.title | calendar.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| calendar.day_level | 컴포넌트 day-character<br>컴포넌트 day-cell | info | - | 1 | 3 | `score`: number | ko 10, en 18, ja 10 |
| calendar.legend.body | calendar.legend.body | info | - | 1 | 2 | - | ko -, en -, ja - |
| calendar.score_item | 컴포넌트 term-token | info | - | 1 | 7 | - | ko 10, en 18, ja 10 |
| calendar.solar_term | 컴포넌트 day-cell | info | - | 1 | 24 | - | ko 4, en 6, ja 3 |
| character.reason | today.character.reason<br>day-sheet.character.reason<br>event-edit.character.hint | info | - | 1 | 4 | - | ko 57, en 90, ja 39 |
| chart.ilgan_body | my-saju.ilgan.body | info | - | 1 | 10 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| chart.ilgan_head | my-saju.ilgan.head | info | - | 1 | 10 | - | ko 42, en 82, ja 34 |
| chart.yongsin_method | saju-chart.yongsin.basis | info | - | 1 | 3 | `yongsin`: element, color<br>`huisin`: element, color<br>`gisin`: element, color<br>`tonggwan`: element, color | ko 60, en 108, ja 60 |
| chart.yongsin_summary | my-saju.yongsin.body | info | - | 1 | 1 | `yongsin`: element, color | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| consent.bar.title | consent.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| consent.cta.agree | consent.cta.agree | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| consent.required.label | consent.required.label | info | - | 1 | 2 | - | ko 34, en 64, ja 28 |
| consent.title.head | consent.title.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| daily.color | today.lucky-color.body | info | - | 1 | 4 | `element`: element, color<br>`role`: none | ko 36, en 64, ja 36 |
| daily.direction | today.lucky-direction.body | info | - | 1 | 4 | `direction`: direction8<br>`rule_id`: none | ko 36, en 64, ja 36 |
| daily.focus_reason | 컴포넌트 lucky-card | info | - | 1 | 4 | - | ko 10, en 18, ja 10 |
| daily.focus_time | today.lucky-time.body | info | - | 1 | 5 | `branches`: list:branch<br>`score`: number | ko 36, en 64, ja 36 |
| daily.fortune.head | today.fortune.head<br>preview.fortune.head<br>system-push.morning.body | info | advice, state, care | 1 | 20 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko 32, en 57, ja 32 |
| daily.fortune.tag | today.fortune.body<br>preview.fortune.body | info | advice, state, care | 1 | 15 | `day_kind`: day_kind<br>`ten_god`: ten_god, ten_god_group<br>`element`: element, color<br>`emphasis`: none | ko 32, en 57, ja 32 |
| daily.guide | today.guide.question<br>diary-edit.guide.question | guide | - | 2 | 20 | `ten_god`: ten_god, ten_god_group<br>`element`: element, color | ko 36, en 70, ja 30 |
| daily.number | today.lucky-number.body | info | - | 1 | 4 | `number`: number<br>`element`: element, color | ko 36, en 64, ja 36 |
| daily.tag_label | 컴포넌트 tag-chip<br>컴포넌트 lucky-card | info | - | 1 | 15 | - | ko 10, en 18, ja 10 |
| day-sheet.diary.open | day-sheet.diary.open | guide | - | 1 | 1 | - | ko 25, en 45, ja 20 |
| day-sheet.diary.write-cta | day-sheet.diary.write-cta | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| day-sheet.event.add | day-sheet.event.add | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| day-sheet.event.empty | day-sheet.event.empty | info | - | 1 | 1 | - | ko -, en -, ja - |
| diary-edit.bar.title | diary-edit.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| diary-edit.body.placeholder | diary-edit.body.placeholder | guide | - | 1 | 1 | - | ko 42, en 82, ja 36 |
| diary-edit.draft.status | diary-edit.draft.status | info | - | 1 | 3 | - | ko -, en -, ja - |
| diary-edit.offline.notice | diary-edit.offline.notice | info | - | 1 | 1 | - | ko 52, en 90, ja 38 |
| diary-edit.saved.tags | diary-edit.saved.tags | info | - | 1 | 1 | - | ko 48, en 78, ja 34 |
| diary-list.bar.title | diary-list.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| diary-list.empty.body | diary-list.empty.body | guide | - | 1 | 1 | - | ko -, en -, ja - |
| diary-list.pick-date.cta | diary-list.pick-date.cta | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| diary-view.bar.title | diary-view.bar.title | guide | - | 1 | 1 | `date`: text | ko -, en -, ja - |
| diary-view.delete.confirm | diary-view.delete.confirm | guide | - | 1 | 3 | - | ko 10, en 16, ja 7<br>`diaryViewDeleteConfirm` ko 34, en 60, ja 28 |
| event-edit.bar.title | event-edit.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| event-edit.delete.confirm | event-edit.delete.confirm | guide | - | 1 | 3 | - | ko 10, en 16, ja 7<br>`eventEditDeleteConfirm` ko 34, en 60, ja 28 |
| event-edit.memo.hint | event-edit.memo.hint | guide | - | 1 | 1 | - | ko 17, en 31, ja 14 |
| event-edit.title.hint | event-edit.title.hint | guide | - | 1 | 1 | - | ko 17, en 31, ja 14 |
| evidence-sheet.a11y.checking | evidence-sheet.a11y.checking | info | - | 1 | 1 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| evidence-sheet.a11y.locked | evidence-sheet.a11y.locked | info | - | 1 | 1 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| evidence-sheet.a11y.unlocked | evidence-sheet.a11y.unlocked | info | - | 1 | 1 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| evidence-sheet.lock.cta | evidence-sheet.lock.cta | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| evidence-sheet.lock.head | evidence-sheet.lock.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.lock.pass | evidence-sheet.lock.pass | info | - | 1 | 2 | - | ko -, en -, ja - |
| evidence-sheet.lock.reward | evidence-sheet.lock.reward | info | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.lock.unavailable | evidence-sheet.lock.unavailable | guide | - | 1 | 1 | - | ko -, en -, ja - |
| evidence-sheet.section.basis | evidence-sheet.section.basis | info | - | 1 | 1 | - | ko 27, en 50, ja 22 |
| evidence-sheet.section.personal | evidence-sheet.section.personal | info | - | 1 | 1 | - | ko 27, en 50, ja 22 |
| evidence-sheet.section.source | evidence-sheet.section.source | info | - | 1 | 1 | - | ko 27, en 50, ja 22 |
| evidence-sheet.unlock.failed | evidence-sheet.unlock.failed | guide | - | 1 | 1 | - | ko 48, en 78, ja 34 |
| evidence.basis | evidence-sheet.basis.body | info | - | 1 | 24 | `breakdown`: none<br>`score`: none<br>`day_kind`: none<br>`element`: none<br>`note`: none<br>`role`: none<br>`day_branch`: none<br>`direction`: none<br>`deity`: none<br>`picks`: none<br>`group`: none<br>`ten_god`: none<br>`featured`: none<br>`basis`: none<br>`day_stem`: none<br>`number`: none<br>`parity`: none<br>`gisin`: none<br>`strength`: none<br>`yongsin`: none<br>`current`: none<br>`luck`: none<br>`part`: none<br>`place`: none<br>`group_count`: none<br>`all`: none<br>`strength_level`: none<br>`strength_score`: none<br>`month_branch`: none<br>`share`: none<br>`threshold`: none | ko -, en -, ja - |
| evidence.source | evidence-sheet.source.quote | info | - | 1 | 124 | - | ko -, en -, ja - |
| explain.today_reason | explain-sheet.today.reason | info | - | 1 | 13 | - | ko -, en -, ja - |
| force-update.cta.store | force-update.cta.store | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| force-update.notice.body | force-update.notice.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| force-update.notice.head | force-update.notice.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| glossary.value_name | today.character.label<br>preview.character.label<br>day-sheet.character.label<br>diary-view.character.label<br>컴포넌트 lucky-card<br>컴포넌트 saju-pillars<br>컴포넌트 manse-table<br>컴포넌트 daeun-table<br>컴포넌트 ohaeng-bar | info | - | 1 | 94 | - | ko 10, en 18, ja 10 |
| legal.bar.title | legal.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| login.bar.title | login.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| login.discard.notice | login.discard.notice | info | - | 1 | 1 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| login.title.body | login.title.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| login.title.head | login.title.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| my-saju.bar.title | my-saju.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| notify-ask.bar.title | notify-ask.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| notify-ask.cta.allow | notify-ask.cta.allow | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| notify-ask.cta.skip | notify-ask.cta.skip | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| notify-ask.question.head | notify-ask.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| notify-ask.why.body | notify-ask.why.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.bar.title | onboard-birth.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.basis.note | onboard-birth.basis.note | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.calendar.hint | onboard-birth.calendar.hint | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.error.range | onboard-birth.error.range | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-birth.question.head | onboard-birth.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-call.bar.title | onboard-call.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-call.input.hint | onboard-call.input.hint | guide | - | 1 | 1 | - | ko 17, en 31, ja 14 |
| onboard-call.note.body | onboard-call.note.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-call.question.head | onboard-call.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-gender.bar.title | onboard-gender.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-gender.question.head | onboard-gender.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-gender.why.body | onboard-gender.why.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-time.bar.title | onboard-time.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-time.hour.confirm | onboard-time.hour.confirm | info | - | 1 | 1 | `branch`: text<br>`start`: text<br>`end`: text | ko 29, en 54, ja 23 |
| onboard-time.question.head | onboard-time.question.head | guide | - | 1 | 1 | - | ko -, en -, ja - |
| onboard-time.unknown.note | onboard-time.unknown.note | info | - | 1 | 1 | - | ko -, en -, ja - |
| personal.day_master | evidence-sheet.personal.body | info | - | 1 | 10 | `strength`: strength<br>`yongsin`: element, color<br>`gisin`: element, color | ko -, en -, ja - |
| personal.luck | evidence-sheet.personal.body | info | - | 1 | 22 | `luck`: luck<br>`part`: part<br>`element`: element, color<br>`role`: role<br>`current`: none | ko -, en -, ja - |
| personal.shinsal | evidence-sheet.personal.body | info | - | 1 | 6 | `place`: place<br>`element`: element, color<br>`role`: role | ko -, en -, ja - |
| personal.ten_god | evidence-sheet.personal.body | info | - | 1 | 10 | `place`: place<br>`element`: element, color<br>`role`: role<br>`group_count`: number<br>`strength`: strength | ko -, en -, ja - |
| personal.twelve_stage | evidence-sheet.personal.body | info | - | 1 | 12 | `place`: place<br>`element`: element, color<br>`role`: role<br>`strength`: strength | ko -, en -, ja - |
| preview.bar.title | preview.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| preview.cta.restart | preview.cta.restart | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| preview.cta.save | preview.cta.save | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| preview.share.login-notice | preview.share.login-notice | guide | - | 1 | 3 | - | ko 10, en 16, ja 7<br>`previewShareLoginNotice` ko 34, en 60, ja 28 |
| profile-edit.bar.title | profile-edit.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| profile-edit.recalc.confirm | profile-edit.recalc.confirm | guide | - | 1 | 4 | `before`: text<br>`after`: text | ko 10, en 16, ja 7<br>`profileEditRecalcConfirmTitle` ko 34, en 60, ja 28<br>`profileEditRecalcConfirmBody` ko 상한 없음, en 상한 없음, ja 상한 없음 |
| profile-edit.recalc.notice | profile-edit.recalc.notice | info | - | 1 | 1 | - | ko -, en -, ja - |
| saju-chart.bar.title | saju-chart.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| saju-chart.time-unknown.notice | saju-chart.time-unknown.notice | info | - | 1 | 1 | - | ko 52, en 90, ja 38 |
| saju-chart.yongsin.open | saju-chart.yongsin.open | guide | - | 1 | 1 | - | ko 12, en 20, ja 9 |
| saju-chart.yongsin.title | saju-chart.yongsin.title | info | - | 1 | 1 | - | ko 27, en 50, ja 22 |
| settings.ad-free.label | settings.ad-free.label | info | - | 1 | 2 | `date`: text | ko 23, en 42, ja 18 |
| settings.bar.title | settings.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| settings.language.birthplace-notice | settings.language.birthplace-notice | guide | - | 1 | 2 | - | ko -, en -, ja - |
| settings.logout.confirm | settings.logout.confirm | guide | - | 1 | 3 | - | ko 10, en 16, ja 7<br>`settingsLogoutConfirm` ko 34, en 60, ja 28 |
| share-preview.cta.share | share-preview.cta.share | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| share-preview.image.footer | share-preview.image.footer | info | - | 1 | 1 | - | ko -, en -, ja - |
| share-preview.image.tagline | share-preview.image.tagline | info | - | 1 | 1 | - | ko -, en -, ja - |
| share-preview.ratio.label | share-preview.ratio.label | info | - | 1 | 3 | - | ko 8, en 13, ja 6 |
| system.apple_return | system-apple-return.page.title<br>system-apple-return.page.body<br>system-apple-return.page.open<br>system-apple-return.page.install | guide | - | 1 | 4 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| system.notice | 컴포넌트 notice-banner | info | - | 1 | 7 | - | ko 52, en 90, ja 38 |
| tag-diary.bar.title | tag-diary.bar.title | guide | - | 1 | 1 | `tag`: text | ko -, en -, ja - |
| tag-diary.empty.body | tag-diary.empty.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| term.meaning | explain-sheet.term.meaning<br>tag-diary.tag.meaning<br>today.lucky-tag.body | info | - | 1 | 77 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| today.bar.title | today.bar.title | guide | - | 1 | 1 | - | ko -, en -, ja - |
| today.event.summary | today.event.summary | info | - | 1 | 6 | `count`: number<br>`title`: text<br>`time`: text | ko -, en -, ja - |
| today.guide.cta | today.guide.cta | guide | - | 1 | 2 | - | ko 23, en 42, ja 19 |
| today.reaction.label | today.reaction.label | info | - | 1 | 2 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.a11y.label | 컴포넌트 primary-button<br>컴포넌트 ad-banner<br>컴포넌트 skeleton<br>컴포넌트 term-token<br>컴포넌트 input-step<br>컴포넌트 text-field<br>컴포넌트 city-search | info | - | 1 | 9 | `term`: text<br>`step`: number<br>`stepCount`: number<br>`current`: number<br>`max`: number<br>`count`: number | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.action.button | 컴포넌트 primary-button<br>컴포넌트 dialog<br>컴포넌트 share-button<br>컴포넌트 check-row<br>컴포넌트 text-field<br>컴포넌트 input-step | guide | - | 1 | 8 | - | ko 10, en 16, ja 7 |
| ui.app.bootstrap | 컴포넌트 error-state | info | - | 1 | 1 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.app.name | 컴포넌트 app-bar | info | - | 1 | 1 | - | ko 14, en 24, ja 11 |
| ui.app.notice | 컴포넌트 notice-banner<br>컴포넌트 empty-state | info | - | 1 | 2 | - | ko 52, en 90, ja 38 |
| ui.app.trace | 컴포넌트 error-state<br>컴포넌트 toast | info | - | 1 | 2 | `traceId`: text | ko 48, en 78, ja 34 |
| ui.birth.option | 컴포넌트 segmented<br>컴포넌트 check-row | info | - | 1 | 6 | - | ko 13, en 22, ja 10 |
| ui.calendar.nav | 컴포넌트 calendar-month | guide | - | 1 | 2 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.day-cell.a11y | 컴포넌트 day-cell | info | - | 1 | 6 | `month`: number<br>`day`: number<br>`count`: number | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.day-cell.lunar | 컴포넌트 day-cell | info | - | 1 | 1 | `month`: number | ko -, en -, ja - |
| ui.depth.evidence_link | today.evidence.link<br>컴포넌트 depth-link | guide | - | 1 | 1 | - | ko 25, en 45, ja 20 |
| ui.depth.explain | 컴포넌트 sheet | info | - | 1 | 1 | - | ko 8, en 13, ja 6 |
| ui.diary-edit.save | diary-edit.save.cta<br>컴포넌트 primary-button | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| ui.diary-list.pick-date-confirm | diary-list.pick-date.confirm<br>컴포넌트 date-picker | guide | - | 1 | 1 | `date`: text | ko 23, en 42, ja 19 |
| ui.diary-view.actions | 컴포넌트 app-bar | info | - | 1 | 2 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.diary-view.deleted | diary-view.deleted.toast<br>컴포넌트 toast | info | - | 1 | 1 | - | ko 48, en 78, ja 34 |
| ui.error.client | 컴포넌트 error-state<br>컴포넌트 toast | info | - | 1 | 6 | - | ko 48, en 78, ja 34 |
| ui.error.code | 컴포넌트 error-state<br>컴포넌트 toast | info | - | 1 | 44 | - | ko 48, en 78, ja 34 |
| ui.event-edit.delete | event-edit.delete.cta<br>컴포넌트 primary-button | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| ui.event-edit.form | 컴포넌트 segmented<br>컴포넌트 text-field | guide | - | 1 | 4 | - | ko -, en -, ja -<br>`eventEditAllDay` ko 13, en 22, ja 10<br>`eventEditTimed` ko 13, en 22, ja 10 |
| ui.event-edit.offline | event-edit.offline.notice<br>컴포넌트 notice-banner | info | - | 1 | 1 | - | ko 52, en 90, ja 38 |
| ui.event-edit.save | event-edit.save.cta<br>컴포넌트 primary-button | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| ui.event-edit.save-failed | event-edit.save.failed<br>컴포넌트 toast | info | - | 1 | 1 | - | ko 48, en 78, ja 34 |
| ui.event-row.label | 컴포넌트 event-row | info | - | 1 | 3 | `count`: number<br>`status`: text<br>`time`: text<br>`title`: text | ko -, en -, ja -<br>`eventRowLabel` ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.evidence.title | evidence-sheet.sheet.title<br>컴포넌트 sheet | info | - | 1 | 1 | - | ko 18, en 33, ja 15 |
| ui.guide.a11y | 컴포넌트 guide-question-card | info | - | 1 | 2 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.guide.card | 컴포넌트 guide-question-card | info | - | 1 | 1 | - | ko 27, en 50, ja 22 |
| ui.login.error | login.error.body<br>컴포넌트 toast<br>컴포넌트 error-state | info | - | 1 | 4 | - | ko 48, en 78, ja 34 |
| ui.login.provider | 컴포넌트 social-login-button | guide | - | 1 | 2 | - | ko 21, en 38, ja 17 |
| ui.nav.a11y | 컴포넌트 app-bar<br>컴포넌트 sheet | guide | - | 1 | 2 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.nav.tab | 컴포넌트 tab-bar | info | - | 1 | 4 | - | ko 9, en 15, ja 7 |
| ui.picker.item | 컴포넌트 date-picker<br>컴포넌트 time-picker | info | - | 1 | 8 | `year`: number<br>`month`: number<br>`day`: number<br>`hour`: number<br>`minute`: text | ko 7, en 12, ja 5 |
| ui.picker.label | 컴포넌트 date-picker<br>컴포넌트 time-picker | info | - | 1 | 6 | - | ko 상한 없음, en 상한 없음, ja 상한 없음 |
| ui.tag-chip.label | 컴포넌트 tag-chip | info | - | 1 | 4 | `tag`: text | ko -, en -, ja -<br>`tagChipPolarityGood` ko 상한 없음, en 상한 없음, ja 상한 없음<br>`tagChipPolarityBad` ko 상한 없음, en 상한 없음, ja 상한 없음<br>`tagChipPolarityNeutral` ko 상한 없음, en 상한 없음, ja 상한 없음 |
| welcome.concept.body | welcome.concept.body | info | - | 1 | 1 | - | ko -, en -, ja - |
| welcome.concept.head | welcome.concept.head | info | - | 1 | 1 | - | ko -, en -, ja - |
| welcome.cta.signin | welcome.cta.signin | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |
| welcome.cta.start | welcome.cta.start | guide | - | 1 | 1 | - | ko 23, en 42, ja 19 |

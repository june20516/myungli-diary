# 구현 대응·IA v3·글자 수 상한 설계 (컴포넌트 계약 2.3.0)

* 작업 단위: design
* 마일스톤: V2 후속 (선행 컴포넌트 2.2.0, 후행 app 계획 3 이후 UI 구현, writing 원고 길이 검사)
* 입력: Issue #118(app 기반 구현의 명세 차이), #142(app 계획 2의 명세 차이), #154(근거 시트 빈 구역, 행운 시간 형식), #159(IA v3 `depth-link` 화면 이동), #131(ui 이름 자리와 새 content 슬롯의 글자 수 상한)
* 기준 문서: [V2 spec](2026-10-11-components-design.md), [근거 잠금·글자 수 spec](2026-10-11-depth-lock-lengths-design.md), [문장 조각·잠금 슬롯 spec](2026-10-13-term-segments-lock-slots-design.md), `docs/decisions.md` D58·D60·D71, IA v3(PR #157 `root/ia-v3`)
* 계약: 컴포넌트 명세 2.2.0 → **2.3.0**(추가와 값 변경만). 토큰 1.1.0은 그대로입니다.

## 1. 목적과 완료 기준

app은 2.2.0을 구현하면서, 명세와 다르게 만든 곳과 명세에 없어 스스로 정한 곳을 두 Issue로 알렸습니다. writing은 상한이 `null`인 슬롯 때문에 검사기가 길이를 보지 못합니다. 이 작업은 그 판단을 명세에 확정해서 명세와 구현이 어긋난 채 남지 않게 합니다.

끝나는 조건:

1. 컴포넌트 명세 2.3.0 (§2~§4)
2. `tools/lengths.py`의 칸 확장과 `lengths.md` 갱신 (§5)
3. 검사기 `tools/components.py`와 pytest 통과
4. 결정 V29~V33, `CLAUDE.md` 갱신
5. Issue: #118·#142·#154·#131 답 코멘트(PR `Closes`), #159는 IA v3 병합과 순서를 맞춤, app 앞 2.3.0 대응 요청, writing 앞 확인 창 슬롯 요청 (§7)

## 2. 구현 대응: 명세를 바꾸는 것

### 2.1. 고정 높이는 최소 높이 (#142-1, 결정 V30)

README 공통 규칙에 한 줄을 더합니다. **"명세의 고정 높이(`height`)는 기본 글자 크기에서의 높이다. 기기 글자가 커지면 글자가 잘리지 않게 늘어나는 최소 높이로 구현한다."** 대상은 `primary-button`(52·44), `text-field`(52), `segmented`(40), `social-login-button`(52), `lucky-card` 칩(34), `day-character` 배지(26) 등 글자를 담은 칸 전부입니다.

* 필드 이름(`height` → `minHeight`)은 바꾸지 않습니다. 바꾸면 주 버전이 되기 때문입니다. 규칙 한 줄이 같은 뜻을 전합니다.
* 예외: 칸이 고정된 표와 달력(`a11y.textScaleMax` 1.3)은 지금처럼 글자 크기에 상한을 두고 칸은 고정입니다.

### 2.2. 글자 링크의 화살표는 컴포넌트가 그린다 (#142-9, 결정 V29)

`depth-link`의 `chevron`, `sentence-block` `locked`의 `open.chevron`, 근거 잠금의 `lockPanel.pass`가 대상입니다.

* 화살표는 원고에 넣지 않습니다. 슬롯 문구는 링크 이름만이고, 컴포넌트가 그 뒤에 화살표를 붙입니다.
* 모양은 글리프 `›`에서 **아이콘 `caret-right`**로 바꿉니다(`weight: regular`, 크기는 링크 글자 크기, 색은 링크 색, 간격 2px). `›` 글리프는 ko 글꼴(Pretendard)과 ja 글꼴에서 모양과 굵기가 달라 두 언어가 다르게 보입니다. `settings-row`의 화살표도 이미 `caret-right`입니다.
* 화살표는 스크린리더가 읽지 않습니다(장식).
* 링크가 여러 줄로 감기면 화살표는 마지막 줄 끝에 붙고, 마지막 낱말과 떨어지지 않습니다(`link.inline-nowrap`과 같은 원리).
* 명세 표기: `chevron: { "icon": "caret-right", "weight": "regular", "size": "link-text-size", "color": "link-color", "gap": 2px, "a11y": "decorative" }`. 값이 바뀌는 것이라 수 버전 변경이지만, 이번 2.3.0에 함께 묶습니다.

### 2.3. `dialog` 변형 `notice` (#142-5)

확인 버튼 하나만 있는 안내형 확인 창입니다. `login.discard.notice`(미리보기 입력을 쓰지 않는다는 안내)처럼 사용자가 고를 것이 없고 읽었다는 확인만 받는 곳에 씁니다.

* `parts.cancel.visible: false`. 확인 버튼은 `confirm`과 같은 모양이고 오른쪽 끝에 놓입니다.
* 바깥을 누르거나 뒤로 가기를 하면 확인과 같습니다.
* 초점은 확인 버튼에 둡니다.
* 두 버튼 형식에서 "닫기"가 취소처럼 읽히던 문제가 없어집니다.

### 2.4. `segmented` 상태 `none` (#142-4)

아직 아무것도 고르지 않은 상태입니다(성별을 고르기 전). 표시 막대가 없고 모든 글자는 `text.secondary`입니다. 처음 고를 때 표시 막대는 미끄러지지 않고 그 자리에 스며 나타납니다(`appear.seep`). 이 상태에서는 `input-step` 아래 버튼이 `disabled`입니다.

### 2.5. `input-step` 아래 버튼 (#142-6)

항목을 고르면 바로 다음으로 넘어가는 단계(지금은 `birthplace`의 도시 결과 줄)에는 **아래 버튼을 두지 않습니다.** 비활성 버튼이 늘 떠 있으면 "무언가 더 해야 한다"로 읽히기 때문입니다. 명세 표기는 `bottomAction.omitWhen: "고르면 바로 넘어가는 단계"`와 규칙 한 줄입니다.

### 2.6. `social-login-button` (#142-7)

* 상태 `disabled`를 더합니다(다른 버튼이 처리 중일 때). 제공자 색을 바꿀 수 없으므로 버튼 전체 `opacity: 0.4`입니다.
* Apple 버튼 글자는 HIG대로 시스템 글꼴을 쓰고, 크기와 굵기는 `type.label.lg`입니다(`label.apple`).

### 2.7. `app-bar` 뒤로 버튼 (#142-8)

갈래의 첫 화면이라 돌아갈 곳이 없는 화면(consent, notify-ask)은 `inner`여도 뒤로 버튼을 숨깁니다. 제목의 시작 위치는 바뀌지 않습니다(뒤로 자리를 비워 두지 않음). 규칙 한 줄을 더합니다.

### 2.8. `date-picker` 윤달 (#142-2, 결정 V31)

* **목표 모양은 유지합니다.** 음력이고 그해에 윤달이 있을 때만 월 휠에 `윤N월`을 끼우고, 음력이면 양력으로 바꾼 날짜를 확인 줄(`solarConfirm`)에 보입니다. 휠 방식이어야 없는 윤달을 고를 수 없고, 확인 줄이 있어야 사용자가 음력 입력이 맞는지 확인할 수 있습니다.
* **대체 모양(조회가 없을 때):** 음력→양력 변환·윤달 조회(server #141)가 계약에 없으면, 월 휠에 윤달을 끼우지 않고 음력일 때 휠 아래에 `check-row` `inline` "윤달" 하나를 둡니다. `solarConfirm`은 그리지 않고 그 자리도 비워 두지 않습니다. 없는 윤달을 고르면 저장할 때 server 오류(`errorBirthInvalid`)로 `input-step` 오류 줄에 보입니다.
* 조회가 계약에 들어오면 app은 목표 모양으로 바꿉니다. 명세 표기는 `variants.birth.parts.leapMonthFallback`(`check-row` inline, `when: "윤달 조회 없음"`)입니다.

### 2.9. `city-search` 지역 줄 (#142-3)

`region`은 "행정 구역, 나라" 이름입니다. **나라 코드(`KR`)를 그대로 보이지 않습니다.** 지역 이름이 계약에 없으면 `region` 줄을 그리지 않고, 결과 줄 최소 높이 56px는 그대로입니다.

### 2.10. 근거 시트의 빈 구역 (#154-1)

`unlocked`에서 본문이 없는 구역(판정 근거·원전·내 사주에서는)은 **제목까지 그리지 않고 자리도 남기지 않습니다.** 반면 `locked`의 `lock.veil`은 본문을 내려받지 않은 상태이므로 지금처럼 세 구역(또는 두 구역)을 그립니다. 규칙 한 줄을 더합니다.

### 2.11. `lucky-card` 시간 값 형식 (#154-2)

`time` 변형의 값은 프로필 시간대의 24시간 `HH:mm–HH:mm`이고, 시작과 끝은 en dash(U+2013)로 잇습니다. 구간이 둘 이상이면 ` · `(가운뎃점, 앞뒤 공백)로 잇습니다. 예: `09:30–11:30 · 13:30–15:30`. 숫자는 `tnum`입니다. 세 언어 모두 같은 형식입니다.

### 2.12. `tab-bar` 아이콘 (#118-2)

`parts.icons`를 더합니다: today `sun`, calendar `calendar-blank`, diary `notebook`, me `user`. app이 고른 값이 V15(Phosphor light, 선택 regular)와 맞고 탭의 뜻과도 맞아 그대로 받습니다.

### 2.13. 요소 값 (#118-1·3·5)

* `icon.set.flutter`: `phosphor_flutter` → `phosphor_glyphs`(2.1.2+1, MIT). 아이콘 세트와 버전(Phosphor 2.1.2)은 같습니다. `phosphor_flutter` 2.1.0은 Flutter 3.47에서 컴파일되지 않습니다.
* `mark.caution.size`: `cap-height-of-text` → **글자 크기 × 0.707**(Pretendard OS/2 `sCapHeight` 1448 / 2048. Regular·SemiBold 같음). app의 0.7 근사는 이 값과 같은 결과입니다.
* `lock.veil`에 매개변수 `lines`(기본 2, `sentence-block` `locked`는 1)를 명시합니다. app의 `LockVeil.line`은 새 변형이 아니라 `lines: 1`입니다.

## 3. 구현 대응: 명세를 바꾸지 않는 것

다음 항목은 명세와 같거나, 추상 역할을 플랫폼에 대응한 결과입니다. 각 `.md`의 "구현 힌트"에 Flutter 대응을 적고 JSON은 그대로 둡니다.

| 항목 | 명세 역할 | Flutter 대응 (app 구현) |
| --- | --- | --- |
| `skeleton` (#118-4) | `progressbar` | `loadingSpinner` 의미 표시 |
| `empty-state` (#118-4) | `group` | `container` |
| `toast`·`notice-banner`·`error-state` (#118-4) | role + liveRegion | 노드 둘로 나눔(한 노드에 두면 모바일 알림이 사라짐) |
| `segmented` (#142-4) | `radio-group` / `radio` | 그룹 `radioGroup`, 항목 `checked` + `inMutuallyExclusiveGroup` |
| `city-search` (#142-3) | `combobox` | 적용하지 않음(flutter#159741). 결과 수 알림은 그대로 |
| `depth-link` `inline-end` (#118-5) | 한 덩어리 | 문장 끝 `WidgetSpan` 하나 |
| `ad-banner` loading·noFill (#118-6) | 자리를 잡지 않음 | 높이 0 |

## 4. `depth-link` 변형 `navigate` (#159, 결정 V32)

IA v3(D71)에서 `birthplace`에 계산 기준 화면(`calc-basis`)으로 가는 링크가 생깁니다. 모양은 같은 "링크 이름 + 화살표"이지만, 시트를 열지 않고 페이지로 이동합니다.

* `variants`에 `{ "id": "navigate", "when": "다른 페이지로 이동(출생지 → 계산 기준)", "parts": { "label": { "align": "start" }, "container": { "marginTop": "{space.12}" } }, "target": "page" }`를 더합니다. 배치는 `block`과 같습니다.
* 누르면 플랫폼 기본 페이지 전환으로 이동합니다. `sheet.enter`·`sheet.stack`을 쓰지 않습니다. 눌림은 `press.ink`(링크 글자 둘레)입니다.
* a11y: role `link`. 라벨은 링크 이름 그대로이고, 화살표는 읽지 않습니다.
* 자리: `birthplace`에서 `birthplace.standard.note`(`input-step` `help`와 같은 글자 스타일) 바로 아래, 검색칸 위. 슬롯 `birthplace.standard.link`.
* `depth-link.summary`를 "한 단계 깊이로 가는 링크 ('근거 보기 ›'), 또는 다른 페이지로 가는 같은 모양의 링크"로 넓힙니다. `sentence.md`의 쓰는 화면에 `birthplace`를 더합니다.
* IA v3 PR #157은 단독 병합 금지이고, app 최종 PR과 함께 병합됩니다. 이 명세는 IA v3의 `birthplace.components`(`depth-link`)를 전제로 합니다. 검사기(`components.py`)는 IA id만 보고 화면 목록은 보지 않으므로 main IA로도 통과합니다.

## 5. 글자 수 상한 (#131, 결정 V33)

### 5.1. 원칙

V27의 계산 방식을 그대로 넓힙니다. 기준 폭 360px, 본문 폭 320px, 실제 글꼴 폭으로 계산하고, 이름 자리는 띄어쓰기 없는 한글로 칸을 채운 가장 넓은 경우, 문장 자리는 원고로 잰 경험값입니다.

* **여러 자리에 쓰는 슬롯은 가장 좁은 자리의 값**을 받습니다. 예를 들어 `ui.action.button`은 `primary-button`과 `dialog` 버튼에 쓰이므로 dialog 버튼 폭으로 계산합니다.
* writing 초안이 없는 자리는 계산값이 곧 확정값입니다(`draft: None`).
* 칸 폭은 컴포넌트 명세의 안쪽 여백·아이콘·간격을 뺀 값입니다. 아래 표의 칸 폭은 계산식이고, 결과 숫자는 `tools/lengths.py`의 출력이 정합니다.

### 5.2. 새 칸

| 칸 | 칸 폭 계산 | 글자 스타일 | 줄 | 종류 | 슬롯 |
| --- | --- | --- | --- | --- | --- |
| 주 버튼 `primary-button` | 320 − 20×2 = 280 | label.lg | 1 | 이름 | welcome.cta.start·signin, preview.cta.save·restart, consent.cta.agree, notify-ask.cta.allow·skip, force-update.cta.store, account-delete.cta.delete, today.guide.cta, evidence-sheet.lock.cta, ad-free.restore.cta, diary-list.pick-date.cta, day-sheet.event.add, day-sheet.diary.write-cta, share-preview.cta.share |
| 확인 창 버튼 `dialog` | (360 − 28×2 − 24×2 − 8) / 2 = 124 | label.lg | 1 | 이름 | ui.action.button, 확인 창 슬롯의 버튼 키(§5.4) |
| 소셜 로그인 글자 | 320 − 16×2 − 로고 20 − 간격 8 = 260 | label.lg | 1 | 이름 | ui.login.provider |
| toast | 320 − 16×2 = 288 | body.ui | 2 | 문장 | ui.error.client, ui.error.code, ui.login.error, ui.app.trace, evidence-sheet.unlock.failed, diary-edit.saved.tags |
| 탭 라벨 | 360 / 4 = 90 | caption.sm | 1 | 이름 | ui.nav.tab |
| segmented 두 칸 | (320 − 2 − 3×2) / 2 = 156 | label.lg | 1 | 이름 | ui.birth.option(양력·음력, 남성·여성, 그리고 check-row inline의 모름·윤달) |
| segmented 세 칸 | 104 (기존) | label.lg | 1 | 이름 | share-preview.ratio.label |
| 동의 항목 `check-row` card | 320 − 16×2 − 상자 24 − 간격 12 − 보기 40 = 212 | body.ui | 2 | 이름 | consent.required.label |
| 입력칸 안내 `text-field` | 320 − 16×2 − 지우기 20 − 간격 8 = 260 | 17px 400 | 1 | 이름 | onboard-call.input.hint, event-edit.title.hint, event-edit.memo.hint |
| 검색칸 안내 `city-search` | 260 − 돋보기 20 − 간격 8 = 232 | 17px 400 | 1 | 이름 | birthplace.search.hint |
| 일기 입력칸 안내 `diary-editor` | 320 − 16×2 = 288 | sentence.body | 2 | 문장 | diary-edit.body.placeholder |
| 안내 띠 `notice-banner` | 320 − 12×2 − 아이콘 16 − 간격 8 = 272 | caption.lg | 2 | 문장 | ui.app.notice, saju-chart.time-unknown.notice, diary-edit.offline.notice |
| 휠 칸 | 320 / 3 ≈ 106 | subtitle | 1 | 이름 | ui.picker.item |
| 구역 제목 | 320 | label.md | 1 | 이름 | evidence-sheet.section.basis·source·personal |
| 링크 이름 | 320 − 화살표 14 − 간격 2 = 304 | label.lg | 1 | 이름 | birthplace.standard.link, day-sheet.diary.open |
| 잠긴 줄 열기 | 320 / 2 − 화살표 14 − 간격 2 = 144 | label.lg | 1 | 이름 | saju-chart.yongsin.open (흐린 줄과 같은 줄 오른쪽 끝) |
| 앱 이름 `app-bar` | 360 − 16×2 − 뒤로 44 − 동작 44×2 = 196 | subtitle | 1 | 이름 | ui.app.name |
| 시진 확인 줄 | 320 | caption.lg | 1 | 이름 | onboard-time.hour.confirm |
| 날의 성격 이유 | 320, 끝 링크 자리("근거 보기" 5자 + 화살표) 뺌 | caption.lg | 2 | 문장 | character.reason |
| 큰 문장 첫 줄 | 320 (today 총운과 같은 칸) | sentence.card | 2 | 문장 | chart.ilgan_head |

* ja는 기존 규칙(글자 단위 + 금칙 여유 한 글자, UI 글꼴은 전각 1em)을, en은 기존 추정식을 씁니다.
* 문장 자리(toast·안내 띠·일기 안내·이유 줄)의 ko는 V27과 같이 원고 문장을 그 칸의 글꼴로 채워 잽니다(UI 글꼴 칸은 Pretendard 폭).
* `my-saju`의 일간 소개 첫 문장(`my-saju.ilgan.head`, 호칭 자리)은 today 총운 첫 문장과 같은 `sentence-block` `card`입니다. 이어지는 문장은 `body`입니다. `sentence.md`의 배치 설명에 적습니다.
* `lock.pass`(`evidence-sheet.lock.pass`, 안내 + 링크 두 키)는 가운데 정렬 caption 한 줄 + 링크로, `lock.reward`·`lock.head`·`lock.unavailable`과 함께 이번 범위 밖입니다(§5.5).

### 5.3. 상한을 두지 않는 슬롯

레이아웃이 길이를 막지 않으므로 design은 상한을 정하지 않습니다. 슬롯 명세에는 `null` 대신 이 사실을 적도록 writing에 알립니다. 편집상의 길이 규칙이 필요하면 writing이 정합니다.

| 종류 | 슬롯 |
| --- | --- |
| 스크린리더 전용(화면에 보이지 않음) | ui.nav.a11y, ui.a11y.label, ui.picker.label, evidence-sheet.a11y.locked·checking·unlocked, today.reaction.label |
| 스크롤 본문 | chart.ilgan_body, chart.yongsin_summary, term.meaning(풀이 시트·태그 모아보기 본문), ui.app.bootstrap(error-state 문장) |
| app 밖 화면 | system.apple_return(server 웹 페이지) |

### 5.4. 확인 창 슬롯 (writing 요청)

`diary-view.delete.confirm`, `event-edit.delete.confirm`, `account-delete.delete.confirm`, `settings.logout.confirm`, `preview.share.login-notice`, `profile-edit.recalc.confirm`은 한 슬롯에 제목·본문·버튼 키가 함께 있습니다. 슬롯 하나의 `max_length`로는 셋을 다 담을 수 없으므로 상한을 역할별로 드립니다.

| 역할 | 칸 | 상한 |
| --- | --- | --- |
| 제목 | 360 − 28×2 − 24×2 = 256, subtitle, 2줄, 이름 | 도구 출력 |
| 본문 | body.ui, 창이 늘어남 | 없음 |
| 버튼 | 확인 창 버튼 124 | 도구 출력 |

슬롯을 역할별로 나눌지, 키별 상한을 둘지는 writing이 정합니다(`kind:request`, §7).

### 5.5. 이번 범위 밖

#131이 묻지 않은 문장형 ui 슬롯(질문 제목 `*.question.head`, 설명 `*.why.body`, 잠금 안내 `evidence-sheet.lock.*` 등)은 이번에 계산하지 않습니다. 필요하면 writing이 다시 요청합니다. `calendar.solar_term`의 en 줄임 표기(`S.Cold`, `Sp.Eq`)는 계산값 6자 안이라 날짜 칸에 들어갑니다. 글리프 폭이 가장 넓은 표기를 도구로 재서 답에 함께 적습니다.

### 5.6. 도구 변경

* `Target`에 `reserve_px`(같은 줄에 붙는 고정 폭, 예: 이유 줄 끝 링크)를 더합니다. 이유 줄의 링크 폭은 label.lg "근거 보기" 폭 + 화살표 14 + 간격 2 + 앞 공백입니다.
* 글자 크기만 있고 자간이 없는 자리(`text-field` 17px)는 `tracking 0`입니다.
* `TARGETS`에 §5.2의 칸을 더하고, `NO_LIMIT`(§5.3)와 확인 창 역할(§5.4)을 표로 출력합니다. `lengths.md`의 표는 도구 출력 그대로이고, 테스트(`test_lengths.py`)가 둘이 같은지 봅니다.
* 기존 칸의 값은 바뀌지 않아야 합니다(테스트가 기존 표 행을 그대로 비교).

## 6. 명세 변경 요약

| 파일 | 변경 |
| --- | --- |
| `README.md` | 계약 2.3.0, 공통 규칙(최소 높이), 버전 표 |
| `sentence.json`·`.md` | `depth-link` `navigate` 변형·summary, 화살표 아이콘(depth-link `chevron`, sentence-block `open.chevron`, `lockPanel.pass.chevron`), 빈 구역 규칙, 쓰는 화면 `birthplace`, my-saju 첫 문장 `card` |
| `feedback.json`·`.md` | `dialog` `notice` 변형, 구현 힌트(skeleton·empty-state·liveRegion) |
| `input.json`·`.md` | `segmented` `none`, `input-step` `bottomAction.omitWhen`·규칙, `date-picker` `leapMonthFallback`·규칙, `city-search` region 규칙, 구현 힌트 |
| `action.json`·`.md` | `social-login-button` `disabled`·`label.apple` |
| `frame.json`·`.md` | `tab-bar` `icons`, `app-bar` 뒤로 숨김 규칙 |
| `today.json`·`.md` | `lucky-card` `time` 값 형식 |
| `elements.json`·`.md` | `icon.set.flutter`, `mark.caution.size`, `lock.veil.lines` |
| 나머지 `*.json` | `version` 2.3.0 |
| `tools/components.py` | `CONTRACT_VERSION` 2.3.0 |
| `tools/lengths.py`, `lengths.md` | §5 |
| `decisions.md` | V29 화살표, V30 최소 높이, V31 윤달, V32 navigate, V33 글자 수 확장 |
| `CLAUDE.md` | 현재 상태·다음 할 일 |

이름이 바뀌거나 빠지는 것이 없으므로 부 버전입니다. 새 필드 이름(`icons`, `omitWhen`, `leapMonthFallback`, `none`, `notice`, `navigate`, `label.apple`, `lines`)이 검사기의 허용 필드 밖이면 검사기 쪽 목록에도 더합니다.

## 7. Issue

* #118·#142·#154 답 코멘트: 항목별 판단(§2·§3)과 명세 위치. PR 본문 `Closes`로 닫습니다.
* #131 답 코멘트: 슬롯별 상한 표(`lengths.md` 링크), 상한 없음 목록, 확인 창 역할별 값. PR 본문 `Closes`로 닫습니다.
* #159: PR 본문 `Closes #159`. IA v3 PR #157과 app 최종 PR이 병합되기 전에 이 PR이 먼저 병합되어도 명세는 IA id만 쓰므로 깨지지 않습니다. 병합 순서는 지휘가 정하도록 PR 본문에 적습니다.
* app 앞 request(`kind:request`): 컴포넌트 계약 2.3.0. 바뀐 값(화살표 아이콘, 시간 형식 등)과 새 변형·상태를 알립니다. app이 이미 그렇게 구현한 것과 바꿔야 할 것(region 줄, input-step 아래 버튼, dialog `notice`, segmented `none`)을 나눠 적습니다. 받는 쪽에 일을 시키는 공지이므로 notice가 아니라 request입니다(workflow §5.2).
* writing 앞 request(`kind:request`): 확인 창 슬롯을 역할별로 나눌지(§5.4), 상한 없음 슬롯을 어떻게 표기할지(§5.3).
* 계약 목록(`docs/contracts/README.md`) 버전 갱신은 지휘가 합니다.

## 8. 검사

* `python3 docs/identity/design/tools/components.py`(저장소 루트)
* `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`(글꼴이 있어 `lengths.md` 표 비교가 실제로 돎)
* `uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts`의 출력이 `lengths.md`와 같음
* 새 토큰 참조는 기존 토큰(`motion`·`color`·`type`)만 씁니다.

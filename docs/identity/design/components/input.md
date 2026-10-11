# input: 입력 (`input.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.3, 결정 V13·V14
* 시안: `design-v2-birth-date`(휠 + 윤달), `design-v2-birth-time`(휠 + 모름), `design-v2-select`(스밈 이동 15%), `design-v2-focus`(포커스 테두리), `design-v2-rest`(달력 날짜 고르기)

## input-step

* 쓰는 화면: onboard-call, onboard-birth, onboard-time, onboard-gender, birthplace, notify-ask
* 위에서부터: 진행 막대(온보딩만, 3px) → 질문(`type.title`) → 입력 → 도움말(`type.caption.lg`) → 오류 줄 → 아래 고정 주 버튼(키보드 위에 붙음).
* 오류 줄(`out-of-range` 등)은 빨간색 없이 `mark.caution` + 본문색입니다. 오류가 있으면 아래 버튼은 disabled.

## text-field

* 쓰는 화면: onboard-call, event-edit
* `bg.sheet`, 1px `line`, `radius.md`, 높이 52px, 글자 17px(ui 글꼴 400).
* 포커스는 `focus.ring`(1px `line` → 2px `action.primary`). 바탕은 바뀌지 않습니다. 다크 모드에서도 같은 규칙입니다.
* Material 힌트: `InputDecoration`의 `filled: true`, `fillColor: bg.sheet`, `OutlineInputBorder` 두 벌(평소·포커스).

## date-picker

* 쓰는 화면: onboard-birth(`birth`), event-edit(`birth`와 같은 휠), diary-list(`calendar`)
* `birth`: 년·월·일 휠 + 위에 양력·음력 segmented. 휠 선택 띠는 `status.bg`.
  * 음력이고 그해에 윤달이 있을 때만 월 휠에서 해당 달 바로 다음에 "윤N월"이 끼어듭니다.
  * 음력이면 아래에 양력 확인 줄이 `appear.seep`으로 나타납니다.
  * 지원 범위(1900-01-31~2099-12-31) 밖은 input-step 오류 줄.
* `calendar`: 시트 안 달력. calendar-month와 같은 표시(일기 쓴 날 옅은 도장, 오늘 윤곽, 선택 굵은 숫자 + 밑줄)이고 길흉 칸 채우기만 뺍니다. 미래 날짜는 흐리게 막습니다. 아래 버튼 글자에 고른 날짜가 들어갑니다(문구는 writing).
* 휠 눈금이 넘어갈 때마다 햅틱 selection.

## time-picker

* 쓰는 화면: onboard-time(`birth`), notify-ask·event-edit·settings(`notify`)
* `birth`: 오전·오후·시·분 휠 + "모름" 체크. 모름을 켜면 휠이 흐려지고(투명도 0.35, 흐림 1.5px) 안내가 `appear.seep`으로 나옵니다.
  * 출생 기록의 벽시계 시각을 그대로 받습니다.
  * 시진 확인 줄은 엔진이 계산한 시진을 받을 수 있을 때만 보입니다(Issue #35). 받을 수 없으면 줄을 뺍니다.
* `notify`: 모름이 없고 분은 5분 단위.

## segmented

* 쓰는 화면: onboard-gender, event-edit, saju-chart(원국·오행 / 만세력·대운), settings, share-preview(비율, Issue #35)
* `bg.sheet` + 1px `line` 알약 트랙, 선택 표시는 `action.primary` 알약 + 흰 글자.
* 선택이 바뀌면 `select.seep-slide`: 새 표시가 이전 자리 쪽에서 거리의 15%만 미끄러지며 선명해지고, 이전 표시는 제자리에서 번지며 사라집니다. 햅틱 selection.
* 항목 2~4개, 같은 너비, 글자 한 줄.

## city-search

* 쓰는 화면: birthplace
* 검색칸(text-field + 돋보기) + 결과 묶음 카드(settings-row와 같은 모양: 도시 `type.body.ui` + 나라·지역 `type.caption.md`). 입력과 일치하는 부분은 600.
* 불러오는 중 skeleton 줄 3개, 결과 없음 empty-state.

## check-row

* 쓰는 화면: consent
* 줄마다 떨어진 카드(`bg.sheet`, `radius.md`). 24px 체크 상자(`radius.sm`): 켜면 `action.primary`로 채워지고 흰 체크가 그어집니다(200ms). 오른쪽 "보기" 링크는 따로 초점을 받고, 눌러도 체크는 바뀌지 않습니다.

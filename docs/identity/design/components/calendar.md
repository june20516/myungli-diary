# calendar: 달력 (`calendar.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.7, 결정 V19, V1 결정 V10(길흉 칸 채우기)
* 시안: `design-v2-calendar`(고른 판), `design-v2-calendar-alternatives`(버린 비교안), `design-v2-rest`(일정 줄)

## calendar-month

* 쓰는 화면: calendar (date-picker `calendar` 변형도 같은 표시)
* 달 제목 `type.subtitle` + 이전·다음(44px). 좌우로 밀어도 달이 넘어갑니다. 넘김은 격자만 `appear.seep`(가로 이동 없음).
* 요일 머리 `type.caption.md`: **일 = `calendar.weekday.sun`(화 ink), 토 = `calendar.weekday.sat`(토 ink)**, 나머지 `text.secondary`. 날짜 숫자에는 요일 색을 넣지 않습니다(주말은 요일 머리로만 표시).
* 주 시작은 일요일.

## day-cell

* 쓰는 화면: calendar
* 높이 62, `radius.sm`. 숫자는 위쪽 32px 상자 가운데, 그 아래 음력, 그 아래 일정 점.

| 표시 | 모습 |
| --- | --- |
| 길흉 | `GOOD` `calendar.good.bg`, `CAUTION` `calendar.caution.bg`, `NEUTRAL` 채우지 않음(칸 채우기, V10) |
| 일기 쓴 날 | `seal` soft 26px, 숫자 상자 가운데, 숫자는 본문색 |
| 오늘 | `seal` outline 1.6px 26px (일기 도장과 같은 크기·자리) |
| 선택 | 숫자 `action.primary` 700 + 펼침 밑줄(`mark.underline-grow`, 가운데에서 좌우로 420ms) |
| 일정 | 음력 아래 `action.primary` 점 5px |
| 음력 | `type.caption.sm` 10.5px `text.secondary`. 초하루 "M.1", 절기 날은 절기 이름 굵게, 그 밖에는 일만 |
| 다른 달 날짜 | 숫자 투명도 0.35, 길흉 채우기 없음 |

* **겹침:** 모두 같은 자리에서 겹쳐 그립니다. 아래부터 길흉 바탕 → 일기 도장 → 오늘 윤곽 → 숫자 → 선택 밑줄 → 일정 점. 빼기 처리를 하지 않습니다. 반투명 도장이 coral·neutral 바탕과 섞여 탁해 보이는 것은 의도이고, 겹침으로 읽힙니다. 숫자 대비는 겹친 색으로 검사합니다(`palette.py --check`).
* **길흉을 색 밖으로 전하기:** 채운 칸은 바탕과 대비가 낮아 색만으로는 전해지지 않습니다. 스크린리더 라벨에 길흉 낱말을 넣고(예시: "10월 11일 토요일, 음력 9.1, 좋은 날, 일기 씀, 일정 2개, 오늘"), 달력 아래 범례(색 견본 + 낱말)를 둘 수 있습니다. 낱말은 writing.
* **시스템 글자 크기:** 1.3배까지만 키우고, 그 위 설정에서는 칸 높이를 늘립니다.

## event-row

* 쓰는 화면: today(`summary`), day-sheet(`list`)
* `summary` — 지금 시각 기준으로 한 줄을 고릅니다.
  1. 진행 중인 일정이 있으면 `tag.status` "진행 중" + 시각·제목
  2. 없으면 다음 일정: "다음" + 시각·제목
  3. 모두 지났으면 개수 문장 한 줄(예시: "오늘 일정 3개 모두 지났어요")
  * 하루 종일 일정은 진행 중으로 보지만, 시각이 있는 진행 중·다음 일정이 있으면 그 일정이 앞섭니다.
  * 더 있으면 "외 N개".
* `list` — 시각 칸 58px(하루 종일도 같은 폭) + 제목(두 줄까지) + 화살표, 줄 사이 1px `line`. 일정이 없으면 빈 문장 + "일정 추가" 조용한 버튼.

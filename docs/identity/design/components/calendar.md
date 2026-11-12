# calendar: 달력 (`calendar.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.7, 결정 V19·V36~V38, V1 결정 V10(길흉 칸 채우기), app 확인 요청 #218, [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §2~§4(결정 V84~V87)
* 시안: `design-v2-calendar`(고른 판), `design-v2-calendar-alternatives`(버린 비교안), `design-v2-rest`(일정 줄), `design-ds1-screen-d`(달력 4단계, 그날 시트, 색 규칙 시트)

## calendar-month

* 쓰는 화면: calendar (date-picker `calendar` 변형도 같은 표시)
* 달 제목 `type.subtitle` + 이전·다음(44px). 좌우로 밀어도 달이 넘어갑니다. 넘김은 격자만 `appear.seep`(가로 이동 없음).
* 요일 머리 `type.caption.md`: **일 = `calendar.weekday.sun`(화 ink), 토 = `calendar.weekday.sat`(토 ink)**, 나머지 `text.secondary`. 날짜 숫자에는 요일 색을 넣지 않습니다(주말은 요일 머리로만 표시).
* 주 시작은 일요일.
* **범례(`legend`, 결정 V84):** 격자 아래 `space.16`에 늘 둡니다. 아주 잘 풀리는 날, 잘 풀리는 날, 조심할 날 셋의 견본(10px, `radius.xs`, 칸과 같은 `calendar.level.*`)과 이름(`type.caption.md` `text.secondary`, 견본과 `space.4`, 항목 사이 `space.12`)입니다. 무난한 날은 칸을 채우지 않아 견본이 바탕과 같으므로 두지 않습니다(origin D). 이름은 writing 슬롯 `calendar.legend.body`입니다. server #806 전(아주 잘 풀리는 날이 아직 오지 않는 동안)에도 아주 잘 풀리는 날 견본을 보입니다. 색 규칙 시트의 네 단계와 맞추고, 수준이 더해질 때 범례가 바뀌지 않게 하기 위해서입니다.
* **규칙 입구(`ruleEntry`, Q2 ②):** 범례 아래 `space.12`, 왼쪽 정렬. 용어 칩 모양(`term-token`과 같은 `term.bg` 바탕, `term.fg` 글자, `radius.xs`, 글자 `type.label.md`, 안쪽 좌우 `space.8` 위아래 `space.4`, 터치 44)이고 누르면 `color-rule-sheet`가 `sheet` `half`로 열립니다. ⓘ 아이콘과 꺾쇠는 두지 않습니다. 문구는 "색" 대신 그날의 길흉을 가리키는 물음입니다(writing, 가안 "길흉은 어떻게 정해지나요").

## day-cell

* 쓰는 화면: calendar
* 높이 62, `radius.sm`. 숫자는 위쪽 32px 상자 가운데, 그 아래 음력, 그 아래 일정 점.

| 표시 | 모습 |
| --- | --- |
| 길흉 | 네 단계(결정 V84): 아주 잘 풀리는 날 `calendar.level.great`, 잘 풀리는 날 `calendar.level.good`, 무난한 날 채우지 않음, 조심할 날 `calendar.level.caution`(칸 채우기, V10). 라이트는 잘 풀리는 두 단계 모두 맑은 coral(회색 섞임 없음)이고 아주 잘 풀리는 날이 더 진함(다크는 명도가 같고 채도로 나뉨, 사용자 결정 2026-11-07) |
| 일기 쓴 날 | `seal` soft 26px, 숫자 상자 가운데, 숫자는 본문색 |
| 오늘 | `seal` outline 1.6px 26px, 낙관 도장 윤곽(원이 아님, Q6 ②, V19), 일기 도장과 같은 크기·자리 |
| 선택 | 숫자 `action.primary` 700 + 펼침 밑줄(`mark.underline-grow`, 가운데에서 좌우로 420ms) |
| 선택 + 일기 쓴 날 | 숫자 `seal.on-soft` 700(옅은 도장 위에서 대비 4.5:1을 지키는 한 단계 진한 sage, 결정 V24) + 밑줄 |
| 일정 | 음력 아래 `action.primary` 점 5px |
| 음력 | `type.caption.sm` 10.5px `text.secondary`. 초하루 "M.1", 절기 날은 절기 이름 굵게, 그 밖에는 일만. 윤달 초하루는 윤달 표지를 붙인 "M.1"(`leapNewMoon`, 결정 V38) |
| 다른 달 날짜 | 숫자 투명도 0.35, 길흉 채우기 없음 |

* **겹침:** 모두 같은 자리에서 겹쳐 그립니다. 아래부터 길흉 바탕 → 일기 도장 → 오늘 윤곽 → 숫자 → 선택 밑줄 → 일정 점. 빼기 처리를 하지 않습니다. 반투명 도장이 coral·neutral 바탕과 섞여 탁해 보이는 것은 의도이고, 겹침으로 읽힙니다. 숫자 대비는 겹친 색으로 검사합니다(`palette.py --check`).
* **네 단계의 출처:** 단계는 server가 주는 길흉 수준입니다. 합한 점 3 이상이 아주 잘 풀리는 날, 2가 잘 풀리는 날, −1~+1이 무난한 날, −2 이하가 조심할 날입니다(엔진 spec §8 점수). 아주 잘 풀리는 날은 server #806에서 수준을 더한 뒤 오고, 그 전에는 3단계로 보입니다.
* **길흉을 색 밖으로 전하기:** 채운 칸은 바탕과 대비가 낮아 색만으로는 전해지지 않습니다. 스크린리더 라벨에 길흉 낱말(범례와 같은 네 단계 이름)을 넣고(예시: "10월 11일 토요일, 음력 9.1, 잘 풀리는 날, 일기 씀, 일정 2개, 오늘"), 달력 아래 범례를 늘 둡니다.
* **시스템 글자 크기(결정 V36):** 칸 안 글자는 1.3배에서 멈춥니다. 칸 높이 62는 최소 높이이고, 1.3배 글자(숫자 상자 32 + 음력 줄 + 일정 점)가 넘치면 그만큼만 늘어납니다(약 65px). 1.3배 위 설정에서는 1.3배와 같고 더 늘지 않습니다.
* **윤달(결정 V38):** 같은 해에 "6.1"이 두 번 보이면 어느 달인지 알 수 없어, 윤달 초하루는 윤달 표지를 붙여 보입니다(예시: ko "윤6.1"). 문구는 writing 슬롯 `ui.day-cell.lunar`(`dayCellLeapNewMoon`, W33, #260)이고 칸 폭 44px 한 줄입니다. 스크린리더는 윤달의 **모든 날**에 음력 조각 뒤 "윤달"(`dayCellLeapMonth`)을 붙입니다(예시: "음력 6월 5일, 윤달"). 절기 날은 보이는 칸처럼 음력 대신 절기 이름을 읽으므로 "윤달"도 읽지 않습니다.

## event-row

* 쓰는 화면: today(`summary`), day-sheet(`list`)
* `summary` — 지금 시각 기준으로 한 줄을 고릅니다.
  1. 진행 중인 일정이 있으면 `tag.status` "진행 중" + 시각·제목
  2. 없으면 다음 일정: "다음" + 시각·제목
  3. 모두 지났으면 개수 문장 한 줄(예시: "오늘 일정 3개 모두 지났어요")
  * **일정에는 길이가 없습니다**(REST 일정 계약). 그래서 시각이 있는 일정은 "진행 중"이 되지 않고, 시각이 지나면 지난 일정입니다. 순서는 ① 지금 이후 첫 시각 일정 = "다음", ② 없고 하루 종일 일정이 있으면 "진행 중", ③ 모두 지났으면 개수 문장입니다.
  * 더 있으면 "외 N개". 스크린리더는 줄 전체를 한 덩어리로 읽으므로, 라벨 틀(상태 + 시각 + 제목) 뒤에 목록 구분자(`a11yListSeparator`)로 이어 붙입니다(예시: "다음 14:00 회의, 외 2개").
  * **두 줄(`twoLines`):** 상태·시각·"외 N개"를 뺀 제목 자리가 본문 글자 4개 폭(`type.body.ui` 글자 크기 × 4)보다 좁으면 [상태·시각] / [제목·외 N개] 두 줄로 내립니다. 폭은 글자 크기로 어림하므로 글자가 좁은 en에서는 4자보다 많이 들어갑니다.
* 시각은 24시간제 `HH:mm`(앞 0 채움)입니다. 일기 줄(`diary-row` `entry`)도 같은 형식입니다(결정 V46).
* `list` — 시각 칸 58px(하루 종일도 같은 폭) + 제목(두 줄까지) + 화살표, 줄 사이 `list.divider`(V58).
  * **가독성(결정 V107, #932 관문 ②):** 시각은 본문색 700 굵게(`type.numeric.table`), 하루 종일은 시각 대신 `tag.status` 꼬리표(새 슬롯 `day-sheet.event.all-day`, 가안 "종일", 58 칸 안에 들어가는 짧은 낱말). 메모(`Schedule.memo`)가 있으면 제목 아래 `space.2`에 한 줄(`type.caption.lg` `text.secondary`, 말줄임). 줄 위아래 `space.12`, 시각과 꼬리표와 꺾쇠는 제목 첫 줄 세로 가운데에 맞춥니다.
  * 시각 글자는 줄이지 않습니다. 시스템 배율을 그대로 적용한 시각이 58 − 8px에 들어가면 58 칸에 두고(1.0은 그대로), 들어가지 않으면 [시각] / [제목·화살표] 두 줄로 내립니다(`timeColumn.overflow`).
  * **일정 추가(결정 V85):** 그날 시트 일정 섹션 머리의 + 하나(`section-header` `action`, 스크린리더 이름 `day-sheet.event.add`)입니다. 일정이 없으면 빈 문장 한 줄(`day-sheet.event.empty`)만 두고 버튼을 두지 않습니다. 머리의 +가 늘 보이므로 목록 아래 추가 버튼도 두지 않습니다(origin D, IA "일정(+로 추가)").
  * **일정만 받지 못함(`failed`):** 날의 성격은 받았는데 일정 목록만 실패하면, 빈 문장 대신 오류 종류별 기존 문구 한 줄(`type.caption.lg`, `text.secondary`) + "다시 시도" quiet를 가운데 정렬로 둡니다. 없는 일정을 없다고 말하지 않기 위해서입니다. 시트 전체 `error`(`error-state`)는 날의 성격을 받지 못했을 때만입니다. 시트의 한 구역이라 `error-state`(원 56px + 문장)는 크기가 맞지 않습니다.


## fortune-verdict

* 쓰는 화면: day-sheet
* 길흉판정 카드(결정 V86). 시트(`bg.sheet`) 안이라 카드는 `bg.base` 바탕, `radius.lg`, 안쪽 `space.16`입니다.
* **위치 막대:** 트랙 높이 4, `radius.full`, 왼쪽 조심할 날(`level.caution`)에서 오른쪽 아주 잘 풀리는 날(`level.great`)로 이어지는 그라데이션 `color.verdict.track`. 양끝은 위치 표시 반지름만큼 들입니다.
* **위치 표시:** 지름 18 원, `bg.sheet` 바탕 + 2px `action.primary` 테두리. 자리는 합한 점을 −3~+3으로 자르고 `(score + 3) / 6`입니다. 0은 가운데, 3 이상은 오른쪽 끝입니다. 움직이지 않습니다(시트가 열릴 때 처음부터 제자리, 동작 줄이기와 상관없음).
* **세 이름:** 막대 아래 `space.8`, 조심할 날(왼쪽), 무난한 날(가운데), 잘 풀리는 날(오른쪽), `type.caption.md` `text.secondary`. 낱말은 달력 범례와 같습니다. 그날 시트에 이름 슬롯이 없어 IA에 요청합니다.
* **내역:** 이름 아래 `space.12`부터 `score-row` `verdict` 줄들, 줄마다 위에 `list.divider`. 더함 먼저, 뺌 다음입니다. 내역은 server #806(엔진 점수 구성)이고, 계약에 없으면(`noBreakdown`) 막대와 이름만 그립니다. 내역은 왔지만 항목이 0개인 날(`noItems`, 합 0)도 같은 모양이고 빈 안내 문장은 두지 않습니다.
* 숫자, 한 줄 요약 문장, 이유 문장을 두지 않습니다(IA day-sheet).
* **접힘과 펼침(결정 V108, #932 ②):** 처음에는 막대와 세 이름, 맨 아래 안내 줄(`list.divider` 아래, 터치 44, `type.caption.lg` `text.secondary` 가운데, 원고 "내역 보기"(개수 없음, writing R36-4, #986 ③) + `caret-down`)만 보입니다. 카드 전체가 버튼이고(`press.ink`) 누르면 내역 줄이 `appear.seep`으로 펼쳐지며 안내 줄은 "접기" + `caret-up`이 됩니다. 펼친 내역 줄의 태그는 안쪽 요소라 누르면 뜻 시트만 열리고 카드는 접히지 않습니다(V61 눌림 규칙). 시트를 다시 열면 늘 접힘이고, 내역이 없는 날(`noBreakdown`, `noItems`)은 카드를 누를 수 없고 안내 줄도 없습니다. 안내 줄 문구는 writing 슬롯 `day-sheet.verdict.expand`, `day-sheet.verdict.collapse`. 스크린리더는 안내 줄을 펼침 상태가 있는 버튼으로 읽습니다.
* 불러오는 중: 막대 자리 글줄 하나. 처음에는 접혀 있어 내역 뼈는 두지 않습니다(V108). 세 이름은 UI 글자라 바로 그립니다.
* 스크린리더: 묶음 하나로 "길흉판정, 무난한 날"처럼 섹션 제목과 단계 이름을 읽고, 점수 숫자는 읽지 않습니다. 이어서 내역 줄을 읽습니다.

## score-row

* 쓰는 화면: day-sheet, color-rule-sheet
* 점수 항목 한 줄(결정 V86): `hanja-tag` + 뜻 + 부호와 점. 줄 최소 높이 48, 위아래 `space.12`, 세로 가운데.
* **태그:** `hanja-tag` `default`이고 톤은 부호를 따릅니다. 더함은 `verdictTone.good`(coral), 뺌은 `verdictTone.bad`(neutral). 날의 성격 태그(用 貴 忌)도 이 규칙입니다. 이 톤은 `score-row`와 `fortune-verdict` 안에서만 씁니다(Q4 ①).
* **뜻:** 태그 뒤 `space.12`, `type.caption.lg` `text.secondary`, 두 줄까지(슬롯 `day-sheet.verdict.item`).
* **부호와 점:** 오른쪽 끝. 부호(+ 또는 −) `type.label.lg` 700 본문색, 뜻과 `space.12`. 점은 지름 8 원, 점 사이와 부호 뒤 `space.4`(spec의 3은 간격 토큰이 아니라 4, V56). 더함 점 `badge.good.bg`, 뺌 점 `text.secondary`. 점 개수는 점수 절댓값이고 최대 셋, 넘으면 셋 뒤에 +를 붙입니다.
* **변형:** `verdict`(그날 시트, 태그를 누르면 `explain-sheet` 뜻), `rule`(색 규칙 시트, 뜻 없이 태그와 점만, 태그는 누를 수 없는 표시. IA color-rule-sheet에 출구가 없음). `rule` 줄은 최소 높이 없이 위아래 `space.8`입니다. 누를 수 없는 표 줄이라 터치 48이 필요 없고 일곱 줄이 시트 높이를 덜 차지합니다.
* **刑(형):** `hanja-tag` 글자 목록에 있는 한자입니다(사용자 결정 2026-11-07, D108 ② 목록 누락 보완). 다른 태그와 같이 그립니다.
* 스크린리더: "이름, 뜻, 더함 둘"처럼 부호와 개수를 낱말로 읽고 점은 읽지 않습니다. `verdict`의 태그는 따로 버튼입니다.

## 화면 배치

### calendar 화면 배치

IA v5 `calendar`. 위에서부터입니다.

1. `app-bar` 탭 루트(`calendar.bar.title`), 오른쪽 일정 추가 +(→ `event-edit`).
2. `calendar-month`: 달 머리, 요일 머리, `day-cell` 격자(네 단계 칸 채우기, 오늘은 낙관 도장 윤곽 26).
3. 범례(`calendar.legend.body`): 격자 아래 `space.16`, 견본 셋과 이름.
4. 규칙 입구(`calendar.legend.rule-link`): 범례 아래 `space.12`, 용어 칩 모양. 누르면 `color-rule-sheet`.
5. `ad-banner`, `tab-bar`.

* 불러오는 중: 칸 채우기와 도장 자리만 뼈, 숫자와 범례와 입구는 바로 그립니다.

### day-sheet 화면 배치

그날 시트(IA v5 `day-sheet`, D108, 결정 V85). 날짜 칸을 누르면 `sheet` `full`로 처음부터 크게 열립니다(펼침과 접힘 없음). 내용이 시트 높이를 넘으면 시트 안에서 세로로 스크롤하고 핸들 자리는 맨 위에 남습니다(`sheet` 규칙). 시트 안쪽 `space.24`, 핸들 자리 24. 위에서부터입니다.

1. `date-header` `day-sheet`: 날짜와 요일(`day-sheet.date.solar`), 아래 `space.2`에 음력(`day-sheet.date.lunar`). 일진은 없습니다. 음력이 없으면 줄과 여백을 그리지 않습니다. 핸들 자리 아래 `space.8`. 오른쪽 끝에 날의 성격(아래 2)을 둡니다.
2. 날의 성격(결정 V109, #932 ③): 날짜 머리 오른쪽 끝, 날짜와 음력 두 줄 묶음의 세로 가운데(음력이 없으면 날짜 줄 가운데), 날짜 글자와 사이 `space.12` 이상. 큰 글자 배율로 한 줄에 들어가지 않으면 날짜 머리 아래 `space.12` 왼쪽 줄로 내립니다. `hanja-tag` `emphasis`(`day-sheet.character.label`, 용신의 날만 진한 채움, 원 안 한자는 알약 바탕색). 누르면 `explain-sheet` 뜻. 이유 한 줄은 두지 않습니다.
3. 길흉판정: 날짜 머리(태그를 아래 줄로 내렸으면 그 줄)와 `space.32`, `section-header` `plain`(`day-sheet.verdict.title`), 아래 `space.12`에 `fortune-verdict` 카드. 맨 아래 안내 줄은 접혔을 때 `day-sheet.verdict.expand`, 펼쳤을 때 `day-sheet.verdict.collapse`(V108). 내역 줄은 `score-row` `verdict`(`day-sheet.verdict.item`)이고 태그를 누르면 `explain-sheet`.
4. 일정: `section-header` `action`(`day-sheet.event.title`, 오늘 화면 `today.event.title`과 같은 키, V97), 오른쪽 +(`day-sheet.event.add`, → `event-edit`). 아래 `event-row` `list`(줄 사이 `list.divider`, 하루 종일 일정은 시각 칸에 `day-sheet.event.all-day` 꼬리표, V107), 없으면 빈 문장(`day-sheet.event.empty`).
5. 일기: `section-header` `plain`(`day-sheet.diary.open`, 그날 쓴 일기 머리. 쓴 일기가 없어도 섹션 제목으로 보임). 아래 `diary-row` `entries`(작성 순, 누르면 `diary-view`, V42), 그 아래 `space.12`에 쓰기 버튼 `primary-button` `filled`(`day-sheet.diary.write-cta`, "<날짜> 일기 쓰기", 상한을 채운 날은 `disabled`, V43).

* 빠진 것(D108): 맨 위 날의 성격 배지와 이유 한 줄. 길흉판정에는 한 줄 요약 문장을 두지 않습니다.
* 그날 시트에서 연 풀이 시트(`explain-sheet`)에는 "근거 보기"가 없습니다(IA 깊이 `surface`, `explain`).
* 불러오는 중: 날짜와 요일은 바로, 음력 줄, 날의 성격 알약, `fortune-verdict`, 일정 줄, 일기 줄은 각자 뼈입니다(V66). 섹션 제목은 그대로.
* 오류: 날의 성격을 받지 못하면 시트 전체 `error-state`, 일정만 실패하면 `event-row` `failed`.

### color-rule-sheet 화면 배치

색 규칙 시트(IA v5 `color-rule-sheet`, 결정 V87). 달력 범례 입구에서 `sheet` `half`(내용 높이)로 엽니다. 명세 값으로 잰 내용 높이는 휴대폰 높이의 59.6%(511 / 858)라 IA대로 하프 상한 안입니다. 작은 화면, 큰 글자, 문장이 긴 언어(ja, en)에서 넘치면 시트 안에서 스크롤합니다.

1. 제목(`color-rule-sheet.sheet.title`): `type.subtitle`, 핸들 자리 아래 `space.8`.
2. 설명 문장(`color-rule-sheet.rule.body`): 제목 아래 `space.12`, `sentence-block` `body`.
3. 점수 항목 표: 문장 아래 `space.24`, `score-row` `rule` 일곱 줄(줄 사이 `list.divider`). 더함은 用 용신의 날 +●●, 貴 귀인의 날 +●●, 合 합 +●. 뺌은 忌 기신의 날 −●, 沖 일지 충과 월지 충 −●●, 沖 충 −●, 刑 형 −●. 점 개수는 엔진 spec §8 점수표입니다.

* 표 아래 합한 점과 색의 관계를 보이는 척도 그림은 두지 않습니다(관문 답 2026-11-07 Q4: 그날 시트 막대와 같은 척도를 두 번 그리지 않음). 그래서 `score-scale`은 명세를 쓰지 않았고, IA 제거 요청(`tools/components.py` `IA_REMOVAL_REQUESTED`)대로 IA에서 빠졌습니다(D113).
* 표의 태그는 누를 수 없는 표시입니다(IA에 출구가 없고 시트를 더 쌓지 않음). 불러올 내용이 없어 loading이 없습니다.

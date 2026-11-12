# today: 오늘 화면 (`today.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.6, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.11, 결정 V20·V22, V1 결정 V8(배지)
* 시안: `design-v2-today`, `design-v2-share-image`, `design-v2-rest`(질문 카드 전·후), `design-ds1-screen-a-g`(DS1 2단계 오늘, 사주 기운 시트, 잠긴 근거 시트)
* DS1 2단계: [spec](../specs/2026-11-05-ds1-screens-design.md) §1, §4, 결정 V78(오늘 배치와 날짜 머리), V79(사주 기운 시트)

## date-header

* 쓰는 화면: today, day-sheet
* 날짜와 요일(`type.subtitle` 본문색, 슬롯 `today.date.solar`) 아래 `space.2`에 음력과 일진 한 줄(`type.caption.lg` `text.secondary`, 슬롯 `today.date.lunar`, `today.date.iljin`).
* 음력과 일진은 간격 `space.8`로만 나눕니다. 쉼표나 기호로 잇지 않습니다(V47, V52와 같은 이유: 칸을 글자로 잇지 않음). 줄이 넘치면 칸 단위로 다음 줄에 놓습니다.
* 일진 글자의 간지 한자는 `font.family.hanja`로 그립니다(`fontFallback`, 한글은 UI 글꼴 그대로). 스크린리더는 한자를 읽지 않고 독음만 읽습니다(예: 경신일).
* 변형 `today`는 셋 다, `day-sheet`는 날짜와 음력(슬롯 `day-sheet.date.solar`, `day-sheet.date.lunar`)이고 일진이 없습니다.
* 음력은 server 계약 추가(#806)입니다. 계약에 없으면 음력 칸만 빼고 줄은 일진으로 남깁니다. 두 칸이 모두 없으면(그날 시트에서 음력이 없을 때) 그 줄과 위 `space.2` 여백을 그리지 않습니다.
* 불러오는 중: 날짜 줄은 기기 날짜라 바로 그리고, 음력과 일진 줄만 글줄 뼈(50%) 하나입니다.
* 누를 수 없는 표시입니다.

## day-character

* 쓰는 화면: preview (IA v5, #812로 나머지 화면에서 빠짐. 날의 성격 표시는 `hanja-tag`)
* 배지(`radius.full`, `type.label.md`, 높이 26) + 이유 한 줄(`type.caption.lg` `text.secondary`) + 끝에 depth-link `inline-end`. 이유 줄의 용어는 `sentence-block` 문장 조각 규칙을 따릅니다(`preview`에서는 일반 글자).

| 변형 | 엔진 `DayKind` | 배지 |
| --- | --- | --- |
| `good` | `YONGSIN_DAY` | `badge.good.*` 채움 |
| `gwiin` | `GWIIN_DAY` | `badge.gwiin.*` 옅은 coral |
| `gisin` | `GISIN_DAY` | `badge.gisin.*` neutral 채움 |
| `ordinary` | `ORDINARY_DAY` | 바탕 없음, 1px `badge.ordinary.border` |

배지는 글자로 날의 성격을 말합니다. 색만으로 전하지 않습니다.

* 배지는 누를 수 없는 표시입니다. 배지나 배지를 감싼 줄에 눌림 표시를 두지 않습니다(F-007, 결정 V61).

## lucky-card

* 쓰는 화면: today, my-saju
* 칩(`bg.sheet` 바탕 + 1px `line` 테두리 알약, 높이 34) = 앞 아이콘 Regular 16(색 변형은 `ohaeng.swatch` 14px 원) + 값(`type.label.md`). 변형 `color`·`direction`·`number`·`time`.
* **바탕과 테두리(Q5 ①, 결정 V75):** 반투명 `chip.bg` 대신 `bg.sheet` 바탕에 1px `line` 테두리를 칩 크기 안쪽에 그립니다. 오늘 카드, 나 탭 카드, 공유 이미지(그라데이션 위), 다크 모드 어디서나 테두리로 칩이 구분됩니다.
* 누르면 칩 테두리가 1.5px `action.primary`로 바뀌고(크기 그대로) 짧은 설명 시트(`explain-sheet`, 제목은 항목 이름, 본문은 설명 문장)가 열립니다(결정 V62). 설명을 칩 줄 아래에 끼워 넣지 않으므로 아래 내용이 밀리지 않습니다. 설명의 용어는 `sentence-block` 문장 조각 규칙을 따릅니다. 시트를 닫으면 테두리가 1px `line`으로 돌아갑니다.
* 칩 줄은 화면 폭에 따라 다음 줄로 넘어갑니다. 줄 수는 제한하지 않고, 칩 하나는 줄 사이에서 끊지 않습니다.
* **칩 줄 개수:** today 칩 줄은 행운 4종(`color`·`direction`·`number`·`time`)뿐이고 최대 5개(색, 방향, 숫자 3 + 시간 2)입니다(결정 V52, V78). 색이 둘인 날도 한 알약이라 개수는 같습니다. 순서는 색, 방향, 숫자, 낮, 밤이고, 시간 칩을 새 줄로 떼지 않고 이어 흐릅니다(관문 답 5A, 결정 V114).
* **대표 태그 칩 없음:** 옛 변형 `tag`(D76, 결정 V35)는 IA v5(D108, 결정 V78)부터 today 칩 줄에 쓰지 않아 계약 5.0.0에서 지웠습니다. 대표 태그는 사주 기운 섹션의 `hanja-tag`입니다(아래 today 화면 배치 4번). `share-image` 칩 줄도 행운 4종만입니다.
* **색이 둘인 날 `pair`(#982, D119 ②, 결정 V114):** `DailyResponse.second_color`가 있는 날은 `color` 칩 하나를 1px `line` 세로선(높이 18)으로 나눈 두 칸 알약으로 그립니다. 앞 칸은 `color`(내 균형 기준), 뒤 칸은 `second_color`(원전 기준)이고 칸마다 견본 원 + 색 이름, 좌우 `space.12`입니다. 칩에도 시트에도 기준 이름표(내 균형 기준, 원전 기준)를 두지 않습니다(관문 답 2026-11-11).
  * 칸마다 누름 자리(44 이상)이지만 어느 칸을 눌러도 같은 행운 색 시트(`colorPairSheet`)가 열리고, 열림 테두리는 알약 전체에 생깁니다.
  * `colorPairSheet`: `explain-sheet` 제목(항목 이름 "행운 색") 아래 추천 색이 둘이라는 한 줄(`today.lucky-color.pair.intro`, `type.caption.lg` `text.secondary`), 첫째 색(견본 원 + 이름 `type.label.lg`, 아래 `space.8` 풀이 `today.lucky-color.body`), `list.divider`(위아래 `space.16`), 둘째 색(같은 모양, 풀이 `today.lucky-color.second.body`). 색마다 풀이 아래에 그 색의 근거 진입점(`depth-link` `block`, 스크린리더 이름 "그 색 이름 + 근거 보기")이 있습니다(D123 ②, V118). 두 기준이 갈렸다고 쓰지 않습니다(사용자 결정, D123 ①).
  * 스크린리더: 칸마다 항목 이름 + 값 + 두 개 중 몇째.
  * 행운 숫자는 색이 둘인 날 첫째 색의 오행입니다(D119 ③).
* **`time`(#1003, D122, 결정 V115, V116):** 낮 칩 하나(`DailyResponse.focus_time`)와 밤 칩 하나(`night_focus_time`)입니다. 옛 구간 반복(`repeat`, 최대 2)과 시계 아이콘은 7.0.0에서 지웠습니다. time 칩은 today에만 씁니다.
  * 앞 아이콘은 채운 해(`sun` Fill, `color.time.day`)와 채운 달(`moon` Fill, `color.time.night`)입니다. Fill을 쓰는 경고 표시 밖의 유일한 자리입니다(요소 `icon` `timeOfDay`). 색은 모드별 아이콘 전용 토큰이고 칩 바탕 위 3:1 이상입니다(토큰 1.8.0, 관문 답 7B).
  * 값은 프로필 시간대의 24시간이고 숫자는 `tnum`입니다. 범위 표기는 writing W44를 따라 언어별입니다.
  | 언어 | 형식 | 예 |
  | --- | --- | --- |
  | ko | `HH:mm~HH:mm` | `09:30~11:30` |
  | ja | `HH:mm〜HH:mm`(U+301C) | `09:30〜11:30` |
  | en | `HH:mm to HH:mm` | `09:30 to 11:30` |
  * **밤 칩 때 낱말(D122 ⑦, V116, 관문 답 3A):** 밤 칩 값 앞(`space.4`)에 때 낱말을 값과 같은 `type.label.md`로 둡니다. 프로필 시간대 07:30 전에는 `today.lucky-time.night.dawn`(가안 "새벽", 지금 이어지는 전날 밤), 07:30부터는 `today.lucky-time.night.tonight`(가안 "오늘 밤")이고 값과 함께 바뀌어 바뀐 까닭이 읽힙니다. 낮 칩에는 낱말이 없습니다. 스크린리더 라벨은 항목 이름 + 때 낱말 + 값입니다.
  * 낮 칩과 밤 칩은 각자 시트를 엽니다(제목 `today.lucky-time.day.title`, `night.title`, 가안 "낮 집중 시간", "밤 집중 시간", 본문 `today.lucky-time.day.body`, `today.lucky-time.night.body`). 열림 테두리는 누른 칩에만 생깁니다.
* **시간 시트 24시간 띠 `timeBand`(결정 V117, 관문 답 4A):** 낮, 밤 시트 모두 본문 아래 `space.20`에 지금 보이는 두 칩이 가리키는 24시간을 그립니다.
  * 순서: 프로필 시간대 07:30 전에는 밤(전날 21:30~오늘 07:29) 다섯 칸 다음 낮(오늘 07:30~21:29) 일곱 칸, 07:30부터는 낮 일곱 칸 다음 밤(오늘 21:30~내일 07:29) 다섯 칸.
  * 머리(높이 24, 아래 `space.16`): 낮과 밤 덩어리의 시작에 칩과 같은 채운 해, 달(16) + `space.4` + 낱말(`today.lucky-time.band.day`, `night`, `type.caption.md` `text.secondary`).
  * 칸: 12칸, 칸 사이 `space.2`, 높이 30, `radius.xs`. 낮 칸은 `ohaeng.earth.bg`/`fg`, 밤 칸은 `ohaeng.water.bg`/`fg`. 칸 안에 시진 지지 이름(`type.caption.sm`, 글자는 writing). 두 칩이 고른 시진에 2px `action.primary` 고리(칸과 사이 2px `bg.sheet` 틈), 그 칸 글자 700.
  * 지금 줄: 지금 시각 비례 자리에 2px `text.primary` 세로선(칸 위아래 6 넘침), 위에 `inverse.bg`/`inverse.fg` 알약 꼬리표(`today.lucky-time.band.now`, 가안 "지금 {time}", `type.caption.sm`, 좌우 `space.4`). 띠 양 끝 가까이에서는 꼬리표만 시트 안쪽으로 밀어 넣고 선은 제자리입니다. 시트가 열린 동안 1분마다 옮깁니다.
  * 눈금(칸 아래 `space.8`, `type.caption.sm` `text.secondary`, `tnum`): 띠 시작(왼쪽 맞춤), 낮과 밤 경계(가운데), 띠 끝(오른쪽 맞춤) 시각. 전날이나 다음 날이면 날 낱말(`today.lucky-time.band.yesterday`, `tomorrow`, 가안 "어제", "내일")을 시각 앞 `space.4`에 둡니다.
  * 띠는 스크린리더에서 그림으로 숨깁니다. 같은 정보는 칩 라벨과 시트 본문이 말합니다.
  * 띠 칸은 360 기기 시트 안 폭 312에서 약 24px이라 지지 이름은 한 글자(ko 한글, ja 한자)를 기대합니다. 문구와 en 표기는 writing이 정합니다.
* **근거 보기(D123 ②, 결정 V118):** 행운 색 시트(색이 하나인 날)와 낮, 밤 시트는 맨 끝에 자기 근거 진입점(`depth-link` `block`, 용어 풀이 시트와 같은 아이콘, V63)을 두고 근거 시트를 겹쳐 엽니다. 시간 시트는 `timeBand` 아래입니다. 색이 둘인 날은 위 `colorPairSheet`처럼 색마다 둡니다. 방향과 숫자 시트에는 없습니다.

## tag-sentence-list

* 쓰는 화면: tag-sheet
* 사주 기운 시트의 "이 기운에서 나온 오늘 문장" 목록과 그 아래 출구입니다(D108).
* 머리: `type.label.md` `text.secondary`(슬롯 `tag-sheet.sentences.title`), 아래 `space.8`.
* 줄: 왼쪽 이름 칸 52(`type.caption.md` `text.secondary`, 첫 줄 기준선에 맞춤, 폭 고정이고 넘치면 칸 안에서 줄바꿈. ko "오늘의 질문"은 두 줄이고 ja, en도 같으며 문장 칸 폭은 줄이지 않음) + `space.8` + 문장(`sentence-block` `body`). 줄 위아래 `space.12`, 줄 사이 `list.divider`. 시트 안이라 문장 속 용어는 일반 글자입니다.
  * 줄은 오늘 화면의 같은 문장입니다: 보조 문장(`today.fortune.body`), 오늘의 질문(`today.guide.question`). 그 태그로 정해진 문장만 오늘 화면 순서대로 놓습니다. 대표 태그 1순위면 둘 다 있습니다.
  * 이름 칸 글자("보조 문장", "오늘의 질문")는 IA 슬롯이 없어 writing 새 슬롯을 요청합니다(#801).
  * 문장 줄은 누를 수 없습니다.
* **빈 상태(`empty`, IA tag-sheet `empty`):** 이 기운으로 정해진 오늘 문장이 없을 때(대표 태그 2순위) 줄을 그리지 않고 안내 한 줄(`tag-sheet.sentences.empty`, `type.body.ui` `text.secondary`)을 둡니다.
* **출구:** 목록 아래 `space.16`에 그 태그가 붙은 내 일기 보기 링크(`tag-sheet.diary.cta`, 매개변수 tag, 조사는 writing josa)입니다. `type.label.lg` `action.primary` + 꺾쇠(`caret-right` Regular, 옆 글자 단계, `space.2`, 장식). 누르면 `tag-diary`로 `page.push`. 편수는 보이지 않고 늘 보입니다. 그 태그의 일기가 없으면 tag-diary 빈 상태가 맡습니다(관문 답 2026-11-06). 꺾쇠는 화면 이동 표시입니다(V73).
* 스크린리더: 목록(`list`), 줄마다 "이름 칸 + 문장", 출구는 링크.

## guide-question-card

* 쓰는 화면: today
* `bg.sheet`, `radius.lg`, 안쪽 20.

| 상태 | 질문 | 동작 | 도장 |
| --- | --- | --- | --- |
| `before` | `type.sentence.card` 본문색 | 주 버튼(`todayGuideCta`) | 없음 |
| `after` | `text.secondary`로 흐림 | 가운데 조용한 버튼(`todayGuideCtaWritten`, 글자 `seal.on-soft`) | 버튼 글자 뒤 층에 `seal` soft 52px |
| `full` | `text.secondary`로 흐림 | 같은 조용한 버튼 `disabled`(`todayGuideCtaFull`, 글자 `disabled.fg`) | `after`와 같음 |

* 버튼은 `full`이 아니면 언제나 새 일기를 엽니다(D83 ③). 오늘 쓴 일기는 카드 아래 `diary-row` `entries`에서 엽니다.
* `full`은 오늘 일기가 상한을 채운 날입니다(D83 ②, 결정 V43). 도장은 그날 일기를 썼다는 표시라 남기고 버튼만 막습니다. 막힌 버튼을 눌러도 아무 일도 없고 햅틱도 없습니다. 이유는 버튼 글자가 말합니다(상한 수치 없음, writing W37).

도장 위치 규칙: 일기 종이는 오른쪽 아래, 질문 카드는 버튼 뒤, 날짜 숫자에 찍는 곳(달력·일기 목록)은 숫자 뒤(elements.md).

## share-image

* 쓰는 화면: share-preview
* 라이트 고정(결정 V5): 다크 모드에서도 라이트 토큰으로 그립니다. 바탕 `gradient.today`.
* 위에서부터 날짜 → 배지 → 문장(호칭 포함) → 행운 칩 → 아래 로고 조합(`logo/lockup.png`, 새 앱 아이콘과 워드마크, 높이 288px PNG, V99) + `image.footer`.

| 변형 | 비율 · 크기 | 이유 줄 | 문장 | 칩 |
| --- | --- | --- | --- | --- |
| `story` | 9:16, 1080×1920 | 있음 | 전체 | 4 |
| `feed` | 4:5, 1080×1350 | 없음 | 두 줄 | 3 |
| `square` | 1:1, 1080×1080 | 없음 | 첫 문장 | 3 |

* 행운 칩의 색은 첫째 색 칸 하나(D119 ④), 시간은 낮 칩 하나만 넣습니다. 칩 수는 표 그대로입니다(결정 V52, V116).
* 공유 미리보기 시트 위 segmented로 사용자가 비율을 고릅니다. 바뀔 때 미리보기가 `appear.seep`.
* 미리보기에는 `shadow.raised`(이 토큰을 쓰는 유일한 곳).
* 태그라인 자리는 writing W1.

### today 화면 배치

IA v5 `today`(D108). 위에서부터입니다. 섹션은 `section-header`(제목과 내용 사이 `space.12`, 섹션 사이 `space.32`, 시작선은 화면 좌우 `space.20`)이고, 섹션 내용은 흰 카드(`bg.sheet`, `radius.lg`, 안쪽 `space.16`)에 담습니다(결정 V78).

1. `app-bar` 탭 루트(`today.bar.title`), 오른쪽 `share-button`.
2. `date-header` `today`: 날짜와 요일(`today.date.solar`), 그 아래 음력(`today.date.lunar`)과 일진(`today.date.iljin`). 상단 바 아래 `space.8`, 날짜 머리 아래 첫 섹션까지 `space.32`(섹션 사이와 같음).
3. 총운: `section-header` `action`(`today.fortune.title`), 오른쪽 자리는 `reaction-button`(좋아요, 스크린리더 `today.reaction.label`). 카드 안은 위에서부터:
   * 총운을 결정한 태그 줄(사이 `space.8`): 날의 성격 `hanja-tag` `emphasis`(`today.character.label`, 용신의 날만 진한 채움, 누르면 `explain-sheet` 뜻), 일진 천간의 십성 묶음 `hanja-tag` `default`(`today.ten-god.label`, `term` 초록, 누르면 `explain-sheet` 뜻). 십성 묶음은 server 계약 추가(#806)이고 없으면 날의 성격 태그 하나입니다.
   * 헤드라인(`today.fortune.head`): 태그 줄 아래 `space.12`, `sentence-block` `card`(화면에서 가장 큰 문장, 호칭 자리) + 끝에 `depth-link` `inline-end`(근거 시트).
   * 선: 헤드라인 아래 `list.divider`(카드 안쪽 여백과 같은 `space.16` 들임, 위아래 `space.16`). 한 카드 안에서 헤드라인과 보조 문장을 나누는 선 하나뿐입니다. 보조 문장이 없으면(대표 태그가 없는 날, D112) 선도 그리지 않습니다.
   * 보조 문장을 정한 사주 기운 태그: 대표 태그 1순위 `hanja-tag` `default`(누르면 `tag-sheet`, 열린 동안 `selected`). 보조 문장은 대표 태그 1순위에서 나오므로 대표 태그가 없는 날에는 태그와 보조 문장을 모두 그리지 않습니다(D112 ③).
   * 보조 문장(`today.fortune.body`): 태그 아래 `space.8`, `sentence-block` `body` + 끝에 `depth-link` `inline-end`.
4. 사주 기운: `section-header` `plain`(`today.featured.title`). 카드 안에 대표 태그(`Daily.tags.featured`, 최대 둘) `hanja-tag` `default` 줄(사이 `space.8`). 누르면 `tag-sheet`, 열린 동안 `selected`. 대표 태그가 0개인 날은 섹션 제목을 그대로 두고 카드 안에 한 줄 안내(`today.featured.empty`)를 둡니다. 글자는 사주 기운 시트 빈 안내와 같은 `type.body.ui` `text.secondary`(`tag-sentence-list` `empty`와 같은 값, 새 값 없음)이고 누를 수 없습니다(D112 ②, 결정 V95).
5. 행운: `section-header` `plain`(`today.lucky.title`). 카드 안에 `lucky-card` 칩 줄(색, 방향, 숫자, 시간). 칩을 누르면 `explain-sheet`가 열리고 본문은 `today.lucky-color.body`(색이 둘인 날은 `colorPairSheet`: 맨 위 `today.lucky-color.pair.intro`, 둘째 색 `today.lucky-color.second.body`), `today.lucky-direction.body`, `today.lucky-number.body`, `today.lucky-time.day.body`·`today.lucky-time.night.body`(제목 `today.lucky-time.day.title`·`today.lucky-time.night.title`, 밤 칩 때 낱말 `today.lucky-time.night.dawn`·`today.lucky-time.night.tonight`, 아래 `timeBand` 머리 `today.lucky-time.band.day`·`today.lucky-time.band.night`, 지금 꼬리표 `today.lucky-time.band.now`, 날 낱말 `today.lucky-time.band.yesterday`·`today.lucky-time.band.tomorrow`, IA v5 보충 D123)입니다. 색과 시간 시트 끝에는 근거 진입점이 있습니다. 대표 태그는 4번 섹션에 있으므로 이 줄에 대표 태그 칩을 두지 않습니다.
6. 일정(있는 날만): `section-header` `plain`(`today.event.title`, 그날 시트 일정 제목과 같은 키). 아래 `event-row` `summary`(`today.event.summary`) 카드, 누르면 `day-sheet`. 일정이 없는 날은 제목까지 섹션째 그리지 않습니다(V97).
7. 오늘의 질문: `section-header` `plain`(`today.guide.title`). `guide-question-card`(`today.guide.question`, 버튼 `today.guide.cta`). 섹션 제목이 같은 말을 하므로 카드의 `eyebrow`는 그리지 않습니다. 오늘 쓴 일기가 있으면 카드 아래 `space.8`에 `diary-row` `entries` 카드.
8. `ad-banner`(탭 바 위), `tab-bar`.

* 빠진 것(D108): 맨 위 날의 성격 배지와 이유 한 줄(`day-character`). 날의 성격은 3번 태그 줄의 한자 태그입니다.
* 대표 태그가 없는 날(D112, 결정 V95, 표본 약 7%): 화면 뼈대는 날마다 같습니다. 4번 사주 기운은 제목은 그대로 두고 카드 안에 `today.featured.empty` 한 줄, 3번 총운은 결정 태그 줄과 헤드라인만 두고 선(`list.divider`), 사주 기운 태그, 보조 문장을 그리지 않습니다. 빠지는 것은 보조 문장 블록이고, 결정 태그 줄은 날마다 있는 헤드라인 쪽 구성이라 남깁니다(근거: IA `today.fortune.body` role "대표 태그가 없는 날(엔진이 보조 문장을 내지 않음)은 선, 태그, 보조 문장을 모두 그리지 않고 헤드라인만 둠(D112)"는 보조 문장 슬롯의 role이고, 결정 태그 줄은 `today.character.label`, `today.ten-god.label`의 자리). 7번 오늘의 질문은 일진 십성 묶음 질문으로 대신합니다(core C30, 질문을 고르는 일은 server, 카드 모양은 그대로). 헤드라인의 근거 아이콘과 그 시트는 같습니다.
* 불러오는 중(IA `loading`): 상단 바와 섹션 제목은 그대로, 날짜 머리는 음력과 일진 줄만 뼈, 카드마다 그 컴포넌트의 뼈(`hanja-tag` 알약, `sentence-block` 글줄, `lucky-card` 칩, `guide-question-card`)를 배치대로 둡니다(V66).
* 시간 모름(IA `time-unknown`): 날짜 머리 아래 `notice-banner` `time-unknown`(세 기둥으로 계산했다는 안내, 문구는 사주 표와 같은 `saju-chart.time-unknown.notice`). 그 밖은 같습니다.

### tag-sheet 화면 배치

사주 기운 시트(IA v5 `tag-sheet`, D108, 결정 V79). 오늘 화면의 사주 기운 태그(4번 섹션, 3번 보조 문장 위 태그)를 누르면 `sheet` `half`(내용 높이)로 아래에서 엽니다. 화면이 밀리지 않습니다(F-008).

1. 머리: 누른 태그 `hanja-tag` `default`(누를 수 없는 표시) + 오른쪽 끝 `depth-link` `inline-end` 아이콘(누르면 `evidence-sheet`가 `sheet.stack`). 핸들 자리 아래 `space.8`.
2. 뜻(`tag-sheet.tag.meaning`): 머리 아래 `space.12`, `sentence-block` `body`(용어 풀이 원고 `term.tag.*`).
3. 이 기운에서 나온 오늘 문장: 뜻 아래 `space.24`, `tag-sentence-list`(머리 `tag-sheet.sentences.title`, 줄은 보조 문장과 오늘의 질문, 없으면 `tag-sheet.sentences.empty`).
4. 출구: `tag-sentence-list` 아래 꺾쇠 링크(`tag-sheet.diary.cta`, 편수 없이 늘 보임) → `tag-diary`.

* 대표 태그 1순위 시트는 줄 둘(보조 문장, 오늘의 질문), 2순위 시트는 빈 안내 한 줄입니다(IA `empty`).
* 시트가 열린 동안 오늘 화면의 그 태그는 `selected`입니다.

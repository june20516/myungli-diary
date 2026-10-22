# today: 오늘 화면 (`today.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.6, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.11, 결정 V20·V22, V1 결정 V8(배지)
* 시안: `design-v2-today`, `design-v2-share-image`, `design-v2-rest`(질문 카드 전·후)

## day-character

* 쓰는 화면: preview, today, day-sheet, diary-view
* 배지(`radius.full`, `type.label.md`, 높이 26) + 이유 한 줄(`type.caption.lg` `text.secondary`) + 끝에 depth-link `inline-end`. 이유 줄의 용어는 `sentence-block` 문장 조각 규칙을 따릅니다(today·day-sheet에서 칩).

| 변형 | 엔진 `DayKind` | 배지 |
| --- | --- | --- |
| `good` | `YONGSIN_DAY` | `badge.good.*` 채움 |
| `gwiin` | `GWIIN_DAY` | `badge.gwiin.*` 옅은 coral |
| `gisin` | `GISIN_DAY` | `badge.gisin.*` neutral 채움 |
| `ordinary` | `ORDINARY_DAY` | 바탕 없음, 1px `badge.ordinary.border` |

배지는 글자로 날의 성격을 말합니다. 색만으로 전하지 않습니다.

## lucky-card

* 쓰는 화면: today, my-saju
* 칩(`chip.bg` 알약, 높이 34) = 앞 아이콘 Regular 16(색 변형은 `ohaeng.swatch` 14px 원) + 값(`type.label.md`). 변형 `color`·`direction`·`number`·`time`·`tag`.
* 누르면 칩 안쪽에 1.5px `action.primary` 테두리가 생기고, 칩 줄 아래에 설명 한 줄이 `appear.seep`(칩 바탕 `radius.md` 상자). 설명의 용어는 `sentence-block` 문장 조각 규칙을 따릅니다. 다시 누르면 닫힘. 한 번에 하나만 열립니다.
* 칩 줄은 화면 폭에 따라 다음 줄로 넘어갑니다. 줄 수는 제한하지 않고, 칩 하나는 줄 사이에서 끊지 않습니다.
* **`tag`(대표 태그, D76, 결정 V35):** today에만 있습니다. 그날의 대표 태그(`Daily.tags.featured`, 0~2개)를 칩 줄 맨 앞, 행운 4종(`color`·`direction`·`number`·`time`) 앞에 계약 순서대로 놓고, 0개면 그리지 않습니다. 칩 줄 전체의 칩은 최대 6개(태그 2 + 행운 4)입니다.
  * 칩 바탕·높이·알약 모양·글자색은 행운 칩과 같습니다. 글자 굵기 600(`type.label.md`의 500 대신)과 앞 아이콘 `tag`의 색 `text.primary`(행운 칩은 `text.secondary`)로만 구분합니다. 아이콘 굵기는 `regular` 그대로입니다(`bold` 금지, elements `icon`).
  * 길흉(`Tag.polarity`)은 색으로 나누지 않습니다. 부정 신호 태그(충·공망)도 같은 모양이고 잠금·구매 안내와 잇지 않습니다(D72). `#`·`hash`는 `number` 칩 아이콘과 겹쳐 쓰지 않습니다.
  * 누르면 다른 칩처럼 설명 상자에 `today.lucky-tag.body`가 스밉니다. 열림 테두리도 같습니다. 칩 이름 슬롯은 `daily.tag_label`, 스크린리더 라벨은 태그 이름만입니다.
  * `share-image`의 칩 줄에는 넣지 않습니다(행운 4종만).
* `time` 값은 프로필 시간대의 24시간 `HH:mm–HH:mm`이고, 시작과 끝은 en dash(U+2013)로 잇습니다. 구간이 둘 이상이면 ` · `(가운뎃점, 앞뒤 공백)로 잇습니다. 예: `09:30–11:30 · 13:30–15:30`. 숫자는 `tnum`이고 세 언어 모두 같은 형식입니다.

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
* 위에서부터 날짜 → 배지 → 문장(호칭 포함) → 행운 칩 → 아래 로고 조합(`logo/lockup.svg`) + `image.footer`.

| 변형 | 비율 · 크기 | 이유 줄 | 문장 | 칩 |
| --- | --- | --- | --- | --- |
| `story` | 9:16, 1080×1920 | 있음 | 전체 | 4 |
| `feed` | 4:5, 1080×1350 | 없음 | 두 줄 | 3 |
| `square` | 1:1, 1080×1080 | 없음 | 첫 문장 | 3 |

* 공유 미리보기 시트 위 segmented로 사용자가 비율을 고릅니다. 바뀔 때 미리보기가 `appear.seep`.
* 미리보기에는 `shadow.raised`(이 토큰을 쓰는 유일한 곳).
* 태그라인 자리는 writing W1.

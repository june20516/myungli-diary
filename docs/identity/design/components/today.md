# today: 오늘 화면 (`today.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.6, 결정 V20·V22, V1 결정 V8(배지)
* 시안: `design-v2-today`, `design-v2-share-image`, `design-v2-rest`(질문 카드 전·후)

## day-character

* 쓰는 화면: preview, today, day-sheet, diary-view
* 배지(`radius.full`, `type.label.md`, 높이 26) + 이유 한 줄(`type.caption.lg` `text.secondary`) + 끝에 depth-link `inline-end`.

| 변형 | 엔진 `DayKind` | 배지 |
| --- | --- | --- |
| `good` | `YONGSIN_DAY` | `badge.good.*` 채움 |
| `gwiin` | `GWIIN_DAY` | `badge.gwiin.*` 옅은 coral |
| `gisin` | `GISIN_DAY` | `badge.gisin.*` neutral 채움 |
| `ordinary` | `ORDINARY_DAY` | 바탕 없음, 1px `badge.ordinary.border` |

배지는 글자로 날의 성격을 말합니다. 색만으로 전하지 않습니다.

## lucky-card

* 쓰는 화면: today, my-saju
* 칩(`chip.bg` 알약, 높이 34) = 앞 아이콘 Regular 16(색 변형은 `ohaeng.swatch` 14px 원) + 값(`type.label.md`). 변형 `color`·`direction`·`number`·`time`.
* 누르면 칩 안쪽에 1.5px `action.primary` 테두리가 생기고, 칩 줄 아래에 설명 한 줄이 `appear.seep`(칩 바탕 `radius.md` 상자). 다시 누르면 닫힘. 한 번에 하나만 열립니다.
* 칩 줄은 화면 폭에 따라 두 줄로 넘어갑니다.

## guide-question-card

* 쓰는 화면: today
* `bg.sheet`, `radius.lg`, 안쪽 20.

| 상태 | 질문 | 동작 | 도장 |
| --- | --- | --- | --- |
| `before` | `type.sentence.card` 본문색 | 주 버튼 "일기 쓰기" | 없음 |
| `after` | `text.secondary`로 흐림 | 가운데 조용한 버튼 "쓴 일기 보기"(글자 `seal.on-soft`) | 버튼 글자 뒤 층에 `seal` soft 52px |

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

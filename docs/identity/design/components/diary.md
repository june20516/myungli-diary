# diary: 일기 (`diary.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.8, 결정 V16·V20, [같은 날 여러 편 spec](../specs/2026-10-22-diary-row-multi-design.md)(V42)
* 시안: `design-v2-diary-save`(종이 아래 도장 자리), `design-v2-diary-list`(흐름 줄 가), `design-v2-tag-chip`(태그 길흉 B), `design-v2-diary-row-multi`(같은 날 묶음 A + 점선)

## diary-row

* 쓰는 화면: diary-list, tag-diary, today, day-sheet
* 변형 `day`(목록·태그 모아보기)와 `entries`(오늘·그날 시트). 날의 성격 배지와 태그는 날짜에 붙어 그날 일기 모두에 같으므로(D83 ①), 같은 날 여러 편을 나타내는 단위는 **시각 + 한 줄 미리보기** 줄(`entry`)입니다.

### `day`

* 왼쪽 날짜 열(44px): 숫자 18px 600(고정폭) + 뒤에 `seal` soft 34px(숫자가 도장 가운데) + 요일 `type.caption.md`.
* 날짜 열 가운데로 `rail.timeline`(1.5px)이 요일 아래에서 다음 날짜까지 이어집니다. 마지막 줄 뒤에는 없습니다.
* 달이 바뀌는 자리에 달 머리(`type.subtitle`).
* **한 편인 날**: 오른쪽 카드(`bg.sheet`, `radius.lg`) 전체가 버튼. 배지 → 미리보기 두 줄(`sentence-block` `preview`, 14.5px 말줄임, 카드 전체가 버튼이라 용어도 일반 글자) → 대표 태그 칩 하나.
* **두 편 이상인 날(묶음 카드)**: 같은 카드 하나에 배지(위, 한 번) → `entry` 줄들(배지 아래 `space.4`) → 태그 칩(아래, 한 번, 마지막 줄 아래 `space.8`). 카드 전체는 버튼이 아니고, 누를 곳은 `entry` 줄마다와 태그 칩입니다. 흐름 줄은 카드 높이만큼 이어집니다.

### `entries`

* 날짜 열·배지·태그 없이 `entry` 줄만 작성 순으로 놓습니다.
* `today`: 가이드 질문 카드 아래 `space.12`에 카드 한 장(`bg.sheet`, `radius.lg`, 좌우 `space.16`·위아래 `space.4`). 오늘 쓴 일기가 없으면 그리지 않습니다.
* `day-sheet`: `day-sheet.diary.open` 머리 아래 시트 바탕에 카드 없이. 그날 쓴 일기가 없으면 머리와 줄을 모두 그리지 않습니다.

### `entry` 줄

| 요소 | 값 |
| --- | --- |
| 시각 | 작성 시각(`createdAt`), `type.caption.md` `text.secondary`, 고정폭, 줄바꿈 없음. 형식은 app이 기기 locale의 짧은 시각 형식으로 만듭니다 |
| 미리보기 | `sentence-block` `preview` **1줄** 말줄임, 시각 오른쪽 `space.12`, 첫 줄 기준선을 시각과 맞춤. 본문이 비어도 한 줄 높이를 지킵니다 |
| 꺾쇠 | `caret-right` 16 Light `text.secondary`, 세로 가운데 |
| 높이 | 위아래 `space.12`, 최소 48 |
| 사이 | 1px 점선(대시 4·간격 3) `color.timeline.entry`, 줄과 줄 사이에만 |

* 순서는 server 순서(작성 순) 그대로입니다. 같은 분에 쓴 일기도 다시 정렬하지 않습니다.
* 몇 편이든 모두 보입니다. 접지 않습니다(계정을 합친 날은 상한보다 많을 수 있음, D83 ④).
* 접근성: 한 편 카드는 버튼 "날짜 요일, 배지, 미리보기 첫 줄, 태그". 묶음 카드는 그룹 "날짜 요일, 배지"이고 안의 줄은 각각 버튼 "시각, 미리보기 첫 줄". `entries`의 줄도 같습니다.

## diary-editor

* 쓰는 화면: diary-edit(`edit`), diary-view(`view`)
* `surface.paper` 위에 날짜, (있으면) 오늘의 질문, 본문(`type.sentence.body`). 종이 아래 여백에 64px 도장 자리를 **쓰는 중에도 늘 비워 둡니다.** 글이 길어도 도장이 글을 덮지 않습니다.
* 해시태그를 쓰는 입력이 없습니다. 태그는 저장할 때 엔진이 붙입니다(엔진 spec §7.7, 제품 결정 D13).
* **저장 순간** (`motion.saveSequence`):
  1. 저장 버튼 점 숨쉬기(`loading.breathe`)
  2. 응답이 오면 종이 맨 아래로 스크롤(320ms)
  3. 아래 여백에 그날 날짜를 새긴 `seal` fill 64px가 `seal.stamp`, 햅틱 light
  4. 대표 태그 칩 `appear.seep`
  5. 토스트
  * 실패하면 도장을 찍지 않고 버튼이 돌아오며 오류 토스트.
* 보기 화면은 같은 종이에 도장이 이미 찍힌 채로, 아래 태그 칩.
* 도장 안 날짜(M.D)는 `seal.knock` 색으로 가늘게 새기고, 도장 영역 가운데에 둡니다.

## draft-indicator

* 쓰는 화면: diary-edit
* app-bar 오른쪽(동작 왼쪽) 작은 글자 `type.caption.md` + 아이콘 16 Light.

| 상태 | 아이콘 | 뜻 |
| --- | --- | --- |
| `local` | cloud | 기기에 초안 저장됨 |
| `saving` | 점 숨쉬기 | 보내는 중 |
| `saved` | check | 서버에 저장됨 |

상태가 바뀔 때만 `appear.seep`으로 바꿔 그립니다. 문구 3종은 writing 몫입니다.

## tag-chip

* 쓰는 화면: diary-list, diary-view, diary-edit(저장 순간)
* "#이름", `radius.full`, `type.label.md` 12px, 높이 26.
* 톤은 엔진이 준 태그의 길흉을 따릅니다(배지와 같은 V8 규칙, `tone` 요소):

| 변형 | 바탕 | 글자 |
| --- | --- | --- |
| `good` | `tag.good.bg` (coral-100 / 다크 coral-800) | `tag.good.fg` |
| `bad` | `tag.bad.bg` (neutral 채움) | `tag.bad.fg` |
| `neutral` | 없음, 1px `tag.neutral.border` | `tag.neutral.fg` |

* 누르면 태그 모아보기(tag-diary). 목록·보기·저장 순간 모두 같은 컴포넌트입니다.

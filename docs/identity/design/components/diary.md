# diary: 일기 (`diary.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.8, 결정 V16·V20, [같은 날 여러 편 spec](../specs/2026-10-22-diary-row-multi-design.md)(V42), [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §2 Q7·Q8, §4(V81~V83)
* 시안: `design-v2-diary-save`(종이 아래 도장 자리), `design-v2-diary-list`(흐름 줄 가), `design-v2-tag-chip`(태그 길흉 B), `design-v2-diary-row-multi`(같은 날 묶음 A + 점선)

## diary-row

* 쓰는 화면: diary-list, tag-diary, today, day-sheet
* 변형 `day`(목록·태그 모아보기)와 `entries`(오늘·그날 시트). 태그는 날짜에 붙어 그날 일기 모두에 같으므로(D83 ①), 같은 날 여러 편을 나타내는 단위는 **시각 + 한 줄 미리보기** 줄(`entry`)입니다.
* 카드 맨 위에 그날 날의 성격(`hanja-tag` 길흉 톤, 데이터 `DiarySummary.dayKind` D96, 쓸 때 기록한 값), 맨 아래에 그날 대표 태그(`hanja-tag` `default` 초록)를 둡니다. 옛 `day-character` 배지는 두지 않습니다. 결정 V81(관문 답 2026-11-06 Q1 ②로 개정).

### `day`

* 왼쪽 날짜 열(44px): 숫자 18px 600(고정폭) + 뒤에 `seal` soft 34px(숫자가 도장 가운데) + 요일 `type.caption.md`.
* 날짜 열 가운데로 `rail.timeline`(1.5px)이 요일 아래에서 다음 날짜까지 이어집니다. 마지막 줄 뒤에는 없습니다.
* 달이 바뀌는 자리에 달 머리(`type.subtitle`).
* **한 편인 날**: 오른쪽 카드(`bg.sheet`, `radius.lg`) 전체가 버튼. 날의 성격 태그 → (있을 때만) `space.8` 아래 미리보기 두 줄(`sentence-block` `preview`, 14.5px 말줄임, 카드 전체가 버튼이라 용어도 일반 글자) → 대표 태그 하나(`space.12` 아래).
* **두 편 이상인 날(묶음 카드)**: 같은 카드 하나에 날의 성격 태그(위, 한 번, 아래 `space.4`) → `entry` 줄들 → 대표 태그(아래, 한 번, 마지막 줄 아래 `space.8`). 카드 전체는 버튼이 아니고, 누를 곳은 `entry` 줄마다와 두 태그입니다. 흐름 줄은 카드 높이만큼 이어집니다.
* **태그(Q7 ②, Q1 ②):** 대표 태그는 엔진이 일진으로 정한 그날의 태그(D108 ①)이고 날의 성격 밖 용어라 `term` 초록, 날의 성격은 길흉 톤(V8 매핑)입니다. 값이 없으면 그 태그만 그리지 않습니다.
* **누르면(Q3 안 A):** 두 태그 모두 뜻 시트(`explain-sheet` half)입니다. 대표 태그 시트에만 본문 아래 그 태그의 모아보기 꺾쇠 링크(→ `tag-diary`)가 있고, 날의 성격 시트는 뜻만입니다. 줄에서 바로 화면 이동하지 않습니다(V73).
* **태그 모아보기 안(Q2 ①):** tag-diary 안의 줄은 대표 태그를 그리지 않습니다(`hiddenIn`). 모든 줄이 같은 태그이고 화면 위에 그 태그 이름과 뜻이 있기 때문입니다. 날의 성격은 줄마다 달라 그대로 보입니다.

### `entries`

* 날짜 열·태그 없이 `entry` 줄만 작성 순으로 놓습니다.
* `today`: 가이드 질문 카드 아래 `space.12`에 카드 한 장(`bg.sheet`, `radius.lg`, 좌우 `space.16`·위아래 `space.4`). 오늘 쓴 일기가 없으면 그리지 않습니다.
* `day-sheet`: 일기 섹션 머리 `section-header` `plain`(슬롯 `day-sheet.diary.open`) 아래 시트 바탕에 카드 없이. 컴포넌트 안 머리 `head`는 그리지 않습니다(결정 V85, V42 개정). 그날 쓴 일기가 없으면 줄을 그리지 않고 섹션 머리와 쓰기 버튼만 둡니다.
* 최상위의 날짜 열·도장·흐름 줄·카드·날의 성격·2줄 미리보기·태그는 모두 `visible: false`로 덮어씁니다.

### `entry` 줄

| 요소 | 값 |
| --- | --- |
| 시각 | 작성 시각(`createdAt`), `type.caption.md` `text.secondary`, 고정폭, 줄바꿈 없음. 형식은 `event-row`와 같은 24시간제 `HH:mm`(앞 0 채움)입니다. 줄마다 미리보기 시작 위치가 같고 그날 시트 안의 시각 형식이 하나가 됩니다(결정 V46, #475) |
| 미리보기 | `sentence-block` `preview` **1줄** 말줄임, 시각 오른쪽 `space.12`, 첫 줄 기준선을 시각과 맞춤. 본문이 비어도 한 줄 높이를 지킵니다 |
| 꺾쇠 | `caret-right` 16 Light `text.secondary`, 세로 가운데, 미리보기와 사이 `space.8`(`event-row`와 같음, V46) |
| 높이 | 위아래 `space.12`, 최소 48 |
| 사이 | 1px 점선(`dashLength` 4, `dashGap` 3) `color.timeline.entry`, 줄과 줄 사이에만, 줄 전체 너비 |

* 순서는 server 순서(작성 순) 그대로입니다. 같은 분에 쓴 일기도 다시 정렬하지 않습니다.
* 몇 편이든 모두 보입니다. 접지 않습니다(계정을 합친 날은 상한보다 많을 수 있음, D83 ④).
* 접근성: 한 편 카드는 버튼 "날짜 요일, 날의 성격, 미리보기 첫 줄, 대표 태그". 묶음 카드는 그룹 "날짜 요일, 날의 성격"이고 안의 줄은 각각 버튼 "시각, 미리보기 첫 줄". `entries`의 줄도 같습니다. 본문이 비면 시각만 읽습니다.

## diary-editor

* 쓰는 화면: diary-edit(`edit`), diary-view(`view`)
* `surface.paper` 위에 날짜, (있으면) 오늘의 질문, 본문(`type.sentence.body`). 종이 아래 여백에 64px 도장 자리를 **쓰는 중에도 늘 비워 둡니다.** 글이 길어도 도장이 글을 덮지 않습니다.
* 쓰기(`edit`)에서는 날짜를 종이 위 `date-block`이 보이므로 종이 안 날짜를 그리지 않습니다.
* 보기(`view`)는 그 일기를 쓸 때의 질문(getDiary `guideQuestion`)을 같은 인용 모양으로 보이고 질문 바꾸기는 없습니다. 질문이 없으면 그리지 않습니다(관문 답 2026-11-06 Q4 ①, IA diary-view 질문 자리는 지휘에 요청). 슬롯 `diary-edit.guide.question`, `diary-edit.body.placeholder`와 질문 바꾸기는 `edit`에만 있습니다.
* **인용 질문(결정 V82):** 질문(`diary-edit.guide.question`)은 종이 안 맨 위에 왼쪽 3px `term.bg` 선(`radius.full`) + 안쪽 `space.12`의 인용형이고, 글자는 `type.sentence.body`에 크기만 14로 덮어쓴 `text.secondary`입니다(본문 15보다 작게, 문장 글꼴 14 토큰이 없어 `preview` 14.5와 같은 방식, 관문 답 2026-11-06). 본문은 질문 아래 `space.16`.
* **질문 바꾸기:** 질문 오른쪽 `arrows-clockwise` Light 20 `text.secondary`(터치 44, 질문 첫 줄 높이, 사이 `space.8`). 그날 근거가 있는 후보(같은 키의 다른 변주, 대표 태그 2순위, 일진 십성 묶음. 목록과 순서는 server #806, 근거는 core #804)가 둘 이상일 때만 보입니다. 누르면 다음 후보로 `appear.seep` 바꿔 그리고 끝에서 처음으로 돌아갑니다. 본문은 건드리지 않습니다. 스크린리더 이름은 IA 자리가 없어 writing 새 슬롯이 필요하고, 바뀐 질문은 polite로 읽습니다.
* **키보드(Q8, 결정 V83):** 본문에 초점이 있는 동안 `text-field`와 같은 키보드 내리기 버튼(요소 `keyboard.dismiss`, 44 원, `caret-down`)을 키보드 inset(OS 자동완성과 추천 줄 포함) 위 `space.12` 오른쪽에 띄웁니다. 본문 스크롤 아래 여백은 키보드 inset + 버튼 44 + `space.12`라 커서 줄이 버튼에 가리지 않습니다. 붙여넣기 막대와 겹치는지는 QA에서 확인합니다.
* 해시태그를 쓰는 입력이 없습니다. 태그는 저장할 때 엔진이 붙입니다(엔진 spec §7.7, 제품 결정 D13).
* **저장 순간** (`motion.saveSequence`):
  1. 상단 바 저장 글자 버튼 점 숨쉬기(`loading.breathe`, `app-bar` `textActionSaving`)
  2. 응답이 오면 종이 맨 아래로 스크롤(320ms)
  3. 아래 여백에 그날 날짜를 새긴 `seal` fill 64px가 `seal.stamp`, 햅틱 light
  4. 대표 태그 칩 `appear.seep`
  5. 토스트
  * 실패하면 도장을 찍지 않고 버튼이 돌아오며 오류 토스트.
* 보기 화면은 같은 종이에 도장이 이미 찍힌 채로, 아래 태그 칩.
* 도장 안 날짜(M.D)는 `seal.knock` 색으로 가늘게 새기고, 도장 영역 가운데에 둡니다.

## date-block

* 쓰는 화면: diary-edit
* 근거: [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §1, §4, 결정 V82. 시안 `design-ds1-screen-f-c`
* 일기 쓰기 맨 위 큰 날짜입니다. 일 숫자 44 700(`font.family.ui`, 고정폭, `text.primary`, `diary-edit.date.day`) 옆 `space.12`에 두 줄 묶음: 월과 요일(`type.label.lg` `text.primary`, `diary-edit.date.month`), 그 아래 `space.2`에 일진(`type.caption.md` `text.secondary`, `diary-edit.date.iljin`, 한자는 `font.family.hanja`). 두 줄 묶음은 숫자와 세로 가운데로 맞춥니다.
* 날짜와 월, 요일은 고른 날짜(기기 값)라 바로 보이고, 일진은 server 값이라 불러오는 중에는 글줄 뼈 하나(64)입니다. 일진이 없으면 그 줄만 그리지 않습니다.
* 누를 수 없는 표시입니다. 날짜를 바꾸는 입구는 diary-list 날짜 고르기뿐입니다.
* 접근성: 머리(`header`) "월 일 요일, 일진 독음". 한자는 읽지 않습니다.

## draft-indicator

* 쓰는 화면: diary-edit
* `app-bar` `edit` 가운데에 작은 글자 `type.caption.md` `text.secondary` + 아이콘 16 Light, 그 뒤 `space.8`에 글자 수(`diary-edit.length.count`, 고정폭). 쉼표 같은 구분 글자는 없습니다(V47, V78과 같은 이유). 본문에 초점이 있는 동안(쓰는 중)만 보이고, 그 밖에는 같은 자리에 화면 제목이 보입니다(결정 V82).
* 상단 바 가운데 정렬입니다(시안 `design-ds1-screen-f-c`). 양쪽에 저장 글자 버튼 최대 폭(88)만큼 비운 가운데 폭(360 기준 152)에 한 줄이고, 넘치면 상태 글자 끝을 말줄임하며 글자 수는 지킵니다. 글자 상한은 이 폭으로 잽니다(`lengths.md`, 결정 V94). 글자 수는 칠 때마다 바꿔 그리되 읽지 않습니다(초점을 옮기면 상태와 함께 읽음).

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

* 누르면 뜻 시트(`explain-sheet`)이고, 그 태그의 모아보기(tag-diary)는 시트 아래 꺾쇠 링크입니다(관문 답 2026-11-06, V73). 보기·저장 순간에 씁니다. 일기 목록 줄의 태그는 IA v5부터 `hanja-tag`입니다(Q7, V81). IA diary-list 구성에는 아직 `tag-chip`이 남아 있어 지휘에 알립니다.

## diary-summary

* 쓰는 화면: my-saju
* 근거: [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §4, 결정 V76. 시안 `design-ds1-screen-b`
* 나 탭 명리일기 회고 섹션의 카드입니다(`bg.sheet`, `radius.lg`, 안쪽 `space.16`). 섹션 제목(`my-saju.record.title`)은 `section-header` 몫입니다.
* 위에서부터 편수, "어떤 날에 썼나" 막대 넷, "자주 붙은 태그"입니다. 머리 글자는 `type.label.md` `text.secondary`, 위 `space.16`, 아래 `space.8`(아래 내용의 이름이라 붙임, V56).

| 부품 | 값 |
| --- | --- |
| 편수 | 숫자 28 700 고정폭 `text.primary` + 단위 글자 `type.label.lg`(숫자 기준선에 맞춤, 사이 `space.4`) |
| 막대 줄 | 이름 칸 72(`type.label.md`, 날의 성격 이름 writing `dayKind` 네 키) + 막대 + 수(`type.numeric.table`, 고정폭, 폭 28 오른쪽 맞춤, 막대와 사이 `space.12`). 줄 사이 `space.8`, 최소 높이 24 |
| 막대 | 높이 8 `radius.full`, 트랙 `bg.base`. 길이는 그 줄의 수를 네 줄 가운데 가장 큰 수에 견준 비율. 0이면 트랙만 |
| 줄 순서 | 용신의 날, 귀인의 날, 평범한 날, 기신의 날 |
| 막대 색 | 날의 성격 톤. V8 배지 매핑의 진한 쪽 색: 용신 `badge.good.bg`, 귀인 `badge.gwiin.fg`, 평범 `badge.ordinary.border`, 기신 `badge.gisin.fg` |
| 태그 | `hanja-tag` `default`(사주 용어 초록) 최대 셋, 수 많은 순, 사이 `space.8`. 수는 알약 안 이름 뒤 `space.4`(`type.label.md` `text.secondary` 고정폭). 누르면 뜻 시트(`explain-sheet`)이고, 그 태그의 일기 모아보기(`tag-diary`)는 시트 아래 꺾쇠 링크입니다(V76을 관문 답 2026-11-06으로 개정). 태그가 없으면 머리와 줄을 그리지 않습니다 |

* 막대 색의 옅은 쪽(귀인 coral-100, 기신 neutral-100)은 트랙과 구분되지 않아 진한 쪽(글자색, 테두리색)을 씁니다. 이름과 수가 늘 함께 보여 색만으로 전하지 않습니다.
* **기록이 적을 때(`few`):** 쓴 편수가 5편 미만이면 막대를 숨기고 안내 한 줄(`my-saju.record.few`, `type.caption.lg` `text.secondary`, 위 `space.12`)을 둡니다. 편수와 (있으면) 태그는 그대로입니다. 0편도 같습니다.
* 불러오는 중: 편수 글줄 하나(96), 막대 글줄 넷, 태그 칩 셋(64). 머리 글자는 바로 보입니다.
* 접근성: 카드는 그룹 "편수, 날의 성격마다 이름과 수, 태그 이름과 수". 막대는 꾸밈이라 읽지 않습니다. 글자 배율 상한 1.3배.
* **문구 자리:** 단위 글자, 막대 머리, 태그 머리는 IA에 슬롯이 없습니다(writing 새 슬롯, IA 알림 필요). 편수 집계는 server 새 경로입니다(IA `my-saju.record.title` 역할 설명).

## 화면 배치

### diary-list 화면 배치

1. `app-bar` `tab-root`: 제목 `diary-list.bar.title`. 오른쪽 동작 아이콘 없음(쓰기 입구는 아래 버튼 하나, IA v5).
2. 일기 줄 `diary-row` `day`: 달 머리(`type.subtitle`) 아래 날짜마다 한 줄(V42 그대로). 카드 위 날의 성격 `hanja-tag`(길흉 톤), 아래 대표 태그 `hanja-tag` `default`(Q7 ②, Q1 ②). 두 태그 모두 누르면 `explain-sheet`.
3. 일기 쓰기 `primary-button` `filled` `floating`(`diary-list.pick-date.cta`, `leadingIcon` `pencil-simple`): 목록이 있을 때 광고 배너 위 `space.16`, 좌우 `space.20`에 떠 있고 목록이 뒤로 지나갑니다. 누르면 날짜 고르기 시트(`date-picker` `calendar`, 기본값 오늘)이고 시트 아래 버튼은 `diary-list.pick-date.confirm`(고른 날이 10편을 채우면 누를 수 없음).
4. `ad-banner`, `tab-bar`.

* 빈 상태(`empty`): `empty-state`(아이콘 `notebook`, 탭 아이콘과 같음) 안내(`diary-list.empty.body`) 아래 같은 일기 쓰기 버튼을 가운데 둡니다. 떠 있는 버튼은 없습니다.
* 불러오는 중: `diary-row` 뼈를 화면 배치대로 쌓고 떠 있는 버튼은 숨깁니다. 오류는 `stateMap`(`error-state` 다시 시도)이고 떠 있는 버튼은 숨깁니다. 오프라인은 받아 둔 목록 + `notice-banner`이고 이때 떠 있는 버튼은 그대로입니다.

### diary-edit 화면 배치

1. `app-bar` `edit`: 뒤로, 가운데 제목 `diary-edit.bar.title`(쓰는 중에는 `draft-indicator`: `diary-edit.draft.status` + `space.8` + `diary-edit.length.count`), 오른쪽 저장 글자 버튼 `diary-edit.save.cta`(쓴 것이 없으면 누를 수 없음, 누르면 저장 순서 뒤 diary-view).
2. `date-block`(app-bar 아래 `space.16`, 좌우 `space.20`): `diary-edit.date.day`, `diary-edit.date.month`, `diary-edit.date.iljin`.
3. `diary-editor` `edit`(date-block 아래 `space.24`): 종이 안 맨 위 인용 질문 `diary-edit.guide.question` + 질문 바꾸기, 그 아래 `space.16`에 본문(안내 `diary-edit.body.placeholder`).
4. 본문에 초점이 있는 동안 키보드 내리기 버튼(키보드 inset 위 `space.12` 오른쪽). 키보드 위 막대는 OS 자동완성과 붙여넣기 막대에 비워 둡니다.

* 아래 고정 버튼은 없습니다(저장은 상단 바 글자 버튼, IA v5).
* 오프라인: 종이 위에 `notice-banner`(`diary-edit.offline.notice`), 초안은 기기에 남습니다. 저장 실패(그날 10편 포함)는 오류 `toast`, 저장 뒤 붙은 태그 알림은 `toast`(`diary-edit.saved.tags`).
* 불러오는 중(가이드 질문): 일진 글줄 뼈와 질문 글줄 뼈 두 줄. 본문 칸은 바로 쓸 수 있습니다.
* 이어 쓰기(`draft`): 기기에 남은 초안을 본문에 채웁니다. 초점 전에는 가운데가 제목이고, 본문이 초점을 받으면 가운데 상태가 `local`로 보입니다(`draft-indicator` 표시 조건).

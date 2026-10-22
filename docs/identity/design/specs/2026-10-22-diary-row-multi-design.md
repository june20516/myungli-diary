# 같은 날 여러 편 일기 줄 설계 (컴포넌트 계약 2.8.0 · 토큰 1.2.0)

* 작업 단위: design
* 마일스톤: V2 후속 (선행 컴포넌트 2.7.0)
* 입력: Issue #410(D83 `diary-row` 같은 날 여러 편), D83 ②의 10편 상한(2026-10-22 개정, #422)
* 기준 문서: `docs/decisions.md` D83, IA v4 `docs/ia/screens.json`(`today`·`day-sheet`·`diary-list`·`tag-diary`), writing W37(상한 문구), REST API draft.13(`DiarySummary.createdAt`, 목록은 같은 날 작성 순)
* 시안: [`artifacts/2026-10-22-v2-diary-row-multi.html`](../artifacts/2026-10-22-v2-diary-row-multi.html) (목록 A안 + 점선 채택)
* 계약: 컴포넌트 명세 2.7.0 → **2.8.0**(변형·상태 추가). 토큰 1.1.0 → **1.2.0**(역할 색 하나 추가)

## 1. 목적과 완료 기준

D83으로 일기를 하루에 여러 편 쓸 수 있습니다. 날의 성격(배지)과 태그는 날짜에 붙어 그날 일기 모두에 같고(D83 ①), 일기마다 다른 것은 **작성 시각과 본문**뿐입니다. 이 작업은 같은 날 여러 편을 세 화면(`diary-list`·`tag-diary`, `today`, `day-sheet`)에서 어떻게 보일지와, 10편을 채운 날 쓰는 입구의 모양을 정해 app이 추가 질문 없이 그리게 합니다.

사용자가 정한 방향:

* 일기 목록은 **날짜 하나에 카드 하나**(A안). 배지는 카드 위에 한 번, 태그는 아래에 한 번, 그 사이에 일기마다 한 줄.
* 같은 날 일기 사이는 **점선**. 두께는 실선(흐름 줄)과 같은 1px, 대시는 4px, 간격 3px.

끝나는 조건:

1. 컴포넌트 명세 2.8.0, 토큰 1.2.0 (§2~§5)
2. 검사기 `tools/components.py`·`tools/tokens.py`와 pytest 통과
3. 결정 V42·V43, 시안 기록, `CLAUDE.md` 갱신
4. Issue #410 `Closes`

## 2. 한 편 줄 `entry` (공통 단위)

같은 날 여러 편을 나타내는 단위는 "시각 + 한 줄 미리보기" 한 줄입니다. 세 화면이 같은 모양을 씁니다.

| 요소 | 값 |
| --- | --- |
| `time` | 작성 시각(`createdAt`, 고친 시각 아님). `type.caption.md`, `color.text.secondary`, 고정폭 숫자(`tnum`), 줄바꿈 없음. 형식은 app이 기기 locale의 짧은 시각 형식으로 만듭니다(writing 슬롯 없음) |
| `preview` | `sentence-block` `preview`, **1줄** 말줄임. `time` 오른쪽에 남은 너비를 씀(간격 `space.12`), 첫 줄 기준선을 `time`과 맞춤 |
| `chevron` | Phosphor `caret-right` 16 Light, `color.text.secondary`, 세로 가운데. 한 카드 안에 누를 곳이 여럿임을 알림 |
| 줄 높이 | 위아래 `space.12`, 최소 48 |
| 사이 구분 | 1px 점선, 대시 4px·간격 3px, `color.timeline.entry`. 줄과 줄 **사이에만** 그음(첫 줄 위·끝 줄 아래 없음) |
| 눌림 | 줄마다 `press.ink`, 누르면 그 일기 `diary-view` |

* 순서는 작성 순(`createdAt` 오름차순)입니다. server 목록 순서 그대로입니다(draft.13).
* 몇 편이든 모두 보입니다. 접거나 "더 보기"를 두지 않습니다. 보통 10편까지이고, 계정을 합친 날은 그보다 많을 수 있습니다(D83 ④).
* 점선은 흐름 줄(`rail.timeline`, 실선)보다 한 단계 가벼운 경계입니다. 날짜 사이는 실선, 같은 날 안은 점선으로 읽힙니다.

## 3. `diary-row`

### 3.1. 변형

| 변형 | 쓰는 화면 | 모양 |
| --- | --- | --- |
| `day` (기본) | `diary-list`, `tag-diary` | 왼쪽 날짜 열 + 오른쪽 카드. 그날 일기가 한 편이면 **지금 모양 그대로**(배지 → 미리보기 2줄 → 태그 칩, 카드 전체가 버튼). 두 편 이상이면 묶음 카드(§3.2) |
| `entries` | `today`, `day-sheet` | 날짜 열·배지·태그 없이 `entry` 줄만. 날짜와 날의 성격은 화면이 이미 보여 줍니다 |

### 3.2. `day` 묶음 카드 (두 편 이상)

* 카드 바탕·반경·여백은 한 편일 때와 같습니다(`bg.sheet`, `radius.lg`, 안쪽 `space.16`).
* 위에서부터: 배지(`day-character` badge) → `entry` 줄들(첫 줄은 배지 아래 `space.4`) → 대표 태그 칩 하나(마지막 줄 아래 `space.8`).
* 카드 전체는 버튼이 아닙니다. 누를 곳은 `entry` 줄마다와 태그 칩(태그 모아보기)입니다.
* 날짜 열·흐름 줄·달 머리 규칙은 그대로입니다. 흐름 줄은 묶음 카드 높이만큼 이어져 다음 날짜까지 갑니다.

### 3.3. `entries`의 바탕

* `today`: 가이드 질문 카드 아래 `space.12`에 카드 한 장(`bg.sheet`, `radius.lg`, 좌우 안쪽 `space.16`, 위아래 `space.4`) 안에 줄을 놓습니다. 오늘 쓴 일기가 없으면 카드를 그리지 않습니다.
* `day-sheet`: `day-sheet.diary.open` 머리 아래 시트 바탕에 카드 없이 바로 놓습니다. 그날 쓴 일기가 없으면 머리와 줄을 모두 그리지 않습니다.

### 3.4. 상태와 접근성

* `pressed`: `entry` 줄 하나, 또는 한 편 카드 전체에 `press.ink`.
* `loading`: `day`는 날짜 열을 바로, 카드는 skeleton(지금과 같음). `entries`는 줄 두 개 높이 skeleton.
* 한 편 카드: role `button`, 라벨 "날짜 요일, 배지, 미리보기 첫 줄, 태그"(지금과 같음).
* 묶음 카드: role `group`, 라벨 "날짜 요일, 배지". 안의 `entry` 줄은 각각 role `button`, 라벨 "시각, 미리보기 첫 줄". 편수는 줄 개수로 전해지므로 따로 읽지 않습니다.
* `entries`의 줄도 role `button`, 라벨 "시각, 미리보기 첫 줄"입니다.

## 4. 10편을 채운 날의 쓰는 입구 (D83 ②)

세 입구 모두 누를 수 없게 하고 문구는 writing의 `…Full` 키를 씁니다(상한 수치 없음, W37). 새 문구 요청은 없습니다.

| 입구 | 컴포넌트·상태 | 문구 키 |
| --- | --- | --- |
| 오늘 가이드 질문 카드 | `guide-question-card` 새 상태 `full` | `todayGuideCtaFull` |
| 그날 시트 이날 일기 쓰기 | `primary-button` `filled` `disabled` | `daySheetDiaryWriteCtaFull` |
| 일기 목록 날짜 시트 아래 버튼 | `date-picker` `calendar`의 `bottomAction` `disabled` | `diaryListPickDateConfirmFull` |

* `guide-question-card` `full`: `after`와 같은 모양(질문 `text.secondary`, 도장 52 soft를 버튼 글자 뒤 층)에 `quiet` 버튼만 `disabled`(글자 `color.disabled.fg`)입니다. 도장은 그대로 둡니다. 그날 일기를 썼다는 표시이기 때문입니다. a11y `stateAnnounced`는 "더 쓸 수 없음"을 더합니다.
* 막힌 입구를 눌러도 아무 일도 일어나지 않고 햅틱도 없습니다. 이유는 버튼 글자가 말합니다.
* 날짜 시트(`date-picker` `calendar`)에서 상한을 채운 날도 고를 수 있습니다(그날 일기를 보려는 것이 아니라 날짜를 고르는 단계라서). 고른 뒤 아래 버튼만 막힙니다.

## 5. 토큰 1.2.0

| 토큰 | 라이트 | 다크 | 설명 |
| --- | --- | --- | --- |
| `color.timeline.entry` | `{color.neutral.300}` | `{color.neutral.700}` | 같은 날 일기 사이 점선 |

* 흐름 줄 `color.timeline.line`(= `color.line`)과 같은 색으로 끊긴 선을 그으면 너무 옅어 한 단계 진한 값을 씁니다. 중립 태그 칩 테두리와 같은 값이지만 역할이 달라 따로 둡니다.
* 추가만이므로 minor입니다.

## 6. 바뀌는 파일

* `components/diary.json`·`.md`: `diary-row` 변형 `day`·`entries`, 부품 `entry`(time·preview·chevron·divider), 묶음 규칙, a11y. "쓰는 화면"의 D83 메모를 이 spec으로 바꿈
* `components/today.json`·`.md`: `guide-question-card` 상태 `full`
* `components/input.json`·`.md`: `date-picker` `calendar` 규칙에 상한 채운 날 `bottomAction` `disabled`
* `components/action.md`: `primary-button` 쓰는 곳에 `day-sheet` 상한 상태 메모
* 모든 컴포넌트 JSON·`tools/components.py`·`components/README.md`: 2.8.0, 토큰 1.2.0 이상 기대
* `tokens/color.light.tokens.json`·`color.dark.tokens.json`·`tokens/README.md`·`tools/test_tokens.py`: `color.timeline.entry`, 1.2.0
* `docs/contracts/README.md`: 디자인 토큰·컴포넌트 명세 행
* `decisions.md` V42·V43, `artifacts/index.json`, `CLAUDE.md`

## 7. 결정

* **V42** 같은 날 여러 편: 목록은 날짜 하나에 카드 하나(배지 위·태그 아래 한 번씩, 사이에 시각 + 한 줄 미리보기 줄). 오늘·그날 시트는 같은 줄만. 줄 사이는 1px 점선(대시 4·간격 3, `color.timeline.entry`). 한 편인 날은 지금 모양.
* **V43** 상한을 채운 날의 입구: 세 입구 모두 `disabled` + writing `…Full` 문구. 가이드 질문 카드는 도장을 남긴 채 버튼만 막음.

## 8. Review Focus

* 미리보기가 빈 일기(본문이 공백뿐)일 때 줄 높이가 무너지지 않아야 합니다. `preview`는 빈 문자열이어도 한 줄 높이를 지킵니다.
* 큰 글자 설정에서 `time`이 줄바꿈되지 않고 `preview`만 줄어야 합니다.
* 같은 시각(분까지 같음)에 쓴 두 편도 작성 순(server 순서)으로 놓입니다. app이 시각 문자열로 다시 정렬하지 않습니다.

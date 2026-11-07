# frame: 화면 틀 (`frame.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.1, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.7·§2.12·§3, [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §1·§2·§4, 결정 V15·V17·V59·V62·V69·V71
* 시안: `design-v2-frame`(틀 C), `design-v2-tab-seal`(낙관 도장 탭), `design-v2-sheet`(겹쳐 쌓기·닫기 규칙)

화면 틀은 "스며든 틀"입니다. 위 막대는 바탕을 칠하지 않고, 아래 탭 바는 반투명이라 내용이 비쳐 지나갑니다. 틀이 내용을 가두지 않게 하려는 것입니다.

## tab-bar

* 쓰는 화면: today, calendar, diary-list, my-saju
* 반투명 `bar.bg` + 탭 바 뒤 흐림 20px. 높이 72px(아래 안전 영역은 따로 더함), 위 0.5px `line`.
* 탭 4개, 아이콘 24px + 글자 11px(`type.caption.sm`).
* 탭 아이콘(`parts.icons`): 오늘 `sun`, 달력 `calendar-blank`, 일기 `notebook`, 나 `user`. app이 고른 값이 결정 V15(Phosphor, 평소 Light·선택 Regular)와 맞고 탭의 뜻과도 맞아 그대로 받았습니다.

| 상태 | 아이콘 | 글자 | 도장 |
| --- | --- | --- | --- |
| 미선택 | Light, `text.secondary` | `text.secondary` | 없음 |
| 선택 | Regular, `action.on-primary`(라이트 흰색, 다크 neutral-950) | `action.primary` 600 | `seal` fill 34px가 아이콘 뒤에 `seal.stamp` |
| 투명도 줄이기 | | | 바탕 `bg.sheet` 불투명, 흐림 없음 |

* 선택이 바뀌면 이전 도장은 `seal.erase`, 새 도장은 `seal.stamp`가 동시에 움직이고 햅틱 selection이 울립니다.
* 선택된 탭을 다시 누르면 맨 위로 올라갑니다. 도장은 다시 찍지 않습니다.
* Material 힌트: `NavigationBar`를 쓰면 indicator·표면 색조·그림자를 끄고, 선택 표시를 도장 위젯으로 바꿉니다.

## app-bar

* 쓰는 화면: 탭 첫 화면 4개와 안쪽 화면 대부분(IA `app-bar`)
* 높이 44px, 바탕 없음, 스크롤해도 선·그림자를 더하지 않습니다.

| 변형 | 왼쪽 | 가운데 | 오른쪽 |
| --- | --- | --- | --- |
| `tab-root` | 작은 제목(`type.subtitle`) | - | 동작 아이콘 최대 2개 |
| `inner` | 뒤로(caret-left) + 제목 왼쪽 정렬 | - | 동작 아이콘 |
| `edit` | 뒤로(caret-left) | 화면 제목(`type.label.lg`), 쓰는 중에는 `draft-indicator` | 글자 버튼 하나(저장) |

* **`edit`(일기 쓰기, 결정 V82):** 가운데는 화면 제목(`diary-edit.bar.title`)이고, 본문에 초점이 있는 동안은 같은 자리에 초안 상태(`draft-indicator`: 상태 글자 + 글자 수)가 `appear.seep`으로 바뀌어 보입니다. 가운데 글자는 뒤로와 글자 버튼 사이 폭에 한 줄입니다. 스크린리더 머리 이름은 늘 화면 제목입니다.
* **글자 버튼(`textAction`):** 바탕 없는 글자만의 오른쪽 버튼(`type.label.lg` `action.primary`, 좌우 `space.8`, 터치 44). `edit`에서 동작 아이콘 대신 하나만 둡니다. 쓴 것이 없으면 글자(`label`)가 `disabled.fg`로 누를 수 없고(`textActionDisabled`), 처리 중은 글자 자리에 점 셋 `loading.breathe`(폭 그대로, `textActionSaving`)입니다.

* 갈래의 첫 화면이라 돌아갈 곳이 없는 화면(consent, notify-ask)은 `inner`여도 뒤로 버튼을 숨깁니다. 뒤로 자리를 비워 두지 않으므로 제목의 시작 위치는 바뀌지 않습니다.
* Material 힌트: `AppBar`의 `scrolledUnderElevation: 0`, `surfaceTintColor: transparent`, `centerTitle: false`.

## 안내 글 본문 (레이아웃, 명세 컴포넌트 아님)

* 쓰는 화면: calc-basis(앞으로 비슷한 안내 글 화면도 같은 값). app 이름 `ProsePageBody`.
* `inner` 앱 바 아래에서 문단을 위에서부터 쌓고 전체가 스크롤됩니다.
* 여백: 좌우 `space.20`, 위 `space.24`, 아래 `space.32`. 문단 사이 `space.20`. 그리지 않는 문단에는 간격도 두지 않습니다.
* IA 컴포넌트가 아니라 JSON에는 없습니다(검사기는 IA 컴포넌트만 받음).

## sheet

* 쓰는 화면: explain-sheet, evidence-sheet, tag-sheet, color-rule-sheet, share-preview, day-sheet, settings 안의 값 고르기
* 위 모서리 `radius.xl`, 바깥 덮개 `scrim`. 좌우와 아래 안쪽 `space.24`(모서리 28 때문에 화면 좌우 20보다 넓힘, 결정 V64).
* 맨 위에 높이 24의 핸들 자리를 두고, 그 가운데 손잡이 36×4 `line`. 핸들 자리 전체가 끌기 영역이고 터치 높이 44입니다. 제목은 핸들 자리 아래 `space.8`.
* 끌어 닫기: 핸들이나 맨 위까지 스크롤된 내용을 끌어 내리면 손가락을 따라 내려가고, 시트 높이의 25% 넘게 내리거나 빠르게 튕기면 닫힙니다. 아니면 제자리로 돌아옵니다. 입력이 있는 시트는 닫기 전에 쓴 내용을 잃지 않게 확인합니다.
* 변형 `half`(화면 60%까지) / `full`(위 안전 영역 + 12px까지). 그날 시트(`day-sheet`)는 펼침과 접힘 없이 처음부터 `full`로 열리고, 색 규칙 시트는 `half`입니다(결정 V85).

| 동작 | 결과 |
| --- | --- |
| 열기 | `sheet.enter` (420ms) |
| 시트에서 한 단계 더 깊이(예: 풀이 → 근거) | 새 route로 `sheet.stack`: 새 시트가 위에 쌓이고 아래 층이 작아지며 어두워짐 |
| 뒤로 가기, 끌어내리기 | 맨 위 시트 하나만 닫힘 (`sheet.exit`) |
| 바깥(덮개) 누르기 | 쌓인 시트 모두 닫힘 |

* 깊어짐은 이동·크기·덮개만 움직입니다. 시트 높이를 움직이면 Flutter·웹 모두 끊겨 보여서 쓰지 않습니다(시안 비교에서 확인).
* Material 힌트: `showModalBottomSheet` 대신 route 기반 시트(`ModalBottomSheetRoute` 또는 자체 route)로 쌓기를 구현합니다.

## ad-banner

* 쓰는 화면: today, calendar, diary-list, my-saju (탭 첫 화면만, D53)
* 결정 V23: **탭 바 바로 위에 붙어 함께 고정**됩니다. 같은 반투명 `bar.bg`와 뒤 흐림을 써서 탭 바와 한 덩어리로 보이고, 내용은 둘 뒤로 지나갑니다. 탭 바 위 0.5px 선은 배너 위로 옮깁니다.
* 광고는 네트워크의 고정형 적응형 배너(화면 폭, 높이는 네트워크가 정함)입니다. 명세는 틀(바탕·선·위치)만 정하고, 광고 안은 네트워크가 그립니다.

| 상태 | 모습 |
| --- | --- |
| `loading` | 자리를 잡지 않음(빈 띠를 보이지 않음) |
| `loaded` | `appear.seep`으로 나타남 |
| `noFill` | 광고가 없으면 `disappear.seep`으로 자리째 사라짐 |
| `adFree` | 광고 제거 기간에는 숨김 |
| `noConsent` | 광고 동의(ATT·UMP)를 받기 전에는 숨김 |
| `reduceTransparency` | 바탕 `bg.sheet` 불투명 |

* 구현 힌트(Flutter): `loading`·`noFill`의 "자리를 잡지 않음"은 높이 0으로 구현합니다. 명세와 같습니다.

* 배너 높이가 생기거나 사라지면 아래 내용 여백도 함께 바뀌고, 스크롤 위치는 지킵니다. 토스트는 배너 위 16px에 뜹니다.

```
┌────────────────────┐
│ 오늘          ⋯     │
│  …내용 스크롤…       │
│  …(배너·탭 바 뒤로)… │
├────────────────────┤  ← 0.5px line
│ [  적응형 배너 광고 ] │  ← bar.bg 반투명
│ 오늘  달력  일기  나 │  ← 탭 바(같은 바탕)
└────────────────────┘
```

## section-header

* 쓰는 화면: today, day-sheet, my-saju, saju-chart
* 1단계 요소 `section.header`(결정 V59)를 IA v5의 컴포넌트로 옮겼습니다(결정 V69). 내용 묶음의 이름입니다.
* 제목은 어디서나 `type.label.lg` 600 본문색입니다(Q1 ③). 설명 줄은 선택이고 `type.caption.md` `text.secondary`, 제목 아래 `space.2`입니다.
* 제목과 내용 사이 `space.12`, 섹션과 섹션 사이 `space.32`입니다. 묶음의 기본은 간격이고, 목록 줄이 이어지는 묶음은 카드(`bg.sheet`, `radius.lg`)로 묶을 수 있습니다.
* **시작선:** 카드 바깥 가장자리에 맞춥니다. 화면에서는 화면 좌우 여백 `space.20`, 시트 안에서는 시트 안쪽 `space.24`에서 시작하고, 카드 안쪽 여백만큼 들이지 않습니다.
* **오른쪽 자리(`trailing`)는 둘 중 하나만 둡니다.**

| 변형 | 오른쪽 자리 | 누르면 |
| --- | --- | --- |
| `plain` | 없음 | |
| `link` | 글자(`type.label.md` `action.primary`) + 꺾쇠 `caret-right` Light(옆 글자 500, V57), 사이 `space.2` | 다른 화면으로 `page.push` |
| `action` | 아이콘 동작 하나: 좋아요(`reaction-button`) 또는 더하기(`plus` Light 24), 터치 44 | 그 동작 |

* 더 보기 글자 버튼, ⓘ, 밑줄 링크는 두지 않습니다(README "자세히 보기 표시").
* 스크린리더는 제목을 머리글로 읽고, 오른쪽 자리는 따로 초점을 받습니다(링크는 `link`, 동작은 `button`).
* 제목과 설명 문구는 화면마다 IA 슬롯입니다. UI 문구라 불러오는 중에도 제목은 그대로 그립니다.

## explain-sheet

* 쓰는 화면: today, saju-chart
* 1단계 요소 `explain.sheet`(결정 V62)를 IA v5의 컴포넌트로 옮겼습니다(결정 V71). 값은 그대로입니다.
* 칩, 배지, 용어, 한자 태그를 눌러 짧은 설명을 여는 곳입니다. 내용 높이만큼의 `sheet` `half`(핸들 있음)이고, 제목은 누른 항목의 이름(`type.subtitle`, 아래 `space.8`), 본문은 `sentence-block` `body`입니다. 바깥 누르기, 끌어 내리기, 뒤로 가기로 닫힙니다.
* 12운성 설명(사주 표 `band-table` 12운성 띠 머리 칩으로 연 시트)이면 본문 아래 `space.12`에 `stage-strip`을 둡니다(결정 V91). 12운성 값 칩(관대 등)의 뜻 시트에는 없습니다.
* **모아보기 링크(`diaryLink`, 관문 답 2026-11-06):** 대표 태그(엔진이 일기에 붙이는 사주 기운 태그: 합충, 신살, 십성 몰림)의 시트에만 본문 아래 `space.16`에 꺾쇠 링크 "<태그>이 붙은 내 일기 보기"(가안, 조사는 writing josa, IA 자리 새로 요청)를 둡니다. `type.label.lg` `action.primary` + `caret-right` Regular(옆 글자 단계, `space.2`), 터치 44. 누르면 시트를 닫고 `tag-diary`로 `page.push`. 편수는 보이지 않고 늘 보입니다(일기가 없으면 tag-diary 빈 상태). 날의 성격, 오늘 총운의 십성 묶음 결정 태그, 간지 태그, 용어 칩 시트에는 없습니다. 한자 태그와 태그 칩은 어디서나 이 시트를 엽니다(V73).
* 설명은 화면 배치 안에 끼워 넣지 않습니다. 그래서 열려도 아래 내용이 밀리지 않습니다(F-008). 연 항목에는 열린 동안 표시가 남습니다(`lucky-card` 테두리, `hanja-tag` `selected`).
* 다른 컴포넌트가 부품을 더하거나 값을 덮어쓰면 그 부품에 `note`로 적습니다. `term-token` 풀이 시트는 제목을 `type.title`로 키우고 한자 줄, 오늘 이유, 근거 진입점을 더합니다.
* 어느 화면의 어느 항목이 이 시트를 열지와 제목 문구 슬롯은 IA가 정합니다.

## scroll-hint

* 쓰는 화면: saju-chart
* 근거: [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §4, 결정 V90, 시안 `design-ds1-screen-e`
* 가로로 넘기는 줄(사주 표 대운, 세운)에 더 있음을 알립니다. 글자 안내(옆으로 넘겨 보세요)는 쓰지 않습니다.
* **흐림:** 데이터가 더 있는 쪽 끝만 24 폭으로 줄 바탕(`bg.sheet`)으로 흐려집니다. 더 없는 쪽 끝은 흐리지 않아 끝임을 보입니다.
* **화살표:** 줄 아래 양 끝에 `caret-double-left`, `caret-double-right` Light 16(`text.secondary`, 줄과 `space.4`). 더 없는 쪽 화살표는 숨깁니다. 누르면 보이는 폭만큼 그쪽으로 넘기고(기둥 경계에 맞춤), 터치 44, 눌림 `press.ink`. 꺾쇠(화면 이동)가 아니라 겹 화살표라 그 줄 안에서만 움직입니다.
* 상태: `atStart`(왼쪽 흐림과 화살표 없음), `middle`(양쪽), `atEnd`(오른쪽 없음). 처음 열 때 지금 칸으로 넘겨 두면 대개 `middle`입니다.
* 동작 줄이기: 흐림과 화살표는 바로 바뀌고, 화살표로 넘길 때 움직임 없이 바로 그 자리로 갑니다.
* 스크린리더: 줄 자체가 목록(list)이라 목록을 넘겨 읽고, 화살표는 숨깁니다.

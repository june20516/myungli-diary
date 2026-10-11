# frame: 화면 틀 (`frame.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.1, 결정 V17
* 시안: `design-v2-frame`(틀 C), `design-v2-tab-seal`(낙관 도장 탭), `design-v2-sheet`(겹쳐 쌓기·닫기 규칙)

화면 틀은 "스며든 틀"입니다. 위 막대는 바탕을 칠하지 않고, 아래 탭 바는 반투명이라 내용이 비쳐 지나갑니다. 틀이 내용을 가두지 않게 하려는 것입니다.

## tab-bar

* 쓰는 화면: today, calendar, diary-list, my-saju
* 반투명 `bar.bg` + 탭 바 뒤 흐림 20px. 높이 72px(아래 안전 영역은 따로 더함), 위 0.5px `line`.
* 탭 4개, 아이콘 24px + 글자 11px(`type.caption.sm`).

| 상태 | 아이콘 | 글자 | 도장 |
| --- | --- | --- | --- |
| 미선택 | Light, `text.secondary` | `text.secondary` | 없음 |
| 선택 | Regular, 흰색(`action.on-primary`) | `action.primary` 600 | `seal` fill 34px가 아이콘 뒤에 `seal.stamp` |
| 투명도 줄이기 | | | 바탕 `bg.sheet` 불투명, 흐림 없음 |

* 선택이 바뀌면 이전 도장은 `seal.erase`, 새 도장은 `seal.stamp`가 동시에 움직이고 햅틱 selection이 울립니다.
* 선택된 탭을 다시 누르면 맨 위로 올라갑니다. 도장은 다시 찍지 않습니다.
* Material 힌트: `NavigationBar`를 쓰면 indicator·표면 색조·그림자를 끄고, 선택 표시를 도장 위젯으로 바꿉니다.

## app-bar

* 쓰는 화면: 탭 첫 화면 4개와 안쪽 화면 대부분(IA `app-bar`)
* 높이 44px, 바탕 없음, 스크롤해도 선·그림자를 더하지 않습니다.

| 변형 | 왼쪽 | 오른쪽 |
| --- | --- | --- |
| `tab-root` | 작은 제목(`type.subtitle`) | 동작 아이콘 최대 2개 |
| `inner` | 뒤로(caret-left) + 제목 왼쪽 정렬 | 동작 아이콘, 초안 상태 |

* Material 힌트: `AppBar`의 `scrolledUnderElevation: 0`, `surfaceTintColor: transparent`, `centerTitle: false`.

## sheet

* 쓰는 화면: explain-sheet, evidence-sheet, share-preview, day-sheet, settings 안의 값 고르기
* 위 모서리 `radius.xl`, 손잡이 36×4 `line`, 바깥 덮개 `scrim`.
* 변형 `half`(화면 60%까지) / `full`(위 안전 영역 + 12px까지).

| 동작 | 결과 |
| --- | --- |
| 열기 | `sheet.enter` (420ms) |
| 시트에서 한 단계 더 깊이(예: 풀이 → 근거) | 새 route로 `sheet.stack`: 새 시트가 위에 쌓이고 아래 층이 작아지며 어두워짐 |
| 뒤로 가기, 끌어내리기 | 맨 위 시트 하나만 닫힘 (`sheet.exit`) |
| 바깥(덮개) 누르기 | 쌓인 시트 모두 닫힘 |

* 깊어짐은 이동·크기·덮개만 움직입니다. 시트 높이를 움직이면 Flutter·웹 모두 끊겨 보여서 쓰지 않습니다(시안 비교에서 확인).
* Material 힌트: `showModalBottomSheet` 대신 route 기반 시트(`ModalBottomSheetRoute` 또는 자체 route)로 쌓기를 구현합니다.

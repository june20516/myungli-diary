# 공통 상호작용 (`interaction.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §3, 결정 V14
* 모든 컴포넌트는 이 패턴만 씁니다. **명세에 적지 않은 효과는 쓰지 않습니다.** 위젯 라이브러리의 기본 물결 효과, 그림자, 표면 색조, 상태 겹침 색은 끄고 이 패턴을 입힙니다.
* 시간과 곡선은 토큰(`motion.duration.*`, `motion.easing.*`)을 가리킵니다. 구성 요소의 하위 시간(이전 선택 표시, 바깥 덮개)도 토큰입니다. 시간 길이가 아닌 간격(`loading.breathe`의 줄 사이 150ms 어긋남)만 직접 적습니다.

## 패턴

| 패턴 | 쓰임 | 움직임 | 시간 · 곡선 |
| --- | --- | --- | --- |
| `press.ink` 먹 번짐 | 모든 눌림(눌림 패턴은 이것 하나, V61) | 누른 자리에서 가장자리가 부드러운 원형 얼룩이 번집니다(그 컴포넌트 글자색, 알파 0.12). 다 자라면 진한 영역이 가장 먼 모서리까지 닿습니다. 떼면 다 자란 크기의 1.15배까지 번지며 사라집니다 | 자람 `stamp`(520) `seep`, 사라짐 `long`(420) `seep` |
| `appear.seep` 스밈 | 토스트·배너·확인 창·풀이 내용 | 제자리에서 흐림 8px→0, 투명도 0→1 | `medium`(320) `seep` |
| `disappear.seep` | 위의 사라짐 | 흐림 0→8px, 투명도 1→0 | `short`(200) `standard` |
| `select.seep-slide` 스밈 이동 | segmented·탭 선택 표시 | 새 표시가 이전 자리 쪽에서 거리의 15%만큼 미끄러져 들어오며 흐림 6px→0, 크기 0.92→1. 이전 표시는 제자리에서 흐림 0→6px·투명도 1→0·크기 1→1.06(`fade` 280ms) | `select`(340) `seep` |
| `loading.breathe` 먹 숨쉬기 | skeleton, 버튼 처리 중 점 세 개 | 투명도 0.55↔1, 줄마다 150ms씩 어긋남 | `breathe`(1800) `standard` |
| `seal.stamp` 찍고 배어듦 | 도장 찍힘 | ① 0~35%: 크기 1.2→1, 투명도 0→0.55, 흐림 3→1.5px, `stamp-press` ② 35~100%: 투명도 0.55→1, 흐림 1.5→0, `seep` | `stamp`(520) |
| `seal.erase` | 도장 지워짐 | 흐림 0→5px, 투명도 1→0 | `short`(200) `standard` |
| `mark.underline-grow` 펼침 밑줄 | 달력 선택 밑줄 | 가로 크기 0→1, 가운데 기준 | `long`(420) `seep` |
| `page.push` 화면 이동 | 화면 쌓기 이동(앞으로, 뒤로) | 새 화면이 오른쪽에서 24px(`motion.offset.page`) 밀려 들어오며 투명도 0→1. 뒤 화면은 움직이지 않고, 뒤로 가기는 거꾸로. 탭 사이 이동과 시트는 쓰지 않음(결정 V67) | `page`(320) `page`(enter 곡선) |
| `tab.switch` 탭 전환 | 탭 바로 탭 사이 이동 | 앞 화면과 새 화면이 겹치며 투명도만 1→0, 0→1. 이동과 크기 변화 없음, 탭 바는 그대로, 도장과 같은 프레임에 시작(결정 V104). 원래 투명도만이라 동작 줄이기에서도 같음 | `short`(200) `standard` |
| `sheet.enter` | 시트 열림 | 아래에서 올라옴. 바깥 덮개 `fade`(280ms) 투명도 | `long`(420) `enter` |
| `sheet.exit` | 시트 닫힘 | 아래로 내려감. 바깥 덮개 `fade`(280ms) 투명도 | `medium`(320) `exit` |
| `sheet.stack` 겹쳐 쌓기 | 시트 깊어짐 | 새 시트가 위에 쌓이고, 아래 화면은 크기 0.92·밝기 0.9, 아래 시트는 위로 30px·크기 0.94·밝기 0.95 | `long`(420) `enter` |
| `focus.ring` | 입력 포커스 | 테두리 1px `line` → 2px `action.primary`. 바탕은 바뀌지 않음 | `short`(200) `standard` |

곡선: `seep` (0.2, 0.7, 0.2, 1), `enter` (0.2, 0.8, 0.2, 1), `exit` (0.4, 0, 1, 1), `stamp-press` (0.5, 0, 0.9, 0.6), `standard` (0.4, 0, 0.2, 1).

* `seal.stamp`의 `keyframes`에서 각 프레임의 `easing`은 **그 프레임에 이르는 구간**의 곡선입니다.
* `sheet.stack`의 밝기는 아래 층 위에 검은 덮개를 겹쳐 냅니다(필터 아님). 움직이는 것은 이동·크기·덮개 투명도뿐입니다.
* `press.ink`의 얼룩은 컴포넌트 안쪽 별도 층에서만 잘립니다. 컴포넌트 밖으로 나가는 꼬리표('나' 등)는 자르지 않습니다.
* **먹 번짐의 크기(결정 V61):** 반지름은 누른 자리에서 가장 먼 모서리까지 거리 ÷ 0.7입니다. 반지름의 0~0.7은 같은 진하기, 0.7~1은 흐려지는 테라서, 다 자라면 진한 영역이 요소 끝까지 닿고 흐린 테는 요소 밖에서 잘립니다. 가장 먼 모서리 거리를 바깥 반지름으로 쓰면 가장자리 30%가 흐려 끝까지 안 퍼져 보입니다.
* 다 자라기 전(520ms)에 떼도 다 자란 크기까지 이어 자라며 사라집니다. 사라짐의 1.15배는 다 자란 반지름 기준입니다.
* **눌림 범위(V61):** 눌림 표시는 누른 컴포넌트 자신의 경계 안에서만 보입니다. 줄 안의 배지나 칩을 누르면 그 안에만 번지고 줄 전체로 번지지 않습니다. 줄과 그 안 요소가 둘 다 누를 수 있으면 안쪽 요소가 눌림을 가져갑니다.

## 햅틱

의미 있는 순간에만 울립니다. 기기의 시스템 햅틱 설정을 따릅니다.

| 순간 | 세기 |
| --- | --- |
| 선택이 바뀜(segmented, 탭, 체크, 날짜·시간 휠 눈금) | selection |
| 저장·완료(일기 저장, 동의 완료), 반응(좋아요) | light |
| 되돌릴 수 없는 동작 확인(일기 삭제, 계정 삭제) | medium |
| 일반 버튼, 목록 줄, 링크 | 없음 |

## 대체 규칙 (`fallbacks`)

* **동작 줄이기**(기기 설정): 이동·크기·흐림을 빼고 투명도 변화만 남깁니다(`reduceMotion: opacity-only`). `focus.ring`은 바로 바뀝니다(`instant`).
* **투명도 줄이기**: 반투명 탭 바를 불투명 `bg.sheet`로 바꿉니다.
* **저사양 기기**: 흐림은 대상 자신에게만 겁니다(배경 흐림 아님). 프레임이 떨어지면 패턴의 `lowEnd` 값대로 흐림을 뺍니다. app은 저사양 Android에서 한 번 확인합니다.

## Flutter 구현 메모 (참고)

명세는 위젯 이름에 묶이지 않습니다. 아래는 1차 구현(Material 3 위에 토큰을 입힘)의 힌트입니다.

* `press.ink`: Material `InkWell`의 splash를 끄고(`splashFactory: NoSplash`), 누른 좌표를 받아 `RadialGradient`로 칠한 층을 `ClipRRect` 안에 둡니다. 흐림 필터는 쓰지 않습니다. 그라데이션 반지름은 가장 먼 모서리 거리 ÷ 0.7, 색 멈춤은 `[진한 색, 진한 색, 투명]`에 `[0, 0.7, 1]`입니다. 떼는 순간의 자람 값에서 멈추지 않고 다 자란 크기까지 이어 갑니다.
* `appear.seep`·`disappear.seep`·`seal.*`: 대상 자신을 `ImageFiltered(ImageFilter.blur)` + `Opacity`(또는 `FadeTransition`)로 감쌉니다. 배경 흐림(`BackdropFilter`)이 아닙니다.
* `seal.stamp`: `TweenSequence` 두 구간(가중치 35 / 65), 구간마다 `Cubic` 곡선.
* `select.seep-slide`: 이전·새 표시를 따로 그려, 새 표시는 `SlideTransition`(거리의 15%) + 흐림 + 크기, 이전 표시는 제자리 흐림 + 크기 + 투명도.
* `page.push`: 앱의 `PageRoute` 전환 하나(`PageTransitionsTheme`에 두 플랫폼 같은 builder)로, 새 화면을 `SlideTransition`(24px) + `FadeTransition`으로 감쌉니다. 이전 화면에는 secondary 애니메이션을 주지 않습니다. iOS 가장자리 밀어 뒤로 가기 제스처는 남깁니다.
* `tab.switch`: 탭 갈래 화면(`StatefulShellRoute` 같은 탭 셸)에서 앞 화면과 새 화면을 겹쳐 두고 각각 `FadeTransition`(앞 1→0, 새 0→1, 200ms standard)으로 감쌉니다. 탭 바는 셸 바깥이라 움직이지 않습니다. 각 탭의 화면 상태(스크롤 위치 등)는 지금처럼 유지합니다.
* `sheet.stack`: 새 시트는 새 route. 아래 층은 `Transform.scale`·`Transform.translate`와 덮개 투명도만 바꿉니다(높이를 움직이지 않음).
* 반투명 탭 바: `BackdropFilter`(탭 바 뒤 흐림)는 이 한 곳에만 씁니다.
* 동작 줄이기: `MediaQuery.disableAnimations`, 투명도 줄이기: 플랫폼 접근성 설정(iOS `UIAccessibility.isReduceTransparencyEnabled`).
* 햅틱: `HapticFeedback.selectionClick` / `lightImpact` / `mediumImpact`.

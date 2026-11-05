# DS1 1단계: 디자인 시스템 규칙 재정비 (#801, D107)

* 날짜: 2026-11-05, design 세션
* 요청: #801(DS1 디자인 시스템 재정비) 1단계와 지휘 범위 보충 코멘트(2026-11-05). 검수 대장 `docs/review/items.md` F-001~F-012
* 입력: 레퍼런스 조사 `docs/research/2026-11-05-design-system-references.md`(아래 "참고 n행"은 이 파일의 줄 번호), 전수 점검 결과 [`2026-11-05-ds1-audit.md`](2026-11-05-ds1-audit.md), 비공개 기록 `review/inbox/2026-11-05-회차1.md`(내용을 옮겨 적지 않음)
* 고른 안: 규칙 견본 `design-ds1-rules`(`artifacts/2026-11-05-ds1-rules.html`). Q1 ①, Q2 ①, Q3 ②, Q4 ②, Q5 ①, Q6 ①, 정한 값 A~G 확인(C, F는 받은 의견으로 고침)
* 결과: 토큰 1.3.0(추가만), 컴포넌트 계약 4.0.0, 결정 V56~V68
* 범위: 컴포넌트와 요소 단위 규칙까지만입니다. 어느 화면에 무엇을 어떻게 놓을지는 2단계(지휘 IA 후보 뒤)에서 정합니다. 화면 요소를 더하거나 빼지 않습니다.

## 0. 공통 원칙

* 규칙은 테스트로 지킵니다. 영역마다 `tools/test_components.py`에 검사를 더해, 명세가 규칙을 벗어나면 CI가 실패합니다(F-001 "지켜지는지").
* 토큰은 freeze라 추가만 합니다. 기존 값(`space.20` 포함)은 바꾸지 않습니다.
* 다른 시스템의 자산은 가져오지 않고 규칙만 참고합니다(참고 5행).

## 1. 간격 체계 (F-002) → V56

**지금 규칙.** 간격 토큰 `space.2/4/8/12/16/20/24/32/48`과 화면 좌우 `space.20`(V26). 언제 어느 단계를 쓰는지는 정해 두지 않았습니다.

**지켜지는지.** 직접 쓴 px 간격 25곳, 이유 없이 다른 위아래 여백 2곳(Task 1 점검 결과 "문제"). 도구가 요소 묶음(`elements.json`)도 보게 넓히자 3곳(`mark.underline-grow` 간격 2, `lock.veil` 제목 4와 본문 6)이 더 나왔고, `term` 안쪽 3도 같이 고쳤습니다. 고친 뒤 점검 결과 파일은 "없음"이고, 고치기 전 목록은 아래 표입니다.

**새 규칙.**
* 간격은 토큰 단계만 씁니다. 직접 쓴 px 간격은 0 말고는 없습니다.
* 쓰임표(`components/README.md` "공통 규칙"에 둠):

| 토큰 | 쓰는 곳 |
| --- | --- |
| `space.2` | 한 덩어리 안 두 줄 사이(표 칸 두 줄 묶음, 섹션 제목과 설명), 글자와 붙은 꺾쇠 |
| `space.4` | 칩, 배지 안 아이콘과 글자 사이, 표 칸 안 줄 사이 |
| `space.8` | 같은 묶음 안 요소 사이(칩 줄, 두 버튼, 제목과 본문), 이름과 값 사이, 제목 줄의 아이콘과 글자 사이 |
| `space.12` | 섹션 제목과 내용 사이, 칩과 배지 좌우 안쪽, 목록 줄 앞 아이콘과 글자 사이, 같은 섹션 안 카드 사이 |
| `space.16` | 카드와 목록 줄의 안쪽 |
| `space.20` | 화면 좌우 여백, 버튼 좌우 안쪽, 큰 카드(질문 카드, 상품 카드) 안쪽 |
| `space.24` | 시트 좌우와 아래, 확인 창 안쪽(사방), 본문과 아래 버튼 사이, 목록 묶음 카드 사이, 시트 안 구역 사이 |
| `space.32` | 섹션 사이 |
| `space.48` | 화면 맨 아래 스크롤 여유, 빈 화면 위아래 |

* `space.20`은 표의 자리에서만 씁니다. 최종 리뷰에서 표와 다르던 설정 묶음 카드 사이, 근거 시트 구역 사이, 상품 카드 구매 버튼 위, 오류 상태 다시 시도 위의 20은 24로 옮겼습니다.
* 묶음 안 간격은 묶음 사이 간격보다 두 단계 이상 작게 둡니다(근접으로 묶임, 참고 27행 M3 implicit grouping).
* 위아래 여백은 같게 둡니다. 다르게 둘 때는 그 부품에 `note`로 이유를 적습니다(F-010 확인 창 위아래 다름의 재발 방지).
* 화면 좌우 여백은 `space.20` 그대로입니다. 레퍼런스는 16(참고 25, 27행)이지만, 이 앱은 긴 문장을 읽는 화면이 중심이고 M3도 넉넉한 배치가 차분하다고 봅니다(참고 27행). 그래서 V26 값을 유지합니다(개정 아님).

**25곳 옮김.**

| 부품 | 지금 | 새 값 | 이유 |
| --- | --- | --- | --- |
| `primary-button` `dots.gap` | 6 | `space.4` | 점 세 개는 한 덩어리 |
| `day-cell` `numberBox.marginTop` | 6 | `space.4` | 칸 높이는 그대로(V36), 숫자가 2px 위로 |
| `diary-row` `weekday.marginTop` | 4 | `space.4` | 같은 값을 토큰으로 |
| `diary-row` `entry.divider.gap` | 3 | 키 이름 `dashGap`(값 3 그대로) | 간격이 아니라 점선 무늬. `dash`도 `dashLength`로 |
| `draft-indicator` `container.gap` | 4 | `space.4` | 같은 값 |
| `tag-chip` `chip.paddingX` | 10 | `space.12` | 칩, 배지 좌우 안쪽 |
| `dialog` `container.marginX` | 28 | `space.24` | §7.2 |
| `segmented` `track.padding` | 3 | `space.4` | 트랙 높이 그대로, 칸이 1px씩 작아짐 |
| `saju-pillars` `columns.gap` | 6 | `space.8` | 기둥은 같은 묶음 안 요소 |
| `saju-pillars` `branch.marginTop` | 4 | `space.4` | 같은 값 |
| `manse-table` `hiddenStems.tenGod.marginTop` | 2 | `space.2` | 같은 값 |
| `daeun-table` `daeun.pillar.gap`, `stemTenGod.marginBottom`, `branchTenGod.marginTop`, `seun.stemTenGod.marginBottom` | 4 | `space.4` | 같은 값 |
| `daeun-table` `daeun.twelveStage.marginTop` | 2 | `space.2` | 같은 값 |
| `sentence-block` `locked.open.chevron.gap`, `depth-link` `chevron.gap`, `lockPanel.pass.chevron.gap` | 2 | `space.2` | 글자와 붙은 꺾쇠 |
| `term-token` `inline.chip.paddingX` | 3 | `space.4` | 문장 안 칩. 2는 글자가 테두리에 닿음 |
| `term-token` `label.chip.paddingX` | 4 | `space.4` | 같은 값 |
| `depth-link` `lockPanel.head.gap` | 6 | `space.8` | 제목 줄의 아이콘과 글자 |
| `depth-link` `lockPanel.reward.marginTop` | 6 | `space.8` | 같은 묶음 안 요소 |
| `day-character` `badge.paddingX` | 10 | `space.12` | 칩, 배지 좌우 안쪽 |
| `lucky-card` `chip.gap` | 6 | `space.4` | 칩 안 아이콘과 글자 |
| `mark.underline-grow` `gap`, `lock.veil` `title.gap` | 2, 4 | `space.2`, `space.4` | 같은 값 |
| `lock.veil` `body.marginTop` | 6 | `space.8` | 제목과 본문 |
| `term` `padding.x` | 3 | `space.4` | `term-token` `inline`과 같게 |

**비대칭 2곳.**
* `diary-row` `entries.head`(위 16, 아래 4): 머리는 아래 줄의 이름이라 아래 내용에 붙여야 묶여 보입니다. 그대로 두고 `note`로 이유를 적습니다.
* `depth-link` `lockPanel`(위 16, 아래 24): 위아래 `space.24`로 맞춥니다. 아래 고정 패널이라 안전 영역은 그 밖에 더합니다.

## 2. 아이콘 (F-003) → V57

**지금 규칙.** Phosphor, 미선택 Light, 선택 Regular, Fill은 경고 표시(V15, V18). 크기는 쓰임 이름 넷(`tab` 24, `bar` 24, `inline` 16, `state` 28). 세트에 없는 것은 직접 그림. 경고 표시는 글자 크기의 0.707배(대문자 높이).

**지켜지는지.** 아이콘이 옆 글자보다 작아 보임. 경고 표시가 대문자 높이라 한글보다 작음. 직접 그린 아이콘을 실제로 쓰는 곳은 없음.

**새 규칙.**
* 크기는 네 단계 `size.icon.16/20/24/28`(새 토큰)입니다. 모든 아이콘 부품의 `size`는 이 토큰을 가리킵니다.
* 글자 옆 아이콘은 **그림 높이가 옆 한글 높이 이상이 되는 가장 작은 단계**입니다. 실측: Phosphor 그림은 상자의 약 0.81(208/256), Pretendard 한글은 글자 크기의 0.861~0.882배입니다. 그래서 14px 이하 글자 옆 16, 15~18px 옆 20, 19~22px 옆 24, 23px 이상 옆 28입니다(경계는 단계 × 0.81 ÷ 0.882).
* 글자와 한 줄에 있지 않은 아이콘은 줄 높이와 터치 영역에 맞춥니다: 목록 줄 앞 20, 탭 바와 위 막대 24, 빈 화면 28.
* 굵기는 옆 글자 굵기와 짝입니다(참고 34, 97행): 400~500 글자 옆 Light, 600 이상 옆 Regular. 글자 없는 아이콘은 V15대로 미선택 Light, 선택 Regular. Fill은 경고 표시에만.
* 기기 글자가 커지면: 글자 옆 아이콘은 기본 글자 크기로 단계를 고르고 그리는 크기에 기기 배율을 곱합니다(그 칸의 `textScaleMax`까지, V30과 같은 원리). 탭 바, 위 막대, 목록 줄 앞, 빈 화면, 키보드 내리기처럼 글자와 한 줄에 있지 않은 아이콘은 배율을 따르지 않습니다.
* 직접 그린 아이콘은 쓰지 않습니다. 세트에 없는 뜻은 글자로 씁니다. `elements.json` `icon.custom`을 지우고, 명세의 아이콘 이름은 Phosphor 2.1.2 이름 목록(`tools/phosphor_names.txt`)에 있어야 합니다.
* 경고 표시(`mark.caution`)는 0.707배 대신 위 단계 규칙을 따릅니다. 모양(`warning-circle` Fill, 글자색)은 V18 그대로입니다.

## 3. 목록 줄과 구분선 (F-004) → V58

**지금 규칙.** `settings-row` 구분선은 왼쪽만 16 들인 1px. 꺾쇠 16은 이동과 값 줄에 있음. 앞 아이콘 없음.

**새 규칙.**
* 구분선은 새 요소 `list.divider`입니다. 굵기 `border.width.hairline`(0.5px, 새 토큰), 색 `color.line`, 묶음 카드 좌우에서 같은 거리 `space.16`(줄 안쪽 여백)만큼 들입니다. 앞 아이콘이 있어도 아이콘 아래까지 긋습니다(사용자 의견). 같은 묶음 안 줄 사이에만 두고, 묶음과 묶음은 선 없이 간격으로 나눕니다(참고 40, 87행). 첫 줄 위와 끝 줄 아래에는 없습니다.
* 모든 구분선 부품은 `list.divider`를 `uses`합니다. 예외: 같은 날 일기 사이 점선(`diary-row` `entry.divider`, V42)은 흐름 줄과 짝인 별도 표시라 그대로 둡니다.
* 꺾쇠는 누르면 다른 화면이나 시트로 들어가는 줄에만 둡니다. 값 줄(`settings-row` 값이 있는 줄)도 시트나 화면을 열면 꺾쇠가 있습니다.
* 고르면 바로 값이 바뀌는 줄(언어 고르기 같은 하나 고르기)은 꺾쇠 없이 고른 줄 끝에 체크 표시(`check`, Regular 20, `color.action.primary`)를 둡니다. 줄 전체를 누릅니다.
* `settings-row`에 선택 부품 `leading`(아이콘 20 Light, `color.text.primary`, 글자와 사이 `space.12`)을 더합니다. 설정 메뉴 아이콘(`bell`, `prohibit`, `translate`, `user-circle`, `globe-hemisphere-east`, `key`, `file-text`, `chat-circle-text`, `sign-out`, `trash`)은 견본 C 표가 기준이고, 메뉴 순서와 묶음은 IA를 따릅니다. 로그아웃과 계정 삭제는 자기 아이콘(Regular)과 600 글자로 구분합니다. 아이콘 표는 `settings-row` `parts.leading.icons`(줄 이름 ARB 키 → 이름)입니다.
* 고르기 줄은 `settings-row`의 새 변형 `select`입니다. 언어 고르기 시트가 `settings-row`로 그려지기 때문입니다(IA `settings`의 컴포넌트).
* 앞 아이콘만큼 이름 자리가 줄어 `lengths.py` `settings-row` 이름 폭을 다시 잽니다. 이름만 있는 줄은 272 − 32 = 240, 이름과 값이 나누는 줄은 아이콘을 뺀 나머지를 반씩 (272 − 8 − 32) ÷ 2 = 116입니다. 지금 원고는 모두 새 상한 안입니다(writing에는 상한 변경을 알림, §8).

## 4. 섹션 제목과 묶음 (F-005, Q3 ②) → V59

**새 규칙.**
* 새 요소 `section.header`: 부품 `title`(필수, `type.label.lg` 600, `color.text.primary`), `description`(선택, `type.caption.md`, `color.text.secondary`, 제목 아래 `space.2`). 오른쪽 더 보기 자리는 두지 않습니다.
* 제목과 내용 사이 `space.12`, 섹션 사이 `space.32`.
* 묶음의 기본은 간격(근접)입니다. 목록 줄이 이어지는 묶음은 카드(`color.bg.sheet`, `radius.lg`)로 묶을 수 있습니다(참고 82행 명시적 묶음). 어느 화면에 섹션 제목과 카드를 둘지는 2단계입니다.

## 5. 버튼 쌍과 눌림 (F-006, F-007, Q1 ①, Q2 ①) → V60, V61

**버튼 쌍(V60).**
* 새 요소 `button.pair`: 세로로 쌓고 주 버튼(`filled`)이 위, 보조(`quiet`)가 아래, 사이 `space.8`, 두 버튼 같은 높이 52, 같은 폭(전체 폭). 가로 배치는 쓰지 않습니다(확인 창은 §7.2).
* `primary-button` `quiet` 높이 44 → 52. 버튼 위계는 크기가 아니라 모양으로 구분합니다(참고 51, 90행).

**눌림(V61, V14 보충).**
* 눌림 패턴은 `press.ink` 하나입니다.
* 먹 번짐의 뜻을 분명히 합니다. 다 자랐을 때 **진한 영역이 누른 자리에서 가장 먼 모서리까지 닿고**, 부드러운 테는 그 바깥(요소 밖, 잘려서 안 보임)에 있습니다. 반지름은 가장 먼 모서리 거리 ÷ 0.7이고 0~0.7은 같은 진하기, 0.7~1은 흐려집니다. 지금 app은 가장 먼 모서리 거리를 바깥 반지름으로 써서 가장자리 30%가 흐려 비어 보입니다. 명세 문장("radius farthest-corner, edge soft")이 두 가지로 읽혀 생긴 차이라 app 버그가 아니라 명세 보충입니다.
* 다 자라기 전에 떼도 끝까지 자라며 사라집니다(사라짐 동안 반지름이 다 자란 크기 × 1.15까지).
* 눌림 표시는 **누른 컴포넌트 자신의 경계** 안에서만 보입니다. 줄 안의 배지나 칩을 누르면 그 배지, 칩 안에만 번지고 줄 전체로 번지지 않습니다(F-007). 줄과 그 안 요소가 둘 다 누를 수 있으면 안쪽 요소가 눌림을 가져갑니다.

## 6. 설명 열기와 근거 진입점 (F-008, F-003, Q4 ②, Q5 ①) → V62, V63

**설명 열기(V62).**
* 칩, 배지, 용어를 눌러 짧은 설명을 여는 곳은 새 요소 `explain.sheet`입니다. 내용 높이만큼의 작은 시트(`sheet` 규칙 §7.1, 핸들 있음, 바깥 누르기와 끌어 내리기로 닫힘)이고, 제목은 그 항목의 이름, 본문은 설명 문장입니다.
* 설명은 화면의 배치 안에 끼어들지 않습니다. 열림 상태가 아래 내용을 미는 배치 값(`insert`)을 쓰지 않습니다(F-008 content shift).
* 연 칩에는 V52처럼 테두리가 남고, 닫으면 사라집니다.
* 어느 화면의 어느 칩이 이 시트를 여는지, 시트 제목 문구를 어느 슬롯에서 가져올지는 IA가 정합니다. 지휘가 같은 결정을 IA로 내릴 예정입니다(#801).

**근거 진입점(V63).**
* "근거 보기" 글자 링크를 아이콘 버튼 하나로 바꿉니다: `book-open-text` Regular, `color.action.primary`, `size.icon.20`, 터치 영역 48. `depth-link`의 근거 변형 `inline-end`(문장 끝)와 `block`(문단 아래)이 모두 이 모양이고 글자 `label` 부품이 없습니다. 다른 페이지로 가는 `navigate`는 글자 링크 그대로입니다(V32).
* 문장 끝 아이콘은 문장 마지막 글자와 줄바꿈 없이 붙습니다(붙는 공백 하나, 아이콘이 다음 줄로 혼자 넘어가지 않음). 이 규칙은 `depth-link` 안에 두고 요소 `link.inline-nowrap`은 지웁니다.
* 줄 배치 폭은 그림 20이고 터치 영역 48은 배치 밖으로 넓힙니다(이웃 줄과 겹쳐도 됨). 글자 수 상한도 20으로 잽니다.
* 스크린리더는 역할 `button`, 이름은 "항목 이름 + 근거 보기" 틀(`ui.depth.evidence_link`에 항목 이름 자리)입니다. 항목 이름은 `inline-end`면 앞 문장이 속한 항목(배지 글자), `block`이면 시트 제목(용어 이름)이나 구역 이름입니다. 누르면 근거 시트가 열린다고 알립니다. 한 화면에 진입점이 여럿이어도 구분됩니다.

## 7. 시트, 확인 창, 로딩, 화면 전환, 키보드 (F-009~F-012, Q6 ①)

### 7.1 바텀시트 (F-009) → V64
* 좌우와 아래 안쪽 `space.24`(지금 20). 시트 모서리 `radius.xl`(28)이라 20이면 글이 모서리에 붙어 보입니다.
* 맨 위에 높이 24의 핸들 자리, 그 가운데 36×4 핸들(참고 56행). 핸들 자리 전체가 끌기 영역이고 터치 높이 44입니다. 제목은 핸들 자리 아래 `space.8`.
* 핸들이나 맨 위까지 스크롤된 내용을 끌어 내리면 손가락을 따라 내려가고, 높이의 25% 넘게 내리거나 빠르게 튕기면 닫힙니다. 아니면 제자리로 돌아옵니다. 입력이 있는 시트는 끌어 닫기 전에 쓴 내용을 잃지 않게 확인합니다(참고 59, 93행).

### 7.2 확인 창 (F-010) → V65
* 안쪽 여백은 사방 `space.24`, 버튼도 그 안이라 위아래가 같아 보입니다. 제목과 본문 사이 `space.8`, 본문과 버튼 사이 `space.24`.
* 버튼은 같은 폭 두 개, 높이 44, 사이 `space.8`, 버튼 좌우 안쪽 `space.12`(두 버튼 공통). 글자 수 상한은 가로 둘 기준(104px)입니다. 지금의 끝 정렬 글자 버튼(`actions` `align: end`)을 바꿉니다. 취소는 옅은 바탕(`color.chip.bg`, 글자 `color.text.primary`), 실행은 `primary-button` `filled` 모양이고, 되돌릴 수 없는 동작(`destructive`)은 실행 버튼을 `primary-button` `destructive` 바탕(본문 글자색)으로 둡니다. 경고 표시는 제목에만 두고 버튼 글자 앞에는 두지 않습니다(한 창에 하나, V18). 확인 창은 폭이 정해진 작은 상자라 §5의 세로 쌓기가 아니라 가로 둘입니다. en, ja 글이 넘치면 세로로 쌓고 실행이 위입니다(참고 64, 91행).
* 경고 표시는 §2 규칙대로 제목 글자(`type.subtitle` 16) 옆 20.
* 화면 좌우와 `space.24` 띄웁니다(지금 28).

### 7.3 로딩 (F-011) → V66
* skeleton은 **요소마다** 만듭니다. 화면을 이루는 컴포넌트와 요소(일기 줄, 목록 줄, 칩, 카드, 섹션 제목)가 각자 자기 skeleton(`loading` 상태의 모양)을 가지고, 실제 요소의 자리, 크기, 반경, 안쪽 여백을 그대로 따릅니다. 글줄 자리는 글줄 높이의 60%, 마지막 줄 60% 폭입니다.
* 화면의 skeleton은 그 화면이 쓰는 요소 skeleton을 그 화면의 실제 배치(화면 좌우 여백, 섹션 제목, 섹션 사이 간격)대로 놓은 것입니다. 그래서 화면마다 조합이 다릅니다. 예: 일기 목록은 달 머리와 `diary-row` skeleton(날짜 열, 카드 안 배지, 미리보기 두 줄, 태그 칩)을 쌓고, 오늘은 배지, 문장 카드, 섹션 제목과 칩 줄을 놓습니다.
* 여백 없는 글줄만 쌓은 공용 skeleton은 쓰지 않습니다. 300ms 안에 끝나는 불러오기에는 보이지 않습니다(지금 규칙).

### 7.4 화면 전환 (F-012, Q6 ①) → V67
* 새 패턴 `page.push`: 새 화면이 오른쪽에서 24px(`motion.offset.page`) 밀려 들어오며 투명도 0 → 1, `motion.duration.page`(320ms), `motion.easing.page`(enter 곡선과 같은 값). 뒤 화면은 움직이지 않습니다. 뒤로 가기는 거꾸로입니다.
* 동작 줄이기 설정에서는 이동 없이 투명도만 바뀝니다.
* 탭 사이 이동과 시트는 이 패턴을 쓰지 않습니다(V17 시트 규칙 그대로). `depth-link` `navigate`의 `platform-default`는 `page.push`로 바꿉니다.

### 7.5 키보드 내리기 → V68
* 입력칸에 초점이 있는 동안 키보드 바로 위 오른쪽(`space.12` 띄움)에 44 원형 버튼(`color.bg.sheet`, `shadow.raised`, `caret-down` Regular 20)을 띄웁니다. 누르면 키보드가 내려갑니다. `text-field` 포커스 상태의 부품 `keyboardDismiss`로 둡니다. 동작 구현은 app #796입니다.
* 스크린리더 이름은 새 writing 슬롯입니다(§9).

## 8. 계약 영향

**토큰 1.3.0(추가만).**

| 토큰 | 값 |
| --- | --- |
| `border.width.hairline` | 0.5px |
| `size.icon.16`, `size.icon.20`, `size.icon.24`, `size.icon.28` | 16, 20, 24, 28px |
| `motion.duration.page` | 320ms |
| `motion.easing.page` | cubic-bezier(0.2, 0.8, 0.2, 1) |
| `motion.offset.page` | 24px |

**컴포넌트 계약 4.0.0(지우는 것이 있어 주 버전).**
* 지움: 요소 `link.inline-nowrap`, `icon.custom`, `icon.sizes`(쓰임 이름 넷, 크기 토큰으로 대체), `mark.caution.size`의 0.707배, `depth-link` 근거 변형의 `label` 부품, `diary-row` `entry.divider`의 `dash`·`gap` 키 이름(`dashLength`·`dashGap`으로).
* 더함: 요소 `list.divider`, `section.header`, `button.pair`, `explain.sheet`, 패턴 `page.push`, `settings-row` `leading`, 고르기 줄 체크 표시, `text-field` `keyboardDismiss`, 모든 컴포넌트의 `loading` skeleton 모양.
* 바뀜: 간격 25곳(§1), `quiet` 높이, `sheet` 여백과 핸들, `dialog` 여백과 버튼, `press.ink` 반지름과 범위.

**writing.** 근거 보기 키를 "항목 이름 + 근거 보기" 접근성 이름 틀로(V63), 설정 줄 이름 상한(V58), 키보드 내리기 접근성 이름 새 슬롯 `ui.keyboard.dismiss`(V68), 시트와 확인 창 폭이 바뀐 자리의 상한(`lengths.md` 4.0.0, ja `accountDeleteDeleteConfirm` 줄이기): #807.

**app.** 4.0.0과 토큰 1.3.0 따라잡기 요청 #808. `press.ink`는 진한 영역 반지름과 떼었을 때 끝까지 자라기(V61)를 맞춥니다.

## 9. 결정

V56~V68은 `decisions.md`에 있습니다. 개정하는 기존 행: V14(눌림 보충, V61), V15(직접 그림 삭제와 굵기 짝, V57), V18(경고 표시 크기, V57), V20(설명 스밈과 근거 보기 글자, V62·V63), V26(시트 안쪽 여백, V64. 화면 좌우 20은 유지), V29(`depth-link` 근거 링크는 아이콘, V63. 잠김 열기와 `pass`는 그대로), V32(`navigate` 전환, V67).

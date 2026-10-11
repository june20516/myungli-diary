# sentence: 문장 (`sentence.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.5, 결정 V16·V20·V21
* 시안: `design-v2-today`(근거 보기 0-나, 하트 아래), `design-v2-tab-seal`(도장 반응), `design-v2-rest`(풀이 시트 잠김)

문장은 이 앱의 본체입니다. 문장 컴포넌트는 글꼴·줄바꿈·덧붙는 링크와 반응만 정하고, 문구는 writing(UI 슬롯)과 server(콘텐츠)가 정합니다.

## sentence-block

* 쓰는 화면: welcome, preview, login, today, explain-sheet, evidence-sheet, diary-edit, diary-view, tag-diary, my-saju, calc-basis, account-delete, force-update
* 변형 `card`(`type.sentence.card` 17px) / `body`(`type.sentence.body` 15px) / `preview`(일기 목록, 14.5px 두 줄 말줄임).
* 한국어는 어절 단위 줄바꿈(keep-all), 일본어는 글자 단위 + 금칙 처리.
* 호칭은 문장 안의 자리로만 들어갑니다. 굵게 하거나 색을 바꾸지 않습니다.

## term-token

* 쓰는 화면: today, day-sheet, tag-diary, my-saju, saju-chart
* `term` 요소: `term.bg`/`term.fg`, `radius.xs`, 굵게 하지 않음(결정 V0).
* 변형 `inline`(문장 안, 글자 스타일 그대로) / `label`(표 행 머리·십성 줄, `type.caption.md`).
* 누르면 풀이 시트(explain-sheet)가 열립니다: 제목 + 한자 → 일반 뜻 → "내 사주에서는" 상자(`status.bg`).
* **잠김 변형**(`states.locked`): 일반 뜻은 열어 두고 "내 사주에서는" 상자만 흐리게(6px, 투명도 0.5) + 자물쇠 + 열기 안내 + 조용한 버튼. 잠긴 자리에는 실제 내용을 내려받지 않고 자리 채우기 글을 흐리게 그립니다. 무엇을 잠글지는 M0에서 정합니다(Issue #32).
* 터치 영역: 글자 높이가 작아도 줄 높이까지 위아래로 넓혀 44px를 맞춥니다.

## depth-link

* 쓰는 화면: today, explain-sheet, my-saju
* "근거 보기 ›", `action.primary` `type.label.lg`.
* `inline-end`: 이유 문장 끝에 붙습니다. `link.inline-nowrap`으로 링크 전체가 한 덩어리라, 줄 끝에 다 들어가지 않으면 통째로 다음 줄로 갑니다. "근거 / 보기"처럼 갈라지지 않습니다(시안 비교에서 고른 0-나).
* `block`: 문단 아래 따로 놓입니다(나 탭).
* 누르면 한 단계 깊은 시트가 열립니다. 이미 시트 안이면 `sheet.stack`으로 쌓입니다.

## reaction-button

* 쓰는 화면: today
* 하트 Light(`text.secondary`), 터치 44px. 문장 아래 오른쪽에 홀로 둡니다(근거 보기와 다른 줄).
* 누르면 `seal` fill 34px가 `seal.stamp`로 찍히고 하트가 Regular 흰색으로 바뀝니다. 햅틱 light.
* 다시 누르면 `seal.erase`, 햅틱 없음.

# 문장 조각의 용어 표시와 근거 잠금 슬롯 설계 (컴포넌트 계약 2.1.0)

* 작업 단위: design
* 마일스톤: V2 후속 (선행 컴포넌트 2.0.0, 후행 A1 UI 구현)
* 입력: Issue #68(root → design, 문장 조각의 `term` 표시), IA v1 추가분(PR #70: `evidence-sheet` ui 슬롯 7개와 `toast`, `saju-chart.yongsin.open`과 `sentence-block`)
* 기준 문서: [V2 spec](2026-10-11-components-design.md), [근거 잠금 spec](2026-10-11-depth-lock-lengths-design.md), `docs/decisions.md` D60, server spec §6.4·결정 S9·S14, REST 계약 1.0.0-draft `RenderedText`·`Segment`, IA 계약 v1 [`docs/ia/screens.json`](../../../ia/screens.json)
* 계약: 컴포넌트 명세 2.0.0 → **2.1.0**(추가만). 토큰 1.1.0은 그대로입니다.

## 1. 목적과 완료 기준

server는 콘텐츠 문장을 조각 배열로 보냅니다(S9).

```json
{"segments": [{"text": "오늘은 "}, {"text": "편관", "term": "편관"}, {"text": "의 기운이 강한 날이에요."}]}
```

app이 `sentence-block` 안에서 `term` 조각을 명세만 보고 그릴 수 있게 합니다. 같은 브랜치에서 IA가 정한 근거 잠금 ui 슬롯을 명세의 자리에 적습니다. 두 일 모두 `sentence-block`을 고치므로 한 버전(2.1.0)으로 묶습니다.

끝나는 조건은 다음과 같습니다.

1. 컴포넌트 명세 2.1.0
   * `sentence-block`에 조각 그리기 규칙(§2)과 `locked` "열기" 슬롯(§3)
   * `depth-link` 근거 시트에 구역 제목·해제 실패 toast·접근성 문구 슬롯(§3)
2. 검사기 `tools/components.py`와 pytest 통과
3. 결정 V28, `CLAUDE.md` 갱신
4. Issue: #68 답, app 앞 2.1.0 notice(§5)

## 2. `term` 조각 표시 (결정 V28)

### 2.1. 원칙: 칩은 누를 수 있다는 표시

용어 칩(`term` 요소: `term.bg`·`term.fg`·`radius.xs`)은 "누르면 풀이를 본다"는 표시입니다. 그래서 **칩은 누를 수 있는 곳에서만 그립니다.**

| 화면 | `term` 조각 |
| --- | --- |
| IA `components`에 `term-token`이 있는 화면: today, day-sheet, tag-diary, my-saju, saju-chart | `term-token` `inline`. 누르면 풀이 시트 |
| 그 밖의 `sentence-block` 화면: explain-sheet, evidence-sheet, `preview` 화면(온보딩 미리보기), diary-edit, diary-view 등 | 일반 글자. 앞뒤 조각과 같은 스타일이고 누를 수 없음 |
| 공유 이미지(`share-image`) | 일반 글자. 이미지는 누를 수 없음 |
| 카드 전체가 버튼인 곳(`diary-row`) 안 | 일반 글자(§2.6) |

* 따로 변형을 만들지 않습니다. 문장 안 용어는 이미 `term-token` `inline`(글자 스타일 그대로, 좌우 3px)입니다.
* 근거: IA가 화면별로 `term-token`을 둔 곳이 곧 풀이로 들어갈 수 있는 곳입니다. 풀이 시트(explain)와 근거 시트(evidence)는 그보다 깊은 단계입니다. 그 안의 용어까지 누를 수 있게 하면 시트가 끝없이 쌓이고, 깊이 순서(surface → explain → evidence)가 돌아 버립니다.
* 같은 문장이 화면에 따라 다르게 보일 수 있습니다. 예를 들어 질문 카드 문장은 today에서는 칩이 있고 diary-edit에서는 일반 글자입니다. 칩이 늘 눌린다는 약속을 지키기 위해 이 차이를 받아들입니다.

고르지 않은 안:

* 어디서나 칩, 어디서나 누름: 여러 화면의 IA에 `term-token`을 더해야 합니다. 그러면 시트 안에서 시트가 계속 쌓입니다.
* 어디서나 칩, `term-token`이 없는 화면에서는 누를 수 없음: 눌리지 않는 칩이 생겨 표시가 거짓이 됩니다.

### 2.2. 조각 이어 붙이기

* 조각은 순서대로 한 문단으로 이어 붙입니다. 조각 경계에서 줄을 바꾸거나 공백을 넣지 않습니다. 공백은 `text` 안에 있는 것만 씁니다.
* `term`이 없는 조각과 `term-token`이 없는 화면의 `term` 조각은 문장 글자 그대로입니다.
* 호칭 자리(`honorific`)와 문장 끝 `depth-link` `inline-end`의 규칙은 바뀌지 않습니다.

### 2.3. 줄바꿈

* **한국어:** 용어 안에서 끊지 않습니다. 용어와 공백 없이 붙은 앞뒤 글자(조사 "의", "이" 등)도 한 덩어리입니다. keep-all의 어절 단위와 같은 결과입니다. 그래서 "편관 / 의"처럼 칩과 조사가 갈라지지 않습니다.
* **일본어:** 용어 안에서 끊지 않습니다. 용어 앞뒤에서는 글자 단위 줄바꿈과 금칙 처리를 그대로 따릅니다.
* 용어 하나가 한 줄보다 길 때만 용어 안에서 끊습니다. MVP 용어에는 그런 경우가 없지만, 넘치지 않게 하는 안전장치입니다.
* 구현 방법(텍스트 배경 span, 위젯 span, joiner 문자)은 app이 고릅니다. 명세는 결과만 정합니다.

### 2.4. 접근성

* `term-token`이 있는 화면에서는 지금 규칙 그대로입니다. 용어마다 따로 초점을 받고, 라벨은 "화면에 보이는 `text` + '풀이 보기'"입니다. `term` 값은 풀이를 찾는 키일 뿐 읽지 않습니다.
* 일반 글자로 그린 `term` 조각은 따로 초점을 받지 않고 문장과 함께 읽힙니다.

### 2.5. 근거 잠금(D60)과의 관계

**바뀌는 것이 없습니다.**

* 잠긴 내용(판정 근거·원전·내 사주에서는·`saju-chart.yongsin.basis`)은 권한이 없으면 server가 응답에 담지 않습니다(S14). `lock.veil`은 글자가 없는 흐린 막대이므로 그 안에 `term` 조각이 없습니다.
* 풀이 시트는 무료입니다(D60 ①). 근거가 잠겨 있어도 `term-token`은 그대로 누를 수 있습니다.
* 열린 근거 시트 안의 `term` 조각은 §2.1에 따라 일반 글자입니다.

### 2.6. 다른 구성 요소와 누를 수 있는 카드 (최종 리뷰 반영)

* `sentence-block` 밖에서 콘텐츠 문장(`RenderedText`)을 그리는 `day-character` 이유 줄과 `lucky-card` 설명도 같은 규칙을 따릅니다(`"segments": "sentence-block"`). day-sheet가 칩 화면인 것은 이유 줄 때문입니다.
* 카드 전체가 버튼인 곳(지금은 `diary-row`) 안에서는 칩 화면이어도 일반 글자입니다(`insidePressable`). 누를 것 안에 누를 것을 두지 않고, 미리보기 말줄임이 칩을 자르지 않게 하려는 것입니다. 테스트가 `a11y.role`이 button이면서 `sentence-block`을 품은 컴포넌트를 찾아 이 목록과 맞춥니다.
* 문장 글자색이 상태로 바뀌어도(질문 카드 `after`의 `text.secondary`) 칩은 `term.bg`·`term.fg` 그대로입니다(`textColorChange`).
* `sentence-block` `locked` 라벨의 "구역 이름"은 사주 표에 그 줄의 이름 슬롯이 없어 지휘에 요청합니다(§5).

## 3. 근거 잠금 ui 슬롯 반영

2.0.0에서 "문구 슬롯은 지휘에 요청함"으로 남겨 둔 자리에 IA가 정한 슬롯 이름을 적습니다.

| IA 슬롯 | 명세 자리 |
| --- | --- |
| `saju-chart.yongsin.open` | `sentence-block` `states.locked.parts.open.slot` |
| `evidence-sheet.section.basis` | `depth-link` `parts.evidenceSheet.basisTitle.slot` |
| `evidence-sheet.section.source` | `depth-link` `parts.evidenceSheet.sourceTitle.slot` |
| `evidence-sheet.section.personal` | `depth-link` `parts.evidenceSheet.personalTitle.slot` |
| `evidence-sheet.unlock.failed` | `depth-link` `states.unlocking.parts.evidenceSheet.failedToast`(`toast`, `slot`) |
| `evidence-sheet.a11y.locked` | `depth-link` `a11y.lockedLabel` |
| `evidence-sheet.a11y.checking` | `depth-link` `a11y.unlockingLabel` |
| `evidence-sheet.a11y.unlocked` | `depth-link` `a11y.unlockedAnnouncement` |

* 구역 제목: 지금의 `sectionTitle`(글자 스타일 `type.label.md` `text.secondary`, 위 여백 `space.20`)은 공통 스타일로 그대로 둡니다. 구역마다 제목 구성 요소 셋(`basisTitle`·`sourceTitle`·`personalTitle`)을 더해 슬롯을 적습니다. `personalTitle`은 `personal`과 같은 조건(사주 표 계열에서 열었을 때만)으로만 나옵니다. **잠겼을 때도 또렷하게 보입니다.** `lock.veil`은 본문에만 씌웁니다(IA 슬롯 설명과 같음).
* 접근성 문구: 지금 `a11y`의 세 값은 문구를 적은 자리입니다. 이것을 `{ "slot": … }`로 바꾸면 값의 형태가 바뀌어 주 버전이 됩니다. 그래서 값은 그대로 두고 `lockedLabelSlot`·`unlockingLabelSlot`·`unlockedAnnouncementSlot` 세 필드를 더합니다. 지금의 문구는 설명으로 남습니다. `sentence-block` `a11y.lockedLabel`도 같은 방식으로 `lockedLabelSlot`을 더합니다(같은 "잠김" 문구).
* IA `saju-chart`의 컴포넌트 목록에 `sentence-block`이 들어갔으므로(#70), `saju.md`에서 "지휘에 요청했습니다" 문장을 지웁니다.

## 4. 명세 변경 요약

| 파일 | 변경 |
| --- | --- |
| `sentence.json` | `sentence-block`: `parts.segments`(조각 그리기 §2), `rules` 추가, `states.locked.parts.open.slot`, `a11y.lockedLabelSlot`, 버전 2.1.0. `depth-link`: `evidenceSheet.basisTitle`·`sourceTitle`·`personalTitle`, `states.unlocking.parts.evidenceSheet.failedToast`, `a11y.*Slot` 세 필드 |
| `sentence.md` | 위 내용 설명, 근거 줄에 이 spec과 V28 |
| `saju.md` | 지휘 요청 문장 삭제 |
| `README.md` | 계약 2.1.0, 버전 표에 한 줄 |
| `decisions.md` | V28 |
| 다른 `*.json` 10개 | `version` 2.1.0(검사기가 모든 파일의 버전을 계약 버전과 맞춰 봄) |
| `tools/components.py` | `CONTRACT_VERSION` 2.1.0 |

모두 구성 요소·필드 추가입니다. 이름이 바뀌거나 빠지는 것이 없으므로 부 버전입니다(README 버전 규칙).

## 5. Issue

* #68 답 코멘트: §2 요약과 명세 위치. 처리한 쪽이 닫는 규칙은 `docs/workflow.md` §5.2를 따릅니다.
* app 앞 notice(`kind:notice`, `to:app`): 컴포넌트 계약 2.1.0. 조각 그리기 규칙과 근거 잠금 슬롯이 들어갔음을 알립니다.
* 지휘 앞 request(`kind:request`, `to:root`): IA `saju-chart`에 용신 근거 줄의 이름 슬롯(잠김 접근성 라벨의 "구역 이름")을 요청합니다. 계약 목록의 버전 갱신은 notice를 보고 지휘가 합니다.

## 6. 검사

* `python3 docs/identity/design/tools/components.py`(저장소 루트): 새 `component` 참조(`term-token`, `toast`)가 IA 컴포넌트를 가리키는지, 필드 이름, README 버전
* `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`
* 새 토큰 참조는 없습니다(조각은 기존 `term-token` 스타일을 씀).

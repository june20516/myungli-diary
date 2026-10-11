# sentence: 문장 (`sentence.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.5, [근거 잠금 spec](../specs/2026-10-11-depth-lock-lengths-design.md) §2, 결정 V16·V20·V21·V25
* 시안: `design-v2-today`(근거 보기 0-나, 하트 아래), `design-v2-tab-seal`(도장 반응), `design-v2-evidence-lock`(근거 시트 잠김 B)

문장은 이 앱의 본체입니다. 문장 컴포넌트는 글꼴·줄바꿈·덧붙는 링크와 반응만 정하고, 문구는 writing(UI 슬롯)과 server(콘텐츠)가 정합니다.

## sentence-block

* 쓰는 화면: welcome, preview, login, today, explain-sheet, evidence-sheet, diary-edit, diary-view, tag-diary, my-saju, calc-basis, account-delete, force-update
* 변형 `card`(`type.sentence.card` 17px) / `body`(`type.sentence.body` 15px) / `preview`(일기 목록, 14.5px 두 줄 말줄임).
* 한국어는 어절 단위 줄바꿈(keep-all), 일본어는 글자 단위 + 금칙 처리.
* 호칭은 문장 안의 자리로만 들어갑니다. 굵게 하거나 색을 바꾸지 않습니다.
* **잠김**(`states.locked`): 근거·해석 열람 권한이 없을 때의 콘텐츠 문장(D60). 흐린 한 줄(`lock.veil`) + 오른쪽 끝 "열기 ›". 누르면 근거 시트가 잠긴 상태로 열립니다. 지금 쓰는 곳은 사주 표의 용신 판정 근거(`saju-chart.yongsin.basis`)뿐입니다.

## term-token

* 쓰는 화면: today, day-sheet, tag-diary, my-saju, saju-chart
* `term` 요소: `term.bg`/`term.fg`, `radius.xs`, 굵게 하지 않음(결정 V0).
* 변형 `inline`(문장 안, 글자 스타일 그대로) / `label`(표 행 머리·십성 줄, `type.caption.md`).
* 누르면 풀이 시트(explain-sheet, half)가 열립니다: 제목 + 한자 → 일반 뜻 → 오늘 그런 이유(오늘 화면에서 열었을 때만) → "근거 보기 ›"(`depth-link` `block`). **모두 무료이고 잠기지 않습니다**(D60).
* 2.0.0에서 "내 사주에서는" 상자와 잠김 변형을 뺐습니다. 원국 개인 해석은 근거 시트로 옮겨 처음부터 잠긴 기능으로 둡니다(D60 ②, depth-link 참고).
* 터치 영역: 글자 높이가 작아도 줄 높이까지 위아래로 넓혀 44px를 맞춥니다.

## depth-link

* 쓰는 화면: today, explain-sheet, my-saju, evidence-sheet(구성)
* "근거 보기 ›", `action.primary` `type.label.lg`.
* `inline-end`: 이유 문장 끝에 붙습니다. `link.inline-nowrap`으로 링크 전체가 한 덩어리라, 줄 끝에 다 들어가지 않으면 통째로 다음 줄로 갑니다. "근거 / 보기"처럼 갈라지지 않습니다(시안 비교에서 고른 0-나).
* `block`: 문단 아래 따로 놓입니다(나 탭).
* 누르면 한 단계 깊은 시트가 열립니다. 이미 시트 안이면 `sheet.stack`으로 쌓입니다.

### 근거 시트 (`parts.evidenceSheet`)

근거 시트(evidence-sheet, full)는 늘 근거 보기 링크(또는 잠긴 용신 근거의 "열기")에서 열리므로, 풀이 시트를 `term-token`이 갖듯 그 구성을 `depth-link`가 갖습니다.

| 순서 | 구성 | 잠김 |
| --- | --- | --- |
| 1 | 제목(`type.title`) | 무료 |
| 2 | 원국표(`saju-pillars`) | 무료(표 데이터) |
| 3 | 판정 근거(`evidence-sheet.basis.body`) | 잠김 |
| 4 | 원전(`evidence-sheet.source.quote`, `bg.base` 상자) | 잠김 |
| 5 | 내 사주에서는(`evidence-sheet.personal.body`, 사주 표·만세력·대운 표의 용어에서 열었을 때만) | 잠김 |

구역 제목은 `type.label.md` `text.secondary`, 구역 사이 `space.20`입니다.

### 잠김과 해제 (시안 B, 결정 V25)

| 상태 | 언제 | 모습 |
| --- | --- | --- |
| `locked` | 권한 없음, 광고 준비됨 | 세 구역을 같은 자리에 `lock.veil`로. 시트 아래 고정 안내 영역(위 1px `line`, `bg.sheet`): 자물쇠 + `lock.head` → `lock.reward`(보상 고지, 버튼보다 먼저) → `primary-button` `filled`(`lock.cta`) → `lock.pass` 링크(→ `ad-free`) |
| `lockedNoAd` | 권한 없음, 광고 준비 안 됨 | 버튼 `disabled` + 아래 `lock.unavailable`. 광고가 준비되면 `locked`(`appear.seep`) |
| `unlocking` | 광고를 끝까지 보고 돌아와 server 확인(SSV)을 기다림 | 버튼 `loading`(점 숨쉬기). 스크린리더 "확인 중" |
| `unlocked` | 권한 있음 | 안내 영역 없음, 세 구역 본문 |

* **광고를 끝까지 보고 돌아옴**: `unlocking` → 권한이 오면 안내 영역 `disappear.seep`, 세 구역 skeleton → 내용 `appear.seep`, 햅틱 light, 스크린리더에 열렸다고 한 번 알림.
* **확인이 오지 않음**(대기 시간은 app이 server 확인 흐름에 맞춰 정함): `locked`로 돌아가고 `toast`로 알립니다(문구 슬롯은 지휘에 요청함).
* **중간에 닫음**: `locked` 그대로, 알림 없음.
* 처음부터 권한이 있으면(그날 이미 열었거나 광고 제거권 기간) `unlocked`로 엽니다.
* 자정이 지나 권한이 끝나도 보고 있던 시트는 바꾸지 않습니다. 다음에 여는 시트부터 `locked`입니다.
* 안내 영역 높이만큼 본문 아래 여백을 둬서 마지막 구역이 가려지지 않게 합니다.
* 고르지 않은 시안: A(안내 카드 하나 + 아래로 흐려짐), C(흐린 본문 위 겹친 안내).

## reaction-button

* 쓰는 화면: today
* 하트 Light(`text.secondary`), 터치 44px. 문장 아래 오른쪽에 홀로 둡니다(근거 보기와 다른 줄).
* 누르면 `seal` fill 34px가 `seal.stamp`로 찍히고 하트가 Regular `action.on-primary`(라이트 흰색, 다크 neutral-950)로 바뀝니다. 햅틱 light.
* 다시 누르면 `seal.erase`, 햅틱 없음.

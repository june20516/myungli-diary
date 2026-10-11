# feedback: 알림과 화면 상태 (`feedback.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.2, 결정 V14·V18
* 시안: `design-v2-appear`(스밈), `design-v2-skeleton`(먹 숨쉬기), `design-v2-kit`, `design-v2-caution-mark`

## 화면 상태 대응표 (`stateMap`)

IA 화면의 `states`에 나오는 상태 7종을 어떤 컴포넌트로 보여 줄지 정합니다. 검사기(`tools/components.py`)가 IA의 상태 전부를 덮는지 확인합니다.

| IA 상태 | 컴포넌트 | 비고 |
| --- | --- | --- |
| `loading` | skeleton | 스피너 없음 |
| `empty` | empty-state | |
| `error` | error-state | `generic` 변형 |
| `offline` | notice-banner `offline` | 받아둔 내용이 없으면 error-state `offline` |
| `draft` | draft-indicator + notice-banner `draft` | 이어 쓸 초안 |
| `time-unknown` | notice-banner `time-unknown` | 사주 표는 시주 칸을 비움 |
| `out-of-range` | input-step 오류 줄 | 지원 범위 1900-01-31~2099-12-31 밖 |

## dialog

* 쓰는 화면: preview, login, event-edit, diary-view, settings, account-delete
* `bg.sheet`, `radius.lg`, 좌우 28px. 제목 `type.subtitle`, 본문 `type.body.ui` `text.secondary`, 오른쪽 아래 글자 버튼. 나타남 `appear.seep`.
* `destructive` 변형(일기 삭제, 계정 삭제): 제목 앞 `mark.caution`, 확정 버튼 글자는 `text.primary` 굵게, 취소는 `action.primary`. **빨간색을 쓰지 않습니다.** 첫 초점은 취소, 바깥 누르기로 닫히지 않음, 확정 시 햅틱 medium.
* Material 힌트: `AlertDialog`의 표면 색조·그림자를 끄고 `appear.seep` 전환을 씁니다.

## toast

* 쓰는 화면: diary-edit(저장 완료)
* 반전색 알약(`inverse.bg`/`inverse.fg`), 탭 바 위 16px. `appear.seep`으로 나타나 `toast-hold`(2.5초) 뒤 `disappear.seep`.
* 한 번에 하나만 보입니다. 누르는 동작을 담지 않습니다.

## notice-banner

* 쓰는 화면: diary-edit, saju-chart, profile-edit (그리고 오프라인일 때 받아둔 내용을 보여 주는 모든 화면)
* 화면 맨 위 내용의 첫 줄입니다. 떠 있지 않고 내용과 함께 스크롤됩니다. `bg.sheet`, `radius.md`, 아이콘 16 + `type.caption.lg` `text.secondary`.
* 닫기 버튼이 없습니다. 상태가 풀리면 `disappear.seep`으로 사라집니다.

## skeleton

* 쓰는 화면: launch, 그리고 IA `loading` 상태가 있는 모든 화면
* 실제 올 요소와 같은 자리·크기·반경의 `skeleton.bone`이 `loading.breathe`로 숨쉽니다(줄마다 150ms 어긋남).
* 300ms 안에 끝나는 불러오기에는 보이지 않습니다. 내용이 오면 내용이 `appear.seep`으로 나타납니다.

## empty-state · error-state

* 쓰는 화면: empty-state는 birthplace, diary-list, tag-diary. error-state는 IA `error` 상태가 있는 모든 화면.
* sage 원(56px, `status.bg`) 안 Light 아이콘 28px(`action.primary`) + 문장(`type.sentence.body`, 가운데). 화면 세로 40% 자리.
* 빈 상태는 있으면 주 버튼, 오류 상태는 `quiet` "다시 시도". 다시 시도하면 그 자리에 skeleton이 다시 나옵니다.
* 문장은 자리 채우기입니다(문구는 writing).

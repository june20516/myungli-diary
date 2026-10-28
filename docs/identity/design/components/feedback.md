# feedback: 알림과 화면 상태 (`feedback.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.2, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.3·§3, [십성 라벨·피드백 spec](../specs/2026-10-28-feedback-saju-labels-design.md) §3, 결정 V14·V18·V50·V51
* 시안: `design-v2-appear`(스밈), `design-v2-skeleton`(먹 숨쉬기), `design-v2-kit`, `design-v2-caution-mark`

## 화면 상태 대응표 (`stateMap`)

IA 화면의 `states`에 나오는 상태 7종을 어떤 컴포넌트로 보여 줄지 정합니다. 검사기(`tools/components.py`)가 IA의 상태 전부를 덮는지 확인합니다.

| IA 상태 | 컴포넌트 | 비고 |
| --- | --- | --- |
| `loading` | skeleton | 스피너 없음 |
| `empty` | empty-state | |
| `error` | error-state 또는 notice-banner `error` | 보일 내용이 없으면 error-state `generic`. 화면 내용(바꾼 값 등)을 남긴 채 실패를 알릴 때는 notice-banner `error`(예 `profile-edit:error`, V50) |
| `offline` | notice-banner `offline` | 받아둔 내용이 없으면 error-state `offline` |
| `draft` | draft-indicator + notice-banner `draft` | 이어 쓸 초안 |
| `time-unknown` | notice-banner `time-unknown` | 사주 표는 시주 칸을 비움 |
| `out-of-range` | input-step 오류 줄 | 지원 범위 1900-01-31~2099-12-31 밖 |

## dialog

* 쓰는 화면: preview, login, event-edit, diary-view, settings, profile-edit, account-delete, login-methods, account-merge
* `bg.sheet`, `radius.lg`, 좌우 28px. 제목 `type.subtitle`, 본문 `type.body.ui` `text.secondary`, 오른쪽 아래 글자 버튼. 나타남 `appear.seep`.
* `destructive` 변형(일기 삭제, 일정 삭제, 계정 삭제, 계정 합치기, 로그인 수단 떼기): 제목 앞 `mark.caution`, 확정 버튼 글자는 `text.primary` 굵게, 취소는 `action.primary`. **빨간색을 쓰지 않습니다.** 바깥 누르기로 닫히지 않고 뒤로 가기는 취소와 같음, 확정 시 햅틱 medium.
* 버튼 두 개짜리 확인 창(`confirm`·`destructive`)에는 첫 초점 규칙을 두지 않습니다. 앱은 웹처럼 키보드 초점으로 기본 버튼을 고르지 않고, 스크린리더는 플랫폼 기본대로 제목 → 본문 → 버튼 순서로 읽습니다(결정 V41). #354 ②의 답: 사주 다시 계산처럼 파괴적이지 않은 무거운 변경은 `confirm`을 쓰고, "첫 초점 취소" 옵션은 두지 않습니다.
* `notice` 변형: 확인 버튼 하나만 있는 안내입니다. `login.discard.notice`(미리보기 입력을 쓰지 않는다는 안내), 로그인 수단 연결·떼기 실패(`login-methods.error.body`), 다른 유저 계정에 연결된 인증 계정이라 연결하지 않음(`login-methods.in-use.body`), 계정 합치기 실패(`ui.account-merge.error`), 유저 계정 B가 아닌 인증 계정으로 인증함(`account-merge.not-other.body`)처럼 고를 것이 없고 읽었다는 확인만 받는 곳에 씁니다. 확인 버튼은 `confirm`과 같은 모양으로 오른쪽 끝에 놓입니다. 바깥을 누르거나 뒤로 가면 확인과 같고, 첫 초점은 확인 버튼입니다. 두 버튼 형식에서 "닫기"가 취소처럼 읽히던 문제가 없어집니다.
* Material 힌트: `AlertDialog`의 표면 색조·그림자를 끄고 `appear.seep` 전환을 씁니다.

## toast

* 쓰는 화면: evidence-sheet(해제 실패), event-edit(저장 실패), diary-edit(저장 완료), diary-view(지운 뒤)
* 반전색 알약(`inverse.bg`/`inverse.fg`). 화면 아래에 붙은 것 중 가장 위의 것에서 16px 위에 뜹니다: 아래 고정 버튼(`primary-button`, `input-step` 주 버튼, 키보드 위 버튼) → 광고 배너 → 탭 바 → 아래 안전 영역 순서로 먼저 있는 것이 기준입니다. 버튼을 덮지 않고, 키보드가 올라오면 함께 올라갑니다(V51, #354 ④). `appear.seep`으로 나타나 `toast-hold`(2.5초) 뒤 `disappear.seep`.
* 한 번에 하나만 보입니다. 누르는 동작을 담지 않습니다.

## notice-banner

* 쓰는 화면: diary-edit, saju-chart, profile-edit (그리고 오프라인일 때 받아둔 내용을 보여 주는 모든 화면)
* 화면 맨 위 내용의 첫 줄입니다. 떠 있지 않고 내용과 함께 스크롤됩니다. `bg.sheet`, `radius.md`, 아이콘 16 + `type.caption.lg` `text.secondary`.
* 닫기 버튼이 없습니다. 상태가 풀리면 `disappear.seep`으로 사라집니다.
* 변형: `offline`(`wifi-slash`), `time-unknown`(`clock`), `draft`(`note-pencil`), `error`(`cloud-warning`, V50).
* **`error`(V50):** 연결은 있지만 요청이 실패했을 때입니다(server 오류, 다시 계산 실패). `offline`과 아이콘만 다르고, 빨간색이나 `mark.caution`을 쓰지 않습니다. 버튼을 담지 않습니다. 다시 시도는 화면의 원래 동작 버튼이 맡습니다. 예: `profile-edit`는 저장 버튼 글자가 "다시 시도"로 바뀌고 바꾼 값은 그대로 남습니다.
* 늘 보이는 안내(예 `profile-edit.recalc.notice`)는 배너가 아니라 `settings-row` `groupNote`입니다(V50).

## skeleton

* 쓰는 화면: launch, 그리고 IA `loading` 상태가 있는 모든 화면
* 실제 올 요소와 같은 자리·크기·반경의 `skeleton.bone`이 `loading.breathe`로 숨쉽니다(줄마다 150ms 어긋남).
* 글줄 skeleton의 줄 높이는 실제 올 글자 스타일을 따릅니다(`textLine.type`, 기본 `type.body.ui`). 예: 문장 본문 자리는 `type.sentence.body`.
* 300ms 안에 끝나는 불러오기에는 보이지 않습니다. 내용이 오면 내용이 `appear.seep`으로 나타납니다.

## empty-state · error-state

* 쓰는 화면: empty-state는 birthplace, diary-list, tag-diary. error-state는 IA `error` 상태가 있는 모든 화면.
* sage 원(56px, `status.bg`) 안 Light 아이콘 28px(`action.primary`) + 문장(`type.sentence.body`, 가운데). 화면 세로 40% 자리.
* 빈 상태는 있으면 주 버튼, 오류 상태는 `quiet` "다시 시도". 다시 시도하면 그 자리에 skeleton이 다시 나옵니다.
* 문장은 자리 채우기입니다(문구는 writing).

## 구현 힌트 (Flutter)

명세의 접근성 역할을 Flutter 의미 표시에 대응한 결과입니다. 명세 값은 그대로입니다.

| 구성 요소 | 명세 역할 | Flutter 대응 |
| --- | --- | --- |
| `skeleton` | `progressbar` | `loadingSpinner` 의미 표시 |
| `empty-state` | `group` | `container` |
| `toast`·`notice-banner`·`error-state` | role + liveRegion | role 노드와 liveRegion 노드를 둘로 나눔(한 노드에 두면 모바일 알림이 사라짐) |

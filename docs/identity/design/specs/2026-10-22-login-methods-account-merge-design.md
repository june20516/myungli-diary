# 로그인 수단·계정 합치기 설계 (컴포넌트 계약 2.7.0)

* 작업 단위: design
* 마일스톤: V2 후속 (선행 컴포넌트 2.6.0, 후행 app 계획 7 #311)
* 입력: Issue #389(D82 컴포넌트·화면 배치, 지휘 정정 코멘트 D83 ④ 포함), drift #414·#395(`account-choice` 명세 없음), #354 ②(`dialog` 첫 초점), #260(윤달 표지 문구, writing W33에서 끝남)
* 기준 문서: `docs/decisions.md` D55·D82·D83, IA v4 `docs/ia/screens.json`(`login`·`login-methods`·`account-merge`), [V2 spec](2026-10-11-components-design.md), [구현 대응 spec](2026-10-15-spec-followups-design.md) §2.3·§2.6
* 시안: [`artifacts/2026-10-22-v2-login-methods.html`](../artifacts/2026-10-22-v2-login-methods.html)(B 채택), [`artifacts/2026-10-22-v2-account-merge.html`](../artifacts/2026-10-22-v2-account-merge.html)
* 계약: 컴포넌트 명세 2.6.0 → **2.7.0**(컴포넌트·변형·상태 추가와 값 변경). 토큰 1.1.0은 그대로입니다.

## 1. 목적과 완료 기준

D82로 로그인 제공자가 넷이 되고, 한 계정에 여러 제공자를 붙이고 두 계정을 합칠 수 있게 됐습니다. IA v4는 `account-choice` 컴포넌트와 화면 `login-methods`·`account-merge`를 더했고, 명세가 없어 design의 계약 검사가 실패합니다(drift #414·#395). 이 작업은 그 명세를 채워 app 계획 7이 추가 질문 없이 두 화면을 그릴 수 있게 합니다.

사용자가 정한 방향:

* `account-merge`에서 눈에 띄어야 하는 것은 **최종 확인**(되돌릴 수 없음) 하나입니다.
* 겹치는 날 안내(`account-merge.overlap.notice`)는 경고가 아니라 **안심시키는 안내**입니다. 같은 날 일기도 지우지 않고 모두 옮기기 때문입니다(D83 ④).
* 로그인 수단 화면은 로그인 화면과 같은 버튼 네 개를 두고, 연결된 수단만 "연결됨" 상태로 바꿉니다(시안 B).
* 앱은 웹이 아니므로 버튼 두 개짜리 확인 창에 첫 초점 규칙을 두지 않습니다.

끝나는 조건:

1. 컴포넌트 명세 2.7.0 (§2~§5)
2. 글자 수 상한 행 추가 (§6)
3. 검사기 `tools/components.py`와 pytest 통과 (drift #414·#395의 실패 해소)
4. 결정 V39~V41, 시안 기록, `CLAUDE.md` 갱신
5. Issue: #389·#414 `Closes`, #354 ② 답 코멘트, 지휘·writing 앞 요청 (§7)

## 2. `social-login-button` (D82, 결정 V39)

### 2.1. 변형 네 개

| 변형 | 바탕 / 글자 | 출처 |
| --- | --- | --- |
| `kakao` | 카카오 로그인 디자인 가이드 | 지금과 같음 |
| `line` | 바탕 `#06C755`, 글자·로고 흰색. 눌림은 검정 30% 덮개, 비활성은 흰 바탕 + `#E5E5E5` 60% 테두리 + 글자·로고 `#1E1E1E` 20% | LINE Login button design guidelines |
| `google` | 라이트 화면은 light 테마(바탕 `#FFFFFF`, 안쪽 1px 테두리 `#747775`, 글자 `#1F1F1F`), 다크 화면은 dark 테마(`#131314`, `#8E918F`, `#E3E3E3`). 글자는 Google Sans Medium 14/20 | Google Sign-In branding guidelines |
| `apple` | Sign in with Apple HIG(라이트 검정, 다크 흰색), 글자는 시스템 글꼴 `type.label.lg` | 지금과 같음 |

* 제공자 색 값은 토큰으로 두지 않습니다. 각 사 가이드가 출처이고, 명세에는 `style` 이름과 가이드가 정한 값을 적어 app이 대조할 수 있게 합니다.
* 로고는 각 사 공식 자산입니다(V15). Google "G"는 표준 컬러로 흰 바탕 위에만 놓습니다. LINE 아이콘은 비율을 바꾸지 않습니다.
* 버튼 글자는 writing #388이 정합니다. Google은 "Google" 한 낱말만 라벨로 쓸 수 없고, LINE은 줄바꿈 없이 "LINE으로 로그인"임이 드러나야 합니다(각 가이드).
* 눌림은 `line`만 가이드의 덮개를 쓰고, 나머지는 지금처럼 `press.ink`입니다. 비활성은 `line`만 가이드 값이고, 나머지는 지금처럼 버튼 전체 `opacity: 0.4`입니다.

### 2.2. 크기와 순서

* 네 버튼은 같은 크기·같은 무게입니다(D82 ①, Google 가이드 "다른 제공자만큼 눈에 띔", App Store 4.8). 높이 52(최소 높이, V30), 너비 fill, `radius.md`, 쌓기 간격 `space.12`, 로고 20px은 왼쪽 안쪽 여백 16에 고정하고 글자는 가운데입니다.
* 순서는 언어마다 맨 위만 다르고 나머지는 기본 순서(카카오·LINE·Google·Apple)를 따릅니다.

| 언어 | 순서 |
| --- | --- |
| ko | 카카오, LINE, Google, Apple |
| ja | LINE, 카카오, Google, Apple |
| en | Google, 카카오, LINE, Apple |

명세 표기: `parts.stack.order: { "base": ["kakao", "line", "google", "apple"], "top": { "ko": "kakao", "ja": "line", "en": "google" } }`. 지금 규칙의 "카카오 위, Apple 아래"를 이 표가 대신합니다.

### 2.3. 상태 `connected` (`login-methods`에서만)

연결된 수단을 보이는 상태입니다. 로그인 동작이 아니라 연결 상태 줄이므로 제공자 버튼 색을 쓰지 않습니다.

* 모양: 바탕 `color.bg.sheet`, 테두리 `color.line` 1px, 크기·반경·로고 자리는 다른 상태와 같음. 로고는 공식 자산이고 Google "G"는 흰 원(지름 20) 위에 놓습니다.
* 글자: 제공자 이름(`type.label.lg`, `text.primary`)을 왼쪽에, 끝에 아이콘 `check`(Regular, 14px)와 "연결됨"(`type.caption.lg`, `action.primary`)을 둡니다. "연결됨"은 IA 밖 슬롯 `ui.social-login-button.connected`(§7.2)이고, 제공자 이름은 `ui.provider.name`입니다.
* 누르면 떼기 확인 `dialog` `destructive`(`login-methods.unlink.confirm`)가 열립니다.
* 연결된 수단이 하나만 남으면 그 줄은 누를 수 없고(`press.ink` 없음, 모양은 그대로), 버튼 묶음 아래에 `login-methods.last.notice`를 늘 보입니다(`type.caption.lg`, `text.secondary`, 위 간격 `space.12`).
* a11y: 역할 button, 라벨 "제공자 이름, 연결됨". 마지막 하나면 역할 없이 라벨 뒤에 안내 슬롯을 이어 읽습니다.
* 연결 중에는 누른 버튼만 `loading`, 나머지 버튼(연결됨 줄 포함)은 `disabled`입니다.

## 3. `account-choice` (새 컴포넌트, `input` 묶음, 결정 V40)

합칠 두 계정 가운데 남길 쪽을 고르는 카드 두 장입니다. 화면 `account-merge`에서만 씁니다.

### 3.1. 구성

* 카드: 바탕 `color.bg.sheet`, `radius.md`, 안쪽 여백 `space.16`, 카드 사이 `space.12`, 테두리 2px `transparent`. 카드는 고르기 묶음 안의 항목이고, 고름 표시는 알약 동그라미입니다(V26).
* 카드 안 줄(위에서 아래, 줄 사이 `space.8`):
  1. 호칭(`type.subtitle`, `text.primary`) + 현재 로그인한 계정이면 알약 "현재 계정"(`type.caption.sm`, `text.secondary`, 테두리 `color.line` 1px, `radius.full`, 좌우 `space.8`). 문구는 `ui.account-choice.current`.
  2. 사주 요약 한 줄(`type.caption.lg`, `text.secondary`, 숫자 tabular): 생년월일·달력 종류·출생 시각. 시각을 모르면 그 자리에 "시간 모름". 사주를 저장하지 않은 계정이면 줄 전체가 "사주 정보 없음". 문구는 `ui.account-choice.saju`(매개변수 `{date}`·`{calendar}`·`{time}`), `ui.account-choice.time-unknown`, `ui.account-choice.no-saju`.
  3. 일기 수와 연결된 수단(`type.caption.lg`, `text.primary`, 사이 `space.12`): "일기 {count}편"(`ui.account-choice.diary-count`), 수단은 이름 글자를 구분자로 이음(`ui.provider.name`, 구분자 `ui.account-choice.providers.join`). 로고는 쓰지 않습니다(Google "G" 단독 사용 금지, 스크린리더가 그대로 읽음).
* 고름 표시: 카드 오른쪽 위(위·오른쪽 `space.16`) 동그라미 22px, 테두리 1.5px `color.line`, `radius.full`.

### 3.2. 상태

| 상태 | 모양 |
| --- | --- |
| `none` | 처음 상태. 어느 카드도 고르지 않음. `account-merge`의 합치기 버튼은 `disabled` |
| `selected` | 고른 카드의 테두리 `action.primary` 2px, 동그라미 테두리 `action.primary` + 안에 채운 점 12px. 바뀔 때 `select.seep-slide`의 스밈만(이동 없음), 처음 고를 때는 `appear.seep` |
| `pressed` | `press.ink` |
| `loading` | 카드 두 장 크기의 빈 카드가 먹 숨쉬기(`loading.breathe`, 글줄 자리는 `skeleton`과 같은 모양). `skeleton` 컴포넌트를 따로 쓰지 않고 이 컴포넌트의 상태입니다(IA `account-merge` 컴포넌트에 `skeleton`이 없음). IA `account-merge:loading` |

* 햅틱: 고름이 바뀔 때 `selection`.
* a11y: 묶음 역할 radio-group, 묶음 이름은 `account-merge.choice.label`. 카드 역할 radio, 라벨은 카드 안 글자를 위에서 아래 순서로 이은 것. 최소 터치 영역은 카드 전체.
* 규칙: 처음부터 어느 쪽도 골라 두지 않습니다. 되돌릴 수 없는 합치기에서 남길 계정은 사용자가 직접 고르게 합니다.

## 4. 화면 배치

### 4.1. `login-methods`

app-bar 아래로 `login-methods.intro.body`(`type.body.ui`, `text.secondary`, 아래 `space.20`) → `social-login-button` 네 개(§2.2 순서, 연결된 것은 `connected`) → 하나만 남았을 때 `login-methods.last.notice`. 오류(`login-methods:error`)는 `login-methods.error.body`를 `toast`가 아니라 `dialog` `notice`로 보입니다(IA 이 화면 컴포넌트에 `toast`가 없음). 연결하려는 수단이 다른 계정에 있으면 `account-merge`로 넘어갑니다.

### 4.2. `account-merge`

app-bar 아래로:

1. `account-merge.title.head`(`type.title`, 위 `space.12`, 아래 `space.8`)
2. `account-merge.title.body`(`type.body.ui`, `text.secondary`, 아래 `space.24`)
3. `account-merge.choice.label`(`type.caption.md`, `text.secondary`, 아래 `space.8`)
4. `account-choice`
5. `account-merge.overlap.notice`: 같은 날 일기가 겹칠 때만. 위 `space.16`, 앞 아이콘 `check-circle`(Light, 16px, `text.secondary`) + `type.caption.lg` `text.secondary`, 사이 `space.8`. **경고 표시(`mark.caution`)와 바탕 상자를 쓰지 않습니다.** 지울 것이 없다는 사실을 알리는 안심 안내이기 때문입니다.
6. 화면 아래(내용이 짧으면 바닥에 붙음): `primary-button` `filled` `account-merge.cta.merge`(고르기 전 `disabled`) → `primary-button` `quiet` `account-merge.cta.cancel`, 사이 `space.4`

* 합치기 버튼을 누르면 `dialog` `destructive`(`account-merge.merge.confirm`)가 열립니다. **강조는 이 확인 창 한 곳입니다.** 화면의 합치기 버튼은 평소 무게(`filled`)로 둡니다. 확인 창 본문은 남는 계정을 호칭과 연결된 수단으로 말합니다(원고는 writing).
* 확정 뒤 합치는 중에는 확인 창이 닫히고 합치기 버튼이 `loading`입니다. 끝나면 `login-methods`로 돌아갑니다.
* 실패(`account-merge:error`)를 알릴 슬롯이 IA에 없습니다. 지휘에 묻고(§7.1), 정해지기 전에는 `dialog` `notice`로 보이는 것을 기본으로 적습니다.

## 5. `dialog` 첫 초점 규칙 (결정 V41, #354 ②)

앱은 웹처럼 키보드 초점으로 기본 버튼을 고르지 않습니다. 버튼 두 개짜리 확인 창(`confirm`·`destructive`)에서 첫 초점 규칙을 지웁니다.

* `dialog.a11y.focusOnOpen`과 `destructive.a11y.focusOnOpen`을 지웁니다. 스크린리더는 플랫폼 기본대로 제목 → 본문 → 버튼 순서로 읽습니다.
* 규칙 "destructive 변형은 처음 초점과 기본 동작을 취소에 둔다"를 "destructive 변형에서 뒤로 가기는 취소와 같다"로 바꿉니다.
* `destructive`의 바깥 누르기로 닫히지 않음(`dismissOnScrim: false`), 제목 앞 `mark.caution`, 굵은 본문색 확정 버튼, 햅틱 medium은 그대로입니다.
* `notice`(버튼 하나)와 시트의 `focusOnOpen`은 그대로입니다.
* #354 ②의 답: `profile-edit.recalc.confirm`처럼 파괴적이지 않은 무거운 변경은 `confirm`을 씁니다. "첫 초점 취소" 옵션은 두지 않습니다.

## 6. 글자 수 상한

`tools/lengths.py`에 행을 더하고 `lengths.md`를 다시 만듭니다. 기존 확정값은 그대로입니다.

* IA ui 자리: `login-methods.*`(intro·last·unlink 확인 창 제목·버튼·error), `account-merge.*`(title·choice.label·overlap.notice·cta 둘·merge 확인 창 제목·버튼). 칸 폭은 화면 폭 360 − 좌우 `space.20`×2 = 320 기준, 버튼은 52 높이 한 줄, 확인 창은 기존 확인 창 슬롯과 같은 규칙(제목·버튼 키만).
* `social-login-button` 글자: 버튼 폭 320 − 로고 자리(16 + 20 + 여백)로 한 줄. LINE·Google 라벨이 이 칸에 들어가는지 #388 원고로 잽니다.
* `account-choice` 슬롯(§3.1): 카드 안 폭 320 − 16×2 − 고름 표시 자리.
* 윤달 표지 `ui.day-cell.lunar`(`dayCellLeapNewMoon`, W33): 칸 폭 44px, 10.5px 400, 한 줄. `calendar.json` `leapNewMoon`에 슬롯 id를 적고 "정해지기 전에는 M.1" 메모를 지웁니다.
* 원고가 아직 없는 슬롯(#388)은 상한만 정하고 측정 대상에서 빠집니다(기존 `unbounded`·미작성 처리와 같음).

## 7. 바깥에 요청할 것

### 7.1. 지휘 (`to:root`)

1. IA `login-methods.components`에서 `settings-row`를 빼 주세요. 시안 B는 연결 상태를 `social-login-button` `connected`로 보여 `settings-row`를 쓰지 않습니다. 반영 전까지 MD "쓰는 화면" 대조 테스트에 이 한 쌍을 예외(`USED_ON_EXCEPTIONS`)로 둡니다.
2. `account-merge:error`(합치기 실패)를 알릴 ui 슬롯이 없습니다. 슬롯을 더할지, 공용 오류 문구를 쓸지 정해 주세요.

### 7.2. writing (#388 코멘트)

1. `account-merge.overlap.notice`의 structure가 아직 "지워질 일기 수"입니다. D83 ④에 맞게 "같은 날 일기도 모두 옮긴다는 안심 안내"로 고쳐 주세요.
2. IA 밖 슬롯 원고: `ui.social-login-button.connected`("연결됨"), `ui.provider.name`(제공자 이름 넷), `ui.account-choice.current`·`saju`·`time-unknown`·`no-saju`·`diary-count`·`providers.join`. 상한은 §6 값입니다.

### 7.3. app

PR 병합 뒤 #311(계획 7)에 2.7.0 요약을 코멘트로 남깁니다. `dialog` 첫 초점 변경은 기존 화면(일기·일정·계정 삭제)에도 걸리므로 함께 알립니다.

## 8. 결정

* **V39** 로그인 수단 화면은 로그인 화면과 같은 `social-login-button` 네 개를 같은 순서로 두고, 연결된 수단만 상태 `connected`(제공자 색 없는 중립 줄 + "연결됨")로 바꿉니다. 언어마다 맨 위만 다르고 나머지는 기본 순서입니다. LINE·Google 변형은 각 사 가이드 값을 따릅니다.
* **V40** `account-choice`는 처음에 아무것도 고르지 않은 카드 두 장이고, 연결된 수단은 이름 글자로 보입니다. `account-merge`의 강조는 최종 확인 `dialog` `destructive` 한 곳이고, 겹치는 날 안내는 경고 표시 없는 안심 안내입니다.
* **V41** 버튼 두 개짜리 확인 창에는 첫 초점 규칙을 두지 않습니다(앱은 웹이 아님). `destructive`의 뒤로 가기는 취소와 같습니다.

## 9. 범위 밖

* #410(`diary-row` 같은 날 여러 편)은 다음 PR에서 합니다. 이 spec은 일기 수를 숫자로만 보이고 여러 편 표시와 관계없습니다.
* #353·#354 ①③④는 이번에 다루지 않습니다.
* 제공자 연결·합치기 API와 오류 코드는 server가 정합니다(D82 ⑦).

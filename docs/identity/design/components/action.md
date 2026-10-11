# action: 동작 (`action.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §2.2·§6.4, 결정 V13·V14·V18
* 시안: `design-v2-kit`(둥근 사각 버튼), `design-v2-press-feedback`(먹 번짐)

## primary-button

* 쓰는 화면: force-update, welcome, 온보딩 단계, preview, consent, notify-ask, share-preview, event-edit, diary-edit, account-delete
* 둥근 사각(`radius.md`), 높이 52, 너비는 채움.

| 변형 | 바탕 | 글자 | 쓰임 |
| --- | --- | --- | --- |
| `filled` | `action.primary` | `action.on-primary` | 화면의 주 동작 |
| `quiet` | 없음(높이 44) | `action.primary` | 다시 입력, 건너뛰기, 다시 시도, 쓴 일기 보기 |
| `destructive` | `text.primary` | `bg.sheet` + 앞에 `mark.caution` | 되돌릴 수 없는 동작 |

| 상태 | 모습 |
| --- | --- |
| pressed | `press.ink` |
| disabled | `disabled.bg` / `disabled.fg`(대비 3:1 이상) |
| loading | 글자 자리에 점 세 개가 `loading.breathe`. 너비 그대로, 다시 누를 수 없음 |

* 스피너는 쓰지 않습니다. 버튼 처리 중의 점 숨쉬기가 유일한 대체입니다.
* Material 힌트: `FilledButton`의 `overlayColor`·`elevation`·`surfaceTintColor`를 끄고 먹 번짐 층을 얹습니다.

## social-login-button

* 쓰는 화면: login
* 반경 `radius.md`, 높이 52, 세로 간격 12만 정합니다. 색·로고·문구는 각 제공자의 공식 가이드와 공식 자산을 씁니다. 제공자는 지휘 세션 미결입니다.

## share-button

* 쓰는 화면: preview(`pill`), today(`icon`)
* `icon`: app-bar 동작, Phosphor `export` Light 24, 터치 44.
* `pill`: 옅은 sage 알약(`status.bg`) + `export` Regular 16 + 글자(`type.label.md`, `status.fg`).
* 누르면 share-preview 시트(비율 고르기 + 미리보기 + 공유)를 엽니다. 시스템 공유 창은 그 시트에서 엽니다.

## settings-row

* 쓰는 화면: settings, profile-edit, legal
* 묶음 카드(`bg.sheet`, `radius.md`) 안에서 1px `line`으로 나눕니다(왼쪽 16px 들여서). 카드 사이 20px, 카드 위 묶음 이름 `type.caption.md`.
* 변형 `navigate`(화살표) / `value`(오른쪽 값 `text.secondary` + 화살표) / `toggle`(스위치, 햅틱 selection) / `destructive`(로그아웃·계정 삭제: 본문색 600, 앞에 `mark.caution`, 화살표 없음).

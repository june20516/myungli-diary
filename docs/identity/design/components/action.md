# action: 동작 (`action.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §2.2·§6.4, 결정 V13·V14·V18·V26
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
* 반경 `radius.md`, 높이 52, 세로 간격 12만 정합니다. 색·로고·문구는 각 제공자의 공식 가이드와 공식 자산을 씁니다. 제공자는 **카카오와 Apple**(D55)이고 iOS·Android 모두 두 버튼을 같은 크기로 보입니다(카카오 위, Apple 아래). Apple 버튼은 라이트 모드 검정, 다크 모드 흰색 스타일입니다(Apple HIG).

## share-button

* 쓰는 화면: preview(`soft`), today(`icon`)
* `icon`: app-bar 동작, Phosphor `export` Light 24, 터치 44.
* `soft`: 옅은 sage 둥근 사각(`status.bg`, `radius.md`, 높이 36) + `export` Regular 16 + 글자(`type.label.md`, `status.fg`). 동작이므로 둥근 사각입니다(README 모양 규칙, 결정 V26). 2.0.0 전 이름은 `pill`(알약)이었습니다.
* 누르면 share-preview 시트(비율 고르기 + 미리보기 + 공유)를 엽니다. 시스템 공유 창은 그 시트에서 엽니다.

## settings-row

* 쓰는 화면: settings, profile-edit, legal
* 묶음 카드(`bg.sheet`, `radius.md`) 안에서 1px `line`으로 나눕니다(왼쪽 16px 들여서). 카드 사이 20px, 카드 위 묶음 이름 `type.caption.md`.
* 변형 `navigate`(화살표) / `value`(오른쪽 값 `text.secondary` + 화살표) / `toggle`(스위치, 햅틱 selection) / `destructive`(로그아웃·계정 삭제: 본문색 600, 앞에 `mark.caution`, 화살표 없음).

## offer-card

* 쓰는 화면: ad-free (D53·D54: 1개월 광고 제거권, 자동 갱신 아님)
* 카드(`bg.sheet`, `radius.lg`, 안쪽 20): Light 아이콘 28 → 주는 것 한 줄(`type.subtitle`) → 가격(`type.title`, 고정폭 숫자) + 기간·"자동 갱신 아님"(`type.caption.lg`) → 구매 주 버튼 → 구매 복원 조용한 버튼 → 약관·정책 안내(`type.caption.md`).
* 가격·기간·자동 갱신 아님 고지는 구매 버튼보다 위, 같은 카드 안에 둡니다.

| 상태 | 모습 |
| --- | --- |
| `available` | 구매 버튼 보임 |
| `active` | 구매 버튼 대신 `tag.status` "이용 중" + 남은 기간·만료일(`appear.seep`) |
| `purchasing` | 구매 버튼 점 숨쉬기 |
| `offline` | 구매·복원 비활성, 화면 위 notice-banner `offline` |

* 구매 복원은 상태와 관계없이 늘 보입니다. 구매·복원이 끝나면 햅틱 light.
* 빨간색·카운트다운·과장 표시를 쓰지 않습니다. 문구는 writing(슬롯 `ad-free.*`).

# action: 동작 (`action.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §2.2·§6.4, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.6, 결정 V13·V14·V18·V26
* 시안: `design-v2-kit`(둥근 사각 버튼), `design-v2-press-feedback`(먹 번짐)

## primary-button

* 쓰는 화면: force-update, welcome, 온보딩 단계(onboard-call, onboard-birth, onboard-time, onboard-gender), preview, consent, notify-ask, evidence-sheet, share-preview, day-sheet, event-edit, diary-edit, ad-free, account-delete, account-merge
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

* 쓰는 화면: login, login-methods
* 반경 `radius.md`, 높이 52(최소 높이, V30), 너비 fill, 세로 간격 12, 로고 20px은 왼쪽 안쪽 16에 고정하고 글자는 가운데입니다. 색·로고·문구는 각 제공자의 공식 가이드와 공식 자산을 씁니다(V15).
* 제공자는 **카카오·LINE·Google·Apple**(D82)이고 iOS·Android 모두 네 버튼을 같은 크기·같은 무게로 보입니다(App Store 4.8, Google 가이드 "다른 제공자만큼 눈에 띔"). 결정 V39.
  * `kakao`: 카카오 로그인 디자인 가이드.
  * `line`: LINE Login button design guidelines. 바탕 `#06C755`, 글자·로고 흰색, 눌림은 검정 30% 덮개, 비활성은 흰 바탕 + `#E5E5E5` 60% 테두리 + 글자·로고 `#1E1E1E` 20%. 아이콘 비율은 바꾸지 않습니다.
  * `google`: Google Sign-In branding. 라이트 화면은 light 테마(`#FFFFFF`, 안쪽 1px `#747775`, 글자 `#1F1F1F`), 다크 화면은 dark 테마(`#131314`, `#8E918F`, `#E3E3E3`). 글자는 Google Sans Medium 14/20. 표준 컬러 "G"는 흰 바탕 위에만 놓고, "Google" 한 낱말만 라벨로 쓰지 않습니다.
  * `apple`: Sign in with Apple HIG(라이트 검정, 다크 흰색). 글자는 플랫폼 시스템 글꼴, 크기와 굵기는 `type.label.lg`.
* 순서(`parts.stack.order`): 언어마다 맨 위만 다르고 나머지는 기본 순서(카카오·LINE·Google·Apple)입니다.

| 언어 | 순서 |
| --- | --- |
| ko | 카카오, LINE, Google, Apple |
| ja | LINE, 카카오, Google, Apple |
| en | Google, 카카오, LINE, Apple |

* `disabled`: 다른 버튼이 처리 중일 때입니다. 제공자 색을 바꿀 수 없으므로 버튼 전체를 `opacity 0.4`로 흐립니다. `line`만 가이드의 비활성 값을 씁니다. 처리 중에는 누른 버튼만 `loading`입니다.
* `connected`(login-methods에서만): 연결된 수단을 보이는 상태입니다. 로그인 동작이 아니라 연결 상태 줄이라 제공자 색을 쓰지 않습니다. `bg.sheet` 바탕 + `line` 1px 테두리, 공식 로고(Google "G"는 지름 20 흰 원 위), 왼쪽에 제공자 이름(`type.label.lg`, `ui.login-methods.row` `loginProvider*`), 끝에 `check` Regular 14 + "연결됨"(`type.caption.lg`, `action.primary`). 누르면 떼기 확인 `dialog` `destructive`(`login-methods.unlink.confirm`)가 열립니다. 스크린리더 라벨은 "제공자 이름, 연결됨", 힌트는 `loginMethodsRowUnlink`.
* 연결된 수단이 하나만 남으면 그 줄은 누를 수 없고(모양은 그대로), 버튼 묶음 아래에 `login-methods.last.notice`(`type.caption.lg`, `text.secondary`, 위 `space.12`)를 늘 보입니다.

### login-methods 화면 배치

app-bar 아래로 `login-methods.intro.body`(`type.body.ui`, `text.secondary`, 아래 `space.20`) → 버튼 네 개(위 순서, 연결된 것은 `connected`) → 하나만 남았을 때 `login-methods.last.notice`. 연결하지 않은 수단은 로그인 화면과 같은 버튼·라벨입니다(연결은 그 제공자로 다시 로그인, D82 ⑤). 오류(`login-methods.error.body`)는 `dialog` `notice`로 보입니다. 붙이려는 수단이 다른 계정에 있으면 `account-merge`로 넘어갑니다. IA는 이 화면에 `settings-row`를 적고 있지만 시안 B(V39)로 쓰지 않습니다(지휘에 IA 수정 요청).

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

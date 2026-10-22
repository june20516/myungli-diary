# action: 동작 (`action.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §2.2·§6.4, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.6, 결정 V13·V14·V18·V26
* 시안: `design-v2-kit`(둥근 사각 버튼), `design-v2-press-feedback`(먹 번짐)

## primary-button

* 쓰는 화면: force-update, welcome, 온보딩 단계(onboard-call, onboard-birth, onboard-time, onboard-gender), preview, consent, notify-ask, evidence-sheet, share-preview, day-sheet, event-edit, diary-edit, ad-free, account-delete, account-merge
* 둥근 사각(`radius.md`), 높이 52, 너비는 채움.

| 변형 | 바탕 | 글자 | 쓰임 |
| --- | --- | --- | --- |
| `filled` | `action.primary` | `action.on-primary` | 화면의 주 동작 |
| `quiet` | 없음(높이 44) | `action.primary` | 다시 입력, 건너뛰기, 다시 시도, 오늘 질문 카드의 쓴 뒤 버튼 |
| `destructive` | `text.primary` | `bg.sheet` + 앞에 `mark.caution` | 되돌릴 수 없는 동작 |

| 상태 | 모습 |
| --- | --- |
| pressed | `press.ink` |
| disabled | `disabled.bg` / `disabled.fg`(대비 3:1 이상) |
| loading | 글자 자리에 점 세 개가 `loading.breathe`. 너비 그대로, 다시 누를 수 없음 |

* 스피너는 쓰지 않습니다. 버튼 처리 중의 점 숨쉬기가 유일한 대체입니다.
* Material 힌트: `FilledButton`의 `overlayColor`·`elevation`·`surfaceTintColor`를 끄고 먹 번짐 층을 얹습니다.
* 그날 시트(`day-sheet`)의 이날 일기 쓰기(`filled`)는 그날 일기가 상한을 채우면 `disabled` + `daySheetDiaryWriteCtaFull`입니다(결정 V43).

## social-login-button

* 쓰는 화면: login, login-methods, account-merge
* 반경 `radius.md`, 높이 52(최소 높이, V30), 너비 fill, 세로 간격 12, 로고 20px은 왼쪽 안쪽 16에 고정하고 글자는 가운데입니다. 색·로고·문구는 각 제공자의 공식 가이드와 공식 자산을 씁니다(V15).
* 제공자는 **카카오·LINE·Google·Apple**(D82)이고 iOS·Android 모두 네 버튼을 같은 크기·같은 무게로 보입니다(App Store 4.8, Google 가이드 "다른 제공자만큼 눈에 띔"). 결정 V39.
  * `kakao`: 카카오 로그인 디자인 가이드.
  * `line`: LINE Login button design guidelines. 바탕 `#06C755`, 글자·로고 흰색, 로고와 글자 사이 구분선(검정 8%)은 공식 로고 자산의 것을 그대로 씀, 글자 자리는 구분선 비율을 따른 198px(다른 제공자 232px, 결정 V46), 눌림은 검정 30% 덮개, 비활성은 흰 바탕 + `#E5E5E5` 60% 테두리 + 글자·로고 `#1E1E1E` 20%. 아이콘 비율은 바꾸지 않습니다.
  * `google`: Google Sign-In branding. 라이트 화면은 light 테마(`#FFFFFF`, 안쪽 1px `#747775`, 글자 `#1F1F1F`), 다크 화면은 dark 테마(`#131314`, `#8E918F`, `#E3E3E3`). 글자는 Google Sans Medium 14/20이고, 없는 한글·가나는 플랫폼 시스템 글꼴로 이어 씁니다. Google Identity SDK가 그리는 버튼을 쓸 수 있으면 그것을 우선합니다(가이드 권장). 표준 컬러 "G"는 light·dark 테마 바탕 위에 그대로 놓고(그 밖의 바탕 금지), "Google" 한 낱말만 라벨로 쓰지 않습니다.
  * `apple`: Sign in with Apple HIG(라이트 검정, 다크 흰색). 글자는 플랫폼 시스템 글꼴, 크기와 굵기는 `type.label.lg`.
* 순서(`parts.stack.order`): 언어마다 맨 위만 다르고 나머지는 기본 순서(카카오·LINE·Google·Apple)입니다.

| 언어 | 순서 |
| --- | --- |
| ko | 카카오, LINE, Google, Apple |
| ja | LINE, 카카오, Google, Apple |
| en | Google, 카카오, LINE, Apple |

* `disabled`: 다른 버튼이 처리 중일 때입니다. 제공자 색을 바꿀 수 없으므로 버튼 전체를 `opacity 0.4`로 흐립니다. `line`만 가이드의 비활성 값을 씁니다. 처리 중에는 누른 버튼만 `loading`입니다.
* `connected`(login-methods에서만): 연결된 수단을 보이는 상태입니다. 로그인 동작이 아니라 연결 상태 줄이라 제공자 색을 쓰지 않습니다. `bg.sheet` 바탕 + `line` 1px 테두리, 로고는 제공자 색 배지 20px 안의 심볼 14px(카카오 `#FEE500` 위 `#191919`(공식 자산, V46), LINE `#06C755` 위 흰색, Apple 라이트 검정 위 흰색·다크 흰색 위 검정, 모서리 `radius.xs`; Google은 흰 원 위 표준 컬러 "G")로 중립 바탕에서도 보이게 하고, 왼쪽에 제공자 이름(`type.label.lg`, `ui.login-methods.row` `loginProvider*`), 끝에 `check` Regular 14 + 간격 `space.4` + "연결됨"(`type.caption.lg`, `action.primary`). 누르면 떼기 확인 `dialog` `destructive`(`login-methods.unlink.confirm`)가 열립니다. 스크린리더 라벨은 "제공자 이름, 연결됨", 힌트는 `loginMethodsRowUnlink`. 떼기 확정 뒤에는 그 줄 전체가 `loading.breathe`로 숨쉬고, 끝나면 연결하지 않은 버튼으로 바뀝니다. 다른 버튼이 처리 중이면 다른 상태와 같이 줄 전체 `opacity 0.4`입니다.
* 연결된 수단이 하나만 남으면 그 줄은 누를 수 없고(모양은 그대로), 버튼 묶음 아래에 `login-methods.last.notice`(`type.caption.lg`, `text.secondary`, 위 `space.12`)를 늘 보입니다.

### login-methods 화면 배치

app-bar 아래로 차례대로 놓습니다(결정 V39·V44).

1. `login-methods.intro.body`(`type.body.ui`, `text.secondary`, 아래 `space.20`)
2. 버튼 네 개(위 순서, 연결된 것은 `connected`). 연결하지 않은 수단은 로그인 화면과 같은 버튼·라벨입니다(연결은 그 제공자로 다시 로그인, D82 ⑤).
3. 하나만 남았을 때 `login-methods.last.notice`
4. **계정 합치기 입구:** 위 `space.32`에 1px `color.line` 가로선을 긋고, 그 아래 `space.16`에 `primary-button` `quiet` `login-methods.merge.cta`를 둡니다. 연결된 수단 수와 관계없이 늘 보입니다(D85 ④). IA `login-methods` 컴포넌트에 `primary-button`이 아직 없어 지휘에 더해 달라고 요청했습니다. 그래서 `primary-button`의 쓰는 화면 줄에는 아직 적지 않습니다.

* 오류(`login-methods.error.body`)는 `dialog` `notice`로 보입니다.
* 붙이려는 인증 수단이 다른 계정에 연결돼 있으면 연결하지 않고, `login-methods.in-use.body`를 `dialog` `notice`로 보입니다. 확인하면 이 화면에 그대로 있습니다. 합치기로 저절로 넘어가지 않습니다(D85 ③).

### account-merge 인증 단계

`account-merge`의 인증 단계(배치는 `input.md` `### account-merge 화면 배치`)에서는 네 버튼을 `login` 화면과 같은 순서·모양·라벨로 씁니다. 가져올 계정의 인증 수단으로 로그인하는 동작이라 `connected`는 쓰지 않습니다(결정 V44).

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
* 카드(`bg.sheet`, `radius.lg`, 안쪽 20): Light 아이콘 28 → 주는 것 한 줄(`type.subtitle`) → 가격(`type.title`, 고정폭 숫자) + 기간·"자동 갱신 아님"(`type.caption.lg`) → 구매 주 버튼 → 구매 내역 조용한 버튼(`ad-free.history.cta`) → 약관·정책 안내(`type.caption.md`).
* 가격·기간·자동 갱신 아님 고지는 구매 버튼보다 위, 같은 카드 안에 둡니다.

| 상태 | 모습 |
| --- | --- |
| `available` | 구매 버튼 보임 |
| `active` | 구매 버튼 대신 `tag.status` "이용 중" + 남은 기간·만료일(`appear.seep`) |
| `purchasing` | 구매 버튼 점 숨쉬기 |
| `offline` | 구매 버튼 비활성, 화면 위 notice-banner `offline`. 구매 내역 버튼은 누를 수 있음(구매 내역 화면이 자기 `offline` 상태를 가짐) |

* 구매 내역 버튼은 상태와 관계없이 늘 보입니다. 따로 누르는 구매 복원 버튼은 없습니다(D88 ②). 구매가 끝나면 햅틱 light.
* 빨간색·카운트다운·과장 표시를 쓰지 않습니다. 문구는 writing(슬롯 `ad-free.*`).

## purchase-row

* 쓰는 화면: purchase-history
* 산 상품의 구매 한 건입니다(D88 ②, #502, 결정 V45). 누르지 않는 줄입니다.
* 줄들은 카드 한 장(`bg.sheet`, `radius.lg`, 좌우 안쪽 `space.16`)에 담습니다. 줄은 위아래 `space.16`이고, 줄과 줄 사이에만 1px `line`을 긋습니다.

| 부품 | 모습 |
| --- | --- |
| `product` | 산 상품 이름. `type.subtitle`, `text.primary`. 문구는 writing이 상품 id마다 둔 키(`ui.purchase-product` `purchaseProduct*`, 줄바꿈하므로 글자 수 상한 없음), 없으면 스토어의 현지화된 이름. 넘치면 말줄임 없이 다음 줄로 감음 |
| `status` | 오른쪽, `product` 첫 줄과 세로 가운데. 사용 중이면 `tag.status`, 대기·만료·환불은 바탕 없는 `type.label.md` `text.secondary`. 낱말은 상품 종류에 따라 다를 수 있음 |
| `meta` | `product` 아래 `space.4`. `type.caption.lg`, `text.secondary`, 고정폭 숫자. 구매일(`purchaseRowPurchased`, 기기 locale의 짧은 날짜) + 사용 기간(`purchaseRowPeriod`). 사용 기간이 없는 상품은 구매일만 |

* 순서는 server가 준 순서 그대로입니다(최근 구매가 위).
* 사용 기간은 server가 준 구간 그대로입니다. 합치기로 옮겨 온 구매는 이 계정에서 쓰는 구간만 오므로 구매일이 사용 기간 시작보다 이를 수 있습니다. 대기 구매와 같습니다.
* 합치기 출처나 산 계정은 표시하지 않습니다(D88 ②).
* 강조는 "사용 중" 꼬리표 하나입니다. 빨간색·카운트다운을 쓰지 않습니다.
* `loading`: 줄 세 개 자리 `skeleton`(상품 이름 줄 + meta 줄 bone).
* 스크린리더는 한 줄을 한 덩어리로 "상품 이름, 상태, 구매일, 사용 기간" 순서로 읽습니다.

### purchase-history 화면 배치

1. app-bar(`purchase-history.bar.title`)
2. 위 `space.12`에 `purchase-row` 묶음 카드
3. `purchase-history.missing.notice`: 위 `space.16`, `type.caption.lg`, `text.secondary`, 좌우 안쪽 `space.4`. 목록이 있든 비었든 늘 보입니다. 결제했는데 목록에 없을 수 있기 때문입니다.

* `empty`: 화면 상태 대응표(`stateMap`)대로 `empty-state`입니다. 아이콘은 Phosphor `receipt`, 문장은 `purchase-history.empty.body`이고 주 버튼은 없습니다. `missing.notice`는 그 문장 아래 `space.16`에 둡니다.
* `loading`·`error`·`offline`은 `stateMap` 그대로입니다. 들어갈 때 결제 기록을 다시 불러오는 동안(D88 ②)이 `loading`입니다.
* 입구는 지금 `ad-free`의 구매 내역 버튼뿐입니다. 상품이 둘 이상이 되면 설정에도 둡니다(D88 ②).

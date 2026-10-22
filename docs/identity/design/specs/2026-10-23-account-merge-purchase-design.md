# 계정 합치기 두 단계·구매 내역 설계 (컴포넌트 계약 3.0.0)

* 작업 단위: design
* 마일스톤: V2 후속 (선행 컴포넌트 2.8.0, 토큰 1.2.0 그대로)
* 입력: drift #480(PR #477·#486·#489의 IA 변경), #483(D85 계정 합치기 흐름), #494(D88 `purchase-row`), #475(app 구현에서 어긋난 값 4가지), #502(구매 내역은 산 상품의 기록, PR #503)
* 기준 문서: `docs/decisions.md` D53·D61·D85·D88, IA `docs/ia/screens.json`(`login-methods`·`account-merge`·`ad-free`·`purchase-history`)
* 시안: [`artifacts/2026-10-23-v2-account-merge-purchase.html`](../artifacts/2026-10-23-v2-account-merge-purchase.html)
* 계약: 컴포넌트 명세 2.8.0 → **3.0.0**. `account-choice`의 부품 `facts`·`diaryCount`·`providers`와 `offer-card`의 부품 `restore`를 지우므로 major입니다. 토큰은 바뀌지 않습니다.

## 1. 목적과 완료 기준

D85로 계정 합치기가 로그인 수단 화면의 별도 입구가 되었고, 남는 계정은 언제나 지금 계정입니다. 고르는 것은 사주 정보·호칭·설정뿐입니다. D88로 구매 복원 버튼이 없어지고 구매 내역 화면이 생겼습니다. 구매 내역은 산 상품의 기록입니다(#502). 이 작업은 두 흐름의 컴포넌트와 화면 배치를 정해 app이 추가 질문 없이 그리게 하고, drift #480을 풉니다.

사용자가 정한 방향(2026-10-23):

* `account-choice`는 카드 두 장을 유지하고 내용을 줄입니다. 처음에는 고르지 않습니다(V40 유지).
* `account-merge`는 한 화면 두 단계입니다(인증 → 요약·고르기). 가져올 기록은 고르기 카드 밖 상자에 둡니다.
* 다른 계정을 부르는 말은 "가져올 계정"입니다("합칠 계정" 아님). 문구는 writing이 정하고, 이 뜻을 요청에 적습니다.
* "합치지 않기" 버튼은 두지 않습니다. 그만두기는 app-bar 뒤로 가기입니다.
* 구매 내역에 합치기로 옮겨 온 구매 표시는 하지 않습니다(D88 ②).
* 구매 줄은 산 상품의 이름이 먼저 보입니다. 광고 제거권만 있는 구간은 MVP의 잠시입니다.
* #475 ④: 일기 줄 시각도 24시간제 고정 폭입니다.

끝나는 조건:

1. 컴포넌트 명세 3.0.0(§2~§6)
2. 검사기 `tools/components.py`·`tools/lengths.py`와 pytest 통과(drift #480의 실패 5건 해소)
3. 결정 V44·V45·V46, 시안 기록, `CLAUDE.md` 갱신
4. 지휘·writing 요청 Issue(§7)
5. Issue #480·#483·#494·#475 `Closes`

## 2. 로그인 수단 `login-methods` (D85 ③)

배치(위에서 아래):

1. `login-methods.intro.body` → `social-login-button` 네 개 → 하나만 남으면 `login-methods.last.notice` (2.7.0 그대로)
2. **계정 합치기 입구:** 위 `space.32`에 1px `color.line` 가로선, 그 아래 `space.16`에 `primary-button` `quiet` `login-methods.merge.cta`. 연결된 수단 수와 관계없이 늘 보입니다.

* 붙이려는 인증 수단이 다른 계정에 연결돼 있으면 연결하지 않고 `dialog` `notice`(`login-methods.in-use.body`)로 알립니다. 확인하면 이 화면에 그대로 있습니다. 합치기로 저절로 넘어가지 않습니다(D85 ③).
* IA `login-methods` 컴포넌트에 `primary-button`이 없습니다. 지휘에 더해 달라고 요청합니다(§7). 그 전까지 `action.md` `primary-button`의 "쓰는 화면" 줄에는 `login-methods`를 적지 않고(IA 대조 검사), 배치는 `social-login-button` 절에 적습니다.

## 3. 계정 합치기 `account-merge` (D85 ④, 결정 V44)

한 화면이 두 단계로 바뀝니다. 제목 `account-merge.title.head`(`type.title`, 위 `space.12`, 아래 `space.8`)는 두 단계에 같습니다.

### 3.1. 인증 단계

1. 제목
2. `account-merge.auth.body`(`type.body.ui`, `text.secondary`, 아래 `space.24`)
3. `social-login-button` 네 개: `login` 화면과 같은 순서·모양·라벨(`parts.stack.order`). `connected` 상태는 쓰지 않습니다.

* 이 단계에는 다른 버튼이 없습니다.
* 누른 버튼만 `loading`, 나머지는 `disabled`입니다(`social-login-button` 기존 규칙).
* 인증한 수단이 지금 계정의 것이거나 어느 계정에도 연결돼 있지 않으면, `account-merge.not-other.body`를 `dialog` `notice`로 보입니다. 확인하면 인증 단계에 그대로 남아 다시 고를 수 있습니다(IA `account-merge:error`).
* 인증되면 요약·고르기 단계로 바뀝니다. 요약을 받는 동안(IA `account-merge:loading`)은 요약 상자와 카드 두 장 자리가 `loading.breathe`로 숨쉽니다.

### 3.2. 요약·고르기 단계

1. 제목
2. `account-merge.title.body`(`type.body.ui`, `text.secondary`, 아래 `space.24`)
3. **가져올 기록 상자**(새, 컴포넌트 아님): `bg.sheet`, `radius.md`, 안쪽 `space.16`, 줄 사이 `space.8`, 아래 `space.24`.
   * 머리: `type.caption.md`, `text.secondary`.
   * 줄마다 왼쪽에 이름(`type.body.ui`, `text.secondary`), 오른쪽에 값(`type.body.ui`, `text.primary`, 고정폭 숫자).
   * 줄 순서: 일기 편수 → 일정 개수 → 광고 제거 남은 기간.
   * 일기·일정은 0이어도 보입니다(D85 ④ "0건이어도 보임"). 광고 제거 남은 기간 줄은 남은 기간이 있을 때만 보입니다.
   * 문구는 IA 밖 새 슬롯 `ui.account-merge.summary`입니다.
4. `account-merge.choice.label`(`type.caption.md`, `text.secondary`, 아래 `space.8`)
5. `account-choice`(§3.3)
6. `account-merge.overlap.notice`: 같은 날 일기가 겹칠 때만(2.7.0 그대로)
7. 화면 아래(내용이 짧으면 바닥에 붙음): `primary-button` `filled` `account-merge.cta.merge`. 고르기 전에는 `disabled`입니다.

* **"합치지 않기" 버튼이 없습니다.** 그만두기는 app-bar 뒤로 가기(또는 시스템 뒤로 가기)이고, 어느 단계에서든 `login-methods`로 돌아갑니다. 인증 결과는 버립니다. IA의 `account-merge.cta.cancel` 슬롯과 "합치지 않기" 출구를 지우도록 지휘에 요청합니다(§7).
* 합치기 버튼 → `dialog` `destructive`(`account-merge.merge.confirm`). 강조는 이 한 곳입니다(V40 그대로).
* 확정 뒤 합치는 중: 확인 창이 닫히고, 합치기 버튼은 `loading`, `account-choice`는 `disabled`입니다. 이 동안 뒤로 가기는 동작하지 않습니다. 되돌릴 수 없는 처리가 진행 중이라 화면을 떠나 결과를 놓치지 않게 합니다. 끝나면 `login-methods`로 돌아갑니다.
* 실패는 `ui.account-merge.error`를 `dialog` `notice`로 보입니다(2.7.0 그대로). 고름은 그대로 둡니다.

### 3.3. `account-choice` (쓰임 바뀜, 3.0.0)

사주 정보·호칭·설정을 지금 계정 것으로 둘지, 가져올 계정 것으로 둘지 고르는 카드 두 장입니다.

* 카드 순서: 지금 계정 → 가져올 계정.
* 카드 안 줄:
  * ① 호칭(`type.subtitle`) + 알약
  * ② 사주 요약 한 줄(`ui.account-merge.saju`, 2.7.0 그대로)
* 알약은 두 카드 모두에 붙습니다. 모양은 2.7.0 `current`와 같습니다.
  * 지금 계정 카드: `current`(`ui.account-merge.choice` `accountChoiceCurrent`)
  * 가져올 계정 카드: 새 부품 `other`(같은 슬롯, 새 키 `accountChoiceOther`)
  * 호칭과 사주가 같은 두 계정도 가를 수 있게 하기 위해서입니다.
* **지우는 부품:** `facts`·`diaryCount`·`providers`. 기록은 고르기와 상관없이 모두 옮기므로 일기 수는 고를 근거가 아닙니다. 인증 수단은 옮기지 않습니다(D85 ④). 키 `accountChoiceDiaryCount`·`accountChoiceProviderSeparator`는 쓰지 않게 되므로 writing에 알립니다.
* 설정은 카드에 보이지 않습니다. 묶음 이름(`choice.label`)이 "사주 정보·호칭·설정"을 말합니다.
* 상태 `none`·`selected`·`pressed`·`loading`·`disabled`와 a11y는 2.7.0 그대로입니다. `none`의 합치기 버튼 `disabled`도 그대로입니다.
* 규칙 "처음부터 어느 쪽도 골라 두지 않는다"의 이유를 "고르지 않은 쪽의 사주 정보·호칭·설정은 지워져 되돌릴 수 없다"로 고칩니다.
* `summary` 문장을 "사주 정보·호칭·설정을 어느 계정 것으로 둘지 고르기 (D85 ④, 결정 V40·V44)"로 고칩니다.

## 4. 광고 제거 `ad-free`의 `offer-card` (D88 ②)

* 부품 `restore`를 지우고 `history`를 둡니다: `primary-button` `quiet`, 슬롯 `ad-free.history.cta`, 자리는 같습니다(구매 버튼·남은 기간 아래, 약관 안내 위).
* 규칙 "구매 복원은 상태와 관계없이 늘 보인다" → "구매 내역 버튼은 상태와 관계없이 늘 보인다".
* `offline` 상태에서 `history`는 누를 수 있습니다. 구매 내역 화면이 자기 `offline` 상태를 가집니다.
* 햅틱 "구매·복원 완료" → "구매 완료".

## 5. 구매 내역 `purchase-history`와 `purchase-row` (D88 ②, #502, 결정 V45)

### 5.1. `purchase-row` (새 컴포넌트, `action` 묶음)

구매 한 건입니다. 누르지 않는 줄입니다.

| 부품 | 값 |
| --- | --- |
| `product` | 산 상품 이름. `type.subtitle`, `text.primary`. 문구는 writing이 상품 id마다 둔 키(IA 밖 슬롯 `ui.purchase-product` `purchaseProduct*`), 없으면 스토어의 현지화된 이름(D88 ②). 넘치면 말줄임 없이 다음 줄로 감음(스토어 이름은 길이를 알 수 없음) |
| `status` | 오른쪽, `product` 첫 줄과 세로 가운데를 맞춤. 사용 중이면 `tag.status`, 그 밖(대기·만료·환불)은 바탕 없는 `type.label.md` `text.secondary`. 낱말은 `ui.purchase-row` 키, 상품 종류에 따라 다를 수 있음(D88 ②) |
| `meta` | `product` 아래 `space.4`. `type.caption.lg`, `text.secondary`, 고정폭 숫자. 구매일(`purchaseRowPurchased`, 날짜는 app이 기기 locale의 짧은 날짜 형식으로) + 구분자 + 사용 기간(`purchaseRowPeriod`, 시작·끝). 사용 기간이 없는 상품(server가 기간을 주지 않음)은 구매일만 |
| 줄 | 위아래 `space.16`, 줄과 줄 사이 1px `color.line`(첫 줄 위·끝 줄 아래 없음) |
| 묶음 | 줄들을 카드 한 장에 담음: `bg.sheet`, `radius.lg`, 좌우 안쪽 `space.16` |

* 순서는 server가 준 순서 그대로입니다(최근 구매가 위). app이 다시 정렬하지 않습니다.
* 사용 기간은 server가 준 구간 그대로입니다. 합치기로 옮겨 온 구매는 이 계정에서 쓰는 구간만 오므로, 구매일이 사용 기간 시작보다 이를 수 있습니다(대기 구매와 같음, D88 ②).
* 합치기 출처·산 계정 표시는 없습니다(D88 ②).
* 상태 `loading`: 줄 세 개 자리 `skeleton`(이름 줄 + meta 줄 bone). 눌림 상태는 없습니다.
* a11y: role 없음(글자 묶음). 한 줄을 한 덩어리로 "상품 이름, 상태, 구매일, 사용 기간" 순서로 읽습니다.

### 5.2. `purchase-history` 화면 배치

1. app-bar(`purchase-history.bar.title`)
2. 위 `space.12`에 `purchase-row` 묶음 카드
3. `purchase-history.missing.notice`: 위 `space.16`, `type.caption.lg`, `text.secondary`, 좌우 안쪽 `space.4`. 목록이 있든 비었든 늘 보입니다. 결제했는데 목록에 없을 수 있기 때문입니다.

* `empty`: `stateMap`대로 `empty-state`입니다. 아이콘은 Phosphor `receipt`이고 문장은 `purchase-history.empty.body`이며 주 버튼은 없습니다. `missing.notice`는 그 문장 아래 `space.16`에 둡니다.
* `loading`·`error`·`offline`은 `stateMap` 그대로입니다. 들어갈 때 결제 기록을 다시 불러오는 동안(D88 ②)이 `loading`입니다.
* 입구는 지금 `ad-free`뿐입니다. 상품이 둘 이상이 되면 설정에도 둡니다(D88 ②). 그때 IA가 바뀌면 따라잡습니다.

## 6. #475 답 (결정 V46)

| # | 항목 | 답 |
| --- | --- | --- |
| 1 | 카카오 배지 심볼 색 | 공식 자산 값 `#191919`로 명세를 고칩니다(`social-login-button` `connected` `logo.badge.kakao.symbol`). 공식 자산이 명세보다 앞섭니다(V15) |
| 2 | LINE 버튼 글자 폭 | 공식 자산의 구분선 비율을 따른 198px로 명세를 고칩니다. 글자 수 상한은 LINE 라벨 키만 198px로 따로 잽니다(`lengths.py` 키별 폭). 다른 제공자는 232px 그대로입니다 |
| 3 | `entry` 미리보기와 꺾쇠 사이 | `space.8`(`event-row`와 같음)로 명세에 적습니다 |
| 4 | 그날 시트 시각 형식 | `entry` 시각도 `event-row`와 같은 24시간제 `HH:mm`(앞 0 채움, 고정폭 숫자)입니다. 오늘·일기 목록에서도 같습니다. 줄마다 미리보기 시작 위치가 같아지고, 한 시트 안의 시각 형식이 하나가 됩니다. `event-row` `time`에도 이 형식을 적어 둡니다(값 변경 없음) |

## 7. 다른 단위에 올리는 것

* **지휘(`to:root`):**
  * ① IA `login-methods` 컴포넌트에 `primary-button`을 더함(`login-methods.merge.cta`).
  * ② IA `account-merge`의 슬롯 `account-merge.cta.cancel`과 출구 "합치지 않기"를 지움(V44: 뒤로 가기로 그만둠).
  * ③ server 합치기 요약에 가져올 계정의 일기 편수·일정 개수·광고 제거 남은 기간이 필요함(§3.2). 지휘가 server로 이어 주기를 요청합니다.
* **writing(`to:writing`):**
  * ① 다른 계정을 "가져올 계정"으로 부름(사용자 뜻)
  * ② `ui.account-merge.summary`(머리, 일기·일정·광고 제거 남은 기간 줄 이름과 값 틀)
  * ③ `accountChoiceOther`
  * ④ `ui.purchase-product`(상품 이름 `purchaseProduct*`)와 `ui.purchase-row`(상태 낱말, `purchaseRowPurchased`·`purchaseRowPeriod`, 구분자)
  * ⑤ 쓰지 않게 된 키 `accountChoiceDiaryCount`·`accountChoiceProviderSeparator`·`ad-free.restore.cta`
  * ⑥ 글자 수 상한(`lengths.md`)

## 8. 글자 수 (`tools/lengths.py`)

| 슬롯 | 자리 |
| --- | --- |
| `login-methods.merge.cta`, `ad-free.history.cta` | `primary-button` 묶음에 더함(`ad-free.restore.cta`는 뺌) |
| `account-merge.auth.body` | 본문 폭, `type.body.ui`, 3줄 |
| `login-methods.in-use.body`, `account-merge.not-other.body` | 상한 없음(확인 창 본문, 창이 늘어남) |
| `purchase-history.missing.notice` | 본문 폭 − 8, `type.caption.lg`, 2줄 |
| `ui.account-merge.summary` | 상자 안 폭(본문 − 32)에서 값 자리를 뺀 이름 한 줄 |
| `ui.purchase-row` | 상태 낱말(꼬리표 한 개 폭) |
| `ui.purchase-product` | 상한 없음(상품 이름은 줄바꿈하고 스토어 이름으로 대체될 수 있음). 슬롯을 나눈 것은 writing 상한이 슬롯 단위라서입니다 |
| `ui.login.provider` LINE 라벨 | 198px(§6 ②) |
| `account-merge.cta.cancel` | IA에서 지워질 때까지 `primary-button` 묶음에 남김(IA 대조 검사) |

`purchase-history.empty.body`는 다른 빈 상태 문장과 같이 재지 않습니다.

## 9. 결정

* **V44** 계정 합치기는 한 화면 두 단계입니다.
  * 인증 단계: 설명 + 로그인 버튼 넷.
  * 요약·고르기 단계: 설명 → 가져올 기록 상자 → 고르기 → 합치기 버튼 하나.
  * `account-choice`는 호칭 + 알약(현재 계정·가져올 계정) + 사주 요약만 보이고, 처음엔 고르지 않습니다.
  * "합치지 않기" 버튼 없이 뒤로 가기로 그만두고, 합치는 중엔 뒤로 가기를 막습니다.
  * 다른 계정에 연결된 수단, 이 계정 수단으로 인증한 경우의 안내는 `dialog` `notice`입니다. 사용자 영향: D85.
* **V45** 구매 내역은 산 상품의 기록입니다.
  * `purchase-row`는 상품 이름 → 구매일·사용 기간 줄이고, 상태는 오른쪽에 둡니다.
  * 강조는 "사용 중" 꼬리표 하나입니다.
  * 누르지 않고, 합치기 출처는 표시하지 않습니다.
  * 결제했는데 없을 때의 문의 안내는 목록이 비어도 늘 보입니다.
  * 사용자 영향: D88.
* **V46** #475:
  * 카카오 배지 심볼 `#191919`, LINE 글자 폭 198px(공식 자산 우선).
  * `entry` 꺾쇠 앞 `space.8`.
  * 일기 줄 시각은 24시간제 `HH:mm`.
  * 사용자 영향: 없음(표시 값 정렬).

## 10. Review Focus

* `account-choice`에서 지운 부품을 다른 곳(MD, 규칙 문장, 테스트)이 여전히 가리키지 않아야 합니다.
* 인증 단계에서 `social-login-button`이 `connected` 모양으로 보이면 안 됩니다. 로그인 화면과 같은 버튼입니다.
* 가져올 기록이 모두 0인 계정도 요약 상자가 사라지지 않아야 합니다.
* 상품 이름이 두 줄이 되어도 상태가 첫 줄에 붙어 있고 meta 줄이 밀리기만 해야 합니다.
* `offer-card` `offline`에서 구매 내역 버튼이 막히지 않아야 합니다.

# 계정 삭제·계정 합치기·구매 장부 (D85·D88) — spec

* 날짜: 2026-10-23
* 요청: Issue #481(D85, 지휘 코멘트: D86 ①·D88 ③·D85 ① 용어), #492(D88 ①②, 지휘 코멘트: #502 모든 상품), drift #478
* 기준: D53·D57·D60·D61·D83 ④·D85·D86·D87·D88, server spec §4.4·§9·§10, D82 spec(2026-10-22-login-providers-merge)
* 결정 번호: S105~S113. 개정: S7·S16·S83·S95·S100~S104
* 쌓는 곳: PR #473(D82 PR B) 위

## 1. 목표

계정 삭제를 요청 즉시 개인 데이터를 지우는 동작으로 바꿉니다. 카카오·Apple 허가 취소는 실패하면 다시 시도합니다. 인증 계정 연결은 다른 유저 계정에 있는 인증 계정을 거절하고, 계정 합치기는 별도 입구로 시작해 지금 유저 계정 A에 B의 기록과 구매를 옮깁니다. 구매는 산 유저 계정에 고정하는 구매 장부로 다루고, 구매 목록 API를 냅니다. 하위 호환을 깨는 계약 변경이 있어 S3 REST v1 freeze 전에 계약 PR 하나로 냅니다.

### 1.1. 용어 (D85 ①)

문서·결정·계약 설명은 아래 다섯 이름만 씁니다. 화면 말은 writing이 정합니다.

| 용어 | 뜻 | server 표 |
| --- | --- | --- |
| 유저 계정 | 명리일기 계정 자체. 인증 계정이 연결되는 주인이고 남거나 지워지는 단위. 합치기에서 A는 지금 로그인한 계정, B는 합쳐져 지워지는 계정 | `accounts` |
| 인증 계정 | 카카오·LINE·Google·Apple 쪽 사용자. 유저 계정에 "연결"됩니다 | `auth_identities` |
| 프로필 | 계정마다 하나뿐인 것(사주 정보·호칭·설정) | `profiles` |
| 기록 | 사용자가 쌓아 가는 것: 일기, 일정, 날짜 기록(태그·가이드 질문 포함), 반응 | `diaries`, `schedules`, `diary_days`, `daily_selections`+`reactions` |
| 구매 | 산 상품과 그 사용 기간(D88) | `purchases`(구매 장부), `entitlement_grants`(사용 구간) |

다섯 이름 밖의 server 내부 상태(`consents`, `rotation_state`, `refresh_tokens`, `idempotency_keys`, `account_merge_tickets`)는 이 spec에서 표 이름으로 부릅니다.

| 그 밖의 말 | 뜻 |
| --- | --- |
| 허가 취소 | 제공자 쪽 "명리일기 로그인 허용"을 없애는 호출(Apple revoke, 카카오 unlink). LINE·Google은 app SDK가 합니다(S100) |
| 사용 구간 | 기간이 있는 상품 구매 하나가 한 유저 계정에서 권한을 주는 시작·끝. `entitlement_grants` 행 |
| 지금부터 다시 잇기 | 지금 이전 구간은 두고, 남은 구간만 지금부터 구매 시각 순으로 다시 붙이는 계산(§4.3) |

## 2. PR 나누기

| 순서 | PR | 범위 | 시작 조건 |
| --- | --- | --- | --- |
| 0 | #473 | D82 제공자·연결(그대로) | writing drift #479 처리 뒤 main 다시 병합 |
| 1 | 계약 | §9 계약 전부(draft.15), 결정 개정(§8), 대장 답(§7), app `kind:request` 하나. 새 operation과 바뀐 동작은 501, `deleteMe`는 응답 모양만 204 | #503 병합(완료) |
| 2 | 계정 삭제 | §3·§4, 연결 409 토큰 제거(§6.1) | 1 |
| 3 | 구매 장부 | §5(장부, 구매 목록, `restorePurchases` 재정의) | 1 |
| 4 | 합치기 | §5.2·§5.3, `Closes #481`·`Closes #492` | 2·3 |

drift #478은 server가 고칠 것이 없습니다(원인은 writing 슬롯, #479). writing이 따라잡은 뒤 처음 병합하는 server PR 본문에 `Closes #478`을 적습니다.

## 3. 계정 삭제 (S105, S7·S16 개정)

### 3.1. 흐름

`deleteMe` 한 번에 끝납니다. 삭제 대기 상태·30일 유예·로그인으로 되돌리기는 없습니다.

1. 한 트랜잭션(`postgres.InTx`)에서 `accounts` 행을 `FOR UPDATE`로 잠급니다. 이미 `deleted`면 아무것도 하지 않습니다(그 access token은 미들웨어에서 이미 401).
2. 카카오·Apple 인증 계정마다 허가 취소 대기 행을 넣습니다(§4).
3. 반응을 문장별 집계에 더합니다(§3.2).
4. 아래 "지움" 표를 자식부터 지웁니다(FK가 모두 ON DELETE RESTRICT).
5. `accounts`를 `status = 'deleted'`, `deleted_at = now`로 바꿉니다.
6. commit 뒤 허가 취소 대기 행을 한 번씩 시도합니다(§4.2). 결과와 상관없이 204입니다.

같은 인증 계정으로 다시 로그인하면 새 유저 계정이 생깁니다. 다른 요청이 삭제 중인 계정을 쓰면 계정 행 잠금 뒤에 기다리고, 기다린 뒤 `deleted`를 보면 401 `auth.token_invalid`로 끝납니다. 이 함수(`account.DeleteAccount(ctx, tx, accountID)`)는 합치기의 B 삭제가 같은 트랜잭션 안에서 그대로 부릅니다(D85 ④).

### 3.2. 지우는 것과 남기는 것

| 지움 | 남김(기간은 §7) |
| --- | --- |
| `profiles` | `accounts` 껍데기(id·status·`created_at`·`deleted_at`) |
| `diaries`, `diary_days`, `schedules` | `purchases`, `entitlement_grants`, `billing_events`(결제·분쟁) |
| `daily_selections`, `reactions`, `rotation_state` | `reward_events`(부정 이용 방지·정산 확인) |
| `consents`, `auth_identities`, `refresh_tokens`, `idempotency_keys`, `account_merge_tickets`(이 계정이 A이거나 B인 것) | `preview_usage`(설치 id 해시, 계정과 무관) |
| 이 계정 프로필의 `birth_hash`로 만든 `chart_cache`·`daily_cache`·`month_cache` 행 | `provider_revocations`(§4, 끝나면 지움) |

* 반응은 지우기 전에 계정과 끊긴 문장별 집계 표 `reaction_tallies(message_key, variant, reaction, count)`에 더합니다(D57). 지운 반응(`deleted_at` 있음)은 더하지 않습니다.
* 캐시는 같은 출생 정보의 다른 계정도 쓸 수 있지만 다시 계산할 수 있으므로 지웁니다(D88 ③ "출생 정보로 만든 계산 캐시").
* `accounts`는 `status IN ('active', 'deleted')`만 남깁니다. `deletion_requested_at`·`anonymized_at`을 `deleted_at` 하나로 바꾸고 CHECK도 맞춥니다. 지금 `pending_deletion`인 행은 출시 전이라 migration이 그 자리에서 이 절차로 지웁니다(staging만 해당).
* 없애는 것: `account.RequestDeletion`의 30일 예정, S16 복구 로그인(`auth` 로그인의 복구 분기), `LoginResponse.restoredFromDeletion`, 삭제 대기 계정의 access token 허용 목록, P8 계획의 익명화 job.

## 4. 허가 취소 재시도 (S106, S100 개정)

### 4.1. 대기 표 `provider_revocations`

| 열 | 뜻 |
| --- | --- |
| `id` | bigserial |
| `provider` | `kakao`·`apple` |
| `subject` | 카카오 사용자 id(카카오 unlink에 씀). Apple은 NULL |
| `identity_id` | 원래 인증 계정 id. Apple refresh token을 이 id를 aad로 묶어 암호화했으므로 복호화에 씁니다 |
| `apple_refresh_token`·`apple_token_key_id`·`apple_client_id` | 원래 행의 암호화 값 그대로. 카카오는 NULL |
| `attempts`·`next_attempt_at`·`created_at` | 재시도 상태 |

FK는 없습니다(원래 인증 계정 행과 유저 계정 행을 지운 뒤에도 남아야 함).

### 4.2. 규칙

1. 떼기(`unlinkIdentity`)·계정 삭제·합치기(B 삭제)가 인증 계정 행을 지우는 트랜잭션에서, 카카오·Apple 인증 계정마다 한 행을 넣습니다. LINE·Google·테스트 제공자는 넣지 않습니다(S100).
2. commit 직후 그 행들을 한 번씩 시도합니다. 성공하면 행을 지우고, 실패하면 `attempts`를 늘리고 `next_attempt_at`을 정합니다(1분 × 2^(attempts−1), 최대 1일).
3. `server job retention`이 `next_attempt_at <= now`인 행을 `FOR UPDATE SKIP LOCKED`로 집어 다시 시도합니다. 겹쳐 도는 job은 같은 행을 부르지 않습니다.
4. 이미 끊긴 경우는 성공입니다: Apple `invalid_grant`(지금과 같음), 저장한 Apple token이 없음, 카카오가 이미 앱과 연결되지 않은 사용자라고 답함.
5. `created_at`에서 30일이 지난 행은 포기합니다. Error 로그(`id`·`provider`만)를 남기고 지웁니다.
6. 로그에 subject·token을 남기지 않습니다.

`auth.DisconnectProviders`·`stillPendingDeletion`·`markDisconnected`와 `auth_identities`의 해제 기록 열은 없앱니다. `job retention`은 지금 이름만 있으므로 이 재시도만 채우고, 나머지 정리는 P8 계획에 둡니다. 실행 주기(Cloud Scheduler)는 배포 설정 몫입니다.

## 5. 구매 장부 (S107·S108·S109, S83·S103 개정)

### 5.1. 표

**`purchases`(구매 장부, 새 표).** 상품 종류와 상관없이 앱에서 산 구매 한 건이 한 행입니다(D88 ②, #502).

| 열 | 뜻 |
| --- | --- |
| `id` | RevenueCat 구매 id(PK) |
| `account_id` | 지금 주인 유저 계정(FK RESTRICT) |
| `original_account_id` | 처음 산 유저 계정(FK RESTRICT) |
| `merged_at` | 합치기로 옮긴 시각(없으면 NULL) |
| `product_id`·`store` | RevenueCat 상품 id·스토어 |
| `purchased_at`·`refunded_at` | 구매·환불 시각 |
| `production` | production 구매인지 |

**`entitlement_grants`(사용 구간, 지금 있는 표).** 기간 상품의 사용 구간을 담습니다. unique를 `(account_id, entitlement, source, source_ref)`로 바꿔, 합친 구매가 B 구간과 A 구간을 함께 가질 수 있게 합니다. 권한 판정은 지금처럼 이 표만 읽습니다.

**상품 목록(설정).** 상품 id마다 기간(지금은 1개월)과 주는 권한(`ad_free`·`insight`)을 적습니다(지금 `SyncConfig`의 상품 id 목록을 넓힘). 목록에 없는 상품도 장부에 적지만 사용 구간은 만들지 않습니다.

### 5.2. 주인 (S107)

* 그 구매 id를 장부에 처음 적은 유저 계정이 주인입니다. 결제 직후 app이 그 계정을 동기화하고 webhook도 보통 그 계정으로 오므로, 처음 적은 계정이 결제 때 로그인한 계정입니다.
* 주인은 합치기(§6.3) 말고는 바뀌지 않습니다. S83(목록 계정으로 주인 옮김)을 없앱니다.
* RevenueCat webhook `app_user_id`는 "마지막으로 쓴 App User ID"로 정의돼 있어 주인을 고치는 근거로 쓰지 않습니다.
* 산 직후 동기화가 실패하고 webhook도 늦은 사이에 같은 스토어 계정으로 다른 유저 계정에서 불러오면 그 계정이 주인이 됩니다. 같은 스토어 계정의 사람이라 받아들이고, 문의가 오면 장부를 고칩니다.

### 5.3. 사용 구간 (S108)

* **새 구매:** `starts_at = max(purchased_at, 이 계정의 같은 권한 구간 끝)`, `expires_at = addMonth(starts_at)`(D61). 한 번 놓은 지난 구간은 다시 계산하지 않습니다.
* **지금부터 다시 잇기 `rechainFrom(account, now)`:**
  1. `expires_at <= now`인 구간은 그대로 둡니다.
  2. 환불된 구매의 구간은 `revoked_at = now`로 끊습니다.
  3. 나머지 구간(지금 쓰는 것과 대기 중인 것)의 남은 길이를 구하고, 구매 시각 순으로 `max(now, 앞 구간 끝)`부터 다시 붙입니다. 지금 쓰는 구간은 시작을 바꾸지 않고 끝만 앞 구간에 맞춥니다.
* 환불과 합치기가 이 함수를 씁니다. 합치기에서는 B 구간을 `now`에서 끊고(B 쪽 행은 남음), 그 남은 길이로 A 쪽 새 구간을 A 끝에 붙입니다(D88 ① 예: A 11/5 만료, B 12일 남음 → A 11/17).

### 5.4. 동기화

결제 직후, 구매 내역 진입 때의 `restorePurchases`, webhook이 그 계정의 RevenueCat 목록으로 장부를 맞춥니다. 계정 advisory lock(S82)을 잡은 뒤 처리합니다.

| 목록의 구매 | 처리 |
| --- | --- |
| 장부에 없음 | 이 계정을 주인으로 적고, 기간 상품이면 구간을 놓음 |
| 이 계정이 주인 | 환불 상태를 맞추고, 바뀌면 `rechainFrom` |
| 다른 계정이 주인 | 주인은 그대로. 환불은 그 구매의 사실이라 장부에 적고 주인 계정을 `rechainFrom`. 두 계정 lock은 uuid 순서로 잡음 |

장부에 있는데 그 계정 목록에 없는 구매(transfer로 다른 RevenueCat 고객에게 간 것)는 취소하지 않습니다. 기준은 장부입니다. webhook은 지금처럼 후보 계정을 찾아 동기화하고, 계정을 못 찾으면 이벤트에 든 구매 id로 장부의 주인을 찾아 그 계정을 동기화합니다. 지운 유저 계정이 주인인 구매도 장부에 남고, 다른 유저 계정으로 가져오지 않습니다(D88 ①, D85 ⑤).

### 5.5. 구매 목록 (S109)

`GET /v1/me/purchases` → `{items: [Purchase]}`, 최근 구매 먼저.

| 필드 | 뜻 |
| --- | --- |
| `productId` | 상품 id. 이름은 app이 writing 문구나 스토어 이름으로 찾습니다(D88 ②) |
| `purchasedAt` | 구매 시각 |
| `status` | 열린 enum `PurchaseStatus`: 기간 상품 `active`·`pending`·`expired`·`refunded`, 기간 없는 상품 `owned`·`refunded` |
| `period` | 기간 상품만. 이 계정의 사용 구간 `{startsAt, endsAt}`. 합친 구매는 A 구간만(D88 ②) |

산 계정과 합치기 출처는 주지 않습니다(D88 ②, #500). 페이지 나누기는 필요해지면 선택 필드로 더합니다. production이 아닌 구매는 `BILLING_PRODUCTION_ONLY`(P7)가 꺼진 환경에서만 보입니다.

### 5.6. 확장 범위

새 기간권이나 다른 권한을 주는 상품은 상품 목록 설정 한 줄로 더합니다. 장부·목록 API·권한 표는 고치지 않습니다. 자동 갱신 구독(D53 ③)은 RevenueCat 구독 객체·갱신 이벤트와 스토어 만료일을 따르는 다른 경로라, 장부에 담는 단위와 동기화를 구독을 넣을 때 정합니다. 그 자리를 막지 않으려고 장부에 상품 종류를 굳히는 열·제약을 두지 않고 상태는 열린 enum으로 둡니다.

## 6. 인증 계정 연결과 계정 합치기 (S110·S111, S95·S101·S102 개정)

### 6.1. 연결 거절 (S110)

`linkIdentity`가 다른 유저 계정에 연결된 인증 계정을 받으면 409 `auth.identity_in_use`만 줍니다(D85 ③). 합치기 토큰과 `account_merge_tickets` 발급을 409에서 뺍니다. `auth.identity_pending_deletion`은 없앱니다. `auth.provider_taken`·`auth.last_identity`는 그대로입니다.

### 6.2. 요약 `previewMerge` (S110)

`POST /v1/me/merge/preview`는 B의 인증 증명을 받습니다. 모양은 `LinkIdentityRequest`에 `provider`를 더한 것이고 검증은 연결과 같습니다(S99). Apple은 소유 확인에 id_token만 씁니다. Android 웹 흐름의 code 교환으로 받은 refresh token은 저장하지 않습니다. 같은 Apple 허가는 B 삭제 때 B의 저장 token으로 취소됩니다(§4).

| 증명한 인증 계정 | 결과 |
| --- | --- |
| A에 연결됨 | 422 `merge.same_account` |
| 어느 유저 계정에도 없음 | 422 `merge.no_account`(연결로 넘어가지 않음) |
| B에 연결됨 | 200: 합치기 토큰·만료와 요약 |

* 합치기 토큰은 지금 `account_merge_tickets`를 그대로 씁니다. 32바이트 base64url, SHA-256만 저장, 10분, 일회용, A·B와 증명한 인증 계정에 묶입니다. 그 인증 계정이 B에서 떼어지면 행이 함께 지워져 토큰이 무효가 됩니다.
* 요약: 옮길 기록 수(일기·일정·날짜 기록·반응, 지운 일기·일정 포함), 같은 날짜 기록이 겹치는 날 수, 더해질 남은 날(기간 상품 권한별), A·B 프로필(호칭, `Birth` 모양의 사주 정보). 옮길 기록이 0건이어도 줍니다.

### 6.3. 실행 `mergeAccounts` (S111)

`POST /v1/me/merge`, 요청 `{mergeToken, profile: current | other}`, `Idempotency-Key`를 받습니다(S60). 응답은 A의 `Me`입니다. 남는 유저 계정이 언제나 A라 새 세션을 주지 않고, 응답에 비밀 값이 없어 멱등 기록에 저장할 수 있습니다(S102의 "받지 않음"을 바꿈).

한 트랜잭션에서:

1. A·B 행을 uuid 순서로 `FOR UPDATE`. 토큰이 있고, 안 썼고, 안 지났고, bearer가 A이고, B가 `active`인지 확인합니다. 아니면 422 `merge.token_invalid`. 토큰을 씀으로 표시합니다.
2. **기록:** B의 `diaries`(지운 것 포함, 10편 상한 무시, D83 ④)·`schedules`·`diary_days`·`daily_selections`(+`reactions`)를 A로 옮깁니다.
   * 같은 날짜의 `diary_days`가 둘 다 있으면 **고른 프로필 쪽** 날짜 기록을 남기고, 다른 쪽 일기는 모두 남긴 날짜 기록 아래로 옮깁니다. 일기는 하나도 지우지 않습니다(S95 개정).
   * 같은 `(date, slot, birth_hash)`의 `daily_selections`가 둘 다 있으면 고른 프로필 쪽을 남깁니다. 다른 쪽 선택에 붙은 반응은 `reaction_tallies`에 더한 뒤 지웁니다. 두 계정의 출생 정보가 같고 같은 날 같은 자리를 본 경우에만 생깁니다.
3. **프로필:** `profile = other`면 B의 프로필로 A의 `profiles` 행을 바꿉니다.
4. **구매:** B가 주인인 `purchases`를 A로 옮기고(`account_id = A`, `merged_at = now`, `original_account_id`는 그대로), `rechainFrom`으로 B 구간을 끊고 A 끝에 붙입니다(§5.3).
5. **B 삭제:** `account.DeleteAccount(tx, B)`(§3.1). B의 인증 계정·세션·`rotation_state`·`consents` 등이 지워지고 허가 취소 대기 행이 생깁니다. 인증 계정은 옮기지 않습니다(D85 ④).

commit 뒤 허가 취소를 시도합니다(§4.2). A와 B가 서로를 동시에 합치면 잠금 순서 때문에 하나만 성공하고, 다른 쪽은 상대가 `deleted`라 `merge.token_invalid`입니다.

## 7. 수집·보관 기간 (S113, 대장 `docs/legal/data-inventory.md` 답)

| 항목 | 기간 | 근거 |
| --- | --- | --- |
| 날짜 기록 | 따로 정리하지 않고 계정 삭제 때 지움 | 그날 일기를 다 지워도 다시 쓸 때 같은 질문·태그(S95) |
| 동의 기록·문장 선택 기록 | 계정 삭제 때 지움 | D88 ③ |
| 비로그인 IP 해시(`rate_limits`) | 1분 창이 끝난 뒤 `job retention`이 지움, 최대 1일 | S68 |
| 미리보기 설치 id 해시 | 1년 | S70, 사용자 결정 2026-10-23 |
| 보상형 광고 기록 | 받은 날부터 1년(계정 삭제와 무관) | 부정 이용 방지·정산 확인, 사용자 결정 2026-10-23 |
| 결제 기록(`billing_events`·`purchases`·`entitlement_grants`) | 결제일부터 5년 | 전자상거래법 시행령 제6조 |
| 허가 취소 대기 | 성공 즉시, 최대 30일 | §4.2 |
| 요청 로그 | 3개월(Cloud Logging 보관 90일) | 통신비밀보호법 시행령 제41조에 맞춤 |
| DB 백업 | 7일(Cloud SQL 자동 백업 7개·PITR 7일) | 지운 데이터가 백업에 최대 7일 |

법 조항이 이 서비스에 해당하는지는 법률 검토가 필요하다고 대장 답에 함께 적습니다. 기간이 지난 행의 정리(설치 id·보상 기록·IP 해시·결제 5년)는 P8 `job retention` 몫이고, 로그·백업 기간은 배포 설정 몫입니다.

## 8. 오류 코드와 결정 개정 (S112)

* problem code: `auth.identity_pending_deletion` 없앰. `merge.same_account`·`merge.no_account`(422) 더함. `merge.token_invalid`(422) 그대로.
* 개정하는 server 결정: S7·S16(→ S105), S83·S103(→ S107·S108), S95(겹친 날은 고른 프로필 쪽), S100(떼기 허가 취소 → S106), S101(토큰은 `previewMerge`가 발급 → S110), S102(→ S111), S104(→ S112). 2026-10-24부터 쓰는 행은 근거 칸에 `사용자 영향` 표시를 붙입니다(D87).
* D82 spec §3.3·§4·§5의 해당 문단에 이 spec을 가리키는 표시를 답니다.

## 9. REST 계약 (draft.15)

| operation·스키마 | 바뀌는 것 | 하위 호환 |
| --- | --- | --- |
| `deleteMe` | 202 + `deletionScheduledAt` → 204, 본문 없음. 스키마 `DeletionScheduled` 없앰 | 깨짐 |
| `Me` | `status`·`deletionScheduledAt` 없앰 | 깨짐 |
| `LoginResponse` | `restoredFromDeletion` 없앰 | 깨짐 |
| `linkIdentity` 409 | `mergeToken`·`expiresAt` 없앰(Problem의 두 필드도), `auth.identity_pending_deletion` 없앰 | 깨짐 |
| `previewMerge` | 요청 `MergePreviewRequest` = B의 증명. 응답 `MergePreview` = 토큰·만료·요약(§6.2) | 깨짐 |
| `mergeAccounts` | 요청 `keep` → `profile`, 응답 → `Me`, `Idempotency-Key` | 깨짐 |
| `listPurchases` | 새 operation(§5.5) | 추가 |
| `restorePurchases` | 설명만: 이 계정의 장부를 다시 맞춤, 다른 계정이 주인인 구매는 가져오지 않음 | 동작 |

계약 PR은 바뀐 handler의 응답 모양을 계약에 맞추고, 새 동작이 아직 없는 `previewMerge`·`mergeAccounts`·`listPurchases`는 501입니다. `deleteMe`는 응답 모양만 204로 맞추고 즉시 삭제는 PR 2가 넣습니다. contracts README의 server 행을 고치고, app에 위 "깨짐" 전부와 #463의 바뀐 부분을 담은 `kind:request`를 엽니다(D78).

## 10. 테스트

* **계정 삭제:** 모든 표를 채운 계정을 지우면 "지움" 표에 그 계정 행이 0개이고 "남김" 표는 그대로. 반응 집계 값. 같은 인증 계정 재로그인은 새 유저 계정. 삭제 중인 계정을 쓰는 요청이 401.
* **허가 취소:** 실패하는 가짜 제공자로 행이 남고 job이 다시 시도해 지움. 겹친 job이 한 번만 부름. 30일 포기. 이미 끊긴 응답은 성공. 떼기도 같은 경로.
* **구매 장부:** 다른 계정의 복원으로 주인이 바뀌지 않음. 환불하면 뒤 구간이 앞당겨짐. 목록에서 빠진 구매 유지. 두 계정 동시 동기화에 deadlock 없음. 목록에 없는 상품은 `owned` 줄만. 목록 API의 상태·구간.
* **합치기:** preview 세 갈래. 겹친 날짜 기록과 문장 선택 기록은 고른 프로필 쪽. 고른 프로필. 구매 남은 날 합산(D88 예시 11/17)과 B 구간 끊김. B 삭제와 허가 취소 대기 행. A·B 서로 동시 합치기는 하나만 성공. 같은 `Idempotency-Key` 재전송은 같은 응답. 토큰 재사용·만료·다른 bearer는 `merge.token_invalid`.
* **계약:** 계약 테스트·생성 코드 차이 검사, 501 operation.

## 11. 결정

| 번호 | 내용 |
| --- | --- |
| S105 | 계정 삭제는 요청 한 트랜잭션에서 개인 데이터를 지우고 `accounts`를 껍데기로 남김(§3). S7·S16 개정 |
| S106 | 카카오·Apple 허가 취소는 `provider_revocations`에 같은 트랜잭션으로 넣고 commit 뒤 시도, `job retention`이 늘어나는 간격으로 30일까지 재시도(§4) |
| S107 | 구매 주인은 장부에 처음 적은 유저 계정이고 합치기 말고는 바뀌지 않음(§5.2). S83 개정 |
| S108 | 사용 구간은 저장하고 다시 계산하지 않으며, 환불·합치기는 지금부터 다시 잇기(§5.3). S103 개정 |
| S109 | 구매 목록 API는 모든 상품의 구매를 상품 id·구매 시각·상태·이 계정 구간으로 줌(§5.5) |
| S110 | 연결 409에 합치기 토큰 없음, 토큰은 B 증명을 받는 `previewMerge`가 발급(§6.1·§6.2). S101 개정 |
| S111 | 합치기는 A가 남고 프로필을 고르며 기록·구매를 옮기고 B를 계정 삭제로 지움. 겹치면 고른 프로필 쪽, `Idempotency-Key` 받음(§6.3). S95·S102 개정 |
| S112 | problem code 변경(§8). S104 개정 |
| S113 | 수집·보관 기간(§7) |
